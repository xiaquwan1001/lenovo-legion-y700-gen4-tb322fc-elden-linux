# 设备进入「日常 Linux」的部署件与工具（主机侧改造 + 清单）

> 日期 **2026-11-22**；轮次类型 = **主机侧改造 + 静态验证**（设备在 bootloader，由主会话独占）。
> 本轮**未执行任何 fastboot / adb / ssh / qdl**，设备零接触；所有结论要么有主机侧命令输出，要么标「未验证」。
> 工件：`rootfs/debian/units-extra/ab-mark-successful.service`（新）、`scripts/fix-ab-mark-successful.sh`（重写）、
> `scripts/deploy-desktop-shell.sh` §13（新增只读/部署段）。本文件 = 三件的审查账 + 部署清单。

## 0. 数字结论（先看这一页）

| # | 问题 | 结论 | 证据强度 |
|---|---|---|---|
| 1 | 上一轮加的 `fix-ab-mark-successful.sh` systemd 分支能不能直接部署 | **不能**。9 个缺陷，其中 3 个会「看起来成功、实际没做」：槽位取自 cmdline（从 a 槽起也给 `_b` 置成功，`#601`）· 两处写操作全挂 `\|\| true`（失败不可见）· python3 段在现役根恒 no-op（`#690`）且 `--allow-wrong-lun` 关掉了 LUN 自检 | 代码原文 + 结论所在 PITFALLS 条目 + `scripts/slot-attr.py:431/443` 原文 |
| 2 | 重写后的件能部署吗 | **能（主机侧全绿）**：`sh -n`/`dash -n`/`busybox sh -n` 三解析器 OK，`shellcheck -s sh` **rc=0 零告警**，`systemd-analyze verify` **rc=0**，离线行为测试 **10/10 通过**（含「已成功零写盘」「写失败 rc=5」「`--check` MISS 计数」） | 本文件 §1.3 / §1.4 的原始输出 |
| 3 | 上机后还需要什么 | 1 次 `qbootctl -a` / `qbootctl -n b` 的**原文比对**（本轮判据的文本来自 `/opt/elden/mobian-rootfs/usr/bin/qbootctl` 的 `strings`，不是上机输出） | §1.5「未验证」 |
| 4 | 「重启到 BL」现在能不能一条命令做完 | **不能，而且不该再试**。三条软路径 2026-11-21 实测全灭（`#701`）；唯一可靠路径 = **物理键**（长按电源 10 s → 音量上+电源）。`scripts/to-bootloader.sh` 的三态判据有 **6 处**必须改（其中 1 处是**判据本身不可靠**：uptime 变小） | `reports/linux-to-fastboot-20261121.md` §0 表 + 本文件 §2.4 逐行 |
| 5 | 日常 Linux 还缺多少外部资源 | **4 项真缺外部件**（Mesa 26.2.x / fcitx5 Qt 前端 / 相机用户态 / Waydroid 运行时+镜像）+ **2 项非外部缺口**（自编 `vendor.img` 需 AOSP 树、`hapticd` 不可重建）；**T9 采样与网络自愈无外部缺口** | §3 表，包版本/大小均为 2026-11-22 现查 Debian 索引 |
| 6 | 本轮给门禁带来什么 | **没引入新 FAIL**。开工时 `FAIL=2`（两条都在 **§24 scripts 索引新鲜度**，且**改动前就已存在**：用旧头注释复算 fp=`54fe052d…` 仍 ≠ 记录值 `d34ba3c9…`）；写报告期间另有并发写者在改 `PITFALLS/`，数字会漂 ⇒ 以主会话自己那次为准 | §4.1 |

---

## 1. 件①：每次启动自动 mark-successful（可部署 / 幂等 / 可回退）

### 1.1 旧 systemd 分支的 9 个缺陷（逐条给证据）

被审对象 = 上一轮未入库的 Debian 分支（`git HEAD` 里只有 Alpine 版，说明它**从未被 review 也没上机**）。原文关键行：

```sh
ExecStart=/bin/sh -c 's=$(sed -n "s/.*androidboot\\.slot_suffix=_\\([ab]\\).*/\\1/p" /proc/cmdline | head -1); \
  [ -n "$s" ] || s=b; /usr/bin/qbootctl -m "$s" || true; \
  if [ -x /usr/local/sbin/slot-attr.py ]; then \
    python3 /usr/local/sbin/slot-attr.py --device /dev/sde --allow-wrong-lun set "$s" --retry 7 --successful || true; fi'
```

