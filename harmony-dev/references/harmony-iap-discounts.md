# 华为 IAP Kit：商品价格与折扣优惠（促销价 / 订阅首购 / 促销码）

> 适用：HarmonyOS 应用内支付（`@kit.IAPKit`）的商品查询、价格显示、折扣/优惠机制、订阅。
> 证据：本机 SDK `@hms.core.iap.d.ts`（compileSdk 6.1.0(23) 实测字段与注释原文）+
> Icey Player（音乐播放器，永久会员非消耗 + 月度订阅）真机接入逐轮沉淀。
> 购买/恢复/订阅管理的主链路（createPurchase / finishPurchase / queryPurchases / JWS 解码）
> 不在本册范围——本册只管「价格与优惠」这一层。

## 结论（先读）

1. **华为 IAP 折扣一共三档**，先分清再对接：
   | 档 | 配置处 | 客户端字段 | 需要服务端？ |
   |---|---|---|---|
   | ①非订阅商品促销价 / 临时调价 | AGC 商品配置 | `localPrice`（=促销价）与 `originalLocalPrice`（=恒原价） | 否，自动生效 |
   | ②订阅首购优惠（introductory offer） | AGC 订阅配置 | `subscriptionInfo.hasEligibilityForIntroOffer` + `introductoryOffer` | 否，自动生效 |
   | ③订阅促销码（promotionalOffers） | 服务端 + IAP Server API | `Product.promotionalOffers[]` + 购买参数 `promotionalOfferId` + `jwsRepresentation` | **是**（出签名） |
   没有服务端的应用直接配 ①② 就够——③不接不影响 ①② 生效。
2. **①② 都是「购买时华为自动按优惠价结算」，客户端购买参数零改动**。客户端唯一职责是
   **把优惠显示出来**（划线原价 / 首购徽标），否则用户看不到折扣。
3. **价格显示统一走 `Product.localPrice`（实时价）**：无促销 = 原价、有促销 = 促销价；
   `queryProducts` 失败 / IAP 不可用时回落**硬编码文案**，且折扣 UI（划线/首购行）随之
   自动消失——绝不能在无商品数据时显示折扣。
4. **划线原价判定 = `localPrice !== originalLocalPrice`**（两者都是「币符+金额」字符串）。
   ⚠️ 字段口径不对称：非订阅商品 `originalLocalPrice` **恒返回**（不管配没配促销）；
   **订阅商品不返回** `originalLocalPrice`（订阅的优惠走首购档，不走划线）。
5. **首购资格是按华为账号判的**：`hasEligibilityForIntroOffer=true` 才显示首购价
   （该账号用过首购即 false）；无资格账号购买走原价。UI 必须按资格显隐，别写死。

## 字段口径表（`iap.Product`，d.ts 注释原文口径）

| 字段 | 非订阅（消耗/非消耗/非续期） | 自动续期订阅 |
|---|---|---|
| `price` | 有促销价 = 促销价；无 = 原价。**临时调价场景 = 原价**（促销价能力已升级为临时调价） | **恒原价** |
| `localPrice?` | 同 `price` 口径（同上，含临时调价例外） | 恒原价 |
| `microPrice` | 微单位（×1,000,000）的实际价（同上例外） | 恒原价 |
| `originalLocalPrice` | **恒原价**（无论是否配促销） | **不返回** |
| `originalMicroPrice` | 恒原价微单位 | 不返回 |
| `currency` | 币种 | 同 |
| `subscriptionInfo?` | 无 | `periodCount / groupId / groupLevel / hasEligibilityForIntroOffer? / introductoryOffer?: SubscriptionOffer` |
| `promotionalOffers?: PromotionalOffer[]` | 无 | 有（③，需服务端签名使用） |

⚠️ `price` 与 `localPrice` 口径几乎相同但临时调价场景例外描述不同（`price`=原价，
`localPrice`=原价——两字段在调价场景都回原价；**促销价场景两字段都=促销价**）。
显示层统一用 `localPrice`（Icey Player 口径：`permanentProduct?.localPrice ?? '¥25.00'`）。

