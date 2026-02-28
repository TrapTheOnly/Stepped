# Stepped Cloud API (Cloud Run)

This backend provides the cloud AI endpoint used by the Flutter app when
`Settings > AI Trip Planner > AI source = Cloud API`.

## Endpoint

- `GET /healthz`
- `GET /v1/wishlist/credits`
- `POST /v1/ai/trip-plan`

Request body:

```json
{
  "country": "Japan",
  "home_base": "Dubai",
  "preferred_month": 10,
  "preferred_cities": ["Tokyo", "Kyoto"],
  "allow_additional_cities": true,
  "max_output_tokens": 900,
  "duration_preference": {
    "id": "balanced_week",
    "min_days": 6,
    "max_days": 8
  },
  "precise_window": {
    "start": "2026-10-10",
    "end": "2026-10-18"
  }
}
```

Response body:

```json
{
  "plan": {
    "country": "...",
    "summary": "...",
    "duration": { "days": 8, "reason": "...", "source": "ai_recommended" },
    "time_windows": [],
    "city_plan": [],
    "city_cards": []
  }
}
```

## Deploy (after billing is enabled)

1. Enable required APIs:

```bash
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com secretmanager.googleapis.com
```

2. Create secret (Gemini key):

```bash
echo YOUR_GEMINI_API_KEY > gemini_key.txt
gcloud secrets create stepped-gemini-key --data-file=gemini_key.txt
```

3. Deploy from source:

```bash
gcloud run deploy stepped-cloud-api \
  --source backend \
  --region us-central1 \
  --allow-unauthenticated \
  --min-instances 0 \
  --max-instances 1 \
  --cpu 1 \
  --memory 256Mi \
  --set-env-vars GEMINI_MODEL=gemini-2.5-flash \
  --set-secrets GEMINI_API_KEY=stepped-gemini-key:latest
```

4. Map custom domain (`api.stepped.world`):

```bash
gcloud run domain-mappings create \
  --service stepped-cloud-api \
  --domain api.stepped.world \
  --region us-central1
```

Then copy the DNS records shown by Google and add them in GoDaddy DNS.

## Cost profile (tiny app)

- Cloud Run min instances `0` means scale-to-zero.
- Max instances `1` prevents unexpected spend.
- Memory `256Mi` is enough for this service.
- Keep one secret and one service only.
