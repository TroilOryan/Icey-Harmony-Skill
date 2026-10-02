"""目录体检：统计各子目录大小 / 列出文件，输出 UTF-8（PS5.1 写文件会被 Read 当二进制，故一律用 python 落盘）

用法：
  python lsdir.py du   <dir> [输出文件]     # 每个直接子目录的递归大小
  python lsdir.py tree <dir> [输出文件] [最大深度]
  python lsdir.py find <dir> <子串> [输出文件]
"""
import os
import sys

def human(n):
    for u in ('B', 'KB', 'MB', 'GB'):
        if n < 1024 or u == 'GB':
            return '%.1f %s' % (n, u)
        n /= 1024.0

def du(root):
    rows = []
    for name in sorted(os.listdir(root)):
        p = os.path.join(root, name)
        if os.path.isdir(p):
            total = 0
            for dp, _dn, fn in os.walk(p):
                for f in fn:
                    try:
                        total += os.path.getsize(os.path.join(dp, f))
                    except OSError:
                        pass
            rows.append((name + '/', total))
        else:
            try:
                rows.append((name, os.path.getsize(p)))
            except OSError:
                pass
    out = []
    for name, size in sorted(rows, key=lambda r: -r[1]):
        out.append('%-40s %12s' % (name, human(size)))
    out.append('%-40s %12s' % ('TOTAL', human(sum(r[1] for r in rows))))
    return out

def tree(root, maxdepth):
    out = []
    base_depth = root.rstrip('/\\').count(os.sep)
    for dp, dn, fn in os.walk(root):
        depth = dp.count(os.sep) - base_depth
        if depth > maxdepth:
            dn[:] = []
            continue
        out.append('%s%s/' % ('  ' * depth, os.path.basename(dp) or dp))
        if depth < maxdepth:
            for f in sorted(fn):
                out.append('%s%s' % ('  ' * (depth + 1), f))
    return out

def find(root, needle):
    out = []
    for dp, _dn, fn in os.walk(root):
        for f in fn:
            if needle in f:
                out.append(os.path.join(dp, f))
        if len(out) > 500:
            break
    return out

mode = sys.argv[1]
root = sys.argv[2]
dst = sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.environ.get('TEMP', '.'), 'lsdir.txt')

if mode == 'du':
    lines = du(root)
elif mode == 'tree':
    lines = tree(root, int(sys.argv[4]) if len(sys.argv) > 4 else 2)
elif mode == 'find':
    lines = find(root, sys.argv[3])
    dst = sys.argv[4] if len(sys.argv) > 4 else os.path.join(os.environ.get('TEMP', '.'), 'lsdir.txt')
else:
    lines = ['unknown mode']

with open(dst, 'w', encoding='utf-8') as fh:
    fh.write('\n'.join(lines) + '\n')
print('wrote %d lines to %s' % (len(lines), dst))
