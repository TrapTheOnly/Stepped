# Stepped Backend / Frontend Alignment Checklist

Last verified: 2026-03-30

This document is based on:

- Frontend code in `/Users/ismail/Documents/Codes/Stepped/lib`
- Backend schema in `/Users/ismail/Downloads/openapi(1).yaml`

This supersedes the older note that `wishlist_items[].ai_plan` and `wishlist_items[].is_pinned` were missing from the backend contract. In the updated OpenAPI, both fields are now present, and the media upload routes are also present.

## 1. Scope

This document covers:

- Every Stepped backend request the current Flutter app makes
- The exact JSON or multipart shapes the frontend sends
- The response shapes the frontend expects
- What the backend must persist durably
- What may remain local-only on device
- Known frontend/backend mismatches and follow-up items

This document does not try to dictate backend implementation details such as SQL vs Firestore. It defines behavior and durable data responsibilities.

## 2. Durable Data Ownership

After the latest frontend change, the app no longer keeps trips, wishlist data, visited countries, or social caches durably on-device. Those data families now live only:

- in memory while the app is running
- in the backend as the only durable source of truth

### 2.1 Must be durably stored in the backend

| Domain | Durable fields |
| --- | --- |
| Auth user | `id`, `email`, `display_name`, `provider`, `photo_url` |
| Social profile | `display_name`, `photo_url`, `home_base`, `bio` |
| Privacy | `share_wishlist_with_friends`, `wishlist_visibility` |
| Trips | `id`, `country_code`, `country_name`, `start_date`, `end_date`, `cities`, `city_entries`, `city_data_json` if used, `cover_image_url`, `notes`, optional `source_wishlist_item_id` |
| Trip city images | image asset bound to `(user_id, trip_id, city_key)` |
| Visited countries | `country_code`, `country_name`, `visited_at` |
| Wishlist items | `id`, `title`, `country_code`, `country_name`, `planned_cities`, `planned_start_date`, `planned_end_date`, `image_url`, `ai_plan`, `is_pinned`, `notes`, `created_at` |
| Wishlist images | image asset bound to `(user_id, wishlist_item_id)` |
| Friend invite links | `token`, `url`, `status`, `created_at`, `can_accept` |
| Friend graph | friendships and visibility-related data needed by `/v1/social/friends*` |

### 2.2 Should remain local-only on device

These settings are intentionally local and do not need backend persistence:

- theme mode
- confirm-delete preference
- show wishlist dates preference
- Gemini API key
- AI planner source switch (`cloud` vs local Gemini)
- cloud AI base URL override

## 3. Global Rules The Backend Must Follow

### 3.1 Auth token behavior

The app signs in through:

- `POST /v1/auth/register`
- `POST /v1/auth/sign-in`
- `POST /v1/auth/google`

After that, the app uses the returned `access_token` as the bearer token for all protected routes.

Backend requirement:

- Protected routes must accept the same token that auth endpoints return in `access_token`.
- If the system internally uses Firebase ID tokens, then either:
  - `access_token` must itself be that Firebase ID token, or
  - the social/planner services must accept the returned token as-is.

### 3.2 Content types

- JSON endpoints: `Content-Type: application/json`
- Media uploads: `multipart/form-data`
- Media upload form field name must be exactly `file`

### 3.3 Error envelope

For non-2xx responses, the frontend works best when the backend returns:

```json
{
  "error": "request_error",
  "message": "Human-readable explanation"
}
```

The frontend reads error text from:

- `message`
- `error_description`
- `error`
- `detail`

### 3.4 IDs must be stable

Trips and wishlist items are keyed by string IDs on the wire.

Backend requirement:

- If the client sends `id`, persist that `id`.
- Do not generate a new ID for the same logical record on every sync.
- Return the same stable `id` values on later reads.

If IDs are not stable, updates, hydrations, and photo uploads will drift.

### 3.5 Travel and wishlist sync must be authoritative replacement

The frontend sends full snapshots for:

- `PUT /v1/social/me/travel`
- `PUT /v1/social/me/wishlist`

Backend requirement:

- Treat the incoming list as the full current list for that user.
- If an item previously existed but is missing from the new payload, remove it.
- Do not implement merge-only upsert semantics.

If the backend only upserts and never removes missing items:

- deleted trips will come back
- removed wishlist items will come back
- unvisited countries will come back

### 3.6 Arrays should always be returned, even when empty

The frontend is more robust if these are always present as arrays:

