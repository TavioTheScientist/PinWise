-- SECURITY FIX for 0003. `apply_subscription_state` was callable with the ANON key.
--
-- WHAT WENT WRONG: 0003 ended with
--     revoke all on function public.apply_subscription_state(...) from public;
-- which looks like a lockdown and is not one. Supabase grants EXECUTE on new functions in the
-- `public` schema to the `anon` and `authenticated` ROLES, and revoking from `public` (the implicit
-- pseudo-role) does not touch a grant made to a named role. Verified against the live project: an
-- anon-key POST to /rest/v1/rpc/apply_subscription_state EXECUTED the function and failed only
-- because the test UUID had no profile row.
--
-- WHY IT MATTERED: the function is SECURITY DEFINER, so it runs with the definer's privileges and
-- bypasses RLS. The anon key ships inside the app and is public by design. So the whole paywall was
-- one curl away from being bypassed for any user id, and any profile row could be rewritten by a
-- stranger. This is the one function in the schema that grants paid access — it needed to be the
-- most locked-down, not the least.
--
-- TWO LAYERS, deliberately, because either alone is one mistake from failing:
--   1. Revoke EXECUTE from the named roles, so PostgREST rejects the call before it reaches SQL.
--   2. An in-function role assertion, so a future migration that re-grants (or a change to
--      Supabase's default privileges) does not silently re-open the hole.
--
-- `claim_trial_start` is deliberately NOT locked down the same way: it is scoped to `auth.uid()`'s
-- own row and raises 'not authenticated' when there is no session, so anon reaching it is harmless
-- and `authenticated` reaching it is the intended path. Verified against the live project.
-- ---------------------------------------------------------------------------

revoke all on function public.apply_subscription_state(uuid, text, text, timestamptz, boolean)
    from anon, authenticated;

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
    jwt_role text := coalesce(
        nullif(current_setting('request.jwt.claims', true), '')::json ->> 'role',
        ''
    );
begin
    -- Layer 2. An empty role means there is no PostgREST request context at all — a direct SQL
    -- session (a migration, or psql), which is allowed. Any request that DOES arrive over the API
    -- must be carrying the service role; `anon` and `authenticated` are refused outright.
    if jwt_role <> '' and jwt_role <> 'service_role' then
        raise exception 'apply_subscription_state is service-role only (got %)', jwt_role
            using errcode = '42501';   -- insufficient_privilege
    end if;

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

-- `create or replace` resets grants to the defaults, so revoke AGAIN after redefining. Order
-- matters here and getting it backwards is precisely how 0003 shipped open.
revoke all on function public.apply_subscription_state(uuid, text, text, timestamptz, boolean)
    from public, anon, authenticated;
