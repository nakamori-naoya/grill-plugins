> 共通の規約は /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/AGENTS.md にある。ここには、この repository だけの規則を置く。

# grill package

公開・インストール対象はpackage `grill@grill`（`./plugins/grill`）一件。公開入口は自己完結skill `skills/grill`一件で、公開playbook `grill`でもある。内部skillは置かない。
公開面はデータ契約（`plugins/grill/skills/grill/CONTRACT.md`）と公開入口、隣接`playbook.yml`の構成宣言だけとする。契約を変えるときはCONTRACT.mdを先に直す。
公開入口は自身のSKILL.md、playbook.yml、対話原則だけで、調査から対話、合意、結果返却までを同じagentが完結させる。
質問ごとの記録script、設定解決runtime、共有runtimeの同期、`${.`マクロや環境変数によるroot解決の配管は持たない。
事実を自分で調べ、一問ずつ推奨と理由を付け、利用者の回答と一覧への明示合意を待つ。
題材固有の観点は入力から受け取り、実装や資料作成へ進まない。

BDDと対話記録の評価は意味評価として行い、語の存在や点数で対話の正しさを判定しない。
