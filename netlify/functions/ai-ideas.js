exports.handler = async (event) => {
  if (event.httpMethod !== "POST")
    return { statusCode: 405, body: JSON.stringify({ error: "Method not allowed" }) };

  try {
    const { niche, platform, count = 5 } = JSON.parse(event.body || "{}");
    if (!niche)
      return {
        statusCode: 400,
        body: JSON.stringify({ error: "niche is required" }),
      };

    const platformContext = platform ? `optimized for ${platform}` : "suitable for any social media platform";

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        max_tokens: 600,
        messages: [
          {
            role: "system",
            content: `You generate creative, engaging social media post ideas.
Return ONLY a JSON array of ${count} ideas. No markdown, no explanation.
Format: [{"title": "short title", "hook": "opening line", "type": "educational|entertaining|promotional|engagement"}]`,
          },
          {
            role: "user",
            content: `Generate ${count} fresh post ideas for a ${niche} brand/creator, ${platformContext}.`,
          },
        ],
      }),
    });

    const data = await response.json();
    if (!response.ok) throw new Error(data.error?.message || "OpenAI error");

    const raw = data.choices?.[0]?.message?.content?.trim();
    const clean = raw.replace(/```json|```/g, "").trim();
    const ideas = JSON.parse(clean);

    return {
      statusCode: 200,
      body: JSON.stringify({ ideas }),
    };
  } catch (err) {
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }
};
