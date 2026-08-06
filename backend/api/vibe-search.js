// api/vibe-search.js
// POST {
//   query: "free text mood/vibe description",
//   refinements: [string]?,             // one-tap refinements already applied, oldest first
//   onboarding_genres: [string]?,
//   read_history: [{ title, author, genres, shelf_placement, why_liked }]?,  // most-recent-first
//   currently_reading: [{ title, still_enjoying_midpoint }]?,                // most-recent-first
//   shown_books: [string]?              // "Title by Author" exclusion list
// }
// Returns { results: [{ book: {...}, reason, confidence }], refinements: [string] }
//
// Deploy target: Vercel. Runtime: Node.js serverless function.
// Env var required: ANTHROPIC_API_KEY (set in Vercel project settings, never in code).

import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// See recommend.js for the fuller rationale — bounded concurrency instead of
// blasting Google Books with every lookup at once or running them serially.
const LOOKUP_CONCURRENCY = 5;

async function mapWithConcurrency(items, limit, mapper) {
  const results = new Array(items.length);
  let nextIndex = 0;
  async function worker() {
    while (nextIndex < items.length) {
      const current = nextIndex++;
      results[current] = await mapper(items[current], current);
    }
  }
  const workers = Array.from({ length: Math.min(limit, items.length) }, worker);
  await Promise.all(workers);
  return results;
}

const SYSTEM_PROMPT = `You are the vibe search engine for Dogear, a reading app. The
reader types free text — a mood, a sentence, a feeling, a comparison to music or
weather or a memory, not a genre or a structured query. Read past the literal words
and find real books that match the tone, pacing, mood, and imagery being described.

You are also blending that vibe with this specific reader's taste profile — never treat
the query as a cold, context-free public book search. The same phrase from two different
readers, with two different histories, should produce different results: filter and
interpret the vibe through their onboarding genres, shelf placement history, and
why-liked-it notes, exactly the way the main recommendation engine does:
- "keepForever" = their strongest possible endorsement, weight heavily.
- "gladIReadIt" = solid but not formative — mild positive signal.
- "shouldveStopped" = a real negative signal (they regret finishing it) — actively avoid
  whatever made this book similar to others, don't just ignore it.
- A book currently being read with "still_enjoying_midpoint": false is an early warning —
  treat it like a soft negative signal even though it's not finished yet.
- read_history and currently_reading are ordered most-recent-first. Weight recent shelf
  placements more heavily than old ones, and if the reader's recent picks trend toward a
  different tone, genre, or pace than their older history, follow the recent trend rather
  than averaging it away.
- If read_history and onboarding_genres are both empty, interpret the query on its own —
  there's no profile yet to blend it with.

Refinements: the "refinements" array, if present, lists one-tap adjustments the reader has
already applied on top of their original query, oldest first (e.g. ["slower", "less
dark"]). Treat each as a real modifier layered onto the original query's intent — combine
them with the query and with each other, don't discard or replace the original meaning.

Rules:
- Interpret tone, pacing, mood, and imagery — don't just keyword-match genre words
  that happen to appear in the query.
- Never recommend a book already in read_history, or listed in shown_books. shown_books is
  every book already surfaced to this reader by this endpoint or by standard
  recommendations, whether or not they saved it — it's a hard exclusion.
- Prefer specificity over safety: real, findable, in-print books only. No invented
  titles.
- Return 5-6 books when you can find them, varied enough to give the reader real choice,
  but every pick should trace back to something specific in the query (and any
  refinements), filtered through this reader's taste profile — not a generic "well-loved
  book" fallback. 3 is the acceptable floor if shown_books has genuinely exhausted every
  reasonable match for this vibe — reaching for that floor too early instead of broadening
  your interpretation of the vibe is the wrong tradeoff.
- "reason" must be one sentence, written directly to the reader ("you"), naming the
  specific connection between their query and this pick. No generic praise ("a
  wonderful read").
- confidence is your own calibrated 0.0-1.0 estimate of fit, used only for sort order —
  never shown to the user verbatim, so don't hedge it, just be honest.
- After picking the books, propose 2-3 short one-tap refinement labels (2-4 words each,
  lowercase, e.g. "slower", "less dark", "more literary") that would meaningfully narrow
  or shift these specific results if the reader tapped one. Base them on the actual query,
  the applied refinements, and the books you just picked — not a fixed generic list — and
  don't repeat a label already present in the input "refinements" array.

Return ONLY valid JSON matching this exact shape, nothing else — no markdown fences,
no preamble:
{
  "results": [
    {
      "title": "string",
      "author": "string",
      "reason": "string",
      "confidence": 0.0
    }
  ],
  "refinements": ["string"]
}`;

