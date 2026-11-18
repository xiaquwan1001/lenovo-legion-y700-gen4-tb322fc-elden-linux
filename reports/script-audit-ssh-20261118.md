# 脚本审查 R4 — ssh / 部署板块（只读静态审查）

- 日期：2026-11-18
- 范围：`scripts/lib-ssh.sh`、`lib-boot-ready.sh`、`lib-wait.sh`、`lib-serial-source.sh`、`deploy-*.sh`（8 个）、
  `mesa-deploy.sh`、`device-window-collect.sh`、`esp-install-grub.sh`、`esp-put-loader.sh`、`grubenv-set.sh`、
  `waydroid-haptics-aidl-deploy.sh`、`win-x86-rootfs.sh`、`devlogs.sh`（**共 20 个主件**；另加 1 个跨板块的 `flash-b.sh`）；
  统计口径扩到 `scripts/**` + 仓根 250 个 `.sh`。
- 方法：`read`/`grep`/`python` 静态读码 + 与 `PITFALLS/`、`.pi/memory/`、`reports/script-audit-20261105.md` 交叉核对。
  **全程零设备接触**（未执行 ssh/scp/adb/fastboot/qdl/edl.py；本次审查期间设备可能处于 fastboot + 槽属性污染态）。
- 建议补丁：`/tmp/script-audit-ssh.patch`（7 文件 / 19 hunk，`git apply --check` 通过；未改动仓库）。
- 并行说明：审查期间另有轮次在改 `scripts/{flash-b,slot-attr,eldroid-bootctl,kexec-boot,to-fastboot,trial,
  uefi-ddr-trial,uefi-flashed-trial,fix-ab-mark-successful,lib-fastboot}`。本报告的补丁**只覆盖那 7 个未被他轮改动的文件**；
  `flash-b.sh` 的 A/B 槽缺陷他轮已在修，本报告只列其**残留缺口**（见 §6）。

---

## 0. 结论（先数字）

| 级别 | 条数 | 一句话 |
|---|---|---|
| **P0** | **4**（3 本板块 + 1 跨板块） | 3 条都会把「下次开机/下次实验」直接打成无效或不可引导：非原子覆盖引导件、非原子写 grubenv、原地解包进在用模块树；1 条是 b 槽 succ 不置位（他轮在修） |
| **P1** | **12** | 挂死/假绿/半部署：无 BatchMode 无超时的 ssh 热点 6 条、退出码被丢 3 条、破坏性操作无回退 3 条 |
| **P2** | **15** | 口径漂移、清理缺失、校验抽样过窄、备份名固定、busybox 不兼容等 |

**选项统一（核心统计）**

| 指标 | 数值 |
|---|---|
| 走 `lib-ssh.sh` 的消费脚本 | **1 个**（`q32-arm.sh` → `lib-boot-ready.sh` → `lib-ssh.sh`） |
| 出现 ssh/scp 的脚本总数 | **77**（`scripts/**` + 仓根，共 250 个 `.sh`） |
| ⇒ lib 采纳率 | **1/77 = 1.3%**（11-05 审计立的 lib 事实上没被采纳） |
| 字面 ssh/scp 调用点 | **144** |
| **完全没有任何 `BatchMode` 的文件** | **17 个 / 61 处调用 = 42%** ← 首次连接会停在 host-key/密码提示挂死 |
| 调用点未套 `timeout` | **93 / 144 = 65%** |
| 主件 20 个文件中：无 BatchMode | 6 个（`deploy-zh-ime`、`deploy-sensors-hal`、`deploy-sensord-routec`、`mesa-deploy`、`win-x86-rootfs`、`devlogs`） |
| 主件中：ssh 无 `timeout` 包裹 | 12 个（上述 6 个 + `deploy-modules`、`deploy-camera-modules`、`deploy-v4l2loopback`、`deploy-sensord-routec-debian`、`esp-install-grub`、`esp-put-loader`、`grubenv-set`、`waydroid-haptics-aidl-deploy`） |
| 用 `-n` 的调用点 | **1**（`slot-switch.sh:139`；`lib-ssh.sh` 补丁后才有第 2 处） |
| 设备侧用 `bash -s`（违反「设备侧只写 POSIX sh」） | 主件内 4 处（`deploy-zh-ime.sh:36,49,73,97`），全仓 20+ 处 |

**关键判断：`lib-ssh.sh` 是好的，但它在生产路径上等于没被采用。** 11-05 审计把「53 处内联 ssh、7 种写法」收进 lib，
结论是「不带 BatchMode 的会卡在密码提示」（`reports/script-audit-20261105.md` §2.3，即 `PITFALLS` 同族结论，非推断）；
13 天后实际仍有 **61 处** 处于该状态，**其中 6 个是 hand-run 的 deploy 脚本**（最常被 agent 直接执行的形态）。

