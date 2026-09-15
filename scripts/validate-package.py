#!/usr/bin/env python3
"""Closed structural predicates declared in evals/validation-contract.md; no semantic grading."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

PUBLIC = 'playbooks/dialogue/grill'
INTERNAL = 'skills/dialogue/ask-until-agreed'
FILES = {
    'LICENSE', '.claude-plugin/plugin.json', '.codex-plugin/plugin.json',
    f'{PUBLIC}/CONTRACT.md', f'{PUBLIC}/playbook.yml', f'{PUBLIC}/SKILL.md',
    f'{INTERNAL}/SKILL.md', f'{INTERNAL}/references/dialogue-principles.md',
}
LEGACY = ('decision.py', 'finalize.sh', 'contract-io.py', 'prepare.sh',
          'run-config.py', 'resolve.sh', 'resolve-dependency.py')


def equal(left, right):
    return json.dumps(left, sort_keys=True) == json.dumps(right, sort_keys=True)


def require(condition, path, message):
    if not condition:
        raise ValueError(f'{path}: {message}')


def yaml_value(text, path):
    result = subprocess.run(['yq', '-o=json', '.', '-'], input=text,
                            text=True, capture_output=True, check=False)
    require(result.returncode == 0, path, 'invalid YAML: ' + result.stderr.strip())
    return json.loads(result.stdout)


def validate(root):
    package = root / 'plugins'
    require(package.is_dir() and not package.is_symlink(), package, 'package directory missing or symlink')
    found = set()
    directories = {str(parent) for name in FILES for parent in Path(name).parents if str(parent) != '.'}
    for path in package.rglob('*'):
        require(not path.is_symlink(), path, 'symlink forbidden')
        relative = path.relative_to(package).as_posix()
        if path.is_dir():
            require(relative in directories, path, 'unexpected directory')
        else:
            require(path.is_file(), path, 'not a regular file')
            found.add(relative)
    require(found == FILES, package, f'inventory mismatch: missing={sorted(FILES-found)}, extra={sorted(found-FILES)}')
    manifests = [json.loads((package / f'.{rt}-plugin/plugin.json').read_text()) for rt in ('claude', 'codex')]
    identity = lambda m: {key: m.get(key) for key in ('name', 'version', 'skills')} | {'harness': m.get('metadata', {}).get('harness')}
    require(equal(identity(manifests[0]), identity(manifests[1])), package, 'runtime identity mismatch')
    manifest = manifests[0]
    require(manifest.get('name') == 'grill' and isinstance(manifest.get('version'), str) and bool(manifest['version']), package, 'package identity invalid')
    require(manifest.get('skills') == [f'./{PUBLIC}'], package, 'public skills mismatch')
    harness = manifest.get('metadata', {}).get('harness', {})
    expected = {
        'installationSurface': 'playbook-package', 'marketplace': 'grill',
        'entryRoot': f'./{PUBLIC}', 'playbooks': {'grill': f'./{PUBLIC}'},
        'internalPlugins': {'ask-until-agreed': f'./{INTERNAL}'},
        'contractVersion': 1,
        'implements': [{'id': 'grill/grill', 'version': 1, 'kind': 'playbook', 'playbook': 'grill'}],
    }
    require(equal(harness, expected), package, 'harness declaration mismatch')
    for rt, relative in [('claude', '.claude-plugin/marketplace.json'), ('codex', '.agents/plugins/marketplace.json')]:
        path = root / relative
        require(path.is_file() and not path.is_symlink(), path, 'catalog missing or symlink')
        catalog = json.loads(path.read_text())
        entries = catalog.get('plugins')
        require(catalog.get('name') == 'grill' and isinstance(entries, list) and len(entries) == 1, path, 'catalog entry count/name mismatch')
        entry = entries[0]
        source = './plugins' if rt == 'claude' else {'source': 'local', 'path': './plugins'}
        require(entry.get('name') == 'grill' and entry.get('version') == manifest['version'] and entry.get('source') == source, path, 'catalog identity mismatch')
    path = package / PUBLIC / 'playbook.yml'
    config = yaml_value(path.read_text(), path)
    require(isinstance(config, dict) and type(config.get('version')) is int and config['version'] == 2 and config.get('name') == 'grill', path, 'composition identity mismatch')
    require(config.get('requires') == [{'plugin': 'ask-until-agreed', 'marketplace': 'grill'}], path, 'requires mismatch')
    require(equal(config.get('contract'), {
        'id': 'grill/grill', 'version': 1, 'states': ['open', 'withdrawn'],
        'invocation': {'input': 'object', 'output': 'object'},
    }), path, 'contract declaration mismatch')
    steps = config.get('steps')
    require(isinstance(steps, list) and len(steps) == 1 and isinstance(steps[0], dict), path, 'steps must contain one mapping')
    step = steps[0]
    require(set(step) == {'id', 'skill', 'purpose', 'provides'} and step.get('skill') == 'ask-until-agreed'
            and isinstance(step.get('id'), str) and bool(step['id'])
            and isinstance(step.get('purpose'), str) and bool(step['purpose'])
            and step.get('provides') == ['status', 'decisions', 'open_questions', 'reason'], path, 'steps mismatch')
    for relative, name in [(PUBLIC, 'grill'), (INTERNAL, 'ask-until-agreed')]:
        path = package / relative / 'SKILL.md'
        text = path.read_text()
        match = re.match(r'\A---\n(.*?)\n---(?:\n|$)', text, re.S)
        require(match is not None, path, 'frontmatter missing')
        metadata = yaml_value(match.group(1), path)
        require(isinstance(metadata, dict) and metadata.get('name') == name
                and isinstance(metadata.get('description'), str) and bool(metadata['description']), path, 'skill identity mismatch')
        require(not re.search(r'^```(?:bash|sh|shell)\b', text, re.M), path, 'shell block forbidden')
        require(not any(legacy in text for legacy in LEGACY), path, 'legacy runtime reference')
    for path in (package / INTERNAL).rglob('*.md'):
        require(not re.search(r'playbook|プレイブック', path.read_text(), re.I), path, 'internal composition reference')
    for path in package.rglob('*.md'):
        text = path.read_text()
        require(not re.search(r'^\s*(?:Feature:|Scenario:|```gherkin)', text, re.M), path, 'Gherkin belongs in evals')
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
