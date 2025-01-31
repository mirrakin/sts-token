#!/bin/bash
set -ex

# generating sts token to access the test-data-hub api
function generate_sts_token {
  local STS_TA_KEY_ID="$1"
  local STS_TA_CLIENT_ID="$2"
  local STS_TA_PRIVATE_KEY="$3"
  local STS_ISSUER="$4"

  echo "-----printing sts ta key id---------------------"
  printf "key=%s" "${STS_TA_KEY_ID}"

  HEADER_RAW=$(printf '{"alg":"RS256","typ":"JWT","kid":"%s"}' "$STS_TA_KEY_ID")
  PAYLOAD_RAW=$(printf '{"aud":"https://sts.deliveryhero.io","jti":"%s","exp":%d,"iss":"%s","sub":"%s"}' "$(uuidgen)" $(( $(date +%s) + 600 )) "$STS_TA_CLIENT_ID" "$STS_TA_CLIENT_ID")


  HEADER=$(printf "%s" "${HEADER_RAW}" | openssl base64 -A | tr -d '=' | tr '/+' '_-' )
  PAYLOAD=$(printf "%s" "${PAYLOAD_RAW}" | openssl base64 -A | tr -d '=' | tr '/+' '_-' )
  HEADER_PAYLOAD="${HEADER}"."${PAYLOAD}"

  key_file=$(mktemp)
  printf "%s" "$STS_TA_PRIVATE_KEY" > "$key_file"

  echo "==== KEY FILE CONTENT ===="
  cat "$key_file" | sed 's/./& /g'

  SIGNATURE=$(printf "%s" "${HEADER_PAYLOAD}" | openssl dgst -sha256 -sign "$key_file" | openssl base64 -A | tr -d '=' | tr '/+' '_-' )
  CLIENT_ASSERTION="${HEADER_PAYLOAD}"."${SIGNATURE}"

  response=$(curl --location --request POST "$STS_ISSUER" \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  --data-urlencode "client_assertion=$CLIENT_ASSERTION")

  access_token=$(echo "$response" | grep -o '"access_token":"[^"]*' | grep -o '[^"]*$')
  envman add --key STS_TOKEN --value "$access_token"
}

generate_sts_token "$STS_TA_KEY_ID" "$STS_TA_CLIENT_ID" "$STS_TA_PRIVATE_KEY" "$STS_ISSUER"


