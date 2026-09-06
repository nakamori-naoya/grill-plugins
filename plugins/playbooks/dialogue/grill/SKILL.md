---
name: grill
description: 合意に達するまで1問ずつ問い詰めて、曖昧さを潰す。推奨回答を必ず添え、調べれば分かることは聞かない。決めたことと未決を呼び出し元へ返す。「詰めて」「問い詰めて」「設計を固めて」と言われたとき、実装や資料作成に入る前に使う。
---

# grill（合意に達するまで問い詰める）

**この段取りは問い方を知らない。** 何を、どの順で呼ぶかだけを持つ。問い方の規律は工程の側にある。

**この段取りが担うのは、公開契約と内部の橋渡しである。** 呼び出し元から受けた入力を工程へ渡し、工程が出した結果を契約の形へ写して返す。契約の正本は[CONTRACT.md](CONTRACT.md)（契約 ID `grill/grill`、版 1）である。

**実装しないし、資料も書かない。** 曖昧さを潰して、決めたことと未決を残すところまでを担う。

## 0. プラグイン root を決める

<!-- BEGIN shared:skill-entry/root-block -->
```bash
BUNDLE_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
if [ -d "${BUNDLE_ROOT}/playbooks/dialogue/grill" ]; then
  PLUGIN_ROOT="${BUNDLE_ROOT}/playbooks/dialogue/grill"
else
  PLUGIN_ROOT="${BUNDLE_ROOT}"
fi
```

`PLUGIN_ROOT`は配布物rootの絶対パスである。単一skill pluginではこの`SKILL.md`があるdirectory、複数skill pluginでは`skills/<skill>/`の2つ上に当たる。Claude Codeでは`${CLAUDE_PLUGIN_ROOT}`が自動展開される。
<!-- END shared:skill-entry/root-block -->

## 1. 工程を解決する

**呼び出し元が解決済みYAMLのpathを渡してきたなら、prepareを再実行しない。** 段取りの入れ子で
prepareを重ねると、入口が決めた scope と束縛lockが捨てられ、別の実行設定が二重に作られ、
後始末の持ち主も分からなくなる。**自分でprepareするのは、自分が入口のとき（単独起動）だけである。**

<!-- BEGIN shared:skill-entry/config-load -->
```bash
if [ -n "${CFG_FILE:-}" ] && [ -f "$CFG_FILE" ]; then
  : # 呼び出し元がE1で解決済み。prepareを再実行しない（後始末は最後にこちらが行う）
else
  # 単独起動。入力YAMLがあれば --input で渡す。無ければ付けない。
  CFG_FILE=$(bash "${PLUGIN_ROOT}/scripts/prepare.sh" "$(pwd)" ${INPUT_FILE:+--input="$INPUT_FILE"}) || exit 2
fi
printf '%s\n' "$CFG_FILE"
```

**このコマンドは説明例ではない。必ず実行する。** 解決済みYAMLが空なら先へ進まない。設定ファイルを直接読んで代用しない。

本文中の `${...}` は解決済みYAMLのプロパティである。使用時に `yq -er` で読み、欠落または `null` なら停止する。
<!-- END shared:skill-entry/config-load -->

呼び出し元が段取りとしてこれを呼ぶときは、**自分の `prepare.sh --input=<abs> --scope=<dir> --bindings=<lock>` が
返した解決済みYAMLのpathをそのまま渡す**（[契約](CONTRACT.md) §1 E1）。こちらはそれを `CFG_FILE` として使う。
**受け取ったものは作り直さず、そのまま下段へ流す。**

最初に `${.instructions.execution.directive}` と `${.instructions.output.directive}` に従う。

## 2. 呼び出し元の入力を読む

```bash
INPUT=$(python3 "${PLUGIN_ROOT}/scripts/contract-io.py" read --config "$CFG_FILE") || exit 2
```

`present` が `true` なら、**その `topic` / `context` / `questions` / `grounding` が今回の題材である**。契約 schema を満たさない入力はここで停止する。呼び出し元へ足りないものを告げ、こちらで補って進めない。

`present` が `false` のときは、利用者が `/grill` で直接呼んだ実行である。依頼文と作業中の会話から `topic` と `context`（目的・読み手・扱わない範囲）を自分で立て、`output_to` は持たない。

