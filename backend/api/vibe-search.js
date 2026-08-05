// api/vibe-search.js
// POST { query: "free text mood/vibe description" }
// Returns { results: [{ book: {...}, reason, confidence }] }
//
// Deploy target: Vercel. Runtime: Node.js serverless function.
// Env var required: ANTHROPIC_API_KEY (set in Vercel project settings, never in code).

import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const SYSTEM_PROMPT = `You are the vibe search engine for Dogear, a reading app. The
reader types free text — a mood, a sentence, a feeling, a comparison to music or
weather or a memory, not a genre or a structured query. Read past the literal words
and find real books that match the tone, pacing, mood, and imagery being described.

Rules:
- Interpret tone, pacing, mood, and imagery — don't just keyword-match genre words
  that happen to appear in the query.
- Prefer specificity over safety: real, findable, in-print books only. No invented
  titles.
- Return 6 books, varied enough to give the reader real choice, but every pick should
  trace back to something specific in the query, not a generic "well-loved book"
  fallback.
- "reason" must be one sentence, written directly to the reader ("you"), naming the
  specific connection between their query and this pick. No generic praise ("a
  wonderful read").
- confidence is your own calibrated 0.0-1.0 estimate of fit, used only for sort order —
  never shown to the user verbatim, so don't hedge it, just be honest.

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
  ]
}`;

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "POST only" });
  }

  if (req.headers["x-app-secret"] !== process.env.APP_SHARED_SECRET) {
    return res.status(401).json({ error: "unauthorized" });
  }

  const { query } = req.body ?? {};
  if (typeof query !== "string" || !query.trim()) {
    return res.status(400).json({ error: "query is required" });
  }

  try {
    const msg = await anthropic.messages.create({
      model: "claude-sonnet-5",
      max_tokens: 1500,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: query.trim() }],
    });

    const raw = msg.content.find((b) => b.type === "text")?.text ?? "{}";
    const parsed = JSON.parse(raw);

    const enriched = [];
    for (const rec of parsed.results ?? []) {
      const book = await lookupBook(rec.title, rec.author);
      enriched.push({
        book,
        reason: rec.reason,
        confidence: rec.confidence ?? 0.5,
      });
      await new Promise((r) => setTimeout(r, 250));
    }

    return res.status(200).json({ results: enriched });
  } catch (err) {
    console.error("vibe-search error:", err);
    return res.status(500).json({ error: "vibe search failed" });
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

async function tryGoogleBooksQuery(query, keyParam) {
  const q = encodeURIComponent(query);
  const url = `https://www.googleapis.com/books/v1/volumes?q=${q}&maxResults=1${keyParam}`;
  const resp = await fetch(url);
  const data = await resp.json();
  if (data.error) {
    console.error("Google Books error for query:", query, JSON.stringify(data.error));
  }
  return data.items?.[0] ?? null;
}
