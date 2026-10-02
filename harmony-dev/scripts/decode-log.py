"""把 hvigor/DevEco 的 UTF-16 构建日志转成 UTF-8，便于 Read 工具读取。
用法：python decode-log.py <输入日志> [输出文件]
"""
import sys
import os

src = sys.argv[1]
dst = sys.argv[2] if len(sys.argv) > 2 else src + '.u8.txt'

data = open(src, 'rb').read()
if data[:2] in (b'\xff\xfe', b'\xfe\xff'):
    text = data.decode('utf-16', errors='replace')
else:
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        text = data.decode('gbk', errors='replace')

# 去掉 BOM 和 \r，方便阅读
text = text.lstrip('\ufeff').replace('\r\n', '\n').replace('\r', '\n')
open(dst, 'w', encoding='utf-8').write(text)
print('decoded %d bytes -> %s' % (len(data), dst))
