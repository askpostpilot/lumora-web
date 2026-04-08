// supabase.js — SolyntraAI complete client
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";

const SUPABASE_URL = window.SUPABASE_URL || "PASTE_YOUR_URL";
const SUPABASE_ANON_KEY = window.SUPABASE_ANON_KEY || "PASTE_YOUR_KEY";
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ─── AUTH ──────────────────────────────────────────────────

export async function signup(email, password, fullName) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: { data: { full_name: fullName || email.split("@")[0] } },
  });
  if (error) throw error;
  return data;
}

export async function login(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

const DEFAULT_ORIGIN = typeof window !== "undefined" ? window.location.origin : "https://solyntraai.com";

export async function loginWithGoogle(redirectTo = `${DEFAULT_ORIGIN}/dashboard.html`) {
  const { error } = await supabase.auth.signInWithOAuth({
    provider: "google",
    options: { redirectTo },
  });
  if (error) throw error;
}

export async function loginWithGitHub(redirectTo = `${DEFAULT_ORIGIN}/dashboard.html`) {
  const { error } = await supabase.auth.signInWithOAuth({
    provider: "github",
    options: { redirectTo },
  });
  if (error) throw error;
}

export async function logout() {
  await supabase.auth.signOut();
  window.location.href = "/index.html";
}

export async function resetPassword(email) {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: "https://solyntraai.com/reset-password.html",
  });
  if (error) throw error;
}

export async function getUser() {
  const { data } = await supabase.auth.getUser();
  return data?.user || null;
}

export async function requireAuth(redirect = "/login.html") {
  const user = await getUser();
  if (!user) {
    window.location.href = redirect;
    return null;
  }
  return user;
}

// ─── PROFILE ───────────────────────────────────────────────

export async function getProfile(userId) {
  const { data, error } = await supabase.from("profiles").select("*").eq("id", userId).single();
  if (error) throw error;
  return data;
}

export async function updateProfile(userId, updates) {
  const { data, error } = await supabase.from("profiles").update(updates).eq("id", userId).select().single();
  if (error) throw error;
  return data;
}

export async function isAdmin(userId) {
  const { data } = await supabase.from("profiles").select("is_admin").eq("id", userId).single();
  return data?.is_admin === true;
}

// ─── PLAN GATES ────────────────────────────────────────────

export async function checkLimit(userId, type) {
  const profile = await getProfile(userId);
  if (profile?.is_admin || profile?.payment_bypass) return { allowed: true, remaining: 9999 };

  if (type === "ai_credits") {
    const rem = (profile.ai_credits_limit || 10) - (profile.ai_credits_used || 0);
    return { allowed: rem > 0, remaining: rem, limit: profile.ai_credits_limit };
  }
  if (type === "thumbnail_credits") {
    const rem = (profile.thumbnail_credits_limit || 0) - (profile.thumbnail_credits_used || 0);
    return { allowed: rem > 0, remaining: rem, limit: profile.thumbnail_credits_limit };
  }
  if (type === "brands") {
    const { count } = await supabase.from("brands").select("*", { count: "exact", head: true }).eq("user_id", userId).eq("is_active", true);
    const rem = (profile.brand_limit || 1) - (count || 0);
    return { allowed: rem > 0, remaining: rem, limit: profile.brand_limit };
  }
  if (type === "queue") {
    const { count } = await supabase.from("posts").select("*", { count: "exact", head: true }).eq("user_id", userId).eq("status", "scheduled");
    const rem = (profile.queue_limit || 10) - (count || 0);
    return { allowed: rem > 0, remaining: rem, limit: profile.queue_limit };
  }
  if (type === "platforms") {
    const { count } = await supabase.from("platform_connections").select("*", { count: "exact", head: true }).eq("user_id", userId).eq("is_active", true);
    const rem = (profile.platform_limit || 2) - (count || 0);
    return { allowed: rem > 0, remaining: rem, limit: profile.platform_limit };
  }
  return { allowed: true, remaining: 99 };
}

