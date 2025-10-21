#!/usr/bin/env python3
"""
Generate Apple Sign in with Apple JWT Secret for Supabase
"""

import jwt
import time
from datetime import datetime, timedelta

# Configuration
TEAM_ID = "FW7825XU7W"
KEY_ID = "FU4HB29JKT"
CLIENT_ID = "eg.Kinnect.auth"
KEY_FILE_PATH = "/Users/kyle.pfister/Desktop/AuthKey_FU4HB29JKT.p8"

# Read the private key
with open(KEY_FILE_PATH, 'r') as key_file:
    private_key = key_file.read()

# Create JWT headers
headers = {
    "kid": KEY_ID,
    "alg": "ES256"
}

# Create JWT payload
# Token valid for 6 months (Apple's maximum)
issued_at = int(time.time())
expiration = int((datetime.now() + timedelta(days=180)).timestamp())

payload = {
    "iss": TEAM_ID,
    "iat": issued_at,
    "exp": expiration,
    "aud": "https://appleid.apple.com",
    "sub": CLIENT_ID
}

# Generate the JWT
token = jwt.encode(
    payload=payload,
    key=private_key,
    algorithm="ES256",
    headers=headers
)

print("=" * 80)
print("Apple Sign in with Apple - JWT Secret Key for Supabase")
print("=" * 80)
print()
print("Copy the token below and paste it into Supabase:")
print()
print(token)
print()
print("=" * 80)
print(f"Token expires: {datetime.fromtimestamp(expiration).strftime('%Y-%m-%d %H:%M:%S')}")
print("(You'll need to regenerate this token every 6 months)")
print("=" * 80)
