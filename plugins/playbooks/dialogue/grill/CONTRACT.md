# grill 公開契約 v1

**この文書に書かれていることだけが契約である。** ここに無い振る舞い・名前・path・ファイル形式は、いつ変わってもよい提供側の内部事情であり、消費側はそれに依存してはならない。

| 項目 | 値 |
|---|---|
| 契約 ID | `grill/grill` |
| 版 | 1 |
| kind | `playbook` |
| playbook 名 | `grill` |
| marketplace | `grill` |
| plugin | `grill` |

消費側の `playbook.yml` はこれを次の 2 行だけで要求する。

```yaml
requires:
  - {plugin: grill, marketplace: grill}

steps:
  - id: settle
    playbook: grill
    purpose: 入力だけでは決まらない事実と判断を、1問ずつ推奨つきで確かめる
    provides: [decisions, open_questions]
```

利用者は `~/.config/harness-plugins/dependencies.yml` などで契約 ID `grill/grill` に別の実体を束縛できる。**消費側は `requires` を書き換えない。**

---

## 1. 入口

外部から参照してよいのは次の 4 点だけである。`<root>` は解決済み YAML の `${.deps.<論理名>.root}`。

| # | 入口 | 形 |
|---|---|---|
| E1 | `<root>/scripts/prepare.sh <repo> --input=<絶対path> [--scope=<dir>] [--bindings=<lock>]` | 解決済み YAML の**絶対 path を 1 行**、stdout へ。失敗は exit 2、stdout は空。**§2 の入力 schema はこの入口で検査され、違反は exit 2 で止まる** |
| E2 | `<root>/playbook.yml` | `version: 2`、`name: grill` |
| E3 | `<root>/scripts/resolve.sh` | `prepare.sh` が内部で呼ぶ入口（`--check-steps` 経路を含む） |
| E4 | `${.deps.grill.entry}` | **playbook 入口の SKILL.md の絶対 path**。実行手順はここに従う |

**`.deps.<論理名>` から組み立ててよいのは `.root`（許された suffix 付き）と `.entry` だけである。**
`entry` は `implements[]` のうち契約 ID が一致する要素の `playbook` が指す directory の `SKILL.md` である。
`entryRoot` は契約の解決に使わない。`.deps.<論理名>.skills.<名前>` を組み立てるのは**禁止**であり、消費側 lint と resolver が `external-dependency-path` として落とす。

`entry_skill`（入口 SKILL.md の frontmatter `name`）は**表示用**である。**その名前で分岐しない。** 名前が変わっても呼び出し方は変わらない。

**参照はドット形で書く。** `.deps` の後ろを角かっこと引用符で綴るブラケット形も lint が落とす。

**`<root>` から組み立ててよいのは E1〜E3 の 3 つだけである。** `<root>/skills/...`、`<root>/references/...`、`<root>/config/...`、`<root>/scripts/` 配下のそれ以外のファイルは、存在しても参照してはならない。

**呼び出し手順は「E1 で解決 → その path を E4 へ渡す」である。** 消費側は E1 が返した解決済み YAML の絶対 path を、そのまま E4 の入口 SKILL.md へ渡す。**入口 SKILL.md は受け取った path をそのまま使い、`prepare.sh` を再実行しない。** 再実行すると入口が決めた `--scope` と `--bindings` の lock が捨てられ、同じ 1 回の呼び出しに実行設定が二重にできる。

**実行設定の後始末は grill が自分で行う。** E1 を呼んだのが消費側であっても、後始末するのは grill である。消費側が `<root>` の script を実行する形は、E1〜E3 のほかに無い。

---

## 2. 入力 schema

`--input` へ渡す YAML。**この schema の検査は E1 の入口で行われる。**
契約 ID・版の不一致、未知のキー、必須キーの欠落、値の形の誤り、書けない `output_to` は、
いずれも工程を1つも実行せずに exit 2 で止まる。診断は stderr へ `[error:input-schema] key=value` の形で出る。

**path は realpath で正規化してから検査する。** `--input` の絶対 path と `output_to` の親 directory は、
祖先に symlink を含んでいてよい（macOS 既定の `TMPDIR`＝`/var/folders/...` をそのまま渡せる）。
解決済み YAML の `.input.output_to` には正規化後の絶対 path が載る。


```yaml
contract: grill/grill               # 必須。固定
version: 1                          # 必須。固定
topic: コアドメインの取消ルール       # 必須。日本語可
context:                            # 必須
  purpose: 業務として何が正しいかを確定させる
  audience: 業務を知る人と、それを形にする人
  boundary: 実装手段は扱わない
questions:                          # 必須（空配列可）
  - id: q1
    question: 取消の締切は受注日基準か出荷日基準か
    recommendation: 出荷日基準（在庫引当の解放時点と揃うため）
  - id: q2
    question: 部分取消を認めるか
    recommendation: 認めない（返金計算の分岐が業務ルールを二重化するため）
grounding:                          # 任意
  - /Users/me/src/acme/docs/domain/order.md
output_to: /var/folders/x/harness-run-abc/grill-output.yml   # 必須
```

