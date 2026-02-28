# Wishlist + AI Planning Technical Requirements (v1)

## 1) Product Objective

Transform Wishlist into a high-retention planning experience with:

- Simple AI-assisted itinerary generation
- Smooth manual editing (no database-table feeling)
- Clear credit economy
- Integrated monetization (subscription, rewarded overage, affiliate)

This spec assumes one unified premium plan:

- `Stepped Plus` monthly: `$1.99`
- `Stepped Plus` yearly: `$20.00`

## 2) Credit and Access Model

### 2.1 Free Tier

- `10` AI credits per month.
- Daily burst cap: `2` AI generations/day.
- Optional rewarded ads: `+1` credit per completed ad.
- Rewarded ad cap: `20` ad-credits/month.

### 2.2 Plus Tier

- `150` AI credits per month.
- Same planner UX, no separate mode.
- Credits reset monthly; no rollover in v1.

### 2.3 Cost Protection Rules

- Hard input cap:
- max `4` cities per request
- max `1` country per request
- Hard output cap:
- `max_output_tokens = 900`
- Hard schema requirement:
- model must return strict JSON matching planner schema
- Server rejects oversized or invalid payloads before response is saved.

## 3) Scope

### 3.1 In Scope

- Wishlist list page improvements for engagement.
- Planner composer page redesign.
- AI generation flow with credit checks.
- Post-generation review screen.
- Manual edit redesign to card/section-based UI.
- Date-sequence planning (exact dates per city when date range provided).
- Affiliate placements in recommendation blocks.

### 3.2 Out of Scope

- Multi-country single request in v1.
- Real-time collaborative editing.
- Desktop-specific custom layout pass.

## 4) UX Requirements

## 4.1 Wishlist Home Screen

Required components:

- Sticky header with:
- monthly credit meter
- one-tap `Generate plan` action
- Filter chips:
- `All`, `Draft`, `AI ready`, `Booked`, `Completed`
- Wishlist cards with:
- country
- selected cities summary
- date window (or AI recommended)
- plan health badge (`Not started`, `Draft`, `Ready`, `Needs edits`)
- Empty state with examples and one guided template.

## 4.2 Planner Composer Screen

Replace form-like flow with step cards:

- Step 1: Destination
- country picker
- city chips input (max 4)
- Step 2: Timing
- exact date range or flexible month + duration
- Step 3: Preferences
- pace, budget, vibe tags
- toggle for additional city suggestions
- Step 4: Generate
- credit cost preview (`1 credit`)
- explain what user will receive

Behavior:

- Disable Generate when constraints fail.
- Show inline validations near the exact field.
- Persist draft automatically every meaningful input change.

## 4.3 AI Result Screen

Render result as rich cards:

- Overview summary card.
- City sequence timeline with per-city day count.
- Daily blocks grouped by date.
- Things to do checklists.
- Save actions:
- `Accept all`
- `Edit city`
- `Regenerate city`
- `Regenerate whole plan`

## 4.4 Manual Edit UX (critical)

Replace current dense form controls with:

- Section tabs:
- `Overview`
- `Cities`
- `Timeline`
- `Activities`
- Card editor per city:
- title, days, rationale
- drag to reorder cities
- inline add/delete timeline rows
- bottom sheet quick editors instead of large dialog chains
- One persistent `Save` footer bar with dirty-state indicator.

Goal:

- User feels like editing a polished itinerary, not editing raw records.

## 4.5 Engagement Mechanics

- Show completion progress:
- `% itinerary complete`
- `missing fields` checklist
- Micro-prompts:
- `Add one local food spot`
- `Add one sunrise view`
- Weekly recap card if user has active plans.

## 5) Functional Requirements

### 5.1 Validation

- City count must be `1..4`.
- Duplicate city names in one request are rejected.
- Date window must be valid and max trip length configurable (default 30 days).
- If exact dates provided, planner must map each city to exact day ranges.

### 5.2 Generation Pipeline

- Client sends normalized request to backend.
- Backend checks:
- entitlement
- available credits
- daily burst limit
- request constraints
- Backend calls model only after checks pass.
- On successful response:
- decrement credits atomically
- persist request + response metadata
- return rendered plan payload

