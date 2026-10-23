# Q24 · Konrad 单变量臂（`rpmhpd_driver.sync_state` 关闭）首测 — 2026-10-23

> 依据：Konrad Dybcio 2026-10-20（`<101257b5-…@oss.qualcomm.com>`）单变量建议 —— 注释掉 `rpmhpd_driver.sync_state`，让所有 rail 钉在最大档。
> 纪律：只在 **7.2 血统（vk64）** 上跑（7.3-rc7 本来不死，跑它没有判别力）。
> 本文件只记「臂镜像 + 首测样本 + 已知偏差」；基线（vk64 原镜像）样本见 `reports/q24-n5b-20261023.md`。

---

## 1. 臂镜像（主机侧，已产出）

| 项 | 值 |
|---|---|
| 镜像 | `out/boot-elden-vk148.img` |
| sha256 | `93bbc4e265ae06a0e302f86d741137cace8d9f233ab60d719069804042435815` |
| kernel payload sha256 | `2696543452a78008bb0ad93a822fec2b36055ce16e57b51c8b62dd45e54fd9a4` |
| UTS | `7.2.0-debug-vk64-gd02658e63cf6`（**显式钉住** ⇒ 复用设备上 1497 个 `.ko`，`PITFALLS #367`） |
| 构建提交 | `d02658e63cf607e71231b077ddd73f42408463c0`（= vk64 manifest 原提交） |
| 唯一源码差异 | `patches/candidate-q24-syncarm/0001-pmdomain-rpmhpd-disable-sync_state.patch`（去掉 `.sync_state = rpmhpd_sync_state`） |
| 配置差异 | 仅 `CONFIG_LOCALVERSION="-debug-vk64-gd02658e63cf6"` + 关 `CONFIG_LOCALVERSION_AUTO`（为了钉 UTS） |
| DTB / ramdisk | 与 vk64 镜像**逐字节相同** |
| 详见 | `reports/q24-syncarm-build-20261023.md` |

**变量确实生效**（设备侧实测）：`grep -c rpmhpd_sync_state /proc/kallsyms` = **0**（基线镜像里该符号存在）；`/proc/version` 的构建时间与臂镜像一致。
（注意：`dmesg` 里 `qcom-rpmhpd … sync_state() pending due to …` 仍在打印 —— 那是 `fw_devlink` 的通用提示，**不能**用来判该变量是否生效，符号表才是判据。）

---

## 2. 首测结果：**3/3 ALIVE**（同一 boot 连采）

台架：`fastboot boot out/boot-elden-vk148.img` → 会话起来 → 加载 19 个相机模块 → `ScreenSaver.SetActive(true)`（真实熄屏，`dpms On→Off` 已核）→ 熄屏 30 s → **显式唤醒** → 再判 8 s。

| 轮 | 来源 | boot_id | dpms | 熄屏 30 s | 唤醒 8 s | 判定 |
|---|---|---|---|---|---|---|
| 2 | 同一 boot 连采 | `6af2e16a-…` | On→Off | 存活 | 存活 | **ALIVE** |
| 3 | 同一 boot 连采 | `6af2e16a-…` | On→Off | 存活 | 存活 | **ALIVE** |
| 4 | 同一 boot 连采 | `6af2e16a-…` | On→Off | 存活 | 存活 | **ALIVE** |
| 5 | **`FRESH=1` 独立冷启**（`fastboot boot`） | `e07bc73c-…` | On→Off | 存活 | 存活 | **ALIVE** |

第 5 发是**独立冷启动**（`FRESH=1`），`dpu_err=0`、`Q28sig=0`、19 个相机模块在位，熄屏 30 s + 唤醒 8 s 均存活 ⇒ 臂的存活不是「单 boot 运气」所能完全解释。
同批另外 2 发因**显示栈已坏**（`dpu_err=15`、会话 DBus 超时）作废，属 Q28 坏发类（`PITFALLS #369`）。

> **采样按用户决定（2026-10-23）到此为止**，不再追加臂/基线样本。

## 3. 与基线的对比（同一协议、同一脚本、同一模块树）

| 臂 | 样本 | DEAD | ALIVE | 死率 |
|---|---|---|---|---|
| 基线 vk64（原镜像） | 8 | **6** | 2 | 75% |
| **sync_state 关闭臂（vk148）** | 4 | **0** | 4 | **0%** |

- Fisher 精确检验（超几何单侧，0/4 vs 合计 6/12）= **p ≈ 0.030** ⇒ 方向一致、已达常用显著线；**但样本仍小、且 3/4 来自同一 boot**。
- 基线那 8 发里 DEAD 的两相位（熄屏瞬间 ADSP/TZ fatal、熄屏后唤醒静默复位）在臂上**一发都没出现**。
- **偏差**：臂 4 发中 3 发为同一 boot 连采，只有 1 发是独立冷启（那发也存活）。基线多数死亡发生在不同 boot ⇒ 严格对拍还缺「基线 FRESH 独立样本」。

## 4. 复跑被设备状态打断

`FRESH=1`（每发强制重开）首轮即遇「显示栈已坏」的 boot（`dpu_err=447`），随后 `reboot2` 静默无效 → `SysRq-b` 逃生 → 设备**再次完全从 USB 消失**（无 `ttyACM`、无 fastboot、无 ping），与 `PITFALLS #368` 同族，需人工断电。

## 5. 结论（当前口径，禁止升级为定论）

- 〔已证实〕`sync_state` 关闭臂**在当前 7.2 台架上没有复现 Q24 致死**（3/3 存活，同一 boot）。
- 〔已证实〕基线同协议同模块 8 发 6 死。
- 〔推测〕Konrad 的方向可能对（rail 提前降档 → ADSP/TZ 在熄屏时判死），但**样本量与独立性都不够**。
- **未做（按用户 2026-10-23 决定停止）**：基线 / 臂各补 ≥5 发 `FRESH=1` 独立样本。**恢复条件**：Q28 v2（复位搬 mdss 侧 + 读回校验）落地后，坏 boot 类被压掉，那时再做对拍成本会低一个数量级。
