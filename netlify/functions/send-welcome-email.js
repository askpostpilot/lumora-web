const { Resend } = require("resend");

exports.handler = async (event) => {
  if (event.httpMethod !== "POST")
    return { statusCode: 405, body: JSON.stringify({ error: "Method not allowed" }) };

  try {
    const { email, name, day = 1 } = JSON.parse(event.body || "{}");
    if (!email) return { statusCode: 400, body: JSON.stringify({ error: "email required" }) };

    const resend = new Resend(process.env.RESEND_API_KEY);
    const from = process.env.RESEND_FROM_EMAIL || "hello@solyntraai.com";

    const emails = {
      1: {
        subject: `Welcome to SolyntraAI, ${name || "Creator"}! 🚀`,
        html: `
          <div style="font-family:sans-serif;max-width:600px;margin:0 auto;color:#f0f4f8;background:#0d1420;padding:40px;border-radius:16px">
            <h1 style="color:#00d4ff;font-size:24px;margin-bottom:16px">You're in! 🎉</h1>
            <p style="color:#8899aa;line-height:1.7;margin-bottom:20px">
              Welcome to SolyntraAI. You've just unlocked the fastest way to plan, create, and schedule your social media content.
            </p>
            <h3 style="color:#f0f4f8;margin-bottom:12px">Start here:</h3>
            <ul style="color:#8899aa;line-height:2">
              <li>📅 <a href="https://solyntraai.com/scheduler.html" style="color:#00d4ff">Open the Scheduler</a> — plan your first post</li>
              <li>🤖 Try AI captions — click "Generate Caption" in the scheduler</li>
              <li>🖼️ Generate a thumbnail with DALL-E 3</li>
              <li>💡 Get post ideas from your Dashboard</li>
            </ul>
            <p style="color:#8899aa;margin-top:24px">
              Any questions? Reply to this email — we read every one.<br>
              <span style="color:#00d4ff">— The SolyntraAI Team</span>
            </p>
          </div>`,
      },
      3: {
        subject: `Did you know you can schedule a year of content in 30 minutes? ⚡`,
        html: `
          <div style="font-family:sans-serif;max-width:600px;margin:0 auto;color:#f0f4f8;background:#0d1420;padding:40px;border-radius:16px">
            <h2 style="color:#00d4ff">Pro tip: Bulk scheduling 📅</h2>
            <p style="color:#8899aa;line-height:1.7">
              Most creators waste 2+ hours per week scheduling posts one by one.<br><br>
              With SolyntraAI's <strong style="color:#f0f4f8">CSV bulk import</strong>, upload 50 posts at once — dates, captions, platforms, all set automatically.
            </p>
            <a href="https://solyntraai.com/scheduler.html"
               style="display:inline-block;margin-top:20px;padding:12px 24px;background:linear-gradient(135deg,#00d4ff,#7b61ff);color:#fff;border-radius:8px;text-decoration:none;font-weight:500">
              Try Bulk Scheduling →
            </a>
            <p style="color:#445566;font-size:12px;margin-top:24px">
              You're receiving this because you signed up for SolyntraAI.
              <a href="https://solyntraai.com/unsubscribe" style="color:#445566">Unsubscribe</a>
            </p>
          </div>`,
      },
      7: {
        subject: `Your first week with SolyntraAI 🌟`,
        html: `
          <div style="font-family:sans-serif;max-width:600px;margin:0 auto;color:#f0f4f8;background:#0d1420;padding:40px;border-radius:16px">
            <h2 style="color:#00d4ff">One week in! How's it going? 🎯</h2>
            <p style="color:#8899aa;line-height:1.7">
              Here are 3 features most users discover in week 2 that change everything:
            </p>
            <div style="background:#111827;border-radius:12px;padding:20px;margin:20px 0">
              <p style="color:#f0f4f8;margin:0 0 8px"><strong>💡 Content Ideas Generator</strong></p>
              <p style="color:#8899aa;margin:0">Never stare at a blank screen again. Dashboard → "Get Ideas"</p>
            </div>
            <div style="background:#111827;border-radius:12px;padding:20px;margin:20px 0">
              <p style="color:#f0f4f8;margin:0 0 8px"><strong>⏰ Best Time to Post</strong></p>
              <p style="color:#8899aa;margin:0">Platform-specific timing suggestions built into the scheduler</p>
            </div>
            <div style="background:#111827;border-radius:12px;padding:20px;margin:20px 0">
              <p style="color:#f0f4f8;margin:0 0 8px"><strong>📊 Deep Analytics with Zynera</strong></p>
              <p style="color:#8899aa;margin:0">
                <a href="https://zynera.cloud" style="color:#00d4ff">Zynera.cloud</a> — see exactly what content performs best
              </p>
            </div>
            <p style="color:#445566;font-size:12px;margin-top:24px">
              <a href="https://solyntraai.com/unsubscribe" style="color:#445566">Unsubscribe</a>
            </p>
          </div>`,
      },
    };

    const emailContent = emails[day];
    if (!emailContent) return { statusCode: 400, body: JSON.stringify({ error: "Invalid day" }) };

    await resend.emails.send({
      from,
      to: email,
      subject: emailContent.subject,
      html: emailContent.html,
    });

    return { statusCode: 200, body: JSON.stringify({ ok: true, day }) };
  } catch (err) {
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }
};
