// api/daily-picks.js
// POST {
//   read_history: [{ title, author, genres, shelf_placement, why_liked }]?,  // most-recent-first
//   onboarding_genres: [string]?,
//   currently_reading: [{ title, still_enjoying_midpoint }]?,                // most-recent-first
//   shown_books: [{ title, author }]?,       // exclusion list, oldest-shown first
//   shelved_books: [{ title, author }]?,     // every shelf entry, any status — hard exclusion, never backfilled from
//   not_interested: [{ title, author }]?     // decision #27 — moderate negative signal, not an exclusion list
// }
// Returns { picks: [{ book, reason, confidence }] } — exactly 3 (decision #24), no row/taxonomy shape.
//
// Deploy target: Vercel. Runtime: Node.js serverless function.
// Env var required: ANTHROPIC_API_KEY (set in Vercel project settings, never in code).
//
// CLAUDE.md decision #24: Today stops being a browsable multi-row feed and
// becomes a once-daily ritual — exactly 3 curated picks, generated once per
// local calendar day (LibraryStore gates the "once per day" part; this
// endpoint just answers "give me 3" whenever it's asked). Deliberately a
// single Claude call, not the three-parallel-row-taxonomy shape recommend.js
// uses for Search — a much smaller generation task, expected to be faster
// and more reliable by construction than the old row model ever was.

import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// See recommend.js/vibe-search.js for the fuller rationale — bounded
// concurrency instead of blasting Google Books with every lookup at once.
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

const SYSTEM_PROMPT = `You are Dogear's daily recommendation engine. Once per day, the
reader gets exactly 3 curated picks — no rows, no taxonomy, just the single best 3
individual books for them right now.

Reader history uses shelf placement instead of star ratings — treat these as the real
signal, not a proxy for one:
- "keepForever" = their strongest possible endorsement, weight heavily.
- "gladIReadIt" = solid but not formative — mild positive signal.
- "shouldveStopped" = a real negative signal (they regret finishing it) — actively avoid
  whatever made this book similar to others, don't just ignore it.
A book currently being read with "still_enjoying_midpoint": false is an early warning —
treat it like a soft negative signal even though it's not finished yet.

not_interested is a separate, real but moderate negative signal — books the reader
explicitly dismissed from a past daily pick without ever adding them to their shelf.
Weaker than "shouldveStopped" (they never even started it), but still a genuine push
away from whatever pattern made that pick land wrong for them.

Recency: read_history and currently_reading are both ordered most-recent-first. Weight
recent shelf placements more heavily than old ones — a reader's taste shifts over time,
and their last few books say more about what to recommend next than their first few. If
the recent entries trend toward a different tone, genre, or pace than the older history,
follow that recent trend rather than averaging it in with everything that came before.

Rules:
- Never recommend a book already in their read history or in shelved_books. shelved_books
  is every book on the reader's shelf in any status (want-to-read, reading, finished,
  dnf) — a permanent, absolute exclusion, no exceptions.
- Never recommend a book listed in shown_books, even if it would otherwise be a strong
  pick. shown_books is every book already surfaced to this reader by any endpoint,
  whether or not they saved it — also a hard exclusion for you to respect; the backend
  (not you) may occasionally backfill an old shown_books entry itself when genuinely
  exhausted, but that's a fallback outside your own picks.
- Prefer specificity over safety: real, findable, in-print books only. No invented titles.
- Return exactly 3 books when you can find them; 2 is the acceptable floor if shown_books
  has genuinely exhausted every reasonable match — reaching for that floor too early
  instead of broadening your interpretation of the reader's taste triggers a slower
  retry, so aim for 3 up front.
- "reason" must be one sentence, written directly to the reader ("you"), naming the
  specific pattern that earned this pick. No generic praise ("a wonderful read").
- confidence is your own calibrated 0.0-1.0 estimate of fit, used only for sort order —
  never shown to the user verbatim, so don't hedge it, just be honest.
- No taste/discovery taxonomy split is needed here (unlike Search's rows) — just the
  single best 3 picks for this reader today. Still favor real variety across the 3
  (not 3 near-identical books) whenever the reader's profile supports it.

Return ONLY valid JSON matching this exact shape, nothing else — no markdown fences,
no preamble:
{
  "picks": [
    { "title": "string", "author": "string", "reason": "string", "confidence": 0.0 }
  ]
}`;

// Both the retry trigger and the backfill target — unlike the row engine's
// "4-6 books, 4 is an acceptable floor" (where being a little short barely
// matters in a scrollable row), a daily batch that ships fewer than the
// promised "exactly 3" is immediately, visibly short on a screen built
// entirely around that number, so there's no lower "acceptable" floor to
// aim below 3 the way the row engine has.
const MIN_PICKS = 3;

const BROADEN_RETRY_HINT = `

RETRY NOTE: Your first attempt returned too few books, most likely because shown_books
is large. For this attempt, allow slightly broader matches within the reader's overall
taste — related subgenres, adjacent authors, a looser reading of the pattern — rather
than returning a short list. The hard exclusions do not change: still never recommend
anything in read_history, shelved_books, or shown_books. Only how broadly you interpret
the reader's taste should loosen. Return 3 books.`;

// See vibe-search.js for the fuller rationale — protects against Claude
// occasionally prefacing the JSON with commentary despite being told not to,
// which otherwise breaks a strict JSON.parse.
function extractJSON(raw) {
  const trimmed = raw.trim();
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start === -1 || end === -1 || end < start) return trimmed;
  return trimmed.slice(start, end + 1);
}

