# C3 收口（2026-11-10）：Play Integrity 三档 × Widevine 等级的**书面结论**

> 任务：`TASKS.md` §2 **C3** / §5 **Q1**（取证判定，**不预设结论**）。
> 本报告把 2026-10-13 本机取证（`reports/c3-identity-drm-20261013.md`）与 2026-10-26 lane F 复核
> （`reports/android-compat-20261026.md` §2/§7）合成**可审阅的三档结论**，并明确分开
> 「**已证**」「**结构性否证**」「**只差一次回包**」三类。**未新上机、未装 APK、未改镜像。**
> 术语：PI = Play Integrity API；BASIC / DEVICE / STRONG = `MEETS_BASIC_INTEGRITY` /
> `MEETS_DEVICE_INTEGRITY` / `MEETS_STRONG_INTEGRITY`。容器 = `lineage-20.0-20260927-GAPPS-waydroid_arm64_only`（A13）。

---

## 0. 结论（先数字）

| 档位 | 结论 | 类型 | 一句话判据 |
|---|---|---|---|
| **GMS 可用性** | ✅ **可用** | 已证 | 账号已登录 `xuqianhui176@gmail.com`；`gstatic/generate_204` = **204**（经宿主代理） |
| **PI — BASIC** | ⛔ **不加对策必失败** | 已证（前置）+ 未取回包 | build = `userdebug` + **`test-keys`** + Waydroid fingerprint（非 Google 认证 build） |
| **PI — DEVICE** | ⛔ **不加对策必失败**；加 PIF 类伪装 = **窗口期产物，不可承诺** | 前置已证（同上）+ 未取回包 | 认证 build / CTS 通过 / 锁定-验证启动三项在本形态**全不满足** |
| **PI — STRONG** | ❌ **结构性不可达（本机本体层面就已不可达）** | **结构性否证** | 容器内**无 TEE**（keymaster 4.0 软实现）；且本机 2026-10-03 BL 解锁后 verified-boot 已非 green |
| **Widevine** | ❌ **"不存在"（比 L3 更低：连 L3 库都没有）** | 已证 | `/vendor/lib64/mediadrm/` 只有 `libdrmclearkeyplugin.so`；全 `/vendor`+`/system` 无 `*wv*`/`*widevine*` |
| **U5（DRM 高清播放）** | ❌ 容器内**不可用**；YouTube 走非 DRM 路径**可测但未测** | 已证 + 一条明确未测项 | ClearKey-only ⇒ 任何 Widevine-required 内容必失败 |

**一句话**：G2 的「身份/完整性」上限 = **GMS 可用 + 无任何 Widevine 等级 + PI 最好情况（加伪装）只可能摸到 BASIC/DEVICE**，
**STRONG 永远没有**——它在解锁那一刻就对整机不可逆地关掉了，容器形态再叠一层结构性缺失。

---

## 1. 已证的硬事实（逐条附原始证据位置）

| # | 事实 | 原始证据 |
|---|---|---|
| F1 | build = `userdebug` + `test-keys`；fingerprint = `waydroid/lineage_waydroid_arm64_only/…:userdebug/test-keys`；`ro.secure=1`、`ro.debuggable=0`、first_api_level 28 | `reports/c3-identity-drm-20261013.md` §1 `getprop` |
| F2 | GMS 26.37.37 / Play 53.4.34 在跑；账号 `Account{name=xuqianhui176@gmail.com, type=com.google}` | 同上（`dumpsys account`、`dumpsys package`、`ps -A`） |
| F3 | 出口连通：`curl -m12 https://www.gstatic.com/generate_204` → **204** | 同上 |
| F4 | **Widevine 缺失**：`ls /vendor/lib64/mediadrm/` = 仅 `libdrmclearkeyplugin.so`；`find /vendor /system -iname '*wv*' -o -iname '*widevine*'` 空；`/vendor/bin/hw` 只有 `android.hardware.drm-service-lazy.clearkey` | 同上 §1 |
| F5 | **keymaster 4.0 为软实现**：`libpuresoftkeymasterdevice.so`，**无 TEE** 支撑 | `reports/android-compat-20261026.md` §2（lane F 镜像直读） |
| F6 | 设备**本体**无可用 TEE 给 Android 用：EL2 被**签名 Gunyah** 占（内核只到 EL1），无 KVM；`hyp` 分区受 XBL 签名 | `DEVICE/README.md` §1 |
| F7 | BL 已解锁（`officially unlocked:yes`），`boot` 为 chained AVB、b 槽自签；**verified-boot 已非 green** | `TASKS.md` §1 G1-0/G1-1、`DEVICE/README.md` §1 |

