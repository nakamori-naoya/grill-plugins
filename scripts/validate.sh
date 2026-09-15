#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
python3 "$ROOT/scripts/validate-package.py" "$ROOT"
python3 "$ROOT/scripts/test-package.py"