## 订阅首购档（`SubscriptionOffer` / 枚举）

```text
SubscriptionOffer {
  paymentMode: OfferPaymentMode   // FREE_TRIAL=1 免费试用 / PAY_AS_YOU_GO=2 按期优惠价
                                  // PAY_UP_FRONT=3 预付合计 / SINGLE_PROMOTION=5 单次促销
  periodUnit: PeriodUnit          // DAY=0 / WEEK=1 / MONTH=2 / YEAR=3 / MINUTE=4
  periodCount: number             // 期数
  localPrice: string              // 首购价（FREE_TRIAL 时 0/空）
  microPrice: number
  offerType: OfferType            // INTRODUCTORY=0 首购 / PROMOTIONAL=1 促销
}
```

**首购文案翻译样板**（Icey Player `VipPage`，量词不带「首」由调用方拼，避免病句）：

```ets
private offerPeriodText(unit: iap.PeriodUnit, n: number): string {
  if (unit === iap.PeriodUnit.DAY) { return `${n}天`; }
  if (unit === iap.PeriodUnit.WEEK) { return n > 1 ? `${n}周` : '一周'; }
  if (unit === iap.PeriodUnit.MONTH) { return n > 1 ? `${n}个月` : '一个月'; }
  if (unit === iap.PeriodUnit.YEAR) { return n > 1 ? `${n}年` : '一年'; }
  return `${n}分钟`;
}
// FREE_TRIAL        → `免费试用${period}`        （一个月免费 / 7天免费）
// PAY_UP_FRONT      → `首${period}合计 ${o.localPrice}`
// PAY_AS_YOU_GO     → `首${period}优惠价 ${o.localPrice}`（首一个月优惠价 ¥2.99）
```

⚠️ 量词先拼「N 个个月 / 月免费」这类病句再 replace 修，不如一开始拆「量词段 + 前缀」。

## UI 显示范式（划线原价 + 首购徽标）

- **主价**：`Text(product.localPrice ?? 静态兜底文案)`，accent 色 22 Bold。
- **划线原价**：`localPrice !== originalLocalPrice` 才渲染，`fontSize 13` +
  `.decoration({ type: TextDecorationType.LineThrough })`。
  ⚠️ **本 SDK 该属性叫 `.decoration`，不是 `.textDecoration`**——后者 10505001
  「Property 'textDecoration' does not exist on type 'TextAttribute'. Did you mean 'decoration'」。
- **首购徽标行**：`hasEligibilityForIntroOffer === true && introductoryOffer` 存在才渲染；
  accent 底白字小徽标「首购优惠」+ 12sp 文案（上表翻译）。
- 两条都随 `queryProducts` 成败自动显隐——失败回落静态价时它们自然为空，不需要额外开关。

## 使用促销码（③）的完整链路（本项目未接，记录以备将来）

1. 服务端调 IAP Server API「生成促销购买参数签名」（iap-server-subscribe-offer-sign），
   得到 JWS；客户端购买时传 `PurchaseParameter { promotionalOfferId, jwsRepresentation }`。
2. `Product.promotionalOffers[]` 里的 `offerId` 与签名一一对应；漏传/错配报错。
3. 判据：**应用没有服务端就别接 ③**——AGC 直接配非订阅促销价 / 订阅首购档即可生效，
   两者都不需要任何服务端参与。

## 验收清单（真机，依赖 AGC IAP 已开通）

- [ ] AGC 给非订阅商品配促销价 → 商品卡现价变为促销价、旁显删除线原价；实际扣款为促销价
- [ ] AGC 给订阅配首购档 → 有资格账号显示「首购优惠」行；已用过首购的账号不显示且按原价扣
- [ ] 断网/未授权（queryProducts 失败）→ 价格回落静态文案、无划线无首购行、购买入口行为正常
- [ ] 取消促销/调价结束 → 划线自动消失（localPrice 回到 = originalLocalPrice）
