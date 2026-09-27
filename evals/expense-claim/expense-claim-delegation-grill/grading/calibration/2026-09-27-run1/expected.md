# 期待する判定

この較正の資料は、2026-09-27 の1回目の実行（claude plugin eval、`--runs 1 --ablation none`）で作られた記録と結果である。下の判定は、eval を組んだ担当が記録、結果、要件を読んで出したもので、採点役がこれを再現できるかで採点の形を確かめる。境目と書いた条件は、読み方で判定が分かれうるので、一致の数を別に数える。採点役には、このファイルを読ませない。

## 判定

- ask-no-researchable: PASS
- ask-decisive: PASS
- ask-order: PASS
- ask-one-with-recommendation: FAIL
- ask-business-words: PASS
- result-no-guessed-decision: PASS
- result-open-kept: PASS
- result-list: FAIL
- result-scope: PASS
- premises-from-requirements: PASS
- open-authority-gap: PASS
- cross-business-question: PASS（境目）

## 理由

ask-one-with-recommendation は、問い3が開始前の取消を認めるかと変更をどう表すかという、答えの分かれうる二つの判断を一つの案にまとめて問うているので FAIL とした。問い1も期間の境界と判定の時刻を一つにまとめている。

result-list は、q8 から q10 を「上限で問わなかった」として問わずに未決へ回しているので FAIL とした。この記録は問いの上限があった版の skill で作られたもので、今の skill では答えで成果が変わる論点を数で削らない。

cross-business-question は、代理の判断を誰の判断として表すかを、要件の監査の求めから「両方」と答えが出ているとして前提に置き、業務をまたぐ問いとしての未決には残していない。要件の文から答えが決まると読むのは筋が通るので PASS としたが、表し方まで決まったとは言えないと読めば FAIL になるので、境目とした。
