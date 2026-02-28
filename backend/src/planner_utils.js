export function readNonEmptyString(value) {
  if (typeof value !== 'string') {
    return null;
  }
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

export function parseInteger(value) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.round(value);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number.parseInt(value.trim(), 10);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}

export function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

export function clampInteger(value, fallback, min, max) {
  const parsed = parseInteger(value);
  if (parsed == null) {
    return clamp(fallback, min, max);
  }
  return clamp(parsed, min, max);
}

export function tryDecodeJson(raw) {
  try {
    return JSON.parse(raw);
  } catch (_) {
    return null;
  }
}

export function startOfNextMonthUtc() {
  const now = new Date();
  const next = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1),
  );
  return next.toISOString();
}
