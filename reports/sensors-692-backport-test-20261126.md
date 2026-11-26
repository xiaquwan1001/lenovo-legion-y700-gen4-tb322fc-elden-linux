# 工单 S2 — fastrpc SENSORS_PD 回移试验核（传感器 #692 根因假设检验）· 2026-11-26

> 状态：**阶段一完成；阶段二两次上机完成；决定性测试 -s 未跑（第三班截止）；设备已回在机旧内核**（2026-11-26 22:2x 收尾轮复核）。
> 假说 A（SENSORS_PD 消息缓冲走 context bank ⇒ attach 即 SMMU fault）：**未判**（三次 boot 的 journal 里 `hexagonrpcd` 均 0 行 ⇒ 崩溃面从未触碰）。
> 过程台账 = `.pi/lanes/20261126-sensors-692-test.md`；证据 = `reports/artifacts/sensors-692-backport-20261126/`。
> 本文由 runner 截止（600 s 交割）写入，交割说明见 §5。

---

## 0. 结论先行

- **阶段一 PASS**：上游 1 行修复（lore `<20261003150559.6926-2-pc1598@mainlining.org>`，R-b Baryshkov）已回移进试验内核并出可上机 boot.img。
  门禁全绿：`git apply --check` rc=0；checkpatch **0E/0W**；`fastrpc.o` 编过（反汇编确认 `cmp #0x2`(SENSORS_PD) 分支在产物里）；符号守卫 OK；UTS 与在机可区分。
- **阶段二（上机）**：试验核已两次经 `fastboot boot` **零写盘**上机成功，`uname -r` = `7.3.1-debug-vk189-suspend-fastrpc1-g4da9a8b69fc8-dirty`。
  途中发现并修复一个**上机阻塞项**：试验 DTB 缺 D22/M10 的 `qcom,non-secure-domain`（ADSP fastrpc 节点）⇒ 首次 boot 只有 `/dev/fastrpc-adsp-secure`、无 `/dev/fastrpc-adsp`。已在 worktree 内补上该属性并重出 boot.img（现役在机件含此修复，属在机载荷的组成部分，非新增实验变量）。
- **决定性测试（`-s` 崩溃面）未执行** —— 两次上机（16:47 / 21:52，均 `fastboot boot` 零写盘）都只到「内核起来 + fastrpc 通道注册」就结束，第三班（21:52 那次）未跑任何 `hexagonrpcd` 命令；见 §7。设备已于 2026-11-26 22:18 前后回到在机旧内核（`…-00005-g4bdf1711b5c0`）。

## 1. 产物（全部真实存在）

| 产物 | 路径 | 身份 |
|---|---|---|
| 补丁（逐字 lore 原文） | `patches/local/fastrpc-sensorspd-20261126/0001-misc-fastrpc-Allocate-message-buffer-from-remote-heap-for-sensors-PD.patch` | Message-ID 同上；`-- ` 签名行 + 空行前导空格已按 /raw 校正 |
| 补丁 README（出处/为什么落 local） | `patches/local/fastrpc-sensorspd-20261126/README.md` | 上游未合入（torvalds master + gregkh char-misc 三处均无；patchwork handled-elsewhere） |
| 内核 worktree | `wt/fastrpc-sensorspd-test`（geekidos-linux @ `4da9a8b69fc8`，与 build/daily 同 commit；fastrpc.c 1 行 + sm8750.dtsi 1 行两处改动，**build/daily 未动**） | |
| Image / DTB / fastrpc.o | `wt/fastrpc-sensorspd-test/arch/arm64/boot/{Image.gz, dts/qcom/sm8750-lenovo-elden.dtb}`、`…/drivers/misc/fastrpc.o` | `uname -r` = `7.3.1-debug-vk189-suspend-fastrpc1-g4da9a8b69fc8-dirty`（CONFIG_LOCALVERSION 追加 `-fastrpc1`；`-dirty` 来自补丁） |
| **boot.img（现行有效件）** | `out/fastrpc1-20261126/boot-elden-fastrpc1.img` | sha256(O_DIRECT) = **`2050cf6c8bd93db8db3caa4414eb0020310250a5413cccc0f0c941b45ae4dc70`**；cmdline 含 `elden_root=LABEL=linux`（#728）+ `androidboot.slot_suffix=_b` |
| 早期（作废）boot.img | sha `8afee2bb…`（ramdisk=slim，RAM-only）与 `64bb10b5…`（首版） | 均被现行件覆盖/作废，勿用 |
| 载具 ramdisk | `out/ramdisk-vk189-extracted.cpio.gz`（sha256 `3282ae6c…` 前 8 位） | 从在机 `out/boot-elden-vk189.img` 提取（持久变体；`out/ramdisk-vk181-daily.cpio.gz` 已损坏——602 B 零前缀，**别再用**） |
| 构建日志 | `reports/artifacts/sensors-692-backport-20261126/{build-kernel.log, build-boot.log, build-boot2.log, build-dtbs2.log, snapshot-before.txt, postboot-state.txt, dmesg-fastrpc.txt}` | |

## 2. 阶段一判据实测