---

## 1. P0（4 条）

### P0-1 `scripts/esp-install-grub.sh:45,57-61,67-68` — 非原子覆盖 ESP-first 引导件，且无身份/空间/读回校验

- **触发**：`--activate`（默认 stage 不触发）。设备侧 `cp EFI/grub/grub-$TAG.efi EFI/BOOT/BOOTAA64.EFI` 是**原地截断写**。
- **后果**：`cp` 中途 ENOSPC / 掉电 / USB 断 → `BOOTAA64.EFI` 变成半个文件；ESP-first 路径（`DEVICE/README.md:148`
  「Mu UEFI → 优先起 ESP 的 `\EFI\BOOT\BOOTAA64.EFI`」）此时既没有旧件也没有完整新件 ⇒ **设备无引导**，只能 EDL/fastboot 救。
  更隐蔽的一层：`ESP=/dev/sda18` 是**硬编码分区号**，脚本不校验它是否还是那个 vfat 的 `eldenesp`
  （`DEVICE/README.md:359`；11-17 已发生过 LUN0 GPT 回刷导致 `linux17`/`eldenesp` 条目丢失，`reports/android-min-avb-facts-20261118.md:387` R2）
  ⇒ GPT 重排后 `mount /dev/sda18` 可能挂到**别的分区**并把引导件写进去。
- **严重度**：P0（唯一会直接造成「不开机」的一条）。
- **修法**：写前 `[ -b $ESP ]` + `blkid -s TYPE -o value` 必须是 vfat + `df` ≥8 MiB；写 `.new` → `sync` → `mv -f`（原子改名）；
  写后读回 sha 与主机 `$sha` 比对，不一致即 exit 1 并打印 `--rollback`。→ 已含在补丁里。

### P0-2 `scripts/grubenv-set.sh:24-43` — 原地截断写 1024 B grubenv，无备份、无 fsync、无长度校验

- **触发**：任何一次改 `elden_arm`（Q28 冷起 A/B 切臂就是靠它，脚本头注释写明「不必重打 EFI」）。
- **后果**：`io.open(path,"wb").write(out)` 直接截断原文件 —— ① 写一半掉电/被 reboot 打断 ⇒ 下次开机 GRUB `load_env`
  读到坏 env（切错臂或回默认臂），而判据只看「起来的是哪个内核」，会记成「臂没生效」而不是「文件坏了」；
  ② `out += b"#" * (1024 - len(out))` 在 kv 内容 >1024 B 时变成 `b"#" * 负数 = b""` ⇒ **静默写出不足 1024 B 的文件**，
  退出码 0；③ 没有任何备份 ⇒ 无法回到上一个 arm 值。
- **严重度**：P0（决定下次开机走哪条臂，且失败无痕）。
- **修法**：先写 `path.bak-grubenv-set`；超 1024 B 直接 `sys.exit`；写同目录 `.new` → `fsync` → 读回断言正好 1024 B 且逐字节相等 →
  `os.replace` → 目录 fsync。→ 已含在补丁里。

### P0-3 `scripts/deploy-modules.sh:101-112` — 直接解包进**在用**的 `/lib/modules/$UTS`，无 staging、无 UTS 门、无 vermagic 门

- **触发**：任何一次 `deploy-modules.sh --from/--bundle`（`mod-loop.sh`、`deploy-camera-modules.sh --bundle` 都走它）。
- **后果**：① `tar xzf ... -C /lib/modules/$UTS` 直接铺到**正在使用**的目录：中断（timeout/拔线/`timeout` 命中）留下
  新旧混合的模块集，`depmod` 随后按混合集重建依赖 ⇒ 下次启动 `=m` 驱动按 depmod 结果 defer，
  正是项目记忆里「RAM 起新核前必须先部署整套 `/lib/modules/<UTS>`」那条铁律的反面；
  ② **不校验 `$UTS == 设备 uname -r`**（`deploy-camera-modules.sh:38-42` 有这道门，统一实现里没有）⇒ 用错树的模块覆盖在役目录；
  ③ 无 vermagic/ABI 门（`PITFALLS #367`：struct 漂移 ⇒ fastrpc 死循环 + `/dev/fastrpc-*` 全缺 + 传感器全废），
  而 `--verify` 只 `shuf -n3` 抽样 3 个 `.ko` 的 sha。
- **严重度**：P0（一次中断就制造「半部署」状态，且看起来是「部署成功」）。
- **修法**：解包到 `/lib/modules/$UTS.new.$$` → 校验 `.ko` 数 + 抽样 sha → `mv` 旧目录到 `.old` → `mv` 新目录就位 → `depmod`；
  入口加 `[ "$UTS" = "$($SSH uname -r)" ]` 或显式 `--allow-foreign-uts`（写明用途）；`--verify` 改全量 sha（tar 内清单 vs 设备 `sha256sum -c`）。

