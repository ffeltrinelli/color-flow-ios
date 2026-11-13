#!/usr/bin/env python3
"""Run simulator tests, then the same UI suite on a connected configured SE."""
import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(arguments, **kwargs):
    return subprocess.run(arguments, cwd=ROOT, check=True, **kwargs)


def json_command(arguments):
    result = run(arguments, stdout=subprocess.PIPE, text=True)
    return json.loads(result.stdout)


def usb_iphones(tree):
    found = []
    for item in tree:
        if 'iphone' in item.get('_name', '').lower():
            found.append(item)
        found.extend(usb_iphones(item.get('_items', [])))
    return found


def choose_device(devices, usb, requested=None):
    physical = [device for device in devices if not device.get('simulator', False)]
    if requested:
        candidates = [device for device in physical if device.get('identifier') == requested]
        if not candidates:
            raise RuntimeError('The configured iPhone is not visible to Xcode. Connect, unlock, and pair it first.')
    else:
        candidates = [device for device in physical if device.get('modelCode') == 'iPhone12,8']
        # xcdevice also remembers disconnected devices. Only report those as present
        # when available, seen over USB, or blocked for a reason other than absence.
        candidates = [device for device in candidates if device.get('available') or usb or
                      (device.get('error') and not any(word in str(device['error']).lower()
                       for word in ['not connected', 'disconnected', 'offline']))]
    if not candidates:
        if usb:
            raise RuntimeError('An iPhone is connected by USB but Xcode cannot identify the SE. Unlock it, trust this Mac, pair it, and enable Developer Mode.')
        return None
    if len(candidates) != 1:
        raise RuntimeError('Multiple candidate phones found. Use --device UDID to select your SE.')
    device = candidates[0]
    if not device.get('available'):
        error = device.get('error', {})
        reason = error.get('recoverySuggestion') or error.get('description') or 'Unlock the phone and check trust, Developer Mode, and pairing.'
        raise RuntimeError('The iPhone is present but unavailable: ' + reason)
    return device


def simulator_destination(requested):
    devices = json_command(['xcrun', 'simctl', 'list', 'devices', 'available', '-j'])['devices']
    available = [device for group in devices.values() for device in group]
    if requested:
        if not any(device['udid'] == requested for device in available):
            raise RuntimeError('Requested simulator is unavailable. Run xcrun simctl list devices available.')
        return requested
    compact = [device for device in available if 'iPhone SE' in device['name'] or
               'iPhone-SE' in device.get('deviceTypeIdentifier', '')]
    if compact:
        return compact[0]['udid']
    raise RuntimeError('Create an iPhone SE-sized simulator in Xcode first, or pass --simulator UDID. See README.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', default=os.environ.get('SIMULATOR_UDID'))
    parser.add_argument('--device', default=os.environ.get('DEVICE_UDID'))
    args = parser.parse_args()
    run(['xcodebuild', '-checkFirstLaunchStatus'])
    destination = simulator_destination(args.simulator)
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    results = ROOT / 'TestResults' / stamp
    results.mkdir(parents=True)
    base = ['xcodebuild', '-project', 'ColorFlow.xcodeproj', '-scheme', 'ColorFlow',
            '-derivedDataPath', str(ROOT / 'DerivedData'), '-parallel-testing-enabled', 'NO']
    failures = []
    try:
        run(base + ['-destination', f'platform=iOS Simulator,id={destination}',
                    '-resultBundlePath', str(results / 'simulator.xcresult'), 'CODE_SIGNING_ALLOWED=NO', 'test'])
    except subprocess.CalledProcessError:
        failures.append('Simulator tests failed; inspect simulator.xcresult.')

    try:
        devices = json_command(['xcrun', 'xcdevice', 'list', '--timeout', '10'])
        usb_tree = json_command(['system_profiler', 'SPUSBDataType', '-json'])
        usb = usb_iphones(usb_tree.get('SPUSBDataType', []))
        device = choose_device(devices, usb, args.device)
        if device is None:
            print('DEVICE TESTS SKIPPED: iPhone SE is not connected.')
        else:
            print('Running UI suite on connected iPhone SE; iOS ' + device.get('operatingSystemVersion', 'unknown'))
            if not (ROOT / 'Config/Local.xcconfig').exists():
                raise RuntimeError('Configure personal signing in Config/Local.xcconfig before physical-device tests. See README.')
            run(base + ['-destination', f'platform=iOS,id={device["identifier"]}',
                        '-resultBundlePath', str(results / 'device.xcresult'),
                        '-only-testing:ColorFlowUITests', '-allowProvisioningUpdates',
                        '-allowProvisioningDeviceRegistration', 'test'])
    except (RuntimeError, subprocess.CalledProcessError) as error:
        failures.append('DEVICE TESTS BLOCKED/FAILED: ' + str(error))
    print('Results: ' + str(results))
    if failures:
        raise RuntimeError('\n'.join(failures))


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