- `git -C build/daily apply --check <patch>` → rc=0（build/daily 与 worktree 同基线）。
- `build/daily/scripts/checkpatch.pl --no-tree <patch>` → **total: 0 errors, 0 warnings**。
- `CONFIG_QCOM_FASTRPC` m→y（olddefconfig 后保持 =y；fastrpc 符号进 System.map，零写盘 boot 无需模块树）。
- `objdump -d fastrpc.o`：`ldr w0,[x0,#8]`(sid)→`cbz`→remote-heap 路径；`ldr w0,[x26,#92]`(pd)→`cmp #0x2`→`b.eq` 同目标 = **补丁语义已入产物**。
- `scripts/build-boot.sh` assert 闸门 ✅（config 锚点/System.map/UTS 对齐/非陈旧 + ABI 27 项）。

## 3. 阶段二实测记录（截至交割）

1. **在机安全态快照（boot 前）**：`uname -r`=`…-00005-g4bdf1711b5c0`、is-system-running=running、--failed=0、phoc=1/phosh=1、`qbootctl -a`=`_b`、hexagonrpcd/iio-sensor-proxy 均 masked（`snapshot-before.txt`）。
2. `scripts/to-fastboot.sh`（#712 软路径）→ fastboot 上线（18 s / 6 s）→ `fastboot boot`（零写盘，逐条）rc=0，SSH ~10–15 s 回。
3. **第一次 boot（sha 8afee2bb…）**：新内核身份确认；但 `/dev/fastrpc-adsp` **缺失**（只有 `-secure` 变体）。根因：worktree 基线 4da9a8b 的 sm8750.dtsi ADSP fastrpc 节点无 `qcom,non-secure-domain`（fastrpc.c:2599 `secure_dsp = !(of_property_read_bool(...))` ⇒ 只注册 `-secure`）。在机内核含 D22/M10 修复 ⇒ 试验核需补齐才可比。
4. 补 DT 属性 → 重编 dtb → 重打 boot.img（sha **2050cf6c…**）→ 第二次 `fastboot boot` 成功，身份确认（进行中）。
5. 当前设备态（交割时）：试验核上，`is-system-running`=degraded（仅 `lxc-net`/`lxcfs` 两个失败 unit，属本机已知非阻塞项）、`qbootctl -a`=`_b`、**设备上已起取证通道** `nohup dmesg -w > /var/log/dmesg-fastrpc1.log`。**未跑任何 hexagonrpcd 命令**（#692 崩溃面未触碰）。

## 4. 交割后剩余工作（下一班按序执行）

1. （可选）确认 `/dev/fastrpc-adsp` 已出现（owner 任意，跑 root）：`ls -l /dev/fastrpc-adsp`；`qrtr-lookup | grep 400`；ADSP `remoteproc0/state`=running。
2. **测试 1（低风险）**：`timeout -k 5 30 /usr/libexec/hexagonrpc/hexagonrpcd -f /dev/fastrpc-adsp -d adsp`（**真二进制，别用 `/usr/bin/hexagonrpcd` wrapper——它默认追加 `-s` 和 fw_dir**，见 S 报告 §1.1）。存活 + journal 无 SMMU/remoteproc 异常 ⇒ 通道健康。
3. **测试 2（决定性）**：同二进制加 `-s`（不带 `-R`）。存活 ⇒ **假说 A 证实**（且与 served 内容无关）；崩 ⇒ 排除 A，指向 B/C。崩后按 #732 零写盘救援（设备自回 boot_b 旧内核；救援件注意 cmdline LABEL=linux，#728）；记录「崩前最后一条成功命令 + 崩后自回时间」+ 取 `/var/log/dmesg-fastrpc1.log`。
4. 若测试 2 存活：测试 3 `-R /var/lib/droid-juicer/sensors`（布局不匹配，只记现象，S 报告 §2）。
5. 收工门：`is-system-running`（允许 degraded，逐条列 failed 并归类）、phoc/phosh 各 1、`qbootctl -a`=`_b`；恢复态后**重启设备回在机内核**（`ssh elden-root 'reboot'`）或如实记录试验核驻留；`device-lock` 释放；报告补全「假说 A 证实/否证/未判」二值结论。
6. 若 `-s` 仍崩：停手，按 S 报告 §6.3 止损（建物理 UART 后才许继续），并在 hexagonrpc #19/lore 线程补设备样本（发信按放行口径）。

## 5. 现场安全说明（交割时点）

- 设备经 `fastboot boot` **零写盘**进试验核：**任何重启/崩溃都会自然回到 boot_b（在机旧内核）**，无需救援件。
- 全程未 enable/unmask 任何 `hexagonrpcd*`/`iio-sensor-proxy`；未写任何分区；未 git commit。
- `build-slot` 已 drop（id `154949-2539415-y700-elden_fastrpc-sensorspd-test`）；`device-lock` 已释放（free）。
- 试验 boot 后 `--failed` 仅有 `lxc-net`/`lxcfs`（模块树缺失的连带，非 #692 面；其余服务正常，SSH/桌面链路活）。

## 6. 复现命令（阶段一最小链）

