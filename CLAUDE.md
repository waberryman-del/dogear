# Dogear — project brief for Claude Code

## What this is
An iOS app (SwiftUI, iOS 17+) that curates a reader's personal library and continuously
recommends new books based on an AI reading of their taste. Name: Dogear (the folded
page corner every reader recognizes — tactile, unpretentious, no explanation needed).

## Architecture (locked — don't relitigate this each session)
- **Client**: SwiftUI, iOS 17+, MVVM. State lives in `LibraryStore` (`ObservableObject`),
  injected via `.environmentObject`. No third-party dependency managers needed for v1 —
  keep it Apple-native (URLSession, Codable, SwiftData for persistence).
- **Persistence**: SwiftData (not Core Data, not a remote DB) for v1. Local-first: the
  library lives on-device. Add CloudKit sync only after core UX is solid. Currently
  in-memory only (`LibraryStore.entries`) — this migration is still pending, tracked
  in Phase 3 below, don't let it get skipped silently.
- **Backend**: Vercel serverless functions in `backend/api/` — `recommend.js` and
  `why-liked-it.js` exist; `vibe-search.js` is new in Phase 2 (see below). All hold
  `ANTHROPIC_API_KEY` server-side and call the Anthropic Messages API
  (model: `claude-sonnet-5` — verify this string is still current before using it in
  new endpoints; it has been wrong once already in this project's history). The iOS
  app never talks to Anthropic directly.
- **Book metadata**: two sources, in order — Google Books API (server-side, with
  `GOOGLE_BOOKS_API_KEY` env var, since unauthenticated calls hit quota almost
  immediately) as primary, falling back to Open Library (`openlibrary.org/search.json`,
  no key needed) whenever Google's result is empty or its API errors out (it has shown
  intermittent `backendFailed` 503s in production — this is a known Google-side
  reliability issue, not something to keep debugging on our end). Any new endpoint that
  needs book metadata should use this same two-source pattern, not just Google alone.
- **Auth to backend**: a shared secret header (`X-App-Secret`), checked against
  `APP_SHARED_SECRET` env var on Vercel. Not real security, just abuse prevention —
  fine for v1, revisit before any public launch with real user accounts.

## Roadmap — locked, in order, do not reorder or skip ahead
This is the actual plan going forward. If any future session (Claude Code or otherwise)
proposes jumping ahead to a later phase before the current one is genuinely done, or
silently reordering these, stop and flag it explicitly instead of just doing it.

- **Phase 1 — done.** Onboarding (genre picks), Today screen with real AI
  recommendations, tap-to-detail, add to shelf, a basic My Shelf screen, real cover
  art (Google Books + Open Library fallback, https-only URLs).
- **Phase 2 — Vibe search (current phase).** The standout feature: a search
  experience where the reader types free text — a mood, a sentence, a vibe, not a
  genre — and gets AI-curated book matches. See "Vibe search spec" below. This is
  what differentiates Dogear from Goodreads/StoryGraph-style trackers; treat it as
  a first-class feature, not an experiment bolted onto Today.
