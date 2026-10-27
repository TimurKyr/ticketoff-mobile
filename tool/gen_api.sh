#!/usr/bin/env bash
set -euo pipefail

openapi_url="${OPENAPI_URL:-http://localhost:8000/openapi.json}"

if ! command -v openapi-generator-cli >/dev/null 2>&1; then
  echo "openapi-generator-cli is required (install OpenAPI Generator CLI first)." >&2
  exit 1
fi

openapi-generator-cli generate \
  -i "$openapi_url" \
  -g dart-dio \
  -o lib/generated/api \
  --additional-properties=pubName=ticketoff_api,serializationLibrary=json_serializable
