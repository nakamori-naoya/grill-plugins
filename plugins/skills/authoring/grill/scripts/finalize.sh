#!/usr/bin/env bash
# grill 固有の検査と、出す形の組み立て。
#
# **resolve.sh から source される。** 設定の解決手順は共通なのでここには無い。
# 使えるもの: merged / required / root / PLUGIN_ROOT / name / selected / source / explain / resolve_path
# やること: 固有schemaの検査と、out への最終JSONの代入。
jq -e '.version==1 and (.log_dir|type=="string" and length>0) and
  (.instructions.questioning.directive|type=="string" and length>0)' >/dev/null <<<"$merged" \
  || { echo "[error] version、log_dir、questioning directiveのいずれかが不正" >&2; exit 2; }

log_dir=$(resolve_path "$(jq -r '.log_dir // "decisions"' <<<"$merged")")

out=$(jq -cn --arg q "$PLUGIN_ROOT/references/questioning.md" \
  --arg l "$log_dir" --arg root "$root" --arg pr "$PLUGIN_ROOT" --argjson instructions "$(jq -c '.instructions' <<<"$merged")" \
  '{contract:1, questioning:$q, log_dir:$l,
    instructions:$instructions,
    repo_root:$root, plugin_root:$pr}')

if [ "$explain" = "1" ]; then
  echo "# 決定ログ: ${log_dir}" >&2
fi
