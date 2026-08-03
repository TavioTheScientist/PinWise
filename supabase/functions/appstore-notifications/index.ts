// App Store Server Notifications V2 → `profiles.tier`.
//
// This is the ONLY thing that grants `pro`. Everything about it is therefore shaped by one
// question: can a stranger POST here and give themselves a subscription? No — the payload is a JWS
// signed by Apple, and it is verified against a pinned Apple root CA before a single field is read.
//
// WHY APPLE'S LIBRARY AND NOT HAND-ROLLED JWS:
// Verifying these payloads means validating an X.509 chain — leaf signed by intermediate,
// intermediate signed by root, root equal to Apple's. Checking only the JWS signature against the
// leaf in `x5c` is NOT verification: an attacker supplies their own leaf. Comparing just the root
// in `x5c` is not verification either, because the chain between leaf and root is what binds them.
// Hand-rolling ASN.1 TBS extraction for a security boundary is how this goes wrong quietly, so
// `SignedDataVerifier` does it.
//
// DEPLOYMENT (this function is different from ai-chat in two ways):
//
//   1. NO SUPABASE JWT. Apple does not send one, so it must be deployed with verification off:
//        supabase functions deploy appstore-notifications --no-verify-jwt
//      Authentication here is the Apple signature, not a bearer token. Deploying it WITH JWT
//      verification silently rejects every notification (Apple sees 401 and retries for days).
//
//   2. APPLE ROOT CERTIFICATES must be supplied. Download the DER files from
//      https://www.apple.com/certificateauthority/ (AppleRootCA-G3 is the one that signs these;
//      include G2 as well so a chain rotation doesn't take the webhook down), base64 them, and set:
//        supabase secrets set APPLE_ROOT_CERTS_B64="<der-b64>,<der-b64>"
//        supabase secrets set APPLE_BUNDLE_ID=com.staxyz.app
//        supabase secrets set APPLE_ENVIRONMENT=Sandbox        # or Production
//        supabase secrets set APPLE_APP_APPLE_ID=<numeric App Store id>   # Production only
//
//      APPLE_APP_APPLE_ID is required in Production and must be omitted in Sandbox — the library
//      rejects a mismatch, which is a good thing: it stops a sandbox notification from being
//      accepted as a production one.
//
// HOW A NOTIFICATION FINDS ITS USER:
// Apple identifies a subscription by `originalTransactionId` and knows nothing about Supabase. The
// app sends the user's UUID as StoreKit's `appAccountToken` at purchase, Apple echoes it back in
// every signed transaction, and that is the join key. It is stored on the profile the first time
// through so later payloads still match even if the token is absent.

import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  Environment,
  SignedDataVerifier,
} from "npm:@apple/app-store-server-library@1";

const BUNDLE_ID = Deno.env.get("APPLE_BUNDLE_ID") ?? "com.staxyz.app";

function appleEnvironment(): Environment {
  return (Deno.env.get("APPLE_ENVIRONMENT") ?? "Sandbox") === "Production"
    ? Environment.PRODUCTION
    : Environment.SANDBOX;
}

/** Pinned Apple roots, base64 DER, comma-separated. Absent ⇒ the function refuses to run. */
function appleRootCerts(): Uint8Array[] {
  const raw = Deno.env.get("APPLE_ROOT_CERTS_B64");
  if (!raw) {
    throw new Error(
      "APPLE_ROOT_CERTS_B64 is not set. Refusing to start: without pinned roots there is no way " +
        "to tell an Apple notification from a forged one.",
    );
  }
  return raw
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
    .map((b64) => Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)));
}

