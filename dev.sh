#!/bin/bash
# Load .env file and export all variables
set -a
source .env
set +a

echo "✅ Loaded SIGNING_SALT from .env"
#mix phx.gen.secret
mix phx.server