| # | 缺陷 | 证据 | 后果 |
|---|---|---|---|
| D1 | **槽位取值用 cmdline 的 `androidboot.slot_suffix`** | `PITFALLS #601`（正文 `sessions/194-…`）：`boot.img` 头里烤死 `_b`，ABL 对 Linux 件不追加 suffix ⇒ **从 `boot_a` 起来也显示 `_b`**；`scripts/build-boot.sh:73` 把 `androidboot.slot_suffix=$SLOT_SUFFIX` 写进 CMDLINE | 给错的槽置 SUCCESSFUL，**真 active 槽继续扣 retry** ⇒ 正是它想防的那件事（`#181`/`#697`） |
| D2 | **两处写操作都挂 `\|\| true`** | 原文（上） | 单元永远 `Result=success`；`qbootctl` 失败、GPT 写失败、python3 缺失**全部不可见** |
| D3 | **python3 段在现役根恒为 no-op** | `PITFALLS #690`（`eldroid-bootctl` 与 `python3` 在现役 Debian 根都不存在）+ `AGENT-OPS §2` 同句 | 「顺手补 retry」这段从来没执行过，但代码存在会让人以为 retry 已复位 |
| D4 | **`--allow-wrong-lun` 恰好关掉了 LUN 自检** | `scripts/slot-attr.py:403` 定义该开关、`:431`/`:443` 是「LUN 不对就拒写」的实现，`PITFALLS #318` 记过「对错 LUN 跑 set，人看到的仍是成功」 | 一旦设备名漂移（`/dev/sdX` 枚举变化），可能改错 LUN 的 GPT |
| D5 | **每次启动都写 LUN4 双表 + 重算两处 CRC**（`set --retry 7 --successful`） | `slot-attr.py` 头注释：「Writes BOTH the primary and the backup GPT (entries + header) and recomputes the two CRCs」 | 为一个只读即可判断的状态付全量写代价（且与 `qbootctl -m` 重复写同一字节） |
| D6 | **`tries_remaining` 复位是错的期望** | `PITFALLS #672` 正文实测原文：「把槽改成 succ=0 retry=3 后跑服务 → succ=1（**retry 不动**）」 | 「每次启动 retry 归 7」这条没被证实；本机只能保证 **SUCCESSFUL 位置 1** |
| D7 | **失败注入点全无**：`ConditionPathExists=/proc/cmdline` 恒真、无 `TimeoutStartSec` | 原文 + `PITFALLS #102`（`qbootctl` 早跑会 `No slots found`，by-partlabel 还没建） | 早启动时 `-m` 报错被 `\|\| true` 吞；看起来「装了就好」 |
| D8 | **与 distro `qbootctl.service` 是两份同语义实现，且没写顺序** | 设备上 `qbootctl.service` 已 enabled（`DEVICE/README.md §1.1` 首条）；该单元 `ExecStart=/usr/bin/qbootctl -m`（`/opt/elden/mobian-rootfs/usr/lib/systemd/system/qbootctl.service` 原文）。旧分支既无 `After=`/`Wants=`，也未说明两者关系 | 启动顺序不定 ⇒ 同一 GPT 属性被两份实现各写一次；`systemctl --failed` 里谁失败都说不清 |
| D9 | **`--install` 只装单元、不装脚本**：逻辑内联在单元里 | 旧分支 `cat > "$U" <<'EOF' … ExecStart=/bin/sh -c '…'` | 无法单独 `--check`/`--mark-once`；`systemd-analyze verify` 看不到 shell 逻辑；单元与脚本两份真相（`PITFALLS #627` 同族） |

### 1.2 新形状（4 个面：文件 / 语义 / 幂等 / 回退）

**文件（仓内 SSOT，不再内联拷贝）**

| 文件 | 角色 |
|---|---|
| `scripts/fix-ab-mark-successful.sh`（282 行，POSIX sh） | 全部逻辑。模式：`--mark-once`（运行期）/ `--check`（只读体检）/ `--install` / `--uninstall` / `--alpine-install`（历史路径） |
| `rootfs/debian/units-extra/ab-mark-successful.service`（30 行） | **薄单元**：`Type=oneshot` + `ExecStart=/bin/sh /usr/local/sbin/ab-mark-successful --mark-once`；不含 shell 逻辑 |
| `scripts/deploy-desktop-shell.sh` §13 | 部署 + `--check`（五件判据，见 §1.2 / §4 的 S2–S4） |

**语义（三处关键改动）**

1. **槽位 = `qbootctl -a` 的 active 槽**（回退 cmdline → 回退 `b`）。active 槽才是 ABL 会扣 retry 的那个槽；cmdline 只作兜底并在日志里写明来源。
2. **先只读、已成功零写盘**：`qbootctl -n <slot>` 命中 `": is marked successful"` 就 `return 0`，一次写都不做（幂等）。判据字符串取自二进制：
   `/opt/elden/mobian-rootfs/usr/bin/qbootctl` 的 `strings` 有 `Active slot: %s` / `SLOT %s: is %smarked successful` / `SLOT %s: already marked successful` / `SLOT %s: Failed to mark boot successful`。
   ⚠ `is not marked successful` 里也含 `marked successful`，所以判据用的是 **`: is marked successful`** 前缀形式并单独排除 `is not`。
3. **失败可见**：`-m` 非 0 ⇒ `rc=5`；写后 `-n` 读回不成立 ⇒ `rc=6`；**不写 `|| true`**。oneshot 失败 ⇒ `systemctl --failed` + `systemctl show -p Result` 可读（deploy §13 读它）。
4. **retry 复位降级为显式开关**：`RETRY_TOPUP=1` 且 `python3` + `/usr/local/bin/slot-attr.py` 都在才执行，且**绝不**传 `--allow-wrong-lun`；缺件只 `WARN`（现役根就是这条路径，见 §2 的 T10）。
5. 与 distro 单元的关系写进单元注释 + `After=`/`Wants=`：**同语义的另一份实现，两者幂等**；本单元通常只做只读校验。

**回退（三档，全在主会话手里）**

| 档 | 动作 | 影响面 |
|---|---|---|
| 1 | `ab-mark-successful --uninstall`（= `systemctl disable --now` + 删 `/etc/systemd/system/ab-mark-successful.service` + `daemon-reload`） | 只删我们的单元；distro `qbootctl.service` 仍在 ⇒ 语义不丢 |
| 2 | `systemctl mask ab-mark-successful.service` | 保留文件、禁止启动（想留证据时用） |
| 3 | 什么都不做，`systemctl stop` 后手工 `qbootctl -m <slot>` | 零持久改动 |

**破坏面**：本件**只写 GPT 的 attribute 一个字节（经 `qbootctl`）**，不碰分区内容、不碰 `misc`、不碰 boot 件、不碰 AVB。

### 1.3 静态验证（原始输出）

```console
$ sh -n scripts/fix-ab-mark-successful.sh          → OK
$ dash -n scripts/fix-ab-mark-successful.sh        → OK
$ busybox sh -n scripts/fix-ab-mark-successful.sh  → OK
$ shellcheck -s sh scripts/fix-ab-mark-successful.sh → rc=0（无告警）
$ systemd-analyze verify --man=no rootfs/debian/units-extra/ab-mark-successful.service → rc=0
$ bash -n scripts/deploy-desktop-shell.sh          → OK
```

