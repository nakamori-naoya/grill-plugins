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
P = 'plugins/' + validator.PUBLIC
I = 'plugins/' + validator.INTERNAL


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
        self.edit(f'plugins/.{runtime}-plugin/plugin.json', lambda text: json.dumps(transform(json.loads(text))))

    def reject(self, expected):
        with self.assertRaisesRegex(ValueError, expected):
            validator.validate(self.root)

    def test_real_distribution_copy(self):
        validator.validate(self.root)

    def test_missing_reference(self):
        (self.root / I / 'references/dialogue-principles.md').unlink()
        self.reject('inventory')

    def test_extra_reference(self):
        (self.root / I / 'references/extra.md').write_text('extra')
        self.reject('inventory')

    def test_empty_directory(self):
        (self.root / I / 'scripts').mkdir()
        self.reject('unexpected directory')

    def test_symlink(self):
        path = self.root / I / 'references/dialogue-principles.md'
        path.unlink()
        path.symlink_to(self.root / 'plugins/LICENSE')
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

    def test_public_internal_mix(self):
        for rt in ('claude', 'codex'):
            self.manifest(lambda d: d | {'skills': [f'./{validator.PUBLIC}', f'./{validator.INTERNAL}']}, rt)
        self.reject('public skills')

    def test_wrong_internal_declaration(self):
        def change(d):
            d['metadata']['harness']['internalPlugins'] = {'other': './skills/other'}
            return d
        for rt in ('claude', 'codex'):
            self.manifest(change, rt)
        self.reject('harness declaration')

    def test_requires(self):
        self.edit(P + '/playbook.yml', lambda t: t.replace('plugin: ask-until-agreed', 'plugin: other'))
        self.reject('requires')

    def test_step_target(self):
        self.edit(P + '/playbook.yml', lambda t: t.replace('skill: ask-until-agreed', 'skill: other'))
        self.reject('steps mismatch')

    def test_extra_step(self):
        self.edit(P + '/playbook.yml', lambda t: t + '  - id: extra\n    skill: ask-until-agreed\n')
        self.reject('steps must')

    def test_contract(self):
        self.edit(P + '/playbook.yml', lambda t: t.replace('version: 1', 'version: 9'))
        self.reject('contract declaration')

    def test_boolean_contract_version(self):
        self.edit(P + "/playbook.yml", lambda t: t.replace("version: 1", "version: true"))
        self.reject("contract declaration")

    def test_frontmatter_collision(self):
        self.edit(I + '/SKILL.md', lambda t: t.replace('name: ask-until-agreed', 'name: grill'))
        self.reject('skill identity')

    def test_legacy_call(self):
        self.edit(I + '/SKILL.md', lambda t: t + '\nRun decision.py.\n')
        self.reject('legacy runtime')

    def test_shell_block(self):
        self.edit(P + '/SKILL.md', lambda t: t + '\n```bash\necho hello\n```\n')
        self.reject('shell block')

    def test_gherkin(self):
        self.edit(I + '/references/dialogue-principles.md', lambda t: t + '\nScenario: example\n')
        self.reject('Gherkin')

    def test_broken_link(self):
        self.edit(I + '/SKILL.md', lambda t: t.replace('(references/dialogue-principles.md)', '(references/missing.md)'))
        self.reject('link missing')

    def test_internal_composition(self):
        self.edit(I + '/SKILL.md', lambda t: t + '\nplaybook dependency\n')
        self.reject('internal composition')

    def test_text_length_is_not_quality(self):
        self.edit(I + '/references/dialogue-principles.md', lambda t: '# 内容は別途意味評価する\n')
        validator.validate(self.root)


if __name__ == '__main__':
    unittest.main(verbosity=2)
