#!/usr/bin/env bash
# Open Issue を org Project #6「All Issues」に自動追加する（追加した Issue の Status は Backlog）。
#
# Close 済みの反映は Project の組み込みワークフロー（Item closed → Done）が行うため、
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

# --- add-to-project ワークフローの自動配布 ---
# 即時反映は各リポジトリの .github/workflows/add-to-project.yml（issues: opened イベント）が担う。
# ここでは未配布のリポジトリ（主に新規作成分）を検知してテンプレートをコミットする。
# 注意: ワークフローファイルの push には PAT の workflow スコープが必要。不足時は warn を出してスキップ。
TEMPLATE="$(dirname "$0")/../templates/add-to-project.yml"
WF_PATH=".github/workflows/add-to-project.yml"
if [ -f "$TEMPLATE" ]; then
  b64=$(base64 -w0 "$TEMPLATE")
  deployed=0
  for repo in $(gh repo list "$OWNER" --limit 200 --json name,isArchived --jq '.[] | select(.isArchived|not) | .name'); do
    if ! gh api "/repos/$OWNER/$repo/contents/$WF_PATH" --silent >/dev/null 2>&1; then
      if gh api -X PUT "/repos/$OWNER/$repo/contents/$WF_PATH" \
        -f message="ci: Issue オープン時に org Project「All Issues」へ即時追加するワークフローを追加" \
        -f content="$b64" >/dev/null 2>&1; then
        echo "deploy: $repo に $WF_PATH を配布"
        deployed=$((deployed + 1))
      else
        echo "warn: $repo への配布に失敗（PAT の workflow スコープ不足の可能性）"
      fi
    fi
  done
  echo "workflow 配布: ${deployed} リポジトリ"
fi

# --- per-repo view の自動作成 ---
# Open Issue のあるリポジトリごとに、リポジトリ名の view（ボード形式・repo: フィルタ）を #6 に用意する。
# view の上限は 1 プロジェクト 50 個。45 個に達したら新規作成を止めて warn を出す。
view_count=$(gh api graphql -f query='query{organization(login:"'"$OWNER"'"){projectV2(number:6){views(first:1){totalCount}}}}' \
  --jq '.data.organization.projectV2.views.totalCount')
existing_views=$(gh api graphql -f query='query{organization(login:"'"$OWNER"'"){projectV2(number:6){views(first:50){nodes{name}}}}}' \
  --jq '.data.organization.projectV2.views.nodes[].name')
created=0
for repo in $(gh search issues --owner "$OWNER" --state open --limit 1000 --json repository --jq '.[].repository.name' | sort -u); do
  grep -qxF "$repo" <<<"$existing_views" && continue
  if [ "$view_count" -ge 45 ]; then
    echo "warn: view 数が 45 に達したため $repo の view は作成しない（上限 50。不要な view の整理が必要）"
    continue
  fi
  view_id=$(gh api graphql -f query='mutation{createProjectV2View(input:{projectId:"'"$ALL_PID"'",name:"'"$repo"'",layout:BOARD_LAYOUT}){projectV2View{id}}}' \
    --jq '.data.createProjectV2View.projectV2View.id') || { echo "warn: $repo の view 作成に失敗"; continue; }
  gh api graphql -f query='mutation{updateProjectV2View(input:{viewId:"'"$view_id"'",filter:"repo:'"$OWNER"'/'"$repo"'"}){projectV2View{id}}}' >/dev/null \
    || echo "warn: $repo の view フィルタ設定に失敗"
  view_count=$((view_count + 1))
  created=$((created + 1))
  echo "view: $repo を作成"
done
echo "view 作成: ${created} 件"
