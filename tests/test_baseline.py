"""Isolated recovery tests: no defaults, NSWorkspace or real user files are accessed."""
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

loader = importlib.machinery.SourceFileLoader('baseline', str(Path(__file__).resolve().parents[1] / 'bin/veil-baseline'))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.root = self.home / '.config/veil'
        self.b = module.Baseline(self.home, self.root)
        self.calls = []

    def fake_run(self, argv, **kwargs):
        self.calls.append(argv)
        if argv[1] == 'export':
            return subprocess.CompletedProcess(argv, 0, plistlib.dumps({'AppleHighlightColor': 'original highlight'}))
        if argv[1] == 'capture':
            return subprocess.CompletedProcess(argv, 0, json.dumps(self.wallpaper()).encode())
        return subprocess.CompletedProcess(argv, 0, b'')

    def wallpaper(self):
        image = self.home / 'Pictures/original.png'
        image.parent.mkdir(exist_ok=True)
        image.write_bytes(b'fixture image; native bridge checks image decoding')
        return {'version': 1, 'scope': 'connected-displays-current-space',
                'screens': [{'uuid': 'screen-A', 'url': image.as_uri()}]}

    def test_each_file_captured_with_partial_original_directory(self):
        self.b.original.mkdir(parents=True)
        (self.b.original / 'cursor.settings.json').write_text('{}')
        ghostty = self.b.files()['ghostty.config.ghostty']
        ghostty.parent.mkdir(parents=True)
        ghostty.write_text('original ghostty')
        self.assertTrue(self.b.capture(True, Path('/fixture/bridge'), self.fake_run))
        self.assertEqual((self.b.original / 'ghostty.config.ghostty').read_text(), 'original ghostty')
        self.assertTrue(self.b.marker('cava.config', 'absent').is_file())
        self.assertEqual(json.loads((self.b.original / 'appearance.json').read_text()), {'AppleHighlightColor': 'original highlight'})
        self.assertTrue((self.b.original / 'wallpaper.json').is_file())

    def test_absent_and_present_baselines_survive_reinstall(self):
        self.b.capture(True, Path('/fixture/bridge'), self.fake_run)
        cava = self.b.files()['cava.config']
        cava.parent.mkdir(parents=True)
        cava.write_text('Veil themed config')
        self.calls.clear()
        self.b.capture(True, Path('/fixture/bridge'), self.fake_run)
        self.assertEqual(self.calls, [])
        self.assertFalse((self.b.original / 'cava.config').exists())
        self.b.restore_files()
        self.assertFalse(cava.exists())

    def test_legacy_missing_baselines_are_unavailable_not_recaptured(self):
        (self.root / 'generated').mkdir(parents=True)
        (self.root / 'generated/launcher.json').write_text('{}')
        cava = self.b.files()['cava.config']
        cava.parent.mkdir(parents=True)
        cava.write_text('current themed config')
        self.assertFalse(self.b.capture(True, Path('/fixture/bridge'), self.fake_run))
        self.assertEqual(self.calls, [])
        self.assertTrue(self.b.marker('wallpaper.json', 'unavailable').exists())
        self.assertTrue(self.b.marker('cava.config', 'unavailable').exists())
        self.b.restore_files()
        self.assertEqual(cava.read_text(), 'current themed config')

    def test_installed_app_overrides_fresh_claim(self):
        (self.home / 'Applications/Veil Search.app').mkdir(parents=True)
        self.assertFalse(self.b.capture(True, Path('/fixture/bridge'), self.fake_run))
        self.assertEqual(self.calls, [])

    def test_fresh_capture_without_native_bridge_refuses_without_records(self):
        with self.assertRaises(ValueError):
            self.b.capture(True, run=self.fake_run)
        self.assertFalse(self.b.original.exists())

    def test_symlink_capture_source_is_refused(self):
        target = self.b.files()['ghostty.config.ghostty']
        target.parent.mkdir(parents=True)
        other = self.home / 'other'
        other.write_text('unrelated')
        target.symlink_to(other)
        with self.assertRaises(ValueError):
            self.b.capture_file('ghostty.config.ghostty', target, True)
        self.assertFalse((self.b.original / 'ghostty.config.ghostty').exists())

    def test_existing_original_is_never_overwritten(self):
        self.b.original.mkdir(parents=True)
        old = self.b.original / 'ghostty.config.ghostty'
        old.write_text('real old settings')
        self.b.capture(False, run=self.fake_run)
        self.assertEqual(old.read_text(), 'real old settings')

    def test_reject_contaminated_missing_remote_duplicate_wallpapers(self):
        valid = self.wallpaper()
        self.b.validate_wallpaper(valid)
        art = self.root / 'art/theme.jpg'
        art.parent.mkdir(parents=True)
        art.write_bytes(b'art')
        for url in (art.as_uri(), 'https://example.com/image.jpg', (self.home / 'missing.jpg').as_uri()):
            data = json.loads(json.dumps(valid))
            data['screens'][0]['url'] = url
            with self.assertRaises(ValueError):
                self.b.validate_wallpaper(data)
        valid['screens'].append(valid['screens'][0])
        with self.assertRaises(ValueError):
            self.b.validate_wallpaper(valid)

    def test_invalid_snapshot_leaves_baseline_files_untouched(self):
        def bad(argv, **kwargs):
            return subprocess.CompletedProcess(argv, 0, b'{"version": 1, "screens": []}')
        with self.assertRaises(ValueError):
            self.b.capture(True, Path('/fixture/bridge'), bad)
        self.assertFalse(self.b.original.exists())

    def test_restore_wallpaper_unavailable_does_not_call_bridge(self):
        self.b.capture(False, run=self.fake_run)
        with self.assertRaises(ValueError):
            self.b.restore_wallpaper(Path('/fixture/bridge'), self.fake_run)
        self.assertEqual(self.calls, [])

    def test_appearance_restores_absence_without_inventing_default(self):
        self.b.capture(True, Path('/fixture/bridge'), self.fake_run)
        self.calls.clear()
        self.b.restore_appearance(self.fake_run)
        self.assertIn(['/usr/bin/defaults', 'delete', '-g', 'AppleAccentColor'], self.calls)
        self.assertIn(['/usr/bin/defaults', 'write', '-g', 'AppleHighlightColor', '-string', 'original highlight'], self.calls)

    def test_symlink_restore_preflight_prevents_partial_changes(self):
        self.b.capture(True, Path('/fixture/bridge'), self.fake_run)
        targets = list(self.b.files().values())
        for target in targets:
            target.parent.mkdir(parents=True, exist_ok=True)
        targets[0].write_text('keep current')
        targets[1].symlink_to(targets[0])
        with self.assertRaises(ValueError):
            self.b.restore_files()
        self.assertEqual(targets[0].read_text(), 'keep current')


if __name__ == '__main__':
    unittest.main()
