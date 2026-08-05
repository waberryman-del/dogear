// api/recommend.js
// POST { read_history, onboarding_genres, currently_reading, shown_books }
// Returns { rows: [{ label, kind: "taste"|"discovery", recommendations: [{ book, reason, confidence }] }] }
//
// Deploy target: Vercel. Runtime: Node.js serverless function.
// Env var required: ANTHROPIC_API_KEY (set in Vercel project settings, never in code).

import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const SYSTEM_PROMPT = `You are the recommendation engine for Dogear, a reading app.
Given a reader's onboarding genre picks, finished-book history, and any books currently
in progress, organize their next reads into a small set of labeled rows for the Today
screen — not one flat list.

Reader history uses shelf placement instead of star ratings — treat these as the real
signal, not a proxy for one:
- "keepForever" = their strongest possible endorsement, weight heavily.
- "gladIReadIt" = solid but not formative — mild positive signal.
- "shouldveStopped" = a real negative signal (they regret finishing it) — actively avoid
  whatever made this book similar to others, don't just ignore it.
A book currently being read with "still_enjoying_midpoint": false is an early warning —
treat it like a soft negative signal even though it's not finished yet.

Recency: read_history and currently_reading are both ordered most-recent-first. Weight
recent shelf placements more heavily than old ones — a reader's taste shifts over time,
and their last few books say more about what to recommend next than their first few. If
the recent entries trend toward a different tone, genre, or pace than the older history,
follow that recent trend rather than averaging it in with everything that came before.

Row structure — this is the core of the task:
- Produce 1-3 "taste" rows, each grounded in one genuinely distinct, specific pattern
  from the reader's real history (a specific book, author, pacing quality, structural
  trait). Only make as many taste rows as the history actually supports distinct
  patterns for — never pad with a second row that's really the same pattern restated.
  If read_history is empty, ground taste rows in onboarding_genres instead (e.g. a row
  for one picked genre, a row for another) rather than waiting for finished books.
- Produce exactly one "discovery" row: books that intentionally step outside the
  reader's established pattern — adjacent but genuinely new (a neighboring genre, an
  unfamiliar structure or era) — never just a repeat of a taste row with a different
  label. This row exists to stretch the reader, not to hedge.
- Each row's "label" must be specific and honest, written as if a bookseller were
  handing over a stack: "Because you loved Beloved," "More slow-burn sci-fi like The
  Left Hand of Darkness," "Something a little different tonight." Never a generic
  label like "More fiction" or "You might also like."
- Each row should contain 4-6 books.

Rules:
- Never recommend a book already in their read history.
- Never recommend a book listed in shown_books, even if it would otherwise be a strong
  pick. shown_books is every book already surfaced to this reader by this endpoint or by
  vibe search, whether or not they saved it — it's a hard exclusion, just like read_history.
- Prefer specificity over safety: real, findable, in-print books only. No invented titles.
- No book should appear in more than one row.
- "reason" must be one sentence, written directly to the reader ("you"), naming the
  specific pattern that earned this pick. No generic praise ("a wonderful read").
- confidence is your own calibrated 0.0-1.0 estimate of fit, used only for sort order —
  never shown to the user verbatim, so don't hedge it, just be honest.

Return ONLY valid JSON matching this exact shape, nothing else — no markdown fences,
no preamble:
{
  "rows": [
    {
      "label": "string",
      "kind": "taste",
      "recommendations": [
        {
          "title": "string",
          "author": "string",
          "reason": "string",
          "confidence": 0.0
        }
      ]
    }
  ]
}`;

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "POST only" });
  }

  if (req.headers["x-app-secret"] !== process.env.APP_SHARED_SECRET) {
    return res.status(401).json({ error: "unauthorized" });
  }

  const { read_history, onboarding_genres, currently_reading, shown_books } = req.body ?? {};
  if (!Array.isArray(read_history)) {
    return res.status(400).json({ error: "read_history must be an array" });
  }

  const historyText = read_history.length
    ? JSON.stringify({
        read_history,
        currently_reading: currently_reading ?? [],
        shown_books: shown_books ?? [],
        note: "read_history and currently_reading are ordered most-recent-first."
      }, null, 2)
    : JSON.stringify({
        onboarding_genres: onboarding_genres ?? [],
        shown_books: shown_books ?? [],
        note: "No finished books yet — ground taste rows in these genres and still " +
              "include one discovery row, excluding anything in shown_books."
      }, null, 2);

  try {
    const msg = await anthropic.messages.create({
      model: "claude-sonnet-5",
      // Rows can run up to 3 taste rows + 1 discovery row x 6 books each, and
      // with real read_history the per-book "reason" text runs longer than
      // the old flat 6-book response ever needed — 2500 was measured to
      // truncate mid-JSON on exactly this input shape (2+ distinct taste
      // patterns), producing an unparseable response and a 500. 4096 gives
      // real headroom over the realistic worst case.
      max_tokens: 4096,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: historyText }],
    });

    const raw = msg.content.find((b) => b.type === "text")?.text ?? "{}";
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (parseErr) {
      // Log the raw text so a future truncation/format issue is diagnosable
      // from Vercel logs instead of showing up only as a generic 500.
      console.error("Failed to parse Claude response as JSON:", parseErr.message, "raw:", raw);
      throw parseErr;
    }

    const rows = [];
    for (const row of parsed.rows ?? []) {
      const enrichedBooks = [];
      for (const rec of row.recommendations ?? []) {
        const book = await safeLookupBook(rec.title, rec.author);
        enrichedBooks.push({
          book,
          reason: rec.reason,
          confidence: rec.confidence ?? 0.5,
        });
        await new Promise((r) => setTimeout(r, 150));
      }
      rows.push({
        label: row.label,
        kind: row.kind === "discovery" ? "discovery" : "taste",
        recommendations: enrichedBooks,
      });
    }

    return res.status(200).json({ rows });
  } catch (err) {
    console.error("recommend error:", err);
    return res.status(500).json({ error: "recommendation failed" });
  }
}

// Decision #21 reliability fix: a single book's metadata lookup failing (Google
// Books timeout, malformed response, etc.) must never take down the whole
// request. lookupBook()/tryGoogleBooksQuery() already degrade internally
// (Google -> Open Library -> bare fallback), but this is the last line of
// defense for anything that still throws unexpectedly.
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

  // Google's Books API has been intermittently failing entirely (backendFailed
  // 503s) — fall back to Open Library, which needs no API key and has its own
  // large, independent catalog and cover-image service.
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

// Decision #21: wrap the actually-flaky call (Google Books has shown
// intermittent backendFailed 503s and outright request failures) in its own
// try/catch with one retry before giving up and letting lookupBook() fall
// through to Open Library. Previously this fetch was unguarded — a thrown
// error here propagated all the way out of the per-book loop and failed the
// entire recommend() request over a single cover lookup.
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
