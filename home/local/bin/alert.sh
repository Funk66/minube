#!/usr/bin/bash
#
# Send an email notification via SMTP using a curl container.
# Usage: alert.sh <subject> [body]
#        some-command | alert.sh <subject>
#
# If no body argument is given and stdin is not a terminal, the body is read
# from stdin. This makes it easy to pipe command output (e.g. journal logs)
# directly into the email.
#
# Reads SMTP configuration from ~/.config/smtp/credentials:
#   SMTP_HOST=mail.guirao.net
#   SMTP_PORT=465
#   SMTP_USER=...
#   SMTP_PASSWORD=...
#   SMTP_FROM=notifications@guirao.net
#   SMTP_TO=admin@guirao.net

set -euo pipefail

CREDENTIALS="$HOME/.config/smtp/credentials"

if [[ ! -f "$CREDENTIALS" ]]; then
  echo "ERROR: SMTP credentials file not found: $CREDENTIALS" >&2
  exit 1
fi

# shellcheck source=/dev/null
. "$CREDENTIALS"

SUBJECT="${1:?Usage: alert.sh <subject> [body]}"
if [[ -n "${2:-}" ]]; then
  BODY="$2"
elif [[ ! -t 0 ]]; then
  BODY=$(cat)
else
  BODY="$SUBJECT"
fi
HOSTNAME=$(hostname)
DATE=$(date -R)

curl \
  --silent --show-error \
  --url "smtps://${SMTP_HOST}:${SMTP_PORT}" \
  --user "${SMTP_USER}:${SMTP_PASSWORD}" \
  --mail-from "$SMTP_FROM" \
  --mail-rcpt "$SMTP_TO" \
  --upload-file - <<EOF
From: ${SMTP_FROM}
To: ${SMTP_TO}
Subject: ${SUBJECT}
Date: ${DATE}

${BODY}

Host: ${HOSTNAME}
EOF