`systemd-analyze verify` 的两个**过程**发现（都已修，留档）：

- 单元最早写的 `ExecStart=/usr/local/sbin/ab-mark-successful --mark-once` 会让 `stage.sh` **门禁 D2**（「ExecStart 首个绝对路径必须存在」）在 overlay 树上判 FAIL（overlay 不含 `/usr/local/sbin`）。
  处置 = 改成 `/bin/sh /usr/local/sbin/ab-mark-successful --mark-once`，与既有 `elden-resource-sample.service`（`ExecStart=/bin/sh /usr/local/sbin/suspend-resource-sample.sh tick`）**同形**；改后 `verify rc=0`，且 D2 只看首 token `/bin/sh`。
- 改前 `verify` 的原样报错 = `Command /usr/local/sbin/ab-mark-successful is not executable`（部署前属预期），现在连这条也没有。

`shellcheck` 对 `deploy-desktop-shell.sh` 的告警集合**与改动前逐条相同**（只有既有的 2 条 `SC2034: GPU_UNIT/GPU_SCRIPT appears unused`）；新加的 §13 只引入该文件既有的 `SC2015/SC2016` info 风格，无新增 warning/error：

```console
$ shellcheck -s bash -S warning scripts/deploy-desktop-shell.sh   # 2 × SC2034（275/276 行，改前就有）
$ shellcheck -s bash -S warning /tmp/deploy_orig.sh（HEAD 版）    # 同样 2 × SC2034
```

### 1.4 离线行为测试（10 组，全通过）

stub `qbootctl`/`systemctl` + `QBOOTCTL`/`CMDLINE`/`UNIT_DIR`/`SBIN_DIR`/`PARTLABEL_WAIT` 环境覆盖（**不碰设备、不写 `/etc`**；完整脚本见附录 A）：

```console
$ sh /tmp/ab-mark-selftest.sh
== T1 已 successful ⇒ 零写盘（幂等） ==            PASS ×2
== T2 未 successful ⇒ 写入 + 读回通过 ==          PASS ×3（含落盘槽位=b）
== T3 active 槽优先于 cmdline（#601）==            PASS ×2（active=_a + cmdline=_b ⇒ 标记 a）
== T4 cmdline 无 suffix ⇒ 回退 b ==                PASS ×2
== T5 qbootctl -m 失败 ⇒ rc=5（不吞错）==          PASS ×2
== T6 --check 四齐 ⇒ rc=0 / MISS=0 ==              PASS ×2
== T7 --check 单元缺失+未 successful ⇒ MISS=3 ==   PASS ×2
== T8 --check Result=failed ⇒ 计入 MISS ==         PASS ×2
== T9 --install 缺单元源 ⇒ rc=3（不猜内容）==      PASS
== T10 --retry-topup 但无 python3 ⇒ 只 WARN ==     PASS ×2
结果: 全部通过（10 组）
```

deploy §13 的**设备侧探针**也单独离线跑过（同一段 shell，7 个样本）：

| 样本 | 期望 | 实际 |
|---|---|---|
| 全绿（单元在/enabled/Result=success/槽位已标记） | 0 | **0** |
| 槽位未标记 | 1 | **1** |
| `Result=failed` | 1 | **1** |
| `is-enabled=disabled` | 1 | **1** |
| 脚本/单元缺失 | 2 | **2** |
| `qbootctl -a` 无输出（回退 b，且未标记） | 1 | **1** |
| active=`_a` 且已标记 | 0 | **0** |

### 1.5 未验证 / 残留缺口（必须由主会话处理）

1. **上机首条（30 秒，必做）**：`qbootctl -a` 与 `qbootctl -n b` 的**原文**要与本文件的判据字符串逐字比一次。
   本轮判据来自 `strings /opt/elden/mobian-rootfs/usr/bin/qbootctl`（`Active slot: %s`、`SLOT %s: is %smarked successful`），
   属**离线二进制证据**，不是上机输出 ⇒ 若设备上的 `qbootctl` 版本或语言环境不同，`--mark-once` 会走「无法判读」分支（rc≠0，可见，不会误写）。
2. **镜像构建侧缺口**：`rootfs/debian/stage.sh` 4d **只给 `*.timer` 建 `timers.target.wants` 软链**，不给 `.service` 建。
   ⇒ 走「重建镜像」这条路时，`ab-mark-successful.service` 会**装进 `/usr/lib/systemd/system` 但不启用**。
   本轮无权改 `stage.sh`（不在允许写入清单内）⇒ **建议主会话加 4e：对 `units-extra/*.service` 里显式声明要启用的，建 `multi-user.target.wants` 软链**。
   在此之前，唯一启用路径 = `deploy-desktop-shell.sh`（run 模式）或 `fix-ab-mark-successful.sh --install`。
3. **`qbootctl -m` 是否复位 retry**：`#672` 的实测说「retry 不动」，`getvar slot-retry-count:b` 在 2026-11-21 09:0x 读到 **6**（`reports/linux-to-fastboot-20261121.md` §5 第 1 步）——两者不矛盾但也没证明复位。
   判据留给主会话（只读，10 秒）：`qbootctl -n b; qbootctl` 前后 + `slot-attr.py show` 的 `retry=` 值各一次。
4. **`check-doctor` §24**（见 §4.1）：我改动了 `fix-ab-mark-successful.sh` 的头注释一句话，而索引指纹含 `desc` ⇒ **必须重生成** `scripts/README.md`（该文件不在本轮写入清单）。

---

## 2. 件②：Linux → bootloader（唯一可靠路径 runbook）

### 2.1 现状判据（一句话）

**现役 vk192 上没有任何软路径可用**（`PITFALLS #701`，2026-11-21 三条臂逐一实测/取证否掉）⇒ 进 fastboot **必须物理键**。
另注：`#707` 纠正的是**适用范围** —— `qbootctl -s`（切 active 槽）与 `dd` 写分区**都不需要物理键**；真正需要物理键的只有「让 ABL 重新验/载 boot 件」。