/** @deprecated use checkLimit */
export const checkPlanLimit = checkLimit;

// ─── BRANDS ────────────────────────────────────────────────

export async function getBrands(userId) {
  const { data, error } = await supabase
    .from("brands")
    .select("*")
    .eq("user_id", userId)
    .eq("is_active", true)
    .order("created_at", { ascending: true });
  if (error) throw error;
  return data || [];
}

export async function createBrand(userId, name, color = "#7b61ff") {
  const check = await checkLimit(userId, "brands");
  if (!check.allowed) throw new Error(`Brand limit reached (${check.limit}). Upgrade to add more.`);
  const { data, error } = await supabase.from("brands").insert({ user_id: userId, name, color }).select().single();
  if (error) throw error;
  return data;
}

export async function updateBrand(brandId, updates) {
  const { data, error } = await supabase.from("brands").update(updates).eq("id", brandId).select().single();
  if (error) throw error;
  return data;
}

export async function deleteBrand(brandId, userId) {
  const { error } = await supabase.from("brands").update({ is_active: false }).eq("id", brandId).eq("user_id", userId);
  if (error) throw error;
}

// ─── POSTS ─────────────────────────────────────────────────

export async function schedulePost(userId, brandId, postData) {
  const check = await checkLimit(userId, "queue");
  if (!check.allowed) throw new Error(`Queue limit reached (${check.limit}). Upgrade for unlimited.`);
  const { data, error } = await supabase.from("posts").insert({
    user_id: userId,
    brand_id: brandId,
    platform: postData.platform,
    account_handle: postData.accountHandle || "",
    caption: postData.caption,
    image_url: postData.imageUrl || null,
    thumbnail_url: postData.thumbnailUrl || null,
    hashtags: postData.hashtags || [],
    scheduled_at: postData.scheduledAt,
    timezone: postData.timezone || "Asia/Kolkata",
    status: "scheduled",
    ai_generated: postData.aiGenerated || false,
    thumbnail_ai_generated: postData.thumbnailAiGenerated || false,
  }).select().single();
  if (error) throw error;
  return data;
}

export async function saveDraft(userId, brandId, postData) {
  const { data, error } = await supabase.from("posts").insert({
    user_id: userId,
    brand_id: brandId,
    platform: postData.platform || "draft",
    caption: postData.caption || "",
    scheduled_at: new Date(Date.now() + 86400000).toISOString(),
    status: "draft",
    ai_generated: postData.aiGenerated || false,
  }).select().single();
  if (error) throw error;
  return data;
}

export async function getRecentPosts(userId, brandId, limit = 5) {
  let q = supabase.from("posts").select("*").eq("user_id", userId);
  if (brandId) q = q.eq("brand_id", brandId);
  const { data, error } = await q.order("created_at", { ascending: false }).limit(limit);
  if (error) throw error;
  return data || [];
}

export async function getPostsInDateRange(userId, brandId, startIso, endIso) {
  let q = supabase
    .from("posts")
    .select("*")
    .eq("user_id", userId)
    .gte("scheduled_at", startIso)
    .lte("scheduled_at", endIso)
    .order("scheduled_at", { ascending: true });
  if (brandId) q = q.eq("brand_id", brandId);
  const { data, error } = await q;
  if (error) throw error;
  return data || [];
}

export async function deletePost(postId, userId) {
  const { error } = await supabase.from("posts").delete().eq("id", postId).eq("user_id", userId);
  if (error) throw error;
}

// ─── AI CAPTIONS ───────────────────────────────────────────

