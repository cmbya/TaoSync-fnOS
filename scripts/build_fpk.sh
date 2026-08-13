#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  echo "用法: $0 v0.4.0" >&2
  exit 2
fi
if [[ "$TAG" != v* ]]; then
  TAG="v${TAG}"
fi
VERSION="${TAG#v}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACK_REV="$(tr -d '[:space:]' < "$ROOT/PACK_REV")"
[[ -n "$PACK_REV" ]] || { echo "PACK_REV 为空" >&2; exit 2; }

WORK="$ROOT/.build"
PKG="$WORK/package"
DIST="$ROOT/dist"
rm -rf "$WORK" "$DIST"
mkdir -p "$WORK" "$DIST"
cp -a "$ROOT/package-template" "$PKG"

# 1) 更新 fnOS manifest 版本与说明。
python3 - "$PKG/manifest" "$VERSION" "$PACK_REV" "$TAG" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
version, pack_rev, tag = sys.argv[2:]
lines = p.read_text(encoding='utf-8').splitlines()
replace = {
    'version': f'{version}-{pack_rev}',
    'desc': f'TaoSync {version} x86 原生飞牛版。直接运行官方 Linux StaticX amd64，不使用 Docker；支持授权目录访问及多种本地/远程存储同步。',
    'changelog': f'自动跟随上游 TaoSync {tag} 构建；fnOS 原生 x86 封装 {pack_rev}。覆盖升级保留数据库、配置和任务数据。',
    'checksum': '',
}
out=[]; seen=set()
for line in lines:
    key=line.split('=',1)[0] if '=' in line else ''
    if key in replace:
        out.append(f'{key}={replace[key]}'); seen.add(key)
    else:
        out.append(line)
for k,v in replace.items():
    if k not in seen:
        out.append(f'{k}={v}')
p.write_text('\n'.join(out)+'\n', encoding='utf-8')
PY

# 2) 更新安装向导里显示的上游版本文字（只影响提示，不影响运行逻辑）。
python3 - "$PKG/wizard/install" "$TAG" <<'PY'
from pathlib import Path
import json, re, sys
p=Path(sys.argv[1]); tag=sys.argv[2]
data=json.loads(p.read_text(encoding='utf-8'))
for step in data:
    for item in step.get('items', []):
        text=item.get('helpText')
        if isinstance(text, str) and 'GitHub Release' in text:
            text=re.sub(r'v\d+(?:\.\d+)+(?:[-+][0-9A-Za-z.-]+)?', tag, text)
            item['helpText']=text
p.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
PY

# 3) app/ -> app.tgz，并写入 MD5 checksum。
tar -czf "$PKG/app.tgz" -C "$PKG/app" .
APP_MD5="$(md5sum "$PKG/app.tgz" | awk '{print $1}')"
python3 - "$PKG/manifest" "$APP_MD5" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); md5=sys.argv[2]
s=p.read_text(encoding='utf-8')
s,n=re.subn(r'^checksum=.*$', f'checksum={md5}', s, flags=re.M)
if n != 1:
    raise SystemExit('manifest checksum 字段异常')
p.write_text(s, encoding='utf-8')
PY
rm -rf "$PKG/app"

# 4) 静态自检。
for f in "$PKG"/cmd/*; do bash -n "$f"; done
python3 -m py_compile "$ROOT/package-template/app/native/bootstrap.py"
python3 - <<PY
import json
for p in [r"$PKG/config/privilege", r"$PKG/config/resource", r"$PKG/wizard/config", r"$PKG/wizard/install"]:
    json.load(open(p, encoding='utf-8'))
PY
grep -q '^platform=x86$' "$PKG/manifest"
grep -q '^service_port=8023$' "$PKG/manifest"
grep -q "^version=${VERSION}-${PACK_REV}$" "$PKG/manifest"
grep -q "^checksum=${APP_MD5}$" "$PKG/manifest"

# 5) 生成 FPK。
OUT="$DIST/TaoSync_${VERSION}_${PACK_REV}_fnOS_x86.fpk"
tar -czf "$OUT" -C "$PKG" .

# 6) 解包复核 app.tgz MD5 与 manifest.checksum。
VERIFY="$WORK/verify"
mkdir -p "$VERIFY"
tar -xzf "$OUT" -C "$VERIFY"
EXPECTED="$(awk -F= '$1=="checksum"{print $2}' "$VERIFY/manifest")"
ACTUAL="$(md5sum "$VERIFY/app.tgz" | awk '{print $1}')"
[[ "$EXPECTED" == "$ACTUAL" ]] || { echo "checksum 校验失败" >&2; exit 1; }
gzip -t "$OUT"
sha256sum "$OUT" | tee "$DIST/SHA256SUMS.txt"

echo
printf '构建成功: %s\n' "$OUT"
