/// 沉浸光感材质（Immersive Material）统一出口
///
/// 依赖：HarmonyOS API 26+ 的 `@ohos.arkui.uiMaterial`（经 `@kit.ArkUI` 导出）。
/// 应用级前置条件：`entry/src/main/module.json5` 的 metadata
///   `ohos.arkui.UIMaterial.state = "enable"`（改动后必须重新构建安装才生效）。
///
/// ⚠️ 四条来自官方《沉浸光感常见问题》的硬规则（每条都踩过）：
///   ① 材质的视觉层级位于 backgroundColor / backgroundBlurStyle **之下**
///      ⇒ 承载层必须显式 `Color.Transparent`，任何不透明底色都会把材质盖住；
///   ② `systemMaterial` 要放在其他样式属性**之后**设置
///      ⇒ 一律用 `.attributeModifier()` 挂在属性链**最末**，不要写在中途；
///   ③ 材质**不采样同一 Stack 里的兄弟节点**（采样的是组件背后的窗口内容）
///      ⇒ 内容画在材质之下会完全看不见，只能画在材质之上；
///   ④ 材质不可用（API<26 / 应用开关关 / 系统总开关关）时必须**降级为毛玻璃**，
///      否则卡片变成一块死板色块。
///
/// ⚠️ 另外两条工程约束：
///   · 材质**必须惰性构造**：`export const X = uiMaterial.ImmersiveStyle.THIN` 这种模块级求值
///     会在模块加载期就解引用 API 26 才有的接口，抛出的异常在任何 try/catch 之外，
///     直接让模块加载失败 → 低版本设备**启动即闪退**。故一律包在函数里、取用时才求值。
///   · 构造失败**返回 null**（不要用 `Material.empty` 把失败伪装成静默失效），
///     让调用方明确走降级路径。
import { uiMaterial } from '@kit.ArkUI';
import { AppLogger } from './AppLogger';

const TAG = 'SystemMaterial';

/// 应用内「强制光感」开关的 AppStorage 键（设置页拨动，MaterialCardLayer 读取）
export const KEY_FORCE_MATERIAL = 'settings_forceMaterial';

// ===== 惰性构造（切勿改成模块级常量）=====

/// 材质档位（函数内求值——模块级会闪退）
function materialStyle(): uiMaterial.ImmersiveStyle {
  return uiMaterial.ImmersiveStyle.THIN;
}

/// 静态材质缓存（无流光）
let staticCache: uiMaterial.Material | null = null;
let staticShadowCache: uiMaterial.Material | null = null;
/// 可交互材质按**流光颜色**缓存（颜色随主题色变，一个固定变量装不下）
const interactiveCache: Map<string, uiMaterial.Material> = new Map<string, uiMaterial.Material>();

/// 平台能力与系统总开关（两者的值在运行期不变，只判一次）
let supportChecked: boolean = false;
let supported: boolean = false;
let systemStateDisable: boolean = false;

/// 平台是否支持沉浸光感（API ≥ 26 且系统实现可用）
export function isImmersiveMaterialSupported(): boolean {
  if (!supportChecked) {
    supportChecked = true;
    try {
      supported = uiMaterial.isImmersiveMaterialSupported();
      systemStateDisable = uiMaterial.getMaterialInfo().state === uiMaterial.MaterialState.DISABLE;
    } catch (e) {
      // API < 26 时模块/接口不存在 → 静默降级
      supported = false;
      systemStateDisable = true;
      AppLogger.info(TAG, `沉浸光感不可用，走降级：${JSON.stringify(e)}`);
    }
  }
  return supported && !systemStateDisable;
}

/// 应用内开关是否打开「强制光感」
export function forceMaterialEnabled(): boolean {
  return (AppStorage.get<boolean>(KEY_FORCE_MATERIAL) ?? true) === true;
}

/// 材质最终是否生效（应用开关开 + 平台支持 + 系统未禁用）
///
/// ⚠️ `forceOn` 必须由**调用方把订阅值传进来**（组件里用 @StorageLink 持有开关值），
/// 不要在函数内部直接读 AppStorage —— ArkUI 的局部更新按表达式登记依赖，
/// 函数内读到的值登记不上，拨开关时已画出的卡片不会重新求值，材质会停在旧状态。
export function materialActive(forceOn: boolean): boolean {
  return forceOn && isImmersiveMaterialSupported();
}

