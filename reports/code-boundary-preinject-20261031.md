# code-boundary 投递前静态门禁独立复核 — 2026-10-31

> 派工单 L1-D：对两批「门禁已过、待用户按批放行」补丁做**独立复跑**（不信任既有回执），给可投/不可投判断。
> 纯主机侧：**未投递 / 未发信 / 未 commit / 未碰设备 / 未改 SSOT / 未改 `patches/` 内补丁本体**。
> 构建只在 `/tmp` 临时 worktree（基点 pristine `24a19b953e` = Linux 7.3-rc7）做，一律 `make -j26`、命令带 `timeout -k 30`。
> 日志：`reports/artifacts/code-boundary-preinject-20261031/`。
> 状态词只用「已证 / 未证实 / 未上机」。

## 0. 结论（逐批）

| 批次 | 判定 | 一句话 |
|---|---|---|
| **wl2868c-v2b（4 枚）** | ✅ **可投（静态门全绿），但投递前须人工撰稿 + 处置 2 个会被挑点** | checkpatch/DTC/binding/重放全过；3/3 的 5 条 WARNING 全部可分类，非阻断 |
| **m3v5（2 枚）** | 🟡 **静态/构建/重放门全绿，但**当前落盘形态**不可直接投** | v5 对 pristine **不自足**（须 v4×3 打底）；目录内无 cover 说明该依赖与 `usb_role_switch_at_endpoint()` 不在 7.3-rc7 |

两批**均无占位身份（`elden-mainline@localhost`）、无 `qcom,sm8750-lenovo-elden` 残留、无 vk/`force_hz`/`module_param`/调试钩子/`NOT FOR UPSTREAM`** 等下游专用内容混入（逐枚 grep 0 命中）。

---

## 1. 关键数字（本人独立复跑）

### 1.1 checkpatch --strict --no-signoff（**stdin 投递，权威**）
> **方法论纠正（重要）**：本树 `scripts/checkpatch.pl`（v0.32）**以文件参数**喂 mbox 补丁会误解析邮件头
> （行数虚高：v5-0001 报 185 行、v5-0002 报 310 行），并把 **diff 上下文空行 `␠` 与 git `--␠` 签名行**误判成
> `ERROR: trailing whitespace`（每枚 2–18 条假 ERROR）。改 `cat patch | checkpatch --strict --no-signoff --patch -`
> 后与既有回执**逐字吻合**。added `+` 源码行 trailing-ws = 0（用 `grep -cP '^\+.*[ \t]+$'` 证）。
> **既有回执的 0E 可信；用文件参数复跑会得到假 FAIL，勿据此回退补丁。**

| 补丁 | E | W | C | lines |
|---|---|---|---|---|
| v3-0000 cover | 1 | 1 | 0 | 0（cover，不受 checkpatch 约束）|
| v3-0001 binding | **0** | 0 | 0 | 91 |
| v3-0002 driver | **0** | 0 | 0 | 186 |
| v3-0003 board DTS | **0** | 5 | 0 | 340 |
| v5-0001 binding | **0** | 0 | 0 | 142 |
| v5-0002 driver | **0** | 0 | 0 | 222 |