> F6/F7 决定的是**整机**上限（不是容器实现问题）。

---

## 2. 三档判读

### 2.1 BASIC —— 「不加对策必失败，加对策才有讨论空间」

- **判据**：BASIC 要求「系统看起来是未被篡改的、Google 认得的 Android」；`test-keys` + `userdebug` +
  非认证 fingerprint 是**直接反例**（社区一致结论：Waydroid 开箱 PI 全档 RED）。
- **结论**：不加对策 → 失败。**是否需要回包才能定？**：结论「必失败」不需要；把它写成「已实测 RED」才需要回包。
- **对策**：PlayIntegrityFork（`pif.json` 指纹伪装）+ 未认证设备注册（`google.com/android/uncertified`）。
  代价：**随 Google 服务端反制漂移**，今天绿明天红 ⇒ **不可作为验收承诺**，只能记「某日某 build 某配置下绿」。

### 2.2 DEVICE —— 「同 BASIC + 认证 build/CTS/验证启动」，因此**同为前置不满足**

- **判据**：DEVICE 要求设备通过 Google 认证（CTS profile）、启动链「锁定且验证」。
- **结论**：本形态**三项全不满足**（非认证 build、BL 已解锁、自编内核/自签 boot）。
  加 PIF + 认证指纹后可**尝试**摸到 DEVICE，但同上——**窗口期产物**。
- **落地口径**：G2 的验收句应写成「**取到多少记多少，并记日期/build/PIF 版本**」，不写「达到 DEVICE」。

### 2.3 STRONG —— **结构性不可达**（这条不需要回包就能定，且不因对策改变）

三层独立理由，任一成立即否证：

1. **容器内无 TEE**：STRONG 的判据是**硬件支撑的密钥认证 + 完整启动状态**；容器里 keymaster 是
   `libpuresoftkeymasterdevice.so`（F5），没有任何可信执行环境可供 attestation。
2. **整机 EL2 不归我们**：签名 Gunyah 占 EL2、`hyp` 分区受 XBL 校验（F6）⇒ 「我们无法提供 hardware-backed
   attestation 链」不是选择而是平台事实。
3. **解锁即失去 green 验证启动**：2026-10-03 BL 解锁（F7）后，即使跑**真 Android**，verified-boot 也不再是 green
   ⇒ STRONG 对本机**本体**已不可达，**与 G2 容器方案无关**。

> 因此：**不做**密钥伪造 / TEE 绕过 / 安全启动降级类尝试（与 `TASKS.md` §6 §2-④「不做什么」一致）。

---

## 3. Widevine 与 U5

| 等级 | 现状 | 说明 |
|---|---|---|
| L1 | ❌ | 需芯片商 + GMS 认证的 TEE 内密钥；容器无 TEE，且解锁后本体也不再有 |
| L3 | ❌ | **本机连 L3 库都没有**（F4）；arm64/A13 社区亦无 prebuilt（`waydroid_script` `Widevine.dl_links` 核实：arm64 仅 A11 有） |
| ClearKey | ✅ 唯一在 | 只能解未加密内容，等于无 DRM |

- **U5（YouTube/Disney+ 等高清 DRM 播放）结论**：**容器内不可用**（不为「等级低」，而是「没有」）。
- **一条明确未测项**：YouTube 在 DRM 失败时会回落非 DRM 路径，**画质上限可测但未测**（不在 C3 取证范围，
  若要做归 C9 用例表，用 `grep -i 'widevine\|drm' logcat` + 实播对照即可）。
- 附带记账：Q15 预期「解锁 ⇒ Widevine L1→L3」**解锁后从未复测**（`c0-baseline` 的 L1 是解锁前采的）。
  这不影响 G2 容器结论（容器侧本来就是「无」），但**本体侧是空白项**，别在别处引用成「L3」。

---

## 4. 为什么换路线也不改善（避免重复投入）

