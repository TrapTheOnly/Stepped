import { withStatus } from './http_errors.js';
import {
  clampInteger,
  parseInteger,
  readNonEmptyString,
} from './planner_utils.js';

export function normalizeTripPlanInput(raw, config) {
  const {
    maxPreferredCities,
    maxTripDays,
    maxOutputTokens,
  } = config;
  if (!raw || typeof raw !== 'object') {
    throw withStatus(400, 'Request body must be a JSON object.');
  }

  const country = readNonEmptyString(raw.country);
  if (!country) {
    throw withStatus(400, 'country is required.');
  }

  const preferredCitiesAnalysis = normalizePreferredCities(raw.preferred_cities);
  if (preferredCitiesAnalysis.hasDuplicates) {
    throw withStatus(400, 'Remove duplicate city names before generating.');
  }
  if (preferredCitiesAnalysis.cities.length > maxPreferredCities) {
    throw withStatus(
      400,
      `You can add up to ${maxPreferredCities} preferred cities per request.`,
    );
  }
  const preferredCities = preferredCitiesAnalysis.cities;

  const preferredMonth = parseInteger(raw.preferred_month);
  const normalizedMonth =
    preferredMonth != null && preferredMonth >= 1 && preferredMonth <= 12
      ? preferredMonth
      : null;

  const preciseWindow =
    raw.precise_window && typeof raw.precise_window === 'object'
      ? {
          start: readNonEmptyString(raw.precise_window.start),
          end: readNonEmptyString(raw.precise_window.end),
        }
      : null;
  validatePreciseWindow(preciseWindow, maxTripDays);

  const durationPreference =
    raw.duration_preference && typeof raw.duration_preference === 'object'
      ? {
          id: readNonEmptyString(raw.duration_preference.id),
          minDays: parseInteger(raw.duration_preference.min_days),
          maxDays: parseInteger(raw.duration_preference.max_days),
        }
      : null;

  const requestedOutputTokens = parseInteger(raw.max_output_tokens);
  const normalizedOutputTokens = clampInteger(
    requestedOutputTokens,
    maxOutputTokens,
    128,
    maxOutputTokens,
  );

  return {
    country,
    homeBase: readNonEmptyString(raw.home_base),
    preferredCities,
    preferredMonth: normalizedMonth,
    allowAdditionalCities: Boolean(raw.allow_additional_cities),
    preciseWindow,
    durationPreference,
    maxOutputTokens: normalizedOutputTokens,
  };
}

function normalizePreferredCities(raw) {
  if (!Array.isArray(raw)) {
    return { cities: [], hasDuplicates: false };
  }

  const seen = new Set();
  const cities = [];
  let hasDuplicates = false;
  for (const value of raw) {
    const city = readNonEmptyString(value);
    if (!city) {
      continue;
    }
    const key = city.toLowerCase();
    if (seen.has(key)) {
      hasDuplicates = true;
      continue;
    }
    seen.add(key);
    cities.push(city);
  }

  return { cities, hasDuplicates };
}

function validatePreciseWindow(window, maxTripDays) {
  if (!window) {
    return;
  }
  const hasStart = Boolean(window.start);
  const hasEnd = Boolean(window.end);
  if (!hasStart && !hasEnd) {
    return;
  }
  if (!hasStart || !hasEnd) {
    throw withStatus(400, 'precise_window must include both start and end.');
  }

  const startDate = parseIsoDate(window.start);
  const endDate = parseIsoDate(window.end);
  if (!startDate || !endDate) {
    throw withStatus(
      400,
      'precise_window dates must be valid and formatted as YYYY-MM-DD.',
    );
  }
  if (endDate < startDate) {
    throw withStatus(400, 'precise_window end must be after or equal to start.');
  }
  const days = inclusiveDays(startDate, endDate);
  if (days > maxTripDays) {
    throw withStatus(400, `Trip window cannot exceed ${maxTripDays} days.`);
  }
}

function parseIsoDate(value) {
  if (typeof value !== 'string') {
    return null;
  }
  const normalized = value.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(normalized)) {
    return null;
  }
  const date = new Date(`${normalized}T00:00:00Z`);
  if (Number.isNaN(date.getTime())) {
    return null;
  }
  return date;
}

function inclusiveDays(startDate, endDate) {
  const ms = endDate.getTime() - startDate.getTime();
  return Math.floor(ms / 86400000) + 1;
}