export async function generateAICaption(userId, context, platform = "instagram", tone = "casual") {
  const check = await checkLimit(userId, "ai_credits");
  if (!check.allowed) throw new Error(`AI credits used up. Resets next month or upgrade for more.`);

  const res = await fetch("/.netlify/functions/ai-caption", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ context, platform, tone }),
  });
  const result = await res.json();
  if (!res.ok) throw new Error(result.error || "AI caption failed");

  await supabase.rpc("increment_ai_credits", { uid: userId });
  const { data: prof } = await supabase.from("profiles").select("total_captions_generated").eq("id", userId).single();
  await supabase
    .from("profiles")
    .update({ total_captions_generated: (prof?.total_captions_generated || 0) + 1 })
    .eq("id", userId);
  return result.caption;
}

// ─── DALL-E THUMBNAILS ─────────────────────────────────────

export async function generateThumbnail(userId, prompt, style = "professional") {
  const check = await checkLimit(userId, "thumbnail_credits");
  if (!check.allowed) throw new Error(`Thumbnail credits used up. Upgrade for more.`);

  const res = await fetch("/.netlify/functions/generate-thumbnail", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ prompt, style }),
  });
  const result = await res.json();
  if (!res.ok) throw new Error(result.error || "Thumbnail generation failed");

  await supabase.rpc("increment_thumbnail_credits", { uid: userId });
  return result.imageUrl;
}

// ─── STATS ─────────────────────────────────────────────────

export async function getUserStats(userId, brandId) {
  const profile = await getProfile(userId);
  let postsQ = supabase.from("posts").select("*", { count: "exact", head: true }).eq("user_id", userId).eq("status", "scheduled");
  if (brandId) postsQ = postsQ.eq("brand_id", brandId);
  const { count: scheduledCount } = await postsQ;

  let totalQ = supabase.from("posts").select("*", { count: "exact", head: true }).eq("user_id", userId);
  if (brandId) totalQ = totalQ.eq("brand_id", brandId);
  const { count: totalPosts } = await totalQ;

  const { count: platformCount } = await supabase
    .from("platform_connections")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("is_active", true);

  const { count: brandCount } = await supabase
    .from("brands")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("is_active", true);

  let postsListQ = supabase.from("posts").select("status").eq("user_id", userId);
  if (brandId) postsListQ = postsListQ.eq("brand_id", brandId);
  const { data: posts } = await postsListQ;

  return {
    scheduledPosts: scheduledCount || 0,
    totalPosts: totalPosts || 0,
    platformsConnected: platformCount || 0,
    hoursSaved: Math.round((totalPosts || 0) * 0.25 * 10) / 10,
    streakDays: profile?.streak_days || 0,
    longestStreak: profile?.longest_streak || 0,
    totalCaptionsGenerated: profile?.total_captions_generated || 0,
    totalIdeasGenerated: profile?.total_ideas_generated || 0,
    brandCount: brandCount || 0,
    plan: profile?.plan || "free",
    fullName: profile?.full_name || "",
    aiCreditsRemaining: (profile?.ai_credits_limit || 10) - (profile?.ai_credits_used || 0),
    thumbnailCreditsRemaining: (profile?.thumbnail_credits_limit || 0) - (profile?.thumbnail_credits_used || 0),
    onboardingComplete: profile?.onboarding_complete || false,
    isAdmin: profile?.is_admin || false,
    brandLimit: profile?.brand_limit || 1,
    draftPosts: posts?.filter(p => p.status === "draft").length ?? 0,
    aiCreditsUsed: profile?.ai_credits_used ?? 0,
  };
}

// ─── ANALYTICS ─────────────────────────────────────────────

