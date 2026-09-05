"""Hash Git-visible source paths and bytes, including untracked source files."""
import hashlib
from pathlib import Path
import subprocess


def source_identity(root):
    paths = subprocess.check_output(
        ['git', '-C', str(root), 'ls-files', '-cz', '--cached', '--others', '--exclude-standard']
    ).split(b'\0')
    digest = hashlib.sha256()
    for name in sorted(set(paths) - {b''}):
        path = root / name.decode('utf-8')
        if path.is_file():
            digest.update(name + b'\0')
            digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


if __name__ == '__main__':
    print(source_identity(Path(__file__).resolve().parent.parent))
