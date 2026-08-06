Dogear — project brief for Claude Code
What this is

An iOS app (SwiftUI, iOS 17+) that curates a reader's personal library and continuously
recommends new books based on an AI reading of their taste. Name: Dogear (the folded
page corner every reader recognizes — tactile, unpretentious, no explanation needed).

Architecture (locked — don't relitigate this each session)
Client: SwiftUI, iOS 17+, MVVM. State lives in LibraryStore (ObservableObject),
injected via .environmentObject. No third-party dependency managers needed for v1 —
keep it Apple-native (URLSession, Codable, SwiftData for persistence).
Persistence: SwiftData (not Core Data, not a remote DB) is still the intended v1
end state — local-first, library lives on-device, CloudKit sync only after core UX
is solid. [UPDATED — Launch Roadmap Stage 0] LibraryStore.entries (shelf status,
reading progress, goals) was confirmed in-memory-only and losing the entire shelf
on every force-quit — this was fixed as a stopgap via the same UserDefaults JSON
pattern already used for shownBooks/notInterestedBooks/todaysPicks/recommendation
Rows (entriesKey + persistEntries(), called from every entries-mutating method,
loaded in init()). Confirmed on a real device: add a book, start reading, set page
+ goal, force-quit, reopen — everything survives. The data-loss risk is closed.
The full SwiftData migration described below is still the legitimate long-term
answer (proper schema, CloudKit-readiness, no hand-rolled encode/decode) — it's
just no longer an urgent blocker, and can happen on its own schedule rather than
gating everything else.
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
the "start reading" flow, midpoint check-ins (decision #5). This turns My Shelf
from a static list into the actual product. [UPDATED — Launch Roadmap Stage 0]
This no longer blocks on a SwiftData migration — entries persistence was fixed via
the UserDefaults JSON stopgap (see Persistence, above). SwiftData is still the
right long-term migration, just no longer a Phase 3 dependency.
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
MidpointCheckIn, Highlight, Recommendation. Migrate the existing plain structs to
@Model classes for SwiftData when you start Week 1 persistence work.

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
conflict with the "no push notifications" rule below.
Signature interaction: press-and-hold a book cover to fold its corner down —
this is how you save/bookmark, not a heart or generic bookmark icon.
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
candidates — exactly the "user behavior warrants it" condition Walker
specified — not a default aging or capping policy. Log whenever this
fallback actually fires, so we can see how often it's really needed
rather than guessing.
Reading history sent to the backend must be recency-ordered, and the prompts
must say so explicitly — e.g. "entries below are ordered most-recent-first;
weight recent shelf placements more heavily than old ones, and if the pattern
is shifting (e.g. recent picks trend toward a different tone/genre than older
ones), follow the recent trend, not the historical average." This applies to
recommend.js's existing prompt too, not just new work.
Vibe search must blend the typed query with the reader's actual taste
profile, not interpret it as a cold, context-free phrase. vibe-search.js
needs the same profile inputs recommend.js gets (onboarding genres, shelf
placement history, why-liked-it notes) alongside the free-text query, and its
system prompt should explicitly instruct the model to filter/interpret the
vibe through that specific reader's taste — "atmospheric and slow" should
produce different results for two readers with different histories.
[AMENDED, then further superseded by decision 12] Vibe Search ("Find")
has its own tab — originally added as a 2-tab (Today/Find) amendment,
now simply one of the full 5 tabs per decision 12. Today and Find remain
distinct surfaces: Today is the once-daily curated ritual (decision 24),
Find is on-demand, query-driven discovery blended with taste (decision 10).
[AMENDED — full 5-tab bar now] Build the full tab bar: Today, Search,
Vibe (Find), Shelf, Profile. The earlier "no empty placeholder tabs"
reasoning held while Search/Shelf/Profile had no real content — they now
do (see the Today/Search redesign below and decision 25).
The initial Vibe Search interface is free text only. No genre dropdowns,
filters, sliders, or structured controls beside the text field, ever, at entry.
Contextual one-tap refinements (e.g. "slower," "less dark," "more
literary") may appear only after results are returned — generated/selected
based on the original query and current results, not a permanent generic
filter set. Tapping one refines the existing query while preserving the
original search context.
The Dogear Design System (docs/Dogear_Design_System_v0_1_1_.docx in this
repo) is the source of truth for all visual and interaction design — colors,
typography, spacing, radii, motion, haptics, component anatomy, and screen
specs. Do not invent new visual patterns when the system already documents
one.
Do not begin Phase 3 work during the Vibe Search / design-system pass —
historical note, that pass is done; kept for record.
[Phase 3 opening] Today shows a "Currently Reading" hero status card.
The hero card shows cover, title, author, page progress, and (if set) a
reading goal with a pace indicator. If nothing is currently being read,
the card invites starting something from the shelf — never a blank space.
Reading goals are: a target page count + a target date, set/edited
from the hero card. Progress is updated via simple manual page-number
entry/stepper — no quick-add buttons, no slider. The app computes a pace
indicator (on track / behind) from current page vs. the goal's timeline.
[SUPERSEDED — see decision 24] The old row-based Today model. Rows are
dynamically generated and specific to the reader — not fixed genre buckets.
Mix of taste-anchored rows (grounded in specific books/patterns from real
history, honest specific titles — "Because you loved Beloved," not "More
Fiction") and at least one explicit discovery/stretch row. This row model
no longer lives on Today — it moved to the Search tab (decision 25). The
underlying engine is NOT thrown away — repurposed to power Search's
default browsing content instead of Today's feed.
These rows reuse the existing recommendation engine, not a parallel
system — same shown-book exclusion (decision 8), recency-weighting
(decision 9), and taste-blending (decision 10). Still true under decision
24/25 — just serving Search instead of Today now.
Reliability: backend book-metadata lookups (Google Books → Open
Library fallback) must not let one book's failure take down the whole
recommendation/vibe-search response — wrap per-book lookups so a single
failure degrades gracefully. Function timeouts generous enough to cover
Claude's response time plus metadata lookups with retries.
(intentionally reserved — no content; renumbering avoided to prevent
invalidating other decisions' cross-references. If a real decision 22 is
needed later, insert it here.)
[Phase 4 reference — do not act on this yet] A finished brand board
exists at docs/brand-board.png. When Phase 4 actually starts, this
board — not the current placeholder palette or docs/Dogear_Design_System_v0_1_1_.docx
— is the intended source of truth. It includes: a real app icon (green
rounded-square with a dog-ear/dog-profile mark), a refined palette
(
#0F2B22, 
#2E4A3A, 
#F6F1E7, 
#E7DECA, 
#C79A62 — distinct from
the current 
#1F3A2E-based placeholder set), Playfair Display for
headlines paired with Inter for body/UI text, and color-coded shelf
spines matching decision #2/#3's three shelves (deep green for "keep
forever," warm tan for "glad I read it," oxblood/rust for "should've
stopped"). It also shows a fully designed 5-tab bar (Home / Discover /
Ask Dogear / Library / Profile) — this has now been substantially
adopted early (decisions 12/24/25), ahead of the original Phase 4
timeline. Phase 4's remaining job for this board is matching its exact
visual execution (icon, palette, typography, shelf art) — not the tab
structure, which already exists. Do not start building toward this
board's exact visuals during Phase 3 work.
[Major Today redesign, replaces decision 19's row model on Today]
Today becomes a once-daily ritual, not a browsable feed. Once per
calendar day, the reader is shown exactly 3 curated picks. For each,
a binary decision: want to read (adds to shelf, status
wantToRead — does NOT auto-start reading, see decision 26) or
not interested (dismissed — see decision 27). Today's screen
composition: if the reader has a currently-reading book AND today's 3
picks aren't fully decided yet, show BOTH at once — hero card on top,
undecided daily picks below. Once all 3 are decided, that section
clears until tomorrow's picks generate. Much smaller, simpler generation
task than the old row model (3 books once a day vs. 2-3 rows of 4-6 on
every refresh) — expect this to be meaningfully faster and more reliable
by construction.
New Search tab. Two things live here: (1) real search by title,
author, or ISBN against the existing Google Books/Open Library metadata
lookups. (2) The AI-personalized row-browsing experience from the old
decision 19 lives here now — same engine, same taxonomy, same
exclusion/recency/taste-blending (decisions 8-10, 20), just relocated
from Today to Search.
"Want to read" and "start reading" are always separate, explicit
actions. Adding a book to the shelf (from Today, Search, or Vibe
Search) never automatically starts it as currently-reading. Starting
to read is a deliberate action from My Shelf.
"Not interested" is a real but moderate negative signal — not as
strong as "should've stopped" on a finished book, but a definite push
away from that pattern in future recommendations. Track it distinctly
from shelf placements, factor it into both Today's daily picks and
Search's rows.
Profile tab scope, for now: basic reading stats (books finished,
current streak or similar) plus app settings. Real content, not a
placeholder, but intentionally minimal.
Design identity
Palette: unchanged from the earlier prototype and still the right call — deep
forest 
#1F3A2E, ink 
#16241D, linen 
#EFE9D8, brass 
#C08A3E, rust 
#9B4B3A.
Dark backgrounds pair with warm accents — no gradients, no neon.
Type: serif display (system serif is fine — .system(.title, design: .serif),
italicized for headers) paired with system sans for UI chrome/labels.
Signature element: the dog-ear fold itself becomes the core interaction —
press and hold a corner of a book cover and it visually folds down.
Full CDS-style rules: no more than 2 accent colors on screen at once, sentence case
everywhere, no filler copy ("simply", "just", "seamlessly").
Screens (current — 5-tab architecture per decisions 12, 24, 25, 28)
Onboarding — pick up to 5 genres, one-time, first launch only.
Today — once-daily ritual (decision 24): exactly 3 curated picks per day,
want-to-read / not-interested decision on each. Hero "Currently Reading" status
card (decision 17/18) shows alongside undecided daily picks, or alone once
they're decided. No manual refresh control — fixed daily cadence, not a
browsable feed.
Search (decision 25) — real search by title/author/ISBN, plus AI-personalized
discovery rows (relocated here from Today).
Find (Vibe Search) — free-text mood/vibe search (decisions 10, 13, 14).
Shelf — three shelves (keep forever / glad I read it / should've stopped),
each a row of spines. Tap a spine → detail sheet with the AI "why you liked it"
note + any highlights.
Profile (decision 28) — basic reading stats + app settings.

Vault (a separate highlights/quotes screen) isn't part of the current 5-tab
architecture — highlights still exist on the data model and surface within book
detail views; a dedicated Vault tab isn't currently planned.

What NOT to build in v1
No social features.
No account system / login — local-first, single user, no backend user table.
No remote/server push notifications. (Midpoint check-in's local notification is fine.)
No in-app purchases / monetization.
No star ratings, no thumbs, no numeric score of any kind — see decision #2.
Working agreement for this project
Optimize for a working app on a real device, not architectural purity.
When in doubt between "more features" and "polish what exists," polish.
Every AI-generated string must degrade gracefully — clear retry state, never a
blank screen or crash.
- Keep `backend/` and `ios/` as separate concerns; the iOS app should only ever know
  about its Vercel endpoint URLs, nothing about Anthropic or Google Books directly.