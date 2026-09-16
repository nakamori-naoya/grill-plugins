# 決定的な検査の宣言

## 配布構造

正本: `.agents/rules/plugin-package-contract.md`の配置とmanifest規則、package manifest、公開契約、playbook.yml。
入力: `plugins/grill`配下の全ファイル・directory、`plugins/`直下、両marketplaceのJSON、両manifest、playbook.yml、SKILL.md、CONTRACT.md、references。
正規化: JSONはobjectへ、YAMLはyq v4でJSONへ変換。ファイル名はpackageからの相対POSIX表記。frontmatterはYAMLとして読む。
合格述語: marketplace sourceが`./plugins/grill`で、`plugins/`直下にmanifestが無い。公開入口`skills/grill`一件の宣言がdirectoryと一致し、内部skillが無い。両runtimeのidentityとharness（marketplace、contractVersion、playbooks、implements）が一致し、`installationSurface`・`entryRoot`・`internalPlugins`を持たない。catalogのidentityがpackageと一致する。配布ファイルは下記の閉じた集合と一致し、余分な空directoryやsymlinkを含まない。playbook.ymlは`version: 2`、`name: grill`、`requires: []`で、stepsは`investigate`→`ask`→`agree`→`return`の順に`agent_work: invoking_agent`だけを持ち、最終工程が`status / decisions / open_questions / reason`をprovideする。SKILLのnameは`grill`で、Markdownのローカルリンクはpackage内の実在ファイルへ届く。SKILL・CONTRACT・references・playbook.ymlの文字列値に禁止参照形（`${.`、`<!-- BEGIN shared:`、`CLAUDE_PLUGIN_ROOT`、`BUNDLE_ROOT`）と旧runtimeファイル名への参照が無く、SKILLにshellコードブロックが無く、指示書にGherkin宣言が無い。
失敗時の診断: 違反したファイルの絶対パスと、identity・inventory・requires・steps・link・plumbing・旧参照のどの条件に違反したかを返す。
正例: 実配布packageを一時directoryへcopyした入力が通る。
反例: 必須ファイル欠落、`internal/`の追加、`plugins/`直下manifest、片側manifestの版違い、catalog版違い・source二階層違反、`skills`の文字列形、`installationSurface`や`internalPlugins`の宣言、自marketplaceの`requires`、工程順・種別・件数の違い、playbook.ymlのマクロ、名前衝突、参照切れ、旧runtime呼び出し、root解決block、shell block、Gherkin混入をそれぞれ拒否する。
境界例: `output_to`を省略しても直接objectの結果を返せる。参照文書が指定の一本なら通り、追加の一本または欠落なら拒否する。空directoryとsymlinkも拒否する。題材の語や文量は変えても構造検査が通る。
意味評価として残す範囲: 調査の真偽、問いと推奨の妥当性、一問の独立性、理由の裏付け、明示合意の解釈、対話の十分性、保存内容と合意の一致、外部呼び出しの実行挙動、判断基準と手順が実行agentに十分か。

## 配布ファイルの閉じた集合

- plugins/grill/LICENSE
- plugins/grill/.claude-plugin/plugin.json
- plugins/grill/.codex-plugin/plugin.json
- plugins/grill/skills/grill/CONTRACT.md
- plugins/grill/skills/grill/playbook.yml
- plugins/grill/skills/grill/SKILL.md
- plugins/grill/skills/grill/references/dialogue-principles.md

旧runtime参照の禁止対象はdecision.py、finalize.sh、contract-io.py、prepare.sh、run-config.py、resolve.sh、resolve-dependency.pyとする。
禁止参照形は`${.`、`<!-- BEGIN shared:`、`CLAUDE_PLUGIN_ROOT`、`BUNDLE_ROOT`とする。
Gherkinの禁止対象は指示書内のFeature:、Scenario:の行宣言とgherkinコードブロックとする。
これらは明示的な表現契約であり、対話の意味の代理ではない。行数やキーワード数は採点しない。

## 意味評価の扱い

8本の移設BDDはdialogue.featureへ保存する。自動実行したBDDとは呼ばず、エージェントが各状況の判断と停止を評価する。
単体・外部呼び出し、負例、境界例の入力・期待行動・観測結果は別の対話評価記録へ残す。
合成回答を使った手動トレースは、実利用者との対話やCodex/Claudeへのインストール試験と区別する。
