$PROJECT="stepped-488711"
$REGION="us-central1"
$SERVICE="stepped-cloud-api"
$GEMINI_SECRET="stepped-gemini-key"
$FIREBASE_WEB_API_KEY_SECRET="stepped-firebase-web-api-key"
$MODEL="gemini-3-flash"

$GEMINI_KEY=$env:GEMINI_API_KEY
$FIREBASE_WEB_API_KEY=$env:FIREBASE_WEB_API_KEY

if ([string]::IsNullOrWhiteSpace($GEMINI_KEY)) {
    throw "Set GEMINI_API_KEY in your shell environment before running this script."
}

if ([string]::IsNullOrWhiteSpace($FIREBASE_WEB_API_KEY)) {
    throw "Set FIREBASE_WEB_API_KEY in your shell environment before running this script."
}

gcloud config set project $PROJECT

gcloud services enable `
    run.googleapis.com `
    cloudbuild.googleapis.com `
    artifactregistry.googleapis.com `
    secretmanager.googleapis.com `
    identitytoolkit.googleapis.com

if (-not (gcloud secrets describe $GEMINI_SECRET --project $PROJECT 2>$null)) {
    gcloud secrets create $GEMINI_SECRET --replication-policy=automatic
}

if (-not (gcloud secrets describe $FIREBASE_WEB_API_KEY_SECRET --project $PROJECT 2>$null)) {
    gcloud secrets create $FIREBASE_WEB_API_KEY_SECRET --replication-policy=automatic
}

$GEMINI_KEY | Set-Content -Path gemini_key.txt -NoNewline
gcloud secrets versions add $GEMINI_SECRET --data-file=gemini_key.txt
Remove-Item gemini_key.txt

$FIREBASE_WEB_API_KEY | Set-Content -Path firebase_web_api_key.txt -NoNewline
gcloud secrets versions add $FIREBASE_WEB_API_KEY_SECRET --data-file=firebase_web_api_key.txt
Remove-Item firebase_web_api_key.txt

gcloud run deploy $SERVICE `
    --source backend `
    --region $REGION `
    --allow-unauthenticated `
    --min-instances 0 `
    --max-instances 1 `
    --cpu 1 `
    --memory 256Mi `
    --set-env-vars GEMINI_MODEL=$MODEL `
    --set-secrets GEMINI_API_KEY="$GEMINI_SECRET`:latest",FIREBASE_WEB_API_KEY="$FIREBASE_WEB_API_KEY_SECRET`:latest"

$URL = gcloud run services describe $SERVICE --region $REGION --format="value(status.url)"
Write-Host "Cloud Run URL: $URL"
Invoke-WebRequest "$URL/healthz" -UseBasicParsing | Select-Object -ExpandProperty Content

# Optional custom domain (api.stepped.world) after deploy:

gcloud run domain-mappings create `
    --service $SERVICE `
    --domain api.stepped.world `
    --region $REGION

gcloud run domain-mappings describe `
    --domain api.stepped.world `
    --region $REGION `
    --format="yaml(status.resourceRecords)"