### P0-4（跨板块，他轮在修）`scripts/flash-b.sh` — 写 `boot_b` 后不置 `BOOT_SUCCESSFUL`

- **触发**：`flash-b.sh --reboot`（b 槽刷机主路径）。
- **后果**：ABL 每次启动扣 `tries_remaining`（`scripts/slot-attr.py:1-22` 权威位定义），不置 bit6 就一路扣到 0 并自标
  `UNBOOTABLE(0x80)` ⇒ ABL **直接拒绝执行该槽**，之后所有「刷了能不能起」的实验都在污染态下做（`PITFALLS #181`、`#672`；
  `#672` 就是 11-18 三发试装全废的直接原因）。本次审查时他轮已加入 `mark-successful` 与写前基线打印。
- **残留缺口（他轮未覆盖）**：① `SSH_OPTS` 仍无 `BatchMode`（`flash-b.sh:40` 一带）；② 读回长度仍硬编码
  `dd if=$D bs=1M count=96`，镜像尺寸一变即永久 MISMATCH；③ `dd of=$D` 不带 `count`，镜像 > 分区会越过分区尾。
- **修法**：`o BatchMode=yes`；读回 `count=$((IMG_SZ/1048576+1)) | head -c $IMG_SZ`；写前 `blockdev --getsize64` 与镜像尺寸比对。

---

## 2. P1（12 条）

| # | file:line | 触发条件 | 后果 | 一句修法 |
|---|---|---|---|---|
| P1-1 | `deploy-zh-ime.sh:23-33,36,49,73,97`（11 处） | 任何一次执行；**连 `-o` 选项都没有** | 首次连接停在 host-key/密码提示 ⇒ 挂死；远端命令无超时 | 统一 `SSHOPTS=(-o BatchMode -o ConnectTimeout=5 …)` + `timeout`（补丁已做） |
| P1-2 | `deploy-zh-ime.sh:97-121` | 验证段最后一条是 `echo "小计 ok=… fail=…"` | ssh 返回 0，`fail>0` 也 rc=0 ⇒ 「IMPORT 全绿」假象（只看退出码 = 假绿） | 远端 `[ "$fail" = 0 ] \|\| exit 1`（或在主机侧 grep `fail=0`） |
| P1-3 | `mesa-deploy.sh:19-20,29,32` | 设备上 `/root/wd` 不存在（新机/清过 `/root`） | `scp` 目标目录缺失 ⇒ 首跑必失败；4 处 ssh/scp 无选项无超时 | `sshc "mkdir -p $REMOTE_TMP"` + 统一选项/`timeout`（补丁已做） |
| P1-4 | `deploy-sensord-routec.sh:24-27` | 设备无网络或 apk 源不可达 | `apk add … \|\| true` 吞掉失败 → 后续 `make` 失败退出，但 `waydroid-sensors` **已被 del** ⇒ 传感器 HAL 全无（回退要再联网 `apk add`） | 先建产物再 `apk del`；del 前记下包名/版本到 `/root/wd-sensord-del.log` |
| P1-5 | `deploy-sensord-routec-debian.sh:79-81` | 每次执行第 4 步 | `XDG_RUNTIME_DIR=/run/user/1001` 而会话 uid=**1000**（`.pi/memory/failures-device.md:87`）⇒ `waydroid session start` 必失败，但它在 `&` 里，rc 不可见，脚本照样 `say done` rc=0 | 改 `/run/user/1000`；失败判据用 `lxc-info -p` + `getprop sys.boot_completed` 且非空才算成功 |
| P1-6 | `deploy-sensord-routec-debian.sh:34,38` | `apt-get install` 遇 dpkg lock/网络黑洞 | `rsh()` 无 `timeout` ⇒ 永久挂（全局硬规则 3） | `rsh() { timeout "${STMO:-600}" ssh …; }` |
| P1-7 | `deploy-v4l2loopback.sh:52-59` | 编译期间 Ctrl-C / `kill` / 外层 timeout | 只还原「make 成功返回」与「make 失败分支」两条路 ⇒ 中断后 `$KSRC/include/generated/utsrelease.h` 永久是**设备 UTS**，之后该树每次构建都产错 vermagic 且看不出来；`.bak` 名固定 `/tmp/.v4l2-*.bak` ⇒ 再跑一次就把污染件当「原件」备份，**不可逆** | `trap … EXIT INT TERM` + 备份名带 `$$`（补丁已做） |
| P1-8 | `deploy-v4l2loopback.sh:72-81` | 模块仍被 gst/容器占用 → 远端 `exit 3` | 主机侧不检查 rsh 返回码，照样 `say done`、脚本 rc=0 ⇒ 「换了模块」假象 | `rsh '…' \|\| exit 3`（补丁已做） |
| P1-9 | `device-window-collect.sh:26-36` | 任一 gate 失败（设备不在 Linux、分区名失效） | `gate()` **无条件 `return 0`**，且 `exit 0`；采集包与正常包无法区分 ⇒ 取证报告里「没有异常」= 没采到（C 类假绿） | 记录 `GATE_FAIL` 并在结尾 rc=1（补丁已做） |
| P1-10 | `device-window-collect.sh:34` | 不在仓根 CWD 执行 | `scripts/device-lock.sh` 是**相对路径** ⇒ 直接 "No such file"，所有 gate 静默失败（又被 P1-9 掩盖） | 用 `"$ROOT/scripts/device-lock.sh"`（补丁已做） |
| P1-11 | `deploy-camera-modules.sh:28-29,41,46` | 首次连接 / `.config` 缺失 | `SSH`/`SCP` 无 BatchMode、无 timeout（可挂死）；ABI 门 **fail-open**（找不到树只 WARN 就继续）⇒ `PITFALLS #367` 那一类崩溃可直接上机，而该崩溃的后果是「无 `/dev/fastrpc-*` + rpmsg 死循环」 | 补 BatchMode+timeout；ABI 门改 fail-closed（`SKIP_ABI_ASSERT=1` 显式才放行） |
| P1-12 | `devlogs.sh:20,27-38` | `devlogs.sh pull`（agent 取证最常用） | 无 BatchMode ⇒ 可挂死；远端一条命令里 `dmesg` + `cat /var/log/*.log` 全量输出**无超时**，日志大或含 FIFO 时永不返回 | 加 `BatchMode` + `timeout`；`for f in /var/log/*.log` 改成按大小过滤（`find -size -2M`） |

