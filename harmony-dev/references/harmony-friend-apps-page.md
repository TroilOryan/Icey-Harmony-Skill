# 应用内「友情应用」页接入清单（2026-10-16，Icey-Reader 实测全流程）

> 适用场景：Icey 系（或任意同作者多应用）要在应用内做「我们制作的其他应用」推荐页，
> 每张卡 = 宣传横幅图 + 应用名 + 「点击查看>>」+ 一句话简介，整卡可点跳转。
> 参考实现：Icey-Reader `pages/subPages/FriendAppsPage.ets`（本册沉淀时的完整可用版）。

## 1. 版式（对齐成熟竞品友应用页，已真机复验）

```
[标题省略——不要"我们制作的其他应用"标题区，直接进卡片列表（用户定案）]

┌─────────────────────────┐
│   横幅宣传图 等比16:9 圆角12 │  ← 素材未提供 = 占位横幅（品牌底色+应用名）
└─────────────────────────┘
 应用名(17 Bold)    点击查看>>
 一句话简介(13 次级色)
└ 下一张卡 ┘
```

- 横幅 **等比 16:9**：`width('100%') + aspectRatio(16/9) + ImageFit.Contain`；
  圆角 12；**不要固定高度 + Cover**（会裁掉素材上下画面，真机复验实锤）；
- 「点击查看>>」= accent 色 13 号 Medium——它是**整卡点击**的入口文案（参考竞品语义）；
- **整卡 `onClick`**，不是只给按钮挂点击。

## 2. ⚠️ 卡片宽度铁律（溢出返工的根因，Icey-Reader 真机实锤）

**横向留白挂外层 `ListItem.padding({left:16,right:16})`；卡片自身 `width('100%')`。**

❌ 卡片 `width('100%')` + `margin({left:16,right:16})` ⇒ 总宽 = 100% + 32vp ⇒ **超出屏幕**。
（ArkUI `width` 是 border-box 语义：padding 在尺寸内层安全，margin 叠在外面必溢出。
`SettingsGroupCard` 头注释同一条铁律——写卡片组件前先看仓里同类组件。）

## 2.4 素材规格（2026-10-17 用户定案：后续素材都按这个给）

| 素材 | 规格 | 落点 |
|---|---|---|
| 横幅宣传图 | **16:9**（参考 1920×1080） | `resources/base/media/friend_*_banner.jpg`，`FRIEND_APPS` 的 `banner` 指向它 |
| 图标（备用） | 256×256 | `friend_*_icon.png`（当前版式未消费，留作日后小图标位） |
| 跳转 | 市场直达 `store://…?id=<bundle>` | `marketId` 字段（见 2.5） |

- ⚠️ **别提供竖图**：等比容器下竖图按宽度适配会撑得非常高（或 Contain 两侧大留白）；
- 实现口径：`aspectRatio(16/9)` 锁比例，高度不写死——任何屏宽下素材完整显示、零裁切；
- 占位横幅（素材未提供）同用等比容器：品牌底色 + 应用名大字 + "敬请期待"；
- **现有素材已入库** `assets/friend-apps/`（player 横幅 / player·星空下图标），
  新应用接入直接从这拷，别再向用户要已有的图。
- ⚠️ **入库前必须压缩**（2026-10-17 用户定案：「实际用不到那么大」）：
  · 横幅 → **720 宽 / JPEG q82**（卡片渲染宽约 320-360vp，720 已含 2x 屏裕量；
    实测 1920×1080/165KB → 720×405/30KB，缩 5.5 倍，观感无差）；
  · 图标 → **256×256** PNG（渲染位 84vp，256 已含 3x 裕量）；
  · 流程：用户给原图 → `PIL` LANCZOS 缩放 → 覆盖保存 → 同步本仓 + 技能 assets 两处。

### 2.4.1 应用名与官方简介（2026-10-17 用户给定，**抄这句，别自己写文案**）

| 应用 | 简介文案（`desc` 字段） |
|---|---|
| Icey Player | 简洁、精致且纯粹的本地音乐播放器 |
| 冰沙阅读 | 冰沙阅读，简洁而不失精致 |
| 星空下 | 找寻自己在哪一片星空 |

## 2.5 ⚠️ 用户定案（2026-10-16）：清单与跳转规则

- **「接友情应用」的固定含义**：把 **Icey Player / 冰沙阅读 / 星空下** 这三个里
  **除自己之外的全部接入**（做哪个应用就排除哪个）。后续要增加应用用户会再说。
- **全部走市场直达**（`store://appgallery.huawei.com/app/detail?id=<bundle>`）：
  不管上没上架都直接换 id 配上——**上没上架不用管**（"这几个应用是确认上了"只是告知
  优先级，不是接不接的判据）。bundle 名对照：
  `com.icey.player`（Icey Player）/ `com.icey.reader`(冰沙阅读) / `com.icey.stars`(星空下)。