/// 取材质实例；不可用时返回 null（调用方走降级）
/// @param interactive 是否需要按压流光（可交互材质）
/// @param withShadow  是否让材质自带投影（小尺寸芯片建议 false）
/// @param lightColor  流光颜色，空串 = 系统默认白光
export function getImmersiveMaterial(interactive: boolean, withShadow: boolean,
                                     lightColor: string): uiMaterial.Material | null {
  try {
    if (!isImmersiveMaterialSupported()) return null;
    if (interactive) {
      const cached = interactiveCache.get(lightColor);
      if (cached !== undefined) return cached;
      const opts: uiMaterial.ImmersiveOptions = {
        style: materialStyle(),
        interactive: true,
        applyShadow: withShadow,
      };
      // ⚠️ lightColor 为空时**不要**传 lightEffect：`interactive: true` 配空 lightEffect 对象
      //    实测会让材质完全不渲染。省略该字段即可。
      if (lightColor.length > 0) {
        const le: uiMaterial.LightEffectOptions = { color: lightColor };
        opts.lightEffect = le;
      }
      const m = new uiMaterial.ImmersiveMaterial(opts);
      interactiveCache.set(lightColor, m);
      return m;
    }
    // 静态材质：带阴影 / 不带阴影各缓存一档
    // （共用一档会出现「关掉阴影的那档把带阴影的覆盖了」）
    if (withShadow) {
      if (staticShadowCache === null) {
        const o: uiMaterial.ImmersiveOptions = { style: materialStyle(), applyShadow: true };
        staticShadowCache = new uiMaterial.ImmersiveMaterial(o);
      }
      return staticShadowCache;
    }
    if (staticCache === null) {
      const o: uiMaterial.ImmersiveOptions = { style: materialStyle(), applyShadow: false };
      staticCache = new uiMaterial.ImmersiveMaterial(o);
    }
    return staticCache;
  } catch (e) {
    AppLogger.error(TAG, `材质构造失败，走降级：${JSON.stringify(e)}`);
    return null;
  }
}

/// 给承载层下发材质；不可用时降级为毛玻璃
/// @param instance    承载层实例（ToggleAttribute 等 CommonAttribute）
/// @param forceOn     「强制光感」开关的**订阅值**（由调用方传入，见 materialActive 说明）
/// @param fallbackBlur 降级时是否补毛玻璃
/// @param interactive 是否可交互（按压流光）
/// @param withShadow  材质是否自带投影
/// @param lightColor  流光颜色（空串 = 系统默认白光）
export function applyMaterialCarrier(instance: CommonAttribute, forceOn: boolean,
                                     fallbackBlur: boolean = true, interactive: boolean = false,
                                     withShadow: boolean = true, lightColor: string = ''): void {
  if (!materialActive(forceOn)) {
    if (fallbackBlur) {
      instance.backgroundBlurStyle(BlurStyle.Thin);
    }
    return;
  }
  const material = getImmersiveMaterial(interactive, withShadow, lightColor);
  if (material !== null) {
    instance.systemMaterial(material);
  } else if (fallbackBlur) {
    instance.backgroundBlurStyle(BlurStyle.Thin);
  }
}

/// 纯函数：流光颜色；空串 = 不指定颜色、用系统默认白光
///
/// ⚠️ 刻意做成**纯函数、由调用方把订阅值传进来**：ArkUI 的局部更新按表达式登记依赖，
/// 函数内直接 AppStorage.get(...) 登记不上 —— 拨开关/切主题色时，已画出的卡片不会重新求值，
/// 流光会**停在旧颜色上**。
export function pressLightColor(themedLightOn: boolean, accentColor: string): string {
  return themedLightOn ? accentColor : '';
}

/// 卡片外壳模糊：材质生效时关掉（材质自带玻璃感），不生效时用毛玻璃
export function shellBlurStyle(forceOn: boolean): BlurStyle {
  return materialActive(forceOn) ? BlurStyle.NONE : BlurStyle.Thin;
}

/// 降级底色：材质/毛玻璃必须有**半透明**底色才看得见
/// （不透明的 cardBg 会把模糊整块盖住——这一步最容易漏）
export function fallbackSurface(isDark: boolean): string {
  // 约 70% 不透明：既让下层透出一点，又保证卡片上文字可读
  return isDark ? '#B31C1C1E' : '#B3F5F7FA';
}

/// 诊断串（设置页「强制光感」下方展示，一眼看出卡在哪一环）
export function materialDiagnostics(): string {
  let apiOk = false;
  let stateText = '未知';
  let typeText = '-';
  try {
    apiOk = uiMaterial.isImmersiveMaterialSupported();
    const info = uiMaterial.getMaterialInfo();
    stateText = info.state === uiMaterial.MaterialState.ENABLE ? 'ENABLE'
      : (info.state === uiMaterial.MaterialState.DISABLE ? 'DISABLE' : 'DEFAULT');
    typeText = info.type === uiMaterial.MaterialType.IMMERSIVE ? 'IMMERSIVE' : `${info.type}`;
  } catch (e) {
    stateText = '接口不可用（API<26）';
  }
  const probe = getImmersiveMaterial(false, true, '');
  const built = probe !== null ? '已构造' : '构造失败';
  const on = forceMaterialEnabled();
  return `材质支持=${apiOk ? '是' : '否'} · 构造=${built} · 系统状态=${stateText}(${typeText}) · 应用开关=${on ? '开' : '关'} · 承载=${materialActive(on) ? '下发材质' : '降级毛玻璃'}`;
}