- `trips`
- `wishlist_items`
- `visited_countries`
- `invites`
- `friends`

### 3.7 Date/time tolerance

The frontend tolerates both epoch milliseconds and ISO 8601 strings for many timestamp fields.

Safest backend behavior:

- For fields documented as epoch millis in sync payloads, return epoch millis there.
- For fields documented as date-time strings in read responses, ISO 8601 UTC is fine.

Examples:

- `visited_at`: frontend accepts integer or ISO string
- `created_at` on wishlist responses: frontend accepts integer or ISO string
- `added_at` / invite timestamps: frontend accepts ISO string

### 3.8 Media upload behavior

The frontend uploads images before the main travel/wishlist sync may have completed.

Backend requirement:

- Upload endpoints must support placeholder or upsert behavior.
- If the parent trip or wishlist row does not exist yet, create a lightweight placeholder and let later sync fill the rest.

### 3.9 `ai_plan` must be treated as an opaque blob

The frontend currently stores `ai_plan` as a JSON-encoded string.

Backend requirement:

- Accept `ai_plan` as a string
- persist it exactly
- return it exactly

Do not parse, normalize, or rewrite it unless you are deliberately versioning the planner format.

## 4. Domain Data Models The Backend Must Persist

## 4.1 Social profile

| Field | Type | Notes |
| --- | --- | --- |
| `display_name` | string | public display name |
| `photo_url` | string \| null | durable URL |
| `home_base` | string \| null | may be empty |
| `bio` | string \| null | may be empty |

## 4.2 Visited country

| Field | Type | Notes |
| --- | --- | --- |
| `country_code` | string | usually ISO 2-letter code |
| `country_name` | string | display name |
| `visited_at` | int64 epoch millis or ISO string | frontend accepts both |

## 4.3 Trip

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | stable remote ID |
| `country_code` | string | required |
| `country_name` | string | required |
| `start_date` | int64 epoch millis | required |
| `end_date` | int64 epoch millis | required |
| `cities` | string | comma-separated summary used in list UI |
| `city_entries` | array of `TripCityEntry` | primary structured trip detail data |
| `city_data_json` | string \| null | spec supports it, current frontend prefers `city_entries` |
| `cover_image_url` | string \| null | durable URL |
| `notes` | string \| null | free text |
| `source_wishlist_item_id` | string \| null | now sent and read by the frontend; backend must persist and return the same stable wishlist item ID used in `wishlist_items[].id` |

## 4.4 Trip city entry

These keys are camelCase on the wire.

| Field | Type | Notes |
| --- | --- | --- |
| `name` | string | required |
| `rating` | integer \| null | 1-5 |
| `visitedPlaces` | array of string | places user visited |
| `notes` | string \| null | city-specific notes |
| `imageUri` | string \| null | durable URL |
| `itineraryOverview` | string \| null | short summary |
| `itineraryStops` | array of `{slot, place, note}` | ordered timeline |
| `suggestedPlaces` | array of string | AI-derived suggestions |
| `completedSuggestedPlaceKeys` | array of string | completion flags |

## 4.5 Wishlist item

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | stable remote ID |
| `title` | string | required |
| `country_code` | string \| null | may be empty |
| `country_name` | string | current frontend expects string, can be empty |
| `planned_cities` | string | comma-separated summary |
| `planned_start_date` | int64 epoch millis \| null | nullable |
| `planned_end_date` | int64 epoch millis \| null | nullable |
| `image_url` | string \| null | durable URL |
| `notes` | string \| null | spec supports it, frontend does not meaningfully round-trip it yet |
| `ai_plan` | string \| null | JSON-encoded plan blob |
| `is_pinned` | boolean | pin state |
| `created_at` | int64 epoch millis or ISO string | frontend accepts both |

## 4.6 Friend / invite data

| Domain | Required data |
| --- | --- |
| Invite link | `token`, `url`, `status`, `created_at`, optional `can_accept` |
| Friend summary | `id`, `display_name`, `photo_url`, `home_base`, optional `added_at` |
| Friend profile | public profile + stats + visited countries + trips + visible wishlist items |

## 5. Endpoint-By-Endpoint Contract

Only routes currently used by the Flutter app are marked as "used by frontend today".

## 5.1 Auth

### POST `/v1/auth/register`

Used by frontend today: yes

Auth: none

Request body:

```json
{
  "display_name": "Ismail",
  "email": "ismail@example.com",
  "password": "correct horse battery staple"
}
```

Backend must:

- create the auth user
- persist the user record
- return a valid session