### 2.2 Runbook（人项 / 设备侧 / 主机侧）

**R1 人项（只有用户能做）**

1. 先说清「为什么现在要断电」：`reboot bootloader` 只会普通重启（内核无 vendor reset 钩子）。
2. **长按电源 10 s**，直到屏幕全黑 / 无振动（= 真断电，不是熄屏）。
3. **按住音量上不放**，再按电源 ~2 s，出现 fastboot/LOGO 屏即松手。

**R2 主机侧（每条都套 `timeout -k`；`fastboot` 必须先解析路径，`PITFALLS #699`）**

```sh
. scripts/lib-hosttools.sh && ensure_hosttools --quiet   # 拿到 $FB_BIN（~/.local/opt/platform-tools）
timeout -k 2 8 "$FB_BIN" devices                          # 判据：出现 HA2EXB0E
timeout -k 2 8 lsusb | grep -E '18d1:|05c6:'              # 判据：见 18d1:4ee0
```

**进 BL 后的第一条命令（`PITFALLS #650`）**：`timeout -k 3 30 "$FB_BIN" -s HA2EXB0E reboot-bootloader`
—— 让 ABL 重新初始化，否则紧接着的 `flash`/`boot` 可能落到旧的 slot 上下文。

**回 Linux**：`timeout -k 3 30 "$FB_BIN" -s HA2EXB0E reboot`，起来后 **先清 BCB**（若之前写过 `bootonce-*`）：

```sh
ssh elden-root 'elden-to-bootloader --clear-bcb'   # 设备侧工具已在位（2026-11-21）
```

⚠ **禁止 `fastboot erase misc`**：`misc` 里除 BCB（头 4 KiB）之外还有槽位计数区（`reports/android-min-avb-facts-20261118.md`），
整分区擦会把 retry 语义一起抹掉。清 BCB 只写**头 4 KiB**。

**停手判据（不重试）**：发出后 25 s 内 `"$FB_BIN" devices` 空 **+** `lsusb` 无 `18d1/05c6/1d6b` **+** SSH 不通 ⇒ **停**，回报用户，请其长按电源断电重来（`AGENT-OPS §2` 原句）。

### 2.3 不要再用这三条（+ 两条同族入口）

| 禁用路径 | 为什么 | 证据 |
|---|---|---|
| ① `systemctl reboot bootloader` / `reboot2 bootloader` / `scripts/to-fastboot.sh --boot` | 现役主线核**无 PSCI SYSTEM_RESET2 vendor reset 钩子** ⇒ 退化成普通复位，设备回 Linux | `PITFALLS #690`；`reports/linux-to-fastboot-20261121.md` 臂 A（kallsyms `vendor_reset\|restart2` 命中 0、`dmesg \| grep -c 'SYSTEM_RESET2 vendor reset'` = 0） |
| ② `misc` 写 BCB `bootonce-bootloader` + reboot | **ABL 不采纳**：写后读回校验通过（`command="bootonce-bootloader"`），重启后仍回 Linux | 同报告臂 B（`uptime 33245 s → 18 s`，用户目视确认「只是普通重启」）；与 Q23 一致 |
| ③ `qbootctl -u b`（逼 ABL 停 fastboot） | 写失败：`gpt_disk_commit: Invalid args` / `update_slot_attribute: Failed to commit disk` / `SLOT _b: Failed to set as unbootable` | 同报告臂 C |
| ④ `cycle.sh --fastboot` / `--soft`（`echo b > /proc/sysrq-trigger`） | 暖复位只回 Linux，不含 reason 语义 | `AGENT-OPS §2`（2026-11-19 起软路径默认拒绝） |
| ⑤ `uefi-oneshot.sh` 侧入口 / `eldroid-bootctl` python3 件 | 件已不在现役根（无 python3），旧入口静默 no-op | `PITFALLS #690`（`\|\| true` 吞错 ⇒ `to-fastboot.sh` 干等 90 s） |
| （未测，不要当备选）`qbootctl -i -u <slot>` | 机制上可能让 ABL 停 fastboot，但**故意把当前槽标成不可启**，成功后必须 `fastboot --set-active=<同槽>` 复原（`#677`）；且 `-i` 从未在本机实测 | `reports/linux-to-fastboot-20261121.md` §3 路线 2（明写「必须在用户在场时试」） |

### 2.4 `scripts/to-bootloader.sh` 三态判据 vs 最新实测：**6 处必须改**

