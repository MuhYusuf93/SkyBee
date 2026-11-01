"""Host-only safety boundary checks; no ADB, archive or user store is touched."""
import importlib.util
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
sys.dont_write_bytecode = True
ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('handoff_under_test', ROOT/'tools/handoff_skybee_m53.py')
module = importlib.util.module_from_spec(spec)
with mock.patch('subprocess.run', side_effect=AssertionError('Import cannot control a device')):
    spec.loader.exec_module(module)

class HandoffBoundaryTest(unittest.TestCase):
    def test_old_archives_markers_and_unknown_data_never_match_reset_allowlist(self):
        uid='11111111-1111-4111-8111-111111111111'
        for path in [f'databases/m5_backups/{uid}/{uid}.kasirbackup', f'databases/m5_backups/{uid}/completed.json', 'databases/skybee-demo-seed-v1.json', 'databases/skybee-m52-upgrade-audit.json', 'databases/another-store.db', 'no_backup/secret-unknown', 'databases/m5_restore_'+'-'*36+'/database.db']:
            with self.subTest(path=path):self.assertFalse(module.allowed_reset_change(path))

    def test_retained_recovery_and_biometric_changes_require_the_exact_scope(self):
        alias='retained-backup-'+'a'*48
        self.assertFalse(module.allowed_reset_change('no_backup/secret-'+alias))
        self.assertTrue(module.allowed_reset_change('no_backup/secret-'+alias, alias))
        self.assertFalse(module.allowed_reset_change('no_backup/secret-retained-backup-'+'b'*48, alias))
        scope='c'*64
        self.assertFalse(module.allowed_reset_change('no_backup/biometric-'+scope))
        self.assertTrue(module.allowed_reset_change('no_backup/biometric-'+scope,biometric_scopes=[scope]))
        self.assertFalse(module.allowed_reset_change('no_backup/biometric-'+scope+'-unrelated',biometric_scopes=[scope]))

    def test_atomic_sidecars_and_exact_temporary_names_match(self):
        for path in ['databases/kasir_app.db-wal','no_backup/secret-database-v1.bak','no_backup/secret-drive-session-11111111-1111-4111-8111-111111111111','databases/m5_restore_11111111-1111-4111-8111-111111111111/database.db']:
            with self.subTest(path=path):self.assertTrue(module.allowed_reset_change(path))

    def test_missing_explicit_authorization_stops_before_any_adb(self):
        folder = pathlib.Path(tempfile.mkdtemp(prefix='m53-skybee-handoff-unittest-',dir=ROOT/'build'))
        self.assertTrue(folder.resolve().is_relative_to((ROOT/'build').resolve()))
        argv=[str(ROOT/'tools/handoff_skybee_m53.py'),'prepare','--directory',str(folder),'--apk','unused','--gate','unused','--source-commit','unused','--poco-result','unused','--dv-result','unused','--external-directory','unused','--source-manifest','unused','--poco-evidence','unused','--dv-evidence','unused']
        try:
            with mock.patch.object(sys,'argv',argv), mock.patch('subprocess.run') as action:
                with self.assertRaises(AssertionError):module.main()
                action.assert_not_called()
        finally:
            folder.rmdir() # Owned directory remains empty; no recursive delete.

    def test_optimized_python_cannot_disable_safety_assertions(self):
        r=subprocess.run([sys.executable,'-O',str(ROOT/'tools/handoff_skybee_m53.py'),'--help'],capture_output=True)
        self.assertNotEqual(r.returncode,0)
        self.assertIn(b'Safety checks require Python without optimization',r.stderr)

if __name__=='__main__':unittest.main()
