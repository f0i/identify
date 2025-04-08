#!/usr/bin/env bash

set -eu -o pipefail

date=$(date --iso-8601)

globalping http "https://www.googleapis.com/oauth2/v3/certs" --method get --json --limit 200 > ./$date.json
jq '.. | .rawBody? // empty' $date.json | jq > "$date.txt"
echo -n "fetch locations: "
cat $date.txt | wc -l
# 99
echo -n "unique responses: "
cat $date.txt | sort -u | wc -l
# 60

(echo "let data = [" ; cat "$date.txt" | sort -u | sed "s/$/,/"; echo "];" ) > certs.mo
