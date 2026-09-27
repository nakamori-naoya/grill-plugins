#!/usr/bin/env python3
"""grill の入口に固有の構造を検査する。配置と manifest は harness-tools の validate-plugin-repository.py が判定するので、ここでは見ない。

基準資料: 入口の playbook.yml、SKILL.md、package の中の Markdown
入力: 絶対パスで渡された repository。YAML は mikefarah/yq v4 で読む
合格述語:
  1. playbook.yml は version 2、name grill、requires が空で、steps が investigate、ask、agree、return の順に並び、
     各 step は呼び出した agent が行う工程（agent_work: invoking_agent）で purpose を持ち、最後の step が結果の四つを provides する
  2. SKILL.md の frontmatter が閉じていて、description が空でない。SKILL.md に shell のコードブロックが無い
  3. package の Markdown に Gherkin（Feature:、Scenario:、```gherkin）が無い
  4. package の Markdown の相対リンクは、package の中の実在するファイルを指す
失敗時の診断: 違反したファイルと理由
正例: この repository の配布物そのもの
反例: test-package.py の負例（step の並びや種類の変更、shell のコードブロック、Gherkin、切れたリンク）
意味評価として残す範囲: 問いの選び方、推奨と理由の質、合意の取り方
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

PACKAGE = 'plugins/grill'
ENTRY = 'skills/grill'
STEP_IDS = ['investigate', 'ask', 'agree', 'return']


def require(condition, path, message):
    if not condition:
        raise ValueError(f'{path}: {message}')


def yaml_value(text, path):
    result = subprocess.run(['yq', '-o=json', '.', '-'], input=text,
                            text=True, capture_output=True, check=False)
    require(result.returncode == 0, path, 'invalid YAML: ' + result.stderr.strip())
    return json.loads(result.stdout)


def validate(root):
    package = root / PACKAGE
    path = package / ENTRY / 'playbook.yml'
    config = yaml_value(path.read_text(), path)
    require(isinstance(config, dict) and type(config.get('version')) is int and config['version'] == 2 and config.get('name') == 'grill', path, 'composition identity mismatch')
    require(config.get('requires') == [], path, 'requires mismatch')
    steps = config.get('steps')
    require(isinstance(steps, list) and [step.get('id') if isinstance(step, dict) else None for step in steps] == STEP_IDS, path, 'steps mismatch')
    for step in steps:
        require(set(step) - {'id', 'agent_work', 'purpose', 'needs', 'provides'} == set() and step.get('agent_work') == 'invoking_agent'
                and isinstance(step.get('purpose'), str) and bool(step['purpose']), path, 'steps mismatch')
    require(steps[-1].get('provides') == ['status', 'decisions', 'open_questions', 'reason'], path, 'steps mismatch')
    path = package / ENTRY / 'SKILL.md'
    text = path.read_text()
    match = re.match(r'\A---\n(.*?)\n---(?:\n|$)', text, re.S)
    require(match is not None, path, 'frontmatter missing')
    metadata = yaml_value(match.group(1), path)
    require(isinstance(metadata, dict) and isinstance(metadata.get('description'), str) and bool(metadata['description']), path, 'description missing')
    require(not re.search(r'^```(?:bash|sh|shell)\b', text, re.M), path, 'shell block forbidden')
    for path in package.rglob('*.md'):
        text = path.read_text()
        require(not re.search(r'^\s*(?:Feature:|Scenario:|```gherkin)', text, re.M), path, 'Gherkin は配布物に置かない')
        for link in re.findall(r'\[[^\]]*\]\(([^)]+)\)', text):
            if '://' in link or link.startswith('#'):
                continue
            target = (path.parent / link.split('#', 1)[0]).resolve()
            require(target.is_relative_to(package.resolve()) and target.is_file(), path, f'link missing or outside package: {link}')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('repository', type=Path)
    args = parser.parse_args()
    try:
        require(args.repository.is_absolute(), args.repository, 'absolute repository required')
        validate(args.repository)
    except (ValueError, OSError, KeyError, TypeError, AttributeError) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        return 1
    print(f'Package structure: passed ({args.repository})')
    return 0


if __name__ == '__main__':
    sys.exit(main())