// Mirrors recommend.js's MIN_BOOKS_PER_ROW / generateRowWithRetry pattern —
// this endpoint had no floor check or retry at all before, unlike recommend.js,
// which is most of why a growing shown_books list was starving vibe-search
// results harder than Today's rows. Floor of 3 matches the design doc's
// documented "Return 3-6 books" range (Section 13) rather than an invented number.
const MIN_RESULTS = 3;

const BROADEN_RETRY_HINT = `

RETRY NOTE: Your first attempt returned too few books, most likely because shown_books is
large. For this attempt, allow slightly broader matches within the same vibe and taste
blend — related subgenres, adjacent authors, a looser reading of the mood — rather than
returning a short list. The hard exclusions do not change: still never recommend anything
in read_history or shown_books. Only how broadly you interpret the vibe itself should
loosen. Return 5-6 books.`;

// CONFIRMED root cause (reproduced against production): a large shown_books
// list combined with a refinement consistently produced a real 500, ~20s in —
// a genuine generation attempt that failed, not a fast validation error.
// Traced to the code: the JSON.parse failure path below is caught and
// re-thrown, but the retry function's *first* attempt was never wrapped in
// try/catch, only the retry call was — so any throw on attempt 1 (a parse
// failure, most likely from Claude adding preamble or getting cut off by
// max_tokens under the combined complexity of a long exclusion list plus
// refinement blending) skipped the retry entirely and failed the whole
// request immediately. extractJSON + the try/catch fix below address both
// the immediate cause and the underlying trigger.
function extractJSON(raw) {
  const trimmed = raw.trim();
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start === -1 || end === -1 || end < start) return trimmed;
  return trimmed.slice(start, end + 1);
}

async function generateResults(userContent, systemPrompt) {
  const msg = await anthropic.messages.create({
    model: "claude-sonnet-5",
    max_tokens: 2200,
    system: systemPrompt,
    messages: [{ role: "user", content: userContent }],
  });

  const raw = msg.content.find((b) => b.type === "text")?.text ?? "{}";
  let parsed;
  try {
    parsed = JSON.parse(extractJSON(raw));
  } catch (parseErr) {
    console.error("Failed to parse Claude response as JSON:", parseErr.message, "raw:", raw);
    throw parseErr;
  }

  return {
    results: parsed.results ?? [],
    refinements: Array.isArray(parsed.refinements) ? parsed.refinements : [],
  };
}

async function generateResultsWithRetry(userContent) {
  let first;
  try {
    first = await generateResults(userContent, SYSTEM_PROMPT);
  } catch (err) {
    // The first attempt threw outright (not just a low count) — this used to
    // fail the whole request with no retry at all. Give it the same second
    // chance a low-count response gets.
    console.error(
      "vibe-search first attempt threw, retrying with a broadened prompt:", err?.message
    );
    return generateResults(userContent, SYSTEM_PROMPT + BROADEN_RETRY_HINT);
  }

  if (first.results.length >= MIN_RESULTS) {
    return first;
  }

  console.log(
    `vibe-search returned ${first.results.length} books on the first attempt, ` +
    `retrying with a broadened prompt`
  );
  try {
    const retry = await generateResults(userContent, SYSTEM_PROMPT + BROADEN_RETRY_HINT);
    // Keep whichever attempt did better — the retry is meant to recover, not
    // to unconditionally replace a first attempt that was already fine.
    return retry.results.length > first.results.length ? retry : first;
  } catch (err) {
    console.error("vibe-search retry failed:", err?.message);
    return first;
  }
}

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "POST only" });
  }

  if (req.headers["x-app-secret"] !== process.env.APP_SHARED_SECRET) {
    return res.status(401).json({ error: "unauthorized" });
  }

  const {
    query,
    refinements,
    onboarding_genres,
    read_history,
    currently_reading,
    shown_books,
  } = req.body ?? {};

  if (typeof query !== "string" || !query.trim()) {
    return res.status(400).json({ error: "query is required" });
  }

  const userContent = JSON.stringify(
    {
      query: query.trim(),
      refinements: Array.isArray(refinements) ? refinements : [],
      onboarding_genres: onboarding_genres ?? [],
      read_history: read_history ?? [],
      currently_reading: currently_reading ?? [],
      shown_books: shown_books ?? [],
      note: "read_history and currently_reading are ordered most-recent-first.",
    },
    null,
    2
  );

  try {
    const { results: rawResults, refinements: rawRefinements } =
      await generateResultsWithRetry(userContent);

    const enriched = await mapWithConcurrency(
      rawResults,
      LOOKUP_CONCURRENCY,
      async (rec) => ({
        book: await safeLookupBook(rec.title, rec.author),
        reason: rec.reason,
        confidence: rec.confidence ?? 0.5,
      })
    );

    return res.status(200).json({
      results: enriched,
      refinements: rawRefinements,
    });
  } catch (err) {
    console.error("vibe-search error:", err);
    return res.status(500).json({ error: "vibe search failed" });
  }
}