| # | 行 | 现在写的 | 为什么必须改 | 建议改法 |
|---|---|---|---|---|
| C1 | **L19**（文件头三态说明） | 「Linux 回来（SSH 可登且 **uptime 变小**/BCB 已被消费）⇒ rc=10」 | 两处不实：① BCB **没有**被 ABL 消费（`#701` 臂 B 实测写后读回仍在）；② uptime 变小不是充分判据（见 C2） | 改成「SSH 可登且 **`boot_id` 变了**」 |
| C2 | **L59 / L105–L107** | `UP0=$(linux_up)` … `[ "$now_up" -lt "$UP0" ]` | **判据不可靠**：若发命令前设备刚起来（uptime 小），重启周期（11-20 冷起 25 s 到 SSH）会大于 UP0 ⇒ `now_up > UP0` ⇒ 漏判「已回 Linux」，白等到 `WAIT=150` 后误报 rc=11「先查线/供电」。2026-11-21 收尾态实测 `uptime 44 s`、11-20 冷起 ~25 s ⇒ 只要在开机头 ~20 s 内发命令就能触发 | 记录 `boot_id=$(cat /proc/sys/kernel/random/boot_id)`，回判 = 「SSH 通且 boot_id 不同」；uptime 只作日志 |
| C3 | **L83–L88**（`--dry-run` 只打印） | 打印「钩子: 无」但不据此决定 | 与 `AGENT-OPS §2`「2026-11-19 起软路径默认拒绝、`ALLOW_SOFT_RESET=1` 才发」冲突；且 `#701` 已证 bcb 臂无效 ⇒ 默认发 = 每轮白重启一次 | 解析 dry-run 的「钩子: 无」⇒ `ARM=auto` 时打印 R1 人项 + `exit 12`；仅 `ALLOW_SOFT_RESET=1` 或显式 `--arm bcb` 才发 |
| C4 | `scripts/elden-to-bootloader.sh` **L62–L63**（设备侧） | `if [ "$HOOK" = 1 ]; then MODE=psci; else MODE=bcb; fi` | 同 C3：无钩子时**自动选一条已知无效的臂**，与 `AGENT-OPS §2` 相反 | 无钩子 ⇒ 打印物理键步骤 + `exit 12`；只有显式 `--bcb` 才写 misc |
| C5 | **L109** | 回 Linux 后直接 `--clear-bcb >/dev/null` | `#701` 的结论正是靠「写后读回 `command="bootonce-bootloader"`」成立的；静默清掉会把诊断证据抹掉（这是本机唯一能区分「没写进去」与「写了但不被采纳」的证据） | 清之前 `dd if=/dev/disk/by-partlabel/misc bs=4096 count=1` 存到 `logs/bcb-<ts>.bin` + 打印 sha/前 32 B，再清 |
| C6 | **L102 / L114** | 提示 `scripts/slot-switch.sh status`（**主机侧**脚本，拿去设备上跑会 not found）；rc=11 只说「按键」 | 指令不可执行 = 静默坑；停手时最需要的是「精确的物理键步骤」 | L102 改「主机侧 `bash scripts/slot-switch.sh status`（或设备侧 `qbootctl; qbootctl -a`）」；L114 附 R1 的三步 |

> 本轮**未改** `scripts/to-bootloader.sh` / `scripts/elden-to-bootloader.sh`（不在允许写入清单）⇒ 上表是给主会话的改动单。
> 在那之前，**Runbook（§2.2）是唯一口径**，不要用这两个脚本的 `--arm auto` 默认行为。

---

## 3. 件③：日常 Linux 待办的外部资源获取清单

口径：只列「达成日常可用还缺的**外部**件」；版本/大小 = **2026-11-22 现查** USTC 镜像的 Debian 索引
（`trixie/main` 与 `trixie-backports/main`、`sid/main` 的 `Packages.xz`，见 §3.4 复现命令）。`需设备` = 必须插卡开机才能落地。

| # | 缺口 | 为什么缺（证据） | 从哪取 | 大小（deb / Installed） | 需设备 | 替代方案 |
|---|---|---|---|---|---|---|
| R1 | **Mesa 26.2.x**（T19 撕裂 A/B 需要换一个 GL 栈版本） | 设备在版 = **26.1.6**（= `trixie-backports` 的 `26.1.6-1~bpo13+1`，`DEVICE §1.1` 11-20 记的 Mesa 26.1.6 与索引一致）；`trixie/main` 只有 **25.0.7-2+deb13u1**；**26.2.6 只在 sid** | sid（`mirrors.ustc.edu.cn/debian sid main`）：`mesa-libgallium` + `mesa-vulkan-drivers` + `libgl1-mesa-dri` | 10.7 MB + 20.4 MB + 36 KB（装后 50.7 MB + 152.5 MB + 0.3 MB） | 是（装 + `apt-mark hold` + 重登会话；`PITFALLS #654` 的 divert 纪律适用） | ① 只做 `libgl1-mesa-dri`+`mesa-libgallium` 的最小 A/B；② 保持 pixman 软合成（`/etc/elden-soft-render`）先日常用；③ 等 backports 升版 |
| R2 | **Qt 应用的中文输入（G1-38 剩「Qt 一例」边角）** | `rootfs/debian/daily-baseline.tsv` 只装 `fcitx5-frontend-gtk3/gtk4`，**无 Qt 前端**；`/opt/elden/mobian-rootfs` 里 `fcitx5-qt` 也**未装**（`dpkg --root … -l` 实测） | `trixie/main`：`fcitx5-frontend-qt5` / `fcitx5-frontend-qt6`（+ qtbase 依赖，装后体积未核） | 118 KB + 135 KB（装后 612 KB + 679 KB；依赖未计） | 是 | 不装：日常只用 GTK 应用（GTK3 侧也仍受 `#653` 的「不建 fcitx IC」限制） |
| R3 | **相机用户态**（日常能拍照/预览） | 11-19 重建根只到「minbase + 桌面」，相机链（`libcamera` / App）**不在任何清单**；内核侧 camss 已通（G1-5 ✅ 2026-10-18 实测 30 fps） | `trixie/main`：`libcamera-tools`(0.4.0-7) + `libcamera0.4`（依赖自动）+ 可选 `megapixels`(1.8.3-1) | 307 KB（装后 1.36 MB）/ 1.36 MB（装后 2.45 MB） | 是 | 不装 App：`gst-launch-1.0 libcamerasrc ! …`（`gstreamer1.0-plugins-good/libav` 已在基线）即可出流 |
| R4 | **Waydroid 运行时 + 容器镜像（G2 主链）** | `waydroid` 包**不在 `trixie/main`**（`grep -c "^Package: waydroid$" trixie/main = 0`）；`trixie-backports` = `1.6.3+ds-2~bpo13+1`，`sid` = `1.6.3+ds-3`。镜像（`system.img`/`vendor.img`）从来不在仓库（2026-10-17 起 OTA 分发，`waydroid-ota/` 只有 44 KB 的 json 骨架） | 包：`trixie-backports`；镜像：Waydroid OTA 源（`system/lineage/waydroid_arm64_only` + `vendor/waydroid_arm64_only`） | 包 220 KB（装后 473 KB）；镜像**未在本轮核实**（历史账：原 OTA `vendor.img` **225 MiB**、自编 82 MiB；`system.img` ≈ 1 GB 量级） | 是（还要 `binder_linux`/`nftables` 与桌面会话） | ① redroid 路线（`RESOURCES §1.3` 先例）；② 先只装包不装镜像（`waydroid init -f` 才需要镜像），日常桌面不依赖它 |
| R5 | **自编 `vendor.img`（haptics/camera HAL 固化进镜像）** | 需要 `waydroid-build`（AOSP）树，**本机不在盘上**（`find / -maxdepth 3 -name waydroid-build` = 0；`external/` 只有 mesa/phoc/AOSP vndk）；`make vendorimage` 增量几分钟但首建要整树 | AOSP + `lineage_waydroid_arm64_only` 设备树（自建，工作量大） | 树 ~100 GB 量级（未核实）；产出 `vendor.img` 82 MiB（历史实测） | 是 | **日常不阻塞**：继续用运行时 `lxc.mount.entry`/`config_nodes` bind（Q29 已删掉的只是 Mesa 那 11 条，haptics/camera 的 bind 仍在）；固化只是「重铺后不用重配」 |
| R6 | **`hapticd`（容器马达透传 daemon）** | T14 债务：自家 ELF **不可重建**（`INDEX.md §0` 「卡什么」块原文：「唯一缺口 = `hapticd` 二进制不可重建」） | 无上游；仓库/manifest 里只是副本 | 未核实 | 是 | 宿主侧直接用 `ffrumble`（`out/ffrumble/ffrumble` 已在，2026-11-20 两侧实测震）；`hapticd` 只影响「容器内 App 触发马达」 |
| R7 | （T9 采样 / 网络自愈） | **无外部缺口**：`scripts/suspend-resource-sample.sh` + `units-extra/elden-resource-sample.{service,timer}` 自研已固化（`reports/t9-sampler-restored-20261121.md`）；`net-selfheal.sh`/`usb0-host-route` 在 `packaging/…/units` | — | — | 取数需设备 | T9 只差「样本时间」；网络只差 WiFi 凭据（人项） |

