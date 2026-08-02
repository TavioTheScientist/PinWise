-- Staxyz subscriptions: a durable trial clock, and the Apple ↔ user mapping the App Store
-- Server Notifications webhook needs to flip a tier.
--
-- Two problems this solves, both of which the client cannot solve alone:
--
--  1. THE TRIAL CLOCK IS RESETTABLE ON DEVICE. The 21-day trial is app-managed (Apple's
--     intro-offer durations don't include 21 days), so there is no receipt proving when it
--     started — the client reads a UserDefaults date, which delete-and-reinstall clears.
--     Stamping it here, keyed to the auth user, makes it survive reinstall and follow the account
--     across devices. `claim_trial_start` is write-once by construction.
--
--  2. APPLE DOES NOT KNOW WHO THE USER IS. A server notification identifies a subscription by
--     `originalTransactionId`, not by Supabase user. The client therefore sends the user's UUID as
--     StoreKit's `appAccountToken` at purchase time, Apple echoes it back in every signed
--     transaction for that subscription, and the webhook uses it to find the row. That is why
--     `original_transaction_id` is stored on first notification: renewals and expirations for the
--     same subscription can then be matched even if a later payload omits the token.
-- ---------------------------------------------------------------------------

alter table public.profiles
    add column if not exists trial_started_at         timestamptz,
    add column if not exists original_transaction_id  text,
    add column if not exists subscription_expires_at  timestamptz,
    add column if not exists subscription_product_id  text,
    add column if not exists subscription_updated_at  timestamptz;

-- One subscription maps to at most one profile. A UNIQUE index rather than a plain one: two
-- profiles claiming the same Apple subscription means account sharing, and it should fail loudly
-- at write time instead of silently granting two people access.
create unique index if not exists profiles_original_transaction_id_key
    on public.profiles (original_transaction_id)
    where original_transaction_id is not null;

-- ---------------------------------------------------------------------------
-- claim_trial_start: write-once stamp of when this user's trial began.
--
-- SECURITY DEFINER so it can write a column that has no client UPDATE policy, but it writes ONLY
-- `auth.uid()`'s own row and ONLY when the column is still null — so a user cannot restart their
-- trial, and cannot touch anyone else's. Returns the effective start date either way, which is
-- what the client caches locally.
-- ---------------------------------------------------------------------------
create or replace function public.claim_trial_start()
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
    uid   uuid := auth.uid();
    stamp timestamptz;
begin
    if uid is null then
        raise exception 'not authenticated';
    end if;

    -- COALESCE keeps this write-once: an existing value is preserved, so repeated calls (every
    -- launch, every re-sign-in) are idempotent and cannot extend the trial.
    update public.profiles
       set trial_started_at = coalesce(trial_started_at, now())
     where id = uid
    returning trial_started_at into stamp;

    -- The auto-profile trigger normally guarantees a row, but a user created before that trigger
    -- existed would have none. Create it rather than returning null and handing the client a
    -- reason to fall back to its resettable local clock.
    if stamp is null then
        insert into public.profiles (id, trial_started_at)
             values (uid, now())
        on conflict (id) do update set trial_started_at = coalesce(public.profiles.trial_started_at, now())
        returning trial_started_at into stamp;
    end if;

    return stamp;
end;
$$;

revoke all on function public.claim_trial_start() from public;
grant execute on function public.claim_trial_start() to authenticated;

-- ---------------------------------------------------------------------------
-- apply_subscription_state: the ONLY path that sets tier = 'pro'.
--
-- Called exclusively by the webhook with the service role. Not granted to `authenticated` — if a
-- client could call this, the entire paywall would be one RPC away from being bypassed.
--
-- Takes the decoded transaction facts and derives the tier, rather than accepting a tier directly,
-- so "what counts as pro" is decided in one place instead of by each caller.
-- ---------------------------------------------------------------------------
create or replace function public.apply_subscription_state(
    p_user_id                 uuid,
    p_original_transaction_id text,
    p_product_id              text,
    p_expires_at              timestamptz,
    p_revoked                 boolean default false
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    new_tier text;
begin
    -- A revoked (refunded) subscription loses access immediately regardless of its expiry date.
    -- Otherwise the expiry date alone decides: Apple sends DID_RENEW ahead of time, so a future
    -- expiry means paid-up and a past one means lapsed.
    if p_revoked or p_expires_at is null or p_expires_at <= now() then
        new_tier := 'free';
    else
        new_tier := 'pro';
    end if;

    update public.profiles
       set tier                    = new_tier,
           original_transaction_id = coalesce(p_original_transaction_id, original_transaction_id),
           subscription_product_id = p_product_id,
           subscription_expires_at = p_expires_at,
           subscription_updated_at = now()
     where id = p_user_id;

    if not found then
        raise exception 'no profile for user %', p_user_id;
    end if;

    return new_tier;
end;
$$;

revoke all on function public.apply_subscription_state(uuid, text, text, timestamptz, boolean) from public;
-- Deliberately NOT granted to `authenticated`. Service role only, and the service role bypasses
-- grants anyway — the revoke is here so a future "grant execute ... to authenticated" has to be
-- written deliberately rather than inherited.
