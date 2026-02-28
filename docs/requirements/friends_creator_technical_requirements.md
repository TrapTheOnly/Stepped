# Friends + Creator System Technical Requirements (v1)

## 1) Product Objective

Build a social layer that increases retention and monetizes through one unified subscription:

- `Stepped Plus` monthly: `$1.99`
- `Stepped Plus` yearly: `$20.00`
- One entitlement unlocks both:
- AI planning credits (`ProAI`)
- Creator content access (`Creator Pass`)

No separate Creator-only subscription in v1.

## 2) Core Principles

- Core social graph must stay free (add friends, basic leaderboard, basic visited map view).
- Premium must gate content users cannot easily replicate by screenshots alone:
- high-quality creator itineraries
- structured place packs
- trip-ready day-by-day plans
- affiliate-assisted booking flow
- Personal location data is not sold as raw user-level data.
- Use privacy-safe aggregates only for internal product analytics and optional B2B later.

## 3) Scope

### 3.1 In Scope (v1)

- Friend add via deep link invite.
- Friend list and friend profile map.
- Friends leaderboard by countries visited and cities visited.
- Public creator profiles with verified badge.
- Creator trip posts:
- city sequence
- day plan
- recommended places
- short notes and ratings
- City rating system (community + creator):
- food
- price/value
- safety
- architecture
- infrastructure
- nightlife
- scenery
- Premium gating for:
- full creator post details
- creator place lists and notes
- city score breakdown details
- Unified subscription entitlements in backend.
- Creator payout ledger (internal first; manual payout operations in v1).
- Affiliate link tracking for outbound clicks and conversions.

### 3.2 Out of Scope (v1)

- Real-time chat/messaging.
- In-app creator ad marketplace.
- Automated creator payout rails (Stripe Connect, etc.) in first release.
- Data-broker export pipeline.

## 4) User Roles

- `free_user`
- `plus_user`
- `creator` (can also be `plus_user`)
- `admin`

## 5) Entitlements and Limits

### 5.1 Free User

- Access to friends graph basics.
- Access to creator profile header and teaser cards.
- Access to city overall score only.
- No access to detailed creator itineraries or full city score breakdown.

### 5.2 Plus User (`$1.99/mo` or `$20/year`)

- Full creator content access.
- Full city score breakdown and rating reasons.
- ProAI monthly credit bucket (defined in wishlist requirements file).
- Priority in new feature rollouts.

### 5.3 Creator

- Can publish public trip boards and place packs.
- Can include affiliate-tagged links in approved blocks.
- Eligible for creator revenue pool based on engagement score.

## 6) Functional Requirements

### 6.1 Friend Invite and Graph

- Generate deep link format: `https://steps.world/add-friend?code=<invite_code>`.
- Invite code must be single-use by default and expire in 7 days.
- Allow reissue from app.
- Accepting invite creates bidirectional friendship edge.

### 6.2 Friend Profile

- Show:
- countries visited count
- cities visited count
- visited world map highlights
- public trip badges
- Respect privacy:
- `private`, `friends_only`, `public`
- Default for new users: `friends_only`

### 6.3 Leaderboards

- Friend leaderboard:
- countries visited
- cities visited
- streak (months with at least one logged trip)
- Global city leaderboard:
- by visit volume
- by weighted score

### 6.4 Creator Profiles and Posts

- Creator profile includes:
- bio
- niches (budget, luxury, food, solo, family)
- trust markers (followers, average rating, post count)
- Posts require structured fields:
- trip title
- city sequence
- suggested exact day split
- top places
- pricing band
- safety notes

### 6.5 City Rating System

- Each rating must include:
- city_id
- category_id
- score (1..5)
- optional rationale text
- source type (`community`, `creator`, `admin`)
- Score aggregation:
- weighted average with source weights
- decay factor for stale ratings (>18 months)

### 6.6 Premium Gates

- Free users can open city page and see headline score.
- Free users can preview first 1-2 creator recommendations only.
- Plus users unlock:
- full rating breakdown
- full creator cards
- full day-level recommendations

### 6.7 Affiliate Flow

