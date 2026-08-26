---
name: grill
description: 合意に達するまで1問ずつ問い詰めて、曖昧さを潰す。推奨回答を必ず添え、調べれば分かることは聞かない。決めたことと未決を決定ログへ残す。「詰めて」「問い詰めて」「設計を固めて」と言われたとき、実装や資料作成に入る前に使う。
---

# grill

このentryは配布形式を中立化する薄い入口である。次を実行してplugin rootを検証し、root直下の正本`SKILL.md`を全文読んで、その手順に従う。

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
cat "${PLUGIN_ROOT}/SKILL.md"
```
