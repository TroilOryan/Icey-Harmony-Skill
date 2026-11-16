# Windows DevEco native 交叉编译坑（CMake / Rust / bindgen）

> 适用场景：鸿蒙工程的 native 层（CMake + NDK 风格工具链）在 **Windows 开发机**
> 上交叉编译，尤其涉及 **Rust（cargo → rustc → bindgen）** 与预编译 C 库。
> macOS / 鸿蒙沙箱路径无空格、工具链自带 coreutils，这些坑只在 Windows 上暴露。
> 触发词：`fatal error: 'stddef.h' file not found`、`Unable to find libclang`、
> `multiple input filenames provided`、`CRYPT_E_REVOCATION_OFFLINE`、
> `Not an int attribute`、`command not found`（bash 里 grep/awk 缺失）。

## 铁律

1. **路径含空格（`C:/Program Files/...`）是 Windows 上大多数构建炸点的根因。**
   三条传递路径各自有不同的引号语义，逐条核对：
   - `RUSTFLAGS` / `BINDGEN_EXTRA_CLANG_ARGS`：按 **shell 规则空格分词**
     （bindgen 用 shell-words，支持单/双引号；cargo 的 RUSTFLAGS 无引号支持）。
     含空格路径要么用 `CARGO_ENCODED_RUSTFLAGS`（ASCII `0x1F` 分隔的编码形式），
     要么保证路径本身无空格（`mklink /J <无空格路径> "<真实 SDK 路径>"` 建
     junction，再经 `DEVECO_SDK_HOME` / `OHOS_SDK_HOME` 喂给探测脚本）。
   - **环境变量的值不做 MSYS 路径转换**：cc-rs 把 `CFLAGS_<target>` 的值原样拼进
     clang 命令行，MSYS 的 `/c/...` 路径原生 clang 不认识 → 统一用 Windows 风格
     `C:/...` 正斜杠。而 **shell 里作为 argv 的路径**会被 MSYS 自动转换，两种场景
     别混（同一个路径,走 argv 能成功、走 env 会炸,是正常现象不是玄学）。
   - CMake `add_custom_command`：`VERBATIM` + `cmake -E env NAME=value` 单参数
     传递，环境变量值整体不受分词影响——**优先把 env 注入逻辑写进 CMakeLists
     （从 `CMAKE_<lang>_COMPILER` 推导工具目录），让 IDE/hvigor 构建自洽，
     而不是要求开发者手工 set 环境变量**。
2. **bindgen 双件套**：DevEco/IDE 启动的构建没有 shell PATH，`libclang.dll`
   找不到 → 注入 `LIBCLANG_PATH=<SDK>/native/llvm/bin`；找到后 builtin 头推断
   仍可能失败（`'stddef.h' file not found`）→ 注入
   `BINDGEN_EXTRA_CLANG_ARGS="-I '<llvm>/lib/clang/<版本>/include' -I '<sysroot>/usr/include' ..."`
   （版本目录用 `file(GLOB .../lib/clang/*/include)` 探测，路径加单引号）。
   两个变量**缺一不可**，只修第一个会走到第二个错。
3. **下载统一 `curl --ssl-no-revoke`**：Windows 系统 curl（schannel TLS）在受限
   网络下做证书吊销检查必炸 `CRYPT_E_REVOCATION_OFFLINE (0x80092013)`，与目标
   站点可达性无关。
4. **PowerShell 直调 `Git\usr\bin\bash.exe` 不走 Git profile**：PATH 里没有
   usr/bin，`grep/awk/sha256sum/head/nm` 全缺。bash 脚本开头自己补：
   `export PATH="/c/Program Files/Git/usr/bin:$PATH"`。
5. **工具链版本代差是"验证器坏"不是"产物坏"**：rustc 新版（LLVM 21）产出的
   `.o`，SDK 老版 llvm-nm（15.x）读不了（`Not an int attribute` / `no symbols`）。
   链接器读 ELF 符号表不受影响。等价验证：`llvm-readelf -s libX.a | grep <symbol>`。
6. **bash 长命令从 PowerShell 内联传递必炸引号**（`$()`、嵌套引号被吃）→
   一律落 `.sh` 文件再 `bash file.sh`；PowerShell 侧长 Python 同理落 `.py`。

## 从零恢复 .gitignore 忽略的本地产物（clone 后编不过的第一原因）

native 依赖（预编译 .a、vendored crate、子模块源码树）通常不入库。换设备后
**先跑项目内的一键恢复脚本**（本库模板原则：每步带 sha 校验、幂等、可
`--force` 重建），再构建。判定"哪块缺"的信号：

| 构建报错 | 缺什么 |
| --- | --- |
| `RustDesk: missing .../libopus.a` 类 CMake message | 预编译 C 库未构建 |
| `failed to load source for dependency <crate>` | vendored path 依赖目录缺失 |
| `fatal error: 'freerdp/freerdp.h' file not found` 类 | 子模块/源码树未 checkout（子模块 URL 已 404 时从公开镜像分支 tarball 恢复，并补 `.git/info/exclude`） |
| `Unable to find libclang` / `'stddef.h' not found` | 见铁律 2 |
| `multiple input filenames provided ('-' and 'Files\...')` | 见铁律 1（明文 RUSTFLAGS） |

## 验收口径

- 交付 = 构建通过 + 产物时间戳刷新（增量构建要警惕复用旧产物掩盖问题；
  修完构建链后**删掉产物从零构建一次**才算验证自洽）。
- 真机安装验证由设备侧执行。
