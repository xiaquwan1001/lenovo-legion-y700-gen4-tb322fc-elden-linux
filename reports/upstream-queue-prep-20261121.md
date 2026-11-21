# 上游队列备料 / 现查 / 上机执行单（2026-11-21）

> 本轮范围：**L3 只读+主机侧备料**。零发信、不碰设备、不改 `out/` 与 `patches/` 既有件（只新增目录）。
> 硬约束遵循：编译一律 `-j4` + `nice -n 15` + `flock /tmp/pi-heavy-build.lock` + `timeout -k`；无 `grow_loop`、无循环。
> 三节：§1 elden DTS v8 备料（产物 `patches/upstream/elden-dts-v8-prep-20261121/`）· §2 fastrpc v3 现查 · §3 dwc3 v10 的 G7 上机执行单。

---

## §0 数字结论（先看这三行）

| 项 | 结论 | 判据 |
|---|---|---|
| elden DTS v8 | **可备料**：3 文件 114 行；新门 **dtbs_check 0 诊断**（带依赖）、负样例 **5/8** 被拒、`checkpatch` 新增两枚 **0E/0W/0C**；**推荐拆成 v8（2 枚）+ v9（USB 部分）** | `patches/upstream/elden-dts-v8-prep-20261121/README.md` §0/§3 |
| fastrpc v3 | **未进 mainline/next**（7.4-rc3 两个 tip 的 `sm8750.dtsi` ADSP `fastrpc` 节点**没有** `qcom,non-secure-domain`，只有 CDSP 有）；patchwork `14971025` **state=new / commit_ref=None / 0 条评论**；**维护者只对 v1 回过一次**（Konrad，两条要求 v3 已全部落实）⇒ 技术零欠账，欠的是一次礼貌 ping | §2 |
| G7 上机 | **前置件不齐**：`patches/current-tree` 指向的 `build/daily`（vk192 的 7.3 树）**已不存在**；v10 三枚只对 7.4-rc3 干净 ⇒ G7 = 在 `build/elden-tree`(7.4-rc3) 上造新核 + **整套模块重部署**。执行单已给（§3），需用户决定「先恢复 7.3 树」还是「接受 7.4 全量」 | §3.1 · `ls build/`、`cat patches/current-tree` |

---

## §1 elden DTS v8 备料（详见目录 README，这里只留结论）

产物目录：`patches/upstream/elden-dts-v8-prep-20261121/`（README + 3 枚候选补丁 + 板文件全文 + `before-vs-v8.diff` + `evidence/` 8 份门日志 + `SHA256SUMS`）。

### 1.1 v7 → v8 差异（实测：纯增量 114 行，3 个文件）

| 文件 | 改动 | 行数 |
|---|---|---|
| `Documentation/devicetree/bindings/arm/qcom.yaml` | `sm8750` compatible enum 加 `lenovo,elden` | +1（v6 3/5 原件，v7 漏了） |
| `arch/arm64/boot/dts/qcom/sm8750.dtsi` | `usb@a600000/ports/port@0` 加标签 `usb_dwc3_hs_port:` | +1/−1 |
| `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts` | `usb_hs_mux`(gpio-mux on `&tlmm 29`) + `usb_con_main`/`usb_con_second` + `&tlmm eusb_mux_state` + `&usb{dr_mode=otg,mux-controls,status=okay}` + `&usb_dwc3_hs_port`(`/delete-node/ endpoint` + `endpoint@0 mux-state=0` / `endpoint@1 mux-state=1`) | +112/−0 |

v7 侧对照：板文件 129 行、**USB 相关命中 0**（连 `&usb` 都没 enable）。

### 1.2 两种拆法：推荐 **B（分开）**

- **A 一并**（单提交塞 3 文件）：整枚要等 dwc3 v10 **1/3 binding** 进树，否则维护者树上 `dtbs_check` 必红。
- **B 分开（推荐）**：`v8 = 0000 qcom.yaml + 0001(=v7 原文)` 立刻可投（零依赖、能消掉 v7 的 2 条 dtbs 诊断 + 1 条 checkpatch W）；USB 部分（dtsi label + 板件 mux）等 v10 进树后作 **v9** 投。
- 实测判据（依赖单向）：**不带** v10 binding 的 7.4-rc3 树上，我们的板件 **8 条诊断，其中 5 条**是 `mux-state`/`usb-role-switch`/`mux-controls` unexpected（`evidence/gate-v8-nov10-dtbscheck.log`）；带上 binding（+ qcom.yaml + wl2868c binding）后 **0 条**（`evidence/gate-v8-final-3dtb.log`，`DTC [C]` 3/3，dtb md5 `2d2d9266…`）。
- 不违反 Krzysztof 的 one-logical-action：他反对的是把**同一件**硬件拆两枚；`qcom.yaml` 是「document 已有 compatible」，与「加硬件」本来就两件事（v6 3/5 就是这个形状）。

