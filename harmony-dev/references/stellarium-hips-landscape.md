> **分册：`stellarium-hips-landscape`** ｜ 原独立技能 `stellarium-hips-landscape`，2026-10-03 合并进 `harmony-dev`。
> 触发场景见入口 `SKILL.md` 的路由表。

# Stellarium HiPS landscape → 等距圆柱烘焙

## 一、为什么离线烘焙（不要运行时读瓦片）

上游 landscape 是 **HiPS**：`assets/data/landscapes/<name>/Norder{0,1,2}/Dir0/Npix*.webp`，
每个瓦片是 HEALPix **等面积图**里一个基像素的方格（gnomonic/切平面投影），天空处**透明**。
运行时直读要管 12/48/192 张纹理 + 每帧 LOD 选瓦片 + GLSL 里做 HEALPix 反算。

**烘焙成一张等距圆柱全景**（`u = az/360`、`v = (altTop−alt)/(altTop−altBottom)`）后，
运行时只需一次 `texture(uLTex, vec2(az/360, v))`：零 HiPS 数学、零瓦片管理，
而且**离线可视觉验证**（产出的图能直接打开看，还能出"真机首屏长什么样"的预览）。

## 二、上游几何（verbatim，stellarium-web-engine `src/algos/healpix.c`）

```c
static const int FACES[12][2] = {{1,0},{3,0},{5,0},{7,0},
                                 {0,-1},{2,-1},{4,-1},{6,-1},
                                 {1,-2},{3,-2},{5,-2},{7,-2}};
// 瓦片 UV(0..1)² → 等面积图 (x,y)：  A = π/(4·nside)
x0 = (FACES[face][0] + (ix - iy)/nside) * π/4;
y0 = (FACES[face][1] + (ix + iy)/nside) * π/4;
x  = x0 + A*(u - v);   y  = y0 + A*(u + v);

static void healpix_xy2_z_phi(const double xy[2], double *z, double *phi) {
    if (fabs(y) > M_PI/4) {        // 极区
        sigma = 2 - fabs(y*4)/M_PI;
        *z = (y>0?1:-1) * (1 - sigma*sigma/3);
        xc = -M_PI + (2*floor((x+M_PI)*4/(2*M_PI)) + 1) * M_PI/4;
        *phi = sigma ? (xc + (x - xc)/sigma) : x;
    } else {                       // 赤道区
        *phi = x;  *z = y * 8/(M_PI*3);
    }
}
```
`ang2pix_nest_z_phi(nside, z, phi)` = 方向 → 嵌套像素号（选哪张瓦片）；
`healpix_nest2xyf` = 像素号 → (ix, iy, face)（低 2k 位解交织）。

世界系：HiPS `hips_frame = observed` ⇒ `vec = (E, N, U)`、`z = sin(alt)`、
`φ = atan2(N, E)`；**方位 az 北起顺时针 ⇒ φ = π/2 − az**。

## 三、两个必踩的坑（都是我们真踩过的）

1. **分支判据是 `|y| > π/4`，不是 `|z| > 2/3`。** 两者在数值上相关（y=π/4 ⟺ z=2/3），
   但反算时必须按 y 判；`y` 由 z 解析求得（赤道 `y = z·3π/8`、极区 `y = ±(2−σ)π/4`，σ=√(3(1−|z|))）。
2. **等面积图的 x 是周期 2π 的环绕坐标。** 上游 `healpix_xy2_z_phi` 把 x 归到 [−π,π]，
   而瓦片公式用的是**不缠绕的 x0**（可达 2π）。**反算必须逐瓦片**：
   `phiw = x0 + wrap180(φ − x0)`，极区再用**该面的扇区中心** `xc = FACES[face][0]·π/4`：
   `x = xc + (phiw − xc)·σ`。按 [−π,π] 统一折算只有 **17%** 的方向能落对瓦片（现象：烘焙图大片空白）。

## 四、证明法（装机前，别靠"看起来对"）

- **往返验证**（最硬）：给方向 `(z, φ)` → 用你的公式反算 `(u, v)` → 再用**上游正向**
  `healpix_xy2_z_phi` 变回 `(z', φ')`，要求逐点相等。32400 个方向（alt 步长 1°、az 步长 2°）
  应得 **一致率 100%、误差 ~1e-16**（含极区样本）。
- **离线出预览**：按运行时**同款**片元数学（像素 → 射线 → (az, alt) → 采样全景）渲染一张
  手机分辨率的图，看三件事：① 照片里的地平线是否正好落在 `alt = 0` 那一行；
  ② 天空侧 alpha 是否真透明（露得出底层星空）；③ 绕一圈有没有接缝。
- **天底那圈"扇面/风车"花纹**：多半是**源瓦片自带的假地板**（4 个极区面凑成），
  与上游同款 —— 先做完往返验证再下结论，别急着改自己的映射。

## 五、落地要点（HarmonyOS/ArkTS 实测）

- 资源放 `entry/src/main/resources/rawfile/landscapes/<name>.webp`（2048×740 RGBA ≈ 50~430 KB/张，
  6 张 ≈ 1.5 MB）。解码走
  `getRawFileContentSync → image.createImageSource → createPixelMapSync(RGBA_8888)
  → readPixelsToBufferSync → 原生 glTexImage2D`；`GL_REPEAT` 给 S（方位环绕）、
  `CLAMP_TO_EDGE` 给 T，并 `glGenerateMipmap`。
- **绘制顺序**：地景/大气在**最底层**（作为背景），照片（含树影）**最后画** —— 这样地平线以上的
  树影能挡住恒星；同一张照片再按一个"地面"开关门控（关了就连照片一起收）。
- 文件编码：源瓦片只到 order0 的两套（如 ocean 8 张、garching 12 张）**是源数据如此**，
  先 `ls` 数一遍再怀疑自己的读取逻辑。

## 六、可复用脚本（Icey-Stars 仓库 `.workbuddy/scripts/`）

| 脚本 | 作用 |
|---|---|
| `bake_landscape.py` | 主烘焙（`--all --out <rawfile 目录>`；`--width/--alt-top/--alt-bottom/--ss`） |
| `check_bake_roundtrip.py` | 上游正向函数往返验证（证明映射等价） |
| `render_lsp_preview.py` | 按运行时片元同款数学出手机尺寸预览 |
| `tile_orientation_check.py` | 瓦片朝向自检（确认"不透明像素 = 地平线以下"） |
