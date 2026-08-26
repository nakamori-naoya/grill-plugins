#!/usr/bin/env bash
# Scenario: grill marketplaceが単一pluginとして両runtimeへ配布できる
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
plugin="$ROOT/plugins/skills/authoring/grill"
failed=0
for manifest in "$plugin/.codex-plugin/plugin.json" "$plugin/.claude-plugin/plugin.json"; do
  jq -e '.name=="grill" and .version=="0.2.12"' "$manifest" >/dev/null || failed=1
done
jq -e '.name=="grill" and (.plugins|length==1) and .plugins[0].name=="grill" and .plugins[0].version=="0.2.12"' "$ROOT/.agents/plugins/marketplace.json" "$ROOT/.claude-plugin/marketplace.json" >/dev/null || failed=1
cmp -s "$ROOT/shared/prepare.sh" "$plugin/scripts/prepare.sh" || failed=1
bash -n "$plugin/scripts/prepare.sh" || failed=1
if [ "$failed" -eq 0 ]; then
  echo 'Validation: passed'
else
  echo 'Validation: failed'
fi
[ "$failed" -eq 0 ]