### 1.3 门禁（本轮实跑，命令在目录 README §3.3）

| 门 | 结果 |
|---|---|
| `git am` 4 枚（qcom.yaml → v7 → label → mux），基点 `aebb727447` | **4/4 干净** |
| `checkpatch --strict`（树模式） | `0000` 0E/0W/0C（7 行）· `0001` 0E/0W/0C（8 行）· `0002` 0E/0W/0C（121 行）· v7 原样 = **0E/3W**（MAINTAINERS 提示 + `lenovo,elden` 未文档化 + `willsemi,wl2868c` 未文档化） |
| `dtbs_check`（`CHECK_DTBS=1`，**不带** `DT_SCHEMA_FILES`） | elden+mtp+qrd **3/3 `DTC [C]`，0 诊断** |
| 负样例（真 DTB） | 两 endpoint 同 `mux-state` ⇒ **5**；删 `mux-controls` ⇒ **8**（均被拒） |
| `dt_binding_check`（全量，先删旧 bundle） | **rc=0**，5420 example `DTC [C]`，0 error/warning 行 |
| 编译 | `make qcom/sm8750-lenovo-elden.dtb` rc=0，无 dtc 警告 |
| 未跑 | 上机（离线）；`DT_SCHEMA_FILES` 形状**故意不跑**（公共片段无 `select:` ⇒ 假绿，`PITFALLS #696`） |

### 1.4 本轮顺手纠正的两条事实

1. **`usb-role-switch` 不需要在板级 `&usb` 里加**：`sm8750.dtsi:3205` 已有（A/B 实测：加与不加 dtb md5 均 `2d2d9266…`）。`dwc3_drd_init()` 的进入条件因此天然满足，mux 代码会真的跑。
2. **v7 的板件根本没 enable USB**（`&usb` 缺席）⇒ 之前把「板 DTS 已含 USB」当既有事实的任何说法都错，本目录 v8 才是第一次 enable。

---

## §2 fastrpc v3 现查（口径：§7「三条限定」+ wl2868c 实发反例）

### 2.1 代次与 patchwork（REST 直查，2026-11-21 13:0x）

```
GET patchwork.kernel.org/api/1.2/patches/14971025/      → state=new, commit_ref=null, archived=false
date=2026-11-11T03:57:31  name="[v3] arm64: dts: qcom: sm8750: mark the ADSP fastrpc node as non-secure domain"
project=linux-arm-msm  series=1207873 (version=3, received_total=1)
GET .../patches/14971025/comments/                      → n=0
```
同族历史：v1 `14959877`（11-07，superseded）· v2 `14966246`（11-10，superseded）· **v3 `14971025`（11-11，new）** ⇒ **最新代次 = v3，未再被取代**。

### 2.2 维护者回信（作者/时间/摘要，逐条）

| 谁 | 时间 | 内容 | 我方是否已落实 |
|---|---|---|---|
| **Konrad Dybcio** `<a32b69d2-80e2-49c5-bb44-d7e808253ca5@oss.qualcomm.com>` | 2026-11-09T14:16:40+0100（= 13:16Z），回 **v1** | ①「Hm, this is a nuanced case - adding +Ekansh, +Dmitry and +Srini」（把三位 Qualcomm fastrpc 侧的人拉进线程）；②「Please keep that [AI-assistance disclosure] under the `---` line so it doesn't end up in the commit log」 | **两条都已在 v3 落实**（披露段在 `---` 下；v3 的 changelog 也写明「move the changelog below the --- line, use a 12-character Fixes hash and place the new property after memory-region」） |
| v3 之后 | — | **0 封**（lore 线程共 4 条消息：v1 / Konrad / v2 / v3；patchwork comments 0） | — |

口径提醒：`state=new` + `commit_ref=null` **不构成未合并证据**（wl2868c 反例：arm-msm 副本今天仍 new，实际已进 `regulator.git for-7.5`）。所以下面做内容级判定。

### 2.3 内容级判定（mainline + next，2026-11-21）

抓取目标：`git.kernel.org/.../{next/linux-next,torvalds/linux}.git/plain/arch/arm64/boot/dts/qcom/sm8750.dtsi`