**非外部但会挡住日常的两条（记在这里，别当资源问题查）**

- `CONFIG_INPUT_UINPUT` 未开 ⇒ 无 `/dev/uinput` ⇒ agent 无法注入键鼠，桌面内验证必须人手（`INDEX.md §0` 2026-11-19 条）。
- `/dev/uinput` 之外，IME 候选条的 kimpanel 自绘是**代码缺口**不是包缺口（`PITFALLS #645`；`libgtk4-layer-shell0` 已在 P1 基线）。

### 3.1 版本/大小的复现命令（2026-11-22 实测）

```sh
cd /tmp && for s in trixie trixie-backports sid; do
  timeout -k 5 120 curl -sS --max-time 110 -o $s.xz \
    https://mirrors.ustc.edu.cn/debian/dists/$s/main/binary-arm64/Packages.xz && xz -dc $s.xz > $s.txt
done
grep -n -m1 '^Package: mesa-libgallium$' sid.txt    # → 26.2.6-1 / Size 10692 KB
grep -c '^Package: waydroid$' trixie.txt            # → 0
grep -n -m1 '^Package: waydroid$' trixie-backports.txt  # → 1.6.3+ds-2~bpo13+1
```

---

## 4. §部署清单（主会话在设备窗口按序执行；每步都有 `--check` 判据与回退）

> 前提：设备能进 Linux（当前**在 bootloader**，先按 §2.2 R1 的物理键/`fastboot reboot` 回 Linux 或起 Linux 后 SSH 可达）。
> 全程 `TAB=root@192.168.7.1`（先 `sudo scripts/ncm-host-up.sh`）；设备写入都会走 `scripts/device-lock.sh`（deploy 脚本内部已用）。

| 步 | 动作（主机侧命令） | `--check` 判据（可复跑） | 回退 |
|---|---|---|---|
| **S0** | 只读现态：`ssh elden-root 'uname -r; qbootctl -a; qbootctl; systemctl is-enabled qbootctl.service; command -v python3 || echo NO-PYTHON'` | 记下 active 槽、`Successful/Bootable` 两列、`NO-PYTHON` 是否存在（预期**无** python3） | 无（只读） |
| **S1** | **判据字符串核对**（30 s，见 §1.5-1）：`ssh elden-root 'qbootctl -a; qbootctl -n b'` | 输出逐字含 `Active slot: _b` 与 `SLOT _b: is marked successful`（或 `is not …`） | 若不匹配 ⇒ **停**，回报（本件的 `--mark-once` 会以 rc≠0 可见失败，不会误写） |
| **S2** | 部署桌面+全部既有面：`bash scripts/deploy-desktop-shell.sh`（run 模式，含新 §13） | `bash scripts/deploy-desktop-shell.sh --check` ⇒ **MISS=0**（§1–§13） | 本步只装包/铺 unit；回退 = 单项 `systemctl disable --now` + `rm /etc/systemd/system/<unit>`（§13 的回退见下） |
| **S3** | 只验 §13（不重跑全量）：`ssh elden-root 'ab-mark-successful --check'` | `MISS=0`；同一命令 `systemctl show -p Result --value ab-mark-successful.service` = `success`；`journalctl -u ab-mark-successful -b --no-pager \| tail -5` 有「读回校验通过」或「已是 successful ⇒ 零写盘」 | `ab-mark-successful --uninstall`（distro `qbootctl.service` 仍兜语义） |
| **S4** | **一次冷起验证**（重启后逐条）：`ssh elden-root 'cat /proc/sys/kernel/random/boot_id; systemctl is-enabled ab-mark-successful; systemctl show -p Result --value ab-mark-successful; qbootctl -a; qbootctl -n $(qbootctl -a \| sed -n "s/.*_\([ab]\)$/\1/p")'` | 新 `boot_id`；`enabled`；`Result=success`；`is marked successful` | 同上（`--uninstall`）；重启本身不是破坏性动作 |
| **S5** | **retry 语义补证**（只读，10 s，见 §1.5-3）：`ssh elden-root 'python3 -V 2>/dev/null \|\| echo no-py; qbootctl; ls -l /usr/local/bin/slot-attr.py 2>/dev/null'` | 记录 `Bootable/retry`（`qbootctl` dump 只给 Bootable；retry 需 `slot-attr.py show`，无 python3 时**跳过并记「未验证」**） | 无（只读） |
| **S6** | `daily-baseline` 日常面复查：`bash scripts/mobian-daily-baseline.sh --check` | 退出码 0（包齐 + `MISS=0`） | 只装不卸；单包回退 `apt-get install --reinstall` 或忽略 |
| **S7** | 资源落地（按需，全部走 §3 的表；**每装一批立刻 `--check`**）：R2 Qt 前端 → R3 相机用户态 → R1 Mesa A/B（**最后做**，会重启会话） | R2：`fcitx5-frontend-qt5/6` `dpkg-query -W` = `install ok installed` + 新开 Qt 应用能看到候选（**需人手**）；R3：`gst-launch-1.0 libcamerasrc ! fakesink` rc=0；R1：`dpkg-query -W mesa-libgallium` = `26.2.6-1` + `glmark2-es2` 有分 | R1：`apt-mark unhold` + 装回 `26.1.6-1~bpo13+1`（backports 仍可用）；R2/R3：`apt-get remove` 单包 |
| **S8** | 收尾：`bash scripts/check-doctor.sh` | **FAIL=0**（开工前已有 2 条 §24 FAIL，见 §4.1：`python3 scripts/gen-scripts-index.py` 可清；若仍 FAIL 逐条列出并归类） | index 重生成可 `git checkout -- scripts/README.md` |

