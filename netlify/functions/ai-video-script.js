exports.handler = async (event) => {
  if (event.httpMethod !== "POST")
    return { statusCode: 405, body: JSON.stringify({ error: "Method not allowed" }) };

  try {
    const { topic, duration = 60, platform = "instagram", tone = "casual" } = JSON.parse(event.body || "{}");

    if (!topic)
      return {
        statusCode: 400,
        body: JSON.stringify({ error: "topic is required" }),
      };

    const platformGuide =
      {
        instagram: "Instagram Reel — hook in first 3 seconds, visual cues, trending",
        tiktok: "TikTok — very casual, Gen-Z friendly, jump cuts, trending sounds",
        youtube: "YouTube Short — educational, clear value, subscribe CTA at end",
        linkedin: "LinkedIn video — professional, story-driven, business value",
      }[platform] || "short-form social media video";

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        max_tokens: 800,
        messages: [
          {
            role: "system",
            content: `You write engaging video scripts for ${platformGuide}.
Tone: ${tone}. Duration: ~${duration} seconds.
Format the script with: [HOOK], [MAIN CONTENT], [CTA]
Include speaking notes and visual direction in brackets.`,
          },
          {
            role: "user",
            content: `Write a ${duration}-second video script about: ${topic}`,
          },
        ],
      }),
    });

    const data = await response.json();
    if (!response.ok) throw new Error(data.error?.message || "OpenAI error");

    const script = data.choices?.[0]?.message?.content?.trim();
    return { statusCode: 200, body: JSON.stringify({ script }) };
  } catch (err) {
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }
};
