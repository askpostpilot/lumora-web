exports.handler = async (event) => {
  if (event.httpMethod !== "POST")
    return { statusCode: 405, body: JSON.stringify({ error: "Method not allowed" }) };

  try {
    const { prompt, style } = JSON.parse(event.body || "{}");
    if (!prompt)
      return {
        statusCode: 400,
        body: JSON.stringify({ error: "prompt is required" }),
      };

    const styleMap = {
      professional: "clean, professional, corporate style, minimal text",
      vibrant: "vibrant colors, eye-catching, social media optimized",
      minimal: "minimalist, white background, clean design",
      dark: "dark moody aesthetic, dramatic lighting",
      lifestyle: "lifestyle photography style, natural, authentic",
    };

    const styleNote = styleMap[style] || "professional, social media optimized";

    const fullPrompt = [
      `Social media thumbnail image for: ${prompt}.`,
      `Style: ${styleNote}.`,
      "No text overlay. No watermarks. High quality.",
      "Aspect ratio friendly for social media posting.",
      "Photorealistic or clean graphic design.",
    ].join(" ");

    const response = await fetch("https://api.openai.com/v1/images/generations", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "dall-e-3",
        prompt: fullPrompt,
        n: 1,
        size: "1024x1024",
        quality: "standard",
        response_format: "url",
      }),
    });

    const data = await response.json();
    if (!response.ok) throw new Error(data.error?.message || "DALL-E error");

    const imageUrl = data.data?.[0]?.url;
    if (!imageUrl) throw new Error("No image returned");

    return {
      statusCode: 200,
      body: JSON.stringify({
        imageUrl,
        expiresIn: "1 hour — download immediately",
      }),
    };
  } catch (err) {
    if (String(err.message).includes("content_policy")) {
      return {
        statusCode: 422,
        body: JSON.stringify({
          error: "Prompt was rejected by content policy. Try a different description.",
        }),
      };
    }
    return {
      statusCode: 500,
      body: JSON.stringify({ error: err.message }),
    };
  }
};
