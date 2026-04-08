// Required Netlify env vars:
// SUPABASE_URL — Supabase project URL
// SUPABASE_ANON_KEY — Supabase anon/public key
// SUPABASE_SERVICE_KEY — used in paypal-webhook only, not injected here

exports.handler = async () => ({
  statusCode: 200,
  headers: { "Content-Type": "application/javascript" },
  body: `window.SUPABASE_URL="${process.env.SUPABASE_URL || ""}";
window.SUPABASE_ANON_KEY="${process.env.SUPABASE_ANON_KEY || ""}";`,
});
