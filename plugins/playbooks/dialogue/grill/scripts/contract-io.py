#!/usr/bin/env python3
"""grill/grill 契約 v1 の入力を読み、出力を書く。**提供側だけが持つ変換層である。**

呼び出し元は CONTRACT.md の語（topic / context / questions / grounding /
decisions / open_questions）しか知らない。内部 skill は別の語（題材のslug、
decided / open / dropped）で動く。**その差をここで吸収する。**
外へ出すのは契約の語だけ、内へ渡すのは内部の語だけにする。

  contract-io.py read  --config <解決済みYAML>
      -> .input を契約 schema で検査し、内部へ渡す形（topic_slug を含む）をJSONで出す。
         --input が渡されていない実行では {"present": false} を出して exit 0。

  contract-io.py slug  --topic <題材>
      -> 決定ログ用の内部idだけを出す。日本語 topic をそのまま受ける。

  contract-io.py write --config <解決済みYAML> --result <JSONファイル>
      -> 結果を契約 schema へ正規化し、.input.output_to の絶対pathへYAMLで書く。

失敗は [error:<code>] key=value を stderr へ出して exit 2。
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

CONTRACT = "grill/grill"
VERSION = 1
IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
ASCII_SAFE = re.compile(r"[^A-Za-z0-9._-]+")
CONTEXT_KEYS = {"purpose", "audience", "boundary"}
INPUT_KEYS = {"contract", "version", "topic", "context", "questions", "grounding", "output_to"}
QUESTION_KEYS = {"id", "question", "recommendation"}
DECISION_KEYS = {"id", "question", "answer", "rationale"}
OPEN_KEYS = {"id", "question", "state", "reason"}
# 内部 skill の状態名 -> 契約の状態名。**内部名は契約に出さない。**
STATE_MAP = {"open": "open", "dropped": "withdrawn", "withdrawn": "withdrawn"}


def fail(code, **fields):
    detail = " ".join("{}={}".format(key, value) for key, value in sorted(fields.items()))
    print("[error:{}] {}".format(code, detail).rstrip(), file=sys.stderr)
    raise SystemExit(2)


def yq(args, stdin=None):
    try:
        result = subprocess.run(["yq", *args], input=stdin, text=True, capture_output=True, timeout=30)
    except OSError as exc:
        fail("input-invalid", reason="yq-unavailable", detail=str(exc))
    if result.returncode != 0:
        fail("input-invalid", reason="yq-failed", detail=result.stderr.strip()[:200])
    return result.stdout


def load_config(path):
    resolved = Path(path)
    if not resolved.is_absolute() or resolved.is_symlink() or not resolved.is_file():
        fail("input-file-unsafe", reason="config-path", path=str(path))
    return json.loads(yq(["-o=json", "-I=0", ".", str(resolved)]))


def text(value, code, **fields):
    if not isinstance(value, str) or not value.strip() or any(ord(ch) < 32 for ch in value):
        fail(code, **fields)
    return value


def absolute_file(value, code, **fields):
    if not isinstance(value, str) or not value:
        fail(code, **fields)
    path = Path(value)
    if not path.is_absolute() or path != Path(os.path.normpath(value)) or path.is_symlink() or not path.is_file():
        fail(code, **fields)
    return str(path)


def topic_slug(topic):
    """日本語 topic を、決定ログが受け取れる内部idへ写す。

    **契約は topic の文字種を制限しない（GG8）。** 内部の記録が英数しか受けない
    のは内部の事情なので、ここで決定的に変換する。同じ topic は同じidになる。
    """
    text(topic, "input-schema", field="topic")
    digest = hashlib.sha256(topic.encode("utf-8")).hexdigest()[:16]
    head = ASCII_SAFE.sub("-", topic).strip("-._")
    head = re.sub(r"^[^A-Za-z0-9]+", "", head)[:48].rstrip("-._")
    return "{}-{}".format(head, digest) if head else "topic-{}".format(digest)


def read_input(config):
    block = config.get("input")
    if block is None:
        return {"present": False}
    if not isinstance(block, dict):
        fail("input-invalid", reason="not-mapping")
    unknown = sorted(set(block) - INPUT_KEYS)
    if unknown:
        fail("input-schema", reason="unknown-keys", keys=",".join(unknown))
    if block.get("contract") != CONTRACT or block.get("version") != VERSION:
        fail("input-contract-mismatch", contract=str(block.get("contract")), version=str(block.get("version")))

    topic = text(block.get("topic"), "input-schema", field="topic")

    context = block.get("context")
    if not isinstance(context, dict) or set(context) != CONTEXT_KEYS:
        fail("input-schema", field="context", reason="purpose/audience/boundaryのちょうど3つ")
    for key in sorted(CONTEXT_KEYS):
        text(context[key], "input-schema", field="context." + key)

    questions = block.get("questions")
    if not isinstance(questions, list):
        fail("input-schema", field="questions", reason="配列（空配列は問いをこちらで立てる指示）")
    seen = set()
    for index, item in enumerate(questions):
        if not isinstance(item, dict) or set(item) != QUESTION_KEYS:
            fail("input-schema", field="questions[{}]".format(index), reason="id/question/recommendationのちょうど3つ")
        if not IDENTIFIER.fullmatch(str(item["id"])) or item["id"] in seen:
            fail("input-schema", field="questions[{}].id".format(index))
        seen.add(item["id"])
        text(item["question"], "input-schema", field="questions[{}].question".format(index))
        text(item["recommendation"], "input-schema", field="questions[{}].recommendation".format(index))

    grounding = block.get("grounding", [])
    if not isinstance(grounding, list):
        fail("input-schema", field="grounding", reason="絶対pathの配列")
    grounding = [absolute_file(item, "input-schema", field="grounding[{}]".format(i)) for i, item in enumerate(grounding)]

    output_to = block.get("output_to")
    if not isinstance(output_to, str) or not Path(output_to).is_absolute() or output_to != os.path.normpath(output_to):
        fail("input-output-unwritable", reason="not-absolute", path=str(output_to))
    parent = Path(output_to).parent
    if not parent.is_dir() or not os.access(parent, os.W_OK):
        fail("input-output-unwritable", reason="parent-unwritable", path=str(output_to))

    return {
        "present": True,
        "topic": topic,
        "topic_slug": topic_slug(topic),
        "context": {key: context[key] for key in sorted(CONTEXT_KEYS)},
        "questions": questions,
        "grounding": grounding,
        "output_to": output_to,
    }


def normalize_result(raw):
    if not isinstance(raw, dict):
        fail("output-schema", reason="not-mapping")
    status = raw.get("status")
    if status not in {"completed", "failed"}:
        fail("output-schema", field="status", reason="completed / failed")
    if status == "failed":
        return {"contract": CONTRACT, "version": VERSION, "status": "failed",
                "reason": text(raw.get("reason"), "output-schema", field="reason")}

    decisions = raw.get("decisions")
    if not isinstance(decisions, list):
        fail("output-schema", field="decisions", reason="配列")
    normalized_decisions = []
    for index, item in enumerate(decisions):
        if not isinstance(item, dict) or not DECISION_KEYS <= set(item) or not set(item) <= DECISION_KEYS | {"state", "status"}:
            fail("output-schema", field="decisions[{}]".format(index), reason="id/question/answer/rationale")
        if not IDENTIFIER.fullmatch(str(item["id"])):
            fail("output-schema", field="decisions[{}].id".format(index))
        normalized_decisions.append({key: text(item[key], "output-schema", field="decisions[{}].{}".format(index, key))
                                     if key != "id" else item["id"] for key in ("id", "question", "answer", "rationale")})

    open_questions = raw.get("open_questions")
    if not isinstance(open_questions, list):
        fail("output-schema", field="open_questions", reason="配列")
    normalized_open = []
    for index, item in enumerate(open_questions):
        if not isinstance(item, dict) or not OPEN_KEYS <= set(item) or not set(item) <= OPEN_KEYS | {"status"}:
            fail("output-schema", field="open_questions[{}]".format(index), reason="id/question/state/reason")
        if not IDENTIFIER.fullmatch(str(item["id"])):
            fail("output-schema", field="open_questions[{}].id".format(index))
        state = STATE_MAP.get(str(item["state"]))
        if state is None:
            fail("output-schema", field="open_questions[{}].state".format(index), reason="open / withdrawn")
        normalized_open.append({
            "id": item["id"],
            "question": text(item["question"], "output-schema", field="open_questions[{}].question".format(index)),
            "state": state,
            "reason": text(item["reason"], "output-schema", field="open_questions[{}].reason".format(index)),
        })

    return {"contract": CONTRACT, "version": VERSION, "status": "completed",
            "decisions": normalized_decisions, "open_questions": normalized_open}


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    reader = sub.add_parser("read")
    reader.add_argument("--config", required=True)
    slug = sub.add_parser("slug")
    slug.add_argument("--topic", required=True)
    writer = sub.add_parser("write")
    writer.add_argument("--config", required=True)
    writer.add_argument("--result", required=True)
    args = parser.parse_args()

    if args.command == "slug":
        print(topic_slug(args.topic))
        return 0
    if args.command == "read":
        print(json.dumps(read_input(load_config(args.config)), ensure_ascii=False))
        return 0

    config = load_config(args.config)
    resolved = read_input(config)
    if not resolved["present"]:
        fail("input-invalid", reason="output_to-unknown")
    result_path = Path(args.result)
    if not result_path.is_absolute() or result_path.is_symlink() or not result_path.is_file():
        fail("input-file-unsafe", reason="result-path", path=args.result)
    payload = normalize_result(json.loads(result_path.read_text(encoding="utf-8")))
    target = Path(resolved["output_to"])
    document = yq(["-P"], stdin=json.dumps(payload, ensure_ascii=False))
    handle = os.open(str(target), os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(handle, "w", encoding="utf-8") as stream:
        stream.write(document)
    print(str(target))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print("[error:output-schema] detail={}".format(exc), file=sys.stderr)
        raise SystemExit(2)