| 树 | tip | 版本 | `grep -c non-secure-domain` | ADSP `fastrpc` 节点 |
|---|---|---|---|---|
| linux-next | `909ef7a9a30fa139e69e555e3606680f5cca7726` | 7.4.0-rc3 | **1**（只有 CDSP，`sm8750.dtsi:6419`） | `:2570` label=adsp → `memory-region` → `qcom,vmids`，**无 `qcom,non-secure-domain`** |
| torvalds | `c44104f3642da720164042623e4832836aefdd8e` | 7.4.0-rc3 | **1**（同上） | 同上，无该属性 |

⇒ **未进 mainline、也未进 next**（不是「patchwork 没记」这种间接证据）。

### 2.4 我方欠什么

| 项 | 结论 | 依据 |
|---|---|---|
| 技术欠账 | **0**：Konrad 的两条（披露段位置、把 +3 人拉线程这条不是动作项）+ sashiko 的 `Fixes:` 要求都已在 v3 | §2.2 表、lore 正文 `v3:` 段 |
| 流程欠账 | **一次礼貌 ping**（线程静默 10 天，v3 发出后无人回）。口径：不催技术结论，只问「v3 是否可入 7.5」；人员 = 原 To（`andersson`/`konradybcio`）+ 已进线程的 `ekansh.gupta`/`dmitry.baryshkov`/`srinivas.kandagatla` | §2.2 |
| 内容/上下文风险 | **低**：v3 的插入点（`memory-region` 之后）在 7.4-rc3 next 树里上下文仍逐行一致；`qcom,non-secure-domain` 仍被驱动使用（`drivers/misc/fastrpc.c:2754` `secure_dsp = !of_property_read_bool(... "qcom,non-secure-domain")`）、binding 仍收录（`qcom,fastrpc.yaml:58`，example `:141` 就在用） | 同次抓取 |
| 相邻系列影响 | ① **`qcom,nsessions` 已废弃并合入**（`641dd7dd0f68`），但 `sm8750.dtsi` 里本来就没有该属性 ⇒ **无清理债**；② 上游方向「减少 secure CB」（Ekansh `lemans: Remove secure FastRPC context bank` `14973058` 已 `in-next`）与本补丁「把 ADSP 标成 non-secure」**同向**，不冲突 | patchwork REST + next 树 grep |
| 先例强度 | 同类「补 `qcom,non-secure-domain`」历史件多枚 `accepted`（sm8450/8550/8650 三枚 2024-02-27；sm6350 2024-07-05）⇒ 形状本身不是争议点 | patchwork `q=non-secure-domain` 全项目查 |

---

## §3 dwc3 v10 的 G7 上机执行单（给主会话，一页照做）

> G7 = **运行期**验证：mux 真的切换、两口各自能枚举、角色切换不走错口。cover 已声明 "No runtime testing is claimed"，所以这是**唯一剩下的门**。
> 本轮**没有**上机（离线 + 本轮禁碰设备）。下面是照做清单，含前置件缺口。

### 3.1 需要哪些件（`ls` 已校验，`sha256` 前 16 位现算）

| 件 | 路径（仓库内，实存） | 大小 | sha256[:16] | 用途 |
|---|---|---|---|---|
| 内核树（v10 唯一干净基点） | `build/elden-tree`（HEAD `aebb727447` = 7.4-rc3） | — | — | 打 v10 1–3/3 + elden DTS v8 后造核 |
| 设备侧回退件（当前在机 b 槽） | `logs/forensics-20261120-2210/boot_b.img` | 100 663 296 | `740d431b2577f95a` | 出事回写（**只在需要时**） |
| vk192 空载件 | `out/boot-elden-vk192.img` | 85 815 296 | `bdf47f5f3f8a49e8` | 对照/回退（不含 v10） |
| vk192 b 槽自签件 | `bootslot-b/boot_b.img` | 100 663 296 | `06c081ca4af94915` | 对照 |
| 设备日线 config（7.3 线） | `patches/config-daily-c2-suspend-20261113` | 327 475 | `79f288cf36183efa` | 造 7.3 核时用；造 7.4 核需先 `olddefconfig` 并核对 `CONFIG_ARCH_QCOM=y` |
| 造核 | `scripts/build-kernel.sh` | 2 535 | `f24d43bff38fde03` | `KDIR=<tree> scripts/build-kernel.sh`（**禁裸 make**） |
| 打包 boot.img | `scripts/build-boot.sh` | 5 882 | `40c0dc1c2ff6920a` | 带 cmdline `elden_root=LABEL=linux` |
| 自签 b 槽件 | `scripts/sign-boot-b.sh` + `bootslot-b/avb.key` | 1 772 / 3 247 | `93881225…` / `dcdb033c…` | RAM 起机**不必**签名（`fastboot boot` 用空载件即可），持久刷才需要 |
| 构建硬门 | `scripts/assert-kernel-sane.sh` | 5 722 | `d1506550c53a5009` | 造完必跑 |
| 进 fastboot（软路径） | `scripts/to-bootloader.sh` | 5 813 | `4021e5aceac23592` | ⚠ 实测**软路径全灭**（`PITFALLS #701`）⇒ 进 BL 只能**物理键**（用户动作） |
| SSH 通路 | `scripts/ncm-host-up.sh` | 1 797 | `7633d71ddf8ae0e0` | `usb0` 192.168.7.1 |

