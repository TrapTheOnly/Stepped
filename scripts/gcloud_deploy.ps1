$PROJECT="stepped-488711"
$REGION="us-central1"
$SERVICE="stepped-cloud-api"
$SECRET="stepped-gemini-key"
$MODEL="gemini-3-flash"   # change to gemini-3-flash if you want
$GEMINI_KEY="AIzaSyBQ8zrqL03bSOPBViPLw0rfVCQH6JVg9wA"

gcloud config set project $PROJECT

gcloud services enable `
    run.googleapis.com `
    cloudbuild.googleapis.com `
    artifactregistry.googleapis.com `
    secretmanager.googleapis.com

if (-not (gcloud secrets describe $SECRET --project $PROJECT 2>$null)) {
    gcloud secrets create $SECRET --replication-policy=automatic
}

$GEMINI_KEY | Set-Content -Path gemini_key.txt -NoNewline
gcloud secrets versions add $SECRET --data-file=gemini_key.txt
Remove-Item gemini_key.txt

gcloud run deploy $SERVICE `
    --source backend `
    --region $REGION `
    --allow-unauthenticated `
    --min-instances 0 `
    --max-instances 1 `
    --cpu 1 `
    --memory 256Mi `
    --set-env-vars GEMINI_MODEL=$MODEL `
    --set-secrets GEMINI_API_KEY="stepped-gemini-key:latest"

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