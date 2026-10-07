# 熄屏睡死根因 — 二分候选与实验计划（2026-10-06）

> 用户 2026-10-06 定：重启「熄屏（DPMS off）→ 整机硬复位/关机」根因调查（G1-22/Q24）。
> 设备当前由另一会话持有 ⇒ 本轮**只做代码追溯 + 主机构建候选**，未上机。
> 本文是过程证据（archive，只增不改）；结论口径以 `TASKS.md` §5 Q24 为准。

---

## 0. 结论摘要

- 此前「根因=N1/N4 调试插桩、已被 vk42 修复」的结论**作废**（`vk47clean` 仍复现）。
- `vk47clean` 的音频改动 = **N2（APM 命令头）+ N3（MI2S 图提前到 prepare）** ⇒ 候选收窄到 **N2 / N3 / 热区 DTS / vk34 之前的既有改动**。
- **新发现（本轮静态取证）**：N2（`patches/0009`）把 `SHARED_MEM_MAP/UNMAP` 的分配改成
  `audioreach_alloc_apm_cmd_pkt`（**多 8 字节 APM 命令头**），但**载荷指针没有随之后移**——
  仍是 `pkt + GPR_HDR_SIZE`，正确应为 `pkt + GPR_HDR_SIZE + APM_CMD_HDR_SIZE`。
  ⇒ 载荷被写进 APM 头、发给 ADSP 的包整体错位 8 字节。`q6apm.c` 中此偏移在 vk34 与 vk40/vk47 之间**未随分配器改变**。

---

## 1. 基线与构建方法（可复现）

| 项 | 值 |
|---|---|
| 源码 | `bd114ca33`（= tag `vk47` = `vk47clean` 源）；worktree `~/wt-sleepdeath` |
| config | `wt-wifibmiss/.config`（sha256 `af8a2d69…`；= `config-vk40-bringup` + `LOCALVERSION_AUTO` 关） |
| ramdisk | `out/initramfs-full-elden.cpio.gz`（sha256 `98ffc622…`，标准 full 载具，含固件） |
| cmdline | 与在机 vk47clean 同（`elden_root=LABEL=linux17`），仅 hz120 变体追加一行 |
| 构建 | `scripts/sd-variant-build.sh <ver>`（ccache；音频/面板 `=y` → 改 C 只重链） |

**注意**：变体 KV 唯一（`7.2.0-debug-sd-*`），与持久根 `/lib/modules/<旧KV>` 失配 ⇒ 相机/WiFi 等 `=m` 模块不加载；
核心驱动均 `=y`，足以进桌面。判据内核用 `uname -r` 区分（不要用 `uname -v`）。

---

## 2. 候选清单（主机侧已构建，零写盘 `fastboot boot`）

| 变体 | 假设 | 源码改动 | 分支 commit | UTS | image sha256(前16) |
|---|---|---|---|---|---|
| `sd-base` | **对照**：vk47 基线应复现 | 无 | `bd114ca33` | `7.2.0-debug-sd-base` | `a132e2320f5e598e` |
| `sd-noN2` | H1：撤销 APM 命令头（回 vk34 形态） | `-0009` | `7376cf223` | `7.2.0-debug-sd-noN2` | `bec37f3a06c9ed11` |
| `sd-n2fix` | H1b：保留命令头、**只修载荷偏移** | `q6apm.c` +`APM_CMD_HDR_SIZE` ×2 | `37eb3985a` | `7.2.0-debug-sd-n2fix` | `3c358e9c4aa24335` |
| `sd-noN3` | H2：MI2S 图改回 trigger 启动 | `-0011` | `162f814c3` | `7.2.0-debug-sd-noN3` | `d28aba002f01fb55` |
| `sd-noN2N3` | H1+H2 合并 | `-0009 -0011` | `7368e9a92` | `7.2.0-debug-sd-noN2N3` | `d6a6e7a2efc8ee9e` |
| `sd-noGC` | H4：撤销 DPU DSDP GC/gamma 块 | `-0002` | `7c985a66c` | `7.2.0-debug-sd-noGC` | `25238556b978547e` |
| `sd-hz120` | H3：面板默认 165→120Hz（同 sd-base 内核 + cmdline） | cmdline `panel_novatek_nt36536.force_hz=120` | `bd114ca33` | `7.2.0-debug-sd-hz120` | `75ecaa517f58f388` |