Response the frontend expects:

```json
{
  "access_token": "jwt-or-firebase-id-token",
  "refresh_token": "refresh-token",
  "user": {
    "id": "uid_123",
    "email": "ismail@example.com",
    "display_name": "Ismail",
    "provider": "password",
    "photo_url": null
  }
}
```

Frontend tolerance:

- token may be read from `access_token`, `token`, `session_token`, or nested `data.access_token`
- user may be read from top-level `user` or nested `data.user`

Backend checklist:

- [ ] Returns `201`
- [ ] Returns `access_token`
- [ ] Returns `refresh_token` per spec
- [ ] Returns user with `id`, `email`, `display_name`, `provider`, `photo_url`

### POST `/v1/auth/sign-in`

Used by frontend today: yes

Auth: none

Request body:

```json
{
  "email": "ismail@example.com",
  "password": "correct horse battery staple"
}
```

Response shape: same as register

Backend checklist:

- [ ] Returns `200`
- [ ] Same session payload shape as register

### POST `/v1/auth/google`

Used by frontend today: yes

Auth: none

Request body sent by frontend:

```json
{
  "id_token": "google-id-token",
  "email": "ismail@example.com",
  "display_name": "Ismail",
  "photo_url": "https://lh3.googleusercontent.com/..."
}
```

Important note:

- The updated OpenAPI only requires `id_token` and lists `display_name`.
- The frontend also sends `email` and optional `photo_url`.
- Backend should accept those extra fields and use them if convenient.

Response shape:

```json
{
  "access_token": "jwt-or-firebase-id-token",
  "refresh_token": "refresh-token",
  "user": {
    "id": "uid_123",
    "email": "ismail@example.com",
    "display_name": "Ismail",
    "provider": "google",
    "photo_url": "https://lh3.googleusercontent.com/..."
  }
}
```

Backend checklist:

- [ ] Accepts `id_token`
- [ ] Tolerates extra `email` and `photo_url`
- [ ] Returns user with `provider: "google"`

### GET `/v1/auth/me`

Used by frontend today: yes

Auth: bearer token

Response preferred shape:

```json
{
  "user": {
    "id": "uid_123",
    "email": "ismail@example.com",
    "display_name": "Ismail",
    "provider": "google",
    "photo_url": "https://cdn.example.com/profile/u_123.webp"
  }
}
```

Frontend tolerance:

- accepts `{ "user": {...} }`
- also tolerates the raw user object without wrapper

Backend checklist:

- [ ] Always returns `provider`
- [ ] Always returns `display_name`
- [ ] Does not omit `photo_url`

## 5.2 Social profile and state

### GET `/v1/social/me`

Used by frontend today: yes

Auth: bearer token

This is the most important read endpoint in the app. After app restart, reinstall, or login on another device, this endpoint must fully reconstruct the user’s state.

Preferred response:

```json
{
  "profile": {
    "id": "uid_123",
    "display_name": "Ismail",
    "photo_url": "https://cdn.example.com/profile/u_123.webp",
    "home_base": "Baku",
    "bio": "Traveler",
    "stats": {
      "total_trips": 3,
      "visited_countries_count": 7
    },
    "visited_countries": [
      {
        "country_code": "JP",
        "country_name": "Japan",
        "visited_at": 1775001600000
      }
    ]
  },
  "visited_countries": [
    {
      "country_code": "JP",
      "country_name": "Japan",
      "visited_at": 1775001600000
    }
  ],
  "stats": {
    "total_trips": 3,
    "visited_countries_count": 7,
    "total_friends": 5
  },
  "privacy": {
    "share_wishlist_with_friends": true,
    "wishlist_visibility": "friends"
  },
  "share_wishlist_with_friends": true,
  "invite": null,
  "active_invite": null,
  "invites": [],
  "trips": [],
  "wishlist_items": []
}
```

Frontend tolerance:

- profile may also be under `me` or `user`
- stats may also be under `counts`
- `visited_countries` may be top-level or nested inside `profile`
- `wishlist_items` may also be `wishlistItems`
- invite may be `invite`, `active_invite`, `friend_invite`, or first element of `invites`

Backend checklist:

- [ ] Returns full persisted state for current user
- [ ] Returns arrays even when empty
- [ ] Returns stable IDs for trips and wishlist items
- [ ] Returns `visited_countries` correctly
- [ ] Returns `ai_plan` and `is_pinned` for wishlist items

### PUT `/v1/social/me/profile`

