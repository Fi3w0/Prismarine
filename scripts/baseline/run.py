#!/usr/bin/env python3
"""Linux Phase 0 measurements against synthetic data; never uses a real library."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import platform
import shlex
import statistics
import sys
import struct
import subprocess
import threading
import time
import zipfile
import zlib


def png(width, height):
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))
    pixels = b''.join(b'\0' + bytes((25, 100 + y % 80, 120)) * width for y in range(height))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b''))


def fixtures(root, count, mods):
    root.mkdir(parents=True)
    # Refuse outside network access through the application's own proxy settings.
    (root / 'prismlauncher.cfg').write_text(
        '[General]\nInstanceDir=instances\nProxyType=HTTP\nProxyAddr=127.0.0.1\nProxyPort=1\n')
    accounts = [{'active': index == 0, 'type': 'Offline', 'profile': {
        'id': f'{index + 1:032x}', 'name': f'Fixture{index}',
        'skin': {'data': base64.b64encode(png(64, 64)).decode(), 'variant': 'CLASSIC'}}}
        for index in range(2)]
    (root / 'accounts.json').write_text(json.dumps({'accounts': accounts}))
    templates = root / 'templates'
    templates.mkdir()
    (templates / 'cover.png').write_bytes(png(1280, 720))
    for index in range(mods):
        with zipfile.ZipFile(templates / f'mod-{index:03}.jar', 'w') as jar:
            jar.writestr('fabric.mod.json', json.dumps({
                'schemaVersion': 1, 'id': f'fixture_{index}', 'version': '1.0.0',
                'name': f'Fixture Mod {index}', 'depends': {'minecraft': '1.21.1'}}))
    for index in range(count):
        instance = root / 'instances' / f'fixture-{index:03}'
        game = instance / '.minecraft'
        for folder in ('mods', 'screenshots', 'saves', 'logs', 'resourcepacks', 'shaderpacks'):
            (game / folder).mkdir(parents=True)
        (instance / 'instance.cfg').write_text(
            f'[General]\nname=Fixture Pack {index:03}\nlastLaunchTime={1700000000000 + index}\n'
            f'totalTimePlayed={index * 120}\n')
        (instance / 'mmc-pack.json').write_text(json.dumps({'components': [
            {'uid': 'net.minecraft', 'version': '1.21.1'},
            {'uid': 'net.fabricmc.fabric-loader', 'version': '0.16.0'}]}))
        for mod in range(mods):
            os.link(templates / f'mod-{mod:03}.jar', game / 'mods' / f'mod-{mod:03}.jar')
        os.link(templates / 'cover.png', game / 'screenshots' / 'fixture.png')


def process_sample(pid):
    proc = Path('/proc') / str(pid)
    # comm may contain spaces or parentheses; stat fields start after its final ')'.
    stat = (proc / 'stat').read_text().rsplit(')', 1)[1].split()
    status = dict(line.split(':', 1) for line in (proc / 'status').read_text().splitlines())
    return {'time': time.monotonic(),
            'cpu_seconds': (int(stat[11]) + int(stat[12])) / os.sysconf('SC_CLK_TCK'),
            'rss_mib': int(status.get('VmRSS', '0 kB').split()[0]) / 1024,
            'hwm_mib': int(status.get('VmHWM', '0 kB').split()[0]) / 1024}


def window_summary(samples, start, end):
    selected = [s for s in samples if start <= s['elapsed'] <= end]
    if len(selected) < 2:
        return None
    a, b = selected[0], selected[-1]
    return {'duration_s': b['time'] - a['time'],
            'cpu_percent_one_core': 100 * (b['cpu_seconds'] - a['cpu_seconds']) / (b['time'] - a['time']),
            'median_rss_mib': statistics.median(s['rss_mib'] for s in selected),
            'peak_rss_mib': max(s['rss_mib'] for s in selected)}


def run(binary, fixture, output, probe=None, screenshot=False, animations=True):
    output.mkdir(parents=True)
    for name in ('config', 'data', 'cache'):
        (output / name).mkdir()
    stub = output / 'prism-stub'
    stub.write_text('#!/bin/sh\nexit 0\n')
    stub.chmod(0o700)
    preferences = output / 'preferences.ini'
    preferences.write_text(f'[interface]\nfirstRunSeen=true\nanimations={str(animations).lower()}\n'
                           f'[launch]\nprismProgram={stub}\n')
    env = dict(os.environ, XDG_CONFIG_HOME=str(output / 'config'), XDG_DATA_HOME=str(output / 'data'),
               XDG_CACHE_HOME=str(output / 'cache'), QSG_INFO='1')
    # Respect the selected platform/backend, normally the user's desktop defaults.
    env['QT_LOGGING_RULES'] = 'qt.scenegraph.time.renderloop=true'
    if probe:
        env['LD_PRELOAD'] = str(probe)
    command = [str(binary), '--prism-data', str(fixture), '--preferences', str(preferences),
               '--page', 'home', '--window-size', '1280x800']
    if screenshot:
        command += ['--screenshot', str(output / 'home.png')]
    events, lines, samples = [], [], []
    started = time.monotonic()
    process = subprocess.Popen(command, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                               text=True, start_new_session=True)

    def read_output():
        for line in process.stderr:
            elapsed = time.monotonic() - started
            lines.append({'elapsed_s': elapsed, 'text': line.rstrip()})
            if 'BASELINE {' in line:
                event = json.loads(line.split('BASELINE ', 1)[1])
                event['observed_elapsed_s'] = elapsed
                events.append(event)

    reader = threading.Thread(target=read_output)
    reader.start()
    # Only unprofiled baseline processes are stopped here. The probe exits normally.
    deadline = 30 if probe else 6
    timed_out = False
    while process.poll() is None:
        elapsed = time.monotonic() - started
        if elapsed > deadline:
            timed_out = bool(probe or screenshot)
            process.terminate()
            break
        try:
            sample = process_sample(process.pid)
            sample['elapsed'] = elapsed
            samples.append(sample)
        except (FileNotFoundError, ProcessLookupError):
            pass
        time.sleep(0.05)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        timed_out = True
        process.kill()
        process.wait()
    reader.join()
    (output / 'stderr.json').write_text(json.dumps(lines, indent=2))
    (output / 'samples.json').write_text(json.dumps(samples, indent=2))
    (output / 'events.json').write_text(json.dumps(events, indent=2))
    render_lines = [line for line in lines if 'qt.scenegraph.time.renderloop:' in line['text']
                    and 'frame rendered' in line['text'].lower()]
    result = {'command': command, 'probe': bool(probe), 'returncode': process.returncode,
              'timed_out': timed_out, 'elapsed_s': time.monotonic() - started,
              'first_render_log_s': render_lines[0]['elapsed_s'] if render_lines else None,
              'idle_rendered_frames': sum(3 <= row['elapsed_s'] <= 5.8 for row in render_lines),
              'peak_sampled_rss_mib': max((s['rss_mib'] for s in samples), default=None),
              'peak_hwm_mib': max((s['hwm_mib'] for s in samples), default=None),
              'idle': window_summary(samples, 3, 5.8)}
    if probe:
        actions = {e['name']: e['observed_elapsed_s'] for e in events if e['event'] == 'action'}
        result['windows'] = {name: window_summary(samples, actions[name] + 0.3, actions[name] + 2.7)
                             for name in ('home_idle', 'library_idle', 'hidden_idle') if name in actions}
        result['events'] = events
    result['valid'] = (not timed_out and bool(samples) and bool(render_lines)
                       and process.returncode == (0 if probe or screenshot else -15))
    if screenshot:
        result['valid'] &= (output / 'home.png').is_file() and (output / 'home.png').stat().st_size > 0
    if probe:
        result['valid'] &= (any(e.get('name') == 'finish' for e in events)
                            and not any(e['event'] == 'error' for e in events))
    (output / 'result.json').write_text(json.dumps(result, indent=2))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, default=Path('build/prismarine'))
    parser.add_argument('--output', type=Path, required=True,
                        help='New directory; existing directories are refused.')
    parser.add_argument('--repetitions', type=int, default=3)
    parser.add_argument('--skip-probe', action='store_true')
    parser.add_argument('--libraries', nargs='+', choices=('empty', 'small', 'large'),
                        default=['empty', 'small', 'large'])
    parser.add_argument('--animations', choices=('on', 'off'), default='on')
    args = parser.parse_args()
    if sys.platform != 'linux':
        parser.error('This diagnostic reads Linux /proc and uses LD_PRELOAD.')
    binary, output = args.binary.resolve(), args.output.resolve()
    if not binary.is_file():
        parser.error('Build the executable first.')
    if output.exists():
        parser.error('Choose a new output directory.')
    if not 1 <= args.repetitions <= 10:
        parser.error('Repetitions must be between 1 and 10.')
    output.mkdir(parents=True)
    results = {'system': {'platform': platform.platform(), 'session': os.environ.get('XDG_SESSION_TYPE'),
                          'qt_platform_override': os.environ.get('QT_QPA_PLATFORM'),
                          'backend_override': os.environ.get('QT_QUICK_BACKEND'),
                          'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(),
                          'animations': args.animations}, 'runs': {}}
    probe = None
    if not args.skip_probe:
        probe = output / 'probe.so'
        flags = shlex.split(subprocess.check_output(
            ['pkg-config', '--cflags', '--libs', 'Qt6Core', 'Qt6Gui', 'Qt6Quick', 'Qt6Test'], text=True))
        subprocess.run(['c++', '-shared', '-fPIC', '-std=c++17', '-O2',
                        str(Path(__file__).with_name('probe.cpp')), '-o', str(probe), *flags], check=True)
    for name, count, mods in [('empty', 0, 0), ('small', 10, 25), ('large', 250, 100)]:
        if name not in args.libraries:
            continue
        fixture = output / 'fixtures' / name
        fixtures(fixture, count, mods)
        runs = []
        for repetition in range(args.repetitions):
            print(f'{name}: release baseline {repetition + 1}/{args.repetitions}', flush=True)
            result = run(binary, fixture, output / f'{name}-{repetition}', animations=args.animations == 'on')
            runs.append(result)
            print(json.dumps(result), flush=True)
        results['runs'][name] = runs
        if name != 'empty' and probe:
            print(f'{name}: instrumented navigation and hidden-window checks', flush=True)
            results['runs'][f'{name}-probe'] = run(binary, fixture, output / f'{name}-probe', probe,
                                                animations=args.animations == 'on')
        print(f'{name}: screenshot smoke check', flush=True)
        results['runs'][f'{name}-screenshot'] = run(binary, fixture, output / f'{name}-screenshot',
                                                 screenshot=True, animations=args.animations == 'on')
    (output / 'summary.json').write_text(json.dumps(results, indent=2))
    print(f'Results: {output / "summary.json"}', flush=True)
    if any(not run['valid'] for runs in results['runs'].values()
           for run in (runs if isinstance(runs, list) else [runs])):
        raise SystemExit('One or more measurements failed; inspect the output logs.')


if __name__ == '__main__':
    main()