---

## 3. P2（15 条）

1. `esp-put-loader.sh:26` — `ESP_LABEL=ELDENESP` **声明了但全文再没用到** ⇒ 分区身份校验形同虚设（也是 P0-1 同族）。
2. `esp-put-loader.sh:89-92` — `df --output=avail -k` 是 coreutils 专有；busybox `df` 无 `--output`（现役根是 Debian，`DEVICE/README.md:391`，
   所以今天不炸；但与仓内「设备侧 POSIX」口径冲突，且 `linux18` Alpine 回退根已删 ⇒ 一旦换根就硬失败）。改 `df -k . | awk 'NR==2{print $4}'`。
3. `esp-put-loader.sh:52-62` — `--verify` 分支 `exit $?` 取的是**最后一条 `umount` 的 rc**，不是采集结果 ⇒ 「读不到 ESP」也 rc=0。
4. `esp-put-loader.sh:100-112` — `cp -f /tmp/esp-boot.img $ESP_MNT/boot/boot.img` 非原子（同 P0-1 机理，但坏的是被 chainload 的 boot.img，不致命）。
5. `esp-install-grub.sh:49-51` — `--rollback` 取「mtime 最新的 `.bak`」，不记 sha、不校验 ⇒ 无法证明回滚到的是哪个版本；应以 tag+sha 建清单。
6. `esp-install-grub.sh:45,68` — 若 `/mnt/esp` **已被别的进程挂着**，脚本结束时无条件 `umount` ⇒ 卸掉别人的挂载点（`esp-put-loader.sh:86` 反而做了 `umount … || true` + `mountpoint -q` 复核，两者口径不一致）。
7. `grubenv-set.sh:19` — `--show` 不校验长度/不提示坏文件（1001 B 的 grubenv 也照样 grep 出内容）。
8. `deploy-modules.sh:103-109` — 每次部署都在 `/var/tmp` 留一份整套模块备份（数百 MB），**无保留策略/无清理**；重复部署 N 次 = N 份。
9. `deploy-modules.sh:119-125` — 校验只 `shuf -n3` 抽样 3 个 `.ko`；`--verify` 用 `--no-verify` 可整体关掉，但**没有任何地方提示「本次未校验」**。
10. `deploy-zh-ime.sh:36,49,73,97` — 设备侧 `bash -s`（4 处）+ `pkill -f elden-ime-focusd`（`:86`）：违反「设备侧只写 POSIX sh」；
    `pgrep -x phosh | head -1` 取不到 pid 时 `/proc//environ` 静默失败 ⇒ `BUS` 为空、后续 `gsettings` 全部 `|| true` 空转。
