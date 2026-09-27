> 共通の規約は /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/AGENTS.md にある。ここには、この repository だけの規則を置く。

# grill package

公開・インストール対象は package `grill@grill`（`./plugins/grill`）一件で、公開入口は `skills/grill` 一件である。内部 skill は置かない。入口は自分の SKILL.md だけで、調べること、問うこと、決定と未決を返すことを同じ agent が行う。ほかの入口は、題材と目的を文章で渡して grill を呼ぶ。

問いの選び方と、未決を呼び出し元がどう扱うかは、この SKILL.md が一か所で持つ。題材固有の観点は入力から受け取り、実装や資料作成へ進まない。

対話と結果の評価は意味評価として行い、語の存在や点数で対話の正しさを判定しない。
