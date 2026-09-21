# SPDX-License-Identifier: GPL-3.0-or-later
"""Build a deterministic source archive from an explicit file list."""
import gzip
import io
from pathlib import Path
import tarfile
import sys

version = sys.argv[1]
root = Path(__file__).resolve().parent.parent
files = [
    ".gitignore", "Makefile", "README.md", "ROADMAP.md", "TODO.md",
    "CHANGELOG.md", "VALIDATION.md", "pathcheck.c", "man/pathcheck.1",
    "tests/test.sh", "scripts/dist.py", "LICENSE",
]
destination = root / "dist"
destination.mkdir(exist_ok=True)
archive = destination / ("pathcheck-" + version + ".tar.gz")
with archive.open("wb") as output:
    with gzip.GzipFile(filename="", mode="wb", fileobj=output, mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode="w") as bundle:
            for name in sorted(files):
                data = (root / name).read_bytes()
                info = tarfile.TarInfo("pathcheck-" + version + "/" + name)
                info.size = len(data)
                info.mode = 0o644
                info.mtime = 0
                bundle.addfile(info, io.BytesIO(data))
print(archive)
