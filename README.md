# Grill

合意に達するまで1問ずつ確認し、曖昧さを潰して決定と未決を残すClaude Code/Codex両対応marketplaceである。

## インストール

Codexでは、marketplaceを登録してpluginをインストールする。

```bash
codex plugin marketplace add nakamori-naoya/grill-plugins
codex plugin add grill@grill
```

Claude Codeでは、次のコマンドを実行する。

```bash
claude plugin marketplace add nakamori-naoya/grill-plugins
claude plugin install grill@grill
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

## 検証

```bash
bash scripts/validate.sh
```
