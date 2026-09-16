# grill の eval

`grill` は利用者との対話そのものを担う公開入口なので、`claude -p`（対話なし・tool無し）の1往復では判断と停止を観測できない。自動実行は行わず、人が実セッションで対話する手動evalを記録する。`scenarios.json` は agent が読む会話fixture、`dialogue.feature` は移設BDD、`fixtures/` は契約入出力の例であり、いずれも自動採点の入力ではない。

## 手動evalの手順（代表1本: 未決と取り下げを含む合意）

| 項目 | 内容 |
|---|---|
| 実施者 | 利用者役1名（Claude Code または Codex の実セッションで `grill` を呼ぶ） |
| 入力 | `scenarios.json` の `external-open-withdrawn` の `input`（`topic` / `context` / `questions` q1・q2、`output_to` は書き込める一時directoryの絶対path） |
| 利用者の発言 | 同caseの `user_turns` を順に1発言ずつ返す（q1は未決、q2は取り下げ、最後に一覧への合意） |
| 観測1 | 問いが一問ずつ出て、各問いに推奨と理由が添えられている |
| 観測2 | 合意前に決定・未決・取り下げの一覧が提示され、利用者の明示合意の後にだけ結果objectが返り `output_to` へ保存される |
| 観測3 | 結果objectで q1 が `open_questions`（推奨を仮置き）、q2 が取り下げとして区別され、呼出元が代わりに判断していない |
| 観測4 | 1回の実行で問う数が調査で見つけた問いを含めて6問以下で、超過分は問わず `open_questions` に返る |
| 記録 | 会話の全文（問い・推奨・利用者の発言・結果object）と、観測1〜4それぞれの根拠となる箇所の引用を `evals/runs/<YYYY-MM-DD>/grill-manual.md` に保存する。観測できなかった項目は「未観測」と書き、合否にしない |

実利用者との対話、合成回答での手動トレース、install後の実セッション試験は区別して記録する。
