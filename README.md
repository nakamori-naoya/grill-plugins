# grill

実装や資料作成に入る前に、題材の曖昧さを利用者との対話で解消するプラグインである。公開パッケージは `grill@grill` で、入口は `/grill` 一つだけである。

## 使い方

`/grill` へ題材を伝える。目的、結果を使う人、扱わない範囲、読んでほしい資料があれば添える。grill は先に資料とコードを調べ、答えで成果が変わる問いだけを、推奨と理由を添えて一問ずつ問う。1回で問うのは最大6問で、残りは推奨付きの未決になる。決定と未決の一覧に利用者が合意したら、その一覧を返して止まる。

ほかの入口から呼ぶときの入力と出力の名前は [plugins/grill/skills/grill/CONTRACT.md](plugins/grill/skills/grill/CONTRACT.md) にある。

## 検証

`scripts/validate.sh` が配布物の構造を検査する。兄弟 checkout の `../harness-tools/` が要る。
