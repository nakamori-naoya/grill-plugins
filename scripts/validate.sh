#!/usr/bin/env bash
# Scenario: grill marketplaceが「公開playbook 1本 + 内部skill」のPlaybook packageとして
# 両runtimeへ配布でき、外から見える面が CONTRACT.md の4点だけに閉じている。
#
# **fixtureだけで緑にしない。** 消費側fixtureは実際の配布物（plugins/）を
# installed-cacheへ写して解決させる。乖離したfixtureで緑になる状態を作らない。
set -uo pipefail
# **継承したenvで負の試験を破らせない。** dev-map と installed-cache の上書きが外から
# 入っていると、「解決できないはず」の負例が解決してしまい、緑のまま規則が抜ける。
# 必要な検査は、自分でその場だけ設定する。
unset HARNESS_PLUGIN_DEV_ROOTS HARNESS_PLUGIN_CACHE_ROOT
# **runtimeを開発環境から拾わせない。** resolverはHARNESS_PLUGIN_RUNTIMEが無いと
# CLAUDE_PLUGIN_ROOT / CODEX_HOME や利用者のinstalled-cacheからruntimeを推測する。
# 手元にそれらがあると通り、何も入っていないCI runnerでは
# dependency-runtime-unresolved で落ちる。**検査するruntimeはここで明示する。**
# 両runtimeを見るprobeは、その場で自分のHARNESS_PLUGIN_RUNTIMEを渡して上書きする。
unset CLAUDE_PLUGIN_ROOT CODEX_HOME CLAUDE_PLUGIN_CACHE CODEX_PLUGIN_CACHE
export HARNESS_PLUGIN_RUNTIME=codex
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PACKAGE="$ROOT/plugins"
PLAYBOOK="$PACKAGE/playbooks/dialogue/grill"
INTERNAL="$PACKAGE/skills/dialogue/grill"

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/grill-validation.XXXXXX") || exit 2
TMP_ROOT=$(cd "$TMP_ROOT" && pwd -P) || exit 2
export TMPDIR="$TMP_ROOT"
trap 'rm -rf "$TMP_ROOT"' EXIT
failed=0
note() { echo "[validate] $1" >&2; failed=1; }

python3 "$ROOT/scripts/test-hardening.py" || failed=1
python3 "$ROOT/scripts/test-decisions.py" || failed=1

# ── 1. 実行基盤の複製が正本と一致する ──────────────────────────────
python3 "$ROOT/scripts/sync-runtime.py" --check >/dev/null || note 'runtime複製が正本とずれている（sync-runtime --check）'
# **自repo内の --check だけでは、正本が進んでも緑のままになる。** 兄弟checkoutの正本と
# 突き合わせる。兄弟が無ければ緑にせず失敗させる（CIは兄弟をcheckoutする）。
RUNTIME_SOURCE="$ROOT/../product-planning-plugins/shared/runtime-source"
python3 "$ROOT/scripts/sync-runtime.py" --check --source "$RUNTIME_SOURCE" >/dev/null \
  || note "正本（兄弟checkout）と一致しない、または兄弟が無い: $RUNTIME_SOURCE"
# **消費側の文書・script・設定に、外部依存の内部の作りを書かない。** resolverはplaybook.ymlしか
# 見ないので、SKILL.md / README / references / scripts を静的に見るlintを同じ規則で二重に掛ける。
for runtime in claude codex; do
  python3 "$ROOT/scripts/lint-consumer-contract.py" --repo "$ROOT" --runtime "$runtime" \
    || note "消費側契約lintが通らない（runtime=${runtime}）"
