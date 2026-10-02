"""把任意编码的文本文件规整为 UTF-8 输出（规避 PS5.1 写文件被 Read 当二进制的问题）。

用法：python show.py <文件> [起始行] [行数] [输出文件]
不给输出文件则打印到 stdout（本机 PS 工具不回显 stdout，一般请给输出文件）
"""
import sys

src = sys.argv[1]
start = int(sys.argv[2]) if len(sys.argv) > 2 else 1
count = int(sys.argv[3]) if len(sys.argv) > 3 else 100
dst = sys.argv[4] if len(sys.argv) > 4 else None

data = open(src, 'rb').read()
text = None
for enc in ('utf-8-sig', 'utf-16', 'gbk'):
    try:
        text = data.decode(enc)
        break
    except UnicodeDecodeError:
        continue
if text is None:
    text = data.decode('utf-8', errors='replace')

lines = text.replace('\r\n', '\n').replace('\r', '\n').split('\n')
selected = lines[start - 1:start - 1 + count]
# 去掉 ANSI 转义，日志更干净
import re
ansi = re.compile(r'\x1b\[[0-9;]*m')
out = ['%4d| %s' % (i, ansi.sub('', line)) for i, line in enumerate(selected, start)]
out.append('--- total %d lines ---' % len(lines))

body = '\n'.join(out) + '\n'
if dst:
    open(dst, 'w', encoding='utf-8').write(body)
    print('wrote %d lines to %s' % (len(out), dst))
else:
    sys.stdout.write(body)