- **Phase 3 — Real organization.** The three-shelf placement system (decision #2/#3),
  the "start reading" flow, midpoint check-ins (decision #5), and the SwiftData
  persistence migration this all depends on. This turns My Shelf from a static list
  into the actual product.
- **Phase 4 — Design pass.** Real app icon and brand colors (replacing the current
  placeholder forest/ink/brass palette if Walker has finalized different ones by
  then), the fold-gesture signature interaction (decision #6), empty states, loading
  polish. Deliberately last — no point polishing screens whose shape Phase 2 and 3
  are still going to change.
- **Phase 5 — Real-world testing + TestFlight.**

## Vibe search spec (Phase 2)
- New backend endpoint: `backend/api/vibe-search.js`. Same auth pattern
  (`X-App-Secret`), same book-metadata enrichment pattern (Google Books → Open
  Library fallback) as `recommend.js` — copy that structure, don't reinvent it.
- Input: free-text string from the reader (a sentence, a mood, a handful of words —
  "something atmospheric and slow like a rainy Sunday," "books that feel like a
  Fleetwood Mac album," etc.). No structured fields, no genre dropdown alongside it —
  the text box IS the whole interface.
- The system prompt for this endpoint should interpret tone, pacing, mood, and
  imagery from the input, not just keyword-match genres. Reuse the same "real,
  findable, in-print books only" and "one specific sentence, not generic praise"
  rules from `recommend.js`'s prompt.
- iOS side: a new screen or a search bar prominent on Today (Claude Code's call which
  fits better once it sees the current layout) — a text field, a submit action, and
  a results list reusing the same card/detail-sheet components already built for
  Today's recommendations. Don't build a whole parallel UI system for this.
- This does NOT replace the genre-seeded Today recommendations — it's an additional,
  on-demand way to get picks, sitting alongside the earned/bell-refresh system.

## Data model (already scaffolded in `ios/Models/Book.swift`)
`Book`, `Genre` (fixed onboarding list), `ShelfPlacement` (keepForever / gladIReadIt /
shouldveStopped — this IS the rating, there is no star score anywhere in this app),
`LibraryEntry` (status: wantToRead/reading/finished/dnf, dateStartedReading,
shelfPlacement, AI-generated "why you liked it" note, midpointCheckIn, highlights),
`MidpointCheckIn`, `Highlight`, `Recommendation`. Migrate the existing plain structs to
`@Model` classes for SwiftData when you start Week 1 persistence work.

## Product decisions (locked in conversation with Walker — do not silently deviate)
1. **Onboarding**: first launch asks the reader to pick up to 5 genres from the fixed
   `Genre` enum. No book search, no CSV import, no taste quiz. Straight into Today
   afterward with recommendations seeded from those genres alone.
2. **No star ratings anywhere.** Finishing a book means placing it on one of three
   shelves (`ShelfPlacement`) — that placement is the only signal the AI gets about
   how the reader felt. Never add a 1-5 or thumbs mechanism back in.
3. **Archive is organized by the three shelves**, not a flat grid of every book. Within
   each shelf, books still render as spines (visual language from `prototype.html`).
4. 4. **[AMENDED after on-device testing] Recommendation refresh is earned, not scheduled.**
   New picks generate automatically whenever a book is placed on a shelf. There is no
   daily timer and no manual "ring the bell" control — that UI element is cut. Find
   (Vibe Search, decision 11) is now the on-demand discovery surface, making a separate
   manual refresh redundant. Today stays a pure, automatically-updating recommendation
   feed.
5. **Mid-book check-in**: exactly once per book, 5 days after it's marked "reading"
   (`LibraryEntry.dateStartedReading + 5 days`, see `midpointCheckIn.askedOn`). A single
   yes/no prompt: "still enjoying this one?" This requires a **local** notification
   (`UNUserNotificationCenter`) to surface at the right time even if the app isn't
   open — this is a local, on-device notification, not a server push, so it doesn't
   conflict with the "no push notifications" rule below.
6. **Signature interaction**: press-and-hold a book cover to fold its corner down —
   this is how you save/bookmark, not a heart or generic bookmark icon.
7. **The recommendation engine and vibe search are the product, not a feature.**
   When either needs a tradeoff between "ship something plausible" and "actually
   reason well about this specific reader/query," take the slower, better-reasoned
   path. This is explicitly the thing meant to beat other book trackers — don't let
   it regress to generic genre-matching to save time.
8. **Never recommend a book the reader has already been shown**, not just books
   already on their shelf. Maintain a persisted, growing list of every book ID ever
   surfaced by either `recommend.js` or `vibe-search.js` (call it something like
   `shownBookIDs` in `LibraryStore`), sent as an explicit exclusion list on every
   request to both endpoints. "Already read" and "already shown" are two different
   lists — a book can be shown and passed over without being added, and it still
   shouldn't come back.
9. **Reading history sent to the backend must be recency-ordered, and the prompts
   must say so explicitly** — e.g. "entries below are ordered most-recent-first;
   weight recent shelf placements more heavily than old ones, and if the pattern
   is shifting (e.g. recent picks trend toward a different tone/genre than older
   ones), follow the recent trend, not the historical average." This applies to
   `recommend.js`'s existing prompt too, not just new work — it currently doesn't
   say anything about recency and should.
10. **Vibe search must blend the typed query with the reader's actual taste
    profile**, not interpret it as a cold, context-free phrase. `vibe-search.js`
    needs the same profile inputs `recommend.js` gets (onboarding genres, shelf
    placement history, why-liked-it notes) alongside the free-text query, and its
    system prompt should explicitly instruct the model to filter/interpret the
    vibe through that specific reader's taste — "atmospheric and slow" should
    produce different results for two readers with different histories.
11. 11. **[AMENDED after on-device testing] Vibe Search ("Find") has its own bottom tab**,
    alongside Today. A header-row entry point on Today wasn't discoverable enough in
    practice — a standard bottom tab is the right call here, not a compromise.
    Today and Find are two distinct surfaces: Today is pure, automatic recommendation
    browsing; Find is on-demand, query-driven discovery blended with taste (decision 10).
    They are not duplicates of each other.
12. **Only Today and Find exist as tabs for now.** Do not add Archive, Vault, or You
    tabs until those destinations are real and useful — no empty placeholder tabs.
13. **The initial Vibe Search interface is free text only.** No genre dropdowns,
    filters, sliders, or structured controls beside the text field, ever, at entry.
14. **Contextual one-tap refinements** (e.g. "slower," "less dark," "more
    literary") may appear only *after* results are returned — generated/selected
    based on the original query and current results, not a permanent generic
    filter set. Tapping one refines the existing query while preserving the
    original search context — this should feel like refining a request with a
    trusted bookseller, not applying database filters.
15. **The Dogear Design System (`docs/Dogear_Design_System_v0_1_1_.docx` in this
    repo) is the source of truth for all visual and interaction design** — colors,
    typography, spacing, radii, motion, haptics, component anatomy, and screen
    specs. Do not invent new visual patterns when the system already documents
    one. If a screen genuinely conflicts with the system, that's a flag to raise
    explicitly, not a silent deviation.
16. **Do not begin Phase 3 work** (shelf placement, SwiftData persistence
    migration, midpoint check-in, fold gesture) during this Vibe Search /
    design-system pass, even if it looks like a small, related change.

## Design identity
- **Palette**: unchanged from the earlier prototype and still the right call — deep
  forest `#1F3A2E`, ink `#16241D`, linen `#EFE9D8`, brass `#C08A3E`, rust `#9B4B3A`.
  Dark backgrounds pair with warm accents — no gradients, no neon.
- **Type**: serif display (system serif is fine — `.system(.title, design: .serif)`,
  italicized for headers) paired with system sans for UI chrome/labels.
- **Signature element (updated for the Dogear name)**: the dog-ear fold itself becomes
  the core interaction, not just a logo mark. Saving a book to a shelf, marking a page,
  or bookmarking a recommendation for later is a literal folded-corner gesture — press
  and hold a corner of a book cover and it visually folds down, like creasing a real
  page. This replaces a generic heart/bookmark icon with something that only makes
  sense for this app. Archive view keeps the shelf-of-spines layout from the earlier
  prototype (`prototype.html`) — that part still holds regardless of name.
- Full CDS-style rules: no more than 2 accent colors on screen at once, sentence case
  everywhere, no filler copy ("simply", "just", "seamlessly").

## Screens (v1 scope — see WEEK-BY-WEEK.md for sequencing)
1. **Onboarding** — pick up to 5 genres, one-time, first launch only.
2. **Today** — the AI recommendation shelf (scrollable, tap for detail — not a swipe
   stack, not a single daily pick) + "why this" reasoning. Also hosts the manual
   "ring the bell" refresh control. Primary screen.
3. **Archive** — three shelves (keep forever / glad I read it / should've stopped),
   each a row of spines. Tap a spine → detail sheet with the AI "why you liked it"
   note + any highlights.
4. **Vault** — all saved highlights/quotes across the whole library.
5. **Profile / Reading DNA** — a simple visualization of genre/pace patterns. Lowest
   priority — cut first if the month gets tight.

## What NOT to build in v1
- No social features (explicitly cut for v1 despite being in the original brainstorm).
- No account system / login — local-first, single user, no backend user table.
- No remote/server push notifications. (The midpoint check-in's local notification is
  fine — it's scheduled entirely on-device, no server involved.)
- No in-app purchases / monetization — that's a post-v1 decision.
- No star ratings, no thumbs, no numeric score of any kind — see decision #2 above.

## Working agreement for this project
- Optimize for a working app on a real device by end of month, not architectural purity.
- When in doubt between "more features" and "polish what exists," polish.
- Every AI-generated string (recommendation reasons, why-liked-it notes) must degrade
  gracefully — if the backend call fails, show a clear retry state, never a blank screen
  or a crash.
- Keep `backend/` and `ios/` as separate concerns; the iOS app should only ever know
  about the two Vercel endpoint URLs, nothing about Anthropic or Google Books directly.