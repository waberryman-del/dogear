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
  library lives on-device. Add CloudKit sync only after core UX is solid.
- **Backend**: Two Vercel serverless functions (`backend/api/recommend.js`,
  `backend/api/why-liked-it.js`), already written — see `backend/`. They hold the
  `ANTHROPIC_API_KEY` server-side and call the Anthropic Messages API
  (model: `claude-sonnet-4-6`). The iOS app never talks to Anthropic directly.
- **Book metadata**: Google Books API, called server-side inside `recommend.js` to
  enrich AI picks with real covers/page counts. No API key needed for basic search
  volume, but watch for rate limits at scale.
- **Auth to backend**: a shared secret header (`X-App-Secret`), checked against
  `APP_SHARED_SECRET` env var on Vercel. Not real security, just abuse prevention —
  fine for v1, revisit before any public launch with real user accounts.

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
4. **Recommendation refresh is earned, not scheduled.** New picks generate automatically
   whenever a book is placed on a shelf. There is no daily timer. A manual "ring the
   bell" action (`LibraryStore.ringTheBell()`) lets the reader force a refresh anytime
   without finishing anything — build this as a real, visible UI element (a bell or
   pull-tab), not a hidden pull-to-refresh gesture, since it's a named feature.
5. **Mid-book check-in**: exactly once per book, 5 days after it's marked "reading"
   (`LibraryEntry.dateStartedReading + 5 days`, see `midpointCheckIn.askedOn`). A single
   yes/no prompt: "still enjoying this one?" This requires a **local** notification
   (`UNUserNotificationCenter`) to surface at the right time even if the app isn't
   open — this is a local, on-device notification, not a server push, so it doesn't
   conflict with the "no push notifications" rule below.
6. **Signature interaction**: press-and-hold a book cover to fold its corner down —
   this is how you save/bookmark, not a heart or generic bookmark icon.

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
