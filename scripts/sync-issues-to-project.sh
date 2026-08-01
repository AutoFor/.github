#!/usr/bin/env bash
# AutoFor 組織内の全リポジトリの Open Issue を org Project「All Issues」に追加する。
# 追加した Issue の Status は Backlog にする（着手するものだけ手動で Todo / In Progress へ）。
# Close 済みの反映は Project 組み込みワークフロー（Item closed → Done）が行うため、
# このスクリプトは「追加と Backlog 設定」だけを担当する（何度実行しても安全）。
set -euo pipefail

OWNER="AutoFor"
PROJECT_NUMBER="6"
PROJECT_ID="PVT_kwDOD7WBKM4BfC0y"
STATUS_FIELD_ID="PVTSSF_lADOD7WBKM4BfC0yzhZYn9s"
BACKLOG_OPTION_ID="7e745b7c"

set_backlog() {
  gh project item-edit --id "$1" --project-id "$PROJECT_ID" \
    --field-id "$STATUS_FIELD_ID" --single-select-option-id "$BACKLOG_OPTION_ID" >/dev/null
}

open_urls=$(gh search issues --owner "$OWNER" --state open --limit 1000 --json url --jq '.[].url')

existing=$(gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --limit 1000 --format json \
  --jq '[.items[].content.url // empty] | .[]')

added=0
for url in $open_urls; do
  if ! grep -qxF "$url" <<<"$existing"; then
    echo "add: $url"
    item_id=$(gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$url" --format json --jq '.id')
    set_backlog "$item_id"
    added=$((added + 1))
  fi
done

# Status 未設定の Open アイテム（サブイシュー自動追加で入った分など）も Backlog にする
no_status=$(gh api graphql --paginate -f query='query($endCursor:String){organization(login:"'"$OWNER"'"){projectV2(number:'"$PROJECT_NUMBER"'){items(first:100,after:$endCursor){pageInfo{hasNextPage endCursor}nodes{id fieldValueByName(name:"Status"){... on ProjectV2ItemFieldSingleSelectValue{name}}content{... on Issue{state}}}}}}}' \
  --jq '.data.organization.projectV2.items.nodes[] | select(.content.state=="OPEN" and .fieldValueByName==null) | .id')

fixed=0
for id in $no_status; do
  set_backlog "$id"
  fixed=$((fixed + 1))
done

echo "done: ${added} 件追加, ${fixed} 件を Backlog に設定"
