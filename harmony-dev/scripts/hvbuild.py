"""本地真编译 HarmonyOS 工程：python 直接驱动 DevEco 自带 hvigorw，捕获原始输出。

为什么需要它（2026-09-17 实测）：
  PowerShell 工具会把 hvigorw 的 stderr 包成 ErrorRecord，并按控制台宽度**折行**，
  重定向到文件后日志被切成 60 字符一段，告警的文件路径和行号全被截断，完全没法读。
  hvigor 日志又是 UTF-16 + ANSI 色码，Read 直接拒读。
  用 python subprocess 拿原始 bytes → 剥 ANSI → 落 UTF-8，一步干净。

用法：
  python hvbuild.py compile [工程根]     # default@CompileArkTS（约 20s，拿全部 ArkTS 错误/告警）
  python hvbuild.py hap     [工程根]     # assembleHap（顺带验证资源引用与签名）
  python hvbuild.py <任意task> [工程根]
  python hvbuild.py compile <工程根> --full   # 不过滤，写全量日志

输出：<工程根>/.workbuddy/scripts/_build.txt（过滤后）；--full 时写 _build_full.txt
  末尾会 print 一行摘要：exit=0 kept=36/421 > hvigor BUILD SUCCESSFUL in 20 s 282 ms

工程根省略时默认取当前工作目录。
"""
import os
import re
import subprocess
import sys

# 项目根通常没有 wrapper，要从 DevEco 安装目录拿。
# 解析顺序：① 环境变量 DEVECO_HVIGORW（显式指定）→ ② 常见安装位置自动探测。
# 换设备若装在非常规目录，设一个环境变量即可，无需改本文件：
#   PowerShell:  $env:DEVECO_HVIGORW = "D:\Apps\DevEco Studio\tools\hvigor\bin\hvigorw.bat"
HVIGORW_REL = r"tools\hvigor\bin\hvigorw.bat"
DEVECO_ROOTS = [
    r"C:\Program Files\Huawei\DevEco Studio",
    r"D:\Program Files\Huawei\DevEco Studio",
    os.path.join(os.path.expanduser("~"), "AppData", "Local", "Huawei", "DevEco Studio"),
]

ANSI = re.compile(r"\x1b\[[0-9;]*m")
FILTER = re.compile(r"ERROR|error:|BUILD |COMPILE RESULT|ArkTS:WARN|ERR_NO|FAILED", re.I)
TASK_ALIAS = {"compile": "default@CompileArkTS", "hap": "assembleHap"}


def find_hvigorw():
    env = os.environ.get("DEVECO_HVIGORW")
    if env and os.path.isfile(env):
        return env
    for root in DEVECO_ROOTS:
        p = os.path.join(root, HVIGORW_REL)
        if os.path.isfile(p):
            return p
    raise SystemExit(
        "找不到 hvigorw。请设环境变量 DEVECO_HVIGORW=<DevEco>/tools/hvigor/bin/hvigorw.bat，"
        "或把安装根目录加进 DEVECO_ROOTS")


def main():
    argv = [a for a in sys.argv[1:] if not a.startswith("--")]
    full = "--full" in sys.argv
    task = TASK_ALIAS.get(argv[0], argv[0]) if argv else "default@CompileArkTS"
    proj = os.path.abspath(argv[1]) if len(argv) > 1 else os.getcwd()

    out_dir = os.path.join(proj, ".workbuddy", "scripts")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "_build_full.txt" if full else "_build.txt")

    cmd = [find_hvigorw(), "--mode", "module",
           "-p", "product=default", "-p", "module=entry@default", "-p", "buildMode=debug",
           task, "--no-daemon"]
    p = subprocess.run(cmd, cwd=proj, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    raw = p.stdout or b""
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        text = raw.decode("utf-16", errors="replace")
    else:
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            text = raw.decode("gbk", errors="replace")

    text = ANSI.sub("", text).lstrip("\ufeff")
    all_lines = text.split("\n")
    keep = all_lines if full else [l.rstrip() for l in all_lines if FILTER.search(l)]

    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(keep))

    tail = [l.strip() for l in all_lines if "BUILD " in l]
    print("exit=%d  kept=%d/%d  %s  -> %s"
          % (p.returncode, len(keep), len(all_lines), tail[-1] if tail else "?", out))


if __name__ == "__main__":
    main()