镜像与 manifest 均在 `out/boot-elden-<变体>.img|.manifest`。

### 不同假设的判别逻辑

- `sd-noN2` 不复位 & `sd-n2fix` 也不复位 → 真因是**载荷偏移**（协议头本身没错）；
- `sd-noN2` 不复位 & `sd-n2fix` 仍复位 → 真因是**给 GET_SPF_STATE/MAP 加头本身**（SM8750 ADSP 不接受）；
- 两者都复位 → N2 无关，看 `sd-noN3` / `sd-noGC` / `sd-hz120`；
- 全部复位（含 sd-base 对照）→ 根因在 **vk34 之前的既有改动**（B 组：GPR 端口 3/7、USB 角色、DPU GC、面板模式…）或与内核增量无关。

---

## 3. 测试协议（设备空闲后执行）

主机侧驱动脚本：`scripts/sd-run-variant.sh <变体> [cycles]`
（自动：SSH `reboot bootloader` → `fastboot boot` → 等 SSH → **核对 UTS** → 跑 `g1-22-dpms-test.sh` → 盯守 180s 判复位）。

手动等价序列：

```
ssh -o StrictHostKeyChecking=no root@192.168.7.1 'sync; reboot bootloader'
fastboot devices
fastboot boot out/boot-elden-sd-noN2.img
ssh root@192.168.7.1 'uname -r'          # 必须 == 期望 UTS，否则结果作废
scp scripts/g1-22-dpms-test.sh root@192.168.7.1:/tmp/
ssh root@192.168.7.1 'sh /tmp/g1-22-dpms-test.sh 5'
```

### 判据（每变体 ≥3 轮，长时窗）

| 指标 | 含义 |
|---|---|
| 是否复位 | `boot_id` 变化 / SSH 掉线后未回来 ⇒ 复位（硬复位回落 boot_b，UTS 会变回旧内核） |
| `vblank timeout` / `wait for commit done returned -110` 计数 | DPU 提交挂死（vk40 有、vk34 无的量化回归） |
| `UCSI PPM init failed` 计数 | pmic_glink 超时（同上） |
| `battmgr-usb ... -110` | 电源/ADSP 连锁超时 |

### 纪律（`PITFALLS` #102/#292、`G1-22`、`REBOOT-5MIN` §7.9）

- **单次观测无统计意义**（间歇性）——每变体 ≥3 轮 + 至少一轮持续熄屏 ≥90s。
- 上机期间 `idle-delay=0`，只用脚本内受控 DPMS off/on；`fastboot boot` **零写盘**，重启即回 b 槽。
- 不做未评估的持久系统改动（kmsg 钩子曾改变现象，已回退）。
- 每轮固定采集 `boot_id` 与 uptime，避免版本归属污染（历史上 boot_b 烧的就是 vk40）。

---

## 4. 待办

- [ ] 设备空闲后按 `sd-base`（确认对照可复现）→ `sd-noN2`/`sd-n2fix` → `sd-noN3` → `sd-noGC`/`sd-hz120` 顺序跑。
- [ ] 若全部不复位 → 转向 B 组既有改动（GPR 端口 `service@3/7`、`&usb` 角色、面板模式数组顺序）。
- [ ] 若 `sd-noN2` 有效 → 把「N2 载荷偏移」作为独立修复提交上游候选，并复查 `audioreach_alloc_apm_cmd_pkt` 的其他调用点偏移。
