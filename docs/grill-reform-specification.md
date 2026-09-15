ちr# grill-plugins 抜本改革仕様書（方針・構造・受け入れ条件）

> **対象リポジトリ**: `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/grill-plugins`  
> **準拠規約**:  
> - `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/.agents/rules/harness-principles.md`  
> - `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/.agents/rules/plugin-package-contract.md`  
> **作成日**: 2026-09-15  
> **位置付け**: Gemini (Antigravity) & Astra (GPT-6) の合同レビューに基づく確定仕様書

---

## 1. 改革の背景と目的

### 背景とコア価値
`grill-plugins` は、開発・設計プロセスの最上流において**「曖昧さを 1 問ずつ解消し、人間との明示合意を得て決定ログを残す」** という極めて重要な役割を担っています。

現行の `plugins/skills/dialogue/grill/references/questioning.md` に書かれている以下の対話哲学は、AI エージェントの自走における**最高水準の規律**であり、本リファクタリング後も 100% 維持・継承します。
1. **「事実は自分で調べる、決定は相手に返す」**（調べれば分かることは聞かず、前提を宣言して進む）
2. **「推奨回答を必ず添える（丸投げの禁止）」**（ゼロから考えさせず、確認・修正だけで進める形にする）
3. **「1 問ずつ出して答えを待つ」**（まとめて質問して難しい問いが黙って落ちるのを防ぐ）
4. **「決められないものは理由付きで未決（open）に残す」**（無理に決めさせず、未決を正直に残す）
5. **「明示合意があるまで工程を閉じない」**（決定一覧を提示し、人間の合意を得るまで終わらせない）

### 現行の病巣（解決すべき課題）
哲学が優れている一方で、実装面では `write-doc` と同様に**過剰なスクリプト依存と形式主義**に陥っています。

1. **`decision.py` による過剰なマイクロマネジメント**:
   - 1 問決まるたびに `python3 decision.py add ...` を CLI 実行させ、合意提示時にも `decision.py render` を叩かせている。エージェント自身の文脈保持・推論能力を無視した過剰な間接層（Simple made easy 違反）。
2. **シェルスクリプト実行呪文の侵食**:
   - SKILL.md の冒頭に `prepare.sh`、`run-config.py`、`yq -er`、exit 2 監視のコードが居座り、エージェントの認知資源がスクリプト実行とエラー監視に浪費されている。
3. **規律ドキュメントの肥大化（Gherkin BDD 混入）**:
   - `questioning.md`（275 行）の後半に 8 本もの Gherkin シナリオがベタ書きされており、エージェントが読むべき指示書のコンテキストを圧迫している。
4. **`write-doc` との不要な密結合**:
   - `write-doc` の内部工程から暗黙的に自動依存されており、単独ツールとしての独立性と境界が曖昧になっている。

---

## 2. アーキテクチャ設計（あるべき姿）

上位規約 `plugin-package-contract.md` および上位検査スクリプト（`validate-plugin-repository.py`）の「公開 Playbook 必須」「内部 Skill 1 つ以上宣言」の制約を満たす最小構造として、**公開入口 1 ＋ 内部対話能力 1** に集約します。

```text
/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/grill-plugins/
├── AGENTS.md
├── README.md
├── plugins/
│   ├── playbooks/dialogue/grill/
│   │   ├── playbook.yml          # 公開 Playbook: 外部契約と内部スキルの接続のみ
│   │   ├── SKILL.md              # 公開入口: 契約入力を受け取り内部スキルへ渡す
│   │   └── CONTRACT.md           # 公開契約: topic, context, questions, output_to
│   └── skills/dialogue/ask-until-agreed/
│       ├── SKILL.md              # 内部 Skill: 調査・質問・合意・決定出力の一気通貫
│       └── references/
│           └── dialogue-principles.md # 問い方と合意形成の規律（約 80〜100 行に凝縮）
```

### 廃止・撤廃するもの
- 内部スクリプト群: `decision.py`, `finalize.sh`, `prepare.sh`, `run-config.py`
- 1 問ごとの CLI 追記処理（インメモリで追跡し、最後に `output_to` へ直接 YAML 出力）
- SKILL.md 内の動的解決スクリプト呼び出し呪文
- 規律ドキュメント内の Gherkin BDD シナリオ（テストコード側へ退避）

---

## 3. 各コンポーネントの詳細仕様

### (1) 公開 Playbook: `grill`
- **`CONTRACT.md`**:
  - 外部入力スキーマ:
    - `topic` (string, 必須): 題材
    - `context` (object, 必須): `purpose`, `audience`, `boundary`
    - `questions` (配列, 必須・空配列可): `{id, question, recommendation}`
    - `grounding` (絶対パス配列, 任意): 既存の調査材料
    - `output_to` (絶対パス, 必須): 出力 YAML の書き込み先
  - 外部出力スキーマ:
    - `status` (`completed` または `failed`)
    - `decisions[]`: `{id, question, answer, rationale}`
    - `open_questions[]`: `{id, question, state: open|withdrawn, reason}`
  - スクリプト呼び出し手順や exit code 2 監視の呪文を契約から排除し、純粋なデータ契約とする。
- **`playbook.yml`**:
  - `requires` は内部スキル `ask-until-agreed` のみ。
  - `steps` は内部スキルを 1 回呼ぶだけの単一ステップとする。
