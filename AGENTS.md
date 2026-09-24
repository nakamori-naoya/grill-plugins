> 作業を始める前に、workspace規約入口 `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/AGENTS.md` を読み、そこから指定される共通規約とこのrepository固有の規則を適用する。

# grill package

公開・インストール対象はpackage `grill@grill`（`./plugins/grill`）一件。公開入口は自己完結skill `skills/grill`一件で、公開playbook `grill`でもある。内部skillは置かない。
公開面はデータ契約（`plugins/grill/skills/grill/CONTRACT.md`）と公開入口、隣接`playbook.yml`の構成宣言だけとする。契約を変えるときはCONTRACT.mdを先に直す。
公開入口は自身のSKILL.md、playbook.yml、対話原則だけで、調査から対話、合意、結果返却までを同じagentが完結させる。
質問ごとの記録script、設定解決runtime、共有runtimeの同期、`${.`マクロや環境変数によるroot解決の配管は持たない。
事実を自分で調べ、一問ずつ推奨と理由を付け、利用者の回答と一覧への明示合意を待つ。
題材固有の観点は入力から受け取り、実装や資料作成へ進まない。
install cacheは変更しない。sourceだけを編集する。

検証はrepositoryの`scripts/validate.sh`を実行する。構造の成功と意味評価を分けて報告する。
新しい機械検査は基準資料・入力・正規化・合格述語・診断・正例・反例・境界例・意味評価範囲を先に宣言する。
BDDと対話記録の評価は意味評価として行い、語の存在や点数で対話の正しさを判定しない。

## 検査スクリプトは、意味が一意に決まることだけを判定する

このrepositoryの検査スクリプト（validate、lint、verify、checkなど、名前を問わない）が判定してよいのは、ファイルや見出しの有無、識別子や版の一致、宣言と配置の対応、禁止された書き方の有無のように、入力と基準資料から意味が決定論的に一意に決まることだけである。読んで解釈しないと決まらないことや、件数や語の出現のような品質の代わりの指標は判定せず、エージェントが読んで評価する（意味評価）。判定が一意に決まることを宣言できない検査は作らず、詳しい条件は `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/.agents/rules/deterministic-validation.md` に従う。
