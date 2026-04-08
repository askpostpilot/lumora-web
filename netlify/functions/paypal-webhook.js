// Required Netlify env vars:
// SUPABASE_URL — already set
// SUPABASE_SERVICE_KEY — get from Supabase Dashboard > Settings > API > service_role key
// RESEND_API_KEY — already set
// RESEND_FROM_EMAIL — already set
const { createClient } = require("@supabase/supabase-js");
const https = require("https");
const querystring = require("querystring");

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

// Map PayPal button/item IDs to plan names
const PLAN_MAP = {
  "3UYP578XT4AE6": "starter",
  "5666PF74ADKB4": "pro",
  "6V2NYJTE68VZ2": "agency",
};

// Map plan names to their limits
const PLAN_LIMITS = {
  starter: {
    plan: "starter",
    ai_credits_limit: 100,
    thumbnail_credits_limit: 10,
    brand_limit: 1,
  },
  pro: {
    plan: "pro",
    ai_credits_limit: 500,
    thumbnail_credits_limit: 30,
    brand_limit: 3,
  },
  agency: {
    plan: "agency",
    ai_credits_limit: 1000,
    thumbnail_credits_limit: 100,
    brand_limit: 10,
  },
};

async function verifyWithPayPal(rawBody) {
  return new Promise((resolve) => {
    const verifyBody = "cmd=_notify-validate&" + rawBody;
    const options = {
      host: "ipnpb.paypal.com",
      path: "/cgi-bin/webscr",
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Content-Length": Buffer.byteLength(verifyBody),
      },
    };
    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => { data += chunk; });
      res.on("end", () => resolve(data.trim()));
    });
    req.on("error", () => resolve("INVALID"));
    req.write(verifyBody);
    req.end();
  });
}

async function sendAlertEmail(subject, details) {
  try {
    const { Resend } = require("resend");
    const resend = new Resend(process.env.RESEND_API_KEY);
    await resend.emails.send({
      from: process.env.RESEND_FROM_EMAIL || "hello@solyntraai.com",
      to: "support@solyntraai.com",
      subject,
      html: `

        
${subject}

        
${JSON.stringify(details, null, 2)}

        

SolyntraAI — automatic alert


      
`,
    });
  } catch (e) {
    console.error("Alert email failed:", e.message);
  }
}

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") {
    return { statusCode: 405, body: "Method not allowed" };
  }

  const rawBody = event.body || "";
  const params = querystring.parse(rawBody);

  // Step 1: Verify with PayPal
  const verification = await verifyWithPayPal(rawBody);
  if (verification !== "VERIFIED") {
    console.error("PayPal IPN verification failed:", verification);
    return { statusCode: 200, body: "IPN verification failed" };
  }

  // Step 2: Only handle completed payments
  const txnType = params.txn_type || "";
  const paymentStatus = params.payment_status || "";

  const isCompleted =
    paymentStatus === "Completed" ||
    txnType === "subscr_payment" ||
    txnType === "web_accept";

  if (!isCompleted) {
    return { statusCode: 200, body: "Ignored: not a completed payment" };
  }

  // Step 3: Extract payment details
  const payerEmail = (params.payer_email || "").toLowerCase().trim();
  const itemNumber = params.item_number || params.btn_id || "";
  const txnId = params.txn_id || params.subscr_id || "";
  const amount = params.mc_gross || params.amount || "0";
  const currency = params.mc_currency || "USD";

  // Step 4: Determine plan from item_number or amount fallback
  let planKey = PLAN_MAP[itemNumber];

  // Amount-based fallback if item_number not matched
  if (!planKey) {
    const amt = parseFloat(amount);
    if (amt >= 149) planKey = "agency";
    else if (amt >= 79) planKey = "pro";
    else if (amt >= 29) planKey = "starter";
  }

  if (!planKey) {
    await sendAlertEmail("⚠️ SolyntraAI: Unknown PayPal payment received", {
      payerEmail,
      itemNumber,
      amount,
      currency,
      txnId,
    });
    return { statusCode: 200, body: "Unknown plan — alert sent" };
  }

  const limits = PLAN_LIMITS[planKey];

  // Step 5: Find user in Supabase by payer email
  const { data: profile, error: findError } = await supabase
    .from("profiles")
    .select("id, email, plan")
    .eq("email", payerEmail)
    .single();

  if (findError || !profile) {
    // User not found — send manual activation alert
    await sendAlertEmail("🔔 SolyntraAI: Manual plan activation needed", {
      reason: "Payer email not found in Supabase",
      payerEmail,
      plan: planKey,
      amount,
      txnId,
      instructions: "Find this user manually and run: UPDATE profiles SET plan = '" + planKey + "' WHERE email = '';",
    });
    return { statusCode: 200, body: "User not found — manual alert sent" };
  }

  // Step 6: Update plan in Supabase
  const { error: updateError } = await supabase
    .from("profiles")
    .update({
      ...limits,
      paypal_txn_id: txnId,
      plan_activated_at: new Date().toISOString(),
      ai_credits_used: 0,
      thumbnail_credits_used: 0,
    })
    .eq("id", profile.id);

  if (updateError) {
    await sendAlertEmail("❌ SolyntraAI: Plan update failed", {
      userId: profile.id,
      payerEmail,
      plan: planKey,
      error: updateError.message,
      txnId,
    });
    return { statusCode: 200, body: "Update failed — alert sent" };
  }

  // Step 7: Send confirmation email to user
  try {
    const { Resend } = require("resend");
    const resend = new Resend(process.env.RESEND_API_KEY);
    await resend.emails.send({
      from: process.env.RESEND_FROM_EMAIL || "hello@solyntraai.com",
      to: payerEmail,
      subject: `Your SolyntraAI ${planKey.charAt(0).toUpperCase() + planKey.slice(1)} plan is now active 🎉`,
      html: `
        

          
You're on ${planKey.charAt(0).toUpperCase() + planKey.slice(1)}! 🚀

          


            Your payment of ${currency} ${amount} has been received and your plan is now active.
          


          

            

What's unlocked:


            

              
AI credits: ${limits.ai_credits_limit}/mo

              
Thumbnail credits: ${limits.thumbnail_credits_limit}/mo

              
Brands: up to ${limits.brand_limit}

            

          

          
            Go to Dashboard →
          


            Transaction ID: ${txnId}

            Questions? Reply to this email or contact support@solyntraai.com


        
`,
    });
  } catch (emailErr) {
    console.error("Confirmation email failed:", emailErr.message);
  }

  // Step 8: Alert yourself that a plan was activated
  await sendAlertEmail("✅ SolyntraAI: Plan activated successfully", {
    user: payerEmail,
    plan: planKey,
    amount: `${currency} ${amount}`,
    txnId,
  });

  return { statusCode: 200, body: "OK" };
};
