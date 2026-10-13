#!/usr/bin/env python3
"""Run the real MKM processor stack in an isolated directory (requires PyYAML).

Example, after cloning rime-moran (trad), rime-mungyeong and rime-mkm:
  python tools/test_mkm.py --mira /path/to/mira \
      --moran /path/to/rime-moran --mungyeong /path/to/rime-mungyeong \
      --mkm /path/to/rime-mkm
"""

import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

import yaml


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("mira", "moran", "mungyeong", "mkm"):
        parser.add_argument("--" + name, required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="kagiroi-mkm-") as temporary:
        work = Path(temporary)
        data = work / "data"
        data.mkdir()
        for repo in (args.moran, root, args.mungyeong, args.mkm):
            files = subprocess.check_output(
                ["git", "-C", str(repo), "ls-files", "-z"]
            ).decode().split("\0")
            for name in filter(None, files):
                relative = Path(name)
                if (name.startswith(("lua/", "opencc/")) or
                        (len(relative.parts) == 1 and relative.suffix in (".yaml", ".txt"))):
                    target = data / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(repo / relative, target)

        def patch_file(name, update):
            path = data / name
            document = yaml.safe_load(path.read_text())
            update(document)
            path.write_text(yaml.safe_dump(document, allow_unicode=True, sort_keys=False))

        for schema in ("moran", "kagiroi", "mungyeong"):
            patch_file(schema + ".schema.yaml", lambda doc, s=schema:
                       doc.update({"__patch": [s + ".mkm:/patch", s + ".custom:/patch?"]}))

        def patch_alphabet(doc):
            for layout in ("3_dan", "3_dan_hira"):
                doc["alphabet"][layout]["alphabet"] += "`"

        patch_file("kagiroi.yaml", patch_alphabet)
        patch_file("default.yaml", lambda doc: doc.update({"schema_list": [
            {"schema": name} for name in ("moran", "kagiroi", "mungyeong")
        ]}))
        suites = [root / "tests/mkm.test.yaml",
                  root / "tests/kagiroi.test.yaml",
                  args.mungyeong / "tests/mungyeong.test.yaml"]
        failed = False
        for index, suite in enumerate(suites):
            spec = yaml.safe_load(suite.read_text())
            spec["source_dir"] = str(data)
            test_file = work / f"suite-{index}.yaml"
            test_file.write_text(yaml.safe_dump(spec, allow_unicode=True, sort_keys=False))
            # An empty cwd avoids reusing any checkout's prebuilt data.
            result = subprocess.run([str(args.mira.resolve()), "-C", str(work / "build"),
                                     str(test_file)], cwd=work)
            failed = failed or result.returncode != 0
        return int(failed)



if __name__ == "__main__":
    raise SystemExit(main())
