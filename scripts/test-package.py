#!/usr/bin/env python3
"""Actual distribution copies; independently break each declared structural boundary."""
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('validator', ROOT / 'scripts/validate-package.py')
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)
P = validator.PACKAGE
E = P + '/' + validator.ENTRY


class PackageTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='grill-package-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        for name in ('plugins', '.claude-plugin', '.agents'):
            shutil.copytree(ROOT / name, self.root / name)

    def edit(self, relative, transform):
        path = self.root / relative
        path.write_text(transform(path.read_text()))

    def manifest(self, transform, runtime='codex'):
        self.edit(f'{P}/.{runtime}-plugin/plugin.json', lambda text: json.dumps(transform(json.loads(text))))

    def reject(self, expected):
        with self.assertRaisesRegex(ValueError, expected):
            validator.validate(self.root)

    def test_real_distribution_copy(self):
        validator.validate(self.root)

    def test_missing_contract(self):
        (self.root / E / 'CONTRACT.md').unlink()
        self.reject('inventory')

    def test_extra_reference(self):
        (self.root / E / 'references').mkdir()
        (self.root / E / 'references/extra.md').write_text('extra')
        self.reject('unexpected directory')

    def test_internal_skill_forbidden(self):
        (self.root / P / 'internal/other').mkdir(parents=True)
        (self.root / P / 'internal/other/SKILL.md').write_text('---\nname: other\n---\n')
        self.reject('unexpected directory')

    def test_manifest_under_plugins_root(self):
        (self.root / 'plugins/.codex-plugin').mkdir()
        self.reject('plugins/grill only')

    def test_empty_directory(self):
        (self.root / E / 'scripts').mkdir()
        self.reject('unexpected directory')

    def test_symlink(self):
        path = self.root / E / 'CONTRACT.md'
        path.unlink()
        path.symlink_to(self.root / P / 'LICENSE')
        self.reject('symlink')

    def test_runtime_mismatch(self):
        self.manifest(lambda d: d | {'version': '0.0.0'})
        self.reject('runtime identity')

    def test_catalog_mismatch(self):
        def change(text):
            data = json.loads(text)
            data['plugins'][0]['version'] = 'different-version'
            return json.dumps(data)
        self.edit('.agents/plugins/marketplace.json', change)
        self.reject('catalog identity')

    def test_catalog_source_two_levels(self):
        def change(text):
            data = json.loads(text)
            data['plugins'][0]['source'] = './plugins'
            return json.dumps(data)
        self.edit('.claude-plugin/marketplace.json', change)
        self.reject('catalog identity')

    def test_skills_string_form(self):
        for rt in ('claude', 'codex'):
            self.manifest(lambda d: d | {'skills': './skills/'}, rt)
        self.reject('public skills')

    def test_installation_surface(self):
        def change(d):
            d['metadata']['harness']['installationSurface'] = 'playbook-package'
            return d
        for rt in ('claude', 'codex'):
            self.manifest(change, rt)
        self.reject('harness declaration')

    def test_internal_declaration(self):
        def change(d):
            d['metadata']['harness']['internalPlugins'] = {'other': './internal/other'}
            return d
        for rt in ('claude', 'codex'):
            self.manifest(change, rt)
        self.reject('harness declaration')

    def test_requires_self(self):
        self.edit(E + '/playbook.yml', lambda t: t.replace('requires: []', 'requires:\n  - {plugin: ask-until-agreed, marketplace: grill}'))
        self.reject('requires')

    def test_step_order(self):
        self.edit(E + '/playbook.yml', lambda t: t.replace('id: ask\n', 'id: ask-first\n'))
        self.reject('steps mismatch')

    def test_step_kind(self):
        self.edit(E + '/playbook.yml', lambda t: t.replace('agent_work: invoking_agent\n    purpose: 答えで成果が変わる', 'skill: ask-until-agreed\n    purpose: 答えで成果が変わる'))
        self.reject('steps mismatch')

    def test_extra_step(self):
        self.edit(E + '/playbook.yml', lambda t: t + '  - id: extra\n    agent_work: invoking_agent\n    purpose: extra\n')
        self.reject('steps mismatch')

    def test_macro_in_playbook(self):
        self.edit(E + '/playbook.yml', lambda t: t.replace('description: 一問ずつ', 'description: ${.topic} 一問ずつ'))
        self.reject('plumbing')

    def test_frontmatter_name(self):
        self.edit(E + '/SKILL.md', lambda t: t.replace('name: grill', 'name: ask-until-agreed'))
        self.reject('skill identity')

    def test_legacy_call(self):
        self.edit(E + '/SKILL.md', lambda t: t + '\nRun decision.py.\n')
        self.reject('legacy runtime')

    def test_root_block(self):
        self.edit(E + '/CONTRACT.md', lambda t: t + '\nPLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/x}"\n')
        self.reject('plumbing')

    def test_shell_block(self):
        self.edit(E + '/SKILL.md', lambda t: t + '\n```bash\necho hello\n```\n')
        self.reject('shell block')

    def test_gherkin(self):
        self.edit(E + '/CONTRACT.md', lambda t: t + '\nScenario: example\n')
        self.reject('Gherkin')

    def test_broken_link(self):
        self.edit(E + '/SKILL.md', lambda t: t.replace('(CONTRACT.md)', '(references/missing.md)'))
        self.reject('link missing')

    def test_text_length_is_not_quality(self):
        self.edit(E + '/CONTRACT.md', lambda t: '# 内容は別途意味評価する\n')
        validator.validate(self.root)


if __name__ == '__main__':
    unittest.main(verbosity=2)
