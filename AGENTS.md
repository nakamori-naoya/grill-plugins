> 作業を始める前に、workspace正本入口 `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/AGENTS.md` を読み、そこから指定される共通規約とこのrepository固有の規則を適用する。

# grill package

公開・インストール対象は`grill@grill`一件。公開入口は`grill`一件、内部能力は`ask-until-agreed`一件とする。
公開面はデータ契約と公開入口、構成宣言だけとする。契約を変えるときはCONTRACT.mdを先に直す。
内部skillは自身のSKILL.mdと対話原則だけで、調査から対話、合意、結果保存までを完結させる。
質問ごとの記録script、設定解決runtime、共有runtimeの同期は持たない。
事実を自分で調べ、一問ずつ推奨と理由を付け、利用者の回答と一覧への明示合意を待つ。
題材固有の観点は入力から受け取り、実装や資料作成へ進まない。
install cacheは変更しない。sourceだけを編集する。

検証はrepositoryの`scripts/validate.sh`を実行する。構造の成功と意味評価を分けて報告する。
新しい機械検査は正本・入力・正規化・合格述語・診断・正例・反例・境界例・意味評価範囲を先に宣言する。
BDDと対話記録の評価は意味評価として行い、語の存在や点数で対話の正しさを判定しない。