**缺件（本轮新查出，必须先决策）**：

1. `patches/current-tree` 里写的是 `build/daily`（vk192 的 7.3.1 树），**该目录已不存在**（`ls build/` 只有 `elden-tree` + 4 个非内核目录）⇒ 想造「与在机同版本」的核得先恢复 7.3 树（`.ko` 可复用，省一次全量模块重编）。
2. v10 三枚的基线 = **7.4-rc3**（`GATES-20261121.md` §0）。若直接在 `build/elden-tree` 造核：**UTS 变化 ⇒ 必须整套模块重编 + 部署**（客上 `/lib/modules/<新 UTS>/`，历史规模 1510 个 `.ko`；本机限 `-j4`，会比平时慢数倍）。
3. 无 G7 用的现成 boot.img（`out/` 里没有任何含 v10 的件）⇒ G7 第一步就是造件。

### 3.2 造件（主机侧，顺序照抄）

```sh
cd /home/xuqianhui/y700-elden
# 1) 门树：7.4-rc3 + v10 1..3/3 + elden DTS v8（label + mux）
git -C build/elden-tree worktree add --detach /tmp/g7-tree aebb727447
cd /tmp/g7-tree && git am /home/xuqianhui/y700-elden/patches/upstream/dwc3-v10-20261120/v10-000{1,2,3}-*.patch
git am /home/xuqianhui/y700-elden/patches/upstream/elden-dts-v8-prep-20261121/000{0,1,2}-*.patch   # 0=qcom.yaml 1=label 2=板件
# 2) 设备 config（7.3 线的整份快照直接当 .config ⇒ 必须 olddefconfig 后核锚点）
cp patches/config-daily-c2-suspend-20261113 /tmp/g7-tree/.config
make -C /tmp/g7-tree ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
grep -E '^CONFIG_(ARCH_QCOM|USB_DWC3_DUAL_ROLE|MULTIPLEXER|USB_ROLE_SWITCH|TYPEC)=y' /tmp/g7-tree/.config
# 注：不要用 scripts/apply-kernel-fragment.sh（它吃的是 fragment 且会往 patches/ 写 .bak 快照，本轮口径是“只新增目录”）
# 3) 造核/模块（限并发；-j4 是本轮硬约束，正常轮可用 -j26）
KDIR=/tmp/g7-tree JOBS=4 scripts/build-kernel.sh Image.gz dtbs
KDIR=/tmp/g7-tree JOBS=4 scripts/build-kernel.sh modules
scripts/assert-kernel-sane.sh          # 造完硬门；FAIL 不出件
# 4) 打包（cmdline 按 build-boot.sh 自带逻辑写 elden_root=LABEL=linux；打包前会跑 assert-kernel-sane）
KDIR=/tmp/g7-tree VERSION=vk193 bash scripts/build-boot.sh     # → out/boot-elden-vk193.img
sha256sum out/boot-elden-vk193.img
```

### 3.3 上机（设备侧，POSIX sh；**RAM 起机 = 零写盘**）

前置人项（用户做）：长按电源 10 s 断电 → 音量上+电源进 fastboot（软路径已废，`PITFALLS #701`）；插线后主机 `sudo scripts/ncm-host-up.sh`。

```sh
# S1 零写盘起机（不刷任何分区）
fastboot boot out/boot-elden-vk193.img          # 期望 OKAY + ~25 s 到 ssh
ssh root@192.168.7.1 'uname -r; uptime'         # 判据：UTS = 新核
```

