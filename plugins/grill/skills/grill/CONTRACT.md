# grill の入力と出力

ほかの入口は `requires: [{plugin: grill, marketplace: grill}]` を宣言し、step の `playbook: grill` から呼ぶ。対話の仕方は [SKILL.md](SKILL.md) にある。

## 入力

`contract: grill/grill` と `version: 1` は、どの版の入出力で呼んだかを示す。`topic` は題材である。`context` には、目的の `purpose`、結果を使う人の `audience`、扱わない範囲の `boundary` を書く。`questions` は呼び出し元が用意した問いで、`{id, question, recommendation}` の配列である。空の配列は、題材から論点を探すという意味になる。任意の `references` には読んでほしい資料の絶対パスを並べ、任意の `output_to` には保存先の絶対パスを書く。

## 出力

合意の後に、次の形で返す。

```yaml
contract: grill/grill
version: 1
status: completed
decisions:
  - {id: q1, question: 取消の締切は何を基準にするか, answer: 出荷日, rationale: 在庫引当の解放時点と揃えるため}
open_questions:
  - {id: q2, question: 再申請の上限を設けるか, state: open, reason: "運用データを集めてから決める。推奨: 上限3回"}
```

`state` は、未決なら `open`、取り下げなら `withdrawn` である。上限で問わなかった論点は `open` にし、`reason` に推奨と理由を書く。呼び出し元はその推奨を仮置きして進めてよい。止まったときは `status: failed` と、理由の `reason` だけを返す。
