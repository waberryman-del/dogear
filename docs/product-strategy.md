# DOGEAR — PRODUCT DIRECTION & STRATEGY BRIEF

> **Status note (added by agreement with Walker):** This document is treated as
> validation and longer-term product direction, NOT a new requirements document.
> Do not implement features from this document without a real, dedicated planning
> conversation first — same discipline as every other major decision in this
> project. See `CLAUDE.md`'s pointer note for what's explicitly preserved,
> deferred, and in conflict with existing locked decisions.

Use this document as the current source of truth for the product direction of Dogear. We are actively building the app, so preserve existing working functionality unless a change is necessary to align the product with this direction.

When implementing features, UX, architecture, data models, onboarding, AI functionality, or monetization, use the principles below to guide decisions.

---

## 1. What Dogear Is

Dogear is an AI-powered personal reading companion that learns an individual reader's taste over time.

The core idea is NOT simply: "AI book recommendations."

The stronger product idea is: **Dogear learns your taste in books.**

Dogear should gradually develop a personalized understanding of: what books a user loves, what books they dislike, why they like or dislike certain books, genres they gravitate toward, themes they enjoy, writing styles they prefer, pacing preferences, character preferences, atmosphere and mood preferences, preferred book lengths, authors they enjoy, tropes they like or dislike, their reading habits, and how their taste changes over time.

The more someone uses Dogear, the better Dogear should understand them. The product should feel like a reading companion that genuinely knows the reader rather than a generic recommendation engine.

## 2. Core Product Thesis

Dogear should become: **the personal intelligence layer for someone's reading life.**

The core loop is: Read → Rate/React → Dogear Learns → Recommendations Improve → User Discovers Another Book → Reads → Dogear Learns More.

Every meaningful interaction should improve Dogear's understanding of the reader. This creates increasing value over time. A new Dogear account should be useful. A Dogear account with 50 books of history should be significantly better. A Dogear account with years of reading history should feel extremely personalized and difficult to replace.

## 3. The Most Important Product Principle

The emotional reaction we are trying to create is: **"This app actually understands what I like."**

That is more important than having the largest feature set. Do not turn Dogear into a generic Goodreads clone. We do NOT need to prioritize a massive social network, followers, social feeds, comments, likes, complex book clubs, badges, gamification systems, or large community features — unless they clearly strengthen the core Dogear experience later.

The initial product should remain focused. Library organization, ratings, reactions, AI discovery, and taste profiles exist primarily to help Dogear understand the reader.

## 4. Dogear's Main Differentiator

AI itself is NOT the differentiator. Users can already ask ChatGPT, Claude, Gemini, or other AI systems "What book should I read?" Therefore, Dogear cannot win simply because it uses AI.

Dogear's differentiation should come from **Persistent Taste Intelligence.** Dogear continuously develops a model of the user's literary taste. Generic AI knows books. Dogear knows the reader. That distinction should influence the entire product.

## 5. Understanding WHY Someone Likes a Book

Simple star ratings are not enough. Two people can both rate the same book five stars for completely different reasons.

For example, a reader could say: "I loved The Secret History because of the atmosphere, relationships, and writing. I don't particularly care about the murder mystery." Dogear should understand this distinction.

When possible, collect signals beyond ratings. Possible signals include: Loved it, Liked it, It was okay, Disliked it, Did not finish, Favorite, Would reread.

But more importantly, allow the reader to communicate WHY. Examples: "I loved the atmosphere." / "The romance annoyed me." / "The beginning was too slow." / "I loved the morally complicated characters." / "The world building was great but the writing wasn't." / "The ending ruined it for me." / "The book was beautiful but emotionally exhausting."

These signals should contribute to the user's Taste Profile.

## 6. Taste Profile

Dogear should maintain an evolving Taste Profile for every user. The Taste Profile is one of the most important concepts in the product.

It should eventually understand things such as:

**Things the reader tends to love** — Atmospheric books, morally complicated characters, literary prose, slow-burn relationships, historical settings, character-driven stories, books around 250–400 pages.

**Things the reader tends to dislike** — Exposition-heavy fantasy, extremely long series, romance-dominant plots, predictable endings, certain tropes, certain pacing styles.

The Taste Profile should NOT necessarily be a static questionnaire. It should evolve automatically through behavior. Users should also be able to correct Dogear. If Dogear thinks "You love murder mysteries," the user should potentially be able to say "Not really." That correction should influence future recommendations. The user should feel like they are teaching Dogear their taste.

## 7. Taste Evolution

An important long-term feature is understanding that people's taste changes. Dogear should eventually be able to recognize things like: "You've been enjoying literary science fiction more recently." / "You used to rate thrillers highly, but your ratings for them have declined over the last year." / "You've recently been gravitating toward shorter books."

