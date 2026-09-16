#!/usr/bin/env python3
"""Haalt alleen de benodigde ARletta-modellen uit de 8,5 GB Zenodo-zip.

Leest de zip-index via HTTP-range-requests, dus er wordt niet gedownload
behalve de ~21 MB aan modelbestanden zelf.

    python3 bin/download-arletta-models.py [doelmap] [--all]
"""
import os
import sys
import urllib.request
import zipfile

URL = "https://zenodo.org/api/records/11191457/files/ARletta.zip/content"
WANTED = ("super.mlmodel", "blla.mlmodel")


class HttpFile:
    """Minimale seek/read-wrapper zodat zipfile over HTTP kan lezen."""

    def __init__(self, url):
        self.url = url
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req) as r:
            self.size = int(r.headers["Content-Length"])
        self.pos = 0

    def seek(self, off, whence=0):
        if whence == 0:
            self.pos = off
        elif whence == 1:
            self.pos += off
        else:
            self.pos = self.size + off
        return self.pos

    def tell(self):
        return self.pos

    def read(self, n=-1):
        if n is None or n < 0:
            n = self.size - self.pos
        if n <= 0:
            return b""
        end = min(self.pos + n, self.size) - 1
        req = urllib.request.Request(
            self.url, headers={"Range": f"bytes={self.pos}-{end}"}
        )
        with urllib.request.urlopen(req) as r:
            data = r.read()
        self.pos += len(data)
        return data


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    take_all = "--all" in sys.argv
    dest = args[0] if args else os.path.expanduser("~/ocr-models/ARletta/models")
    os.makedirs(dest, exist_ok=True)

    print(f"zip-index lezen ({URL}) ...")
    with zipfile.ZipFile(HttpFile(URL)) as zf:
        members = [n for n in zf.namelist() if n.endswith(".mlmodel")]
        if not take_all:
            members = [n for n in members if os.path.basename(n) in WANTED]
        if not members:
            raise SystemExit("geen passende .mlmodel-bestanden gevonden in de zip")

        for name in members:
            target = os.path.join(dest, os.path.basename(name))
            if os.path.exists(target) and os.path.getsize(target) == zf.getinfo(name).file_size:
                print(f"  skip   {os.path.basename(name)} (al aanwezig)")
                continue
            print(f"  ophalen {os.path.basename(name)} "
                  f"({zf.getinfo(name).file_size / 1e6:.1f} MB)")
            with zf.open(name) as src, open(target, "wb") as dst:
                while chunk := src.read(1 << 20):
                    dst.write(chunk)
            print(f"  ok     {target}")


if __name__ == "__main__":
    main()
