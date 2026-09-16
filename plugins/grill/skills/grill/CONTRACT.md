# grill 公開契約 v1

曖昧さを対話で解消し、利用者が明示合意した決定と未決を返す。
契約IDは`grill/grill`、契約版は`1`、kindは`playbook`、pluginとmarketplaceと公開入口名は`grill`である。

## 入口

単体では`/grill`へ題材と文脈を渡す。外部からは次の宣言で公開入口を呼び、契約入力を渡す。

```yaml
requires:
  - {plugin: grill, marketplace: grill}
steps:
  - id: settle
    playbook: grill
    purpose: 判断が必要な曖昧さを利用者との対話で解消する
    provides: [status, decisions, open_questions, reason]
```

公開面はこのデータ契約、同じdirectoryの`playbook.yml`と`SKILL.md`である。
呼び出し元は内部skill、設定、保存途中の状態へ依存しない。

## 入力

次の入力objectを公開playbookへ直接渡す。入力用のYAMLファイルや設定解決は使わない。

```yaml
contract: grill/grill
version: 1
topic: コアドメインの取消ルール
context:
  purpose: 取消の業務ルールを確定する
  audience: 業務担当者と開発者
  boundary: 実装手段は扱わない
questions:
  - id: q1
    question: 取消の締切は何を基準にするか
    recommendation: 出荷日基準（在庫引当の解放時点と揃うため）
output_to: /tmp/grill-output.yml
```

| 名前 | 型・制約 | 必須 |
|---|---|---|
| `contract` | string、`grill/grill`固定 | 必須 |
| `version` | integer、`1`固定 | 必須 |
| `topic` | 空でないstring。日本語を含め文字種の制限なし | 必須 |
| `context` | `purpose`, `audience`, `boundary`のちょうど3キーを持つobject。値は空でないstring | 必須 |
| `questions` | `{id, question, recommendation}`のちょうど3キーを持つobjectの配列。空配列可 | 必須 |
| `questions[].id` | 空でないstring、文字は`[A-Za-z0-9._-]`、重複不可 | 必須 |
| `questions[].question` / `recommendation` | 空でないstring | 必須 |
| `grounding` | 読める通常ファイルの絶対パス配列。空配列可 | 任意 |
| `output_to` | 絶対パス。親directoryが存在し書き込めること | 任意。保存も求める場合だけ指定 |

未知キー、必須値の欠落、型・固定値の不一致は入力不備とする。値を推測で補わない。
空の`questions`は文脈から論点を探す指定であり、合意を省略する指定ではない。
`grounding`の省略は追加材料がないことを示す。関連コードや既存文書から調べる責務は残る。
単体の自然言語依頼でも外部からの構造化呼び出しでも、`output_to`の不足だけを理由に本題の調査や完了を止めない。最終結果objectは常に呼び出し元へ直接返す。保存も求められた場合だけ`output_to`を受け取り、保存先は推測しない。

## 出力

一覧と対話終了への明示合意後、次のYAML objectを結果として直接返す。指定された`output_to`がある場合だけ同じ内容を直接一括保存し、読み戻してから返す。保存先が未指定なら保存せず、呼び出し結果だけで完了する。

```yaml
contract: grill/grill
version: 1
status: completed
decisions:
  - id: q1
    question: 取消の締切は何を基準にするか
    answer: 出荷日基準
    rationale: 在庫引当の解放時点と揃えるため
open_questions:
  - id: q2
    question: 再申請の上限を設けるか
    state: open
    reason: 運用データを集めてから判断するため
```

| 名前 | 型・意味 |
|---|---|
| `contract` / `version` | 入力と同じ固定値 |
| `status` | `completed`または`failed` |
| `decisions` | completed時に必須の配列。各要素は`{id, question, answer, rationale}`、全値は空でないstring |
| `open_questions` | completed時に必須の配列。各要素は`{id, question, state, reason}`、全値は空でないstring |
| `open_questions[].state` | `open`（未決）または`withdrawn`（取り下げ） |
| `reason` | failed時だけ必須の空でない停止理由。failed時は`decisions`と`open_questions`を持たない |

入力由来の問いのIDを維持し、新しい問いのIDも同じ文字制約で採番する。両配列を通してIDを重複させない。
調査で解消した問いは確認済み前提として一覧に示し、利用者の決定には混ぜない。
配列に該当事項がなければ`[]`とする。未決が残っていても、その一覧への明示合意があればcompletedになる。

回答・合意待ちは継続待ちであり、出力を保存しない。入力不備・調査不能・中止はfailedとして停止理由を返す。
有効な書き込み先が確定していれば失敗YAMLを保存する。書けない場合は理由を応答で返し、保存済みと主張しない。

## 保証

- 事実は先に調べ、根拠付きの前提として示す。調べれば分かることを聞かない。
- 前提が揃った問いを一問ずつ出し、推奨回答と理由を必ず添える。
- 利用者の回答を待つ。自分の提案を自分で承認しない。
- 決定の理由をその場で確認し、推測で補わない。
- 決められない論点は理由付きで未決にし、取り下げと区別する。
- 決定・未決・取り下げの一覧と対話終了への明示合意があるまで完了しない。
- 対話途中のログを逐次保存しない。保存先が指定された場合だけ終端で最終YAMLを保存して読み戻す。
- 単体でも外部呼び出しでも同じ対話規律を適用し、結果を返して止める。
- 実装や資料作成は行わない。