This creates another reason for Dogear to remain valuable over time. The system should therefore avoid assuming that a user's taste is permanently fixed. Recent behavior may sometimes deserve more weight than very old behavior.

## 8. Library

The user's library is foundational. Users should be able to organize books into states such as: Want to Read / TBR, Currently Reading, Read, Did Not Finish. Potentially also: Favorites, custom collections/lists.

Importing an existing library is extremely valuable because it allows Dogear to understand a new user faster. Goodreads import or other library-import mechanisms should therefore be considered important.

The library is not merely organizational. The library provides the data that powers the Taste Profile.

## 9. Dogear Discovery / Natural-Language Book Search

One of Dogear's signature experiences should be the ability to describe almost ANY kind of reading desire in natural language. The user should not have to search primarily through conventional genre/category filters.

They should be able to type things like: "Something like Dune but less dense." / "A mystery where the setting is almost a character." / "Something my girlfriend and I could both read." / "A short book that will destroy me." / "Books that feel like autumn." / "I haven't read in six months. Give me something impossible to put down." / "Something philosophical without feeling like homework." / "Give me a weird book." / "I want something lonely and atmospheric that I can read on a rainy weekend. Nothing devastating, under 350 pages." / "Give me something similar to my favorite books but outside the genres I normally read."

Dogear should interpret (1) the explicit request and (2) the user's existing Taste Profile, and combine them. This is critical. A generic AI system responds to "Give me a weird book." Dogear should effectively respond to "Give THIS PARTICULAR PERSON a weird book." Those are different problems.

## 10. Recommendation Quality Over Quantity

Dogear should generally favor a smaller number of highly relevant recommendations rather than overwhelming users with dozens of books. Instead of "Here are 30 fantasy books," prefer "Here are the 3 books I think you're most likely to love."

Recommendations should feel intentional. Where possible, explain WHY the recommendation fits the person. Example: "92% Taste Match — Book Title — 'I'm recommending this because you consistently rate atmospheric, character-driven novels highly. It has the isolation you liked in [Book A], but isn't nearly as emotionally heavy as [Book B].'"

This explanation is important because it demonstrates that Dogear understands the reader.

## 11. Recommendation Explanations

Avoid generic explanations like "You might enjoy this because you like fantasy." Prefer specific reasoning derived from actual user taste.

Examples: "You tend to enjoy fantasy with strong character relationships but rate lore-heavy books lower. This has the former without requiring a huge amount of world-building." / "You loved the atmosphere of [Book A] and the character dynamics of [Book B]. This combines elements of both." / "You've recently been rating shorter literary novels highly, which makes this a strong fit."

Recommendations should ideally answer: Why this book? and Why this book for ME? The second question is much more important.

## 12. Trust

Recommendation trust is extremely important. If Dogear repeatedly recommends books the user dislikes, the product loses value quickly.

Therefore: do not recommend books merely because they are popular. Do not over-recommend the same famous titles. Avoid generic genre matching. Consider negative preferences. Consider DNF history. Consider explicit feedback. Consider contextual requests. Consider previous recommendations. Avoid repeatedly showing books the user has already rejected. Avoid recommending books already read unless the context explicitly calls for them.

Dogear should become increasingly precise as more information becomes available.

## 13. Cold Start

A major product challenge is helping Dogear understand someone quickly. New users have no Dogear history. The onboarding experience should therefore gather high-value taste signals without feeling like a tedious questionnaire.

Possible mechanisms: import Goodreads/library, select favorite books, select books they disliked, rate several familiar books, choose genres they frequently read, ask lightweight preference questions, allow users to explain why they loved certain books.

The goal should be: get Dogear to its first surprisingly good recommendation as quickly as possible. Do not make onboarding unnecessarily long. Imported historical data should reduce how much manual onboarding is required.