- For each recommended place, if partner mapping exists:
- show partner badge
- show outbound CTA (`View on TripAdvisor`, `Book on Booking.com`)
- Attach click tracking parameters:
- `source=creator|ai|admin`
- `city_id`
- `post_id` or `wishlist_id`
- `user_tier`

### 6.8 Revenue Share for Creators (v1)

- Use monthly creator pool percentage of net plus subscription revenue.
- Initial requirement:
- creator pool percentage is remote-configurable (default 20%).
- Engagement score inputs:
- unique premium viewers
- dwell time on creator content
- outbound affiliate clicks
- fraud filters:
- ignore self-views
- ignore sessions <5 seconds
- cap repeated views per user/day

## 7) Data Model Requirements

Minimum cloud entities:

- `users`
- `friend_edges`
- `friend_invites`
- `profiles`
- `creator_profiles`
- `creator_posts`
- `cities`
- `city_ratings`
- `subscriptions`
- `entitlements`
- `affiliate_events`
- `creator_payout_ledger`

Key constraints:

- `friend_edges` unique on `(user_id_a, user_id_b)` normalized order.
- `city_ratings` unique on `(user_id, city_id, category_id, source_type)` per rolling window.
- `entitlements` must be server-authoritative; never trust client-only state.

## 8) API Requirements (Cloud)

Required endpoints:

- `POST /v1/friends/invites`
- `POST /v1/friends/invites/accept`
- `GET /v1/friends`
- `GET /v1/friends/{userId}/profile`
- `GET /v1/leaderboards/friends`
- `GET /v1/creators`
- `GET /v1/creators/{creatorId}`
- `GET /v1/creators/{creatorId}/posts`
- `GET /v1/cities/{cityId}/ratings`
- `POST /v1/affiliate/click`
- `POST /v1/subscriptions/webhook` (store verification)
- `GET /v1/entitlements/me`

All endpoints require auth except public creator discovery pages.

## 9) Client App Requirements (Flutter)

- Add new tab: `Friends`.
- Add route groups:
- `/friends`
- `/friends/invite`
- `/friends/profile/:id`
- `/creators`
- `/creators/:id`
- `/city/:id`
- Add entitlement provider in Riverpod with cache + refresh.
- UI states required for every premium block:
- loading
- paywall teaser
- unlocked
- offline fallback

## 10) Privacy, Legal, and Policy Requirements

- No sale of precise per-user travel history.
- If aggregate reports are built later:
- enforce k-anonymity threshold (`k >= 100`)
- remove direct identifiers
- retain opt-out controls
- Provide delete account + delete social graph endpoint.
- Keep consent ledger for:
- analytics personalization
- creator recommendations
- affiliate attribution

## 11) Analytics Requirements

Track events:

- `friend_invite_created`
- `friend_invite_accepted`
- `creator_profile_view`
- `creator_post_open`
- `city_breakdown_unlock_tap`
- `paywall_view`
- `paywall_subscribe_success`
- `affiliate_click`
- `affiliate_conversion` (if callback available)

Dashboards must show by country:

- subscription conversion
- creator content engagement
- affiliate click-through rate

## 12) Non-Functional Requirements

- P95 API latency under 500 ms for feed/list endpoints.
- P95 app screen open under 1.5 s on mid-tier Android.
- 99.9% integrity for entitlement checks.
- All sensitive endpoints rate-limited and abuse-scored.

## 13) Acceptance Criteria (v1)

- Users can add friends with deep links and see friend profiles.
- Free users can access basic social features.
- Plus users can unlock creator detail content and city score breakdown.
- Subscription verification controls entitlements server-side.
- Affiliate clicks are tracked end-to-end.
- Creator pool ledger computes monthly payout shares.

## 14) UI Generation Prompt Inputs (for design tools)

Design references should include:

- A social-first `Friends` tab with:
- friend cards
- leaderboard strip
- creator spotlight carousel
- A `Creator Profile` screen with:
- hero cover
- trust stats row
- trip cards with premium lock overlays
- A `City Insight` screen with:
- overall score ring
- category bars
- premium explanation cards

Visual direction:

- Clean travel editorial style.
- Card-heavy layout with map thumbnails.
- Strong hierarchy between free preview and premium unlock.