Used by frontend today: yes

Auth: bearer token

Request body sent by frontend:

```json
{
  "display_name": "Ismail",
  "photo_url": "https://cdn.example.com/profile/u_123.webp",
  "home_base": "Baku",
  "bio": "Traveler"
}
```

Backend should accept snake_case and may also accept camelCase aliases.

Backend must persist:

- `display_name`
- `photo_url`
- `home_base`
- `bio`

Preferred response:

```json
{
  "profile": {
    "id": "uid_123",
    "display_name": "Ismail",
    "photo_url": "https://cdn.example.com/profile/u_123.webp",
    "home_base": "Baku",
    "bio": "Traveler",
    "stats": {
      "total_trips": 3,
      "visited_countries_count": 7
    },
    "visited_countries": []
  }
}
```

### POST `/v1/social/me/profile-photo`

Used by frontend today: yes

Auth: bearer token

Request:

- `multipart/form-data`
- field name must be `file`
- frontend may upload `.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.heic`, `.heif`

Required response:

```json
{
  "photo_url": "https://cdn.example.com/profile/u_123.webp"
}
```

Backend checklist:

- [ ] Accepts multipart upload
- [ ] Stores normalized durable asset
- [ ] Returns durable URL in `photo_url`

### GET `/v1/social/me/privacy`

Used by frontend today: yes

Auth: bearer token

Preferred response:

```json
{
  "share_wishlist_with_friends": true,
  "wishlist_visibility": "friends"
}
```

### PUT `/v1/social/me/privacy`

Used by frontend today: yes

Auth: bearer token

Request body sent by frontend:

```json
{
  "share_wishlist_with_friends": true
}
```

Backend must:

- persist the boolean
- derive or return `wishlist_visibility`

Preferred response:

```json
{
  "share_wishlist_with_friends": true,
  "wishlist_visibility": "friends"
}
```

Backend checklist:

- [ ] `GET /social/me/privacy` and `GET /social/me` remain consistent

## 5.3 Travel sync and travel media

### PUT `/v1/social/me/travel`

Used by frontend today: yes

Auth: bearer token

This is the authoritative snapshot for:

- profile fields
- trips
- visited countries

Request body shape:

```json
{
  "profile": {
    "display_name": "Ismail",
    "photo_url": "https://cdn.example.com/profile/u_123.webp",
    "home_base": "Baku",
    "bio": "Traveler"
  },
  "trips": [
    {
      "id": "trip_japan_apr_2026",
      "country_code": "JP",
      "country_name": "Japan",
      "start_date": 1775001600000,
      "end_date": 1775606400000,
      "cities": "Tokyo, Kyoto",
      "city_entries": [
        {
          "name": "Tokyo",
          "rating": 5,
          "visitedPlaces": ["Shibuya", "Senso-ji"],
          "notes": "Busy but great",
          "imageUri": "https://cdn.example.com/trips/trip_japan_apr_2026/tokyo.webp",
          "itineraryOverview": "3 days in Tokyo",
          "itineraryStops": [
            {
              "slot": "Morning",
              "place": "Senso-ji",
              "note": "Arrive early"
            }
          ],
          "suggestedPlaces": ["Meiji Shrine", "Tokyo Skytree"],
          "completedSuggestedPlaceKeys": ["senso-ji"]
        }
      ],
      "cover_image_url": "https://cdn.example.com/trips/trip_japan_apr_2026/cover.webp",
      "notes": "Cherry blossom trip"
    }
  ],
  "visited_countries": [
    {
      "country_code": "JP",
      "country_name": "Japan",
      "visited_at": 1775001600000
    }
  ]
}
```

Backend must persist:

- full trip list
- nested trip city entry data
- full visited country list
- profile subobject if supplied

Behavior requirement:

- authoritative replacement, not merge-only

Response acceptable to frontend:

```json
{
  "synced": true,
  "profile": {
    "id": "uid_123",
    "display_name": "Ismail",
    "photo_url": "https://cdn.example.com/profile/u_123.webp",
    "home_base": "Baku",
    "bio": "Traveler",
    "stats": {
      "total_trips": 3,
      "visited_countries_count": 7
    },
    "visited_countries": [
      {
        "country_code": "JP",
        "country_name": "Japan",
        "visited_at": 1775001600000
      }
    ]
  }
}
```

Backend checklist:

- [ ] Persist trips durably
- [ ] Persist visited countries durably
- [ ] Delete records missing from the new snapshot
- [ ] Preserve client trip IDs
- [ ] Return non-error 2xx response