| 名前 | 型 | 必須 | 意味 |
|---|---|---|---|
| `contract` | string | ○ | `grill/grill` 固定 |
| `version` | int | ○ | `1` 固定 |
| `topic` | string | ○ | 何について詰めるか。**文字種を制限しない。日本語をそのまま渡してよい** |
| `context` | object | ○ | `purpose` / `audience` / `boundary` のちょうど 3 つ。**何を問うかは grill の関心ではない**ので、題材固有の観点はここで渡す |
| `context.purpose` | string | ○ | この対話で何を確定させたいか |
| `context.audience` | string | ○ | 決めた結果を使うのは誰か |
| `context.boundary` | string | ○ | 今回は扱わない範囲 |
| `questions` | 配列 | ○ | `{id, question, recommendation}` のちょうど 3 キー。`id` は `[A-Za-z0-9._-]`、重複不可 |
| `grounding` | 絶対 path[] | 任意 | 既に分かっている材料。regular file であること |
| `output_to` | 絶対 path | ○ | 出力 YAML の書き込み先。親 directory が存在し書き込めること |

**`questions` の空配列は「問いはこちらで立ててよい」であって「問わなくてよい」ではない。** 件数を別のキーで渡さない（`questions` の長さと二重管理になる）。

**`recommendation` は必須である。** 推奨のない問いを積むことは、考える仕事をそのまま相手へ渡すことなので、契約として許さない。

---

## 3. 出力 schema

grill は完了時に `output_to` の絶対 path へ次の YAML を書く。

```yaml
contract: grill/grill
version: 1
status: completed                   # completed | failed
decisions:
  - id: q1
    question: 取消の締切は受注日基準か出荷日基準か
    answer: 出荷日基準
    rationale: 在庫引当の解放時点と揃えるため
open_questions:
  - id: q3
    question: 取消の再申請に上限回数を置くか
    state: open                     # open | withdrawn
    reason: 運用データがまだ無い
```

| 名前 | 型 | 意味 |
|---|---|---|
| `status` | `completed` \| `failed` | 合意まで到達したか |
| `decisions[]` | `{id, question, answer, rationale}` | **決まったこと**。`rationale` は「なぜそう決めたか」 |
| `open_questions[]` | `{id, question, state, reason}` | **決まらなかったこと** |
| `open_questions[].state` | `open` \| `withdrawn` | `open` はまだ決められない、`withdrawn` は問い自体を取り下げた |
| `reason` | string | 停止理由（`status: failed` のとき。`decisions` / `open_questions` は持たない） |

**状態名は `open` と `withdrawn` の 2 つだけである。** grill が内部の記録で使う状態名は別にあるが、それは契約ではない。提供側が変換して返す。

**出力は `decisions` と `open_questions` の 2 つだけである。** 「根拠づけられた入力」のような、決定を素材へ束ね直したものは grill の出力ではない。必要なら消費側が自分の工程で作る。

---

## 4. 契約の語と提供側の中の対応

この表の**左側だけが契約**である。右側は提供側がいつでも変えてよい。

| 契約の語 | 提供側が内部でどうするか（**非契約**） |
|---|---|
| `topic` | 決定ログ用の内部 id へ決定的に変換して工程へ渡す。利用者へ見せる文言は `topic` のまま |
| `context` | 工程へ渡す題材固有の前提として読ませる |
| `questions` | 1 問ずつ確かめる対象にする。空なら自分で問いを立てる |
| `grounding` | 先に読ませ、そこから分かることを問い直させない |
| `decisions` | 工程の記録のうち「決まった」ものを写す |
| `open_questions` | 工程の記録のうち「決まらなかった」ものを写し、状態名を `open` / `withdrawn` へ正規化する |
| `output_to` | 完了時に出力 YAML を書く |

---

## 5. 保証

| # | 保証 |
|---|---|
| GG1 | **1 問ずつ**問う。一度に大量の問いを出さない |
| GG2 | **推奨回答を必ず添える** |
| GG3 | **調べれば分かることを聞かない**。`grounding` から読み取れる事項を問い直さない |
| GG4 | **自分の問いに自分で答えて先へ進まない** |
| GG5 | `questions` が空でも問いを立て、相手が合意したと言うまで工程を閉じない |
| GG6 | 決めたことと未決を**分けて**返す |
| GG7 | 実装や資料作成へ進まない |
| GG8 | `topic` の文字種を制限しない。ログ用の変換は自分で行う |
| GG9 | `output_to` へ出力 YAML を書く。実行設定の後始末を自分で行う |
| GG10 | **失敗は停止する。** 劣化した結果を返さない。入力が schema を満たさなければ、補わずに exit 2 する |

---

## 6. 非契約

契約に書かれていないものはすべて非契約である。以下は代表例であり、網羅ではない。

| 種別 | 具体 |
|---|---|
| 工程 id | `ask` |
| 内部 skill 名・内部 plugin 名 | package の内部で使う名前。消費側から `skill:` で指しても解決しない |
| 内部 script | 決定ログの追記・読み出し・整形を行う script とその引数 |
| 決定ログ | 置き場、ファイル形式、1 件の構造、記録上の状態名 |
| 問いの生成手順 | `references/` 配下の手引き |
| config | `.harness-plugins/` に置く内部 plugin の設定キー（利用者が触るのは可、消費側 plugin が語るのは不可） |
| exit code | exit 2 以外の意味づけ |
| `run-config.py cleanup` | 後始末は GG9 で提供側が行う |

**言い換え表**

| 内部語（禁止） | 契約の言葉 |
|---|---|
| `skill: grill` を呼ぶ | `playbook: grill` を呼ぶ |
| `dropped` として返る | `open_questions[].state: withdrawn` |
| `decided` として返る | `decisions[]` の要素 |
| 決定ログの path を読む | `output_to` の出力 YAML を読む |
| topic を英数へ直してから渡す | `topic` をそのまま渡す（GG8） |
| `grounded_input` を受け取る | 消費側が `decisions` / `open_questions` から自分で束ねる |
