#!/usr/bin/env bash
set -euo pipefail

keywords="${REVIEW_ACTIONS_FORBIDDEN_KEYWORDS:-}"
fail_on_empty="${REVIEW_ACTIONS_FAIL_ON_EMPTY:-true}"
excludes="${REVIEW_ACTIONS_EXCLUDES:-}"

if [[ -z "$keywords" ]]; then
  if [[ "$fail_on_empty" == "true" || "$fail_on_empty" == "1" ]]; then
    echo "::error title=Forbidden keyword scan not configured::No forbidden keywords were provided."
    exit 1
  fi
  echo "::warning title=Forbidden keyword scan skipped::No forbidden keywords were provided."
  exit 0
fi

keywords_file="$(mktemp)"
trap 'rm -f "$keywords_file"' EXIT

printf '%s\n' "$keywords" \
  | tr ',' '\n' \
  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
  | awk 'length > 0 { print }' > "$keywords_file"

if [[ ! -s "$keywords_file" ]]; then
  if [[ "$fail_on_empty" == "true" || "$fail_on_empty" == "1" ]]; then
    echo "::error title=Forbidden keyword scan not configured::The forbidden keyword input did not contain a non-empty keyword."
    exit 1
  fi
  echo "::warning title=Forbidden keyword scan skipped::The forbidden keyword input did not contain a non-empty keyword."
  exit 0
fi

pathspecs=()
while IFS= read -r exclude; do
  exclude="$(printf '%s' "$exclude" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -n "$exclude" ]] || continue
  pathspecs+=(":!:${exclude}")
done <<< "$excludes"

found=0

scan_file_for_keyword() {
  local file="$1"
  local keyword="$2"

  awk -v kw="$keyword" '
    BEGIN {
      kw = tolower(kw)
      matched = 0
    }
    index(tolower($0), kw) > 0 {
      printf "%s:%d\n", FILENAME, FNR
      matched = 1
    }
    END {
      exit matched ? 1 : 0
    }
  ' "$file"
}

while IFS= read -r -d '' file; do
  [[ -f "$file" ]] || continue
  if ! grep -Iq . "$file"; then
    continue
  fi

  while IFS= read -r keyword; do
    matches="$(scan_file_for_keyword "$file" "$keyword" || true)"
    if [[ -z "$matches" ]]; then
      continue
    fi

    found=1
    while IFS= read -r match; do
      [[ -n "$match" ]] || continue
      match_file="${match%:*}"
      match_line="${match##*:}"
      echo "::error file=${match_file},line=${match_line}::Forbidden keyword matched. Remove or generalize this repository content."
    done <<< "$matches"
  done < "$keywords_file"
done < <(git ls-files -z -- "${pathspecs[@]}")

if [[ "$found" -ne 0 ]]; then
  exit 1
fi

echo "Forbidden keyword scan passed."