done
cmp -s "$ROOT/shared/prepare.sh" "$PLAYBOOK/scripts/prepare.sh" || note 'playbookのprepare.shが共通入口と違う'
cmp -s "$ROOT/shared/prepare.sh" "$INTERNAL/scripts/prepare.sh" || note '内部skillのprepare.shが共通入口と違う'
cmp -s "$ROOT/shared/run-config.py" "$PLAYBOOK/scripts/run-config.py" || note 'playbookのrun-config.pyが共通版と違う'
cmp -s "$ROOT/shared/run-config.py" "$INTERNAL/scripts/run-config.py" || note '内部skillのrun-config.pyが共通版と違う'
cmp -s "$ROOT/shared/playbook/resolve.sh" "$PLAYBOOK/scripts/resolve.sh" || note 'playbookのresolve.shが共通版と違う'
cmp -s "$ROOT/shared/playbook/resolve-dependency.py" "$PLAYBOOK/scripts/resolve-dependency.py" || note 'playbookのresolverが共通版と違う'
cmp -s "$ROOT/shared/playbook/state.py" "$PLAYBOOK/scripts/state.py" || note 'playbookのstate.pyが共通版と違う'
cmp -s "$ROOT/shared/skill/resolve.sh" "$INTERNAL/scripts/resolve.sh" || note '内部skillのresolve.shが共通版と違う'
for script in "$PLAYBOOK/scripts"/*.sh "$INTERNAL/scripts"/*.sh; do
  bash -n "$script" || note "shell構文が不正: $script"
done

# ── 2. 配布構造 ────────────────────────────────────────────────
python3 "$ROOT/scripts/validate-distribution.py" "$ROOT" || failed=1
python3 "$ROOT/scripts/validate-distribution.py" --self-test "$ROOT" || failed=1
for f in "$PLAYBOOK/SKILL.md" "$PLAYBOOK/CONTRACT.md" "$PLAYBOOK/playbook.yml" "$PLAYBOOK/LICENSE" \
         "$PLAYBOOK/scripts/validate-config.sh" "$PLAYBOOK/scripts/contract-io.py" \
         "$PLAYBOOK/scripts/validate-input.sh" \
         "$INTERNAL/SKILL.md" "$INTERNAL/config/defaults.yml" "$PACKAGE/LICENSE"; do
  [ -f "$f" ] || note "必須ファイルが無い: $f"
done
[ -d "$PLAYBOOK/references" ] || note 'playbookのreferences/が無い'
# **入れ子でprepareを重ねない。** 呼び出し元がE1で作った解決済みYAMLを受け取ったら、それを使う。
# 再実行するとscopeと束縛lockが捨てられ、1回の呼び出しに実行設定が二重にできる。
rg -qF 'if [ -n "${CFG_FILE:-}" ]' "$PLAYBOOK/SKILL.md" \
  || note '入口SKILL.mdに「渡されたCFG_FILEを使いprepareを再実行しない」分岐が無い'
rg -qF 'E1 で解決 → その path を E4 へ渡す' "$PLAYBOOK/CONTRACT.md" \
  || note 'CONTRACT.mdに呼び出し手順（E1の結果pathをE4へ渡す）が書かれていない'
# **内部skillはpackage rootのskills宣言に現れない。** 現れたらruntimeが登録して名前が衝突する。
jq -e '.skills == ["./playbooks/dialogue/grill"]' "$PACKAGE/.claude-plugin/plugin.json" >/dev/null \
  || note 'package のskills宣言が公開playbookだけになっていない'
# 相対リンク切れを作らない。
while IFS= read -r link; do
  [ -e "$PLAYBOOK/$link" ] || note "playbook文書の相対リンクが切れている: $link"
done < <(rg -o --no-filename '\]\(([^):]+\.md)\)' -r '$1' "$PLAYBOOK/SKILL.md" "$PLAYBOOK/CONTRACT.md" | sort -u)
for section in '^## 1\. 入口' '^## 2\. 入力 schema' '^## 3\. 出力 schema' '^## 4\. 契約の語' '^## 5\. 保証' '^## 6\. 非契約'; do
  rg -q "$section" "$PLAYBOOK/CONTRACT.md" || note "CONTRACT.mdに必須の節が無い: $section"
done
# **E4 は `${.deps.<論理名>.entry}` である。** skills map を消費側から引く形は resolver と lint が
# external-dependency-path として落とすので、CONTRACT.md に例示しない。ブラケット形も同様。
rg -qF '${.deps.grill.entry}' "$PLAYBOOK/CONTRACT.md" \
  || note 'CONTRACT.mdのE4例が ${.deps.grill.entry} になっていない'
rg -q '\$\{[^}]*\.skills[.\[]' "$PLAYBOOK/CONTRACT.md" \
  && note 'CONTRACT.mdが .deps.<x>.skills 参照を例示している（resolverとlintが落とす形）'
rg -q '\$\{[^}]*\[\s*["'"'"']' "$PLAYBOOK/CONTRACT.md" \
  && note 'CONTRACT.mdがブラケット形の ${...} 参照を例示している（lintが落とす形）'

# ── 3. manifest：両runtimeが同一値で、契約を自己宣言する ───────────────
python3 - "$PACKAGE" <<'PY' || failed=1
import json, sys
from pathlib import Path
package = Path(sys.argv[1])
data = {r: json.loads((package / f'.{r}-plugin/plugin.json').read_text()) for r in ('claude', 'codex')}
errors = []
harness = {r: d.get('metadata', {}).get('harness', {}) for r, d in data.items()}
if harness['claude'] != harness['codex']:
    errors.append('両runtimeのmetadata.harnessが一致しない')
if data['claude'].get('skills') != data['codex'].get('skills'):
    errors.append('両runtimeのskills宣言が一致しない')
h = harness['claude']
expected = {
    'installationSurface': 'playbook-package',
    'marketplace': 'grill',
    'entryRoot': './playbooks/dialogue/grill',
    'playbooks': {'grill': './playbooks/dialogue/grill'},
    'internalPlugins': {'grill-dialogue': './skills/dialogue/grill'},
    'contractVersion': 1,
    'implements': [{'id': 'grill/grill', 'version': 1, 'kind': 'playbook', 'playbook': 'grill'}],
}
for key, value in expected.items():
    if h.get(key) != value:
        errors.append(f'metadata.harness.{key} が期待値と違う: {h.get(key)!r}')
if set(h) != set(expected):
    errors.append(f'metadata.harness のキー集合が違う: {sorted(set(h) ^ set(expected))}')
# **内部pluginをmarketplace名と同じ名前にしない。** resolverは plugin==marketplace を
# packageそのものへ短絡させるので、公開playbookが自分自身を依存として解決してしまう。
if 'grill' in h.get('internalPlugins', {}):
    errors.append('内部plugin名がmarketplace名と衝突している')
for name in ('claude', 'codex'):
    if data[name].get('name') != 'grill' or data[name].get('version') != '2.0.0':
        errors.append(f'{name} package manifest identityが違う')
for message in errors:
    print('[validate] ' + message, file=sys.stderr)
raise SystemExit(1 if errors else 0)
PY
jq -e '.name=="grill" and (.plugins|length==1) and .plugins[0].name=="grill" and .plugins[0].version=="2.0.0"' \
  "$ROOT/.claude-plugin/marketplace.json" "$ROOT/.agents/plugins/marketplace.json" >/dev/null \
  || note 'marketplace catalogのidentityが不正'
jq -e '.plugins[0].source=="./plugins"' "$ROOT/.claude-plugin/marketplace.json" >/dev/null \
  || note 'Claude catalogのsourceが./pluginsでない'
jq -e '.plugins[0].source.path=="./plugins" and .plugins[0].source.source=="local"' "$ROOT/.agents/plugins/marketplace.json" >/dev/null \
  || note 'Codex catalogのsourceが./pluginsでない'
jq -e '.name=="grill-dialogue"' "$INTERNAL/.claude-plugin/plugin.json" "$INTERNAL/.codex-plugin/plugin.json" >/dev/null \
  || note '内部pluginのmanifest identityがgrill-dialogueでない'

# ── 4. playbookが単独で解決できる ───────────────────────────────
resolved="$TMP_ROOT/resolved.yml"
if ! bash "$PLAYBOOK/scripts/resolve.sh" "$ROOT" > "$resolved" 2> "$TMP_ROOT/resolve.err"; then
  note "playbookのresolve.shがexit 0で通らない: $(head -3 "$TMP_ROOT/resolve.err")"
else
  yq -o=json -I=0 '.' "$resolved" | jq -e '
    .playbook.name=="grill" and .playbook.contract.states==["open","withdrawn"] and
    (.deps|keys)==["grill-dialogue"] and
    .deps["grill-dialogue"].dependency_scope=="internal" and
    (.deps["grill-dialogue"].root|test("/plugins/skills/dialogue/grill$")) and
    (.deps["grill-dialogue"].skills["ask-until-agreed"]|test("/plugins/skills/dialogue/grill/SKILL.md$")) and
    ([.playbook.steps[].skill]==["ask-until-agreed"])' >/dev/null \
    || note '解決結果が期待した形でない（内部skillへ解決していない）'
fi
# **公開面はplaybook 1枚だけ。** packageの公開skillに内部skillが混ざっていないこと。
python3 - "$PACKAGE" "$PLAYBOOK" <<'PY' || failed=1
import json, sys, importlib.util
from pathlib import Path
package, playbook = Path(sys.argv[1]), Path(sys.argv[2])
spec = importlib.util.spec_from_file_location('resolver', playbook / 'scripts/resolve-dependency.py')
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
data = json.loads((package / '.claude-plugin/plugin.json').read_text())
public = module.public_skills(package, data)
if public != {'grill': str(playbook / 'SKILL.md')}:
    print('[validate] packageの公開skillが playbook入口1枚になっていない: %r' % public, file=sys.stderr)
    raise SystemExit(1)
PY

# ── 5. 契約の入出力（提供側の変換層） ─────────────────────────────
cio="$PLAYBOOK/scripts/contract-io.py"
[ "$(python3 "$cio" slug --topic 'コアドメインの取消ルール')" = "$(python3 "$cio" slug --topic 'コアドメインの取消ルール')" ] \
  || note '日本語topicのslug変換が決定的でない'
python3 "$cio" slug --topic 'コアドメインの取消ルール' | rg -q '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$' \
  || note '日本語topicが決定ログの受け取れる内部idへ写らない'
mkdir -p "$TMP_ROOT/io"
cat > "$TMP_ROOT/io/input.yml" <<YML
contract: grill/grill
version: 1
topic: コアドメインの取消ルール
context:
  purpose: 業務として何が正しいかを確定させる
  audience: 業務を知る人と、それを形にする人
  boundary: 実装手段は扱わない
questions:
  - id: q1
    question: 取消の締切は受注日基準か出荷日基準か
    recommendation: 出荷日基準
output_to: $TMP_ROOT/io/out.yml
YML
make_cfg() { yq -o=json -I=0 '{"input": .}' "$1" > "$2"; }
# ── 入口hook validate-input.sh：契約固有schemaは入口で止まる ──────────────
# **共通resolverは contract / version / 能力 / output_to しか見ない。** 未知キーや
# recommendation 欠落を入口で止めるのはこのhookだけなので、正負の両方を直に見る。
vinput="$PLAYBOOK/scripts/validate-input.sh"
[ -f "$vinput" ] && [ ! -L "$vinput" ] || note '入口hook validate-input.sh が通常ファイルとして無い'
bash "$vinput" "$TMP_ROOT/io/input.yml" > "$TMP_ROOT/io/hook.out" 2>"$TMP_ROOT/io/hook.err" \
  || note "契約どおりの入力を入口hookが拒否する: $(head -1 "$TMP_ROOT/io/hook.err")"
[ ! -s "$TMP_ROOT/io/hook.out" ] || note '入口hookがstdoutを使っている（解決済みYAMLのpathと混ざる）'
reject_hook() { # reject_hook <名前> <入力YAML>
  local name="$1" dir="$TMP_ROOT/hook-$1"
  mkdir -p "$dir"; printf '%s\n' "$2" > "$dir/input.yml"
  if bash "$vinput" "$dir/input.yml" >/dev/null 2> "$dir/err"; then
    note "契約違反の入力を入口hookが受け入れている: $name"
  elif ! rg -q '^\[error:input-schema\] ' "$dir/err"; then
    note "入口hookの診断が [error:input-schema] key=value でない: $name ($(head -1 "$dir/err"))"
  elif [ "$(wc -l < "$dir/err")" -ne 1 ]; then
    note "入口hookの診断が1行でない: $name"
  fi
  # 同じ入力は E1 経由でも exit 2 で止まる。
  if bash "$PLAYBOOK/scripts/prepare.sh" "$ROOT" --input="$dir/input.yml" >/dev/null 2> "$dir/e1.err"; then
    note "契約違反の入力をE1が受け入れている: $name"
  elif ! rg -q 'input-schema' "$dir/e1.err"; then
    note "E1が契約固有schema違反を期待した理由で拒否できない: $name ($(head -1 "$dir/e1.err"))"
  fi
}
reject_hook unknown-key "contract: grill/grill
version: 1
topic: t
context: {purpose: p, audience: a, boundary: b}
questions: []
aspects: business-rules
output_to: $TMP_ROOT/io/out.yml"
reject_hook no-recommendation "contract: grill/grill
version: 1
topic: t
context: {purpose: p, audience: a, boundary: b}
questions:
  - {id: q1, question: 締切は}
output_to: $TMP_ROOT/io/out.yml"
# **契約の状態名は出力にしか無い。** 入力へ持ち込もうとしたら未知キーとして止める。
reject_hook state-in-input "contract: grill/grill
version: 1
topic: t
context: {purpose: p, audience: a, boundary: b}
questions: []
open_questions:
  - {id: q1, question: q, state: parked, reason: r}
output_to: $TMP_ROOT/io/out.yml"
reject_hook missing-context "contract: grill/grill
version: 1
topic: t
questions: []
output_to: $TMP_ROOT/io/out.yml"
# **入力pathの祖先にsymlinkがあっても受ける。** macOS既定のTMPDIRはその形なので、
# ここを拒否すると素直に書いた入力が必ず落ちる。
symroot="$TMP_ROOT/symlinked"; mkdir -p "$TMP_ROOT/real"
ln -s "$TMP_ROOT/real" "$symroot"
sed "s|^output_to: .*|output_to: $symroot/out.yml|" "$TMP_ROOT/io/input.yml" > "$symroot/input.yml"
if sym_cfg=$(bash "$PLAYBOOK/scripts/prepare.sh" "$ROOT" --input="$symroot/input.yml" 2> "$TMP_ROOT/sym.err"); then
  yq -o=json -I=0 '.' "$sym_cfg" | jq -e --arg real "$TMP_ROOT/real" '.input.output_to == ($real + "/out.yml")' >/dev/null \
    || note '祖先がsymlinkのoutput_toが正規化されて載らない'
  python3 "$PLAYBOOK/scripts/run-config.py" cleanup --config "$sym_cfg" >/dev/null 2>&1
else
  note "祖先にsymlinkを含む入力pathをE1が拒否する: $(head -1 "$TMP_ROOT/sym.err")"
fi
# **E1 を実際に通す。** prepare.sh --input=<abs> が .input を載せた解決済みYAMLを返し、
# そこから契約入力を読めるところまでを、合成configではなく本番の経路で確かめる。
if ! entry_cfg=$(bash "$PLAYBOOK/scripts/prepare.sh" "$ROOT" --input="$TMP_ROOT/io/input.yml" 2> "$TMP_ROOT/io/entry.err"); then
  note "prepare.sh --input が通らない: $(head -3 "$TMP_ROOT/io/entry.err")"
else
  python3 "$cio" read --config "$entry_cfg" \
    | jq -e '.present==true and .topic=="コアドメインの取消ルール" and (.topic_slug|length>0) and (.output_to|startswith("/"))' >/dev/null \
    || note '解決済みYAMLの .input から契約入力を読めない'
  python3 "$PLAYBOOK/scripts/run-config.py" cleanup --config "$entry_cfg" >/dev/null 2>&1 \
    || note '実行設定の後始末が自分で行えない'
fi
# 契約IDが違う入力は入口で止まる（提供側の変換層へ届く前に落ちる）。
sed 's|^contract: grill/grill$|contract: write-doc/write-doc|' "$TMP_ROOT/io/input.yml" > "$TMP_ROOT/io/wrong-contract.yml"
if bash "$PLAYBOOK/scripts/prepare.sh" "$ROOT" --input="$TMP_ROOT/io/wrong-contract.yml" >/dev/null 2> "$TMP_ROOT/io/wrong.err"; then
  note '別契約の入力を入口が受け入れている'
elif ! rg -q 'input-contract-mismatch' "$TMP_ROOT/io/wrong.err"; then
  note "別契約の入力を期待した理由で拒否できない: $(head -1 "$TMP_ROOT/io/wrong.err")"
fi
make_cfg "$TMP_ROOT/io/input.yml" "$TMP_ROOT/io/cfg.json"
echo '{}' > "$TMP_ROOT/io/empty.json"
python3 "$cio" read --config "$TMP_ROOT/io/empty.json" | jq -e '.present==false' >/dev/null \
  || note '--input無しの直接起動を present:false として扱えない'
cat > "$TMP_ROOT/io/result.json" <<'JSON'
{"status":"completed",
 "decisions":[{"id":"q1","question":"締切の基準","answer":"出荷日基準","rationale":"在庫引当の解放時点と揃えるため"}],
 "open_questions":[{"id":"q3","question":"再申請の上限","state":"dropped","reason":"運用データが無い"}]}
JSON
python3 "$cio" write --config "$TMP_ROOT/io/cfg.json" --result "$TMP_ROOT/io/result.json" >/dev/null \
  && yq -o=json -I=0 '.' "$TMP_ROOT/io/out.yml" \
     | jq -e '.contract=="grill/grill" and .version==1 and .status=="completed" and .open_questions[0].state=="withdrawn"' >/dev/null \
  || note '出力YAMLがoutput_toへ契約の形で書かれない（状態名の正規化を含む）'

# ── 6. 負の試験 ────────────────────────────────────────────────
reject() { # reject <名前> <期待コード片> <入力YAML>
  local name="$1" expected="$2" body="$3" dir="$TMP_ROOT/neg-$1"
  mkdir -p "$dir"; printf '%s\n' "$body" > "$dir/input.yml"
  make_cfg "$dir/input.yml" "$dir/cfg.json"
  if python3 "$cio" read --config "$dir/cfg.json" >/dev/null 2> "$dir/err"; then
    note "負例を拒否できない: $name"
  elif ! rg -q "$expected" "$dir/err"; then
    note "負例を期待した理由で拒否できない: $name ($(head -1 "$dir/err"))"
  fi
}
reject unknown-key 'input-schema' "contract: grill/grill
version: 1
topic: t
context: {purpose: p, audience: a, boundary: b}
questions: []
aspects: business-rules
output_to: $TMP_ROOT/io/out.yml"
reject wrong-contract 'input-contract-mismatch' "contract: write-doc/write-doc
version: 1
topic: t
context: {purpose: p, audience: a, boundary: b}
questions: []
output_to: $TMP_ROOT/io/out.yml"
reject no-recommendation 'input-schema' "contract: grill/grill
version: 1
topic: t
context: {purpose: p, audience: a, boundary: b}
questions:
  - {id: q1, question: 締切は}
output_to: $TMP_ROOT/io/out.yml"
reject relative-output 'input-output-unwritable' 'contract: grill/grill
version: 1
topic: t
context: {purpose: p, audience: a, boundary: b}
questions: []
output_to: ./out.yml'
printf '%s\n' '{"status":"completed","decisions":[],"open_questions":[{"id":"q1","question":"q","state":"parked","reason":"r"}]}' > "$TMP_ROOT/io/bad-state.json"
if python3 "$cio" write --config "$TMP_ROOT/io/cfg.json" --result "$TMP_ROOT/io/bad-state.json" >/dev/null 2> "$TMP_ROOT/io/bad-state.err"; then
  note '契約に無い状態名を黙って受け入れている'
elif ! rg -q 'output-schema' "$TMP_ROOT/io/bad-state.err"; then
  note '契約に無い状態名を期待した理由で拒否できない'
fi

# playbook設定：契約の固定値は利用者が変えられない。
mkdir -p "$TMP_ROOT/cfgrepo/.harness-plugins"
git -C "$TMP_ROOT/cfgrepo" init -q
yq -P '.contract.states = ["open","parked"]' "$PLAYBOOK/playbook.yml" > "$TMP_ROOT/cfgrepo/.harness-plugins/grill.config.yml"
if bash "$PLAYBOOK/scripts/resolve.sh" "$TMP_ROOT/cfgrepo" >/dev/null 2> "$TMP_ROOT/states.err"; then
  note '契約の状態名を差し替えた設定を受け入れている'
elif ! rg -q 'open / withdrawn' "$TMP_ROOT/states.err"; then
  note '契約の状態名の差し替えを期待した理由で拒否できない'
fi

# 内部skillの廃止設定を黙って受け入れない。
mkdir -p "$TMP_ROOT/repo/.harness-plugins"
git -C "$TMP_ROOT/repo" init -q
cfg=$(bash "$INTERNAL/scripts/prepare.sh" "$TMP_ROOT/repo") || note '内部skillのprepare.shが通らない'
if [ -n "${cfg:-}" ]; then
  yq -o=json -I=0 '.' "$cfg" | jq -e '((has("aspects")|not) and (.questioning|type=="string"))' >/dev/null \
    || note '内部skillの解決結果が期待した形でない'
  rm -f "$cfg"
fi
[ ! -d "$INTERNAL/references/aspects" ] || note '題材固有の観点を同梱している'
yq -o=json -I=0 '.' "$INTERNAL/config/defaults.yml" \
  | jq -e '((has("aspects")|not) and (has("prompt_parameters")|not) and (has("instructions")|not))' >/dev/null \
  || note '内部skillの同梱既定に廃止したキーが残っている'
for legacy in 'aspects: business-rules' 'instructions:'; do
  if [ "$legacy" = 'instructions:' ]; then
    printf '%s\n' 'version: 1' 'log_dir: decisions' 'instructions:' '  questioning:' '    directive: legacy' \
      > "$TMP_ROOT/repo/.harness-plugins/grill-dialogue.config.yml"
    want='同梱既定に無い設定: instructions'
  else
    printf '%s\n' 'version: 1' "$legacy" 'log_dir: decisions' \
      > "$TMP_ROOT/repo/.harness-plugins/grill-dialogue.config.yml"
    want='同梱既定に無い設定: aspects'
  fi
  if bash "$INTERNAL/scripts/prepare.sh" "$TMP_ROOT/repo" >/dev/null 2> "$TMP_ROOT/legacy.err"; then
    note "廃止設定を受け入れている: $legacy"
  elif ! rg -q "$want" "$TMP_ROOT/legacy.err"; then
    note "廃止設定を期待した理由で拒否できない: $legacy"
  fi
done
rm -f "$TMP_ROOT/repo/.harness-plugins/grill-dialogue.config.yml"

# ── 7. 消費側から見た公開面 — 実際の配布物に対して解決する ──────────────
# fixtureは「grillを外部依存として要求する別marketplaceのplaybook」。
# 配布物 plugins/ をそのままinstalled-cacheへ写すので、fixtureが実体から乖離しない。
consumer="$TMP_ROOT/consumer"
cpb="$consumer/plugins/playbooks/probe/probe"
mkdir -p "$cpb/scripts" "$cpb/.claude-plugin" "$cpb/.codex-plugin" "$consumer/plugins/.claude-plugin" "$consumer/plugins/.codex-plugin"
git -C "$consumer" init -q 2>/dev/null || { mkdir -p "$consumer"; git -C "$consumer" init -q; }
cache="$cpb/.harness-plugin-test-cache/grill/grill/2.0.0"
mkdir -p "$(dirname "$cache")"
cp -R "$PACKAGE" "$cache"
for runtime in claude codex; do
  cat > "$cpb/.${runtime}-plugin/plugin.json" <<'JSON'
{"name":"probe","version":"1.0.0","description":"fixture","skills":"./","metadata":{"harness":{"contractVersion":1}}}
JSON
  cat > "$consumer/plugins/.${runtime}-plugin/plugin.json" <<'JSON'
{"name":"probe","version":"1.0.0","description":"fixture","skills":["./playbooks/probe/probe"],
 "metadata":{"harness":{"installationSurface":"playbook-package","marketplace":"probe",
 "entryRoot":"./playbooks/probe/probe","playbooks":{"probe":"./playbooks/probe/probe"},
 "internalPlugins":{},"contractVersion":1,
 "implements":[{"id":"probe/probe","version":1,"kind":"playbook","playbook":"probe"}]}}}
JSON
done
printf -- '---\nname: probe\ndescription: fixture\n---\nfixture\n' > "$cpb/SKILL.md"
cp "$ROOT/shared/prepare.sh" "$cpb/scripts/prepare.sh"
cp "$ROOT/shared/run-config.py" "$cpb/scripts/run-config.py"
cp "$ROOT/shared/playbook/resolve.sh" "$cpb/scripts/resolve.sh"
cp "$ROOT/shared/playbook/resolve-dependency.py" "$cpb/scripts/resolve-dependency.py"
printf '#!/usr/bin/env bash\nexit 0\n' > "$cpb/scripts/validate-config.sh"
chmod 755 "$cpb/scripts"/*
probe_playbook() { # probe_playbook <requires plugin> <step種別>
  cat > "$cpb/playbook.yml" <<YML
version: 2
name: probe
description: fixture
instructions:
  execution:
    directive: fixture
requires:
  - {plugin: $1, marketplace: grill}
steps:
  - id: settle
    $2: $1
    purpose: fixture
    provides: [decisions]
YML
}
probe_run() { HARNESS_PLUGIN_CACHE_ROOT="$cpb/.harness-plugin-test-cache" \
  bash "$cpb/scripts/resolve.sh" "$consumer" 2> "$TMP_ROOT/probe.err"; }

# (a) 公開playbookは外部から解決でき、入口4点が揃う。
probe_playbook grill playbook
if ! probe_run > "$TMP_ROOT/probe.yml"; then
  note "配布物のgrillを外部依存として解決できない: $(head -3 "$TMP_ROOT/probe.err")"
else
  # **契約面は entry と entry_skill である。** entry は入口SKILL.mdの実path、
  # entry_skill はその frontmatter name（表示用。名前で分岐しない）。
  entry_skill_name=$(rg -N -m1 '^name: (.+)$' -r '$1' "$PLAYBOOK/SKILL.md")
  yq -o=json -I=0 '.' "$TMP_ROOT/probe.yml" | jq -e --arg skill "$entry_skill_name" '
    .deps.grill.dependency_scope=="external" and .deps.grill.contract=="grill/grill" and
    (.deps.grill.implements|map(select(.id=="grill/grill" and .version==1 and .kind=="playbook"))|length==1) and
    (.deps.grill.root|test("/playbooks/dialogue/grill$")) and
    (.deps.grill.entry|test("/playbooks/dialogue/grill/SKILL.md$")) and
    .deps.grill.entry_skill==$skill' >/dev/null \
    || note '外部から見えるgrillの公開面（entry / entry_skill）が契約どおりでない'
  for entry in playbook.yml SKILL.md scripts/resolve.sh scripts/prepare.sh; do
    root=$(yq -er '.deps.grill.root' "$TMP_ROOT/probe.yml")
    [ -f "$root/$entry" ] || note "公開面の入口が無い: $entry"
  done
fi

# (b) 内部pluginを外部から指定しても解決しない。
probe_playbook grill-dialogue playbook
if probe_run >/dev/null; then
  note '外部repositoryから内部plugin（grill-dialogue）が解決できてしまう'
elif ! rg -q 'dependency-missing' "$TMP_ROOT/probe.err"; then
  note "内部pluginの外部指定を期待した理由で拒否できない: $(head -1 "$TMP_ROOT/probe.err")"
fi

# (c) 外部依存を skill: で掴めない（最上位規則の機械的強制）。
probe_playbook grill skill
if probe_run >/dev/null; then
  note '外部依存のgrillを skill: step で呼べてしまう'
elif ! rg -q 'external-dependency-skill' "$TMP_ROOT/probe.err"; then
  note "外部skill参照を期待した理由で拒否できない: $(head -1 "$TMP_ROOT/probe.err")"
fi

if [ "$failed" -eq 0 ]; then
  echo 'Validation: passed'
else
  echo 'Validation: failed'
fi
[ "$failed" -eq 0 ]
