# 契約と工程の橋渡し

**この段取りの実務は、外の言葉と中の言葉を往復させることだけである。** 問い方の判断は工程の側にあり、ここには無い。

判断に迷ったときだけ読む。通常の実行は[SKILL.md](../SKILL.md)の 5 節で足りる。

## 入力を読むとき

```bash
INPUT=$(python3 "${PLUGIN_ROOT}/scripts/contract-io.py" read --config "$CFG_FILE") || exit 2
present=$(jq -er '.present' <<<"$INPUT")
```

| `present` | 何が起きているか | どうするか |
|---|---|---|
| `true` | 呼び出し元が `--input` で契約入力を渡した | `INPUT` の値だけを題材にする。会話から補わない |
| `false` | 利用者が直接呼んだ | 依頼文と会話から `topic` と `context` を立てる。`output_to` は無い |

**`present: true` の実行で入力に足りないものがあれば、`read` が exit 2 で止まる。** そのとき補って進めない。何が足りないかを呼び出し元へ告げて止まる。補って進むと、呼び出し元がかけた制限を外したのと同じになる。

`INPUT` が持つ値は次のとおり。

| キー | 使い道 |
|---|---|
| `topic` | 利用者へ見せる文言。**そのまま使う** |
| `topic_slug` | 決定ログへ渡す内部 id。**利用者へ見せない** |
| `context.purpose` / `.audience` / `.boundary` | 何を確定させたいか、誰のためか、どこまでを扱わないか |
| `questions` | 確かめる問いと推奨回答。空なら自分で立てる |
| `grounding` | 先に読む材料。ここから分かることは問い直さない |
| `output_to` | 出力 YAML の書き込み先 |

## topic を内部 id へ写す理由

決定ログは題材ごとにファイルを分けるので、題材名がファイル名に使える文字でなければならない。**その制限は記録の都合であって、呼び出し元の都合ではない。** だから契約は `topic` の文字種を縛らず、変換をこちら側に置く。

変換は決定的である。同じ `topic` は同じ `topic_slug` になるので、同じ題材の対話を複数回に分けても記録は 1 本に積み上がる。

`topic_slug` を自分で組み立てない。`contract-io.py slug --topic <題材>` か `read` の出力を使う。手で作った id は次回と一致しない。

## 出力を書くとき

工程が返した記録を、契約の 4 つ組へ写す。

- 決まったもの → `decisions[]` の `{id, question, answer, rationale}`
- 決まらなかったもの → `open_questions[]` の `{id, question, state, reason}`

`id` は、呼び出し元が `questions` で渡した `id` をそのまま使う。こちらで立てた問いには、衝突しない新しい `id` を付ける。

**状態名の正規化は `contract-io.py write` が行う。** 工程の記録上の状態名をそのまま JSON へ入れてよい。`write` が契約の `open` / `withdrawn` へ写す。契約に無い状態名は exit 2 で落ちるので、黙って別の意味に丸められることはない。

`status: failed` で返すのは、合意に達しないまま工程を閉じるときだけである。**部分的な結果を `completed` として返さない。**
