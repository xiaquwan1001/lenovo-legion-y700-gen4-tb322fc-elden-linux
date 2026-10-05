# DRIVER-VERIFY-2026-10-06：驱动批次上机验证（vk53 DTS 破坏启动定位；**已按用户指示停止**）

> 承接 `MERGE-2026-10-05.md` Phase 1（设备独占、agent 执行 fastboot）。过程证据，只增不改；结论以 `TASKS.md`/`PITFALLS.md` 为准。
> **本轮中途用户指示「更新进度，不要继续」→ 以下为已得结论 + 未完成项**；设备已回 b 槽 vk47clean，未做任何持久写入。

---

## 0. 一句话结论

1. **`fastboot boot` 机制正常**（vk58c-slim 实测接管，`uname`=vk58）。
2. **vk53/vk54 的 DTS 改动会导致整机启动失败 → 复位回 b 槽**：重建的 vk59 内核（NFC+`FSA4480` 内建）+ **HEAD DTB** 无法接管；同内核 + **vk47 DTB** 正常启动。
   ⇒ **驱动批次的 vk53「未上机验证」若真刷入，会启动失败**。
3. 单变量初步：**只关 NFC 仍失败、只关 CDSP 仍失败**（各一变量不足以修复）；**ramoops 改动尚未单独验证**。
4. 设备基线确认：b 槽持久系统（vk47clean）+ greetd 会话 overhaul 已在线；`boot_b`=`0x7f` 健康。

---

## 1. 设备勘察（2026-10-05 深夜，只读）

| 项 | 值 |
|---|---|
| 单元 / 运行 | U2 / b 槽持久 Linux vk47clean（`7.2.0-debug-vk47clean-gbd114ca335e1`），`/`=`/dev/sda17`（linux17，193 GiB，用 9.1 G） |
| 会话 | greetd initial_session 生效：`loginctl` = **c1/root/seat0/tty7/active**（USERLAND-PKGS 路径 A 在线） |
| 亮度 API | `/sys/class/backlight/aw99706-backlight/brightness` 可写（idle-delay=0） |
| slot | `boot_b` byte6=**0x7f**（active=1/succ=1/retry=7/unbootable=0）；`current-slot=b` |
| 驱动基线（vk47clean） | 无 `/sys/class/typec`；无 i2c-0（NFC）；remoteproc 仅 adsp；`card0-DSI-1` only（**无 DP**）——与「vk53 待验证」一致 |
| TF | 无 `/dev/mmcblk*`（卡未在位） |

---

## 2. 方法与资产

- 主机侧修复 `scripts/build-boot.sh` / `scripts/build-manifest.sh`：**`KDIR` 现可 env 覆盖**（原来硬编码 `linux/`，导致想用外部 Image/DTB 打镜像时静默用错内核——本轮首版 vk59 即中了这个坑）。
- 版本登记：`versions/vk-registry.tsv` 补录 vk56–vk58（kexec R2 ad-hoc，未登记）+ 本轮 **vk59**（hw-driver）。
- 关键资产：
  - `out/boot-elden-vk59-slim.img` = 树内 vk59 内核（NFC/FSA4480 **内建**）+ HEAD DTB + 修复后 min initramfs。
  - `out/boot-elden-vk59a-slim.img` = **vk59 内核 + vk47 DTB**（能启动的对照）。
  - `out/boot-elden-vk59-nfcoff-slim.img` / `vk59-cdspoff-slim.img` = HEAD DTB 上单独关 NFC / 关 CDSP（**均仍失败**）。
  - `/tmp/dts-*.dts`、`/tmp/dtb-*` 为一次性变体（未入库）。

---

## 3. 上机矩阵（全部零写盘 `fastboot boot`；结果=运行 `uname`）

| 镜像 | 内核 | DTB | 结果 |
|---|---|---|---|
| `vk58c-slim`（R2 资产） | vk58 | vk47 | ✅ vk58 |
| 旧 vk59（从 vk53.img 抽内核） | vk53 | vk53 | ❌ 回 vk47clean |
| `vk59-slim` | vk59（树内，NFC+FSA 内建） | **HEAD** | ❌ 回 vk47clean |
| `vk59a-slim` | vk59 | **vk47** | ✅ vk59 |
| `vk59-nfcoff-slim` | vk59 | HEAD−NFC | ❌ 回 vk47clean |
| `vk59-cdspoff-slim` | vk59 | HEAD−CDSP | ❌ 回 vk47clean |

> 判读：**内核 config（NFC/FSA4480=y）不是原因**；**DTS 是原因**（vk47 DTB 一换就好）。DTS 三处改动 = ① ramoops（console 2M→1M + record 2M + max-reason）、② `&i2c0` NFC 节点 + 4 组 pinctrl、③ `&remoteproc_cdsp` firmware-name + `status=okay`。**①未测**；②③各自单独关闭都仍失败 ⇒ 可能是 ①，或 ②③**各自都足以**致挂，或需组合。

---

## 4. 未完成（续做时的最小步骤）

1. **ramoops-only 变体**：HEAD DTB 上把 ramoops 三个属性还原为 vk47（`console-size/pmsg-size=0x200000`、删 `record-size`/`max-reason`）→ `fastboot boot` 判是否修复。
   - 若修复 ⇒ 根因 = ramoops 属性（record-size 与 console/pmsg 合计须 ≤4 MiB？当前 1M+1M+2M=4M 恰满，疑边界/校验问题）。
2. 若仍失败 ⇒ 分别 **NFC-only**（vk47 DTB + 只加 NFC 节点）与 **CDSP-only** 二分，定位到具体 hunk。
3. 定位后再谈 G1-10/11 的真实上机验收；**在 DTS 修复前，vk53/vk54 不得作为「已实现」引用**。
4. 用户另要求：**init 稳固化**（启动时的挂载失败 / 找不到 `/bin` / VFS 告警）——见 §5。

---

## 5. init 稳固化（用户要求，未开工）

- 已见的启动告警分两类：
  - **min initramfs 阶段瞬态**：内核在无 `/lib/firmware` 的 RAM 根里探测外设（awinic 功放/触觉、novatek 触屏、ath12k），报 `Direct firmware load … failed -2`；`switch_root` 后（`/lib/firmware` 就位）多数自愈（ath12k 由 `ath12k-retry.sh` 恢复）。**非 init bug**，但刷屏且有误导性。
  - **历史 slim bug**：`Failed to execute /init (error -2)` → `No working init found` + VFS/panic 复位——**已由 #107 修复**（`/bin/sh` applet 符号链接）。
- 待办：给 `initramfs/init` 加健壮性（挂载失败显式报错/重试、`/bin`/applet 自检、`switch_root` 失败回退路径、把固件相关探测延后到 switch_root 后），并做一次真机冒烟。

---

## 6. 引用

- `MERGE-2026-10-05.md`、`KEXEC-ONDEVICE-R2-2026-10-05.md`（#107 slim bug）、`USERLAND-PKGS-2026-10-05.md`（会话 overhaul）。
- `TASKS.md` §1 G1-9/10/11、§4；`PITFALLS` #106/#107/**#108**；`versions/vk-registry.tsv` vk59。