**必须由用户做的（agent 不能代做）**：R1 的物理键、S4 的重启时机、S7 的人眼验收（候选词上屏 / 相机画面 / 出声）。

### §4.1 附注：`check-doctor` 现状（本轮实测，非本轮引入；数字会漂，见本节末段）

> ⚠ **本轮期间有并发写者在改 `PITFALLS/`**（`git status` 显示 `PITFALLS/README.md` + 多个 `PITFALLS/sessions/*` 处于 `M`，
> 并从 2 个变到更多）。所以下面的数字只代表**取样时刻**，不是稳态；本节只负责把我这一轮的 3 个文件与门禁 FAIL 切开。

**开工时（我的改动落地前）**：`FAIL=2 / WARN=7`，两条 FAIL 都在 §24：

```console
$ bash scripts/check-doctor.sh            # 摘要（开工时）
== 汇总: FAIL=2  WARN=7 ==
第 24 节（scripts 索引新鲜度）两条：
  [FAIL] 反作弊②收尾失败：撤掉探针后 --check 仍 rc=1（有残留）
  [FAIL] scripts/README.md 过期（rc=1）
$ python3 scripts/gen-scripts-index.py --check
STALE scripts/README.md 过期（结构变了：346 个入口，fp d34ba3c93fd9357d → 51e6019dd0515b32）
```

**它不是本轮引入的**（两条独立证明）：

- 第 346 个入口 = `scripts/recover-lun4-slotguid.sh`（**另一条 lane 新建、未跟踪**：`git status` 里是 `??`），
  它的头注释一句话进了指纹（`gen-scripts-index.py:319 structural_fp` 把 `desc` 算进 payload）⇒ 345→346 的漂移源头不在本轮的 3 个文件。
- 把我改的 `fix-ab-mark-successful.sh` 头注释那句还原成旧措辞后复算，fp = `54fe052dc8e6ef3b`，**仍** ≠ 记录值 `d34ba3c9…` ⇒ 改动前就已过期。

**本轮期间 `scripts/README.md` 被另一写者重生成过**（`git diff` 显示指纹 `d34ba3c9…` → `51e6019d…`、入口数 345→346、`设备操作 105→106`），
之后又过期（`--check` 现报 `fp 51e6019d… → d8dcf143…`，因为那条新脚本仍在途编辑）。
⇒ **修法只有一步，交给收尾那一轮**：`python3 scripts/gen-scripts-index.py`（本轮无权写 `scripts/README.md`，且并发写者没停时重生成必然再漂）。

**写报告期间（并发写者正在改 `PITFALLS/`）**：抽样三次分别读到 `FAIL=3`（新增 §8「PITFALLS #1–#5 编号撞车：
`01-引导fastboot重启交接.md` × `329-…GUID占位与LUN错配.md`」）、`FAIL=1`（§8「`PITFALLS/README.md:372` 索引行 865 B > 800」）。
两者**都不涉及本轮 3 个文件**（我既不新增 PITFALLS 条目，也不改 `PITFALLS/README.md`），属并发写者的在途编辑。
⇒ 收尾前请以**主会话自己那次** `bash scripts/check-doctor.sh` 为准。

---

## 附录 A：离线行为测试脚本（本轮实测件，落 `/tmp/ab-mark-selftest.sh`）

> 只用 stub，不碰设备、不写 `/etc`；`REPO=<仓库根> sh /tmp/ab-mark-selftest.sh` 可复跑（10 组）。

