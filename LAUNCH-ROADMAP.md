# Dogear — Launch Roadmap

This is the honest, current-state roadmap to an actual launchable app. It replaces the
original WEEK-BY-WEEK.md, which was written before the daily-picks pivot and is now
stale. Read this top to bottom before starting any new work — the order matters.

**The one rule for using this document**: don't skip a stage because a later one seems
more exciting. Stage 0 exists because skipping foundational work is exactly what led to
the rough patch this roadmap is responding to.

---

## Honest current-state assessment

**What's real and working:**
- A genuine, differentiated recommendation engine: taste-blending, recency-weighting,
  never-repeat logic, "not interested" as a real signal — this is Dogear's actual
  competitive edge and it's built.
- Two real discovery modes: Today's daily-3 ritual, and Vibe Search's free-text mood
  matching.
- Three-shelf reflection system (keep forever / glad I read it / should've stopped)
  instead of star ratings.
- Reading goals with page/date targets and a pace indicator.
- A 5-tab navigation structure matching the intended final architecture.

**What's rough or unfinished — the actual gap between "features exist" and "ready to launch":**
- **Book detail page.** Repeatedly deferred, and it's the chokepoint every other
  feature funnels through. A great recommendation with a broken detail screen is a
  dead end for the person using the app. This is Stage 1, next up.
- No rate limiting or cost safety net if more than one person starts using the app.
- No privacy policy, no App Store assets, no real-user testing yet.

Everything else that used to be listed here — persistence, the hero moment redo,
Search/Vibe Search reliability under real exclusion load, and the midpoint check-in —
was Stage 0's job. Stage 0 is done; see below.

---

## Stage 0 — Stabilize (no new features, no new screens)

**STATUS: DONE. Closed, no open caveats.**

Goal: nothing gets built until the foundation is trustworthy.

1. **Confirm and fix persistence.** ✅ Done. `LibraryEntry` (shelf status, reading
   progress, goals, shelf placement) is fixed and verified on a real device: add a
   book, set a goal, force-quit, reopen — everything survives. (The full SwiftData
   migration is still the legitimate long-term architecture, per `CLAUDE.md`, but it's
   no longer a blocker — this was the urgent data-loss risk, and it's closed.)
2. **Confirm Search/Vibe Search hold up under real exclusion load.** ✅ Done.
   Re-tested against production with a realistic ~60-book `shown_books` exclusion
   list. vibe-search.js held up clean on the first pass. recommend.js initially still
   broke (2 of 3 rows falling back, the "More you might like" label reappearing) —
   root-caused to `max_tokens` truncation plus an insufficient retry count, fixed
   (`max_tokens` 2000→4096, one retry → two), and re-verified clean on production
   afterward: 3/3 rows real content, 0 backfilled, no retries even needed.
3. **Redo Today's post-decision moment.** ✅ Done. Rebuilt on the proven compact hero
   card (not the rejected full-bleed redesign), then refined through several real
   rounds of feedback: no pace/pressure language (calm factual stats line only),
   time-aware greeting redesign (first name only, stacked on its own line, correct
   punctuation), and the "DOGEAR" wordmark dropped as redundant with the tab bar.
4. **Confirm the midpoint check-in actually exists.** ✅ Done. It didn't — only the
   date-tracking data model existed, no notification, no UI, `answerMidpointCheckIn`
   was dead code. Built for real: `UNUserNotificationCenter` scheduling on
   `startReading` (permission requested in-context, not on cold launch), a real
   yes/no UI prompt on Today that surfaces the same way whether the reader taps the
   notification or just opens the app normally after the date passes, and the answer
   verified reaching `recommend.js`/`vibe-search.js` as `still_enjoying_midpoint` in
   the actual request payload.

Also caught and fixed in the same on-device pass, not originally scoped but real bugs
found along the way: tab bar icons, My Shelf reorganized into real sections (Currently
Reading / Want to Read / the three finished shelves, instead of one flat grid), and a
card-height alignment bug in Search's fallback-cover state (untruncated text growing
one card taller than its row neighbors).

**Done when**: you can use the app for several real days — adding books, setting a
goal, tracking pages, searching, vibe-searching — without a single moment of "wait,
where did that go" or "why did this fail again." Met.

---

## Stage 1 — Book detail page (dedicated session, treated like Vibe Search was)

**Next up — do not start on this until the planning conversation below happens.**

This gets the same treatment the design system and Vibe Search specs got: a real
conversation about what it needs to show and do, written into `CLAUDE.md` as its own
locked spec, before any code. Don't jump straight to implementation because Stage 0
closing makes this feel unblocked — it's unblocked to *plan*, not to *build* yet.

At minimum, it needs to handle every entry point consistently (Today's daily picks,
Search's rows and manual lookup, Vibe Search results, My Shelf) and show:
- Cover, title, author, page count
- The AI's specific reasoning for this book (already a locked principle — specific,
  not generic praise)
- A real synopsis
- Current status (not on shelf / want to read / reading / finished + shelf placement)
- Clear, unambiguous next actions for whatever state the book is in

**Done when**: tapping into any book, from anywhere in the app, feels complete —
never a blank or half-populated screen.

---

## Stage 2 — Core loop, end to end, for real

Not screen-by-screen testing — walk the entire loop as a real reader would, more than
once, with real books:

Open app → see today's 3 → decide → start reading something → update progress → set a
goal → get a midpoint check-in → finish the book → place it on a shelf → confirm
tomorrow's picks actually reflect that decision.

**Done when**: this loop works smoothly multiple times in a row, with no manual
workarounds and no "well, if you do it in this specific order it works."

---

## Stage 3 — Reliability & cost safety net (before any real tester touches this)

1. **Basic abuse/cost protection.** Right now there's a shared-secret header and
   nothing else — no per-user rate limiting. Before anyone besides you is using this,
   there needs to be a sane limit (even a simple one) so a bug or heavy use can't
   generate runaway Anthropic API costs.
2. **Basic error visibility.** You don't need a full monitoring stack, but you should
   be able to tell if something's failing in production without personally
   reproducing it via curl every time — Vercel's own logs are probably sufficient for
   this stage, just confirm you know how to check them without me walking you through
   it each time.

---

## Stage 4 — Design pass (Phase 4, now with a real, finished reference)

This is where `docs/brand-board.png` actually gets built toward, in full, now that the
functional app underneath it is stable:
- Real app icon
- The board's actual palette and Playfair Display typography, applied consistently
  app-wide — not just on one screen
- The fold-gesture signature interaction (decision 6)
- A genuine empty-state and loading-state pass across every screen

**Done when**: nothing in the app looks like a placeholder or a default component —
every screen looks intentionally designed, including the boring states.

---

## Stage 5 — Real user testing (people who aren't you)

1. TestFlight internal testing — a handful of real readers, not just you.
2. Watch where they get confused without prompting them — their confusion tells you
   things your own testing can't, precisely because they have no context.
3. Fix what actually causes friction for them, not just what you'd personally change.
4. If you want testers beyond your internal circle, Apple's Beta App Review adds its
   own timeline — start that early, not last-minute.

---

## Stage 6 — App Store launch requirements (business side, easy to underestimate)

- **Privacy policy** — required for submission, and genuinely necessary here since the
  app processes reading data and talks to Anthropic/Google Books on the reader's
  behalf.
- **App Store listing**: screenshots, description, keywords, app icon in required
  sizes.
- **Terms of service** — recommended, not strictly required, but worth having.
- **Monetization decision** — currently explicitly deferred (`CLAUDE.md`'s "What NOT
  to build in v1"). That's fine, but make it a conscious choice going into launch:
  free at launch, monetize later, stated plainly rather than left ambiguous.
- **App Review submission** — realistically 1-3+ days once submitted, plan the
  timeline around that, not around when the code is done.

---

## Stage 7 — Launch, then watch closely

- Monitor real Anthropic/Vercel costs once real people are using it — this is the
  first time cost will scale with usage you don't personally control.
- Have a real plan for collecting feedback post-launch, not just hoping people email
  you.

---

## What this roadmap deliberately does NOT include

Anything not already locked in `CLAUDE.md` stays out, on purpose: no new screens, no
new AI features, no social features, no monetization mechanics. If a good idea comes
up during any of these stages, it goes through the same discipline as everything
else — a real conversation, written into the spec, before it touches code.
