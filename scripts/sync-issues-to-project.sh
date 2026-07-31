#!/usr/bin/env bash
# AutoFor 組織内の全リポジトリの Open Issue を org Project「All Issues」に追加する。
# Close 済みの反映は Project 組み込みワークフロー（Item closed → Done）が行うため、
# このスクリプトは「追加」だけを担当する（何度実行しても安全）。
set -euo pipefail

OWNER="AutoFor"
PROJECT_NUMBER="6"

open_urls=$(gh search issues --owner "$OWNER" --state open --limit 1000 --json url --jq '.[].url')

existing=$(gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --limit 1000 --format json \
  --jq '[.items[].content.url // empty] | .[]')

added=0
for url in $open_urls; do
  if ! grep -qxF "$url" <<<"$existing"; then
    echo "add: $url"
    gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$url" >/dev/null
    added=$((added + 1))
  fi
done

echo "done: ${added} 件追加"