- **`SKILL.md`**:
  - 契約入力を受け取り、内部スキル `ask-until-agreed` を起動して結果を `output_to` へ出力して終了する薄いディスパッチャ（スクリプト呪文ゼロ）。

---

### (2) 内部 Skill: `ask-until-agreed`
- **`SKILL.md` の責務**:
  1. `grounding` とコード・既存文書を自律調査し、事実を確定させる。
  2. 調べて分かった前提を「この前提で進める」と利用者に宣言する。
  3. 未決・論点を 1 問ずつ提示する（必ず `➡️ 推奨: ... 理由: ...` を添える）。
  4. 利用者の回答を受け取り、決定事項と未決事項をインメモリで整理する。
  5. 問える問いが尽きたら、決定一覧（決定・未決・取り下げ）を提示し、利用者の「明示合意」を得る。
  6. 明示合意を得たら、`output_to` に直接最終 YAML を書き出して完了する。

- **参照 1: `references/dialogue-principles.md`（問い方と合意形成の規律）**:
  現行の `questioning.md`（275 行）と `workflow.md`（43 行）から、エージェントの行動を律する本質的原則を約 80〜100 行に凝縮して記述する。
  - **事実は自分で調べ、決定は相手に返す**:
    - コードやドキュメントに答えがあるなら質問しない。調査結果は「前提」として宣言する。自分の問いに自分で答えて勝手に決定しない。
  - **1 問ずつ問い、答えを待つ**:
    - まとめて質問しない。前の問いの答えによって次の問いが変わるため、1 問ずつ進める。
  - **推奨回答と理由を必ず添える**:
    - 丸投げの「どうしますか？」を禁止する。相手が確認または修正だけで進められるよう、推奨回答と根拠を提示する。
  - **前提が揃った上流から問う**:
    - スコープや前提が決まっていない段階で細かい境界値を問わない。
  - **業務の言葉で問う**:
    - 実装の詳細（内部変数名やテーブル名）ではなく、業務概念の言葉で問う。
  - **決められないものは未決（open）に残す**:
    - 情報不足や試行が必要な論点は無理に合意させず、理由を添えて未決として残す。
  - **明示合意によってのみ工程を閉じる**:
    - 決定一覧を提示し、利用者が「合意した」と明言するまで工程を完了しない。

---

## 4. 受け入れ条件（Acceptance Criteria）

本リファクタリングの完了は、以下の条件をすべて満たすことによって判定されます。

### AC 1: 上位規約・構造検査の完全通過
- リポジトリルートの検査スクリプトが成功すること:
  ```bash
  bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/scripts/validate.sh /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/grill-plugins
  ```
- 公開 Playbook（`grill`）1 つ、内部 Skill（`ask-until-agreed`）1 つが正しく宣言され、名前衝突や未宣言依存が存在しないこと。

### AC 2: `decision.py` およびランタイムスクリプトの完全撤廃
- `decision.py`, `finalize.sh` などの Python/Shell スクリプトがスキル実行ループから完全に排除されていること。
- 対話中に CLI 経由でファイルを逐次更新せず、合意完了時に一括で `output_to` に書き出されること。
- SKILL.md に `prepare.sh` や `run-config.py` の呼び出しが存在しないこと。

### AC 3: 規律ドキュメントの凝縮と Gherkin の分離
- `references/` 配下が `dialogue-principles.md` 1 本に集約されていること。
- Gherkin シナリオが指示書本文から排除され、エージェント向けプロンプトが簡潔で明確になっていること。

### AC 4: 公開契約（CONTRACT.md）の純化
- `CONTRACT.md` の入力スキーマ（`topic`, `context`, `questions`, `grounding`, `output_to`）および出力スキーマ（`status`, `decisions`, `open_questions`）のデータ形式が維持されていること。
- スクリプト呼び出しや終了コードの前提が排除されていること。

### AC 5: 独立動作の担保
- 単体で `/grill` として実行でき、かつ外部 Playbook から `playbook: grill` として呼び出された際にも正常に一気通貫で対話・合意形成が完了すること。

---

## 5. 移行作業手順（Execution Steps）

Astra（GPT-6）は、以下の手順に従って実装を進めてください。

1. **Phase 1: 内部スキルの整理と参照ドキュメントの作成**
   - `plugins/skills/dialogue/grill` をリネームまたは整理し、内部スキル `ask-until-agreed` を確立。
   - `references/dialogue-principles.md` を作成（Gherkin を除外した黄金律 80〜100 行）。
   - `ask-until-agreed/SKILL.md` を作成（`decision.py` や `prepare.sh` の呪文を全廃し、調査・1問提示・推奨付与・インメモリ管理・明示合意・一括出力のフローを宣言）。
2. **Phase 2: 公開 Playbook の刷新**
   - `plugins/playbooks/dialogue/grill/CONTRACT.md`, `playbook.yml`, `SKILL.md` を新仕様へ書き換え。
   - `metadata.harness` および manifest の登録情報を更新。
3. **Phase 3: 不要スクリプトの削除**
   - `decision.py`, `finalize.sh`, `contract-io.py`, `run-config.py` などの不要となったスクリプトを削除または整理。
4. **Phase 4: 静的検証と動作確認**
   - `bash scripts/validate.sh` を実行し、全項目合格を確認。
   - 単体での問い詰めテストを実施し、1問ずつ推奨付きで提示され、明示合意後に正しい YAML が出力されることを確認。
