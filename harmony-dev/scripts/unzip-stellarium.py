"""解压 stellarium-master.zip（桌面版完整源码，含 skycultures / 星表 / 着色器等资源）。

用法（换设备只需给参数或设环境变量，不必改本文件）：
  python unzip-stellarium.py <zip路径> <解压目标目录> [日志路径]
  或设环境变量 STELLARIUM_ZIP / STELLARIUM_DEST，然后 python unzip-stellarium.py

支持断点续跑：已存在且大小一致的文件跳过。
"""
import os
import sys
import time
import zipfile

# 缺省值仅作示例；实际请用命令行参数或环境变量覆盖
ZIP = os.environ.get("STELLARIUM_ZIP", "")
DEST = os.environ.get("STELLARIUM_DEST", "")
LOG = os.environ.get("STELLARIUM_LOG", "")


def main() -> int:
    global ZIP, DEST, LOG
    argv = sys.argv[1:]
    if len(argv) >= 2:
        ZIP, DEST = argv[0], argv[1]
    if len(argv) >= 3:
        LOG = argv[2]
    if not LOG:
        LOG = os.path.join(DEST or ".", "_unzip.txt")
    if not ZIP or not DEST:
        print("usage: python unzip-stellarium.py <zip> <dest> [log]\n"
              "   or: set STELLARIUM_ZIP / STELLARIUM_DEST env vars")
        return 2
    os.makedirs(DEST, exist_ok=True)
    if not os.path.isfile(ZIP):
        open(LOG, "w", encoding="utf-8").write("zip missing: " + ZIP)
        return 1
    out = []
    zf = zipfile.ZipFile(ZIP)
    names = zf.namelist()
    out.append("entries: %d" % len(names))
    t0 = time.time()
    done = skip = 0
    errs = []
    for i, n in enumerate(names):
        if n.endswith("/"):
            continue
        target = os.path.join(DEST, n.replace("/", os.sep))
        try:
            info = zf.getinfo(n)
            if os.path.isfile(target) and os.path.getsize(target) == info.file_size:
                skip += 1
                continue
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with zf.open(n) as src, open(target, "wb") as dst:
                dst.write(src.read())
            done += 1
        except Exception as e:  # noqa: BLE001
            errs.append("%s -> %s" % (n, e))
        if (i + 1) % 500 == 0:
            out.append("  progress %d/%d  written=%d skipped=%d  %.0fs"
                       % (i + 1, len(names), done, skip, time.time() - t0))
            open(LOG, "w", encoding="utf-8").write("\n".join(out))
    out.append("DONE written=%d skipped=%d errors=%d  %.1fs" % (done, skip, len(errs), time.time() - t0))
    out += ["ERR " + e for e in errs[:40]]
    # 顶层结构快照
    root = os.path.join(DEST, "stellarium-master")
    if os.path.isdir(root):
        out.append("--- stellarium-master 顶层 ---")
        for n in sorted(os.listdir(root)):
            p = os.path.join(root, n)
            out.append(("DIR  " if os.path.isdir(p) else "FILE ") + n)
        for sub in ["skycultures", "data", "nebulae", "stars"]:
            p = os.path.join(root, sub)
            if os.path.isdir(p):
                out.append("--- %s (%d 项) ---" % (sub, len(os.listdir(p))))
                out.append("    " + ", ".join(sorted(os.listdir(p))[:40]))
    open(LOG, "w", encoding="utf-8").write("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
