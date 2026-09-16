# grill

曖昧さを一問ずつ解消し、明示合意した決定と未決をYAMLで返すプラグイン。
公開パッケージは`grill@grill`、版は`5.0.0`。公開入口は`/grill`一つ。

## 単体で使う

`/grill`へ題材、目的、結果を使う人、扱わない範囲を伝える。出力先の絶対パスは保存したい場合だけ指定する。省略しても本題を進め、最終一覧への合意後に結果を会話応答として受け取れる。
最初の問いは任意。既存資料があれば絶対パスで添える。
足りない文脈は依頼から仮説を立てて前提として示す。事実は先に調べ、判断が必要な問いを成果を左右する順に最大6問へ厳選し、推奨回答と理由を付けて一問ずつ確かめる。
7問目以降と決められない論点は、推奨と理由付きで未決に残す。決定・未決・取り下げの一覧へ明示合意したら結果を返し、出力先を指定した場合だけ一括保存する。

## 外部から使う

[公開契約](plugins/grill/skills/grill/CONTRACT.md)の入力と出力を使う。

```yaml
requires:
  - {plugin: grill, marketplace: grill}
steps:
  - id: settle
    playbook: grill
    purpose: 利用者との合意を得る
    provides: [status, decisions, open_questions, reason]
```

呼び出し元は公開入口へ契約入力objectを直接渡し、利用者が回答できる会話を維持する。入力用YAML、設定解決、中間出力ファイルは使わない。
返却されたstatusとYAML objectを読み、failedなら停止する。指定先がある場合は保存結果も照合する。入力と返却形式の正本は公開契約である。

## 配置の変更（2026-09-16）

marketplaceの`source`を`./plugins`から`./plugins/grill`へ、公開入口を`plugins/playbooks/dialogue/grill`から`plugins/grill/skills/grill`へ移し、内部skill `ask-until-agreed`を公開入口へ統合した。配置変更はinstall identityを変えるため、release時にmajor bumpが要る。契約ID`grill/grill`、データ契約版`1`、入力と出力のデータ形式は変わらない。

## 3.0.0での変更

対話中のCLIによる逐次記録、設定解決、共有runtimeを廃止した。
旧版のスクリプト入口を呼ぶ利用側は、公開入口への契約入力受け渡しへ更新する。互換入口は提供しない。
契約ID`grill/grill`とデータ契約版`1`、入力と出力のデータ形式は維持する。
資料作成や実装はこのプラグインの仕事に含めない。

## 構造と検証

公開入口 `plugins/grill/skills/grill` 一件で構成する。`SKILL.md`が目的・入力・判断基準・手順・停止条件・出力を持ち、隣接`playbook.yml`が同じagentの辿る4工程（調べる→一問ずつ問う→一覧合意→結果を返す）を宣言し、対話原則は参照文書一本に置く。内部skillと薄いwrapperは持たない。
開発時の構造検査はBash、Python 3、yq v4を使う。スキルの対話実行に専用CLIは不要。
repositoryの`scripts/validate.sh`で配布構造と、その検査を壊す負例を実行する。
workspaceではrootの検査入口へ対象repositoryの絶対パスを渡す。

- [検査仕様](evals/validation-contract.md)
- [移設BDD](evals/dialogue.feature)
- [意味評価記録](evals/reform-review.md)

構造検査の成功は対話の正しさを保証しない。意味評価と実環境での確認状況は評価記録に記す。
版更新・リリース記録の作成（`release.py`）を含む保守用toolの正本は兄弟checkoutの `../harness-tools/` であり、このrepositoryは複製を持たない。`scripts/validate.sh` は `../harness-tools/tools/` の実在を確認してから呼び、無ければ止まる。CIの `validate.yml` も `harness-tools` を兄弟checkoutして `harness-tools/ci/validate.sh` を実行する。
