# AutoFor/.github

AutoFor 組織の共通設定・組織横断の自動化を置くリポジトリ。

## Issue 集約ボード

org Project は [All Issues (#6)](https://github.com/orgs/AutoFor/projects/6) の 1 本のみ。組織内 **全リポジトリ** の Issue をここに自動集約し、リポジトリ単位の絞り込みは per-repo view で行う。

- Open された Issue → 各リポジトリの `add-to-project.yml`（issues: opened イベント）が**即時**で Project #6 に追加し **Status: Backlog** にする
- Close された Issue → Project 組み込みワークフロー「Item closed」が自動で Status: Done に変更（即時）
- 5分おきの cron 同期は**安全網**（イベントの取りこぼし・ワークフロー未配布リポジトリの Issue を拾う）
- Status 運用: 新規はすべて Backlog に落ち、着手するものだけ手動で Todo / In Progress に引き上げる

### 仕組み

| 担当 | 内容 |
|---|---|
| 各リポジトリの `.github/workflows/add-to-project.yml` | Issue の opened/reopened イベントで即時に Project #6 へ追加＋Backlog 設定（全アクティブリポジトリに配布済み） |
| `templates/add-to-project.yml` | 上記の配布用テンプレート |
| `.github/workflows/sync-issues-to-project.yml` | 5分おきに `scripts/sync-issues-to-project.sh` を実行 |
| `scripts/sync-issues-to-project.sh` | ① `gh search issues` で組織の Open Issue を列挙し未登録分を Project に追加して Backlog 設定 ② Status 未設定の Open アイテムを Backlog に補正 ③ `add-to-project.yml` 未配布のリポジトリ（新規作成分）を検知してテンプレートを自動コミット ④ Open Issue のあるリポジトリの per-repo view（ボード・`repo:` フィルタ）を #6 に自動作成 |
| Project 組み込みワークフロー | Item closed → Done（Project 側の設定、コード管理外）。「Item added to project」ワークフローは Backlog 運用と競合するため**無効化しておくこと** |

新規リポジトリを作った場合: 次回の cron（最大5分後）でワークフローが自動配布され、以後は即時反映になる。配布までの間の Issue も cron が拾うので取りこぼしはない。

view 構成: 「All」（全件テーブル）＋ Open Issue のあるリポジトリごとのボード view（`createProjectV2View` / `updateProjectV2View` API で自動作成）。**view の上限は 1 プロジェクト 50 個**のため、45 個に達したら自動作成は止まる（warn がログに出る）。その場合は不要な view を整理するか、Slice by: Repository での絞り込みに切り替える。

### 必要なシークレット

| 名前 | 内容 |
|---|---|
| `PROJECT_SYNC_TOKEN` | classic PAT（scope: `repo`, `workflow`, `project`, `read:org`）。org Project への書き込み・全リポジトリの Issue 読み取り・ワークフロー自動配布に使用。**org シークレット（visibility: all）として設定する**こと（各リポジトリの add-to-project.yml が参照するため） |

トークンを設定・更新する場合（org シークレット。admin:org スコープの gh 認証が必要）:

```bash
gh auth refresh -h github.com -s admin:org
gh secret set PROJECT_SYNC_TOKEN --org AutoFor --visibility all -b "<token>"
```

### 注意

- リポジトリが 60 日間更新されないと GitHub が scheduled workflow を自動停止する。停止したら Actions タブから re-enable する
- 新しいリポジトリを作った場合も追加作業は不要（cron がワークフローを自動配布し、配布前の Issue も `gh search issues --owner AutoFor` が組織全体を対象にするため拾われる）
- Issue 管理の履歴: 2026-07-30 に Linear へ移行 → 2026-08-01 に GitHub Issues へ回帰（既存の Linear Issue は Linear に残置）
