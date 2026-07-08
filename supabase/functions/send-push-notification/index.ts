import { createClient } from "jsr:@supabase/supabase-js@2";

// ── Types ─────────────────────────────────────────────────────────────────────

interface RequestBody {
  agent_id: string;
  title: string;
  message: string;
  related_lead_id?: string;
}

interface ServiceAccount {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
  token_uri: string;
}

// ── OAuth2 token from service account ────────────────────────────────────────

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: sa.token_uri,
    iat: now,
    exp: now + 3600,
  };

  const b64 = (obj: object) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

  const signingInput = `${b64(header)}.${b64(payload)}`;

  // Import the RSA private key
  const pemKey = sa.private_key.replace(/\\n/g, "\n");
  const keyData = pemKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "");

  const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const encoder = new TextEncoder();
  const signatureBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    encoder.encode(signingInput)
  );

  const signature = btoa(
    String.fromCharCode(...new Uint8Array(signatureBuffer))
  )
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const jwt = `${signingInput}.${signature}`;

  // Exchange JWT for access token
  const tokenRes = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenRes.ok) {
    const err = await tokenRes.text();
    throw new Error(`OAuth2 token exchange failed: ${err}`);
  }

  const { access_token } = await tokenRes.json();
  return access_token as string;
}

// ── FCM V1 send ───────────────────────────────────────────────────────────────

async function sendToToken(
  accessToken: string,
  projectId: string,
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<{ success: boolean; unregistered: boolean }> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
          data,
          android: {
            priority: "high",
            notification: {
              channel_id: "propex_notifications",
              sound: "default",
            },
          },
        },
      }),
    }
  );

  if (res.ok) return { success: true, unregistered: false };

  const errBody = await res.json().catch(() => ({}));
  const errCode = errBody?.error?.details?.[0]?.errorCode ?? "";
  const unregistered =
    errCode === "UNREGISTERED" || errCode === "INVALID_ARGUMENT";

  console.error(`[FCM] Token send failed (${res.status}):`, errCode, fcmToken.slice(-8));
  return { success: false, unregistered };
}

// ── Main handler ──────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON body", { status: 400 });
  }

  const { agent_id, title, message, related_lead_id } = body;
  if (!agent_id || !title || !message) {
    return new Response("Missing required fields: agent_id, title, message", {
      status: 400,
    });
  }

  // Load service account from secret
  const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!saJson) {
    return new Response("FIREBASE_SERVICE_ACCOUNT secret not set", {
      status: 500,
    });
  }

  let sa: ServiceAccount;
  try {
    sa = JSON.parse(saJson);
  } catch {
    return new Response("Invalid FIREBASE_SERVICE_ACCOUNT JSON", {
      status: 500,
    });
  }

  // Supabase admin client to query device_tokens
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // Fetch all tokens for this agent
  const { data: tokens, error: tokensErr } = await supabase
    .from("device_tokens")
    .select("id, token")
    .eq("agent_id", agent_id)
    .eq("platform", "android");

  if (tokensErr) {
    console.error("[FCM] DB error fetching tokens:", tokensErr.message, tokensErr.code, tokensErr.details);
    return new Response(JSON.stringify({ error: "DB error", message: tokensErr.message, code: tokensErr.code }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!tokens || tokens.length === 0) {
    return new Response(JSON.stringify({ sent: 0, failed: 0 }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  // Get OAuth2 access token once for all sends
  let accessToken: string;
  try {
    accessToken = await getAccessToken(sa);
  } catch (e) {
    console.error("[FCM] OAuth2 error:", e);
    return new Response("OAuth2 token error", { status: 500 });
  }

  const data: Record<string, string> = {};
  if (related_lead_id) data["related_lead_id"] = related_lead_id;

  let sent = 0;
  let failed = 0;
  const staleTokenIds: string[] = [];

  for (const { id, token } of tokens) {
    const result = await sendToToken(
      accessToken,
      sa.project_id,
      token,
      title,
      message,
      data
    );

    if (result.success) {
      sent++;
    } else {
      failed++;
      if (result.unregistered) staleTokenIds.push(id);
    }
  }

  // Remove stale/unregistered tokens
  if (staleTokenIds.length > 0) {
    await supabase
      .from("device_tokens")
      .delete()
      .in("id", staleTokenIds);
    console.log(`[FCM] Removed ${staleTokenIds.length} stale token(s)`);
  }

  const result = { sent, failed };
  console.log(`[FCM] Done:`, result);

  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
  });
});