- **v3-0003 的 5 条 WARNING（逐条）**：① `DT binding docs and includes should be a separate patch`（arm/qcom.yaml 一行板 compatible 与板 DTS 同补丁 —— 上游「新板 + 登记 qcom.yaml」常见做法，启发式假阳性）；②③④ `un-documented compatible`：`giantec,gt9764` / `samsung,s5kjns` / `galaxycore,gc08a8`（**真告警，但属相机系列**，见 §3）；⑤ `MAINTAINERS need updating?`（`ARM/QUALCOMM SUPPORT` 段已含 `arch/arm64/boot/dts/qcom/` glob，假阳性）。
- ⚠ **文档漂移**：`TASKS/README.md §7 M4` 与本报告 `reports/wl2868c-v2b-20261030.md` §0 均写「3/3 0E/**2W**」，**实测 = 0E/5W**（差的 3 条即上述未登记 sensor compatible）。

### 1.2 wl2868c 构建 + binding（在 replay 树 /tmp/cb-wl，O=/tmp/cb-wl-out）
| 门禁 | rc | 关键计数 |
|---|---|---|
| `qcom/sm8750-lenovo-elden.dtb`（W=1）| **0** | ERROR=**0**；仅 2 条**基线 `sm8750.dtsi`** 既有 `avoid_unnecessary_addr_size`（dsi@ae94000/@ae96000），新板未引入 |
| `qcom/sm8750-mtp.dtb`（对照）| 0 | ERROR=0 |
| `drivers/regulator/` W=1 | **0** | warning:=0 error:=0；`wl2868c-regulator.o` = 49368 B |
| `dt-doc-validate willsemi,wl2868c.yaml` | 0 | 输出 **0 字节** |
| `dt-doc-validate arm/qcom.yaml` | 0 | 输出 **0 字节** |
| `dt-check-style --mode=strict willsemi,wl2868c.yaml` | 0 | 输出 **0 字节**（v2 的 property-order nit 仍消除）|
| `dt-validate -m -s bindings elden.dtb` | 0 | **7 行**，全部 = 3 个未登记 sensor compatible + 2 派生类型错（**不在本系列**）|

### 1.3 m3v5 构建（在 replay 树 /tmp/cb-m3，O=/tmp/cb-m3-out）
| 门禁 | rc | 计数 |
|---|---|---|
| `make W=1 drivers/usb/dwc3/ drivers/usb/roles/`（`CROSS_COMPILE=aarch64-linux-gnu-` 显式传）| **0** | warning:**0** error:**0**；实编 32 个 CC 行 |

> 复现工具链坑：必须 `CROSS_COMPILE=aarch64-linux-gnu-`，缺省首轮 `rc=2`（gcc `-mlittle-endian` 不识别）= 工具链假故障，非源码缺陷（与 `reports/m3v5-prefetch-regression-20261030.md` 同口径）。

### 1.4 pristine 重放一致性（基点 24a19b953e，git am）
| 批次 | am | 终态 vs 分支 tip |
|---|---|---|
| wl 3 枚（0001/0002/0003，跳 cover）| **3/3 rc=0** | 终态树与 `build/wl-v2` tip `315a6afcbf` **逐字节相同（0 文件差异）** |
| m3 v4×3 + v5×2 | **5/5 rc=0** | 终态树与 `build/m3v5-pristine` tip `34865c8915` **逐字节相同（0 文件差异）** |
| **m3 仅 v5×2 打 pristine**（负向）| **FAIL rc=128** | `snps,dwc3-common.yaml:31` 补丁未应用 ⇒ **v5 对 pristine 不自足，必须 v4×3 打底** |

> **`build/wl-v2` 实际 tip = `315a6afcbf`**，v3-0003 的 `From` 头 = `315a6afcbf`；`reports/wl2868c-v2b-20261030.md` §1/§2.6 记录的 `18297199de` 与其 4 枚 md5 **均已过期**（补丁在「compatible 改 `lenovo,elden`」后重出，`compatible` 现 = `"lenovo,elden", "qcom,sm8750"`，无 `qcom,sm8750-lenovo-elden` 残留 —— 该检查 PASS）。当前落盘 4 枚 md5 见 §4。

### 1.5 base-commit trailer
**两批 6 枚补丁均无 `base-commit:` 尾注**（生成时未带 `--base`）。派工单「以补丁内 base-commit 为准」无法执行 ⇒ 本次以补丁 `From` 头 + 分支历史推得基点（wl = 24a19b953e；m3 = 24a19b953e + v4×3）。

---

## 2. 上游化三问门判定

| 补丁 | Q1 有主线子系统？ | Q2 有同类芯片驱动？ | Q3 硬件事实/软件策略分置？ |
|---|---|---|---|
| wl2868c binding | ✅ `regulator`（红线框架）+ `of_match` 用 `willsemi,wl2868c` | ✅ 上游无 wl2868c，按 regulator 规范新写，合规 | ✅ 电压/区间走 binding+DTS；C 内 `enable_time=150`/`max_register=0x25`/`ID_VALUE=0x82` 是 **regulator_desc 表项**（与全部 regulator 驱动同形，非 Q3 违例，但**出处**见 §3）|
| wl2868c board DTS | ✅ devicetree | ✅ 复用 `sm8750-mtp.dts` 的 fixed-clock/fixed-factor（`xo_board`/`sleep_clk`/`bi_tcxo*_div2`），未造异名节点 | ✅ 纯 DT |
| m3v5 0001 binding | ✅ `usb`/`typec` binding | ✅ 扩 `snps,dwc3-common.yaml`（regex `endpoint(@[0-9a-f]+)?` + 每 port 单 endpoint + `mux-state`）| ✅ 拓扑事实进 DT |
| m3v5 0002 driver | ✅ dwc3/roles 框架，复用 `glue_ops`/`pre_set_role` | ✅ 未新造子系统 | ✅ 角色状态机进 C |

**两批均通过三问门。**

---

## 3. 「若被问会被挑的点」+ 最小改法

### wl2868c
1. **3/3 越界携带相机节点**：标题「describe the WL2868C **regulators**」，却在 `sm8750.dtsi`/板 DTS 同时新增 `qcom,sm8750-cci`、`camera@56`(s5kjns)、`camera@31`(gc08a8)、`lens@c`(gt9764) —— 正是 3 条 un-documented 告警来源。**最小改法**：把相机/lens/CCI 子节点从 3/3 摘出，随相机系列（binding 随行）投；本板 DTS 只留 PMIC/clocks/regulator 消费者。或至少 cover 里点明「相机 binding 另系列，本板 DTB 能编、`dt-validate` 剩余告警由它承担」。
2. **`enable_time=150` / `max_register=0x25` / `ID_VALUE=0x82` 单源未证实**（`reports/wl2868c-v2b-20261030.md` §3.3）：**最小改法** = cover 或 binding 正文注明数据手册出处；无手册则以「厂商 regulator 驱动/数据段实测」措辞，别裸给魔数。
3. **vin12/34/5..7-supply 全缺**（dummy regulator 回落）：reviewer 会问消费者电源从哪来 ⇒ cover 说明当前回落与后续接线计划。
4. **MAINTAINERS 新段**（假阳性，但确保 F: glob 覆盖 `drivers/regulator/wl2868c*` 与新 binding 路径，别让 0001 与 0002 各加一半）。

### m3v5
1. **`usb_role_switch_at_endpoint()` 不在 7.3-rc7**（由 v4-0002 `a0a5d3f1f5` 引入）：v5-0002 直接**修改**该函数（`if (!IS_ERR_OR_NULL(sw))`→`if (sw)`，保 `-EPROBE_DEFER`，即绑定根因 F1）。**最小改法** = **补 cover**：写明「本系列 supersede v4、依赖 v4 引入的 `usb_role_switch_at_endpoint()` helper」，或把 v4 一并作为 v5 系列重发（否则 reviewer `git am` v5 直接失败，见 §1.4 负向测试）。
2. **0002 文件数**：实测 = **4 文件**（core.c/core.h/drd.c/roles/class.c），`TASKS §7` 与 `reports/m3v5-prefetch-regression-20261030.md` 记「5 文件」为**文档漂移**（不改补丁，改文档由总管收口）。
3. **binding 形状已被上机证「DTS 对、binding 曾错」**：v5-0001 已改为「两 port、每 port 单 endpoint、mux-state 在 endpoint」——确认与板 DTS `port@0`+`port@2` 一致（`reports/m3v5-binding-reshape-20261030.md` 探针矩阵）；cover 应引用该形状结论，避免 Konrad/Krzysztof 再问拓扑。

---

## 4. 投递前仍差什么（硬项）

1. **wl2868c**：**回信/cover 必须人工撰稿**（信誉事件：Krzysztof 三次点名 `LLM-generated slop`；`reports/upstream-status-20261029.md` §2）。且建议先处置 §3.1（相机节点是否留在本系列）。
2. **m3v5**：**目录内缺 cover letter**，且必须新增说明 —— ① supersede v4；② 依赖 v4 引入的 `usb_role_switch_at_endpoint()`（不在 7.3-rc7）；③ binding 形状结论引用；④ 未上机（pristine 血统内核上机两发早期失联，`PITFALLS #472`；行为证据以 daily 血统 `m3v5-f2` 为准，pristine 系列只作投递形状门）。
3. **两批均缺 `base-commit:` 尾注**：正式投递建议 `git format-patch --base=<base>` 重出（wl base=24a19b953e；m3 base=v4-tip），便于 reviewer 定位。
4. 投递动作本身 = **用户按批放行**（`TASKS §7` 口径），本 lane 不发信。

---

## 5. 落盘件身份（当前磁盘 md5）
```
# wl2868c-v2b-20261030/（与 reports/wl2868c-v2b §2.6 旧 md5 全部不同 = 已在 compatible 改名后重出）
749e4e6fe6fe85a862a8d89cd8648180  v3-0000-cover-letter.patch
df6c7ee4712d1bae5dccc3e4c1aaba1b  v3-0001-...-add-the-WL.patch
e990de087d5155f17a8613107d7eef08  v3-0002-...-camera.patch
da4c806c2090c4ffaf82a5c34b39629a  v3-0003-...-describe-the-W.patch
# m3v5-20261030/
b63599e16081c9f859814ede32ab54fe  v5-0001-...-tighten-the-two-connect.patch
a271b1cb7b5e1cdc81769189d99dfb8a  v5-0002-...-shared-HS-bus-role.patch
```

---

## 6. 复现命令
```sh
R=/home/xuqianhui/y700-elden; CP=$R/build/wl-v2/scripts/checkpatch.pl
D=$R/patches/upstream/wl2868c-v2b-20261030; M=$R/patches/upstream/m3v5-20261030; V4=$R/patches/upstream/m3-v4-20261026
# 1) checkpatch（务必 stdin，否则文件参数触发假 trailing-ws ERROR）
for f in $D/v3-000*.patch $M/v5-000*.patch; do cat "$f" | perl $CP --strict --no-signoff --patch - | grep '^total:'; done
# 2) 重放（临时 worktree，基点 24a19b953e）
git -C $R/build/wl-v2 worktree add --detach /tmp/cb-wl 24a19b953e
for p in $D/v3-0001*.patch $D/v3-0002*.patch $D/v3-0003*.patch; do git -C /tmp/cb-wl am "$p"; done
git -C /tmp/cb-wl diff --quiet 315a6afcbf && echo "wl terminal == tip"
git -C $R/build/m3v5-pristine worktree add --detach /tmp/cb-m3 24a19b953e
for p in $V4/000[1-3]*.patch $M/v5-000[12]*.patch; do git -C /tmp/cb-m3 am "$p"; done
git -C /tmp/cb-m3 diff --quiet 34865c8915 && echo "m3 terminal == tip"
# 3) wl DTB（核心）+ binding
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-; O=/tmp/cb-wl-out
make O=$O defconfig; ./scripts/config --file $O/.config --module REGULATOR_WL2868C; make O=$O olddefconfig
make O=$O -j26 W=1 qcom/sm8750-lenovo-elden.dtb; make O=$O -j26 W=1 drivers/regulator/
V=~/.local/opt/dtschema-venv/bin
$V/dt-doc-validate /tmp/cb-wl/Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml
$V/python /tmp/cb-wl/scripts/dtc/dt-check-style --mode=strict /tmp/cb-wl/Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml
$V/dt-validate -m -s /tmp/cb-wl/Documentation/devicetree/bindings $O/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
# 4) m3 W=1（CROSS_COMPILE 必显式传）
OM=/tmp/cb-m3-out; make O=$OM defconfig
./scripts/config --file $OM/.config --enable COMPILE_TEST --module USB_DWC3 --enable USB_ROLE_SWITCH --enable TYPEC
make O=$OM olddefconfig; make O=$OM -j26 W=1 drivers/usb/dwc3/ drivers/usb/roles/
# 5) 清理
git -C $R/build/wl-v2 worktree remove --force /tmp/cb-wl; git -C $R/build/m3v5-pristine worktree remove --force /tmp/cb-m3
```

**写路径**：本报告 + `reports/artifacts/code-boundary-preinject-20261031/*.log`。
临时 worktree（/tmp/cb-wl、/tmp/cb-m3、/tmp/cb-m3bare）在收口时 `worktree remove` 清理；`build/wl-v2`、`build/m3v5-pristine` 工作区**未被触碰**（tip/dirty 行数收口前已核）。
