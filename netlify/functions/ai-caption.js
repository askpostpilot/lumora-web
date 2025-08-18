exports.handler = async (event) => {
  if (event.httpMethod !== "POST")
    return { statusCode: 405, body: JSON.stringify({ error: "Method not allowed" }) };

  try {
    const { context, platform, tone } = JSON.parse(event.body || "{}");
    if (!context)
      return {
        statusCode: 400,
        body: JSON.stringify({ error: "context is required" }),
      };

    const platformRules = {
      instagram: "Max 2200 chars. Use 3-5 emojis. Add hashtags at end.",
      linkedin: "Max 3000 chars. Professional tone. No hashtags in body.",
      twitter: "Max 280 chars. Punchy. 1-2 hashtags max.",
      tiktok: "Max 2200 chars. Casual, trendy, Gen-Z friendly. 3-5 hashtags.",
      facebook: "Conversational. No char limit. Can be longer.",
      threads: "Max 500 chars. Casual. Like a thought or conversation starter.",
      youtube: "Max 5000 chars. Include keywords for SEO. Describe video.",
      pinterest: "Max 500 chars. Descriptive. Include keywords.",
      telegram: "Max 4096 chars. Can use markdown *bold* _italic_.",
      x: "Max 280 chars. Punchy. 1-2 hashtags max.",
    };

    const toneMap = {
      professional: "professional and authoritative",
      casual: "casual and friendly",
      funny: "witty and humorous",
      inspiring: "motivational and inspiring",
      educational: "informative and educational",
    };

    const platformInstruction = platformRules[platform] || "Max 2200 chars. Engaging.";
    const toneInstruction = toneMap[tone] || "engaging and natural";

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        max_tokens: 400,
        messages: [
          {
            role: "system",
            content: `You write social media captions. Be ${toneInstruction}.
Platform rules: ${platformInstruction}
Return ONLY the caption text. No explanations, no "Here's your caption:", nothing extra.`,
          },
          {
            role: "user",
            content: `Write a caption for: ${context}`,
          },
        ],
      }),
    });

    const data = await response.json();
    if (!response.ok) throw new Error(data.error?.message || "OpenAI error");

    const caption = data.choices?.[0]?.message?.content?.trim();
    if (!caption) throw new Error("Empty response from OpenAI");

    return {
      statusCode: 200,
      body: JSON.stringify({ caption }),
    };
  } catch (err) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: err.message }),
    };
  }
};