> **[Conflict with existing locked decision — see CLAUDE.md's pointer note.]**
> Decision #1 explicitly rules out book search/CSV import at onboarding. That
> locked decision wins for now; import is not being added on the strength of
> this document alone.

## 14. Personalization Architecture

When designing the backend/data model, do not treat personalization as an afterthought. The architecture should support storing and updating signals such as: book ratings, reading status, favorites, DNF, user reactions, explicit preference statements, recommendation impressions, recommendation clicks, saved recommendations, rejected recommendations, books subsequently added to TBR, books subsequently read, search/discovery prompts, recommendation feedback, preference strength, recency of preferences.

Where practical, preserve the underlying interaction data rather than storing only a final summarized Taste Profile. This gives us the ability to improve the recommendation model later without losing historical information.

## 15. Recommendation Feedback Loop

Recommendations themselves should generate useful signals. For example, users could indicate: Interested, Not for me, Already read, Save to TBR. Potentially allow reasons: "Too long." / "Not interested in this genre." / "Already seen this everywhere." / "Too dark." / "Looking for something faster paced."

These interactions should improve subsequent recommendations. The recommendation system should learn from both positive AND negative signals.

## 16. Dogear Should Remember Context

Dogear should feel persistent. If a user repeatedly says "I don't like romance-heavy books," Dogear should not require them to repeat this every time they search. If they later explicitly say "Actually, give me a romance," the immediate request can override the normal preference.

Think about recommendations as: Current request + long-term taste + recent behavior + relevant constraints — rather than merely sending the current prompt to an LLM.

## 17. Monetization Philosophy

Dogear should use a freemium model. The free product needs to be genuinely useful. Users need enough experience with Dogear to understand the value of personalization before being asked to pay. Do NOT put the entire recommendation experience immediately behind a paywall. The user should experience "Dogear understands me" before being asked to subscribe.

## 18. Proposed Free Tier

Possible free functionality: personal library, TBR, currently reading, read books, ratings, favorites, basic Taste Profile, library import, basic recommendations, limited AI discovery/search, limited number of personalized recommendations per week, basic lists/collections.

Exact limits are not finalized and should remain configurable.

## 19. Proposed Dogear+ Subscription

Target price: $7.99/month. Strongly consider an annual option around $49.99/year. Exact pricing can change after testing.

Dogear+ needs to feel substantially more valuable than basic book tracking. Potential premium functionality: unlimited AI discovery, deep Taste Profile, advanced taste insights, taste evolution/history, conversational recommendations, detailed recommendation explanations, advanced filters, unlimited smart collections, personalized reading reports, more recommendation controls, more sophisticated personalization, advanced reading statistics.

Do not arbitrarily paywall fundamental library functionality simply to manufacture subscription value. Premium value should come primarily from intelligence and personalization.

## 20. Target Customer

Do NOT initially design Dogear for every person who occasionally reads a book. The strongest early target customer is an enthusiastic reader: reads approximately 15–50+ books per year, maintains a TBR, uses Goodreads/StoryGraph/Fable/Bookmory/spreadsheets/notes or another reading system, watches or participates in BookTok/BookTube/Bookstagram, regularly searches for their next book, buys books frequently or uses a library heavily, has strong opinions about books, cares about finding books that specifically fit their taste, enjoys understanding their own reading habits.

For someone reading two books per year, a $7.99 subscription is probably difficult to justify. For a passionate reader who reads 30–50 books per year, Dogear can potentially provide substantial value.

## 21. Competitive Position

Relevant products: Goodreads, StoryGraph, Fable, Bookmory, generic AI assistants, other AI book recommendation tools.

Do not attempt to beat these products by copying all of their functionality. Dogear's strategic advantage should be: understanding the individual reader better. Goodreads can know "You like science fiction." Dogear should eventually know something closer to "You like science fiction when it is character-driven and philosophical, but tend to dislike extremely technical world-building. You prefer standalone novels, generally enjoy ambiguous endings, and recently have been gravitating toward books under 400 pages." That level of taste understanding is the goal.

## 22. Product Personality

Dogear should feel: intelligent, calm, personal, thoughtful, literary, modern, trustworthy, curious, human without pretending to be human.

Avoid making the AI overly chatty or gimmicky. Avoid excessive emojis, AI sparkle icons, "magic" terminology, robotic explanations, generic AI copy, tech jargon.

The user should primarily experience Dogear as a beautifully designed reading product, not as an AI demo. AI should power the experience quietly.

## 23. UX Principle

The interface should reduce friction between "I want something to read." and "That's exactly what I was looking for." Avoid making users navigate unnecessary menus or configure dozens of filters before receiving recommendations. Natural language should handle complicated discovery requests. Traditional controls and filters can complement it where useful.

## 24. Important Success Metrics

Do not optimize solely for downloads. Important metrics should eventually include: activation rate, number of books imported/added, time until first useful recommendation, recommendation save rate, recommendation → TBR conversion, recommendation → read conversion, recommendation rejection rate, search satisfaction, number of taste signals collected, Taste Profile depth, weekly/monthly active readers, retention, free → Dogear+ conversion, Dogear+ retention/churn, percentage of users who report that recommendations improve over time.

One particularly important qualitative question is: Would the user be disappointed if they could no longer use Dogear? Early on, finding 100 users who genuinely feel this way is more important than maximizing raw download numbers.

## 25. Product Prioritization Framework

When deciding whether to build a feature, ask:
1. Does this help Dogear understand the reader? If yes, high value.
2. Does this help the reader understand their own taste? If yes, high value.
3. Does this improve recommendation quality? If yes, high value.
4. Does this make discovering the next book easier? If yes, high value.
5. Does this improve the personalization feedback loop? If yes, high value.
6. Is this primarily copying Goodreads/social features? If yes, probably lower priority.
7. Is this AI functionality merely because AI is available? If yes, reconsider it. AI should solve an actual reader problem.

## 26. MVP Priorities

Unless the existing implementation suggests a better sequence, prioritize roughly:

Priority 1 — Library Foundation: reliable book data, library management, reading states, ratings, favorites, and imports.
Priority 2 — Taste Signals: capture enough information to begin understanding what users like and dislike.
Priority 3 — Taste Profile: build a useful representation of the user's preferences from those signals.
Priority 4 — Personalized Recommendations: generate recommendations based on the Taste Profile rather than generic popularity.
Priority 5 — Natural-Language Discovery: allow users to describe exactly what they want to read, combining the prompt with their Taste Profile.
Priority 6 — Recommendation Feedback: allow users to teach Dogear whether recommendations were good or bad.
Priority 7 — Dogear+: introduce premium functionality once the free experience demonstrates enough value to make the subscription understandable.

Avoid expanding into large social/community functionality before the core recommendation loop is excellent.

## 27. Technical Principle for AI Features

Do not create a system where every recommendation is simply: user prompt → LLM → book titles. That makes Dogear little more than a wrapper around an AI model.

The system should conceptually operate more like: User Library + Explicit Ratings + Behavioral Signals + Taste Profile + Negative Preferences + Recent Taste + Current Natural-Language Request + Book Metadata/Candidate Retrieval → Recommendation System → Ranked Personalized Recommendations → Personalized Explanation → User Feedback → Updated Taste Intelligence.

Design implementation decisions so we can progressively improve this pipeline.

## 28. Avoid Hallucinated Books and Metadata

This is especially important. The AI should not be trusted as the authoritative database for whether a book exists, author, ISBN, cover, publication date, page count, or edition information. Use reliable book data sources/database records for factual book information.

The AI layer should primarily perform tasks such as: understanding intent, interpreting taste, matching nuanced preferences, ranking candidates, explaining recommendations, extracting preference signals. Recommendation results should resolve to actual book records whenever possible.

## 29. Long-Term Moat

Dogear's potential moat is not access to an LLM — everyone has access to capable AI models. The valuable asset is the accumulated relationship between Reader ↔ Books ↔ Taste Signals ↔ Outcomes.

Over time Dogear can understand: "This reader said they wanted X." → "Dogear recommended Y." → "They saved Y." → "They eventually read Y." → "They rated Y five stars." → "They specifically loved Z about it." That feedback loop is extremely valuable. Therefore, preserve this data carefully in the architecture.

## 30. The Dogear Test

Whenever implementing or evaluating something, ask: Does this make Dogear feel more like an app that knows my reading taste? If yes, it probably belongs. If it merely makes Dogear a larger book-tracking app, reconsider its priority.

## 31. Current Product Positioning

Working positioning: "Dogear learns what you love to read and gets better at finding your next book the more you use it."

Alternative internal product thesis: "Dogear is the personal intelligence layer for your reading life."

The first is clearer for consumers. The second is useful for guiding product development.

## 32. Instructions for Claude While Building

Treat everything above as product context for future implementation decisions. However:

1. Do not blindly rewrite existing working code to conform to this document.
2. First understand the existing Dogear codebase and architecture.
3. Preserve existing functionality that remains compatible with this direction.
4. Prefer incremental, testable changes over large unnecessary rewrites.
5. When proposing a new feature, explain how it strengthens the core Dogear loop.
6. Keep future scalability in mind when designing Taste Profile and recommendation data structures.
7. Separate reliable book metadata from AI-generated interpretation.
8. Store useful raw user signals so recommendation logic can improve later.
9. Avoid unnecessary social/community scope during the MVP.
10. Keep free vs. Dogear+ capabilities configurable because pricing and limits will require experimentation.
11. Do not assume the current monetization structure is final.
12. Prioritize recommendation quality and user trust over the quantity of recommendations.
13. When there is a conflict between adding more features and making Dogear understand the reader better, prioritize understanding the reader.
14. Before making major architectural changes, explain the proposed change and why it is necessary.
15. Continue treating the existing codebase as the implementation source of truth and this document as the product-strategy source of truth.

The ultimate goal is not to build "Goodreads with AI." The goal is to build a product where, after enough use, a reader genuinely feels: **"Dogear knows my taste better than any other place I look for books."**