11. `deploy-zh-ime.sh:64-66` — 覆盖用户级 `~/.config/autostart/*` 与 `~/.local/share/applications/*` **不留备份**（`install -o` 直接覆盖）。
12. `deploy-sensord-routec.sh:30,42-44` — 设备上留 `/root/sensord-routeC` 源码 + `scp` 的 3 个件，无清理；`scp` 无 `ConnectTimeout`。
13. `mesa-deploy.sh:29,35` — `/root/wd/mesa-new` 每次 `rm -rf` 重铺，无清理策略；被 scp 的 `waydroid-mesa-swap.sh` 用了 bash 数组与 `pipefail`（设备侧非 POSIX）。
14. `waydroid-haptics-aidl-deploy.sh:22,43-44` — `SSH` 只有 BatchMode、**无 ConnectTimeout/无 `timeout`**；`cp -n $CFG $CFG.bak-…` 备份名固定 ⇒ 第二次跑不再备份（第一次的备份可能已被覆盖改动）。
   另：`:43` 先 `kill -9` 容器再上传，**任一步失败即把设备留在「容器停着」状态**，脚本非零退出但不恢复、不提示（见 §4 A 类）。
15. `lib-boot-ready.sh:69,88` — 库函数里 `exit 3/4`（sourced 场景会连带杀掉调用方），无法当布尔门用；`lib-wait.sh` 全部用 `timeout 8` 而非 `timeout -k`（全局硬规则 3 的 `-k` 口径）。

---

## 4. A/B/C/D/E/F 专项（用户点名的两类）

### A. 失败标志清理 —— 本板块 **0/20** 有「实验前先 show、失败路径也留」

本板块 20 个主件里**没有一个**写 `boot_a/boot_b` 或切槽，所以「槽属性」这一层风险 = 0。
但**改引导路径**的两条（`esp-install-grub.sh`、`grubenv-set.sh`）与「停容器」的一条（`waydroid-haptics-aidl-deploy.sh`）
都属同类失败状态，判定如下：

| 脚本 | 实验前先读现值？ | 失败路径留痕？ | 失败后复位？ | 判定 |
|---|---|---|---|---|
| `esp-install-grub.sh` | ❌ 不读 `/EFI/BOOT/BOOTAA64.EFI` 现值/sha | ⚠ 打印了 sha 但**不与主机比对** | ❌ 无自动回滚（`--rollback` 需人工） | P0-1 |
| `grubenv-set.sh` | ❌ `--show` 存在但不自动调用 | ❌ 原值无备份 | ❌ 无 | P0-2 |
| `waydroid-haptics-aidl-deploy.sh` | ❌ 不记录容器原本是否在跑 | ⚠ 只打印 stopped | ❌ 失败留容器停着 | P1-14 |
| 其余 18 个 | 读操作 / 纯主机侧 | — | — | 无 |

**跨板块统计（同类缺陷的真正重灾区，供编排者排期）**：`scripts/**` 里**有上机动作**（`flash boot_*` /
`dd of=…by-partlabel/boot_*` / `reboot bootloader` / `reboot -f` / `reboot2` / `/proc/sysrq-trigger` / `eldroid-bootctl reboot`）
的脚本 **30 个**，其中出现 `mark-successful` / `slot-attr.py` / `qbootctl` 的只有 **6 个**
（`f2fs-migrate.sh`、`flash-b.sh`（他轮刚加）、`slot-switch.sh`、`suspend-boot-panic-capture.sh`、`uefi-ddr-trial.sh`、`uefi-flashed-trial.sh`）；
**24 个 0 覆盖**，含 `to-fastboot.sh`、`q28-por-rounds.sh`、`q32-arm.sh`、`uefi-boot-trial.sh`、`uefi-a-slot-prepare.sh`、
`uefi-r21-sbstop-ladder.sh`、`kexec-diag-test.sh`、`n5b-vk64-death-rate.sh`、`switch-kernel-abi.sh`、`slotboot-run.sh`。这正是 `#672` 的机器化根因：**任何一发「刷/重启但没置 succ」都在扣 b 槽重试预算**。
处置建议：在 `scripts/lib-fastboot.sh`（他轮正在加）里做成默认钩子，而不是逐个脚本加。

**misc BCB / pstore 陈旧**：本板块脚本无一读/写 `misc`；`device-window-collect.sh:49` 读 `boot_b` 但不读 `misc`
⇒ 「ABL 为何进 fastboot」这一类判读缺一条证据（建议补 `gate`：`dd if=/dev/disk/by-partlabel/misc bs=1M count=1 | strings`）。

**留在 9008/fastboot 却 return 0**：本板块无 fastboot 调用（`lib-wait.sh:113` 有 `wa_fastboot_alive`，是探测）；
`esp-*` 系列不碰 fastboot。**结论：该风险在本板块 = 0。**

### B. GPT 分区核对 —— **2/21 有，且都不完整**

