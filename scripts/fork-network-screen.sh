#!/usr/bin/env bash
# Screen the docusealco/docuseal fork network for forks with commits ahead of upstream.
# Emits TSV rows incrementally, most-recently-pushed forks first, so "active fork"
# results are available early while the long tail is still being screened.
#
# Output: docs/reports/fork-screen-results.tsv
#   full_name  default_branch  stars  pushed_at  ahead  behind  status
set -u
OUT="docs/reports/fork-screen-results.tsv"
RAW="docs/reports/fork-screen-forklist.jsonl"
mkdir -p docs/reports
: > "$RAW"

echo "[$(date +%T)] fetching fork list..." >&2
page=1
while :; do
  resp=$(gh api "repos/docusealco/docuseal/forks?per_page=100&page=$page&sort=newest" 2>/dev/null) || break
  count=$(echo "$resp" | jq 'length')
  [ "$count" -eq 0 ] && break
  echo "$resp" | jq -c '.[] | {full_name, default_branch, stars: .stargazers_count, pushed_at, created_at, size, archived}' >> "$RAW"
  echo "[$(date +%T)] page $page ($count forks)" >&2
  [ "$count" -lt 100 ] && break
  page=$((page+1))
done

total=$(wc -l < "$RAW")
echo "[$(date +%T)] $total forks listed" >&2

# Candidates: pushed after creation (i.e., someone actually pushed something).
# Sort by pushed_at desc so active forks screen first.
candidates=$(jq -r 'select(.pushed_at > .created_at) | [.full_name, .default_branch, .stars, .pushed_at] | @tsv' "$RAW" | sort -t$'\t' -k4,4r)
ncand=$(echo "$candidates" | grep -c . || true)
echo "[$(date +%T)] $ncand candidates with pushes after fork creation" >&2

printf 'full_name\tbranch\tstars\tpushed_at\tahead\tbehind\tstatus\n' > "$OUT"
i=0
while IFS=$'\t' read -r name branch stars pushed; do
  [ -z "$name" ] && continue
  i=$((i+1))
  owner=${name%%/*}
  cmp=$(gh api "repos/docusealco/docuseal/compare/master...${owner}:${branch}" --jq '[.ahead_by, .behind_by] | @tsv' 2>/dev/null)
  if [ -n "$cmp" ]; then
    ahead=$(echo "$cmp" | cut -f1); behind=$(echo "$cmp" | cut -f2)
    printf '%s\t%s\t%s\t%s\t%s\t%s\tok\n' "$name" "$branch" "$stars" "$pushed" "$ahead" "$behind" >> "$OUT"
  else
    printf '%s\t%s\t%s\t%s\t\t\terr\n' "$name" "$branch" "$stars" "$pushed" >> "$OUT"
  fi
  if [ $((i % 50)) -eq 0 ]; then
    echo "[$(date +%T)] compared $i/$ncand" >&2
    # stay well inside the 5000/hr rate limit
    rem=$(gh api rate_limit --jq '.resources.core.remaining' 2>/dev/null || echo 9999)
    [ "$rem" -lt 300 ] && { echo "[$(date +%T)] rate limit low ($rem), sleeping 15m" >&2; sleep 900; }
  fi
done <<< "$candidates"

echo "[$(date +%T)] done: $i forks compared -> $OUT" >&2
