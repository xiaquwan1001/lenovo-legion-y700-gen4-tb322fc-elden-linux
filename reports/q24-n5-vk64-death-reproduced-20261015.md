# ★★★ Q24 死亡**已复现**（2026-10-15 晚，N5，vk64 台架）—— 12 发全存活后第一次致死

> 动机：`reports/q24-n2prime-both-arms-survive-20261015.md` §5.5 提出**镜像血统差异**为最强候选
> （历史致死在 `vk64`/7.2 血统，本轮 12 发全存活都在 `m1-baseline-f3`/7.3）。
> **N5 = 退回 vk64 台架跑同一配方**。
> 设备：U2 `HA2EXB0E`；方法 = **`fastboot boot out/boot-elden-vk64.img`**（零写盘：RAM 内核 + 持久磁盘根）。
> 安全：`idle-delay` 先置 0（熄屏由我们主动触发）。

---

## 0. 一句话

**在 vk64（7.2 血统）RAM 内核上、完整相机栈 19 模块 + 真实 `dpms On→Off` 熄屏 ⇒ 第 2 发即致死**，
且判据是 **Q24 的教科书签名**：**用户态 powerlog 无本次记录 + pstore 空 + 内核被换回 `boot_b`**。
⇒ **镜像血统差异假设【成立方向】**：同一配方在 **M1-7.3 (12 发全活)** 与 **vk64-7.2 (第 2 发死)** 上**行为不同**。

---

## 1. 时间线（可复核）

| 时间 | 事件 | 证据 |
|---|---|---|
| ~13:05 | `fastboot boot out/boot-elden-vk64.img` | `Booting OKAY`；`boot_id` = **`c1ca45b4-…`**，`uname` = **`7.2.0-debug-vk64-gd02658e63cf6`** |
| ~13:10 | 会话起来（phoc 2107 / phosh 2260 / greetd started），blank 置 0 | `gsettings idle-delay` = `uint32 0` |
| ~13:12 | **完整相机栈加载**：`CAM_FORCE=1 camera-modules-load.sh` | **19 模块 / 1 media / 17 video** |
| **13:14** | **N5 run1**：`WAKE(On) → BLANK(Off)`，保持 30 s | `boot_id` 不变、uptime 323 ⇒ **存活** |
| **~13:15** | **N5 run2**：同一 `WAKE → BLANK` 序列 | **SSH 两次超时（run2/run3）⇒ 设备失联** |
| ~13:17 | 设备回来：`uptime 42`、`uname` = **`7.3.0-rc7-debug-ged6f232d10e3`** | ⇒ **RAM 的 vk64 内核已死，回落到 `boot_b`（M1）** |
| 13:19 | 取证确认 | 见 §2 |

---

## 2. ★ 致死判据（三条独立证据，全部指向"硬复位"而非"用户态重启"）

| # | 判据 | 实测 | 含义 |
|---|---|---|---|
| **1** | **`/root/powerlog.txt` 是否记下本次** | 最后一条 = `USERLAND-reboot … uptime=1340 boot_id=1a42c78f-…`；**当前 `boot_id`（`9e32c92d-…`）在其中出现 0 次** | `elden-powerwrap` 的设计意图正是「区分用户态重启 vs 硬复位」⇒ **本次不是用户态发起 ⇒ 内核死了** |
| **2** | **`/sys/fs/pstore/`** | **完全为空**（`total 0`） | Q24 一贯的**无痕**特征（`PITFALLS #197` 一带） |
| **3** | **内核身份改变** | 死前 `7.2.0-debug-vk64-…`（RAM）→ 死后 `7.3.0-rc7-debug-ged6f232d10e3`（`boot_b`） | `fastboot boot` 的 RAM 内核不持久；系统重启后回落到槽内镜像 ⇒ **发生了整机复位** |

**恢复行为**：设备**自行恢复**（无需物理 POR），与 `PITFALLS #209`「SoC 级复位 + ~30 s 自恢复」一致
（失联 ~1–2 min 后回来）。

---

## 3. 与 M1 的对照（同会话、同配方、单变量 = 内核血统）

| 台架 | 内核 | 配方 | 结果 |
|---|---|---|---|
| **M1-7.3** | `7.3.0-rc7-debug-ged6f232d10e3` | 完整栈(19) + 真实熄屏 | **5/5 存活** |
| M1-7.3 | 同上 | 2 CC + 真实熄屏（两臂） | **7/7 存活** |
| **vk64-7.2** | `7.2.0-debug-vk64-gd02658e63cf6` | **完整栈(19) + 真实熄屏** | **第 2 发致死** ❌ |

⇒ **同一配方、同一设备、同一 rootfs、同一模块集规模**，**只换内核血统** ⇒ **行为不同**。
这是 Q24 排查以来**第一次拿到"可二分的单一变量"**。

---

## 4. 审慎限定（必须写清，不得过度结论）

1. **样本数小**：vk64 侧只有 **run1 存活 + run2 致死**（n=2），
   而历史口径是**间歇性**（60+ 轮二分时代也只是"多数"触发）。
   ⇒ **不能**说"vk64 必死"；只能说"**vk64 上更易致死**"。需补样本。
2. **存在一个未控变量：Q28 显示态**。本次两个台架的 boot **都是 Q28 坏发**
   （vk64 boot：`dmesg | grep -cE "command DMA timeout|Failed to initialize panel"` = **3**；
   死后的 M1 boot = 2）。`reports/q24-mech-20261012.md` 记过「致死点随显示电源转换移动」
   ⇒ **显示态可能是必要的第三成分**，而它在两臂间**没有被单独控制**。
