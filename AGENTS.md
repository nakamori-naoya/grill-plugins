# AGENTS.md

このrepositoryは、曖昧さを1問ずつ解消する`grill` marketplaceのsourceである。配布形は**Playbook package 1件**（`grill@grill`、`source: ./plugins`）である。

## 公開面

- 公開するインストール対象は`grill@grill` 1件だけにする。`.claude-plugin/marketplace.json`と`.agents/plugins/marketplace.json`の`plugins`を2件以上にしない。
- 公開するplaybookは`grill` 1本だけにする。package manifestの`skills`にはそのplaybook entryだけを並べ、**内部skillを並べない**。
- 外部から使ってよい面は[公開契約](plugins/playbooks/dialogue/grill/CONTRACT.md)の4点（`scripts/prepare.sh` / `playbook.yml` / `scripts/resolve.sh` / playbook入口SKILL.md）だけである。**契約を変えるときはCONTRACT.mdを先に直す。**
- 契約に無いもの（内部skill名、内部plugin名、工程id、決定ログの置き場と形式、script引数、exit code）を、READMEやリリースノートで外部向けの約束として書かない。

## 内部skill

- 問い方の実装は`plugins/skills/dialogue/grill`（内部plugin名`grill-dialogue`、skill名`ask-until-agreed`）にある。**これは公開面ではない。**
- **内部plugin名をmarketplace名`grill`と同じにしない。** resolverは`plugin == marketplace`をpackageそのものへ短絡させるので、公開playbookが自分自身を依存として解決してしまう。
- **package内のSKILL.md frontmatter `name`を重複させない。** 公開playbookが`grill`なので、内部skillは別名にする。`scripts/test-hardening.py`がpackage全体で一意性を検査する。
- 内部skillを別entryへ分解しない。増やすときは内部pluginとして`metadata.harness.internalPlugins`へ宣言し、公開面は増やさない。

## 振る舞い

- 調べれば分かることを利用者へ聞かず、各質問には推奨回答を添える。
- 題材固有の観点を同梱しない。背景・前提・目的は契約の`context`と`questions`、または依頼の文脈から受け取る。
- 実装や資料作成へ進まない。決めたことと未決を分けて返すところまでを担う。

## 保守

- install cacheは編集せず、このsourceを正本として変更する。
- 実行基盤（`shared/prepare.sh`、`shared/run-config.py`、`shared/playbook/*`、`scripts/`配下の生成物）はProduct Planning repositoryの`shared/runtime-source`が正本である。手で直さず、`python3 scripts/sync-runtime.py --source <正本directory>`で取り込む。
- 変更後は`bash scripts/validate.sh`を実行する。
