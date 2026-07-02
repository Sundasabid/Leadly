#!/usr/bin/env bash
# Test extract-lead locally.
#
# Prerequisites:
#   1. Add your Gemini API key to /home/sundasabid/leadly/.env.local
#   2. In a separate terminal, start the function:
#        cd /home/sundasabid/leadly
#        npx supabase functions serve extract-lead --env-file .env.local --no-verify-jwt
#      (--no-verify-jwt is for local iteration only; JWT is enforced on the deployed function)
#   3. Provide a real m4a audio file as the first argument:
#        bash test_local.sh /path/to/voice_note.m4a

set -e

AUDIO_FILE="${1:-}"
FUNCTION_URL="http://localhost:54321/functions/v1/extract-lead"

if [[ -z "$AUDIO_FILE" ]]; then
  echo "Usage: bash test_local.sh <path-to-audio.m4a>"
  echo ""
  echo "Record a short voice note on your phone, transfer it here, then run:"
  echo "  bash test_local.sh ~/voice_note.m4a"
  exit 1
fi

if [[ ! -f "$AUDIO_FILE" ]]; then
  echo "File not found: $AUDIO_FILE"
  exit 1
fi

echo "Encoding audio..."
AUDIO_B64=$(base64 -w 0 "$AUDIO_FILE")

echo "Sending to $FUNCTION_URL ..."
curl -s -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d "{\"audio\": \"$AUDIO_B64\", \"mimeType\": \"audio/aac\"}" \
  | python3 -m json.tool