### 5.3 Regeneration Modes

- Whole plan regeneration: costs `1` credit.
- City-only regeneration: costs `1` credit.
- Minor manual edits: no credit cost.

### 5.4 Credit Ledger

Maintain immutable ledger rows:

- `grant_free_monthly`
- `grant_subscription`
- `grant_rewarded_ad`
- `spend_ai_generation`
- `refund_failed_generation`

All spend/refund operations must be idempotent with request IDs.

### 5.5 Rewarded Ads

- Ad watch is optional overage path.
- Credit granted only on server-verified completion callback.
- If callback missing/invalid, do not grant credit.

## 6) Affiliate Requirements

### 6.1 Placement Rules

- Show affiliate cards only in context:
- city plan sections
- recommended places
- lodging windows based on exact city/date split
- Keep max `2` affiliate blocks per city card in v1.

### 6.2 Partner Mapping

- Attempt place matching with:
- canonical place name
- city
- geo coordinates if available
- If partner mapping confidence is low, hide affiliate CTA.

### 6.3 Attribution

Track:

- `affiliate_impression`
- `affiliate_click`
- `affiliate_conversion` (if callback/API supported)

Attach metadata:

- source (`ai`, `creator`, `admin`)
- wishlist_id
- city_id
- date range
- user tier

## 7) API Requirements

Required endpoints:

- `POST /v1/wishlist/plan/generate`
- `POST /v1/wishlist/plan/regenerate-city`
- `POST /v1/wishlist/plan/save-manual`
- `GET /v1/wishlist/credits`
- `POST /v1/wishlist/credits/rewarded-complete`
- `GET /v1/wishlist/plans/{planId}`
- `POST /v1/wishlist/plans/{planId}/accept`

Backend response must include:

- plan payload
- remaining credits
- next reset timestamp

## 8) Data Requirements

Minimum entities:

- `wishlist_items`
- `wishlist_plans`
- `wishlist_plan_versions`
- `credit_ledger`
- `generation_jobs`
- `affiliate_place_map`
- `affiliate_events`

Versioning:

- Every regeneration creates a new plan version.
- User can restore previous version within 30 days.

## 9) Performance and Reliability

- P95 planner request end-to-end under 9 seconds.
- Show progressive loading states after 1.5 seconds.
- If generation fails, auto-refund credit and show retry CTA.
- Offline mode:
- allow viewing saved plans
- queue manual edits locally and sync later

## 10) Security and Abuse Controls

- Rate limit by user and device fingerprint.
- Block scripted ad-credit abuse with anomaly scoring.
- Prevent prompt injection in saved text fields through sanitization.
- Server remains source of truth for credits and entitlement.

## 11) Analytics Requirements

Track funnel:

- `wishlist_open`
- `composer_started`
- `composer_validated`
- `generation_started`
- `generation_success`
- `generation_fail`
- `manual_edit_started`
- `manual_edit_saved`
- `subscription_prompt_shown`
- `subscription_purchased`

Report by market:

- conversion rate
- average credits consumed
- average cost per user
- affiliate revenue per active planner user

## 12) Acceptance Criteria (v1)

- User can generate a plan in <=4 cities with stable quality.
- Credits are correctly granted/spent/refunded with no double charge.
- Manual editing feels section-based and mobile-friendly.
- Plus users receive higher monthly credit entitlement.
- Affiliate blocks appear only when relevant and track correctly.

## 13) UI Generation Prompt Inputs (for design tools)

Design artifacts should include:

- `Wishlist Home` screen with credit meter and engaging plan cards.
- `Planner Composer` step-card flow (destination, timing, preferences, generate).
- `AI Result` screen with timeline and editable city cards.
- `Manual Edit` screen using tabs and bottom-sheet editors.
- `Paywall` sheet that explains one plan unlock (`Plus = AI + Creator content`).

Visual direction:

- Travel magazine style with rich cards and clear hierarchy.
- Strong progress indicators and action-oriented CTAs.
- Minimal dense forms; prefer chips, cards, and expandable sections.