```sh
#!/bin/sh
set -u
REPO=${REPO:-$PWD}
SUT=$REPO/scripts/fix-ab-mark-successful.sh
WORK=$(mktemp -d "${TMPDIR:-/tmp}/abmark.XXXXXX"); trap 'rm -rf "$WORK"' EXIT
BIN=$WORK/bin; mkdir -p "$BIN" "$WORK/unit" "$WORK/sbin"; fail=0
chk() { if [ "$2" = "$3" ]; then printf 'PASS  %s（%s）\n' "$1" "$3"; else printf 'FAIL  %s：期望 %s 实际 %s\n' "$1" "$2" "$3"; fail=$((fail+1)); fi; }
cat > "$BIN/qbootctl" <<'EOS'
#!/bin/sh
S=${STATE:?}; act=$(sed -n 's/^active=//p' "$S"); mk=$(sed -n 's/^marked=//p' "$S")
case "${1:-}" in
  -a) echo "Active slot: $act" ;;
  -n) [ "${mk:-}" = "$2" ] && echo "SLOT _$2: is marked successful" || echo "SLOT _$2: is not marked successful" ;;
  -m) if [ "${FAKE_FAIL_MARK:-0}" = 1 ]; then echo "SLOT _$2: Failed to mark boot successful"; exit 1; fi
      if [ "${mk:-}" = "$2" ]; then echo "SLOT _$2: already marked successful"; else
        sed -i "s/^marked=.*/marked=$2/" "$S"; echo "SLOT _$2: Marked boot successful"; fi ;;
  *) echo "Current slot: $act" ;;
esac
EOS
cat > "$BIN/systemctl" <<'EOS'
#!/bin/sh
S=${STATE:?}
case "$*" in
  "is-enabled ab-mark-successful.service") cat "$S.enabled" 2>/dev/null || echo disabled ;;
  "show -p Result --value ab-mark-successful.service") cat "$S.result" 2>/dev/null || echo success ;;
  "is-enabled qbootctl.service") echo enabled ;;
  *) exit 0 ;;
esac
EOS
chmod 755 "$BIN"/*
run() { PATH=$BIN:$PATH STATE=$WORK/state CMDLINE=$WORK/cmdline PARTLABEL_WAIT=0 \
        UNIT_DIR=$WORK/unit SBIN_DIR=$WORK/sbin sh "$SUT" "$@"; }
# T1 已成功→零写盘 / T2 未成功→写+读回 / T3 active 优先 / T4 回退 b / T5 -m 失败 rc=5
# T6 --check 全绿 / T7 --check 缺 3 件 / T8 Result=failed / T9 --install 缺源 rc=3
# T10 --retry-topup 无 python3 只 WARN
# （每组的状态文件与断言见本轮会话记录；核心断言：rc、$WORK/state 里的 marked= 值、--check 的 MISS 计数）
```

---

## §结论

1. **件①（自动 mark-successful）从「不可部署」变成「可部署 + 幂等 + 可回退」**：旧 systemd 分支 9 个缺陷（槽位取 cmdline `#601`、`|| true` 吞错、python3 段恒 no-op 且 `--allow-wrong-lun` 关掉 LUN 自检、retry 复位是错误期望 `#672`）已全部替换；新形状 = 282 行 POSIX 脚本（`--mark-once/--check/--install/--uninstall`）+ 30 行薄 unit（`/bin/sh` 前缀，过 `stage.sh` 门禁 D2），**主机侧静态验证全绿**（`sh`/`dash`/`busybox sh -n`、`shellcheck rc=0`、`systemd-analyze verify rc=0`、离线行为 10/10、deploy §13 探针 7/7）。
   剩 3 件事：上机核对 `qbootctl` 文本（S1）、镜像侧 `stage.sh` 4d 不给 `.service` 建启用软链（建议加 4e）、`check-doctor §24` 需重生成 `scripts/README.md`（改动前即存在）。
2. **件②（Linux→BL）**：唯一可靠路径 = 物理键（长按电源 10 s → 音量上+电源），runbook 已按「人项 / 主机侧 / 停手判据」写死；**三条软路径（PSCI reboot bootloader、misc BCB `bootonce-bootloader`、`qbootctl -u`）永久停用**，另两条同族入口（`cycle.sh --soft/--fastboot`、`uefi-oneshot`/`eldroid-bootctl`）同样不用。`scripts/to-bootloader.sh` 有 **6 处**必须改（其中最硬的一条：uptime 变小不是判据，要用 `boot_id`；另外默认行为违反 `AGENT-OPS §2` 的「软路径默认拒绝」）。
3. **件③（外部资源）**：真缺 4 项外部件 —— Mesa 26.2.6（只在 sid，10.7+20.4 MB）、fcitx5 Qt 前端（118+135 KB）、相机用户态 `libcamera-tools`+`megapixels`（307 KB+1.36 MB）、Waydroid 包+镜像（backports 220 KB，镜像 ~GB 级未核实）；另 2 项非外部缺口（自编 `vendor.img` 需 AOSP 树；`hapticd` 不可重建）。**T9 采样与网络自愈无外部缺口**，只差样本时间与人项（WiFi 凭据、物理键）。
4. **未验证项 3 条**：`qbootctl` 在机文本（离线 `strings` 证据，非上机输出）、`qbootctl -m` 是否复位 retry（`#672` 说不动，11-21 `getvar` 读到 6 不构成复位证据）、`deploy §13` 端到端（本轮设备在 BL，未跑）。

## §部署清单

按 §4 的 **S0→S8** 顺序执行，每步都可单独复跑判据：

- **S0** 只读现态（`qbootctl -a` / `is-enabled qbootctl.service` / `command -v python3`，预期无 python3）
- **S1** 判据字符串核对（`qbootctl -n b` 原文）——不匹配就停
- **S2** `bash scripts/deploy-desktop-shell.sh`（run，含新 §13）→ 判据 `--check` **MISS=0**
- **S3** `ssh elden-root 'ab-mark-successful --check'` → `MISS=0` + `Result=success`
- **S4** 一次冷起重启 → 新 `boot_id` + `enabled` + `Result=success` + `is marked successful`
- **S5** retry 语义只读补证（有 python3 才做，否则记「未验证」）
- **S6** `mobian-daily-baseline.sh --check` rc=0
- **S7** 资源按 §3 表落地（Qt → 相机 → Mesa 最后；每批立刻验收）
- **S8** `check-doctor.sh` FAIL=0（先 `python3 scripts/gen-scripts-index.py` 清既有的 2 条 §24）
- **回退**：`ab-mark-successful --uninstall`（保留 distro 语义）/ `systemctl mask` / Mesa `apt-mark unhold` + 装回 backports 26.1.6；**禁止** `fastboot erase misc`（会连槽位计数区一起抹）
