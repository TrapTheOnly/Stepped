import express from 'express';

import { clampInteger } from './src/planner_utils.js';
import { normalizeTripPlanInput } from './src/trip_planner_input.js';
import { requestTripPlanFromGemini } from './src/trip_planner_service.js';
import { buildWishlistCreditsPayload } from './src/wishlist_credits.js';

const app = express();
const port = Number(process.env.PORT ?? 8080);
const geminiModel = process.env.GEMINI_MODEL?.trim() || 'gemini-2.5-flash';

const maxPreferredCities = 4;
const maxTripDays = 30;
const defaultMaxOutputTokens = 900;
const maxOutputTokens = clampInteger(
  process.env.MAX_OUTPUT_TOKENS,
  defaultMaxOutputTokens,
  128,
  defaultMaxOutputTokens,
);

const plannerConfig = {
  maxPreferredCities,
  maxTripDays,
  maxOutputTokens,
};

app.use(express.json({ limit: '1mb' }));
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type,Authorization,X-Stepped-Plan',
  );
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  next();
});

app.get('/healthz', (_req, res) => {
  res.json({ ok: true, service: 'stepped-cloud-api' });
});

app.get('/v1/wishlist/credits', (req, res) => {
  res.json(buildWishlistCreditsPayload(req.headers['x-stepped-plan']));
});

app.post('/v1/ai/trip-plan', async (req, res) => {
  try {
    const input = normalizeTripPlanInput(req.body, plannerConfig);
    const plan = await requestTripPlanFromGemini({
      input,
      geminiModel,
      geminiApiKey: process.env.GEMINI_API_KEY?.trim(),
      maxPreferredCities,
      maxTripDays,
    });
    res.json({ plan });
  } catch (error) {
    const statusCode =
      error && typeof error === 'object' && 'statusCode' in error
        ? Number(error.statusCode)
        : 500;
    res.status(statusCode).json({
      error: statusCode >= 500 ? 'trip_plan_failed' : 'trip_plan_invalid_request',
      message: error instanceof Error ? error.message : String(error),
    });
  }
});

app.use((error, _req, res, _next) => {
  const statusCode =
    error && typeof error === 'object' && 'statusCode' in error
      ? Number(error.statusCode)
      : 500;
  const fallback = statusCode >= 500
    ? 'Unexpected server error.'
    : 'Request could not be processed.';
  res.status(statusCode).json({
    error: statusCode >= 500 ? 'server_error' : 'request_error',
    message: error instanceof Error ? error.message : fallback,
  });
});

app.listen(port, () => {
  console.log(`Stepped cloud API listening on :${port}`);
});