| 脚本 | 分区存在 | 落哪个 LUN | 尺寸 ≥ 待写 | 主备表/CRC | 覆盖冲突 | 判定 |
|---|---|---|---|---|---|---|
| `esp-install-grub.sh` | ❌ | ❌（硬编码 `/dev/sda18`，无 label 校验） | ❌ | n/a（只写文件） | ❌ | **P0-1** |
| `esp-put-loader.sh` | ⚠ `[ -b $ESP_PART ]` 隐含 | ❌（`ESP_LABEL` 声明未用） | ✅ 空间 ≥ 总量+16 MiB | n/a | ❌ | **P0-1 同族 + P2-1** |
| `device-window-collect.sh:49` | ❌（`dd` 失败被 `2>/dev/null` 吞） | ❌（`by-partlabel` 不打印解析结果） | ❌（未断言 96 MiB/实际容量） | n/a（只读） | n/a | **P1-9/P1-10 同族** |
| 其余 18 个 | 不写分区 | — | — | — | — | 无风险 |

- 本机 **4096 B 逻辑扇区**、`boot_*` 在 **LUN4 `/dev/sde`**（sde12/sde45）而 ESP 在 **LUN0 `/dev/sda18`**：
  本板块 3 个涉及分区的脚本**全部硬编码 `/dev/sdaNN`**，没有一个走 `by-partlabel` + `readlink -f` 复核。
- `linux` 起点 LBA 90504 = 原 `super` 起点这类覆盖冲突：本板块不写表，**n/a**，但 `esp-put-loader` 的
  `ESP_MNT=/mnt/esp` 默认挂载点与 `esp-install-grub` 共用 ⇒ 两个脚本并发跑会互卸挂载点（P2-6）。

### C. 写后校验

| 脚本 | 读回 sha | 只信退出码 |
|---|---|---|
| `esp-put-loader.sh` | ✅ 主机 sha vs 设备 sha 逐字节比对 + `fsck.vfat -n` | — |
| `esp-install-grub.sh` | ❌ **只打印不比对** | ⚠ 依赖远端 `set -e` | **P0-1** |
| `deploy-modules.sh` | ⚠ 抽样 3 个 `.ko` | ⚠ `dev_n -ge local_n` 只是数量 | P2-9 |
| `grubenv-set.sh` | ❌ 无读回 | ✅ 只信 python 正常返回 | **P0-2** |
| `deploy-v4l2loopback.sh` | ⚠ 只看 `ls -l /dev/video100` | ❌ 远端 rc 被丢 | P1-8 |
| `deploy-zh-ime.sh` / `deploy-sensord-routec*.sh` / `mesa-deploy.sh` | ❌ 无 | ⚠ | P1-2/P1-5 |
| `device-window-collect.sh` | n/a（取证） | ❌ rc 全丢 | P1-9 |

设备侧 `sha256sum`（设备算摘要）只在 `esp-put-loader`、`deploy-modules`、`flash-b` 用了 —— 这是 `PITFALLS #669`
（「用设备端 sha256 当第二把尺子」）的正确形态，本板块**没有把主机侧 `sha256sum` 冒充成设备侧校验**的实例。

### D. 超时 / 串行 / ssh+fastboot 混用

- `timeout -k`：**0 处**（全用 `timeout N` 单参数；`lib-wait.sh`、`lib-ssh.sh`、`deploy-bt-suspend-guard.sh` 亦然）。全局硬规则 3 要求 `-k`。
- `device-lock.sh`：本板块 **1 个**脚本用（`device-window-collect.sh`，且路径写错 P1-10）。8 个 `deploy-*` + `mesa-deploy`
  **全部不持锁** ⇒ 两个 agent 同时 deploy 会交错写 `/lib/modules`、`/var/lib/waydroid/overlay`（`deploy-modules.sh:8` 只写「调用方负责」）。
- **同一条命令里混用 ssh 与 fastboot（#584）**：本板块 **0 例**。全仓只有 6 行同时出现两词，都是「先 ssh 再 wait_fastboot」的
  **两条独立命令**（`cycle.sh:23` 等），不构成 #584 的 `fastboot | grep -q` 形态。**本项无缺陷。**

### E. 回退（是否可执行）

| 脚本 | 回退件 | 回退步骤可执行？ |
|---|---|---|
| `esp-put-loader.sh` | 无自动备份（靠手头旧件） | ✅ 末尾打印了旧件路径 |
| `esp-install-grub.sh` | ✅ `BOOTAA64.EFI.$TAG.bak` | ⚠ `--rollback` 按 mtime 猜（P2-5） |
| `grubenv-set.sh` | ❌ | ❌ **无回退路径** |
| `deploy-modules.sh` | ✅ `/var/tmp/modules-backup-<UTS>-<ts>.tar.gz`（`/var/tmp` 非 tmpfs，`rootfs/persistent-overlay/init:108` 只把 `/tmp` 挂 tmpfs ⇒ 重启后仍在） | ⚠ 但若半部署导致**起不到 Linux**，备份与设备一起不可达 |
| `deploy-v4l2loopback.sh` | 无 | ✅ 头注释给了 `rm … && depmod -a` |
| `mesa-deploy.sh` | ✅ `config_nodes.bak-<ts>` + bind-mount 设计（不改镜像） | ✅ `--rollback` 可执行 |
| `waydroid-haptics-aidl-deploy.sh` | ✅ `config.bak-elden-haptics-aidl`（`cp -n`，只备一次） | ✅ 删两行 mount.entry |
| `deploy-sensord-routec.sh` | ❌ 无（`apk del` 不可逆，除非联网重装） | ⚠ 头注释只给一行命令 |
| `win-x86-rootfs.sh` | ❌ 无（`/root/glibc-rootfs` 就地覆盖） | ❌ 无 |

