# Dogear — project brief for Claude Code

## What this is
An iOS app (SwiftUI, iOS 17+) that curates a reader's personal library and continuously
recommends new books based on an AI reading of their taste. Name: Dogear (the folded
page corner every reader recognizes — tactile, unpretentious, no explanation needed).

## Architecture (locked — don't relitigate this each session)
- **Client**: SwiftUI, iOS 17+, MVVM. State lives in `LibraryStore` (`ObservableObject`),
  injected via `.environmentObject`. No third-party dependency managers needed for v1 —
  keep it Apple-native (URLSession, Codable, SwiftData for persistence).
- **Persistence**: SwiftData (not Core Data, not a remote DB) is the eventual, ideal
  answer for v1, but is NOT what's currently implemented. **Current state (fixed,
  verified working)**: `LibraryStore.entries` persists via the same simple
  UserDefaults JSON-encoding pattern used for the store's other persisted properties
  — confirmed on a real device that shelf status, reading progress, and goals all
  survive a force-quit. This was a deliberate, lower-risk stopgap chosen over an
  urgent full SwiftData migration when total data loss was discovered and fixed. The
  full SwiftData migration remains a legitimate future improvement (better querying,
  eventual CloudKit sync), but is no longer an urgent, blocking data-loss risk — don't
  treat it as more urgent than it currently is.
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
  into the actual product. **Status: Stage 0 of this phase (per `LAUNCH-ROADMAP.md`)
  is CLOSED — persistence fixed and verified, the Today hero moment rebuilt and
  refined, recommend.js/vibe-search.js confirmed reliable under heavy real-world
  exclusion load, and the midpoint check-in built and verified end-to-end. See
  `LAUNCH-ROADMAP.md` for the authoritative, detailed stage-by-stage status — this
  file holds the locked decisions, that file holds current progress. Stage 1 (the
  book detail page, decisions #31 and #36-39 below) is built per decision 39's
  full section-by-section spec — compiles clean, not yet walked through on a
  simulator/device. Update `LAUNCH-ROADMAP.md` once that on-device pass happens.**
- **Phase 4 — Design pass.** Real app icon and brand colors — see decision #23 below,
  which now supersedes the placeholder forest/ink/brass palette — the fold-gesture
  signature interaction (decision #6), empty states, loading polish. Deliberately
  last — no point polishing screens whose shape Phase 2 and 3 are still going to
  change.
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
4. **[AMENDED after on-device testing] Recommendation refresh is earned, not
   scheduled.** New picks generate automatically whenever a book is placed on
   a shelf. There is no daily timer and no manual "ring the bell" control —
   that UI element is cut. Find (Vibe Search) and Search (decision 25) are
   now the on-demand discovery surfaces, making a separate manual refresh
   redundant. Today's own cadence is now the once-daily model (decision 24),
   not a continuously-refreshing feed at all.
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
8. **[AMENDED after real-usage data] Never recommend a book already on the
   reader's shelf** (any status: want-to-read, reading, finished, dnf) — this
   never changes, no exceptions. For books already *shown* but not shelved
   (`shownBookIDs`): the default is still never-repeat. However, if a
   request would return fewer than the minimum floor even after the
   existing retry, the backend may backfill remaining slots from the
   oldest entries in `shownBookIDs` (least-recently-shown first) rather
   than returning a thin or empty result. This is a scarcity fallback that
   only activates when real usage has genuinely exhausted fresh
   candidates — exactly the "user behavior warrants it" condition Walker
   specified — not a default aging or capping policy. Log whenever this
   fallback actually fires, so we can see how often it's really needed
   rather than guessing.
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
11. **[AMENDED, then further superseded by decision 12] Vibe Search ("Find")
    has its own tab** — originally added as a 2-tab (Today/Find) amendment,
    now simply one of the full 5 tabs per decision 12. Today and Find remain
    distinct surfaces: Today is the once-daily curated ritual (decision 24),
    Find is on-demand, query-driven discovery blended with taste (decision 10).
12. **[AMENDED — full 5-tab bar now] Build the full tab bar: Today, Search,
    Vibe (Find), Shelf, Profile.** The earlier "no empty placeholder tabs"
    reasoning held while Search/Shelf/Profile had no real content — they now
    do (see the Today/Search redesign below and decision 25). This isn't
    reopening the old question, it's the same rule reaching its natural
    resolution now that the destinations are real.
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
17. **[Phase 3 opening] Today (home) is being redesigned around a "Currently
    Reading" hero status card**, not just a flat recommendation feed. The
    hero card shows cover, title, author, page progress, and (if set) a
    reading goal with a pace indicator. If nothing is currently being read,
    the card invites starting something from the shelf or recommendations —
    never a blank space.
18. **Reading goals are: a target page count + a target date**, set/edited
    from the hero card. Progress is updated via simple manual page-number
    entry/stepper — no quick-add buttons, no slider. The app computes a pace
    indicator (on track / behind) from current page vs. the goal's timeline.
19. **[SUPERSEDED — see decision 24] Below the hero card, recommendations
    render as AI-personalized horizontal-scroll rows**, replacing the flat
    grid. Rows are dynamically generated and specific to the reader — not
    fixed genre buckets. Mix of taste-anchored rows (grounded in specific
    books/patterns from real history, with honest, specific titles —
    "Because you loved Beloved," not "More Fiction") and at least one
    explicit discovery/stretch row that intentionally introduces something
    adjacent-but-new, framed as such. **This row model no longer lives on
    Today — it moves to the new Search/Discover tab (decision 25). The
    underlying engine (row generation, taxonomy, retry/backfill logic) is
    NOT thrown away — it's repurposed to power Search's default browsing
    content instead of Today's feed.**
20. **These rows reuse the existing recommendation engine**, not a parallel
    system — same shown-book exclusion (decision 8), recency-weighting
    (decision 9), and taste-blending (decision 10) already built. This is an
    extension of `recommend.js`'s logic, not a new, separately-reasoned
    feature. Still true under decision 24/25 — just serving Search instead
    of Today now.
21. **Reliability**: backend book-metadata lookups (Google Books → Open
    Library fallback) must not let one book's failure take down the whole
    recommendation/vibe-search response — wrap per-book lookups so a single
    failure degrades gracefully (missing cover, not a failed request).
    Function timeouts should be generous enough to cover Claude's response
    time plus metadata lookups with retries, since users have hit
    intermittent "couldn't reach your library's brain" failures that are
    most likely timeout-related, not hard errors. **[Update]** A later
    heavy-exclusion investigation found the deeper cause was `max_tokens`
    truncation on the harder secondary/discovery rows, not just missing
    try/catch — fixed (2000→4096 + a second retry attempt). Known,
    accepted remaining risk: a worst-case row needing all 3 attempts
    (~15-20s each) could theoretically approach the 60s `maxDuration` —
    not observed in testing, not ruled out either.
22. *(intentionally skipped — no content. An earlier numbering pass left a
    gap here rather than renumbering everything after it, to avoid
    invalidating other decisions' cross-references. If a real decision 22
    is needed later, insert it here; otherwise leave the gap as-is.)*
23. **[Phase 4 reference — do not act on this yet] A finished brand board
    exists at `docs/brand-board.png`.** When Phase 4 actually starts, this
    board — not the current placeholder palette or `docs/Dogear_Design_System_v0_1_1_.docx`
    — is the intended source of truth to design and build toward. It includes:
    a real app icon (green rounded-square with a dog-ear/dog-profile mark), a
    refined palette (`#0F2B22`, `#2E4A3A`, `#F6F1E7`, `#E7DECA`, `#C79A62` —
    distinct from the current `#1F3A2E`-based placeholder set), Playfair
    Display for headlines paired with Inter for body/UI text, and — notably —
    **color-coded shelf spines matching decision #2/#3's three shelves**
    (deep green for "keep forever," warm tan for "glad I read it," oxblood/rust
    for "should've stopped"), which is a more concrete execution of that
    decision than anything specified in text so far. It also shows a fully
    designed 5-tab bar (Home / Discover / Ask Dogear / Library / Profile) —
    this is a real, considered answer to the tab-navigation question — and it's now
    been substantially adopted early (decision 12/24/25), ahead of the original
    Phase 4 timeline, because Today/Search/Shelf/Profile all ended up with real
    content sooner than expected. Phase 4's remaining job for this board is matching
    its exact *visual* execution (icon, palette, typography, the color-coded shelf
    art) — not the tab structure itself, which already exists now.
    **[Note: decision 12 has since been amended — the full 5-tab bar is now
    built, superseding the "2-tab bar" reference above. This board's own
    5-tab layout (Home/Discover/Ask Dogear/Library/Profile) is very close to
    what's now real — Phase 4 is about matching its exact visual execution
    (icon, palette, typography, the color-coded shelf art), not the tab
    structure itself, which already exists.]**
    Do not start building toward this board's exact visuals during Phase 3
    work — this entry exists so a future session knows it's there when
    Phase 4 opens.

24. **[Major Today redesign, replaces decision 19's row model on Today]
    Today becomes a once-daily ritual, not a browsable feed.** Once per
    calendar day, the reader is shown exactly 3 curated picks. For each,
    a binary decision: **want to read** (adds to shelf, status
    `wantToRead` — does NOT auto-start reading, see decision 26) or
    **not interested** (dismissed — see decision 27 for how this feeds
    back into recommendations). Today's screen composition: if the reader
    has a currently-reading book AND today's 3 picks aren't fully decided
    yet, show BOTH at once — the hero reading-status card (decision 17/18)
    on top, undecided daily picks below it. Once all 3 are decided, that
    section clears until tomorrow's picks generate; the hero card remains
    the persistent view otherwise. This is a much smaller, simpler
    generation task than the old row model (exactly 3 books once a day,
    vs. 2-3 rows of 4-6 books on every refresh) — expect this to be
    meaningfully faster and more reliable by construction, not just by
    patching.
25. **New Search/Discover tab.** Two things live here: (1) real search by
    title, author, or ISBN against the existing Google Books/Open Library
    metadata lookups — not AI-driven, a straightforward manual lookup so
    a reader can find and add any specific book. (2) Below/alongside
    search, the AI-personalized row-browsing experience from the old
    decision 19 lives here now — same engine, same taste-anchored +
    discovery row taxonomy, same shown-book exclusion/recency/taste-
    blending (decisions 8-10, 20), just relocated from Today to Search.
    Nothing about the row engine itself needs to be rebuilt — it's being
    re-homed, not redesigned.
26. **"Want to read" and "start reading" are always separate, explicit
    actions.** Adding a book to the shelf (from Today's daily picks,
    Search, or Vibe Search results) never automatically starts it as the
    currently-reading book. Starting to read is a deliberate action taken
    from My Shelf. (This matches how `addToShelf`/`startReading` already
    work as separate calls in the existing code — confirm this holds,
    don't introduce new auto-start behavior anywhere.)
27. **"Not interested" is a real but moderate negative signal** — not as
    strong as "should've stopped" on a finished book (that's a book you
    actually read and regretted; this is a book you declined without
    reading), but a definite, real push away from that pattern in future
    recommendations, not a no-memory soft dismiss. Track it distinctly
    from shelf placements (a lighter-weight signal, not reusing
    `ShelfPlacement`), and factor it into both Today's daily picks and
    Search's rows.
28. **Profile tab scope, for now**: basic reading stats (books finished,
    current streak or similar) plus app settings. Real content, not a
    placeholder, but intentionally minimal — not a feature-rich profile
    system. Expand later if a real need shows up, don't over-build it now.
29. **Today's header**: no "DOGEAR" wordmark needed at the top — just the
    time-aware greeting ("Good morning" / "Good afternoon" / "Good
    evening"), optionally followed by the reader's first name if set, in a
    larger, more prominent type size than currently shown. Name source for
    now: a simple optional "Your name" field in Profile settings (plain
    text, no validation needed) — if blank, greeting has no name, just the
    time-of-day phrase. **Forward note, not to act on now**: once real
    accounts/login exist (a future phase, explicitly not v1 — see "What NOT
    to build in v1"), this manual field should be replaced by the real
    account name. Record this intent so it isn't lost, don't build login now.
30. **My Shelf reorganization**: no longer a flat grid of everything. Real
    sections, in order: **Currently Reading** (a real list — can be more
    than one book; this is separate from the hero card's single-book
    spotlight on Today, which shows only the most recent — both are valid,
    different views of the same underlying data, not a conflict), **Want to
    Read** (the same list Today's "Up Next" already previews under the hero
    card — one underlying data source, two places it's shown), then the
    three finished-book shelves per decision #3: **Keep Forever**, **Glad I
    Read It**, **Should've Stopped**. This finally gives want-to-read/
    currently-reading books — which don't have a `shelfPlacement` and never
    belonged in the three finished shelves — an honest home.
31. **[Stage 1 spec — planned, NOT yet built] Book detail page — core
    content and behavior.** Every entry point (Today's daily picks,
    Search's rows/manual lookup, Vibe Search results, My Shelf) opens the
    same detail view. Shows: cover, title, author, page count, a real
    synopsis, and the AI's personal "why this fits you" verdict (decision
    33). Actions available depend on the book's current status: not on
    shelf → add to shelf / want to read; want to read → start reading;
    reading → update page / view goal; finished → shows shelf placement,
    can be re-placed. No highlights/quotes on this page (decision 32) — it
    stays focused on discovery and status, not reflection. No external
    reviews or ratings (decision 34) — purely personal, consistent with the
    existing "no social features" rule. **A camera/scan-based entry point
    was considered and explicitly cut** — Vibe Search remains the sole
    standout/differentiating feature by deliberate choice; do not
    reintroduce scanning without a real product conversation first.
32. **Highlights stay off the detail page.** They remain part of the data
    model (`LibraryEntry.highlights`) but aren't surfaced here — this page
    is about deciding/tracking, not reflecting.
33. **The "why this fits you" verdict**: one specific reasoning sentence,
    same quality bar as recommendations elsewhere (decision 7) — never
    generic praise. Generated once and cached, not regenerated on every
    visit. Cache invalidation: store the reader's finished-book count
    alongside the cached verdict; regenerate only if that count has changed
    since it was generated (a simple, cheap proxy for "taste profile
    changed meaningfully" — not a full re-diff of history).
34. **No external reviews/ratings anywhere on the detail page.** Purely
    personal — the AI's reasoning and the reader's own status/history with
    that book. Consistent with the existing no-social-features decision.
35. **[Priority pass] Vibe Search AI quality — closing the gap between
    "plausible" and "genuinely great."** Real evidence from testing: the
    same handful of books (Beloved, Piranesi, Convenience Store Woman,
    Norwegian Wood, Housekeeping) have come up repeatedly across different
    queries — a sign the model defaults to a "canon" for moody/literary
    requests rather than genuinely searching wide. Fix via prompt work, not
    UI: (1) explicit instruction to avoid over-recommended default picks
    unless genuinely the best fit, actively reach for less obvious strong
    matches; (2) require the model to consider multiple honest
    interpretations of an ambiguous query (a vague phrase can mean tone,
    pacing, or setting) before committing to its picks, rather than
    pattern-matching the first obvious association; (3) the "why this fits"
    reasoning must reference the reader's actual words, not just the
    general mood category, so it reads as genuinely responsive, not
    templated. **DONE — verified with real before/after evidence across
    four different queries, canon books confirmed no longer dominating.**
    Pattern note: longer/more specific reasoning costs more tokens — this
    hit the same max_tokens truncation bug recommend.js already had, twice
    now. Check token budget proactively on any future prompt change asking
    for longer output, don't wait to discover it via a truncated response.
36. **[Stage 1] Book detail page — loading behavior.** Show the full page
    immediately on open — cover, title, author, synopsis, and available
    actions all render right away. Only the AI "why this fits you" verdict
    (decision 33) gets a small, contained loading placeholder if it isn't
    cached yet — never hold the entire page hostage waiting on one AI call
    when everything else is already available.
37. **[Stage 1, AMENDED by decision 39.4 — see there for why] Reuse existing
    reasoning when available.** If a book arrived via Today, Search's rows,
    or Vibe Search — all of which already generate a specific "why this
    fits" reason as part of their normal response — the detail page uses
    that exact reasoning as its verdict directly, appears instantly, no
    waiting. `book-verdict.js` (the lightweight backend call) still runs
    once for this book regardless, per decision 39.4, but only to supply the
    Recognition section — its own `verdict` field is discarded whenever a
    prior reason exists. Only when no prior reasoning exists at all (Search's
    manual title/author/ISBN lookup) does the detail page use that call's
    `verdict` field too. Either way, the call happens at most once per book,
    ever — this is what decision 33's caching applies to.
38. **[Stage 1] Missing synopsis fallback**: a short, calm line — "No
    synopsis available for this edition." — not a silently empty section.
    Consistent with the app's existing pattern of being honest about known
    data gaps rather than hiding them.
39. **[Stage 1 — FULL content architecture, supersedes the bare-bones
    version in decision 31] Book detail page, section by section, in
    order:**
    1. **Identity** — cover (full, real proportions, aspectFit, never
       cropped for effect), title, author.
    2. **At-a-glance strip** — one row of small, consistent, scannable
       facts: page count, publication year, estimated reading time (a
       real computed number — pages ÷ an assumed average reading pace),
       genre tag(s). The goal: understand the shape of the book/commitment
       in two seconds, before reading any prose. Publication year isn't
       currently in `Book`/the metadata pipeline — add it (Google Books'
       `publishedDate` / Open Library's equivalent).
    3. **The AI verdict** ("why this fits you," decision 33) — personal,
       reader-specific reasoning. Placed prominently, right after the
       at-a-glance strip — this is the page's actual differentiator, not
       something buried under a synopsis.
    4. **Recognition** (best-effort, may not appear on every book) —
       awards and what makes this book notable/distinctive, both
       *objective* facts (not personal to the reader, unlike the verdict).
       Honest technical constraint: neither Google Books nor Open Library
       has a structured "awards" field — this data, when it exists at
       all, is typically embedded as plain text inside the description
       (e.g. Beloved's summary literally contains "PULITZER PRIZE
       WINNER"). **[AMENDED — new endpoint instead, not a shared prompt]**
       The original spec here said to generate Recognition via the same AI
       call that produces the verdict, extending decision 37's reuse
       principle to avoid a second call. In practice that meant adding a
       recognition field to `recommend.js`/`vibe-search.js`/`daily-picks.js`'s
       existing prompts — and those three have now hit the exact same
       `max_tokens` truncation bug *twice* (see decision 21's pattern note)
       from changes with far smaller footprints than this. Risking their
       now-hard-won stability for a best-effort section wasn't worth it.
       **Actual approach**: a new endpoint, `book-verdict.js`, is called
       once per book, always — regardless of whether a prior reason exists.
       It returns both `verdict` and `recognition`. When a prior reason
       exists (decision 37), only `recognition` is used and the response's
       `verdict` is discarded; when it doesn't, both are used. Net effect:
       still exactly one AI call per book, ever, cached per decision 33 —
       the "don't add a second call" goal is preserved, just via a
       dedicated small endpoint instead of three already-stable ones.
       Omit the section cleanly when `recognition` comes back null — never
       fabricate an award that isn't actually evidenced in the source text.
    5. **Synopsis** (decision 38's fallback applies here).
    6. **Actions** — status-dependent per decision 31, anchored where
       always reachable. In practice this also had to cover the
       reading-to-finished transition itself: nothing in the app had ever
       called `placeOnShelf` from any UI before this — a "Finished — place
       on a shelf" action on the `reading` state, and a "Re-place on a
       shelf" action on `finished`, are this page's way of closing that gap,
       not scope beyond decision 31's intent.
    Formatting principle across the whole page: consistent, easy to parse
    at a glance — the at-a-glance strip in particular should render
    identically in structure every time (same order, same visual
    treatment), not vary book to book.
    **Built** — `BookDetailView.swift` rewritten to this section order;
    `book-verdict.js` added; `publicationYear` added to `Book` and to all
    four backend `lookupBook()` implementations; `LibraryEntry` gained
    `cachedVerdict`/`cachedRecognition`/`verdictCachedAtFinishedCount`
    (decision 33's cache), with an in-memory session-only cache in
    `LibraryStore` covering books not yet on a shelf. Compiles clean
    (`xcodebuild build` succeeded); not yet walked through on a simulator/
    device — treat as implemented, not yet verified end-to-end.

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

## Screens (current — 5-tab architecture per decisions 12, 24, 25, 28)
1. **Onboarding** — pick up to 5 genres, one-time, first launch only.
2. **Today** — once-daily ritual (decision 24): exactly 3 curated picks per day,
   want-to-read / not-interested decision on each. Hero "Currently Reading" status
   card (decision 17/18) shows alongside undecided daily picks, or alone once
   they're decided. No manual refresh control (decision 4) — this is a fixed daily
   cadence, not a browsable feed.
3. **Search** (decision 25) — real search by title/author/ISBN, plus AI-personalized
   discovery rows (the taste-anchored + discovery row model from decision 19/20,
   relocated here from Today).
4. **Find (Vibe Search)** — free-text mood/vibe search (decisions 10, 13, 14).
5. **Shelf** — three shelves (keep forever / glad I read it / should've stopped),
   each a row of spines. Tap a spine → detail sheet with the AI "why you liked it"
   note + any highlights.
6. **Profile** (decision 28) — basic reading stats + app settings. Intentionally
   minimal for now.

Vault (a separate highlights/quotes screen) was in an earlier draft of this spec but
isn't part of the current 5-tab architecture — highlights still exist on the data
model (`LibraryEntry.highlights`) and surface within book detail views; a dedicated
Vault tab isn't currently planned. Revisit only if it becomes clearly needed.

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
  about its Vercel endpoint URLs, nothing about Anthropic or Google Books directly.
