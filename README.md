# AutoFor/.github

AutoFor 組織の共通設定・組織横断の自動化を置くリポジトリ。

## Issue 集約ボード

org Project へ Issue を自動集約している。

| Project | 対象 |
|---|---|
| [All Issues (#6)](https://github.com/orgs/AutoFor/projects/6) | 組織内 **全リポジトリ** の Issue |
| [im8-hr (#8)](https://github.com/orgs/AutoFor/projects/8) | `im8-EG056-hr-master-pipeline` の Issue |

- Open された Issue → GitHub Actions（5分おき）が自動で Project に追加され **Status: Backlog** になる
- Close された Issue → Project 組み込みワークフロー「Item closed」が自動で Status: Done に変更
- Status 運用: 新規はすべて Backlog に落ち、着手するものだけ手動で Todo / In Progress に引き上げる

### 仕組み

| 担当 | 内容 |
|---|---|
| `.github/workflows/sync-issues-to-project.yml` | 5分おきに `scripts/sync-issues-to-project.sh` を実行 |
| `scripts/sync-issues-to-project.sh` | `gh search issues` で組織の Open Issue を列挙し、未登録のものを Project に追加して Backlog に設定。Status 未設定の Open アイテムも Backlog に補正 |
| Project 組み込みワークフロー | Item closed → Done（Project 側の設定、コード管理外）。「Item added to project」ワークフローは Backlog 運用と競合するため**無効化しておくこと** |

### 必要なシークレット

| 名前 | 内容 |
|---|---|
| `PROJECT_SYNC_TOKEN` | classic PAT（scope: `repo`, `project`, `read:org`）。org Project への書き込みと全リポジトリの Issue 読み取りに使用 |

トークンを更新する場合:

```bash
gh secret set PROJECT_SYNC_TOKEN -R AutoFor/.github -b "<token>"
```

### 注意

- リポジトリが 60 日間更新されないと GitHub が scheduled workflow を自動停止する。停止したら Actions タブから re-enable する
- 新しいリポジトリを作った場合も追加作業は不要（`gh search issues --owner AutoFor` が組織全体を対象にするため）
- Issue 管理の履歴: 2026-07-30 に Linear へ移行 → 2026-08-01 に GitHub Issues へ回帰（既存の Linear Issue は Linear に残置）
