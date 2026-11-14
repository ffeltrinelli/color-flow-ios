"""Checks for absence vs. blocked-device reporting without requiring a phone."""
import unittest
from unittest.mock import patch
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path

spec = spec_from_file_location('runner', Path(__file__).with_name('run-tests.py'))
runner = module_from_spec(spec)
spec.loader.exec_module(runner)


class DeviceSelectionTests(unittest.TestCase):
    def phone(self, **changes):
        return dict(simulator=False, identifier='local-device', modelCode='iPhone12,8', **changes)

    def test_absent_is_skipped(self):
        self.assertIsNone(runner.choose_device([], []))

    def test_remembered_disconnected_phone_is_skipped(self):
        self.assertIsNone(runner.choose_device([self.phone(available=False, error={'description': 'Device is not connected'})], []))

    def test_connected_se_is_selected(self):
        phone = self.phone(available=True)
        self.assertEqual(runner.choose_device([phone], []), phone)

    def test_locked_device_is_blocked(self):
        with self.assertRaisesRegex(RuntimeError, 'unavailable'):
            runner.choose_device([self.phone(available=False, error={'description': 'Device is locked'})], [{}])

    def test_unpaired_usb_phone_is_blocked(self):
        with self.assertRaisesRegex(RuntimeError, 'trust this Mac'):
            runner.choose_device([], [{}])

    def test_explicit_missing_phone_is_blocked(self):
        with self.assertRaisesRegex(RuntimeError, 'not visible'):
            runner.choose_device([], [], 'requested')

    def test_custom_named_se_simulator_is_selected(self):
        data = {'devices': {'runtime': [{'name': 'Color Flow SE', 'udid': 'compact',
                 'deviceTypeIdentifier': 'com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation'}]}}
        with patch.object(runner, 'json_command', return_value=data):
            self.assertEqual(runner.simulator_destination(None), 'compact')

    def test_ambiguous_devices_are_blocked(self):
        with self.assertRaisesRegex(RuntimeError, 'Multiple'):
            runner.choose_device([self.phone(available=True), self.phone(available=True)], [])


class TestSelectionTests(unittest.TestCase):
    def test_routine_run_checks_ui_without_full_campaign(self):
        selection = runner.test_selection(False)
        self.assertIn('-only-testing:ColorFlowUITests', selection)
        self.assertIn('-skip-testing:ColorFlowUITests/ColorFlowUITests/testFullCampaignJourneyAndStartAgain', selection)

    def test_release_check_includes_full_campaign(self):
        selection = runner.test_selection(True)
        self.assertIn('-only-testing:ColorFlowUITests', selection)
        self.assertFalse(any(item.startswith('-skip-testing:') for item in selection))


if __name__ == '__main__':
    unittest.main()
