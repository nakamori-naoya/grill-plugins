# grill

実装や資料作成に入る前に、題材の曖昧さを利用者との対話で解消するプラグインである。公開パッケージは `grill@grill` で、入口は `/grill` 一つだけである。

## 使い方

`/grill` へ題材を伝える。目的、結果を使う人、扱わない範囲、読んでほしい資料があれば添える。grill は先に資料とコードを調べ、答えが資料から一つに決まる論点は前提として示し、答えで成果が変わる問いだけを、推奨と理由を添えて一問ずつ問う。問いが尽きたら、利用者が答えた決定と、決められなかった未決と、取り下げを一覧にして返し、止まる。

ほかの入口からは、題材、目的、結果を使う人、扱わない範囲、読んでほしい資料を文章で渡して呼ぶ。

## 検証

`scripts/validate.sh` が配布物の構造を検査する。兄弟 checkout の `../harness-tools/` が要る。

## 出来の eval

grill が問いを正しく選び、推奨を決定にせず、決められない論点を未決に残せるかは、`evals/` の下のケースで確かめる。実行は `claude plugin eval` が受け持ち、出来の採点は、対話をしたエージェントとは別の Claude（採点役）が、条件ごとに判定と根拠を書いて受け持つ。eval には問いに答える利用者がいないので、実行の担当が利用者の役も務め、要件に答えがあれば「それは〜にある」とだけ答え、無ければ決めずに返す。こうすると、要件を読めば分かる問いを出したことと、利用者の決めていない推奨を決定に載せたことが、記録から読み取れる。

`evals/criteria/` には採点役への指示 `brief.md` と共通の条件 `grill-dialogue.md` を、ケースの `grading/` には固有の条件と較正の資料（実際の成果と、既知の欠陥を埋めた写し、それぞれの期待する判定）を置く。条件の重みは、利用者の原則の芯を3、対話の骨組みを2、細部を1とし、85点以上を「実用に足る」、70点以上を「手直しで使える」とする。

```bash
claude plugin eval . --case expense-claim-delegation-grill --runs 1 --ablation none \
  --keep-temp --scaffold --allow-tools Write Edit Bash --max-cost-usd 5 --no-publish
bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/harness-tools/tools/grade-eval.sh \
  "$(pwd)/evals/expense-claim/expense-claim-delegation-grill" /private/tmp/e-XXXXXX
```

条件や採点役への指示を変えたら、先に較正の資料へ採点役をかけ、期待する判定を再現できるかを確かめる。結果は `evals/results/` に書かれ、git の管理から外してある。
