# AGENTS.md

このrepositoryは、曖昧さを1問ずつ解消する`grill` marketplaceのsourceである。

- `grill`以外のpluginやplaybookを追加しない。
- marketplaceへ公開するインストール対象は、利用者との対話を完了させる`grill`だけにする。内部処理を別entryへ分解しない。
- 調べれば分かることを利用者へ聞かず、各質問には推奨回答を添える。
- install cacheは編集せず、このsourceを正本として変更する。
- 変更後は`bash scripts/validate.sh`を実行する。