本板块**没有**用到已被推翻的 `fastboot set-active=a` 口径（`.pi/memory/failures-kernel.md:141` ④：`qbootctl -s` 会走 UFS boot-LUN 切换，本项目不适用）——
`slot-switch.sh:139` 走的是 `qbootctl -m b`（mark-successful），符合现行口径。

### F. 幂等与重入

| 脚本 | 重复跑 | 说明 |
|---|---|---|
| `deploy-bt-suspend-guard.sh` | ✅ 安全 | 固定目标路径 + `sh -n` 自检 |
| `deploy-camera-modules.sh` | ✅ 安全 | 传输/备份交给 `deploy-modules` |
| `deploy-modules.sh` | ⚠ 安全但**累积** | 每次留一份整套备份（P2-8），且原地解包（P0-3） |
| `deploy-v4l2loopback.sh` | ❌ **不安全** | 固定 `/tmp/.v4l2-*.bak`：上次中断后再跑会把污染件当原件（P1-7） |
| `deploy-zh-ime.sh` | ✅ 安全 | 但覆盖用户 autostart 不备份（P2-11） |
| `deploy-sensord-routec*.sh` | ⚠ 安全 | 重复 `apk add/del`；`.new` 残留会被下次误用（`:44-46`） |
| `deploy-sensors-hal.sh` | ✅ 安全 | `cp` 覆盖 overlay（容器在跑会 ETXTBSY，失败不留半件） |
| `esp-install-grub.sh` | ✅ stage 幂等 / ⚠ activate 每次新增一个 `.bak` | 无清理策略 |
| `esp-put-loader.sh` | ✅ 安全 | 空间检查 + 读回 sha + fsck |
| `grubenv-set.sh` | ✅ 幂等（按键覆盖） | 但不原子、无备份（P0-2） |
| `waydroid-haptics-aidl-deploy.sh` | ✅ 幂等（`grep -qF "$MARK"`） | `:57` `mount -o loop` 若上次中断未 umount，则 `mountpoint -q` 直接跳过（正确） |
| `device-window-collect.sh` | ✅ 安全 | 输出目录按模式固定，`>` 覆盖 |
| `win-x86-rootfs.sh` | ⚠ 幂等 | bind mount 用 `mountpoint -q` 守卫；但不卸载、不清理旧 rootfs |

**重复 append 到 misc / 重复加 cmdline**：本板块 0 例（无 misc/cmdline 写入）。
**`pkill -f` / `pgrep -f` 自匹配**（技能 `pkill-self-match`）：本板块仅 3 处，全在**设备侧远端 shell**：
`deploy-zh-ime.sh:86,119`（`pkill -f elden-ime-focusd`，远端命令串是 `bash -s` ⇒ 不自匹配）、
`waydroid-haptics-aidl-deploy.sh:43`（已用字符组 `waydroi[d]`，正确）。**主机侧 0 例 ⇒ 本项无缺陷。**
**远端 `grep -q` / rc 误判（PITFALLS #97 类）**：本板块 1 例实体缺陷 —— `device-window-collect.sh` 的 rc 全丢（P1-9）；
`lib-ssh.sh:53-58` 的 `S_kv` 无法区分「探测失败」与「值为空」（P2-15 同族，PITFALLS #97 的 1/2 语义问题）。

---

## 5. 逐文件裁定（20 主件 + 1 跨板块）

