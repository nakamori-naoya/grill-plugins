# Grill

合意に達するまで1問ずつ確認し、曖昧さを潰して決定と未決を残すClaude Code/Codex両対応marketplaceである。

## こんなときに使う

**答えによって成果物や実装方針が変わる曖昧さを、利用者と一つずつ決めたいときに使う。** 一度に質問を並べず、各質問へ推奨回答と影響を添え、合意した内容を決定ログへ残す。

- 要件に複数の解釈があり、どれを選ぶかで仕様が変わる
- 対象利用者、成功条件、非目標が決まっていない
- 複数案のトレードオフを利用者と合意したい
- BDDやProduct Strategyを作る前に、未決事項を解消したい

調査すれば分かる事実を利用者へ質問する用途には使わない。自由なアイデア出しだけが目的の場合や、すでに決定済みの内容を文章化する場合にも不要である。

## 利用例

```text
この機能の対象利用者と成功条件をgrillで一つずつ決めて。
```

```text
保存期間の選択肢を整理し、推奨案を添えて合意まで進めて。
```

質問への回答によって次の質問が変わるため、利用者が回答する前に後続の質問や作業へ進まない。

## インストール

### Codex

Codexのpluginコマンドには`--scope`がない。通常の手順はuser単位でmarketplaceとpluginを登録する。

```bash
codex plugin marketplace add nakamori-naoya/grill-plugins
codex plugin add grill@grill
```

このrepositoryだけに分離したい場合は、repository専用の`CODEX_HOME`を作り、インストール時と利用時に同じ値を指定する。

```bash
mkdir -p .codex-home
export CODEX_HOME="$PWD/.codex-home"

codex plugin marketplace add nakamori-naoya/grill-plugins
codex plugin add grill@grill
codex
```

`CODEX_HOME`には認証、設定、ログ、session、plugin metadataも保存されるため、このdirectoryはGit管理しない。

### Claude Code

Claude Codeは次のscopeを選べる。

| scope | 対象 |
|---|---|
| `user` | user全体。省略時の既定値 |
| `project` | このrepositoryで有効にする設定をGitでチーム共有する |
| `local` | このrepositoryで有効にするが、Git共有せず自分だけで使う |

repository設定としてインストールする場合は`project`を指定する。`CLAUDE_PLUGIN_SCOPE`を`user`または`local`へ変えれば、同じ手順でscopeを切り替えられる。

```bash
CLAUDE_PLUGIN_SCOPE=project

claude plugin marketplace add nakamori-naoya/grill-plugins --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install grill@grill --scope "$CLAUDE_PLUGIN_SCOPE"
```

## 依存plugin

`grill@grill`に外部pluginへの依存はない。

## 設定の上書きと優先順位

設定を持つpluginは、優先順位が最も高い1ファイルだけを選ぶ。複数層をマージしないため、上書きするYAMLには同梱設定と同じ必須項目をすべて含める。必須項目の不足、未知のキー、許可されていない値があれば実行を停止する。

skillの静的設定は、上から順に優先する。

1. scope: `<scope>/<plugin-name>.config.yml`。呼び出し元がscopeを渡した実行だけで使う
2. local: `<repo>/.harness-plugins/<plugin-name>.local.yml`。端末固有で、通常はcommitしない
3. repository: `<repo>/.harness-plugins/<plugin-name>.config.yml`
4. personal: `$XDG_CONFIG_HOME/harness-plugins/<plugin-name>.config.yml`（未設定時は `~/.config/harness-plugins/<plugin-name>.config.yml`）
5. bundled defaults: plugin同梱の既定設定

playbookの静的設定は、scope、repository、personal、同梱 `playbook.yml` の順で優先する。playbookにはlocal層がない。入口playbook自身は通常のrepository設定を使い、下段のpluginへscopeを渡す。単体呼び出しではscopeを読まない。

skillでは、同梱設定の `prompt_parameters` に宣言されたpathだけ、依頼で明示された値を `--override=<path>=<value>` として最終上書きできる。宣言されていないpathを任意に上書きすることはできない。

単体利用は `<repo>/.harness-plugins/grill.config.yml`、端末固有値は `<repo>/.harness-plugins/grill.local.yml` に置く。別playbookから呼ぶ場合は、その入口が渡すscope内の `grill.config.yml` が最優先になる。

grillは問い方と決定記録だけを担い、題材固有の観点を同梱しない。単体利用では依頼の文脈、別pluginからの利用ではそのpluginの指示書から背景・前提・目的・着眼点を受け取る。

## 検証

```bash
bash scripts/validate.sh
```
