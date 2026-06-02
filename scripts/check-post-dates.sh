#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
shopt -s nullglob

files=("$ROOT_DIR"/site/content/*/posts/*/index.md)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No post index.md files found under site/content/*/posts/*"
  exit 0
fi

failures=0

trim() {
  local value="$1"
  # Trim leading and trailing whitespace
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

extract_ymd() {
  local raw="$1"
  local cleaned

  cleaned="$(trim "$raw")"
  cleaned="${cleaned%\"}"
  cleaned="${cleaned#\"}"
  cleaned="${cleaned%\'}"
  cleaned="${cleaned#\'}"

  if [[ $cleaned =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2}) ]]; then
    printf '%s%s%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
    return 0
  fi

  if [[ $cleaned =~ ^([0-9]{8})$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

for file in "${files[@]}"; do
  post_dir="$(basename "$(dirname "$file")")"
  folder_prefix="${post_dir:0:8}"

  if [[ ! $folder_prefix =~ ^[0-9]{8}$ ]]; then
    echo "ERROR: $file -> folder '$post_dir' must start with YYYYMMDD"
    failures=$((failures + 1))
    continue
  fi

  first_line="$(head -n1 "$file" || true)"
  if [[ $first_line != "---" && $first_line != "+++" ]]; then
    echo "ERROR: $file -> missing front matter start delimiter (--- or +++)"
    failures=$((failures + 1))
    continue
  fi

  date_line="$(awk -v delim="$first_line" '
    NR == 1 { next }
    $0 == delim { exit }
    /^[[:space:]]*date[[:space:]]*:/ { print; exit }
  ' "$file")"

  if [[ -z $date_line ]]; then
    echo "ERROR: $file -> missing 'date' field in front matter"
    failures=$((failures + 1))
    continue
  fi

  date_value="${date_line#*:}"
  if ! frontmatter_ymd="$(extract_ymd "$date_value")"; then
    echo "ERROR: $file -> unsupported date format in front matter: $(trim "$date_value")"
    failures=$((failures + 1))
    continue
  fi

  if [[ $frontmatter_ymd != $folder_prefix ]]; then
    echo "ERROR: $file -> folder date '$folder_prefix' does not match front matter date '$frontmatter_ymd'"
    failures=$((failures + 1))
  else
    echo "OK: $file"
  fi
done

if [[ $failures -gt 0 ]]; then
  echo
  echo "Validation failed with $failures issue(s)."
  exit 1
fi

echo

echo "All post dates are valid."