### POST `/v1/social/me/trips/{tripId}/cover-photo`

Used by frontend today: yes

Auth: bearer token

Request:

- `multipart/form-data`
- field name `file`
- `{tripId}` must be the same stable string ID used in travel sync

Required response:

```json
{
  "trip_id": "trip_japan_apr_2026",
  "image_url": "https://cdn.example.com/trips/trip_japan_apr_2026/cover.webp",
  "cover_image_url": "https://cdn.example.com/trips/trip_japan_apr_2026/cover.webp"
}
```

Frontend tolerance:

- accepts `cover_image_url`
- also accepts `image_url`

Backend checklist:

- [ ] Supports placeholder trip row creation if needed
- [ ] Replaces previous image for same `(user_id, trip_id)`
- [ ] Returns usable durable URL

### POST `/v1/social/me/trips/{tripId}/cities/{cityKey}/photo`

Used by frontend today: yes

Auth: bearer token

Request:

- `multipart/form-data`
- field name `file`
- `{cityKey}` must be URL-safe city identifier such as `tokyo` or `new-york`

Required response:

```json
{
  "trip_id": "trip_japan_apr_2026",
  "city_key": "tokyo",
  "city_name": "Tokyo",
  "image_url": "https://cdn.example.com/trips/trip_japan_apr_2026/tokyo.webp",
  "imageUri": "https://cdn.example.com/trips/trip_japan_apr_2026/tokyo.webp"
}
```

Frontend tolerance:

- accepts `imageUri`
- also accepts `image_url`

Backend checklist:

- [ ] Supports placeholder trip or city row creation if needed
- [ ] Replaces previous image for same `(user_id, trip_id, city_key)`

## 5.4 Wishlist sync and wishlist media

### PUT `/v1/social/me/wishlist`

Used by frontend today: yes

Auth: bearer token

This is the authoritative snapshot for wishlist items.

Request body shape:

```json
{
  "wishlist_items": [
    {
      "id": "wish_kyoto_spring",
      "title": "Japan in spring",
      "country_code": "JP",
      "country_name": "Japan",
      "planned_cities": "Tokyo, Kyoto, Osaka",
      "planned_start_date": 1775001600000,
      "planned_end_date": 1775606400000,
      "image_url": "https://cdn.example.com/wishlist/wish_kyoto_spring.webp",
      "notes": null,
      "ai_plan": "{\"cover_image\":{\"image_url\":\"https://cdn.example.com/wishlist/wish_kyoto_spring.webp\"},\"cityPlan\":[{\"city\":\"Tokyo\"},{\"city\":\"Kyoto\"}]}",
      "is_pinned": true,
      "created_at": 1774400000000
    }
  ]
}
```

Backend must persist:

- every wishlist item field above
- especially `ai_plan`
- especially `is_pinned`

Behavior requirement:

- authoritative replacement, not merge-only

Response acceptable to frontend:

```json
{
  "synced": true,
  "wishlist_items": [
    {
      "id": "wish_kyoto_spring",
      "title": "Japan in spring",
      "country_code": "JP",
      "country_name": "Japan",
      "planned_cities": "Tokyo, Kyoto, Osaka",
      "planned_start_date": 1775001600000,
      "planned_end_date": 1775606400000,
      "image_url": "https://cdn.example.com/wishlist/wish_kyoto_spring.webp",
      "notes": null,
      "ai_plan": "{\"cover_image\":{\"image_url\":\"https://cdn.example.com/wishlist/wish_kyoto_spring.webp\"},\"cityPlan\":[{\"city\":\"Tokyo\"},{\"city\":\"Kyoto\"}]}",
      "is_pinned": true,
      "created_at": "2026-03-30T12:00:00Z"
    }
  ],
  "wishlist_visibility": "friends"
}
```

Backend checklist:

- [ ] Persist wishlist items durably
- [ ] Delete items missing from the new snapshot
- [ ] Preserve client wishlist IDs
- [ ] Return `ai_plan` unchanged
- [ ] Return `is_pinned`

### POST `/v1/social/me/wishlist/{wishlistItemId}/photo`

Used by frontend today: yes

Auth: bearer token

Request:

- `multipart/form-data`
- field name `file`

Required response:

```json
{
  "wishlist_item_id": "wish_kyoto_spring",
  "image_url": "https://cdn.example.com/wishlist/wish_kyoto_spring.webp"
}
```

Backend checklist:

