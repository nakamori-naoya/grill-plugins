#!/usr/bin/env python3
"""配布物の写しに対して、validate-package.py が宣言した述語を一つずつ破り、拒むことを確かめる。"""
import importlib.util
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

    def reject(self, expected):
        with self.assertRaisesRegex(ValueError, expected):
            validator.validate(self.root)

    def test_real_distribution_copy(self):
        validator.validate(self.root)

    def test_description_missing(self):
        self.edit(E + '/SKILL.md', lambda t: t.replace('\ndescription:', '\nsummary:', 1))
        self.reject('description missing')

    def test_shell_block(self):
        self.edit(E + '/SKILL.md', lambda t: t + '\n```bash\necho hello\n```\n')
        self.reject('shell block')

    def test_gherkin(self):
        self.edit(E + '/SKILL.md', lambda t: t + '\nScenario: example\n')
        self.reject('Gherkin')

    def test_broken_link(self):
        self.edit(E + '/SKILL.md', lambda t: t + '\n[欠けた資料](references/missing.md)\n')
        self.reject('link missing')


if __name__ == '__main__':
    unittest.main(verbosity=2)