3. **`fastboot boot` 的 RAM 内核与"真 POR 冷起"不完全等价**（`PITFALLS #166`/DOSSIER §f 曾讨论）。
   本轮用的是 `fastboot boot`，与历史致死的"盘启"在**引导路径**上可能有差异。
4. **本轮 run1 存活、run2 死** ⇒ 若为间歇，**单发存活不能证明"该配方在 vk64 上安全"**（反之亦然）。
5. **口径纪律**：**不得写"Q24 已解"或"Q24 = vk64 特有缺陷"**。
   现在能说的是：**「镜像血统」是一个已被实测支持的、可二分的单一变量**，值得投入。

---

## 5. 下一步（N5 续，按性价比）

| # | 动作 | 变量 | 判据 | 成本 |
|---|---|---|---|---|
| **N5b** | **补 vk64 样本至 n≥5**（同一 `fastboot boot` + 完整栈 + 真实熄屏；每次死后自动回落 `boot_b`，需重新 `fastboot boot`） | 无（重采样） | 若致死率显著高于 M1 的 0/12 ⇒ 坐实血统差异 | 0 构建；每次死亡自恢复 |
| **N5c** | **在 vk64 上做"不熄屏"对照**（完整栈在位、不熄屏、长时窗） | 单变量 = 是否熄屏 | 不熄屏存活 ⇒ 熄屏确为触发；若也死 ⇒ 触发不是熄屏 | 0 构建 |
| **N5d** | **控制显示态**：让两臂同为 Q28 **GOOD**（或同为 BAD）后再比 | 单变量 = 血统（控制显示） | 排除 §4.2 混淆 | 每次需撞 GOOD 发 |
| **N6** | 若 N5b 坐实 ⇒ **在 `clean/base → m1-73/baseline` 的提交集上二分**，定位"哪次改动让 Q24 不再触发" | 提交区间 | 找到首个不死的提交 | 构建 + 上机 |

> **编排者判断**：**N5b 优先**（零构建、每次死亡自恢复、直接决定这条线是否值得投入二分）。
> 建议同时记录**每次的 Q28 显示态**作为协变量（§4.2）。

---

## 6. 证据与会话

- 死亡现场取证（设备实读）：`logs/n5-q24-death-20261015/post-death.txt`
  - `boot_id 9e32c92d-90ef-4c36-ba49-38ace13b2d64`，`grep -c <该id> /root/powerlog.txt` = **0**
  - `/sys/fs/pstore/` **空**；`uname -r` = `7.3.0-rc7-debug-ged6f232d10e3`（= `boot_b`，非 RAM 的 vk64）
- vk64 台架启动证据：`fastboot boot out/boot-elden-vk64.img`；`boot_id c1ca45b4-…`；
  `uname 7.2.0-debug-vk64-gd02658e63cf6`；模块树 1224 `.ko`
- M1 侧的 12 发存活：`reports/q24-n2prime-both-arms-survive-20261015.md`
- 相关口径：`PITFALLS #209`（自恢复）、`#212`（最小触发，本日已证不可复现）、`#289`
- 工具教训：`PITFALLS #288`（`reboot` 挂起；**死活判据必须用 `boot_id`**）

---

## 7. 会话收尾状态（2026-10-15 晚，用户指示"总结后结束"）

- **N5 结论已定**：vk64（7.2 血统）+ 完整栈 + 真实熄屏 = **第 2 发致死**（n=2：1 活 1 死）；
  对照 M1-7.3 同配方 **12/12 存活** ⇒ **镜像血统是被实测支持的、可二分的单一变量**。
- **N5b 未执行**（用户裁决"把 vk64 刷进 boot_b 做全自动 N5b"已获批，但会话按用户指示收尾而暂停）。
  已备好工具：**`scripts/n5b-vk64-death-rate.sh`**（含逐轮 `boot_id` 判据、
  `powerlog`/`pstore` 硬复位签名取证、`fastboot` 回落自动处理；**`bash -n` 已过**）。
  **前置**：需先把 vk64 刷进 `boot_b`（`scripts/flash-b.sh out/boot-elden-vk64.img --reboot`），
  这样每轮死亡后设备自动回落到 vk64，无需人工进 fastboot。
- **回退资产已确认可用**：`bootslot-b/boot_b.img`（sha `78a2beb1…`）**正是**当前在机
  `m1-baseline-f3` 的已签名写入版（与 `DEVICE/README.md` §1.1 记录逐字一致）⇒ 可随时刷回。
  ⚠ **`fastboot fetch boot_b` 在本机不支持**（`Device does not support fetch command`），
  别指望它做备份（本轮实测还留下过一个 0 字节文件，已删）。
- **设备收尾态**：用户手动置于 **fastboot**（`HA2EXB0E`）；`boot_b` **未被本次会话改写**（仍是 `m1-baseline-f3`）。
- **附带修的脚本**（均 `#288` 同源）：`cycle.sh --soft/--fastboot` 与 `scripts/flash-b.sh --reboot`
  的 `reboot -f` → **`echo b > /proc/sysrq-trigger`**；
  另在 `cycle.sh --fastboot` 加了 PITFALLS #65 的告警（BCB **未被 ABL 采纳**，
  2026-10-15 实测：走该路径先落 BL、随即进 Q28 坏发版本，需人工干预）。
