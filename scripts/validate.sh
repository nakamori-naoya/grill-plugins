#!/usr/bin/env bash
# Scenario: grill marketplaceが単一pluginとして両runtimeへ配布できる
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
plugin="$ROOT/plugins/skills/authoring/grill"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/grill-validation.XXXXXX") || exit 2
trap 'rm -rf "$TMP_ROOT"' EXIT
failed=0
python3 "$ROOT/scripts/validate-distribution.py" "$ROOT" || failed=1
python3 "$ROOT/scripts/validate-distribution.py" --self-test "$ROOT" || failed=1
for manifest in "$plugin/.codex-plugin/plugin.json" "$plugin/.claude-plugin/plugin.json"; do
  jq -e '.name=="grill" and .version=="0.3.1"' "$manifest" >/dev/null || failed=1
done
jq -e '.name=="grill" and (.plugins|length==1) and .plugins[0].name=="grill" and .plugins[0].version=="0.3.1"' "$ROOT/.agents/plugins/marketplace.json" "$ROOT/.claude-plugin/marketplace.json" >/dev/null || failed=1
cmp -s "$ROOT/shared/prepare.sh" "$plugin/scripts/prepare.sh" || failed=1
bash -n "$plugin/scripts/prepare.sh" || failed=1

# grillは題材固有の観点を同梱せず、aspect入力がなくても依頼文脈で実行できる。
[ ! -d "$plugin/references/aspects" ] || failed=1
yq -o=json -I=0 '.' "$plugin/config/defaults.yml" \
  | jq -e '((has("aspects")|not) and (has("prompt_parameters")|not) and (has("instructions")|not))' >/dev/null || failed=1
mkdir -p "$TMP_ROOT/repo"
git -C "$TMP_ROOT/repo" init -q
cfg=$(bash "$plugin/scripts/prepare.sh" "$TMP_ROOT/repo") || failed=1
if [ -n "${cfg:-}" ]; then
  yq -o=json -I=0 '.' "$cfg" | jq -e '((has("aspects")|not) and (.questioning|type=="string"))' >/dev/null || failed=1
  rm -f "$cfg"
fi

# 廃止した設定を黙って受け入れない負の試験。aspectsもinstructionsも、
# 残っていれば黙って無視せず停止する。
mkdir -p "$TMP_ROOT/repo/.harness-plugins"
printf '%s\n' 'version: 1' 'aspects: business-rules' 'log_dir: decisions' \
  > "$TMP_ROOT/repo/.harness-plugins/grill.config.yml"
if bash "$plugin/scripts/prepare.sh" "$TMP_ROOT/repo" >/dev/null 2> "$TMP_ROOT/legacy.err"; then
  failed=1
elif ! rg -n '同梱既定に無い設定: aspects' "$TMP_ROOT/legacy.err" >/dev/null; then
  failed=1
fi
printf '%s\n' 'version: 1' 'log_dir: decisions' \
  'instructions:' '  questioning:' '    directive: legacy' \
  > "$TMP_ROOT/repo/.harness-plugins/grill.config.yml"
if bash "$plugin/scripts/prepare.sh" "$TMP_ROOT/repo" >/dev/null 2> "$TMP_ROOT/legacy.err"; then
  failed=1
elif ! rg -n '同梱既定に無い設定: instructions' "$TMP_ROOT/legacy.err" >/dev/null; then
  failed=1
fi
rm -f "$TMP_ROOT/repo/.harness-plugins/grill.config.yml"
if [ "$failed" -eq 0 ]; then
  echo 'Validation: passed'
else
  echo 'Validation: failed'
fi
[ "$failed" -eq 0 ]
