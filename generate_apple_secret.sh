#!/bin/bash

# Configuration
TEAM_ID="FW7825XU7W"
KEY_ID="FU4HB29JKT"
CLIENT_ID="eg.Kinnect.auth"
KEY_FILE="/Users/kyle.pfister/Desktop/AuthKey_FU4HB29JKT.p8"

# Calculate timestamps
ISSUED_AT=$(date +%s)
# Token valid for 6 months (180 days)
EXPIRATION=$(date -v+180d +%s)

# Create JWT header (base64url encoded)
HEADER=$(printf '{"alg":"ES256","kid":"%s"}' "$KEY_ID" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# Create JWT payload (base64url encoded)
PAYLOAD=$(printf '{"iss":"%s","iat":%s,"exp":%s,"aud":"https://appleid.apple.com","sub":"%s"}' "$TEAM_ID" "$ISSUED_AT" "$EXPIRATION" "$CLIENT_ID" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# Create signature
SIGNATURE=$(printf "%s.%s" "$HEADER" "$PAYLOAD" | openssl dgst -sha256 -sign "$KEY_FILE" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# Combine to create JWT
JWT="$HEADER.$PAYLOAD.$SIGNATURE"

# Output
echo "================================================================================"
echo "Apple Sign in with Apple - JWT Secret Key for Supabase"
echo "================================================================================"
echo ""
echo "Copy the token below and paste it into Supabase 'Secret Key (for OAuth)' field:"
echo ""
echo "$JWT"
echo ""
echo "================================================================================"
echo "Token expires: $(date -r $EXPIRATION '+%Y-%m-%d %H:%M:%S')"
echo "(You'll need to regenerate this token every 6 months)"
echo "================================================================================"
