// api/book-verdict.js
// POST {
//   book: { title, author, summary },
//   onboarding_genres: [string]?,
//   read_history: [{ title, author, genres, shelf_placement, why_liked }]?,  // most-recent-first
//   currently_reading: [{ title, still_enjoying_midpoint }]?                 // most-recent-first
// }
// Returns { verdict: "string", recognition: "string" | null, synopsis: "string" }
//
// Deploy target: Vercel. Runtime: Node.js serverless function.
// Env var required: ANTHROPIC_API_KEY (set in Vercel project settings, never in code).
//
// CLAUDE.md decision #37/#39: Stage 1's book detail page. Called once per book
// (decision #37, amended) — whether or not the caller already has a "why this
// fits" reason from Today/Search-rows/Vibe Search, this endpoint always runs
// once so the page can get a Recognition section (decision #39.4) without a
// second AI call. When a reason already exists, the client uses this
// response's `verdict` field for nothing and keeps its own reason — only
// `recognition` gets used. When no reason exists (Search's manual title/
// author/ISBN lookup), both fields are used. `synopsis` (decision #40) is
// always used regardless of whether a prior reason exists — it isn't
// produced by any other entry point, so this is its only source. Client-side
// caching (decision #33) applies to whichever fields actually get used,
// keyed on the reader's finished-book count, so this call only happens once
// per book in practice.

import Anthropic from "@anthropic-ai/sdk";
import { checkRateLimit } from "../lib/rateLimit.js";

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const SYSTEM_PROMPT = `You write three things for Dogear's book detail page, about ONE
specific book, for ONE specific reader:

1. A "verdict" — one specific sentence, written directly to the reader ("you"), on why
   this particular book fits them. Same quality bar as every other reasoning surface in
   this app: no generic praise ("a wonderful read"), name an actual, specific connection
   to their taste profile below. If the reader has no history yet (read_history and
   onboarding_genres both empty), reason from the book itself — its tone, subject, and
   pacing — rather than inventing a fake personal connection.

Reader history uses shelf placement instead of star ratings — treat these as the real
signal, not a proxy for one:
- "keepForever" = their strongest possible endorsement, weight heavily.
- "gladIReadIt" = solid but not formative — mild positive signal.
- "shouldveStopped" = a real negative signal (they regret finishing it) — actively avoid
  implying this book resembles whatever soured them on that one.
A book currently being read with "still_enjoying_midpoint": false is an early warning —
treat it like a soft negative signal even though it's not finished yet.
read_history and currently_reading are ordered most-recent-first — weight recent shelf
placements more heavily than old ones, and follow a recent trend over the historical
average if the reader's taste is visibly shifting.

2. A "recognition" — a short, objective, factual note (not personal to the reader,
   unlike the verdict) on what makes this book notable or distinctive: awards, major
   adaptations, cultural impact, a distinctive structural or stylistic claim to fame.
   Honest constraint: you only have the book's summary/description text to work with,
   not a structured awards database. Extract or note recognition ONLY when it's
   genuinely evidenced in the summary text provided (e.g. the summary literally
   mentions a prize, a bestseller status, a film adaptation, "the first novel to...").
   NEVER invent or infer an award or accolade that isn't actually there in the text.
   If the summary contains nothing like this, return null for recognition — an absent
   section is correct and expected for most books, not a failure. A book being old
   enough to predate a prize that didn't exist yet (e.g. a 1920s novel and the modern
   Pulitzer fiction category) is not evidence of anything — just leave recognition null,
   don't reach for a weaker substitute claim to fill the space.

3. A "synopsis" — a clean, readable synopsis of the book itself, not personal to the
   reader. Target length: 3-4 sentences, roughly 60-90 words — consistent enough that
   every book's detail page feels like it belongs to the same app, not wildly varying
   in length book to book. The raw description text you're given (sourced from Google
   Books or Open Library) is frequently messy: marketing copy ("An instant #1
   bestseller!"), plain-text award badges ("PULITZER PRIZE WINNER"), leftover HTML
   fragments, or pull-quote review blurbs standing in for an actual description.
   Rewrite it into calm, plain prose describing what the book is actually about — strip
   marketing language, HTML, review quotes, and all-caps award callouts (recognition
   facts belong in the "recognition" field above, not repeated here).
   Source text only — same standard already locked for Recognition, now applied here
   too: base the synopsis SOLELY on the raw description text provided (plus the book's
   own title/author/genre for framing). Do NOT draw on any background or outside
   knowledge you may separately have about this book from training — even if you
   recognize the title and know accurate plot details, style, structure, or narrative
   voice, do not add anything that isn't actually evidenced in the source text given to
   you. This applies even when the added detail would be true — the risk being guarded
   against is that for an obscure book you don't actually know, the same move produces
   an unverifiable, confidently-stated hallucination with nothing in the request to
   catch it, so the rule has to be "source text only," not "only add true things."
   Self-check before answering: for every sentence you're about to write, point to the
   specific words or phrases in the provided source text that it restates or closely
   paraphrases. If a sentence names a narrative technique, point of view, structure,
   format, setting detail, or any other specific fact that ISN'T actually named in that
   source text, delete that sentence — that kind of added specificity is exactly the
   signature of background knowledge leaking in rather than the source, even when it's
   true. Concretely: if the source text is one short sentence like "A group of friends
   navigate loss and memory in a small coastal town," a compliant synopsis stays at
   that same level of detail — it does NOT add the number of characters, their names,
   the narrative point of view, or thematic analysis, even if you happen to know all of
   that about the real book. Write 1-2 sentences reflecting exactly what's given, then
   stop, rather than layering in unsourced specifics to reach the target length.
   If the raw description is too sparse to responsibly reach 60-90 words on its own,
   write a shorter, accurate synopsis instead rather than padding it out with anything
   not in that text. If you genuinely have nothing to go on at all, an empty string is
   correct and expected, not a failure. A short honest synopsis grounded only in the
   source text always beats a longer one that reaches beyond it — a thin synopsis is
   correct behavior on a thin source, not a shortcoming to engineer around.

Return ONLY valid JSON matching this exact shape, nothing else — no markdown fences,
no preamble:
{
  "verdict": "string",
  "recognition": "string or null",
  "synopsis": "string"
}`;

