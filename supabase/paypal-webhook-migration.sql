-- Run this in Supabase SQL Editor before activating the webhook
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS paypal_txn_id text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS plan_activated_at timestamptz;