export async function getAnalyticsData(userId, brandId) {
  let q = supabase.from("posts").select("platform,status,scheduled_at,created_at").eq("user_id", userId);
  if (brandId) q = q.eq("brand_id", brandId);
  const { data: posts } = await q;

  if (!posts?.length) return {
    totalPosts: 0, topPlatform: null, postsThisMonth: 0, hoursSaved: 0,
    platformBreakdown: {}, statusBreakdown: {}, weeklyActivity: buildEmptyWeek()
  };

  const platformBreakdown = {};
  posts.forEach((p) => {
    if (p.platform) platformBreakdown[p.platform] = (platformBreakdown[p.platform] || 0) + 1;
  });
  const topPlatform = Object.entries(platformBreakdown).sort((a, b) => b[1] - a[1])[0]?.[0];

  const statusBreakdown = {};
  posts.forEach((p) => {
    if (p.status) statusBreakdown[p.status] = (statusBreakdown[p.status] || 0) + 1;
  });

  const som = new Date(); som.setDate(1); som.setHours(0, 0, 0, 0);
  const postsThisMonth = posts.filter((p) => new Date(p.created_at) >= som).length;

  const weeklyActivity = buildEmptyWeek();
  posts.forEach((p) => {
    const d = new Date(p.created_at);
    const entry = weeklyActivity.find(w => w.date === d.toDateString());
    if (entry) entry.count++;
  });

  return {
    totalPosts: posts.length,
    topPlatform,
    postsThisMonth,
    hoursSaved: Math.round(posts.length * 0.25 * 10) / 10,
    platformBreakdown,
    statusBreakdown,
    weeklyActivity,
  };
}

function buildEmptyWeek() {
  const days = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    days.push({ label: d.toLocaleDateString("en-US", { weekday: "short" }), count: 0, date: d.toDateString() });
  }
  return days;
}

// ─── RSS ───────────────────────────────────────────────────

export async function getRssSources(userId, brandId) {
  let q = supabase.from("rss_sources").select("*").eq("user_id", userId).eq("is_active", true);
  if (brandId) q = q.eq("brand_id", brandId);
  const { data } = await q;
  return data || [];
}