- [ ] Supports placeholder wishlist row creation if needed
- [ ] Replaces previous image for same `(user_id, wishlist_item_id)`

## 5.5 Friend invite and friend graph

### POST `/v1/social/friend-links`

Used by frontend today: yes

Auth: bearer token

Request body:

- none

Preferred response:

```json
{
  "invite": {
    "token": "abc123",
    "url": "https://app.stepped.world/friends/add/abc123",
    "status": "active",
    "created_at": "2026-03-30T12:00:00Z"
  }
}
```

### DELETE `/v1/social/friend-links/{token}`

Used by frontend today: yes

Auth: bearer token

Frontend expectation:

- `204 No Content` is ideal
- any 2xx with empty or JSON body is acceptable

### GET `/v1/social/friend-links/{token}`

Used by frontend today: yes

Auth: bearer token

Preferred response:

```json
{
  "invite": {
    "token": "abc123",
    "url": "https://app.stepped.world/friends/add/abc123",
    "status": "active",
    "created_at": "2026-03-30T12:00:00Z",
    "can_accept": true
  },
  "inviter": {
    "id": "uid_friend",
    "display_name": "Alex",
    "email": "alex@example.com",
    "photo_url": "https://cdn.example.com/profile/alex.webp",
    "home_base": "London"
  },
  "status": "active",
  "can_accept": true
}
```

Frontend tolerance:

- the app reads `status` and `can_accept` from either top-level or nested invite
- inviter may also be under `friend`, `profile`, or `user`

### POST `/v1/social/friend-links/{token}/accept`

Used by frontend today: yes

Auth: bearer token

Preferred response:

```json
{
  "accepted": true,
  "status": "accepted",
  "friend": {
    "id": "uid_friend",
    "display_name": "Alex",
    "photo_url": "https://cdn.example.com/profile/alex.webp",
    "home_base": "London",
    "added_at": "2026-03-30T12:05:00Z"
  }
}
```

### GET `/v1/social/friends`

Used by frontend today: yes

Auth: bearer token

Required response shape:

```json
{
  "friends": [
    {
      "id": "uid_friend",
      "display_name": "Alex",
      "photo_url": "https://cdn.example.com/profile/alex.webp",
      "home_base": "London",
      "added_at": "2026-03-30T12:05:00Z"
    }
  ]
}
```

### GET `/v1/social/friends/{friendUserId}`

Used by frontend today: yes

Auth: bearer token

Required response shape:

```json
{
  "friend": {
    "id": "uid_friend",
    "display_name": "Alex",
    "photo_url": "https://cdn.example.com/profile/alex.webp",
    "home_base": "London",
    "bio": "Traveler",
    "stats": {
      "total_trips": 4,
      "visited_countries_count": 9,
      "total_friends": 12
    },
    "visited_countries": [
      {
        "country_code": "IT",
        "country_name": "Italy",
        "visited_at": 1760000000000
      }
    ]
  },
  "trips": [
    {
      "id": "trip_rome_2026",
      "country_code": "IT",
      "country_name": "Italy",
      "start_date": 1760000000000,
      "end_date": 1760600000000,
      "cities": "Rome",
      "city_entries": [],
      "city_data_json": null,
      "cover_image_url": "https://cdn.example.com/trips/trip_rome_2026/cover.webp",
      "notes": null,
      "source_wishlist_item_id": null
    }
  ],
  "wishlist_items": [
    {
      "id": "wish_rome_food",
      "title": "Rome food trip",
      "country_code": "IT",
      "country_name": "Italy",
      "planned_cities": "Rome",
      "planned_start_date": null,
      "planned_end_date": null,
      "image_url": "https://cdn.example.com/wishlist/wish_rome_food.webp",
      "ai_plan": null,
      "is_pinned": false,
      "notes": null,
      "created_at": "2026-03-01T10:00:00Z"
    }
  ],
  "wishlist_visibility": "friends"
}
```

Frontend tolerance:

- `wishlist_items` may also be `wishlistItems`, `shared_wishlist_items`, or `sharedWishlistItems`

### DELETE `/v1/social/friends/{friendUserId}`

Used by frontend today: yes

Auth: bearer token

Frontend expectation:

- `204 No Content` is ideal
- any successful 2xx is acceptable

## 5.6 Planner and credits

### POST `/v1/ai/trip-plan`

Used by frontend today: yes when AI planner source is `cloud`

Auth:

- frontend sends `Authorization: Bearer <access_token>`
- updated OpenAPI marks this route `security: []`

