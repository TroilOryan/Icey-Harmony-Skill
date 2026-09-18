# 内置模板清单（TEMPLATE_MANIFEST）

> 本目录 `assets/template/` 是 **HarmonyAppTemplate 工程的完整副本**，随 Skill 一起走，
> 换机器/新环境无需再找外部工程 —— 这是本 Skill 的可移植性来源。

## 1. 包含内容（79 个文件 / 约 1.2MB）

```
assets/template/
├── .gitignore                      # 已排除 node_modules/oh_modules/build/.hvigor/.idea 等
├── README.md                       # 模板自身文档（铁律原文 122 条，SKILL.md 是其纲要）
├── build-profile.json5             # targetSdk 26 / compatibleSdkVersion 6.1.0(23)
├── hvigorfile.ts
├── oh-package.json5
├── hvigor/hvigor-config.json5
├── AppScope/
│   ├── app.json5                   # bundleName / versionCode / versionName
│   └── resources/base/media/       # background.png / foreground.png / layered_image.json
└── entry/
    ├── build-profile.json5         # apiType: stageMode
    ├── hvigorfile.ts
    ├── oh-package.json5
    └── src/main/
        ├── module.json5
        ├── ets/                    # 34 个 .ets（App / Ability / layout / pages / model / services / components）
        └── resources/
            ├── base/{element,media,profile}/
            └── rawfile/changelog.txt
```

## 2. 有意排除的内容

| 排除项 | 原因 | 如何恢复 |
|---|---|---|
| `entry/src/main/resources/rawfile/fonts/sficons_harmony.ttf`（约 9.5MB） | 可选：SFIcon 走 SVG 渲染，模板代码中**无任何引用**（已 grep 验证） | 需要 SF Symbols 原始字体时从原工程拷回并放同路径 |
| `.workbuddy/` | 本项目工作记忆，非模板资产 | 无需恢复 |
| `node_modules` / `oh_modules` / `build` / `.hvigor` | 构建产物与依赖，由 DevEco 打开后自动生成 | 无需恢复 |
| 签名材料（certificates/keys） | 安全红线：永不随模板分发 | 各机器自行配置 |

## 3. 使用方式（W1 新建项目）

```bash
# 模板根 = <skill>/assets/template
cp -r <skill>/assets/template <新工程目录>
# 然后按 SKILL.md 附录 C 修缺陷 → 改 bundleName → DevEco 打开 → 构建
```

## 4. ⚠️ 首次使用必读

内置副本**未修**模板的 4 个已知缺陷（详见 `SKILL.md` 附录 C）。其中 **D1 / D2 会导致编译失败**：

- D1：`SettingsManager.getInstance()` 在纯静态类上被调用（8 处）
- D2：`EntryAbility.ets` 使用了 `WindowHelper` 但未 import

**新建项目后第一件事就是按 SKILL.md 附录 C 修复这 4 处**，否则首次构建必然报错。
（副本刻意保持与源工程一致，便于后续双向同步；不擅自改源码。）

## 5. 同步约定

源工程（`E:\project\HarmonyAppTemplate`，路径可能变化）若有基建改动，
需回拷到本目录并更新 `SKILL.md` 的 version + changelog + 相关章节。
判定「是否需要回拷」的 5 个哨兵文件：

```
AppScope/app.json5
entry/src/main/ets/layout/Index.ets
entry/src/main/ets/model/SettingsManager.ets
entry/src/main/ets/model/ThemeManager.ets
entry/src/main/ets/entryAbility/EntryAbility.ets
```