export async function addRssSource(userId, brandId, url, platforms) {
  const { data, error } = await supabase
    .from("rss_sources")
    .insert({ user_id: userId, brand_id: brandId, url, platforms: platforms || [], auto_caption: true })
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ─── PLATFORMS (connections) ───────────────────────────────

export async function getConnectedPlatforms(userId, brandId) {
  let q = supabase.from("platform_connections").select("*").eq("user_id", userId).eq("is_active", true);
  if (brandId) q = q.eq("brand_id", brandId);
  const { data, error } = await q;
  if (error) throw error;
  return data || [];
}

// ─── ONBOARDING ────────────────────────────────────────────

export async function saveOnboardingStep(userId, step, data) {
  const updates = { user_id: userId, step_completed: step };
  if (data.platforms) updates.platforms_selected = data.platforms;
  if (data.categories) updates.categories_selected = data.categories;
  if (step >= 3) updates.completed_at = new Date().toISOString();
  const { error } = await supabase.from("onboarding").upsert(updates, { onConflict: "user_id" });
  if (error) throw error;
  if (step >= 3) await updateProfile(userId, { onboarding_complete: true });
}

export async function getOnboardingStatus(userId) {
  const { data } = await supabase.from("onboarding").select("*").eq("user_id", userId).single();
  return data;
}

// ─── HASHTAG SETS ──────────────────────────────────────────

export async function getHashtagSets(userId, brandId) {
  let q = supabase.from("hashtag_sets").select("*").eq("user_id", userId);
  if (brandId) q = q.eq("brand_id", brandId);
  const { data, error } = await q.order("use_count", { ascending: false });
  if (error) throw error;
  return data || [];
}

export async function saveHashtagSet(userId, brandId, name, hashtags, platform) {
  const { data, error } = await supabase
    .from("hashtag_sets")
    .insert({ user_id: userId, brand_id: brandId || null, name, hashtags, platform: platform || null })
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function deleteHashtagSet(id, userId) {
  const { error } = await supabase.from("hashtag_sets").delete().eq("id", id).eq("user_id", userId);
  if (error) throw error;
}

export async function useHashtagSet(id) {
  const { error } = await supabase.rpc("increment_hashtag_use", { set_id: id });
  if (error) throw error;
}

// ─── CAPTION TEMPLATES ─────────────────────────────────────

export async function getCaptionTemplates(category) {
  let q = supabase.from("caption_templates").select("*").eq("is_system", true);
  if (category && category !== "all") q = q.eq("category", category);
  const { data, error } = await q.order("use_count", { ascending: false });
  if (error) throw error;
  return data || [];
}

// ─── EVERGREEN QUEUE ───────────────────────────────────────

export async function getEvergreenQueues(userId, brandId) {
  let q = supabase.from("evergreen_queue").select("*").eq("user_id", userId);
  if (brandId) q = q.eq("brand_id", brandId);
  const { data, error } = await q;
  if (error) throw error;
  return data || [];
}

export async function createEvergreenQueue(userId, brandId, name, posts, platforms, repeatDays) {
  const days = repeatDays || 7;
  const { data, error } = await supabase
    .from("evergreen_queue")
    .insert({
      user_id: userId,
      brand_id: brandId || null,
      name,
      posts: posts || [],
      platforms: platforms || [],
      repeat_every_days: days,
      next_post_at: new Date(Date.now() + days * 86400000).toISOString(),
      is_active: true,
    })
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ─── LINK IN BIO ───────────────────────────────────────────

export async function getBioPage(userId, brandId) {
  let q = supabase.from("bio_pages").select("*").eq("user_id", userId);
  if (brandId) q = q.eq("brand_id", brandId);
  else q = q.is("brand_id", null);
  const { data } = await q.maybeSingle();
  return data;
}

export async function saveBioPage(userId, brandId, pageData) {
  const row = {
    user_id: userId,
    brand_id: brandId || null,
    ...pageData,
    updated_at: new Date().toISOString(),
  };
  const { data, error } = await supabase.from("bio_pages").upsert(row, { onConflict: "slug" }).select().single();
  if (error) throw error;
  return data;
}

export async function getBioPageBySlug(slug) {
  const { data, error } = await supabase.from("bio_pages").select("*").eq("slug", slug).eq("is_active", true).maybeSingle();
  if (error) throw error;
  return data;
}

export async function incrementBioPageViews(slug) {
  const { error } = await supabase.rpc("increment_bio_page_views", { p_slug: slug });
  if (error) console.warn("View count update:", error.message);
}

// ─── STREAK ────────────────────────────────────────────────

export async function updateStreak(userId) {
  const profile = await getProfile(userId);
  const today = new Date().toISOString().split("T")[0];
  const lastPost = profile?.last_post_date;

  let newStreak = 1;
  if (lastPost) {
    const yesterday = new Date(Date.now() - 86400000).toISOString().split("T")[0];
    if (lastPost === yesterday) newStreak = (profile.streak_days || 0) + 1;
    else if (lastPost === today) newStreak = profile.streak_days || 1;
    else newStreak = 1;
  }

  const longestStreak = Math.max(newStreak, profile?.longest_streak || 0);
  await updateProfile(userId, {
    streak_days: newStreak,
    longest_streak: longestStreak,
    last_post_date: today,
  });
  return newStreak;
}

// ─── AI HELPERS (client-side wrappers) ─────────────────────

export async function getContentIdeas(niche, platform, count = 5) {
  const res = await fetch("/.netlify/functions/ai-ideas", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ niche, platform, count }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || "Failed");
  const user = await getUser();
  if (user?.id) {
    const { data: prof } = await supabase.from("profiles").select("total_ideas_generated").eq("id", user.id).single();
    await supabase
      .from("profiles")
      .update({ total_ideas_generated: (prof?.total_ideas_generated || 0) + 1 })
      .eq("id", user.id);
  }
  return data.ideas;
}

export async function generateVideoScript(topic, duration, platform, tone) {
  const res = await fetch("/.netlify/functions/ai-video-script", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ topic, duration, platform, tone }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || "Failed");
  return data.script;
}

// ─── UTILITIES ─────────────────────────────────────────────

export function formatDate(iso) {
  return new Date(iso).toLocaleDateString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function getPlatformIcon(p) {
  const k = p?.toLowerCase();
  return (
    {
      instagram: "📸",
      facebook: "📘",
      x: "🐦",
      twitter: "🐦",
      linkedin: "💼",
      tiktok: "🎵",
      youtube: "▶️",
      pinterest: "📌",
      threads: "🧵",
      telegram: "✈️",
      google_business: "🏢",
    }[k] || "🌐"
  );
}

export function getStatusBadge(status) {
  return (
    {
      scheduled: { label: "Scheduled", color: "#00d4ff" },
      posted: { label: "Posted", color: "#00ff9d" },
      draft: { label: "Draft", color: "#ffb800" },
      failed: { label: "Failed", color: "#ff5e57" },
      cancelled: { label: "Cancelled", color: "#8899aa" },
    }[status] || { label: "Draft", color: "#ffb800" }
  );
}

export function showToast(message, type = "success") {
  if (window.Solyntra?.showToast) {
    window.Solyntra.showToast(message, type);
    return;
  }
  const t = document.createElement("div");
  t.style.cssText = `position:fixed;bottom:2rem;right:2rem;z-index:9999;
    padding:1rem 1.5rem;border-radius:12px;font-weight:500;font-family:sans-serif;
    background:${type === "success" ? "rgba(0,255,157,0.1)" : "rgba(255,94,87,0.1)"};
    border:1px solid ${type === "success" ? "#00ff9d" : "#ff5e57"};
    color:${type === "success" ? "#00ff9d" : "#ff5e57"};
    backdrop-filter:blur(20px);transition:opacity 0.3s;font-size:14px;`;
  t.textContent = message;
  document.body.appendChild(t);
  setTimeout(() => {
    t.style.opacity = "0";
    setTimeout(() => t.remove(), 300);
  }, 3000);
}

export function showUpgradeModal(reason, limit) {
  const lim = limit != null ? limit : "plan";
  const msgs = {
    queue: `You've reached your ${lim}-post queue limit.`,
    platforms: `You've reached your ${lim}-platform limit.`,
    ai_credits: `You've used all your AI caption credits this month.`,
    thumbnail_credits: `You've used all your thumbnail credits this month.`,
    brands: `You've reached your ${lim}-brand limit.`,
  };
  const overlay = document.createElement("div");
  overlay.style.cssText = `position:fixed;inset:0;background:rgba(0,0,0,0.7);
    z-index:9999;display:flex;align-items:center;justify-content:center;`;
  overlay.innerHTML = `
    <div style="background:#111827;border:1px solid rgba(255,255,255,0.1);
      border-radius:16px;padding:32px;max-width:400px;width:90%;text-align:center;">
      <div style="font-size:24px;margin-bottom:12px">⚡</div>
      <h3 style="color:#f0f4f8;margin-bottom:8px;font-size:18px">Upgrade Required</h3>
      <p style="color:#8899aa;margin-bottom:24px;font-size:14px;line-height:1.6">
        ${msgs[reason] || "Upgrade to continue."} Upgrade your plan to unlock more.
      </p>
      <a href="/pricing.html" style="display:inline-block;padding:12px 24px;
        background:linear-gradient(135deg,#00d4ff,#7b61ff);color:#fff;
        border-radius:8px;text-decoration:none;font-weight:500;margin-right:8px;">
        See Plans →
      </a>
      <button type="button" class="upgrade-modal-close" style="padding:12px 24px;background:transparent;color:#8899aa;
        border:1px solid rgba(255,255,255,0.1);border-radius:8px;cursor:pointer;">
        Not now
      </button>
    </div>`;
  document.body.appendChild(overlay);
  overlay.querySelector(".upgrade-modal-close")?.addEventListener("click", () => overlay.remove());
}