| 路线 | 对 PI/DRM 的净增益 | 依据 |
|---|---|---|
| redroid（R1'） | **0**：同栈（LXC + 同一套用户态），身份仍取决于 GApps + PIF | `TASKS.md` §6 §0 |
| VM（R2, Gunyah） | **0**：已终局裁决不可行；即便可行，也仍无 TEE 给 guest（EL2 归签名 Gunyah） | `reports/gunyah-decision-20261025.md` |
| droidloom（R3） | **0**：上游 `threat-model-v2.md` **明写**不承诺 Protected media / hardware attestation / Play Integrity | `reports/droidloom-feasibility-20261108.md` |
| 退回 stock Android 日常用 | 唯一能拿回 L1/STRONG 的路，但**前提是重新锁定 + 官方固件**，与 G1 目标互斥 | `RESOURCES/README.md` §1.3、`backup/stock-259/` |

⇒ **C3 的剩余价值已经不在"能不能更高"，而在"把上限写清楚、把验收句写对"**。

---

## 5. 唯一剩余动作（一次回包，需用户批准装 APK）

目的**不是**推翻上面结论，而是把「必失败」从**推理**升级为**实测记录**（并且顺便验证 PIF 后的实际档位）。

| 项 | 内容 |
|---|---|
| APK 候选 | `herzhenr/spic-android` v1.4.0（SPIC，11.2 MB，Apache-2.0）——单一 App 一次出 BASIC/DEVICE/STRONG 三档 |
| 获取 | 宿主直连 `curl --noproxy '*' -L https://github.com/herzhenr/spic-android/releases/download/v1.4.0/spic-v1.4.0.apk`（GitHub 直连可达；走代理会 403） |
| 安装 | 容器 RUNNING 且 `sys.boot_completed=1` 时：`waydroid app install spic-v1.4.0.apk` |
| 取证 | `adb -s waydroid shell am start -n gr.nikolasspyr.integritycheck/.MainActivity` → 截图 + `logcat -s IntegrityCheck`；记录 **Google Play 是否"未认证"** |
| 判据表（三种结果都要记） | ① 三档全红 + 提示"设备未认证" ⇒ 印证 §2.1/§2.2；② BASIC/DEVICE 绿、STRONG 红 ⇒ 印证 §2.3 且把 §2.1/§2.2 降级为"窗口期可得"；③ 全绿 ⇒ **上面的结构性判读被推翻**，必须重开 C3（并检查是否误用了非本机 fingerprint） |
| 附加变量（各变一次，一次性做完） | (a) 原样；(b) 装 PIF + `pif.json`；(c) 未认证设备注册 + 清 GMS 缓存 |

⚠ 前置：容器运行 + 上行可用（`scripts/host-net-proxy.sh`）。CLI 安装第三方 APK 属用户信任域，**执行前需你点头**。

---

## 6. 收口口径（本次落地）

1. `TASKS.md` §2 **C3**：状态标记 `🆕` → `🟡`，格内改为「**书面三档结论已出（本报告）**；剩一次回包验证（需批准装 APK）」。
   ⇒ **完成度计数不变**（`🟡` 与 `🆕` 同计"未完成"，§0 的 8/12 不需要动，`check-progress-counts.sh --selftest` 仍绿）。
2. `TASKS.md` §5 **Q1**：加一行指针到本报告（三档结论 + 结构性否证），保留原取证链。
3. `TASKS.md` §6 §1 的 **C2 维度**格：由「待调查」改为「容器 2（GMS ✅ / PI ≤ BASIC-DEVICE 且需伪装 / DRM 无）」，附本报告指针。
4. 不再把「PI 能做到哪一级」当开放问题——**开放项只剩"要不要装那一次 APK"**。

---

## 7. 与其它文档的关系

- 取证原文：`reports/c3-identity-drm-20261013.md`（10-13 本机）、`reports/android-compat-20261026.md` §2/§7（lane F 镜像直读与否证条件）。
- 基线对照：`reports/c0-android-baseline-20261011.md`（stock Android：Widevine **L1**、HDCP 2.3、**未 root**、BL orange）。
- 用例判据：`reports/c9-cases-20261013.md`（U5 DRM 播放）。
- 上限与取舍：`TASKS.md` §6 §3（"a 槽可弃"风险登记）、§5 Q15（解锁代价）。
