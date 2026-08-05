// api/recommend.js
// POST { read_history: [{ title, author, genres, rating, why_liked }] }
// Returns { recommendations: [{ book: {...}, reason, confidence }] }
//
// Deploy target: Vercel. Runtime: Node.js serverless function.
// Env var required: ANTHROPIC_API_KEY (set in Vercel project settings, never in code).

import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const SYSTEM_PROMPT = `You are the recommendation engine for Dogear, a reading app.
Given a reader's onboarding genre picks, finished-book history, and any books currently
in progress, propose their next 6 reads.

Reader history uses shelf placement instead of star ratings — treat these as the real
signal, not a proxy for one:
- "keepForever" = their strongest possible endorsement, weight heavily.
- "gladIReadIt" = solid but not formative — mild positive signal.
- "shouldveStopped" = a real negative signal (they regret finishing it) — actively avoid
  whatever made this book similar to others, don't just ignore it.
A book currently being read with "still_enjoying_midpoint": false is an early warning —
treat it like a soft negative signal even though it's not finished yet.

Rules:
- Never recommend a book already in their read history.
- If read_history is empty, lean on onboarding_genres alone — don't wait for finished
  books to make a real pick.
- Prefer specificity over safety: real, findable, in-print books only. No invented titles.
- Vary the picks: not all the same genre, but every pick should trace back to a
  concrete pattern in their history (pacing, tone, subject, structure) — not just
  "similar genre."
- "reason" must be one sentence, written directly to the reader ("you"), naming the
  specific pattern that earned this pick. No generic praise ("a wonderful read").
- confidence is your own calibrated 0.0-1.0 estimate of fit, used only for sort order —
  never shown to the user verbatim, so don't hedge it, just be honest.

Return ONLY valid JSON matching this exact shape, nothing else — no markdown fences,
no preamble:
{
  "recommendations": [
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

  const { read_history, onboarding_genres, currently_reading } = req.body ?? {};
  if (!Array.isArray(read_history)) {
    return res.status(400).json({ error: "read_history must be an array" });
  }

  const historyText = read_history.length
    ? JSON.stringify({ read_history, currently_reading: currently_reading ?? [] }, null, 2)
    : JSON.stringify({
        onboarding_genres: onboarding_genres ?? [],
        note: "No finished books yet — recommend 6 strong, well-loved books within or " +
              "adjacent to these genres to seed their shelf."
      }, null, 2);

  try {
    const msg = await anthropic.messages.create({
      model: "claude-sonnet-5",
      max_tokens: 1500,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: historyText }],
    });

    const raw = msg.content.find((b) => b.type === "text")?.text ?? "{}";
    const parsed = JSON.parse(raw);

    const enriched = [];
    for (const rec of parsed.recommendations ?? []) {
      const book = await lookupBook(rec.title, rec.author);
      enriched.push({
        book,
        reason: rec.reason,
        confidence: rec.confidence ?? 0.5,
      });
      await new Promise((r) => setTimeout(r, 250));
    }

    return res.status(200).json({ recommendations: enriched });
  } catch (err) {
    console.error("recommend error:", err);
    return res.status(500).json({ error: "recommendation failed" });
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

  const info = item?.volumeInfo;
  return {
    id: item?.id ?? `${title}-${author}`.replace(/\s+/g, "-").toLowerCase(),
    title: info?.title ?? title,
    author: info?.authors?.[0] ?? author,
    coverURL: info?.imageLinks?.thumbnail ?? null,
    pageCount: info?.pageCount ?? null,
    genres: info?.categories ?? [],
    summary: info?.description ?? null,
  };
}

async function tryGoogleBooksQuery(query, keyParam) {
  const q = encodeURIComponent(query);
  const resp = await fetch(
    `https://www.googleapis.com/books/v1/volumes?q=${q}&maxResults=1${keyParam}`
  );
  const data = await resp.json();
  return data.items?.[0] ?? null;
}