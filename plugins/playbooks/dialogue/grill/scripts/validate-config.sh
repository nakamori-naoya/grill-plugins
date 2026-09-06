#!/usr/bin/env bash
# grill playbook 固有の設定検査。共通 resolver から呼ばれる。
# 引数は解決済み playbook 設定（JSON）の一時ファイル。
#
# **公開契約（CONTRACT.md）が固定している値だけを見る。** 工程 id や内部 skill 名は
# 利用者が差し替えてよいので、ここでは固定しない。
set -euo pipefail
file="$1"

jq -e '.contract.id == "grill/grill" and .contract.version == 1' "$file" >/dev/null \
  || { echo "[error] grillの契約IDと版は grill/grill / 1 に固定する" >&2; exit 2; }
jq -e '.contract.states == ["open","withdrawn"]' "$file" >/dev/null \
  || { echo "[error] 未決の状態名は open / withdrawn に固定する（内部の記録形式を公開しない）" >&2; exit 2; }
jq -e '[.steps[] | .provides[]?] | (index("decisions") != null) and (index("open_questions") != null)' "$file" >/dev/null \
  || { echo "[error] decisions と open_questions を provides する工程が無い（出力契約を満たせない）" >&2; exit 2; }
jq -e 'all(.steps[]; has("playbook") | not)' "$file" >/dev/null \
  || { echo "[error] grillは他のplaybookを呼ばない" >&2; exit 2; }