// Decision #21 reliability fix: a single book's metadata lookup failing must
// never take down the whole vibe search response — see recommend.js for the
// same wrapper and the fuller rationale.
async function safeLookupBook(title, author) {
  try {
    return await lookupBook(title, author);
  } catch (err) {
    console.error("lookupBook failed unexpectedly, using bare fallback:", title, author, err?.message);
    return {
      id: `${title}-${author}`.replace(/\s+/g, "-").toLowerCase(),
      title,
      author,
      coverURL: null,
      pageCount: null,
      genres: [],
      summary: null,
    };
  }
}

// Same two-source metadata pattern as recommend.js: Google Books first (needs
// GOOGLE_BOOKS_API_KEY or the unauthenticated quota dies almost immediately),
// falling back to Open Library on an empty result or a Google-side error.
async function lookupBook(title, author) {
  const key = process.env.GOOGLE_BOOKS_API_KEY;
  const keyParam = key ? `&key=${key}` : "";

  let item = await tryGoogleBooksQuery(
    `intitle:${title} inauthor:${author}`,
    keyParam
  );
  if (!item) {
    item = await tryGoogleBooksQuery(`${title} ${author}`, keyParam);
  }

  if (item) {
    const info = item.volumeInfo;
    return {
      id: item.id,
      title: info?.title ?? title,
      author: info?.authors?.[0] ?? author,
      coverURL: info?.imageLinks?.thumbnail?.replace(/^http:/, "https:") ?? null,
      pageCount: info?.pageCount ?? null,
      genres: info?.categories ?? [],
      summary: info?.description ?? null,
    };
  }

  return lookupOpenLibrary(title, author);
}

async function lookupOpenLibrary(title, author) {
  try {
    const q = encodeURIComponent(`${title} ${author}`);
    const resp = await fetch(
      `https://openlibrary.org/search.json?q=${q}&limit=1`
    );
    const data = await resp.json();
    const doc = data.docs?.[0];

    return {
      id: doc?.key ?? `${title}-${author}`.replace(/\s+/g, "-").toLowerCase(),
      title: doc?.title ?? title,
      author: doc?.author_name?.[0] ?? author,
      coverURL: doc?.cover_i
        ? `https://covers.openlibrary.org/b/id/${doc.cover_i}-L.jpg`
        : null,
      pageCount: doc?.number_of_pages_median ?? null,
      genres: doc?.subject?.slice(0, 3) ?? [],
      summary: null,
    };
  } catch (err) {
    console.error("Open Library lookup failed:", err);
    return {
      id: `${title}-${author}`.replace(/\s+/g, "-").toLowerCase(),
      title,
      author,
      coverURL: null,
      pageCount: null,
      genres: [],
      summary: null,
    };
  }
}

// Wrapped + retried per decision #21 — previously an unguarded fetch here
// could throw and propagate all the way out of the per-book loop, failing
// the entire vibe search over a single flaky Google Books call.
async function tryGoogleBooksQuery(query, keyParam, attempt = 0) {
  const q = encodeURIComponent(query);
  const url = `https://www.googleapis.com/books/v1/volumes?q=${q}&maxResults=1${keyParam}`;
  try {
    const resp = await fetch(url);
    const data = await resp.json();
    if (data.error) {
      console.error("Google Books error for query:", query, JSON.stringify(data.error));
      return null;
    }
    return data.items?.[0] ?? null;
  } catch (err) {
    if (attempt === 0) {
      console.error("Google Books fetch failed, retrying once:", query, err?.message);
      return tryGoogleBooksQuery(query, keyParam, attempt + 1);
    }
    console.error("Google Books fetch failed after retry, falling back:", query, err?.message);
    return null;
  }
}