async function generatePicks(userContent, systemPrompt) {
  const msg = await anthropic.messages.create({
    model: "claude-sonnet-5",
    max_tokens: 1500,
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

  return { picks: parsed.picks ?? [] };
}

// Same shape as vibe-search.js's generateResultsWithRetry, including the
// first-attempt try/catch that a prior session's version of that pattern
// initially missed (confirmed root cause of a real production 500 there) —
// built correctly here from the start rather than repeating that bug.
async function generatePicksWithRetry(userContent) {
  let first;
  try {
    first = await generatePicks(userContent, SYSTEM_PROMPT);
  } catch (err) {
    console.error(
      "daily-picks first attempt threw, retrying with a broadened prompt:", err?.message
    );
    return generatePicks(userContent, SYSTEM_PROMPT + BROADEN_RETRY_HINT);
  }

  if (first.picks.length >= MIN_PICKS) {
    return first;
  }

  console.log(
    `daily-picks returned ${first.picks.length} books on the first attempt, ` +
    `retrying with a broadened prompt`
  );
  try {
    const retry = await generatePicks(userContent, SYSTEM_PROMPT + BROADEN_RETRY_HINT);
    return retry.picks.length > first.picks.length ? retry : first;
  } catch (err) {
    console.error("daily-picks retry failed:", err?.message);
    return first;
  }
}

// CLAUDE.md decision #8 (amended): a shelved book (any status) is never
// backfilled, no exceptions. If the batch is still short of MIN_PICKS (3)
// even after the retry above, backfill remaining slots from the OLDEST
// shown_books entries (least-recently-shown first) rather than shipping a
// daily batch with fewer than the promised 3. `shownBooks` is already in
// oldest-first order (the client only ever appends), so a plain
// left-to-right scan is "oldest first" — no separate sort needed.
function backfillFromShownBooks(currentPicks, shownBooks, shelvedBooks, needed) {
  if (needed <= 0 || !Array.isArray(shownBooks)) return [];

  const bookKey = (title, author) =>
    `${(title ?? "").toLowerCase().trim()}|${(author ?? "").toLowerCase().trim()}`;

  const shelvedKeys = new Set(
    (Array.isArray(shelvedBooks) ? shelvedBooks : []).map((b) => bookKey(b?.title, b?.author))
  );
  const pickedKeys = new Set(currentPicks.map((r) => bookKey(r.title, r.author)));

  const backfilled = [];
  for (const entry of shownBooks) {
    if (backfilled.length >= needed) break;
    const title = entry?.title;
    const author = entry?.author;
    if (!title || !author) continue;
    const key = bookKey(title, author);
    if (shelvedKeys.has(key) || pickedKeys.has(key)) continue;
    pickedKeys.add(key);
    backfilled.push({
      title,
      author,
      reason: "You saw this one before and it's still one of the strongest fits here.",
      confidence: 0.5,
    });
  }
  return backfilled;
}

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "POST only" });
  }

  if (req.headers["x-app-secret"] !== process.env.APP_SHARED_SECRET) {
    return res.status(401).json({ error: "unauthorized" });
  }

  const {
    read_history,
    onboarding_genres,
    currently_reading,
    shown_books,
    shelved_books,
    not_interested,
  } = req.body ?? {};

  const historyText = JSON.stringify(
    {
      read_history: read_history ?? [],
      onboarding_genres: onboarding_genres ?? [],
      currently_reading: currently_reading ?? [],
      shown_books: shown_books ?? [],
      shelved_books: shelved_books ?? [],
      not_interested: not_interested ?? [],
      note: "read_history and currently_reading are ordered most-recent-first.",
    },
    null,
    2
  );

  try {
    const { picks: rawPicks } = await generatePicksWithRetry(historyText);

    let finalPicks = rawPicks;
    if (finalPicks.length < MIN_PICKS) {
      const needed = MIN_PICKS - finalPicks.length;
      const backfilled = backfillFromShownBooks(finalPicks, shown_books, shelved_books, needed);
      if (backfilled.length > 0) {
        console.log(
          `daily-picks scarcity fallback fired: backfilling ${backfilled.length} book(s) ` +
          `from oldest shown_books (had ${finalPicks.length}, needed ${MIN_PICKS})`
        );
        finalPicks = [...finalPicks, ...backfilled];
      }
    }

    const enriched = await mapWithConcurrency(
      finalPicks,
      LOOKUP_CONCURRENCY,
      async (rec) => ({
        book: await safeLookupBook(rec.title, rec.author),
        reason: rec.reason,
        confidence: rec.confidence ?? 0.5,
      })
    );

    return res.status(200).json({ picks: enriched });
  } catch (err) {
    console.error("daily-picks error:", err);
    return res.status(500).json({ error: "daily picks failed" });
  }
}

// Decision #21 reliability fix: a single book's metadata lookup failing must
// never take down the whole daily-picks response — see recommend.js for the
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

// Same two-source metadata pattern as recommend.js/vibe-search.js: Google
// Books first (needs GOOGLE_BOOKS_API_KEY or the unauthenticated quota dies
// almost immediately), falling back to Open Library on an empty result or a
// Google-side error. Duplicated a third time here rather than extracted into
// a shared module — Vercel's per-file routing behavior for a shared helper
// under api/ wasn't worth the deploy-time risk to verify mid-pivot; worth
// consolidating in a future pass.
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

// Wrapped + retried per decision #21 — an unguarded fetch here could throw
// and propagate all the way out of the per-book loop, failing the entire
// daily-picks request over a single flaky Google Books call.
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
