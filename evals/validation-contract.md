# 決定的な検査の宣言

## 配布構造

正本: 正式改革仕様書の第2・3・4節、package manifest、公開契約、playbook.yml。
入力: plugins配下の全ファイル・directory、両marketplaceのJSON、両manifest、playbook.yml、2本のSKILL.md。
正規化: JSONはobjectへ、YAMLはyq v4でJSONへ変換。ファイル名はrepositoryからの相対POSIX表記。frontmatterはYAMLとして読む。
合格述語: 公開入口grill一件、内部ask-until-agreed一件の宣言が指定directoryと一致する。両runtimeのidentityとharnessが一致する。catalogのidentityがpackageと一致する。配布ファイルは下記の閉じた集合と一致し、余分な空directoryやsymlinkを含まない。唯一のrequiresが内部能力を指し、唯一のstepがその能力を指す。contractのID・版・状態集合が固定値に一致する。SKILLのnameは各入口名と一致し、Markdownのローカルリンクはpackage内の実在ファイルへ届く。SKILLのshellコードブロックと、旧runtimeファイル名への参照、指示書のGherkin宣言を拒否する。
失敗時の診断: 違反したファイルの絶対パスと、identity・inventory・requires・steps・link・旧参照のどの条件に違反したかを返す。
正例: 改革後の実配布packageを一時directoryへcopyした入力が通る。
反例: 必須ファイル欠落、片側manifestの版違い、catalog版違い、未宣言の公開・内部入口、誤った依存またはstep、名前衝突、契約版違い（整数と真偽値を区別）、参照切れ、旧runtime呼び出し、Gherkin混入をそれぞれ拒否する。
境界例: 参照文書が指定の一本なら通り、追加の一本または欠落なら拒否する。空directoryとsymlinkも拒否する。題材の語や文量は変えても構造検査が通る。
意味評価として残す範囲: 調査の真偽、問いと推奨の妥当性、一問の独立性、理由の裏付け、明示合意の解釈、対話の十分性、保存内容と合意の一致、外部呼び出しの実行挙動。

## 配布ファイルの閉じた集合

- plugins/LICENSE
- plugins/.claude-plugin/plugin.json
- plugins/.codex-plugin/plugin.json
- plugins/playbooks/dialogue/grill/CONTRACT.md
- plugins/playbooks/dialogue/grill/playbook.yml
- plugins/playbooks/dialogue/grill/SKILL.md
- plugins/skills/dialogue/ask-until-agreed/SKILL.md
- plugins/skills/dialogue/ask-until-agreed/references/dialogue-principles.md

旧runtime参照の禁止対象はdecision.py、finalize.sh、contract-io.py、prepare.sh、run-config.py、resolve.sh、resolve-dependency.pyとする。
Gherkinの禁止対象は指示書内のFeature:、Scenario:の行宣言とgherkinコードブロックとする。
これらは明示的な表現契約であり、対話の意味の代理ではない。行数やキーワード数は採点しない。

## 意味評価の扱い

8本の移設BDDはdialogue.featureへ保存する。自動実行したBDDとは呼ばず、エージェントが各状況の判断と停止を評価する。
単体・外部呼び出し、負例、境界例の入力・期待行動・観測結果は別の対話評価記録へ残す。
合成回答を使った手動トレースは、実利用者との対話やCodex/Claudeへのインストール試験と区別する。
