"""Deploy this title through the paired SteamOS devkit, preserving saved games."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import time
from source_identity import source_identity

ROOT = Path(__file__).resolve().parent.parent
REMOTE = '/home/deck/devkit-game/ElasticExplorer'
EXE = REMOTE + '/elastic_explorer.x86_64'


def cyg(path):
    path = str(path).replace('\\', '/')
    return '/cygdrive/' + path[0].lower() + path[2:]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', default='192.168.2.177')
    parser.add_argument('--devkit', default='T:/SteamLibrary/steamapps/common/SteamOSDevkitClient/windows-client')
    parser.add_argument('--capture', action='store_true', help='Run a sandbox smoke capture instead of normal menu')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    build = ROOT / 'builds/linux'
    manifest = json.loads((build / 'build-info.json').read_text(encoding='utf-8-sig'))
    binary = build / 'elastic_explorer.x86_64'
    digest = hashlib.sha256(binary.read_bytes()).hexdigest()
    if digest.lower() != manifest['sha256'].lower():
        raise RuntimeError('Artifact hash mismatch; rebuild before deploying')
    if source_identity(ROOT) != manifest.get('source_sha256'):
        raise RuntimeError('Source changed since export; rebuild before deploying')
    if args.dry_run:
        print(f'Verified {digest}; would deploy to {args.host}:{REMOTE}')
        return
    devkit = Path(args.devkit)
    ssh = devkit / 'cygroot/bin/ssh.exe'
    rsync = devkit / 'cygroot/bin/rsync.exe'
    home = Path.home()
    options = ['-o', 'UserKnownHostsFile=' + cyg(home / '.ssh/known_hosts'),
               '-o', 'StrictHostKeyChecking=yes', '-o', 'BatchMode=yes',
               '-o', 'ConnectTimeout=10', '-i', cyg(home / 'AppData/Local/steamos-devkit/steamos-devkit/devkit_rsa')]

    def remote(code):
        payload = base64.b64encode(code.encode()).decode()
        command = 'python3 -c "import base64; exec(base64.b64decode(\'' + payload + '\'))"'
        return subprocess.check_output([str(ssh), *options, 'deck@' + args.host, command], text=True).strip()

    def sync(source, destination):
        transport = ' '.join("'" + item + "'" for item in [cyg(ssh), *options])
        subprocess.run([str(rsync), '-az', '--chmod=Du=rwx,Dgo=rx,Fu=rwx,Fgo=rx',
                        '-e', transport, source, destination], check=True)

    output = remote("import subprocess; subprocess.run(['python3', '/home/deck/devkit-utils/steamos-prepare-upload', '--gameid', 'ElasticExplorer'], check=True)")
    print(output)
    prepared = json.loads(output)
    if prepared.get('directory', '').rstrip('/') != REMOTE:
        raise RuntimeError('Unexpected upload directory: ' + output)
    sync(cyg(ROOT / 'tools/deck_process_guard.sh'), 'deck@' + args.host + ':' + REMOTE + '/process_guard.sh')
    guard = REMOTE + '/process_guard.sh'
    prior = remote(f"import subprocess; print(subprocess.check_output(['bash', {guard!r}, 'list', {EXE!r}], text=True))").split()
    remote(f"import subprocess; subprocess.run(['bash', {guard!r}, 'stop', {EXE!r}], check=True)")
    sync(cyg(build) + '/', 'deck@' + args.host + ':' + REMOTE + '/')
    actual = remote(f"import hashlib; print(hashlib.sha256(open({EXE!r}, 'rb').read()).hexdigest())")
    if actual != digest:
        raise RuntimeError('Remote executable hash mismatch')
    argv = ['elastic_explorer.x86_64', '--resolution', '1280x800', '--fullscreen']
    if args.capture:
        remote("from pathlib import Path; Path('/home/deck/devkit-game/ElasticExplorer/deck-smoke.png').unlink(missing_ok=True)")
        argv += ['--', '--autostart', '--smoke', '--capture=/home/deck/devkit-game/ElasticExplorer/deck-smoke.png']
    parms = dict(gameid='ElasticExplorer', directory=REMOTE, argv=argv,
                 env={}, settings={'steam_play': '0'}, force_appid='')
    output = remote(f"import subprocess; subprocess.run(['python3', '/home/deck/devkit-utils/steam-client-create-shortcut', '--parms', {json.dumps(parms)!r}], check=True)")
    print(output)
    if json.loads(output).get('error'):
        raise RuntimeError(output)
    print(remote("import subprocess; subprocess.run(['python3', '/home/deck/devkit-utils/steam-devkit-rpc', 'run-game', 'gameid=ElasticExplorer'], check=True)"))
    for attempt in range(40):
        try:
            pid = remote(f"import subprocess; print(subprocess.check_output(['bash', {guard!r}, 'verify-fresh', {EXE!r}, {','.join(prior)!r}], text=True))")
            break
        except subprocess.CalledProcessError:
            time.sleep(0.5)
    else:
        raise RuntimeError('No fresh game process found')
    print(f'Verified Deck PID {pid}; SHA256 {digest}')
    if args.capture:
        for attempt in range(40):
            if remote("from pathlib import Path; print(Path('/home/deck/devkit-game/ElasticExplorer/deck-smoke.png').is_file())") == 'True':
                break
            time.sleep(0.5)
        else:
            raise RuntimeError('Deck did not produce a smoke capture')
        target = ROOT / 'test-results/deck-smoke.png'
        target.parent.mkdir(exist_ok=True)
        sync('deck@' + args.host + ':' + REMOTE + '/deck-smoke.png', cyg(target))


if __name__ == '__main__':
    main()
