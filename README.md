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

インストールするのは`grill@grill`です。外部プラグインの追加は不要です。

内部のスキルは同梱されています。個別にインストールせず、公開入口から利用してください。

### Codex

利用するCodexと同じ設定環境で実行してください。

```bash
codex plugin marketplace add nakamori-naoya/grill-plugins
codex plugin add grill@grill
codex plugin list
```

一覧で導入先を確認し、新しい会話で利用してください。

### Claude Code

次は自分の全プロジェクトで使う例です。このプロジェクトのチームで共有する場合は`project`、このプロジェクトで自分だけが使う場合は`local`に変更し、利用先のディレクトリで実行してください。

```bash
CLAUDE_PLUGIN_SCOPE=user
claude plugin marketplace add nakamori-naoya/grill-plugins --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install grill@grill --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin list
```

一覧で導入を確認し、Claude Codeを再起動してください。すでに導入しているパッケージは、次の更新手順を使ってください。

## 更新する

GitHubから登録したmarketplaceを更新し、その公開パッケージを更新します。新規インストールと同じCodexの設定環境、Claude Codeの適用範囲を使ってください。

### Codex

```bash
codex plugin marketplace upgrade grill
codex plugin add grill@grill
codex plugin list
```

更新後は新しい会話で確認してください。ローカルのパスからmarketplaceを登録した場合は、Git版の更新コマンドではなく、その登録先のソースを更新してから追加し直します。

### Claude Code

```bash
# インストール時に合わせてuser / project / localを選ぶ
CLAUDE_PLUGIN_SCOPE=user
claude plugin marketplace update grill
claude plugin update grill@grill --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin list
```

更新後はClaude Codeを再起動してください。

marketplaceの取得と、インストール済みパッケージの更新は分けて確認します。同じバージョンとして公開された変更は、更新コマンドだけでは反映されない場合があります。「最新」と表示された場合は公開バージョンを確認し、キャッシュ内のファイルを直接編集しないでください。

コマンドは2026-09-06時点のCLIヘルプと、[Codexのmarketplace管理](https://developers.openai.com/plugins/build/plugins)、[Claude Codeの更新仕様](https://code.claude.com/docs/en/plugins-reference#plugin-update)を確認しています。

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

## 実行契約と保守

設定はprepareが返すrun専用の絶対pathで引き継ぐ。別shellで同じpathを明示し、完了・失敗停止の最後に同梱run-configのcleanupを呼ぶ。中断後は保存したpathを使い、既にcleanup済みなら設定を再解決する。

[doctor](scripts/doctor.py)は`python3 scripts/doctor.py --repo <対象project>`でCLI構文、両runtime公開入口、依存、設定の解決元を読み取り専用で診断する。`--distribution-only`は依存・project設定を検査しない限定診断であり、full診断の代用にはしない。

共通実装の開発時正本はProduct Planning repositoryの`shared/runtime-source`にある。更新時はそのsource checkoutを取得し、[生成CLI](scripts/sync-runtime.py)へ`--source <取得した正本directory>`を渡す。`--check`は生成差分と[生成履歴](shared/runtime-manifest.json)のversion・内容hash・対象集合を検査する。正本checkoutなしのCIでも同梱物のhashと対象集合を検査できる。実行時に別repositoryや生成CLIは不要である。変更は正本へ加え、同じ生成コマンドを各source repositoryへ適用する。

[release CLI](scripts/release.py)は`--plugin --version --notes --breaking --migration --checks`で更新計画を返す。`--checks`にはcodex/claudeの実検証結果、または未検証と理由を明示する。`--apply`で両manifestとcatalogの整合を確認して一括更新し、releases配下へ変更内容・移行・検証結果のJSON記録を残す。依存宣言は変更しない。

[意味評価fixture](evals/scenarios.json)を[評価runner](scripts/evaluate-skills.py)へ渡し、異なる生成modelとjudge modelを指定する。モデル名、実model利用、適用設定、入力、出力、SKILL hash、判定の引用と理由を保存する。これはツール無効の次応答を対象とした代表caseの意味評価であり、実ツールを使った全工程E2Eや全行動の保証ではない。保存・CLI・再開の検証は[振る舞い回帰試験](scripts/test-hardening.py)と既存validateが担う。実モデル未実行のfixtureを合格扱いにしない。

### 破壊的変更の移行

重複した薄いSKILL入口を廃止した。利用者は公開manifestに列挙された入口を使い、旧入口pathを保存した独自ランチャーは新しい宣言へ切り替える。設定のEXIT trapは廃止し、返されたrun pathを明示して完了・停止時にcleanupする。旧式の一時pathやshell変数だけを再利用しない。

### 開発CLIの入力境界

`doctor`、`release`、`sync-runtime`、意味評価runnerは、操作者が明示したローカルsource、出力先、adapter argvを扱う開発CLIである。外部から受け取った文書やモデル出力をCLI引数へ自動変換しない。doctorのfull modeは選んだrepositoryのresolverを実行するため、信頼するsource checkoutを対象にする。doctorは配布treeのsymlinkを読取・実行前に拒否し、sync-runtimeは生成先と正本treeのsymlinkをcopy前に拒否する。評価の会話・fixture・モデル出力はadapterへstdinデータとして渡し、実行argvに混ぜない。