function buildVerifier(): SignedDataVerifier {
  const env = appleEnvironment();
  const appAppleId = Deno.env.get("APPLE_APP_APPLE_ID");
  return new SignedDataVerifier(
    appleRootCerts(),
    /* enableOnlineChecks */ true,
    env,
    BUNDLE_ID,
    // Required in Production, must be undefined in Sandbox.
    env === Environment.PRODUCTION && appAppleId ? Number(appAppleId) : undefined,
  );
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Apple retries any non-2xx for up to several days. So the rule is: reject FORGERIES with 4xx
  // (retrying won't help and we don't want the traffic), but return 5xx for OUR failures — a
  // transient database error should be retried, not silently dropped.
  let verifier: SignedDataVerifier;
  try {
    verifier = buildVerifier();
  } catch (err) {
    console.error("misconfigured:", err instanceof Error ? err.message : err);
    return new Response("Server misconfigured", { status: 500 });
  }

  let signedPayload: string;
  try {
    const body = await req.json();
    signedPayload = body?.signedPayload;
    if (typeof signedPayload !== "string" || !signedPayload) {
      return new Response("Missing signedPayload", { status: 400 });
    }
  } catch {
    return new Response("Malformed body", { status: 400 });
  }

  // THE security boundary. Anything that fails here is not from Apple.
  let notification;
  try {
    notification = await verifier.verifyAndDecodeNotification(signedPayload);
  } catch (err) {
    console.warn("rejected unverified payload:", err instanceof Error ? err.message : err);
    return new Response("Invalid signature", { status: 401 });
  }

  const type = notification.notificationType;
  const subtype = notification.subtype;
  const transaction = notification.data?.signedTransactionInfo
    ? await verifier.verifyAndDecodeTransaction(notification.data.signedTransactionInfo)
    : undefined;

  // Notifications that carry no transaction (e.g. CONSUMPTION_REQUEST, some TEST payloads) are
  // acknowledged rather than retried — there is nothing to apply.
  if (!transaction) {
    console.log(`ack ${type}${subtype ? "/" + subtype : ""} — no transaction payload`);
    return new Response("OK", { status: 200 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const originalTransactionId = transaction.originalTransactionId ?? null;
  const productId = transaction.productId ?? null;
  const expiresAt = transaction.expiresDate ? new Date(transaction.expiresDate).toISOString() : null;
  const revoked = transaction.revocationDate != null;

  // Resolve the user: appAccountToken first (present from the purchase onward), then the stored
  // originalTransactionId as a fallback for any payload that omits the token.
  let userId: string | null = transaction.appAccountToken ?? null;

  if (!userId && originalTransactionId) {
    const { data, error } = await supabase
      .from("profiles")
      .select("id")
      .eq("original_transaction_id", originalTransactionId)
      .maybeSingle();
    if (error) {
      console.error("lookup failed:", error.message);
      return new Response("Lookup failed", { status: 500 });   // retryable
    }
    userId = data?.id ?? null;
  }

  if (!userId) {
    // Genuinely unmappable — most often a sandbox purchase made before appAccountToken was wired,
    // or a StoreKit-config transaction. Acknowledge: retrying will never produce a mapping, and
    // making Apple retry for days over an orphan notification is worse than logging it.
    console.warn(
      `unmapped ${type} — no appAccountToken and no profile for originalTransactionId ` +
        `${originalTransactionId}. Acknowledged without applying.`,
    );
    return new Response("OK", { status: 200 });
  }

  // Tier derivation lives in the RPC, not here: expiry + revocation decide it, and one place
  // deciding "what counts as pro" beats every notification type re-implementing the rule.
  const { data: tier, error } = await supabase.rpc("apply_subscription_state", {
    p_user_id: userId,
    p_original_transaction_id: originalTransactionId,
    p_product_id: productId,
    p_expires_at: expiresAt,
    p_revoked: revoked,
  });

  if (error) {
    console.error("apply_subscription_state failed:", error.message);
    return new Response("Apply failed", { status: 500 });   // retryable
  }

  console.log(
    `${type}${subtype ? "/" + subtype : ""} → user ${userId} tier=${tier} ` +
      `product=${productId} expires=${expiresAt} revoked=${revoked}`,
  );
  return new Response("OK", { status: 200 });
});