Backend should:

- accept bearer auth if provided
- not require a special alternate header from the current Flutter app

Request body sent by frontend:

```json
{
  "wishlist_title": "Japan in spring",
  "country": "Japan",
  "trip_purpose": "Food and culture",
  "home_base": "Baku",
  "time_mode": "month_and_duration",
  "preferred_month": 4,
  "preferred_cities": ["Tokyo", "Kyoto"],
  "allow_additional_cities": true,
  "generation_attempt": 1,
  "max_output_tokens": 2048,
  "duration_preference": {
    "id": "one_week",
    "min_days": 6,
    "max_days": 8
  },
  "precise_window": null
}
```

Important mismatch note:

- `time_mode`, `wishlist_title`, `trip_purpose`, and `generation_attempt` are sent by the frontend but are not listed in the current OpenAPI `TripPlanRequest`.
- Backend should continue to tolerate these extra fields.

Preferred response:

```json
{
  "plan": {
    "country": "Japan",
    "summary": "A spring itinerary focused on Tokyo and Kyoto.",
    "duration": {
      "days": 7,
      "reason": "Best fit for the selected cities.",
      "source": "user_selected"
    },
    "time_windows": [
      {
        "label": "Early April",
        "months": "April",
        "reason": "Cherry blossom season"
      }
    ],
    "city_plan": [
      {
        "city": "Tokyo",
        "days": 4,
        "reason": "Best starting point",
        "is_extra": false
      }
    ],
    "city_cards": [
      {
        "city": "Tokyo",
        "overview": "Urban culture and historic landmarks",
        "image_query": "Tokyo skyline",
        "timeline": [
          {
            "slot": "Morning",
            "place": "Senso-ji",
            "note": "Arrive early"
          }
        ],
        "things_to_do": ["Shibuya", "Asakusa"]
      }
    ]
  }
}
```

Frontend tolerance:

- accepts either `{ "plan": {...} }` or the raw plan object
- on errors, reads `message` or `error`

Backend checklist:

- [ ] Accepts current frontend extras without failing validation
- [ ] Returns planner output in a parseable structure
- [ ] Returns readable error message on failure

### GET `/v1/wishlist/credits`

Used by frontend today: yes when AI planner source is `cloud`

Auth:

- frontend sends bearer token if available
- updated OpenAPI marks this route `security: []`
- updated OpenAPI mentions optional `X-Stepped-Plan`, but frontend does not send that header

Backend should:

- tolerate bearer token
- not require `X-Stepped-Plan` from this Flutter app

Preferred response:

```json
{
  "plan": "free",
  "generation_cost_credits": 1,
  "monthly_limit": 10,
  "remaining_credits": 10,
  "daily_burst_limit": 2,
  "rewarded_ad_monthly_limit": 20,
  "rewarded_ad_remaining": 20,
  "next_reset_at": "2026-04-01T00:00:00Z"
}
```

Frontend behavior note:

- if this endpoint fails or returns an invalid payload, the app silently falls back to a built-in free plan

## 6. Spec Routes Present But Not Used By The Current Flutter App

These routes are in `openapi(1).yaml` but are not currently called by the Flutter frontend:

- `GET /health`
- `GET /v1/auth/health`
- `GET /v1/social/health`
- `GET /v1/social/me/trips/{tripId}/cover-photo`
- `GET /v1/social/me/trips/{tripId}/cities/{cityKey}/photo`
- `GET /v1/social/me/wishlist/{wishlistItemId}/photo`
- `GET /v1/social/friend-links/{token}/public`

They can still be implemented, but they are not needed for the current app to function.

## 7. Known Alignment Gaps And Follow-Up Items

These are the remaining mismatches after checking the updated spec and the actual frontend code.

### 7.1 `source_wishlist_item_id` is now wired in the frontend

Current status:

- updated OpenAPI includes `source_wishlist_item_id`
- the frontend now sends `source_wishlist_item_id` in travel sync
- the frontend now reads `source_wishlist_item_id` from remote trips during hydration
- the frontend local trip model still stores `sourceWishlistItemId` as a local integer foreign key to the in-memory wishlist row, so hydration maps the remote wishlist ID back onto the local row ID

Impact:

- the trip itself syncs correctly
- the relationship "this trip started from wishlist item X" now survives backend round-trip, as long as the backend persists and returns the same stable wishlist item IDs

Backend requirement now:

