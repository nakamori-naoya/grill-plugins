---
name: grill
description: 合意に達するまで1問ずつ問い詰めて、曖昧さを潰す。推奨回答を必ず添え、調べれば分かることは聞かない。決めたことと未決を決定ログへ残す。「詰めて」「問い詰めて」「設計を固めて」と言われたとき、実装や資料作成に入る前に使う。
---

# grill（合意に達するまで問い詰める）

**このスキルは実装しないし、資料も書かない。** 曖昧さを潰して、決めたことと未決を残すところまでを担う。

**事実は自分で調べ、決定は相手に返す。** 自分の問いに自分で答えて先へ進んだ実行は、解釈の幅ではなく壊れている。

## 0. プラグイン root を決める

<!-- BEGIN shared:skill-entry/root-block -->
```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
```

`PLUGIN_ROOT`は配布物rootの絶対パスである。単一skill pluginではこの`SKILL.md`があるdirectory、複数skill pluginでは`skills/<skill>/`の2つ上に当たる。Claude Codeでは`${CLAUDE_PLUGIN_ROOT}`が自動展開される。
<!-- END shared:skill-entry/root-block -->

## 1. grillの規律を読む

<!-- BEGIN shared:skill-entry/config-load -->
```bash
CFG_FILE=$(bash "${PLUGIN_ROOT}/scripts/prepare.sh" "$(pwd)") || exit 2
printf '%s\n' "$CFG_FILE"
```

**このコマンドは説明例ではない。必ず実行する。** 解決済みYAMLが空なら先へ進まない。設定ファイルを直接読んで代用しない。

本文中の `${...}` は解決済みYAMLのプロパティである。使用時に `yq -er` で読み、欠落または `null` なら停止する。
<!-- END shared:skill-entry/config-load -->

`${.questioning}` を読む。**問い方の規律は設定ではなくこのファイルにある。** 設定が持つのは決定ログの置き場だけである。

**何を問うかはgrillの関心ではない。** domain、data model、product、デートなど題材固有の背景・前提・目的・着眼点は、依頼またはgrillを使う側の指示から受け取る。専用のaspectファイルや設定は要求せず、grill自身も題材固有の観点を同梱しない。

## 2. 1問ずつ詰めて記録する

[問い詰めワークフロー](../../references/workflow.md)を必ず読む。先に調査し、いま問える1問ずつを聞き、決まった瞬間に`decision.py`へ記録する。

**問える問いが尽きても、そこで終わりではない。** 決定・未決・取り下げを`render`で提示し、相手が合意したと言うまで工程を閉じない。

設定形式は[README](../../README.md)を参照する。実装や資料作成へ進まず、一度に大量の問いを出さず、推奨回答なしで丸投げしない。

## 実行設定の寿命

prepareが返した絶対pathを実行記録へ保持する。別shellではそのpathを`CFG_FILE`へ明示して読み、shell変数の継承を前提にしない。完了時と失敗停止時のどちらも、最後の設定利用後に`python3 "${PLUGIN_ROOT}/scripts/run-config.py" cleanup --config "$CFG_FILE"`を実行する。他runの設定やdirectoryを削除しない。