// See vibe-search.js for the fuller rationale — protects against Claude
// occasionally prefacing the JSON with commentary despite being told not to.
// Also strips trailing commas before a closing brace/bracket — observed live
// while testing decision #40's synopsis field: with three fields to close
// out instead of two, Claude occasionally left a trailing comma after the
// last one (valid in JS, not in strict JSON), which failed JSON.parse
// outright and threw away an otherwise well-formed response. Applied to
// recommend.js/vibe-search.js's copies of this same helper too, proactively
// — same latent risk, same shared pattern, no reason to wait for a third
// occurrence of this exact bug class in a sibling file.
function extractJSON(raw) {
  const trimmed = raw.trim();
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start === -1 || end === -1 || end < start) return trimmed;
  return trimmed.slice(start, end + 1).replace(/,(\s*[}\]])/g, "$1");
}

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "POST only" });
  }

  if (req.headers["x-app-secret"] !== process.env.APP_SHARED_SECRET) {
    return res.status(401).json({ error: "unauthorized" });
  }

  // LAUNCH-ROADMAP.md Stage 3: basic per-device cost/abuse safety net.
  const rateLimit = await checkRateLimit(req.headers["x-device-id"]);
  if (!rateLimit.allowed) {
    return res.status(429).json({ error: "rate limit exceeded", limit: rateLimit.limit });
  }

  const { book, onboarding_genres, read_history, currently_reading } = req.body ?? {};
  if (!book?.title) {
    return res.status(400).json({ error: "book.title is required" });
  }

  const userContent = JSON.stringify(
    {
      book: {
        title: book.title,
        author: book.author ?? "Unknown",
        summary: book.summary ?? null,
      },
      onboarding_genres: onboarding_genres ?? [],
      read_history: read_history ?? [],
      currently_reading: currently_reading ?? [],
      note: "read_history and currently_reading are ordered most-recent-first.",
    },
    null,
    2
  );

  try {
    const msg = await anthropic.messages.create({
      model: "claude-sonnet-5",
      // Decision #40 added a third field (synopsis) to this call. Decision
      // #35 already hit max_tokens truncation twice on other endpoints when
      // output grew — bumped from 600 to leave real headroom rather than
      // wait to discover truncation via a bad response.
      max_tokens: 1000,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: userContent }],
    });

    const raw = msg.content.find((b) => b.type === "text")?.text ?? "{}";
    let parsed;
    try {
      parsed = JSON.parse(extractJSON(raw));
    } catch (parseErr) {
      console.error("Failed to parse book-verdict response:", parseErr.message, "raw:", raw);
      throw parseErr;
    }

    return res.status(200).json({
      verdict: parsed.verdict ?? "",
      recognition: parsed.recognition ?? null,
      synopsis: parsed.synopsis ?? "",
    });
  } catch (err) {
    console.error("book-verdict error:", err);
    return res.status(500).json({ error: "verdict generation failed" });
  }
}