- persist `source_wishlist_item_id` on trip records
- return `source_wishlist_item_id` on both `GET /v1/social/me` and friend trip payloads if applicable
- use the same stable string ID as the referenced wishlist item’s `id`

### 7.2 Wishlist `notes` are in the spec, but not meaningfully round-tripped by the frontend

Current status:

- frontend sync sends `notes: null` for wishlist items
- local wishlist model does not really use a `notes` field

Backend requirement now:

- may persist it if sent
- not important for current app behavior

### 7.3 Planner request schema is slightly behind the real client payload

The frontend currently sends extra fields not declared in the updated OpenAPI:

- `wishlist_title`
- `trip_purpose`
- `time_mode`
- `generation_attempt`

Backend should tolerate them.

### 7.4 Credits endpoint auth/header behavior does not match the spec exactly

The spec says:

- no auth required
- optional `X-Stepped-Plan`

The frontend actually does:

- bearer auth if available
- no `X-Stepped-Plan`

Backend should accept current client behavior.

## 8. Final Backend Acceptance Checklist

## 8.1 Must-pass for core app data sync

- [ ] `GET /v1/social/me` returns complete current state for the signed-in user
- [ ] `PUT /v1/social/me/profile` persists profile edits
- [ ] `PUT /v1/social/me/travel` persists trips and visited countries
- [ ] `PUT /v1/social/me/travel` removes trips and visits missing from the new payload
- [ ] `PUT /v1/social/me/wishlist` persists wishlist items
- [ ] `PUT /v1/social/me/wishlist` removes wishlist items missing from the new payload
- [ ] `wishlist_items[].ai_plan` is stored and returned unchanged
- [ ] `wishlist_items[].is_pinned` is stored and returned correctly
- [ ] trip cover uploads work
- [ ] trip city uploads work
- [ ] wishlist image uploads work
- [ ] upload endpoints support placeholder/upsert behavior before full sync
- [ ] trip IDs remain stable across reads and writes
- [ ] wishlist item IDs remain stable across reads and writes
- [ ] visited countries survive app restart, reinstall, and login on a second device
- [ ] AI-generated wishlist plans survive app restart, reinstall, and login on a second device

## 8.2 Must-pass for auth and friends

- [ ] auth endpoints return `access_token`
- [ ] auth endpoints return correct `provider`
- [ ] `GET /v1/auth/me` returns valid current user
- [ ] friend invite creation works
- [ ] friend invite preview works
- [ ] friend invite accept works
- [ ] friends list works
- [ ] friend profile read works
- [ ] unfriend works

## 8.3 Nice-to-have or later

- [ ] persist and return `source_wishlist_item_id` with the same stable wishlist item ID used in `wishlist_items[].id`
- [ ] decide whether wishlist `notes` should become a real product field
- [ ] align `TripPlanRequest` schema with current client extras
- [ ] align credits endpoint auth/header documentation with real client behavior

## 9. Short Version For The Backend Developer

If you only read one section, read this one.

The backend must do all of the following for the current Flutter app to work correctly:

- Accept the auth token returned by Stepped auth endpoints on all protected routes
- Persist profile, trips, trip city data, visited countries, wishlist items, friend data, and privacy durably in the cloud
- Make `PUT /v1/social/me/travel` and `PUT /v1/social/me/wishlist` behave as authoritative replacement snapshots
- Preserve client-provided trip and wishlist IDs
- Store and return `wishlist_items[].ai_plan` exactly
- Store and return `wishlist_items[].is_pinned`
- Implement the three media upload routes with placeholder/upsert behavior
- Make `GET /v1/social/me` return the full current state every time

## 10. External Services Used By The App

These are not Stepped backend responsibilities, but the Flutter app does call them.

### 10.1 Google Gemini direct API

Used when AI planner source is local Gemini.

Request target:

- `https://generativelanguage.googleapis.com/{apiVersion}/models/{model}:generateContent?key={apiKey}`

Request body shape:

```json
{
  "contents": [
    {
      "parts": [
        {
          "text": "planner prompt"
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.7,
    "responseMimeType": "application/json",
    "maxOutputTokens": 2048
  }
}
```

### 10.2 Openverse image search

Used to find city and wishlist cover images.

Request target:

- `GET https://api.openverse.org/v1/images/?q=...&license=cc0,by,by-sa&mature=false&page_size=8`

The app expects an Openverse-like response with a `results` array containing image metadata such as:

- `url`
- `foreign_landing_url`
- `title`
- `creator`
- `license`
- `license_version`
- `license_url`
- `source`