| 文件 | 行数 | BatchMode | timeout | 持锁 | P0/P1/P2 | 一句话 |
|---|---|---|---|---|---|---|
| `lib-ssh.sh` | 62 | ✅ | ✅ | n/a | P2 | 好；缺 `ServerAlive*`、缺 `-n`（补丁已补） |
| `lib-boot-ready.sh` | 100 | ✅（转调） | ✅ | n/a | P2 | 库内 `exit` 使其不能当布尔门 |
| `lib-wait.sh` | 161 | ✅ | ✅（无 `-k`） | n/a | P2 | `SSH_OPTS` 与 lib-ssh **两份真源**，会漂移 |
| `lib-serial-source.sh` | 109 | ✅ | ✅ | n/a | — | 本板块质量最高（探针/失败硬拒/`pkill -P` 正确）；调用方都有 `trap … EXIT` |
| `deploy-bt-suspend-guard.sh` | 82 | ✅ | ✅ 30 s | ❌ | — | 唯一「选项+超时+自检」都全的 deploy |
| `deploy-camera-modules.sh` | 79 | ❌ | ❌ | ❌ | P1-11 | ABI 门 fail-open |
| `deploy-modules.sh` | 130 | ❌ | ❌ | ⚠`--lock` | **P0-3** | 原地解包进在用树 |
| `deploy-sensord-routec.sh` | 59 | ❌ | ❌ | ❌ | P1-4 | `apk del` 不可逆 |
| `deploy-sensord-routec-debian.sh` | 90 | ✅ | ❌ | ❌ | P1-5,P1-6 | uid 1001 错 |
| `deploy-sensors-hal.sh` | 74 | ❌ | ❌ | ❌ | P1 | 5 处无选项 |
| `deploy-v4l2loopback.sh` | 84 | ✅ | ❌ | ❌ | P1-7,P1-8 | 改完构建头不 trap |
| `deploy-zh-ime.sh` | 123 | ❌ | ❌ | ❌ | P1-1,P1-2 | 11 处零选项 |
| `mesa-deploy.sh` | 38 | ❌ | ❌ | ❌ | P1-3 | 首跑必失败 |
| `device-window-collect.sh` | 74 | ✅ | ❌ | ✅（路径错） | P1-9,P1-10 | rc 全丢 |
| `esp-install-grub.sh` | 69 | ✅ | ❌ | ❌ | **P0-1** | 非原子 + 不比对 |
| `esp-put-loader.sh` | 130 | ✅ | ❌ | ❌ | P2×3 | 本板块最接近合格（读回+fsck+空间） |
| `grubenv-set.sh` | 43 | ✅ | ❌ | ❌ | **P0-2** | 非原子写引导环境 |
| `waydroid-haptics-aidl-deploy.sh` | 100 | ✅ | ❌ | ❌ | P1-14 | 失败留容器停 |
| `win-x86-rootfs.sh` | 86 | ❌ | ❌ | ❌ | P1 | 不卸 bind、不回退 |
| `devlogs.sh` | 96 | ❌ | ❌ | ❌ | P1-12 | 远端可永不返回 |
| `flash-b.sh`（跨板块） | 69→82 | ❌ | ⚠ | ❌ | **P0-4** | 他轮在修，留 3 缺口 |

---

## 6. 给编排者的排期建议

1. **立刻**：P0-1/P0-2（`git apply /tmp/script-audit-ssh.patch` 已含）—— 这两条是「下次开机就没救」级别，成本最低。
2. **本轮内**：P0-3（`deploy-modules` staging 化）。改完后 `mod-loop.sh`/`camera` 路径自动受益。
3. **下一轮**：把 6 个无 BatchMode 的 deploy 统一到 `lib-ssh.sh`（P1-1/P1-3/P1-4/P1-11/P1-12 + `deploy-sensors-hal`），
   同时把 `SSH_OPTS` 收敛成**单一真源**（`lib-wait.sh` 与 `lib-ssh.sh` 现在各写一份）。
4. **门禁化（防造轮回退）**：在 `scripts/doctor/06-hygiene.sh` 加一条静态门 ——
   `scripts/**/*.sh` 里出现 `ssh ` 的行若不含 `BatchMode` 且文件内无 `BatchMode` 默认值 ⇒ WARN；
   出现 `ssh `（非 `--stdin`/`-n`）且同行无 `timeout` ⇒ WARN。今天这条门会报 **17 文件 / 93 处**，正是本报告的数字化形态。
5. **跨板块**：A 类（槽 succ）必须在 `lib-fastboot.sh` 做成默认钩子，否则 24 个 0 覆盖脚本永远补不完（§4 A）。

---

## 7. 附：本次未做 / 边界

- 未执行任何设备命令（ssh/scp/adb/fastboot/qdl/edl.py 一律未跑），所有设备侧行为结论均来自代码路径 + `PITFALLS`/`.pi/memory` 既有实测。
- 「首次连接会等密码提示」的判据沿用 `reports/script-audit-20261105.md` §2.3 的实测结论，未在本轮重测（不得触碰设备）。
- 设备当前槽属性（`boot_b` 的 succ/retry/UNBOOTABLE）**本轮未现查**，报告不假设其现值；上机前必须按 `PITFALLS #672` 跑一次 `slot-attr.py show`。
- 未审查 `scripts/doctor/*`、`build/`、`geekidos-linux/`、`archive/`、内核树内脚本（非本项目资产）。
