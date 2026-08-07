Dogear — project brief for Claude Code
What this is

An iOS app (SwiftUI, iOS 17+) that curates a reader's personal library and continuously
recommends new books based on an AI reading of their taste. Name: Dogear (the folded
page corner every reader recognizes — tactile, unpretentious, no explanation needed).

Architecture (locked — don't relitigate this each session)
Client: SwiftUI, iOS 17+, MVVM. State lives in LibraryStore (ObservableObject),
injected via .environmentObject. No third-party dependency managers needed for v1 —
keep it Apple-native (URLSession, Codable, SwiftData for persistence).
Persistence: SwiftData (not Core Data, not a remote DB) is the eventual, ideal
answer for v1, but is NOT what's currently implemented. Current state (fixed,
verified working): LibraryStore.entries persists via the same simple
UserDefaults JSON-encoding pattern used for the store's other persisted properties
— confirmed on a real device that shelf status, reading progress, and goals all
survive a force-quit. This was a deliberate, lower-risk stopgap chosen over an
urgent full SwiftData migration when total data loss was discovered and fixed. The
full SwiftData migration remains a legitimate future improvement (better querying,
eventual CloudKit sync), but is no longer an urgent, blocking data-loss risk — don't
treat it as more urgent than it currently is.
Backend: Vercel serverless functions in backend/api/ — recommend.js and
why-liked-it.js exist; vibe-search.js is new in Phase 2 (see below). All hold
ANTHROPIC_API_KEY server-side and call the Anthropic Messages API
(model: claude-sonnet-5 — verify this string is still current before using it in
new endpoints; it has been wrong once already in this project's history). The iOS
app never talks to Anthropic directly.
Book metadata: two sources, in order — Google Books API (server-side, with
GOOGLE_BOOKS_API_KEY env var, since unauthenticated calls hit quota almost
immediately) as primary, falling back to Open Library (openlibrary.org/search.json,
no key needed) whenever Google's result is empty or its API errors out (it has shown
intermittent backendFailed 503s in production — this is a known Google-side
reliability issue, not something to keep debugging on our end). Any new endpoint that
needs book metadata should use this same two-source pattern, not just Google alone.
Auth to backend: a shared secret header (X-App-Secret), checked against
APP_SHARED_SECRET env var on Vercel. Not real security, just abuse prevention —
fine for v1, revisit before any public launch with real user accounts.
Roadmap — locked, in order, do not reorder or skip ahead

This is the actual plan going forward. If any future session (Claude Code or otherwise)
proposes jumping ahead to a later phase before the current one is genuinely done, or
silently reordering these, stop and flag it explicitly instead of just doing it.