**何を問うかはこの段取りの関心ではない。** 題材固有の背景・前提・目的・着眼点は `context` と `questions` から受け取る。専用の観点ファイルを持たず、題材固有の観点を同梱しない。

`questions` が空配列でも「問わなくてよい」ではない。**問いはこちらで立ててよい、という意味である。**

## 3. 1問ずつ詰める

`${.playbook.steps}` を上から実行する。工程 `ask` は `${.deps.grill-dialogue.skills.ask-until-agreed}` のSKILL.mdに従って実行する。**そのSKILL.mdが問い方の正本である。** 渡すものは次の4つだけである。

- 題材（`topic`）と、決定ログ用の内部id（`INPUT` の `topic_slug`）
- `context` の目的・読み手・扱わない範囲
- `questions` の問いと推奨回答（あれば）
- `grounding` の絶対path（あれば）。**そこから読み取れることは問い直さない**

**`topic` の文字種は制限しない。** 日本語の題材をそのまま受け、決定ログが受け取れる内部idへの変換は `contract-io.py` が行う。工程へは `topic_slug` を渡し、利用者へ見せる文言には `topic` を使う。

各工程を呼ぶときは `--scope=${.resolution.scope_root}` を必ず渡す。この段取りを通るときだけ効く設定がそこにある。渡さなければ効かない。

**exit 2 で止まったら先へ進まない。** 劣化した結果を返さず、どの工程で・なぜ止まったかを報告する。

## 4. 決めたことと未決を分けて返す

工程が返した記録を、次のJSONへ写して一時ファイルへ置く。

```json
{
  "status": "completed",
  "decisions":      [{"id": "q1", "question": "…", "answer": "…", "rationale": "…"}],
  "open_questions": [{"id": "q3", "question": "…", "state": "open", "reason": "…"}]
}
```

`state` は `open`（まだ決められない）か `withdrawn`（問い自体を取り下げた）だけである。**工程が使う記録上の状態名をそのまま外へ出さない。** 変換は次のコマンドが行う。

```bash
python3 "${PLUGIN_ROOT}/scripts/contract-io.py" write --config "$CFG_FILE" --result "$RESULT_JSON" || exit 2
```

これが `output_to` の絶対pathへ出力YAMLを書く。`present` が `false` の実行では `output_to` が無いので、この書き出しは行わず、決定と未決を会話へ提示するだけにする。

**問える問いが尽きても、そこで終わりではない。** 決定・未決を提示し、相手が合意したと言うまで工程を閉じない。合意が取れない、または工程が止まったときは `status: failed` と `reason` を書いて返す。

## 5. 報告する

- 通した工程の `id`
- 決めたこと（`decisions`）の件数と要点
- 残った未決（`open_questions`）と、その状態（`open` / `withdrawn`）
- 出力YAMLの**絶対パス**（`output_to` を受け取った実行のみ）
- 途中で止まったなら、**どの工程で・なぜ**

## 順番を変えたいとき

`<repo>/.harness-plugins/grill.config.yml` に `steps` を書く。**書いたら丸ごと差し替わる。** ただし `contract` は契約の正本なので、`scripts/validate-config.sh` が変更を拒む。

## 実行設定の寿命

**受け取ったCFG_FILEも、後始末するのはこちらである（GG9）。** それは呼び出し元が E1 で**この段取りの `prepare.sh`** を呼んで作らせたものであり、この実行のための設定だからである。呼び出し元に後始末を代行させない。

prepareが返した絶対pathを実行記録へ保持する。別shellではそのpathを`CFG_FILE`へ明示して読み、shell変数の継承を前提にしない。完了時と失敗停止時のどちらも、最後の設定利用後に`python3 "${PLUGIN_ROOT}/scripts/run-config.py" cleanup --config "$CFG_FILE"`を実行する。**後始末はこの段取りが自分で行い、呼び出し元に委ねない。** 他runの設定やdirectoryを削除しない。

工程を呼ぶ直前に`yq -o=json '.' "$CFG_FILE" | python3 "${PLUGIN_ROOT}/scripts/resolve-dependency.py" --check-steps <工程id>`を実行する。失敗時は工程を実行せず停止する。
