# Dogear — one-month build plan

Each week ends with something you can open on your phone and use, not just code that
compiles. If a week slips, cut from the "cut list" in CLAUDE.md before you cut into the
next week's time.

## Before week 1 (half a day, do this yourself)
- [ ] Apple Developer account ($99/yr) — start this first, it can take a day to activate.
- [ ] Create a GitHub repo, push this starter (`ios/`, `backend/`, `CLAUDE.md`, this file).
- [ ] Create a Vercel account, link the repo, deploy `backend/` as its own project.
- [ ] In Vercel project settings, add env vars: `ANTHROPIC_API_KEY`, `APP_SHARED_SECRET`
      (make up any random string for the secret — same value gets hardcoded in the iOS app).
- [ ] Confirm both endpoints respond: `curl -X POST https://your-app.vercel.app/api/recommend
      -H "x-app-secret: yoursecret" -H "content-type: application/json" -d '{"read_history":[]}'`
      should return 6 seed recommendations.
- [ ] Open Xcode, create a new iOS App project named Dogear, drag in the `ios/` files.

## Week 1 — onboarding + one real screen
Goal: a fresh install takes you from genre picks to real AI recommendations.
- Migrate `Book`/`LibraryEntry`/etc. structs to SwiftData `@Model` classes.
- Build the genre-picker onboarding screen (pick up to 5 from the fixed `Genre` list,
  one-time, first launch only — see CLAUDE.md decision #1).
- Wire `LibraryStore` to SwiftData for persistence (survives app relaunch).
- Point `RecommendationEngine` at your real Vercel URL + shared secret header.
- Get `TodayView` showing real recommendations seeded from onboarding genres, with real
  cover art, on a physical device (not just simulator — it masks real network latency).
- Build the "ring the bell" manual refresh control as a real, visible UI element.
- **Done when**: fresh install → pick genres → see real, relevant recommendations,
  and force-quitting/reopening the app doesn't lose anything.

## Week 2 — the core loop: shelves, not stars
Goal: finishing a book actually changes tomorrow's recommendations.
- "Start reading" action sets `dateStartedReading` and schedules the midpoint check-in.
- Local notification (`UNUserNotificationCenter`) fires 5 days later: "still enjoying
  this one?" — yes/no only, recorded on `MidpointCheckIn`.
- "Finish a book" flow: no star picker — the reader places it on one of the three
  shelves (keep forever / glad I read it / should've stopped). This triggers the
  `why-liked-it` backend call and an earned recommendation refresh.
- Archive screen: the three shelves as three sections, each a row of spines from the
  real library. Tap a spine → detail sheet with the AI note + highlights.
- **Done when**: you finish a book, place it on a shelf, and the next recommendation
  batch visibly reflects that placement — and a midpoint check-in actually fires on
  schedule for a book marked "reading."

## Week 3 — the vault, the fold gesture, and polish pass
Goal: it stops feeling like a prototype and starts feeling like a product.
- Press-and-hold-to-fold-corner gesture for saving/bookmarking (the signature
  interaction — see CLAUDE.md decision #6). Don't ship a placeholder heart icon instead.
- Highlight capture (manual entry for v1 — "add a quote" from a book detail screen is
  enough; OCR/camera capture is a fast-follow, not v1).
- Vault screen: all highlights, searchable.
- Empty states for every screen (empty shelves, no recommendations yet, no highlights).
- Loading states for every AI call (never a frozen screen while waiting on Claude).
- Error states: if the backend call fails, show "couldn't reach your library's brain —
  retry" with a retry button, not a silent failure.
- App icon + launch screen.
- **Done when**: you could hand the phone to someone with zero context and they
  wouldn't hit a broken or blank screen doing normal things, and the fold gesture is
  the actual save mechanism, not a stand-in icon.

## Week 4 — real-world testing + TestFlight
Goal: it survives contact with actual daily use.
- Use it for real for 3-4 days as your only book-tracking method. Note every friction
  point immediately (a running list, not memory).
- Fix the top 5 friction points, not all of them — a month is enough time to fix five
  things well, not everything adequately.
- TestFlight build, install on your device properly (not just Xcode's "Run").
- If you want feedback from anyone else, TestFlight external testing needs Apple's
  Beta App Review first — start that submission early in the week, not the last day.
- **Done when**: you'd genuinely reach for this instead of Goodreads or a notes app.

## Explicit non-goals for this month
Reading DNA visualization, social features, push notifications, and App Store public
launch are all out of scope for the 4 weeks above. They're listed in CLAUDE.md's cut
list for a reason — don't let scope creep back in mid-month.
