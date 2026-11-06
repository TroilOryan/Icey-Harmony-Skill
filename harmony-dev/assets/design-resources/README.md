# 华为设计资源库（design-resources）

> **来源**：华为开发者联盟「设计资源」页 <https://developer.huawei.com/consumer/cn/design/resource/>
> **抓取**：2026-11-01（资源页 CMS 内嵌清单解析 + CDN 直链批量下载）
> **口径**：**只收成品**（PNG / SVG / TTF），**不收可编辑源文件**（PSD / Sketch / PIX / Figma）——用户定案。
> 用途：宣传图机框图底板、华为品牌合规图标（登录 / 分享 / 支付 / 应用市场）、官方字体。

## 一、mockups/（真机机框图，宣传图底板，20 图 / 44MB）

全部为透明底 PNG 机框图（多为 10000×10000 超清，直接当宣传图/商店截图底板用）：

Mate 80（3 张：标准 / Pro / Pro Max）、Mate 80 TV、Mate X6（展开态）、Mate XT（三折展开）、
Mate70 Pro、MatePad Pro、Matebook Fold（3 折叠角度）、Matebook X Pro、Pura 90（3 型号）、
Pura X（展开 / 折叠）、Pura70 Pro、Watch 5、Watch Fit 3。

## 二、brand-icons/（华为品牌与合规图标，PNG+SVG，81 文件 / 2.6MB）

| 包 | 内容 | 典型用途 |
| --- | --- | --- |
| `华为品牌资源/` | HarmonyOS LOGO（type1~3 × @1x/2x/3x × 反白等变体） | 关于页 / 推广物料 |
| `使用华为账号登录/` | 华为账号登录按钮 logo（huaweilogo1/2，PNG+SVG） | 华为账号登录按钮（合规要求用官方图形） |
| `华为分享图标/` | 分享图标（应用图标 / 粗 / 细，hdpi~xxxhdpi 多密度） | 华为分享 / 碰一碰入口 |
| `华为支付图标/` | 华为支付图标（@1x~@4x + SVG） | 支付入口 |
| `华为应用市场图标/` | 应用市场图标（@1x~@4x + SVG） | 市场直达 / 友情应用页 |
| `元服务静默登录默认头像/` | 默认头像（PNG+SVG） | 元服务静默登录 UI |

## 三、fonts/（HarmonyOS Sans 官方字体，8 TTF + LICENSE，30.7MB）

`HarmonyOS_Sans(_Italic/_Condensed/_Condensed_Italic/_SC/_TC/_Naskh_Arabic/_Naskh_Arabic_UI).ttf`
——宣传图 / 海报排版用官方字体（系统 UI 默认即它，带包是为了宣传图制作时字体一致）。
许可以包内 `LICENSE-update.txt` 为准（华为官方字体许可）。

## 未收录清单（均为源文件或超限，附理由）

| 资源 | 未收原因 |
| --- | --- |
| 12 个设计组件包（手机/折叠屏/平板/电脑、穿戴、智慧屏、通知、实况窗、闪控球和闪控窗、服务卡片、播控中心、分享、启动页、碰一碰、靠近发现） | 只有 **Sketch / PIX** 格式 = 可编辑源文件（用户定案不收）。组件视觉规范请看官方页面预览 |
| HarmonyOS 应用图标包（93MB zip） | 内容**只有** `HarmonyOS AppIcon Design.pix + .sketch` 两个源文件，无成品 PNG |
| 各样机的 Photoshop（PSD）包 | 源文件 |
| 品牌类目的 Sketch,PIX 包 | 源文件（成品 PNG+SVG 已收） |
| `Mate X6_折叠态.png`（62MB / 10000²） | 单图 62MB，本机无图像工具链可缩（无 PIL/ffmpeg），克隆代价不值；展开态已收。要的话去来源页重新下载 |

## 再同步方法（CDN 直链有时效性，别抄旧链接）

资源清单**内嵌在页面壳的 base64 CMS JSON 里**，无需浏览器即可重新解析：

1. `curl` 抓 `https://developer.huawei.com/consumer/cn/design/resource/` 页面 HTML；
2. 取内联脚本里的 `atob("…")` base64 解码成 JSON；
3. 遍历 JSON 找 `cardTitle` + `Download` 节点：`href` = dbankcdn FileServer 直链、`text.value` = 格式标签（PNG / SVG, PNG / Sketch / PIX / Photoshop / 立即下载）；
4. 只下载成品格式标签的链接（本次脚本口径：`PNG`、`SVG, PNG`、`立即下载`，跳过 `HarmonyOS 应用图标`）。
5. ⚠️ zip 内中文文件名是 **GBK** 编码：解压时 `name.encode('cp437').decode('gbk')` 转码，并剔 `.DS_Store`。
