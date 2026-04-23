#!/bin/bash
# Load environment variables from .env file and start the Phoenix server

if [ -f .env ]; then
  set -a
  source .env
  set +a
  echo "Loaded environment variables from .env file"
else
  echo "Warning: .env file not found. Some configuration may be missing."
fi

echo "Starting Phoenix server on port 4000..."
mix phx.server
