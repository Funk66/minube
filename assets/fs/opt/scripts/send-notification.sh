#!/usr/bin/bash
#
# Send an email notification via AWS SES using the aws-cli container.
# Usage: send-notification.sh <subject> [body]
#        some-command | send-notification.sh <subject>
#
# If no body argument is given and stdin is not a terminal, the body is
# read from stdin, so command output (e.g. journal logs) can be piped
# directly into the email. The instance role provides the credentials.

set -euo pipefail

FROM=notifications@guirao.net
TO=ggaguilar@gmail.com
REGION=eu-central-1

SUBJECT="${1:?Usage: send-notification.sh <subject> [body]}"
if [[ -n "${2:-}" ]]; then
	BODY="$2"
elif [[ ! -t 0 ]]; then
	BODY=$(cat)
else
	BODY="$SUBJECT"
fi

# JSON via python3 so arbitrary log content can't break the CLI arguments;
# --network host because rootless pasta adds a hop and the IMDS hop limit is 1
python3 -c '
import json, sys
source, to, subject, body = sys.argv[1:5]
print(json.dumps({
    "Source": source,
    "Destination": {"ToAddresses": [to]},
    "Message": {
        "Subject": {"Data": subject},
        "Body": {"Text": {"Data": body}},
    },
}))
' "$FROM" "$TO" "$SUBJECT" "$BODY" |
	podman run --rm -i --network host docker.io/amazon/aws-cli \
		--region "$REGION" ses send-email --cli-input-json file:///dev/stdin
