import { withStatus } from './http_errors.js';
import {
  extractGeminiCandidateText,
  extractGeminiErrorMessage,
  extractGeminiJsonObject,
} from './trip_planner_response.js';
import {
  clamp,
  parseInteger,
  readNonEmptyString,
  tryDecodeJson,
} from './planner_utils.js';

export async function requestTripPlanFromGemini({
  input,
  geminiModel,
  geminiApiKey,
  maxPreferredCities,
  maxTripDays,
}) {
  if (!geminiApiKey) {
    throw withStatus(503, 'Server is missing GEMINI_API_KEY configuration.');
  }

  const prompt = buildPrompt(input);
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
    geminiModel,
  )}:generateContent?key=${encodeURIComponent(geminiApiKey)}`;

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [
        {
          role: 'user',
          parts: [{ text: prompt }],
        },
      ],
      generationConfig: {
        temperature: 0.2,
        maxOutputTokens: input.maxOutputTokens,
        responseMimeType: 'application/json',
      },
    }),
  });

  const rawBody = await response.text();
  const decoded = tryDecodeJson(rawBody);
  if (!response.ok) {
    const message = extractGeminiErrorMessage(decoded) ??
      `Gemini request failed (${response.status}).`;
    throw withStatus(502, message);
  }

  const text = extractGeminiCandidateText(decoded);
  if (!text) {
    throw withStatus(502, 'Gemini response is missing text.');
  }

  const parsed = extractGeminiJsonObject(text);
  if (!parsed || typeof parsed !== 'object') {
    throw withStatus(502, 'Gemini response JSON payload is invalid.');
  }

  return sanitizePlan(parsed, input.country, {
    maxPreferredCities,
    maxTripDays,
  });
}

function buildPrompt(input) {
  const citiesText =
    input.preferredCities.length > 0
      ? input.preferredCities.join(', ')
      : 'None';
  const windowText = input.preciseWindow?.start && input.preciseWindow?.end
    ? `${input.preciseWindow.start} to ${input.preciseWindow.end}`
    : 'Not provided';
  const durationText =
    input.durationPreference?.id &&
    input.durationPreference?.minDays != null &&
    input.durationPreference?.maxDays != null
      ? `${input.durationPreference.id} (${input.durationPreference.minDays}-${input.durationPreference.maxDays} days)`
      : 'Not provided';

  return `
You are a travel planning assistant. Return JSON only and no markdown.

INPUT
- country: ${input.country}
- traveler_home_base: ${input.homeBase ?? 'Unknown'}
- precise_date_window: ${windowText}
- preferred_month: ${input.preferredMonth ?? 'Not provided'}
- duration_preference: ${durationText}
- preferred_cities: ${citiesText}
- allow_additional_cities_if_time_allows: ${input.allowAdditionalCities}

OUTPUT SCHEMA
{
  "country": "string",
  "summary": "max 2 short sentences",
  "duration": {
    "days": 0,
    "reason": "string",
    "source": "user_selected|ai_recommended"
  },
  "time_windows": [
    { "label": "string", "months": "string", "reason": "string" }
  ],
  "city_plan": [
    { "city": "string", "days": 0, "reason": "string", "is_extra": false }
  ],
  "city_cards": [
    {
      "city": "string",
      "overview": "1 sentence",
      "image_query": "string",
      "timeline": [{ "slot": "Day X AM/PM", "place": "string", "note": "string" }],
      "things_to_do": ["string"]
    }
  ]
}

Rules:
- Keep city_plan to 1-4 cities where possible.
- Sum of city_plan days should match duration.days with max +/-1.
- If precise_date_window is provided, duration.days should match that window length.
- If duration_preference is provided, keep duration inside min/max.
- Keep every string concise and practical.
`.trim();
}

function sanitizePlan(raw, fallbackCountry, limits) {
  const country = readNonEmptyString(raw.country) || fallbackCountry;
  const summary =
    readNonEmptyString(raw.summary) || `Suggested plan for ${country}.`;
  const duration = readDuration(raw.duration);
  const timeWindows = readTimeWindows(raw.time_windows);
  const cityPlan = readCityPlan(raw.city_plan, limits);
  const cardsByCity = readCityCards(raw.city_cards);
  const cityCards = cityPlan.map((city) => {
    const key = city.city.toLowerCase();
    return cardsByCity.get(key) || {
      city: city.city,
      overview: city.reason,
      image_query: `${city.city} skyline`,
      timeline: [],
      things_to_do: [],
    };
  });

  return {
    country,
    summary,
    duration,
    time_windows: timeWindows,
    city_plan: cityPlan,
    city_cards: cityCards,
  };
}

function readDuration(raw) {
  const durationRaw = raw && typeof raw === 'object' ? raw : null;
  const durationDays = parseInteger(durationRaw?.days);
  const durationReason = readNonEmptyString(durationRaw?.reason);
  const durationSource = readNonEmptyString(durationRaw?.source);
  if (durationDays == null || durationDays <= 0) {
    return null;
  }
  return {
    days: clamp(durationDays, 1, 45),
    reason: durationReason || 'Recommended trip length.',
    source: durationSource === 'user_selected'
      ? 'user_selected'
      : 'ai_recommended',
  };
}

function readTimeWindows(raw) {
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw
    .map((item) => {
      if (!item || typeof item !== 'object') {
        return null;
      }
      const label = readNonEmptyString(item.label);
      const months = readNonEmptyString(item.months);
      const reason = readNonEmptyString(item.reason);
      return label && months && reason ? { label, months, reason } : null;
    })
    .filter(Boolean);
}

function readCityPlan(raw, limits) {
  if (!Array.isArray(raw)) {
    return [];
  }
  const parsed = [];
  const seen = new Set();
  for (const item of raw) {
    if (!item || typeof item !== 'object') {
      continue;
    }
    const city = readNonEmptyString(item.city);
    const days = parseInteger(item.days);
    const reason = readNonEmptyString(item.reason);
    if (!city || !days || !reason) {
      continue;
    }
    const key = city.toLowerCase();
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    parsed.push({
      city,
      days: clamp(days, 1, limits.maxTripDays),
      reason,
      is_extra: Boolean(item.is_extra),
    });
    if (parsed.length >= limits.maxPreferredCities) {
      break;
    }
  }
  return parsed;
}

function readCityCards(raw) {
  const cardsByCity = new Map();
  if (!Array.isArray(raw)) {
    return cardsByCity;
  }
  for (const item of raw) {
    if (!item || typeof item !== 'object') {
      continue;
    }
    const city = readNonEmptyString(item.city);
    if (!city) {
      continue;
    }
    cardsByCity.set(city.toLowerCase(), {
      city,
      overview: readNonEmptyString(item.overview) || '',
      image_query: readNonEmptyString(item.image_query) || `${city} skyline`,
      timeline: Array.isArray(item.timeline)
        ? item.timeline
            .map((step) => {
              if (!step || typeof step !== 'object') {
                return null;
              }
              const slot = readNonEmptyString(step.slot);
              const place = readNonEmptyString(step.place);
              const note = readNonEmptyString(step.note);
              return slot && place && note ? { slot, place, note } : null;
            })
            .filter(Boolean)
        : [],
      things_to_do: Array.isArray(item.things_to_do)
        ? item.things_to_do.map(readNonEmptyString).filter(Boolean)
        : [],
    });
  }
  return cardsByCity;
}
