// api/why-liked-it.js
// POST { title, rating, highlights: [string] }
// Returns { note: "one short paragraph" }

import Anthropic from "@anthropic-ai/sdk";
import { checkRateLimit } from "../lib/rateLimit.js";

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const SYSTEM_PROMPT = `You write one short paragraph (2-3 sentences max) for a reader's
personal archive, explaining why they landed where they did on a book they just finished.

Instead of a star rating, the reader placed the book on one of three shelves:
- "keepForever" — their strongest endorsement.
- "gladIReadIt" — solid, positive, but not formative.
- "shouldveStopped" — real regret at having finished it.
If they had a midpoint check-in and said they were no longer enjoying it
("still_enjoying_midpoint": false), factor that into the note even if they ultimately
placed it on a more positive shelf — that arc (lost interest, then it won them back, or
didn't) is worth naming directly.

Write directly to the reader ("you"), in a warm but unsentimental voice — like a sharp
friend who read the book too, not a critic. If they highlighted specific passages, ground
the note in what those passages actually contain. If there are no highlights, reason from
the shelf placement and title alone, but stay honest — don't invent specifics you don't have.

Return ONLY the paragraph text. No quotation marks, no preamble, no markdown.`;

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

  const { title, shelf_placement, still_enjoying_midpoint, highlights } = req.body ?? {};
  if (!title) {
    return res.status(400).json({ error: "title is required" });
  }

  const userContent = `Title: ${title}
Shelf placement: ${shelf_placement ?? "gladIReadIt"}
Midpoint check-in ("still enjoying it?"): ${
    still_enjoying_midpoint === null || still_enjoying_midpoint === undefined
      ? "not asked / not answered"
      : still_enjoying_midpoint
  }
Highlights: ${highlights?.length ? highlights.join(" | ") : "none saved"}`;

  try {
    const msg = await anthropic.messages.create({
      model: "claude-sonnet-5",
      max_tokens: 300,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: userContent }],
    });

    const note = msg.content.find((b) => b.type === "text")?.text?.trim() ?? "";
    return res.status(200).json({ note });
  } catch (err) {
    console.error("why-liked-it error:", err);
    return res.status(500).json({ error: "generation failed" });
  }
}
