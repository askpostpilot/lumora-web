-- ============================================================
-- FEATURES EXPANSION SCHEMA — run in Supabase SQL Editor
-- ============================================================

-- 1. HASHTAG SAVED SETS
CREATE TABLE IF NOT EXISTS public.hashtag_sets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  brand_id UUID REFERENCES public.brands(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  hashtags TEXT[] NOT NULL DEFAULT '{}',
  platform TEXT,
  use_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.hashtag_sets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "own hashtag sets" ON public.hashtag_sets;
CREATE POLICY "own hashtag sets" ON public.hashtag_sets
  FOR ALL USING (auth.uid() = user_id);

-- 2. CAPTION TEMPLATES
CREATE TABLE IF NOT EXISTS public.caption_templates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  category TEXT NOT NULL,
  title TEXT NOT NULL,
  template TEXT NOT NULL,
  platforms TEXT[] DEFAULT '{}',
  is_system BOOLEAN DEFAULT TRUE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  use_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.caption_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "read system templates" ON public.caption_templates;
DROP POLICY IF EXISTS "manage own templates" ON public.caption_templates;
CREATE POLICY "read system templates" ON public.caption_templates
  FOR SELECT USING (is_system = TRUE OR auth.uid() = user_id);
CREATE POLICY "manage own templates" ON public.caption_templates
  FOR ALL USING (auth.uid() = user_id);

-- 3. EVERGREEN CONTENT QUEUE
CREATE TABLE IF NOT EXISTS public.evergreen_queue (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  brand_id UUID REFERENCES public.brands(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  posts JSONB DEFAULT '[]',
  platforms TEXT[] DEFAULT '{}',
  repeat_every_days INTEGER DEFAULT 7,
  next_post_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.evergreen_queue ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "own evergreen" ON public.evergreen_queue;
CREATE POLICY "own evergreen" ON public.evergreen_queue
  FOR ALL USING (auth.uid() = user_id);

-- 4. LINK IN BIO PAGES
CREATE TABLE IF NOT EXISTS public.bio_pages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  brand_id UUID REFERENCES public.brands(id) ON DELETE CASCADE,
  slug TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  bio TEXT,
  avatar_url TEXT,
  background_color TEXT DEFAULT '#0d1420',
  accent_color TEXT DEFAULT '#00d4ff',
  links JSONB DEFAULT '[]',
  social_links JSONB DEFAULT '{}',
  show_latest_post BOOLEAN DEFAULT TRUE,
  is_active BOOLEAN DEFAULT TRUE,
  view_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.bio_pages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "own bio pages" ON public.bio_pages;
DROP POLICY IF EXISTS "public bio pages read" ON public.bio_pages;
CREATE POLICY "own bio pages" ON public.bio_pages
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "public bio pages read" ON public.bio_pages
  FOR SELECT USING (is_active = TRUE);

-- 5. STREAK TRACKING (add to profiles)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS streak_days INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS longest_streak INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_post_date DATE,
  ADD COLUMN IF NOT EXISTS total_ideas_generated INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_captions_generated INTEGER DEFAULT 0;

-- 6. WELCOME EMAIL TRACKING
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS welcome_email_day INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS welcome_email_sent_at TIMESTAMPTZ;

-- 7. HASHTAG USE COUNTER RPC
CREATE OR REPLACE FUNCTION public.increment_hashtag_use(set_id UUID)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.hashtag_sets
  SET use_count = COALESCE(use_count, 0) + 1, updated_at = NOW()
  WHERE id = set_id AND auth.uid() = user_id;
$$;

GRANT EXECUTE ON FUNCTION public.increment_hashtag_use(UUID) TO authenticated;

-- Public bio page view counter (anon-safe)
CREATE OR REPLACE FUNCTION public.increment_bio_page_views(p_slug TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.bio_pages
  SET view_count = COALESCE(view_count, 0) + 1
  WHERE slug = p_slug AND is_active = TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.increment_bio_page_views(TEXT) TO anon, authenticated;

-- 8. SYSTEM CAPTION TEMPLATES — Pre-populate (idempotent)
INSERT INTO public.caption_templates
  (category, title, template, platforms, is_system) VALUES

('motivation', 'Monday Motivation',
'Every expert was once a beginner. 💪

The only way to fail is to never start. Take that first step today — your future self will thank you.

What''s one thing you''re starting this week? Drop it in the comments 👇

{hashtags}',
ARRAY['instagram','linkedin','facebook'], TRUE),

('motivation', 'Mindset Shift',
'Stop waiting for the perfect moment. 🚀

The perfect moment is now.
The perfect tool is what you have.
The perfect version of you is the one who starts.

Save this for the days you need a reminder. ✨

{hashtags}',
ARRAY['instagram','threads','linkedin'], TRUE),

('product_launch', 'New Feature Announcement',
'Big news! 🎉 We just launched [FEATURE NAME].

Here''s what it means for you:
→ [Benefit 1]
→ [Benefit 2]
→ [Benefit 3]

Try it now — link in bio. 👆

{hashtags}',
ARRAY['instagram','linkedin','facebook','twitter'], TRUE),

('product_launch', 'Before & After',
'Before [PRODUCT/SERVICE]: [pain point] 😩
After [PRODUCT/SERVICE]: [transformation] 🙌

This is what we do for our clients every single day.

Ready for your transformation? DM us or link in bio.

{hashtags}',
ARRAY['instagram','facebook','linkedin'], TRUE),

('behind_scenes', 'Day in the Life',
'A day in the life of [YOUR ROLE] 👀

6am: [activity]
9am: [activity]
12pm: [activity]
3pm: [activity]
6pm: [activity]

The reality of building [BRAND/BUSINESS]. Not always glamorous, always worth it. 💼

{hashtags}',
ARRAY['instagram','tiktok','linkedin'], TRUE),

('behind_scenes', 'The Making Of',
'Ever wondered how we [create/make/do] this? 🎬

Here''s a behind-the-scenes look at our process:

Step 1: [step]
Step 2: [step]
Step 3: [step]

The details most people never see. What surprised you most? 👇

{hashtags}',
ARRAY['instagram','youtube','linkedin'], TRUE),

('engagement', 'This or That',
'Help us decide! 🤔

[Option A] 🔵 or [Option B] 🔴?

Comment A or B below — we''re actually listening and your vote counts!

{hashtags}',
ARRAY['instagram','facebook','threads'], TRUE),

('engagement', 'Question of the Day',
'Real question for my community 💭

[YOUR QUESTION]?

I''ll start: [YOUR ANSWER]

Drop yours in the comments — I read every single one. 👇

{hashtags}',
ARRAY['instagram','linkedin','threads','twitter'], TRUE),

('educational', 'X Tips Format',
'[NUMBER] things I wish I knew about [TOPIC] earlier 📚

1. [tip]
2. [tip]
3. [tip]
4. [tip]
5. [tip]

Save this post — you''ll need it. Which one surprised you most?

{hashtags}',
ARRAY['instagram','linkedin','twitter','threads'], TRUE),

('educational', 'Myth vs Fact',
'MYTH: [common misconception] ❌
FACT: [the truth] ✅

So many people get this wrong. Here''s what actually works:

[Brief explanation in 2-3 lines]

Share this with someone who needs to hear it. 👇

{hashtags}',
ARRAY['instagram','linkedin','facebook'], TRUE),

('testimonial', 'Client Win',
'Client result we''re incredibly proud of 🏆

[Client/Name] came to us with [problem].

After working together:
✅ [Result 1]
✅ [Result 2]
✅ [Result 3]

This is why we do what we do.

Want results like this? Link in bio. 👆

{hashtags}',
ARRAY['instagram','linkedin','facebook'], TRUE);
