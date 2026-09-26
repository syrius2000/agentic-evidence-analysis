# OpenSpec Supersession Map

created: 2026-09-21 00:45 (JST)
update: 2026-09-21 00:45 (JST)
author: Codex (GPT-5)

この表はarchive済みChangeを現行挙動の正本として再利用しないための追跡対応表です。現在の規範は`openspec/specs/`であり、archiveは当時の判断・検証根拠を保持します。

| archive Change | 現行Specの参照先 | 現在の位置づけ |
| :--- | :--- | :--- |
| `2026-09-17-vcd-categorical-analysis-v4` | `two-way-evidence-analysis` | 2次元Interface 3.0、局所診断、Dashboard契約の基礎。後続Changeで改訂済み。 |
| `2026-09-17-vcd-categorical-analysis-v4-1-repair` | `two-way-evidence-analysis` | canonical実行・provenance境界へ統合済み。 |
| `2026-09-18-vcd-categorical-provenance-boundary-hardening` | `two-way-evidence-analysis` | canonical SHA・run状態の契約として統合済み。 |
| `2026-09-18-vcd-categorical-conditional-posterior-contract` | `two-way-evidence-analysis` | 2次元Jeffreys主事前α=0.5、感度α=1.0、条件付き事後契約として統合済み。 |
| `2026-09-18-vcd-categorical-scientific-dashboard` | `two-way-evidence-analysis`, `shared-dashboard-presentation` | 2次元Scientific Dashboardと共通表示契約へ統合済み。 |
| `2026-09-19-vcd-bayesian-evidence-dashboard-theme` | `three-way-dashboard-reporting`, `shared-dashboard-presentation` | 3次元テーマ・用語集の基礎。現行/legacy事前の表示は成果物由来情報に従う。 |
| `2026-09-20-shared-dashboard-theme-assets` | `shared-dashboard-presentation` | 2次元・3次元の共通テーマ、オフライン、用語集基盤として統合済み。 |
| `2026-09-21-reconcile-canonical-specs-with-current-implementation` | `analysis-workflow-governance`および対象現行Spec | 起票中。archive後に正本・派生文書・テスト台帳の関係を確定する。 |

## 利用規則

- CC-SDDの通常参照面は`openspec/specs/**/spec.md`とする。
- 指定されたactive Changeの作業中だけ、そのChange配下のdelta specを併読する。
- archiveの事前分布、CLI、指標が現行Specと異なる場合は、現行Specを採用する。
- この表で関係を解決できない場合は、実装を停止してOwnerへ照会する。
