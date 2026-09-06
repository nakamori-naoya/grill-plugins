#!/usr/bin/env bash
# grill/grill 契約 v1 の入力 schema を入口で検査する（共通resolverの任意hook）。
#
#   validate-input.sh <正規化済みの入力YAMLの絶対path>
#
# **共通resolverが見るのは contract / version / 能力 / output_to だけである。**
# 契約固有の schema（必須キー、未知キーの拒否、値の形）はここでしか見られない。
# 提供側の変換層 contract-io.py が持つ検査を正本として呼び、二重定義を作らない。
#
# exit 0 で受理、非0で拒否。診断は stderr へ [error:input-schema] key=value の1行。
# **stdoutは使わない。** 呼び出し元は stdout を解決済みYAMLのpathに使う。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

reject() { echo "[error:input-schema] $*" >&2; exit 2; }

[ "$#" -eq 1 ] || reject 'reason=usage detail=validate-input.sh <input>'
input="$1"
[ -f "$input" ] || reject "path=${input} reason=not-file"

work=$(mktemp -d "${TMPDIR:-/tmp}/grill-input.XXXXXX") || reject 'reason=tmpdir-unavailable'
trap 'rm -rf "$work"' EXIT
config="$work/config.json"

# contract-io.py は解決済みYAMLの .input を読む。入口ではまだ解決前なので、
# 同じ形（{"input": <入力>}）へ包んでから同じ検査へ通す。
yq -o=json -I=0 '{"input": .}' "$input" > "$config" 2>"$work/yq.err" \
  || reject "path=${input} reason=yaml-parse"
jq -e '.input | type=="object"' "$config" >/dev/null 2>&1 \
  || reject "path=${input} reason=not-mapping"

python3 "$SCRIPT_DIR/contract-io.py" read --config "$config" >/dev/null
