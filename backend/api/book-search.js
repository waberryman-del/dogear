// api/book-search.js
// POST { query: "title, author, or ISBN text" }
// Returns { results: [{ id, title, author, coverURL, pageCount, genres, summary, publicationYear }] }
//
// Deploy target: Vercel. Runtime: Node.js serverless function.
//
// CLAUDE.md decision #25: Search gets real search by title/author/ISBN
// against the existing Google Books/Open Library metadata lookups —
// deliberately NOT an AI-reasoning endpoint. No ANTHROPIC_API_KEY use here;
// this is a direct catalog lookup, same two-source pattern (Google Books
// primary, Open Library fallback) as recommend.js/vibe-search.js/
// daily-picks.js use for enriching AI picks, just returning several
// candidate matches instead of the single best one for a known title+author.

const MAX_RESULTS = 12;

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
  const trimmed = query.trim();

  try {
    const results = isLikelyISBN(trimmed)
      ? await searchGoogleBooks(`isbn:${trimmed.replace(/[-\s]/g, "")}`)
      : await searchGoogleBooks(trimmed);

    if (results.length > 0) {
      return res.status(200).json({ results });
    }

    // Google's Books API has been intermittently failing entirely
    // (backendFailed 503s) — fall back to Open Library, which needs no API
    // key and has its own large, independent catalog and cover service.
    const fallback = await searchOpenLibrary(trimmed);
    return res.status(200).json({ results: fallback });
  } catch (err) {
    console.error("book-search error:", err);
    return res.status(500).json({ error: "search failed" });
  }
}

// A plain 10 or 13-digit ISBN (hyphens/spaces allowed) — anything else is
// treated as a free-text title/author query.
function isLikelyISBN(text) {
  const stripped = text.replace(/[-\s]/g, "");
  return /^\d{10}(\d{3})?$/.test(stripped);
}

// Stage 1 (decision #39.2) — see recommend.js for the fuller rationale, same
// leading-4-digit-year parse of Google Books' free-form publishedDate string.
function parsePublicationYear(publishedDate) {
  const match = /^\d{4}/.exec(publishedDate ?? "");
  return match ? parseInt(match[0], 10) : null;
}

// CLAUDE.md decision #40: same bundle/study-guide filter as recommend.js/
// vibe-search.js/daily-picks.js's lookupBook() — but here there's no single
// "best match" to fall back through, just a results list shown directly to
// the reader for manual search, so bad matches are dropped from the list
// outright rather than deprioritized behind a fallback query.
const BUNDLE_OR_GUIDE_PATTERNS = [
  /study guide/i,
  /summary (?:and analysis )?of\b/i,
  /companion (?:to|guide)/i,
  /box(?:ed)? set/i,
  /set of \d+ books?/i,
  /\bcollection\b/i,
];

function isBundleOrGuideMatch(title, categories) {
  const haystack = [title, ...(categories ?? [])].filter(Boolean).join(" ");
  return BUNDLE_OR_GUIDE_PATTERNS.some((re) => re.test(haystack));
}

async function searchGoogleBooks(query) {
  const key = process.env.GOOGLE_BOOKS_API_KEY;
  const keyParam = key ? `&key=${key}` : "";
  const q = encodeURIComponent(query);
  const url = `https://www.googleapis.com/books/v1/volumes?q=${q}&maxResults=${MAX_RESULTS}${keyParam}`;

  try {
    const resp = await fetch(url);
    const data = await resp.json();
    if (data.error) {
      console.error("Google Books search error for query:", query, JSON.stringify(data.error));
      return [];
    }
    return (data.items ?? [])
      .filter((item) => !isBundleOrGuideMatch(item.volumeInfo?.title, item.volumeInfo?.categories))
      .map((item) => {
        const info = item.volumeInfo ?? {};
        return {
          id: item.id,
          title: info.title ?? query,
          author: info.authors?.[0] ?? "Unknown",
          coverURL: info.imageLinks?.thumbnail?.replace(/^http:/, "https:") ?? null,
          pageCount: info.pageCount ?? null,
          genres: info.categories ?? [],
          summary: info.description ?? null,
          publicationYear: parsePublicationYear(info.publishedDate),
        };
      });
  } catch (err) {
    console.error("Google Books search fetch failed:", query, err?.message);
    return [];
  }
}

async function searchOpenLibrary(query) {
  try {
    const q = encodeURIComponent(query);
    const resp = await fetch(
      `https://openlibrary.org/search.json?q=${q}&limit=${MAX_RESULTS}`
    );
    const data = await resp.json();
    return (data.docs ?? [])
      .filter((doc) => !isBundleOrGuideMatch(doc.title, doc.subject))
      .map((doc) => ({
        id: doc.key ?? `${doc.title}-${doc.author_name?.[0] ?? "unknown"}`.replace(/\s+/g, "-").toLowerCase(),
        title: doc.title ?? query,
        author: doc.author_name?.[0] ?? "Unknown",
        coverURL: doc.cover_i ? `https://covers.openlibrary.org/b/id/${doc.cover_i}-L.jpg` : null,
        pageCount: doc.number_of_pages_median ?? null,
        genres: doc.subject?.slice(0, 3) ?? [],
        summary: null,
        publicationYear: doc.first_publish_year ?? null,
      }));
  } catch (err) {
    console.error("Open Library search failed:", query, err?.message);
    return [];
  }
}