## 3. 跳转通道（三类，按目标应用是否可直达选）

### 3.1 已上架 AppGallery ⇒ 市场详情页直达（首选）

```ets
const want: Want = {
  action: 'ohos.want.action.appdetail',
  uri: `store://appgallery.huawei.com/app/detail?id=${bundleName}`,
};
ctx.startAbility(want);
```
- ⚠️ id **不带 C 前缀**（旧兼容写法会跳错/空白页，player 2026-09-08 实测修正）；
- 真机实测通过：`com.icey.player`（270 评分 5.0 星详情页完整打开）、`com.icey.stars` 同理——
  **同一条通路换 id 即用**。
- 照抄实现：player `Index.onShareApp`。

### 3.2 未上架（自建仓库/暂存）⇒ 外跳浏览器

```ets
ctx.startAbility({ action: 'ohos.want.action.viewData', uri: 'https://github.com/...' });
```
- 只保证"拉起浏览器"，页面级导航不承诺。

### 3.3 华为主题商店等**内购资源**（不在应用市场）⇒ 只能走分享 https 链接

- ❌ `aa start -U 'theme://…'` / `hwt://…` / 注入 want 参数（`--ps hitopId xxx`）：
  **全部只落商店首页**（两轮真机实测，商店不消费外部 uri/参数——它的详情页路由
  `hitopId` 是内部跳转专用）；
- ✅ 唯一通路 = **应用详情页分享二维码里的 https 链接**，浏览器打开 → web 落地页 →
  H5 侧"在应用中打开"拉起商店详情页（App Linking，商店自己声明并消费）；
- 判据通用化：**第三方应用有没有页面级深链，`bm dump -n <bundle>` 看 skills 声明
  + 真机发一条 uri 验证**。不消费 ⇒ 只能走"分享链接/浏览器"路线。

## 4. 数据结构（直接抄）

```ets
class FriendApp {
  name: string;        // 显示名
  desc: string;        // 一句话简介
  marketId: string;    // 市场直达（空串 = 未上架走 webLink）—— 二选一
  webLink: string;     // 外跳浏览器链接
  banner: Resource | null;  // 横幅图；null = 占位横幅（品牌底色+应用名+敬请期待）
}
```
加新应用 = 加一条 + 拷一张横幅图进 `resources/base/media/`，页面自动渲染。

## 4.5 入口在设置分组里的顺序与图标（用户定案）

「友情应用」放「**关于**」的**前面一个**（浏览/推荐类入口先于"版本信息"这类收尾入口）。
 Icey-Reader 实际顺序：藏书库 → 阅读设置 → 界面 → 阅读统计 → **友情应用** → 关于。

入口行图标：**`sys.symbol.discover_fill`**（指南针，"探索/发现"语义），
色底沿用设置分组色表（reader 用 `#34C759` 绿）。
⚠️ 别用 `person_2`（那是"账号/双人"语义，与"发现其它应用"不符，用户已否）。
⚠️ `discover_fill` 已核 SDK 符号表存在（`compass_fill` 不存在，别用）。

## 5. ⚠️ 新子页接线清单（白屏返工根因——两处映射表必须同改）

`AppRouter` 加路由常量后，**漏掉任何一处都会白屏/静默不弹**：

| 注册点 | 作用 | 漏掉的后果 |
|---|---|---|
| `Index.navDestinationBuilder` 分支 | 全局栈（设置页等正常入口）路由名→组件 | **`load page failed: xxx`，页面空白**（最常见主因） |
| `SubPageRouterHost.dispatch` 分支 | 阅读页存活时的旁路分发 | 从阅读页入口进去空白 |
| `ROUTES_ABOVE_READER`（按需） | 需要盖在阅读页上的子页 | 入口在阅读页内时点击无效 |
| `main_pages.json`（仅 @Entry 路由页） | 真·路由页形态 | 404 |

排查指纹：hilog `AceNavigation: load page failed: <name>` ⇒ builder 缺分支。

## 6. 联调命令（真机验证跳转）

```bash
hdc shell bm dump -n <bundle>        # 查 ability 真名 + skills 声明（scheme/action/host）
hdc shell aa start -b <bundle> -a <ability> -U '<scheme>://<host>/<path>?k=v'   # 显式
hdc shell aa start -U '<uri>' -A <action>                                        # 隐式（action 必须与声明一致）
hdc shell aa start -b <bundle> -a <ability> --ps <key> <value>                   # want 参数注入
```
- 隐式失败 `10103101` = action 不匹配；`10104001` = ability 名错（先 dump 查真名）；
- "拉起成功但落首页" = 目标应用不消费 uri 参数 ⇒ 该应用无页面级深链，改走分享链接/浏览器。
