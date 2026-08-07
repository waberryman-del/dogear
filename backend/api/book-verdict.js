// api/book-verdict.js
// POST {
//   book: { title, author, summary },
//   onboarding_genres: [string]?,
//   read_history: [{ title, author, genres, shelf_placement, why_liked }]?,  // most-recent-first
//   currently_reading: [{ title, still_enjoying_midpoint }]?                 // most-recent-first
// }
// Returns { verdict: "string", recognition: "string" | null }
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
// author/ISBN lookup), both fields are used. Client-side caching (decision
// #33) applies to whichever fields actually get used, keyed on the reader's
// finished-book count, so this call only happens once per book in practice.

import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const SYSTEM_PROMPT = `You write two things for Dogear's book detail page, about ONE
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
   section is correct and expected for most books, not a failure.

Return ONLY valid JSON matching this exact shape, nothing else — no markdown fences,
no preamble:
{
  "verdict": "string",
  "recognition": "string or null"
}`;

// See vibe-search.js for the fuller rationale — protects against Claude
// occasionally prefacing the JSON with commentary despite being told not to.
function extractJSON(raw) {
  const trimmed = raw.trim();
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start === -1 || end === -1 || end < start) return trimmed;
  return trimmed.slice(start, end + 1);
}

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "POST only" });
  }

  if (req.headers["x-app-secret"] !== process.env.APP_SHARED_SECRET) {
    return res.status(401).json({ error: "unauthorized" });
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
      max_tokens: 600,
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
    });
  } catch (err) {
    console.error("book-verdict error:", err);
    return res.status(500).json({ error: "verdict generation failed" });
  }
}