Phase 1 — done. Onboarding (genre picks), Today screen with real AI
recommendations, tap-to-detail, add to shelf, a basic My Shelf screen, real cover
art (Google Books + Open Library fallback, https-only URLs).
Phase 2 — Vibe search (current phase). The standout feature: a search
experience where the reader types free text — a mood, a sentence, a vibe, not a
genre — and gets AI-curated book matches. See "Vibe search spec" below. This is
what differentiates Dogear from Goodreads/StoryGraph-style trackers; treat it as
a first-class feature, not an experiment bolted onto Today.
Phase 3 — Real organization. The three-shelf placement system (decision #2/#3),
the "start reading" flow, midpoint check-ins (decision #5), and the SwiftData
persistence migration this all depends on. This turns My Shelf from a static list
into the actual product. Status: Stage 0 of this phase (per LAUNCH-ROADMAP.md)
is CLOSED — persistence fixed and verified, the Today hero moment rebuilt and
refined, recommend.js/vibe-search.js confirmed reliable under heavy real-world
exclusion load, and the midpoint check-in built and verified end-to-end. See
LAUNCH-ROADMAP.md for the authoritative, detailed stage-by-stage status — this
file holds the locked decisions, that file holds current progress. Stage 1 (the
book detail page, decisions #31-34 below) is next and is spec'd but not yet built —
do not start Stage 1 code without the dedicated planning/inspect-and-plan pass,
same discipline as the design system and Vibe Search got.
Phase 4 — Design pass. Real app icon and brand colors — see decision #23 below,
which now supersedes the placeholder forest/ink/brass palette — the fold-gesture
signature interaction (decision #6), empty states, loading polish. Deliberately
last — no point polishing screens whose shape Phase 2 and 3 are still going to
change.
Phase 5 — Real-world testing + TestFlight.
Vibe search spec (Phase 2)
New backend endpoint: backend/api/vibe-search.js. Same auth pattern
(X-App-Secret), same book-metadata enrichment pattern (Google Books → Open
Library fallback) as recommend.js — copy that structure, don't reinvent it.
Input: free-text string from the reader (a sentence, a mood, a handful of words —
"something atmospheric and slow like a rainy Sunday," "books that feel like a
Fleetwood Mac album," etc.). No structured fields, no genre dropdown alongside it —
the text box IS the whole interface.
The system prompt for this endpoint should interpret tone, pacing, mood, and
imagery from the input, not just keyword-match genres. Reuse the same "real,
findable, in-print books only" and "one specific sentence, not generic praise"
rules from recommend.js's prompt.
This does NOT replace Today or Search — it's the on-demand, query-driven surface,
sitting alongside them (see decisions 24, 25).
Data model (already scaffolded in ios/Models/Book.swift)

Book, Genre (fixed onboarding list), ShelfPlacement (keepForever / gladIReadIt /
shouldveStopped — this IS the rating, there is no star score anywhere in this app),
LibraryEntry (status: wantToRead/reading/finished/dnf, dateStartedReading,
shelfPlacement, AI-generated "why you liked it" note, midpointCheckIn, highlights),
MidpointCheckIn, Highlight, Recommendation.

Product decisions (locked in conversation with Walker — do not silently deviate)
Onboarding: first launch asks the reader to pick up to 5 genres from the fixed
Genre enum. No book search, no CSV import, no taste quiz. Straight into Today
afterward with recommendations seeded from those genres alone.
No star ratings anywhere. Finishing a book means placing it on one of three
shelves (ShelfPlacement) — that placement is the only signal the AI gets about
how the reader felt. Never add a 1-5 or thumbs mechanism back in.
Shelf is organized by the three shelves, not a flat grid of every book. Within
each shelf, books still render as spines (visual language from prototype.html).
[AMENDED after on-device testing] Recommendation refresh is earned, not
scheduled. New picks generate automatically whenever a book is placed on
a shelf. There is no daily timer and no manual "ring the bell" control —
that UI element is cut. Find (Vibe Search) and Search (decision 25) are
now the on-demand discovery surfaces, making a separate manual refresh
redundant. Today's own cadence is now the once-daily model (decision 24),
not a continuously-refreshing feed at all.
Mid-book check-in: exactly once per book, 5 days after it's marked "reading"
(LibraryEntry.dateStartedReading + 5 days, see midpointCheckIn.askedOn). A single
yes/no prompt: "still enjoying this one?" This requires a local notification
(UNUserNotificationCenter) to surface at the right time even if the app isn't
open — this is a local, on-device notification, not a server push, so it doesn't
conflict with the "no push notifications" rule below. Built and verified
end-to-end — real notification scheduling, real UI prompt, answer persists and
reaches the backend payload.
Signature interaction: press-and-hold a book cover to fold its corner down —
this is how you save/bookmark, not a heart or generic bookmark icon. Not yet built
— Phase 4 work.
The recommendation engine and vibe search are the product, not a feature.
When either needs a tradeoff between "ship something plausible" and "actually
reason well about this specific reader/query," take the slower, better-reasoned
path. This is explicitly the thing meant to beat other book trackers — don't let
it regress to generic genre-matching to save time.
[AMENDED after real-usage data] Never recommend a book already on the
reader's shelf (any status: want-to-read, reading, finished, dnf) — this
never changes, no exceptions. For books already shown but not shelved
(shownBookIDs): the default is still never-repeat. However, if a
request would return fewer than the minimum floor even after the
existing retry, the backend may backfill remaining slots from the
oldest entries in shownBookIDs (least-recently-shown first) rather
than returning a thin or empty result. This is a scarcity fallback that
only activates when real usage has genuinely exhausted fresh
candidates — not a default aging or capping policy. Log whenever this
fallback actually fires.
Reading history sent to the backend must be recency-ordered, and the prompts
must say so explicitly — weight recent shelf placements more heavily than old
ones, and if the pattern is shifting, follow the recent trend, not the historical
average.
Vibe search must blend the typed query with the reader's actual taste
profile, not interpret it as a cold, context-free phrase. vibe-search.js
needs the same profile inputs recommend.js gets alongside the free-text query —
"atmospheric and slow" should produce different results for two readers with
different histories.
[AMENDED, then further superseded by decision 12] Vibe Search ("Find")
has its own tab — now simply one of the full 5 tabs per decision 12. Today
and Find remain distinct surfaces: Today is the once-daily curated ritual
(decision 24), Find is on-demand, query-driven discovery blended with taste
(decision 10).
[AMENDED — full 5-tab bar now] Build the full tab bar: Today, Search,
Vibe (Find), Shelf, Profile.
The initial Vibe Search interface is free text only. No genre dropdowns,
filters, sliders, or structured controls beside the text field, ever, at entry.
Contextual one-tap refinements (e.g. "slower," "less dark," "more
literary") may appear only after results are returned — generated/selected
based on the original query and current results, not a permanent generic
filter set. Built and working.
The Dogear Design System (docs/Dogear_Design_System_v0_1_1_.docx in this
repo) is the source of truth for all visual and interaction design.
(historical — the Vibe Search/design-system pass this referred to is complete.)
[Phase 3] Today shows a "Currently Reading" hero status card. Built,
rebuilt once after initial dissatisfaction, refined into its current working
form.
Reading goals are: a target page count + a target date, set/edited
from the hero card. Progress via manual page-number entry/stepper. Ambient
pace-comparison language ("ahead/behind") is explicitly NOT used anywhere
passive — see the neutral stats-line resolution below. Reader-initiated
goal-setting guidance ("X pages a day to stay on track," shown only in
ReadingProgressSheet when actively setting a goal) is fine and stays.
[SUPERSEDED — see decision 24] The old row-based Today model. Rows moved
to the Search tab (decision 25). Engine not thrown away, repurposed.
These rows reuse the existing recommendation engine — same shown-book
exclusion (8), recency-weighting (9), taste-blending (10). Now serving Search.
Reliability: backend book-metadata lookups must not let one book's failure
take down the whole response. [Update] A heavy-exclusion investigation found
the deeper cause of intermittent failures was max_tokens truncation on harder
rows — fixed (2000→4096 + a second retry). Known, accepted remaining risk: a
worst-case row needing all 3 attempts could theoretically approach the 60s
maxDuration — not observed, not ruled out.
[Pattern to watch for] This has now silently bitten two separate "make the
AI reasoning better" changes: recommend.js's harder secondary/discovery rows,
then vibe-search.js's decision #35 reason-binding rewrite (fixed 2200→4096).
Both times the failure was the same — longer, more specific per-book
reasoning pushed the response past max_tokens and truncated the JSON — and
both times it was caught by live testing after the fact, not anticipated.
Any future prompt change that asks a row/endpoint for longer or more
specific reasoning (more detail per pick, more books per response, more
context to weave in) must have its max_tokens budget checked against that
requirement BEFORE shipping, not discovered by a truncated response later.
(intentionally skipped — no content, gap preserved to avoid invalidating other
decisions' cross-references.)
[Phase 4 reference — do not act on this yet] A finished brand board exists at
docs/brand-board.png. This is the intended source of truth for Phase 4's
visual execution (icon, palette 
#0F2B22/
#2E4A3A/
#F6F1E7/
#E7DECA/
#C79A62,
Playfair Display + Inter, color-coded shelf spines — keep forever=green, glad I
read it=tan, should've stopped=oxblood/rust, vertically stacked per Walker's
later note). The board's 5-tab structure has already been substantially adopted
early (decisions 12/24/25) — Phase 4's remaining job is matching the visual
execution, not the tab structure. Do not start on this during Phase 3 work.
[Major Today redesign] Today is a once-daily ritual, not a browsable feed.
Once per calendar day, exactly 3 curated picks, each a binary want-to-read /
not-interested decision. If a currently-reading book exists AND today's 3 aren't
fully decided, show both — hero card on top, undecided picks below. Built and
working.
Search tab. Real title/author/ISBN search + the relocated AI row-browsing
engine. Built and working.
"Want to read" and "start reading" are always separate, explicit actions.
"Not interested" is a real but moderate negative signal — lighter than
"should've stopped," tracked distinctly from shelf placements.
Profile tab scope, for now: basic reading stats + app settings, intentionally
minimal.
[FINAL, as built] Today's header: no "DOGEAR" wordmark. Time-aware greeting
("Good morning," / "Good afternoon," / "Good evening," — WITH a trailing comma
when a name follows, no comma when blank) stacked on its own line, with the
reader's FIRST NAME ONLY on the line below when set. Name source for now: an
optional "Your name" field in Profile settings. Forward note: once real
accounts/login exist (future phase, not v1), this manual field gets replaced by
the real account name.
My Shelf reorganization: real sections, in order — Currently Reading
(full list, can be multiple books — distinct from the hero card's single-book
spotlight on Today), Want to Read (same list Today's "Up Next" previews),
then the three finished shelves: Keep Forever, Glad I Read It,
Should've Stopped. Built and verified with real data.
[Stage 1 spec — planned, NOT yet built] Book detail page — core content and
behavior. Every entry point (Today, Search, Vibe Search, My Shelf) opens the
same detail view. Shows: cover, title, author, page count, real synopsis, and
the AI's personal "why this fits you" verdict (decision 33). Actions depend on
status: not on shelf → add/want to read; want to read → start reading; reading
→ update page/view goal; finished → shelf placement, re-placeable. No
highlights (decision 32). No external reviews (decision 34). A camera/scan
entry point was considered and explicitly cut — Vibe Search remains the sole
standout feature by deliberate choice; don't reintroduce scanning without a real
product conversation first.
Highlights stay off the detail page. Still in the data model, not surfaced
here.
The "why this fits you" verdict: one specific reasoning sentence, same
quality bar as decision 7. Generated once, cached; regenerate only if the
reader's finished-book count has changed since generation.
No external reviews/ratings anywhere on the detail page. Purely personal.
[Priority pass] Vibe Search AI quality — closing the gap between "plausible"
and "genuinely great." Real evidence: the same handful of books (Beloved,
Piranesi, Convenience Store Woman, Norwegian Wood, Housekeeping) recur across
different queries — the model defaults to a "canon" rather than genuinely
searching wide. Fix via prompt work: (1) explicit anti-cliché instruction; (2)
require considering multiple honest interpretations of an ambiguous query before
committing; (3) reasoning must reference the reader's actual query words, not
just the general mood category. May cost more time/tokens — approved
explicitly. Explicitly NOT in scope: visual styling stays on current tokens,
Phase 4 boundary holds.
Design identity
Palette: current placeholder — deep forest 
#1F3A2E, ink 
#16241D, linen

#EFE9D8, brass 
#C08A3E, rust 
#9B4B3A. Superseded by decision 23's brand
board palette once Phase 4 starts.
Type: serif display (system serif, .system(.title, design: .serif),
italicized for headers) paired with system sans for UI chrome/labels.
Signature element: the dog-ear fold — press and hold a book cover to fold its
corner down as the save/bookmark gesture. Not yet built (Phase 4).
No pace-pressure or ambient judgment language anywhere passive (decision 18) —
calm, factual information only, unless the reader actively asked (e.g. goal-setting
guidance).
No more than 2 accent colors on screen at once, sentence case everywhere, no
filler copy.
Screens (current — 5-tab architecture)
Onboarding — pick up to 5 genres, one-time, first launch only.
Today — once-daily ritual (24): 3 curated picks, want-to-read/not-interested.
Hero card (17/18) + Up Next preview of want-to-read (once picks decided) +
midpoint check-in card when due.
Search (25) — real title/author/ISBN search + AI-personalized discovery rows.
Find (Vibe Search) — free-text mood search (10, 13, 14, 35).
Shelf (30) — Currently Reading, Want to Read, then the three finished
shelves.
Profile (28) — basic stats + settings (including the name field, decision 29).
What NOT to build in v1
No social features.
No account system / login (decision 29's forward note records the future intent).
No remote/server push notifications (the midpoint check-in's local notification is fine).
No in-app purchases / monetization.
No star ratings, no thumbs, no numeric score of any kind.
No camera/scan-based book identification (decision 31 — explicitly considered and cut).
Working agreement for this project
Optimize for a working app on a real device, not architectural purity.
When in doubt between "more features" and "polish what exists," polish.
Every AI-generated string must degrade gracefully — clear retry state, never a
blank screen or crash.
Keep backend/ and ios/ as separate concerns; the iOS app should only ever know
about its Vercel endpoint URLs, nothing about Anthropic or Google Books directly.
Big visual/architectural pivots get a real planning conversation and a locked spec
before any code — no same-session "I saw this, let's redo that" jumps, even when
the inspiration is good.