| # | 验什么 | 命令 | 判据（预期） | 预期日志/关键字 |
|---|---|---|---|---|
| T1 | mux 被 `gpio-mux` 持有 | `cat /sys/kernel/debug/gpio \| grep -A1 'gpio-29'` | `gpio-29 … gpio-mux` 且 `out lo` | 无（debugfs） |
| T2 | 两个 role switch 注册 | `ls /sys/class/usb_role/` | **`a600000.usb-port0`** 与 **`a600000.usb-port1`** | `dmesg \| grep -i 'usb_role\|dwc3'` |
| T3 | mux 代码真的接管（互斥） | `echo host > /sys/kernel/debug/dwc3.a600000.usb/mode` | **写失败**：`Device or resource busy`（= `-EBUSY`，`dwc3-0003` 加的判据） | — |
| T4 | 角色请求 → 主机模式 | `echo host > /sys/class/usb_role/a600000.usb-port0/role; cat /sys/class/usb_role/a600000.usb-port0/role` | `host`；随后插 U 盘到**该口** | `usb 1-1: new high-speed USB device` + `lsusb` 出现新 VID |
| T5 | 角色请求 → 设备模式 | `echo device > /sys/class/usb_role/a600000.usb-port0/role; ls /sys/class/udc/; cat /sys/class/udc/a600000.usb/state` | `/sys/class/udc/` 出现 `a600000.usb`；插到主机口后 `state=configured` | 主机 `lsusb` 见新设备；客 `dmesg` 有 `gadget`/`configfs` 相关行 |
| T6 | **换口**（A→B）不改错口 | 端口轮询脚本（下方）＋ `echo host > …-port1/role` | `gpio-29` 电平**单次跳变**（0→1 或 1→0），**无中间态翻转** | `dmesg -w` 同窗口无 `dwc3.*reset` 风暴 |
| T7 | 两口各自枚举（物理） | 依次只插 A、再只插 B：`dmesg -C; <插>; sleep 3; dmesg \| grep -c 'new high-speed USB device'` | 每次 **1**；另一个口插着时不产生事件（同一条 HS 线**只能**通一个口） | — |
| T8 | 极性/0↔口定死（可选，便宜） | `gpioset gpiochip0 29=0/1`（宿主手工翻转）后重复 T7 | 记录「电平 ↔ 哪个口枚举」= 唯一能给出 0/1 与长/短边对应的办法 | — |

T6 轮询脚本（设备侧，POSIX sh，整文件 scp 后 `sh`）：

```sh
i=0; while [ $i -lt 200 ]; do
  printf '%s ' "$(awk '/gpio-29/{getline; print $1}' /sys/kernel/debug/gpio)"
  i=$((i+1)); sleep 0.05
done | tr ' ' '\n' | uniq -c     # 期望：两段，各 ~100 次，无第三段
```

**T9 明确不测（写清原因，别当漏做）**：DP/altmode、SBU 方向、SS 超速 —— 本轮板 DTS 里 `usb_hsphy`/`usb_dp_qmpphy` 仍 `status="disabled"`、两颗 `fsa4480` 与 `pmic-glink`/`ucsi` 都没描述；两个 connector 是**根级**、只表达 HS 各一个座（`patches/upstream/dwc3-v10-20261120/README.md` §7.4 第 2–3 条）。

### 3.4 失败取证（任一条不符就跑这组，一次抓全）

```sh
ssh root@192.168.7.1 '
  dmesg > /tmp/g7-dmesg.txt
  { uname -r; uptime; } > /tmp/g7-env.txt
  cat /sys/kernel/debug/gpio > /tmp/g7-gpio.txt 2>&1
  ls -l /sys/class/usb_role/ /sys/class/udc/ > /tmp/g7-class.txt 2>&1
  cat /sys/class/usb_role/*/role > /tmp/g7-roles.txt 2>&1
  cat /sys/kernel/debug/dwc3*/mode /sys/kernel/debug/dwc3*/link_state > /tmp/g7-dwc3.txt 2>&1 || true
  lsmod | grep -E "dwc3|mux|role|typec" > /tmp/g7-lsmod.txt
  cat /proc/interrupts | grep -i usb > /tmp/g7-irq.txt
'
scp root@192.168.7.1:/tmp/g7-*.txt reports/artifacts/g7-<日期>/    # 目录只新增
scripts/trial.sh ...   # 项目纪律：一次设备实验一条 record，无 record 不写 verdict
```

典型失败 → 先查什么：

