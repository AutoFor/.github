#!/usr/bin/env bash
# Open Issue を org Project に自動追加する（追加した Issue の Status は Backlog）。
#
# 対象プロジェクト:
#   #6 All Issues — 組織内全リポジトリの Open Issue
#   #8 im8-hr    — im8-EG056-hr-master-pipeline の Open Issue
#
# Close 済みの反映は各 Project の組み込みワークフロー（Item closed → Done）が行うため、
# このスクリプトは「追加と Backlog 設定」だけを担当する（何度実行しても安全）。
set -euo pipefail

OWNER="AutoFor"

# Open Issue の URL 一覧を stdin から受け取り、未登録分を Project に追加して Backlog にする
sync_project() {
  local number=$1 pid=$2 fid=$3 backlog=$4
  local existing added=0 url item_id
  existing=$(gh project item-list "$number" --owner "$OWNER" --limit 1000 --format json \
    --jq '[.items[].content.url // empty] | .[]')
  while read -r url; do
    [ -z "$url" ] && continue
    if ! grep -qxF "$url" <<<"$existing"; then
      echo "add(#$number): $url"
      item_id=$(gh project item-add "$number" --owner "$OWNER" --url "$url" --format json --jq '.id')
      gh project item-edit --id "$item_id" --project-id "$pid" \
        --field-id "$fid" --single-select-option-id "$backlog" >/dev/null
      added=$((added + 1))
    fi
  done
  echo "project #$number: ${added} 件追加"
}

# Status 未設定の Open アイテム（サブイシュー自動追加や Auto-add で入った分）を Backlog にする
backfill_project() {
  local number=$1 pid=$2 fid=$3 backlog=$4
  local fixed=0 id
  for id in $(gh api graphql --paginate -f query='query($endCursor:String){organization(login:"'"$OWNER"'"){projectV2(number:'"$number"'){items(first:100,after:$endCursor){pageInfo{hasNextPage endCursor}nodes{id fieldValueByName(name:"Status"){... on ProjectV2ItemFieldSingleSelectValue{name}}content{... on Issue{state}}}}}}}' \
    --jq '.data.organization.projectV2.items.nodes[] | select(.content.state=="OPEN" and .fieldValueByName==null) | .id'); do
    gh project item-edit --id "$id" --project-id "$pid" \
      --field-id "$fid" --single-select-option-id "$backlog" >/dev/null
    fixed=$((fixed + 1))
  done
  echo "project #$number: ${fixed} 件を Backlog に補正"
}

# --- #6 All Issues: 組織内全リポジトリ ---
ALL_PID="PVT_kwDOD7WBKM4BfC0y"
ALL_FID="PVTSSF_lADOD7WBKM4BfC0yzhZYn9s"
ALL_BACKLOG="7e745b7c"
gh search issues --owner "$OWNER" --state open --limit 1000 --json url --jq '.[].url' \
  | sync_project 6 "$ALL_PID" "$ALL_FID" "$ALL_BACKLOG"
backfill_project 6 "$ALL_PID" "$ALL_FID" "$ALL_BACKLOG"

# --- #8 im8-hr: im8-EG056-hr-master-pipeline ---
HR_PID="PVT_kwDOD7WBKM4BfHNi"
HR_FID="PVTSSF_lADOD7WBKM4BfHNizhZcc60"
HR_BACKLOG="5a8ea6ef"
gh issue list -R "$OWNER/im8-EG056-hr-master-pipeline" --state open --limit 1000 --json url --jq '.[].url' \
  | sync_project 8 "$HR_PID" "$HR_FID" "$HR_BACKLOG"
backfill_project 8 "$HR_PID" "$HR_FID" "$HR_BACKLOG"