```sh
P=patches/local/fastrpc-sensorspd-20261126/0001-misc-fastrpc-Allocate-message-buffer-from-remote-heap-for-sensors-PD.patch
git -C build/daily apply --check "$PWD/$P"                     # rc=0
build/daily/scripts/checkpatch.pl --no-tree "$P"               # 0E/0W
# worktree：git -C /home/xuqianhui/elden-cache/src/geekidos-linux worktree add --detach wt/fastrpc-sensorspd-test 4da9a8b69fc85
#   + apply $P + sm8750.dtsi adsp fastrpc 节点加 qcom,non-secure-domain（D22/M10）+ config: QCOM_FASTRPC=y, LOCALVERSION+=-fastrpc1
. scripts/env-build.sh && KDIR=$PWD/wt/fastrpc-sensorspd-test JOBS=12 scripts/build-kernel.sh Image.gz dtbs
KDIR=$PWD/wt/fastrpc-sensorspd-test VERSION=fastrpc1 RAMDISK=$PWD/out/ramdisk-vk189-extracted.cpio.gz bash scripts/build-boot.sh
sha256sum out/fastrpc1-20261126/boot-elden-fastrpc1.img    # 2050cf6c…（O_DIRECT 值以 build-boot2.log 为准）
```


## 归档位置更正（父代理，2026-11-26T10:4xZ）

`out/boot-elden-fastrpc1.img` **已移到** `out/fastrpc1-20261126/boot-elden-fastrpc1.img`（sha256 `2050cf6c8bd93db8db3caa4414eb0020310250a5413cccc0f0c941b45ae4dc70`）。
原因：`check-doctor` §5 扫 `out/*.img` 顶级文件，未登记件会报 `[FAIL] 内核身份表已过期`；本项目惯例是把出件放进带日期的子目录（同 `out/gunyah-wdt-20261125/`）。
**注意**：该核的结论未变——试验核只注册 `/dev/fastrpc-adsp-secure`、**没有 `/dev/fastrpc-adsp`**，`-s` 假说 A 未判；下一步要么补 `qcom,non-secure-domain` 到试验 DTB 重编，要么改用「在机 vk192 + 模块方式」验证。

---

## 7. 收尾轮（父代理，2026-11-26T14:2xZ / CST 22:2x；网关额度中断后）

**独立重跑的事实（不采信上轮叙述）**：

| 项 | 现查 | 判据/命令 |
|---|---|---|
| 设备当前内核 | `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`（在机旧核，非试验核） | `ssh elden uname -r` |
| 试验核上机记录 | journal `boot -1`（21:52:37 起，`fastrpc1-g4da9a8b69fc8-dirty` 内核串） | `journalctl -b -1` |
| `-s` 崩溃面 | **三次 boot 全部 `hexagonrpcd` 0 行** ⇒ 决定性测试从未跑（boot -1/-2/0：0/0/0） | `journalctl -b $b \| grep -ic hexagonrpcd` |
| 补丁语义在试验核产物内 | `boot -1` 有 `qcom,fastrpc 6800000.remoteproc:…: assigned reserved memory node adsp-rpc-remote-heap`（RPC remote heap 被认领）+ SMR `mask out of range` 警告（cb 自带、与补丁无关，旧核同样有） | 证据 = `reports/artifacts/sensors-692-trial-20261127/journal-b-1-fastrpc.txt` |
| `/dev/fastrpc-adsp` 是否出现 | **无记录**（-s 测试前未采集 `ls -l /dev/fastrpc-adsp`）⇒ 「补 DTB 后是否成功注册非 secure 节点」仍未实证 | — |
| 设备安全态 | systemd `--failed`=0；`phoc`/`phosh` 各 1；`hexagonrpcd`/`iio-sensor-proxy` = masked；slot `_b` | 22:22 CST 快照 |
| 产物归档 | 证据 3 件 → `reports/artifacts/sensors-692-trial-20261127/`；boot.img+manifest → `out/fastrpc1-20261126/`（O_DIRECT 两读一致 sha `2050cf6c…`）；已登记 `versions/out-candidate-sha.tsv` | 探针见本文件 §1 |

**结论**：S2 工单的价值停在「补丁 + DTB 修复 + 可上机件已备好、两次零写盘上机验证内核可起」。**假说 A 依旧是未判**，不是否定。

**下一班的最小剩余动作**（不需重建）：
1. `fastboot boot out/fastrpc1-20261126/boot-elden-fastrpc1.img`（sha `2050cf6c…`，已含 `qcom,non-secure-domain`）。
2. 上机后先取证 `ls -l /dev/fastrpc-adsp /dev/fastrpc-adsp-secure`、`qrtr-lookup | grep 400`、`remoteproc0/state`（**这三个必须先于 -s 采集**，本轮就是漏了这一条使得 DTB 修复效果无实证）。
3. 再跑 §4 测试 1/2（`timeout -k 5 30 /usr/libexec/hexagonrpc/hexagonrpcd -f /dev/fastrpc-adsp -d adsp`，真二进制不带 wrapper）。
4. 崩则按 #732 零写盘自回；不崩则假说 A 证实、进入 hexagonrpc 侧写支持讨论。