| 现象 | 先查 | 常见真因 |
|---|---|---|
| T2 没有 `usb_role` 目录 | T1 的 gpio 是否被 `gpio-mux` 持；`dmesg \| grep -i 'mux\|role'` | `mux-controls` 没生效（dtb 没更新/板件没 apply）或 `mux_control_states < 2` ⇒ `dwc3_role_mux_init` 返回 `-EINVAL` |
| T3 能写 mode（没 EBUSY） | 同上 | role_mux 没建成 ⇒ 落回单连接器路径 |
| T4/T5 角色写了但不枚举 | `cat /sys/class/usb_role/*/role`、`gpio-29` 电平 | mux 状态没跟随（`dwc3-0003` 的 drd 路径没跑到）或极性/0↔口反（T8 才能定死） |
| 枚举偶尔出现但掉 | `dmesg \| grep -i 'reset\|over-current'` | 换口瞬态（若有人加了非 AS_IS `idle-state`）；本轮候选**故意省略** `idle-state` |
| 起机就 panic/deferred | `dmesg \| head -50` | phy/regulator 依赖（本 DTS 两个 phy 仍 disabled ⇒ 只应影响 SS，不影响 HS） |

### 3.5 回退路径

1. **默认零写盘**：RAM 起机不写任何分区 ⇒ 最坏情况「长按电源 10 s 断电 → 正常开机」即回 vk192（`boot_b`，sha `740d431b…`）。
2. **若进了持久路线（刷了 `boot_b`）**：回写 `logs/forensics-20261120-2210/boot_b.img` → `sync` → 读回 `sha256sum` 比对 `740d431b2577f95a…`。
3. **进不了 fastboot**：物理键（音量上+电源）为主路径；`scripts/to-bootloader.sh` 只作诊断（软路径实测全灭，`PITFALLS #701`）。
4. **不要**在 G7 里碰 `vbmeta_*`/GPT/`super`/`userdata`（与本任务无关，且是当前唯一不可快速恢复的面）。

---

## §4 本轮产物与校验

```
patches/upstream/elden-dts-v8-prep-20261121/{README.md,0000-*.patch,0001-*.patch,0002-*.patch,
  sm8750-lenovo-elden.dts,before-vs-v8.diff,evidence/(8 份门日志+checkpatch.txt),SHA256SUMS}
reports/upstream-queue-prep-20261121.md   （本文件）
```

复核命令（任何人可复跑）：

```sh
ls -l patches/upstream/elden-dts-v8-prep-20261121/ patches/upstream/elden-dts-v8-prep-20261121/evidence/
cd patches/upstream/elden-dts-v8-prep-20261121 && sha256sum -c SHA256SUMS | grep -c ': OK'
grep -cE "^(ERROR|WARNING)" evidence/checkpatch.txt      # 期望 3（全部来自 v7 原样复跑）
grep -cE "^arch/arm64/boot/dts/qcom/.*elden\.dtb: " evidence/gate-v8-final-3dtb.log   # 期望 0
grep -cE "^arch/arm64/boot/dts/qcom/.*elden\.dtb: " evidence/gate-v8-nov10-dtbscheck.log # 期望 8
```

---

## §5 本轮副作用与复原（如实记账）

- 为跑门禁在 `/tmp` 建了两处内核工作区（`git -C build/elden-tree worktree add --detach`）：`/tmp/elden-v8-1121`（打 v7+候选做 `format-patch`）与 `/tmp/v8-am`（`git am` 顺序 apply）；**收尾已 `worktree remove --force` + `prune`**，`build/elden-tree` 仍 `aebb727447`、`git status` 干净。
- 门树 `/tmp/elden-gate`（7.4-rc3 全量副本，含 v10 1/3 + qcom.yaml + wl2868c binding）**保留**，下一轮复核可直接复用（`README.md` §3.3 的命令假定它存在）。
- `scripts/check-doctor.sh` 全量跑过一次，§24 反作弊步骤在本机留下过一版被改坏的指纹（`scripts/README.md:1` 变成 `fp=d34b0000`，§24 报 `反作弊②收尾失败` + `scripts/README.md 过期` ⇒ 一次 `FAIL=2`）；处理 = `git checkout -- scripts/README.md` 后 `gen-scripts-index.py --check` **rc=0**，再跑全量 doctor = **FAIL=0 / WARN=6（全部 C 类存量：源树已档、`patches/current-tree` 指向已删的 `build/daily`、无内核树 `.config` 等）**。这条 WARN 里的「无构建树可用」「无内核树 .config」**正是 §3.1 那个前置件缺口的机器侧佐证**。
