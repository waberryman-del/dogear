// backend/lib/rateLimit.js
//
// LAUNCH-ROADMAP.md Stage 3: basic cost/abuse safety net for the 5
// Anthropic-calling endpoints (recommend.js, vibe-search.js, daily-picks.js,
// book-verdict.js, why-liked-it.js). book-search.js is deliberately excluded
// — it never calls Anthropic (Google Books/Open Library only), so it isn't
// a cost risk.
//
// Backed by Upstash Redis because this backend otherwise has zero
// persistent storage — an in-memory counter would not actually work as a
// real limit under real concurrent load: Vercel can and will run multiple
// separate instances of the same function, each with its own memory, so a
// per-instance count is not a real cross-request limit, and instances get
// recycled/cold-started, silently zeroing any in-memory count anyway.
//
// Using `@upstash/redis` directly rather than `@vercel/kv`: as of this
// writing `@vercel/kv` prints its own deprecation warning on install
// ("Vercel KV is deprecated... moved to Upstash Redis") — it's a thin
// wrapper around the exact same Upstash REST API, no longer maintained
// going forward. Pointed at the same env var names Vercel's KV/Upstash
// dashboard integration injects either way, so this works whether the
// store shows up as "KV" or "Upstash" in the dashboard.
//
// Lives outside `api/` on purpose — anything under `api/` is auto-routed by
// Vercel as its own endpoint; this is a shared helper, not a route.
//
// Env vars (auto-populated by the Vercel dashboard integration, already
// provisioned): KV_REST_API_URL, KV_REST_API_TOKEN.

import { Redis } from "@upstash/redis";

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});

const WINDOW_SECONDS = 24 * 60 * 60; // 1 day
const MAX_REQUESTS_PER_WINDOW = 50;

// Requests with no device ID (an old client build, or a malformed request)
// share one bucket rather than bypassing the limit entirely — keeps "just
// omit the header" from trivially defeating this, without hard-failing
// genuinely old clients that don't send the header yet.
const UNKNOWN_DEVICE_KEY = "unknown-device";

/**
 * Increments and checks a per-device request count for the current
 * WINDOW_SECONDS window. Fails OPEN, not closed: if KV isn't reachable
 * (not yet provisioned, transient error), the request is allowed through
 * rather than taking every endpoint down over the safety net itself. Logged
 * clearly so it's visible in Vercel's own logs (Stage 3 also wants basic
 * error visibility there, and this is exactly the kind of thing worth
 * knowing happened even though it didn't block anyone).
 *
 * @param {string | undefined} deviceId - value of the `X-Device-ID` header.
 * @returns {Promise<{ allowed: boolean, count: number, limit: number }>}
 */
export async function checkRateLimit(deviceId) {
  const key = `ratelimit:${deviceId || UNKNOWN_DEVICE_KEY}`;
  try {
    const count = await redis.incr(key);
    if (count === 1) {
      // Only the request that actually creates the key sets its expiry —
      // otherwise every subsequent call would keep pushing the window back
      // out and the limit would never actually reset.
      await redis.expire(key, WINDOW_SECONDS);
    }
    return { allowed: count <= MAX_REQUESTS_PER_WINDOW, count, limit: MAX_REQUESTS_PER_WINDOW };
  } catch (err) {
    console.error("[rateLimit] KV unavailable, failing open:", err?.message);
    return { allowed: true, count: 0, limit: MAX_REQUESTS_PER_WINDOW };
  }
}
