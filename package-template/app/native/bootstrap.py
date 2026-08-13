#!/usr/bin/env python3
import argparse
import os
import shutil
import stat
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path


def log(msg: str):
    print(f"[TaoSync fnOS] {msg}", flush=True)


def download(url: str, dst: Path):
    req = urllib.request.Request(url, headers={"User-Agent": "TaoSync-fnOS-native-builder/1.0"})
    with urllib.request.urlopen(req, timeout=120) as r, open(dst, "wb") as f:
        total = r.headers.get("Content-Length", "?")
        log(f"下载 {url} ({total} bytes)")
        shutil.copyfileobj(r, f, length=1024 * 1024)


def install(runtime: Path, data: Path, version: str):
    runtime.mkdir(parents=True, exist_ok=True)
    data.mkdir(parents=True, exist_ok=True)
    current = runtime / "VERSION"
    binary = runtime / "taoSync"
    if binary.is_file() and current.is_file() and current.read_text(encoding="utf-8").strip() == version:
        binary.chmod(binary.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
        log(f"TaoSync {version} 已存在，跳过重新下载")
    else:
        asset = f"taoSync-v{version}-linux-StaticX-amd64.zip"
        url = f"https://github.com/dr34m-cn/taosync/releases/download/v{version}/{asset}"
        with tempfile.TemporaryDirectory(prefix="taosync-fnos-") as td:
            td = Path(td)
            archive = td / asset
            download(url, archive)
            if not zipfile.is_zipfile(archive):
                raise RuntimeError("下载内容不是有效 ZIP 文件，可能 GitHub 访问被代理/拦截")
            with zipfile.ZipFile(archive) as zf:
                candidates = [n for n in zf.namelist() if Path(n).name == "taoSync" and not n.endswith("/")]
                if not candidates:
                    raise RuntimeError("官方 StaticX 压缩包中没有找到 taoSync 可执行文件")
                member = candidates[0]
                extracted = td / "taoSync"
                with zf.open(member) as src, open(extracted, "wb") as dst:
                    shutil.copyfileobj(src, dst)
            extracted.chmod(0o755)
            newbin = runtime / "taoSync.new"
            shutil.copy2(extracted, newbin)
            newbin.chmod(0o755)
            os.replace(newbin, binary)
            current.write_text(version + "\n", encoding="utf-8")
            log(f"已安装 TaoSync {version} StaticX amd64")

    link = runtime / "data"
    if link.is_symlink():
        if Path(os.readlink(link)) != data:
            link.unlink()
            link.symlink_to(data, target_is_directory=True)
    elif link.exists():
        if link.is_dir() and not any(link.iterdir()):
            link.rmdir()
            link.symlink_to(data, target_is_directory=True)
        else:
            raise RuntimeError(f"{link} 已存在且不是可替换的空目录/软链接")
    else:
        link.symlink_to(data, target_is_directory=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runtime", required=True)
    ap.add_argument("--data", required=True)
    ap.add_argument("--version", required=True)
    args = ap.parse_args()
    try:
        install(Path(args.runtime), Path(args.data), args.version)
    except Exception as e:
        log(f"ERROR: {type(e).__name__}: {e}")
        raise
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
