#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# 保守toolの正本は兄弟checkoutの harness-tools。無ければ止まる（fixtureで代用しない）。
TOOLS="$ROOT/../harness-tools/tools"
[ -d "$TOOLS" ] || { echo "[error] 兄弟 checkout harness-tools が無い: $TOOLS" >&2; exit 2; }
python3 "$ROOT/scripts/validate-package.py" "$ROOT"
python3 "$ROOT/scripts/test-package.py"
# repositoryの回帰検査（harness-tools）: CI workflowのSHA固定、公開入口の一意性、doctorの読み取り専用性
python3 "$TOOLS/test-hardening.py" --repository "$ROOT"
