# M1-73（7.3-rc7 重基树）上机启动失败 — 静态取证与对照镜像

> 日期：2026-10-13 ｜ 机型：TB322FC / SM8750P (elden) ｜ 设备：**全程未触碰**（只做主机侧静态分析 + 造镜像）
> 关联：`out/boot-elden-m1-73.img`（新内核+新DTB+vk126 ramdisk，上机黑屏约 39s 回旧系统）
> 本报告只写两条产物路径：`reports/m1-73-boot-failure-20261013.md`、`out/boot-elden-m1-73d.img`（必要时 `...e.img`）。

## 0. 现场事实（编排者实测，直接引用）

- 新树镜像 `out/boot-elden-m1-73.img`：内核 `7.3.0-rc7-debug-ged6f232d10e3`（Image.gz）+ 新树板 DTB（153262 B，含 `framebuffer@fc800000`）+ vk126 ramdisk（另加 36 个 .ko 与 payload 加载器）。
- 上机：`fastboot boot` 报 `Booting OKAY`，但**背光一直不亮（黑屏）**、**新内核从未拉起 USB gadget**（主机 journal 无 cdc_ncm/cdc_acm 事件），约 **39 s** 后回到旧系统（`7.2.0-debug-vk64…`）——与 `panic=15` + 旧系统冷启耗时吻合。设备无损伤。
- 已排除（编排者）：镜像头/命令行、内核 gzip 形式、背光(aw99706)/面板(nt36536) 驱动、SM8750 时钟/pinctrl/interconnect config、USB gadget config、**模块层**（v2 镜像 = 同内核同 DTB + 纯 vk126 ramdisk/零 .ko，同样失败）。
- 现役 vk126 用 `out/sm8750-lenovo-elden-dtbold.dtb`（149063 B，**不含** simple-framebuffer）；新树 DTB 153262 B **含**。

## 1. 两 DTB 逐节点差异表

- 新树 DTB：`/tmp/m173/dtb`（153262 B）；旧 dtbold：`/tmp/vk126u/dtb`（149063 B）。
- 反编译：`build/m1-upstream/clean-tree-73/scripts/dtc/dtc -I dtb -O dts`（下同）。
- 列含义：**节点/属性 ｜ 旧值 ｜ 新值 ｜ 是否可能影响早期启动**。

### 1.1 方法

```
$ build/m1-upstream/clean-tree-73/scripts/dtc/dtc -I dtb -O dts /tmp/m173/dtb   > /tmp/m173/new.dts   # rc=0
$ build/m1-upstream/clean-tree-73/scripts/dtc/dtc -I dtb -O dts /tmp/vk126u/dtb > /tmp/vk126u/old.dts # rc=0
$ wc -l /tmp/m173/new.dts /tmp/vk126u/old.dts
  9510 /tmp/m173/new.dts
  9222 /tmp/vk126u/old.dts
```

- dtc 解码 rc=0，无 error；两侧只有常规 warning（`unique_unit_address` 等），**新树无 `splash_region` 少 unit-name 的 warning**（旧树有）。
- 逐节点比对：脚本 `/tmp/dtsdiff3.py`（按节点路径建树，属性差值；把「仅 phandle 数字重编号」的属性分离出来）。
  **原始文本 diff** 另有 `scripts/dtc/dtx_diff`：\`rc=1`，7247 行（绝大部分是 phandle 重编号）。
- 汇总：**共同节点中，仅 phandle 重编号的属性 = 1072 处；去重编号后仍有差异的属性 = 55 处**（其中绝大多数仍是「phandle 首格 0xNN→0xNN+1」类，见 1.4）。

### 1.2 节点增删（路径级）

**只在旧 DTB 有（7 个）**：

| 节点 | 说明 |
|---|---|
| `/reserved-memory/splash_region` | 无 unit-address（旧树 dtc warning），新树改名为 `splash-region@fc800000`，**reg 完全相同** |
| `/soc@0/remoteproc@6800000/glink-edge/gpr/service@3`（+ `dais`/`bedais`/`dai@12`） | 新树该 GPR service 节点号 3→1 |
| `/soc@0/remoteproc@6800000/glink-edge/gpr/service@7`（+ `clock-controller`） | 新树该 GPR service 节点号 7→2 |

**只在新 DTB 有（60 个）**，按类：

| 类别 | 节点 | 是否可能影响早期启动 |
|---|---|---|
| **/chosen 下的 framebuffer** | `/chosen/framebuffer@fc800000`（`compatible="simple-framebuffer"`） | **是（唯一可疑新增）** |
| /reserved-memory 改名 | `/reserved-memory/splash-region@fc800000` | 否（reg/no-map 同旧） |
| Coresight/TPDM 调试基础设施 | `ctcu@10001000`、`replicator@10046000/1004e000/10b06000`、`tmc@10048000/1004f000`、`tmc@10b05000/out-ports` 及其 in/out-ports/endpoint | 否（仅 DT 节点；需 CORESIGHT config，与引导无关） |
| GPR service | `service@1`(+dais/bedais/dai@12)、`service@2`(+clock-controller) | 否（音频 GPR，节点号演进） |
| SPMI PMIC ADC | `/soc@0/spmi@c400000/pmic@0/adc@9000`(+channel@0/1/3) | 否 |
| QUP UART15 | `/soc@0/geniqup@8c0000/serial@89c00000`、`pinctrl@f100000/qup-uart15-default-state` | 否（新增串口） |

> 结论：**新树相对旧 dtbold 的「新增/删除节点」里，唯一可能改变早期启动行为的是 `/chosen/framebuffer@fc800000`。**

### 1.3 属性差异（去 phandle 重编号后的 55 处，按影响分级）

| 节点/属性 | 旧值 | 新值 | 是否可能影响早期启动 |
|---|---|---|---|
| **`/chosen`** | 无 framebuffer 子节点 | 新增 `framebuffer@fc800000`：`compatible="simple-framebuffer"`，`reg=<0 0xfc800000 0 0x2b00000>`，`width=0x770 height=0xbe0 stride=0x1dc0 format="a8r8g8b8"` | **是（首要嫌疑）** |
| `/reserved-memory/splash_region` → `splash-region@fc800000` | `reg=<0 0xfc800000 0 0x2b00000>; no-map; phandle=<0xd7>` | 同名属性、同名值，仅节点名加 unit-address + phandle 0xd7→0xd8 | 否（语义等价） |
| `/soc@0/display-subsystem@ae00000 :: memory-region` | `<0xd7>` | `<0xd8>` | 否（指向同一 splash 区，随 phandle 重编号） |
| `/soc@0/display-subsystem@ae00000/displayport-controller@af54000 :: reg` | 5 段（0x104/0xc0/0x770/0x9c/0x9c） | 10 段（0x200/0x200/0xc00/0x400/0x400/0x400/0x400/0x600/0x600） | 否（7.3 上游 DP 寄存器表扩充） |
| `/soc@0/geniqup@ac0000/i2c@a80000 :: status` | `"disabled"` | `"okay"` | **可能**（新启用的 I2C，若挂载从设备探测异常可能拖慢/失败；但 I2C 探测不会导致无 gadget） |
| `/soc@0/mmc@8804000 :: no-1-8-v` | 存在 | **删除** | **可能**（UFS/SDHCI 1.8V 信令策略变化；影响存储，不影响背光/gadget） |
| `/soc@0/clock-controller@1760000 :: power-domains` | `<0x24 0x08>` | `<0x24 0x06 0x24 0x08>` | 否（7.3 上游补 power-domain） |
| `/soc@0/*/:: label`（cti/tpdm，共 30+ 个） | 无 | 新增 `"tpdm_*"`/`"cti_*"` label | 否（仅为 label 属性） |
| `/soc@0/spmi@c400000 :: phandle` | 无 | 新增 `<0xfd>` | 否 |
| 其余 `::clocks / ::interrupts-extended / ::msi-map / ::sound-dai / ::required-opps` 等 ~30 处 | — | 首格 phandle `0xNN→0xNN+1` 类整体平移 | 否（新树插入 phandle 造成的重编号，引用目标同路径） |

### 1.4 关于「phandle 重编号」

- 新树比旧树多 16 个 phandle（495 → 511），由 1.2 的新增节点造成，**全部节点按 DTS 顺序重新分配 phandle 号**，因此 ~1072 处属性出现「数字变了但引用目标不变」。用路径解析后这些差异全部消失。
- 两侧 phandle 声明**均无重复**：
```
$ grep -oE "^\t+phandle = <0x[0-9a-f]+>" old.dts | sort | uniq -d   # 空
$ grep -oE "^\t+phandle = <0x[0-9a-f]+>" new.dts | sort | uniq -d   # 空
```

### 1.5 /chosen 与 /aliases

```
OLD /chosen:                          NEW /chosen:
	chosen {                              chosen {
		#address-cells = <0x02>;               #address-cells = <0x02>;
		#size-cells = <0x02>;                 #size-cells = <0x02>;
		ranges;                               ranges;
	};                                        framebuffer@fc800000 {
                                                          compatible = "simple-framebuffer";
                                                          reg = <0x00 0xfc800000 0x00 0x2b00000>;
                                                          width = <0x770>; height = <0xbe0>;
                                                          stride = <0x1dc0>; format = "a8r8g8b8";
                                                  };
                                          };
```

- `/aliases`：**两侧完全一致**（i2c5/i2c6/i2c9/i2c10/serial1，逐字节相同）。
- 根节点 `model`/`compatible`/`chassis-type`：**两侧一致**（`"Lenovo Legion Y700 Gen4"` / `"lenovo,elden","qcom,sm8750"`）。
- **`qcom,board-id` / `qcom,msm-id` 两侧根节点均不存在**（`grep -nE "board-id|msm-id" old.dts new.dts` 只命中 `qcom,pmic-id = "b/d/f/g/i/j"`，属 PMIC 子节点，与引导匹配无关）。

---

## 2. 重点核查（①framebuffer reserved ②memory 重叠 ③id/chosen/aliases ④phandle 悬空 ⑤正常演进）

### ① `framebuffer@fc800000` 是否在 reserved-memory 下、对应 region 是否真被 reserved

- **不在** `/reserved-memory` 下，而在 **`/chosen/framebuffer@fc800000`** —— 这符合 `simple-framebuffer` 绑定（framebuffer 节点在 /chosen，保留区在 /reserved-memory）。
- 对应保留区在 `/reserved-memory/splash-region@fc800000`：

```
$ sed -n '/splash-region@fc800000/,/};/p' /tmp/m173/new.dts
		splash-region@fc800000 {
			reg = <0x00 0xfc800000 0x00 0x2b00000>;
			no-map;
			phandle = <0xd8>;
		};
```

- `0xfc800000 + 0x2b00000 = 0xff300000`，即覆盖 **0xfc800000..0xff2fffff（含）**，与 framebuffer 的 `reg` 完全一致 ⇒ **是**。
- **旧树同样有该保留区**（仅节点名 `splash_region` 无 unit-address）：

```
$ sed -n '/splash_region {/,/};/p' /tmp/vk126u/old.dts
		splash_region {
			reg = <0x00 0xfc800000 0x00 0x2b00000>;
			no-map;
			phandle = <0xd7>;
		};
```

### ② /memory 与 reserved-memory 是否与 framebuffer 区间重叠

脚本 `/tmp/overlap.py`（解析 `reserved-memory` 与 `memory@a0000000` 的 `reg`，与 fb 区间求交）：

```
=== OLD reserved-memory regions: 44
  OVERLAP-with-fb: 0xfc800000 0x2b00000
  /memory regions: 15
  /memory covers fb: 0xe3720000 0x1c0e0000
=== NEW reserved-memory regions: 44
  OVERLAP-with-fb: 0xfc800000 0x2b00000
  /memory regions: 15
  /memory covers fb: 0xe3720000 0x1c0e0000
```

- /memory 的 `0xe3720000..0xff800000` **覆盖** fb 区间；但 `reserved-memory/splash-region` 已用 `no-map` 把它从内核可用内存中挖掉。
- **两侧结果完全相同**：唯一与 fb 相交的保留区就是 splash-region 本身；`oem-vm@f7c00000`（end=0xfc800000）与 `llcc-lpi@ff800000` 与之**边界相邻但不重叠**。
- /memory 的 `reg` 两侧**逐字节相同**（`sed -n '/memory@a0000000 {/,/};/p'` 对比结论）。
- ⇒ 内存布局差异 **不存在**；fb 区间在两棵树上都被同样地保留/挖除。

### ③ id / chosen / aliases 差异

- 见 §1.5：根 `compatible`、`/aliases` 完全一致；**无 `qcom,board-id`/`qcom,msm-id`**；`/chosen` 唯一差异 = 新增 `framebuffer@fc800000`。

### ④ phandle/label 悬空

- `dtc -I dtb -O dts` 两侧 **rc=0、无 error**；phandle 声明无重复（§1.4）。
- 逐个复核关键引用解析（用 `/tmp/dtsdiff3.py` 把 phandle 解析成节点路径）：
  - `display-subsystem@ae00000 :: memory-region = <0xd8>` → 解析到 `/reserved-memory/splash-region@fc800000`（旧：`<0xd7>` → `/reserved-memory/splash_region`）**引用有效**。
  - 反编译后的 DTS **不含 label**（`&label` 在编译期已展开），故不存在 `&label` 解析失败问题；新树新增的 `"tpdm_*"/"cti_*"` 是 **`label` 属性字符串**（Coresight 驱动用），非 phandle 引用。
- **未发现悬空引用**。

### ⑤ 哪些差异只是 7.2→7.3 的正常演进

- Coresight/TPDM/CTCU/replicator/TMC 节点与 `label`（7.3 上游 coresight 补全，见 1.2/1.3）。
- GPR service 节点号 3→1、7→2（7.3 上游 ADSP GPR 定义变更）。
- SPMI PMIC `adc@9000` 子树（7.3 上游 PMIC ADC）。
- `splash_region`→`splash-region@fc800000` 改名（修 dtc `unit_address_vs_reg` warning，语义等价）。
- displayport-controller `reg` 扩充、各节点 `label` 补齐、`clock-controller@1760000` 补 power-domains（均为上游演进）。
- ~1072 处 phandle 重编号（新节点插入的副作用）。


---

## 3. 对照镜像

### 3.0 产物

| 镜像 | 内核 | DTB | ramdisk | 用途 | 状态 |
|---|---|---|---|---|---|
| `out/boot-elden-m1-73.img` | 新树 | 新树（含 /chosen fb） | vk126+36 .ko | 原始失败样本 | 编排者造（**未改动**） |
| `out/boot-elden-m1-73b.img` | 新树 | 新树（含 fb） | 纯 vk126 | 排除模块层 | 编排者造（**未改动**） |
| `out/boot-elden-m1-73c.img` | 新树 | **旧 dtbold** | 纯 vk126 | 隔离「内核 vs DTB」 | 编排者造（**未改动**） |
| **`out/boot-elden-m1-73d.img`** | **新树** | **新树但删 `/chosen/framebuffer@fc800000`** | 纯 vk126 | **本任务新造：锁定 simple-framebuffer** | **本次产出** |

（73b/73c 的组件身份经本报告独立解包核对，见 3.3。）

### 3.1 输入（sha256，本次实测）

```
78dbf7b16595edd24b41273d778e6a499893c9e2158b5c6c8aa24d1886e2c7a1  /tmp/m173/kernel     (新树 Image.gz)
35823240fcd15b4b08e1219e9a849a9abaa997bca7c11fd7f3e6e477c9c0478c  /tmp/vk126u/ramdisk  (vk126 纯 ramdisk)
6c07499f4025c51a27256a45317cdd9d4ab41f22ad8082d6b8b112f140a8ab87  /tmp/m173/dtb        (新树 DTB，含 fb，153262 B)
5d658a2ce48cdda9a0451aaef28b6c668fb76607f76e2f0648ee9194c0008c0d  /tmp/vk126u/dtb      (旧 dtbold，149063 B)
2cd49ee1879671cc972ab7736263203713c9e8cb32857e918fcc2d18c1fa8a08  /tmp/m173/new-nofb.dtb (本次新编，删 fb，153084 B)
```

### 3.2 造法（可复现）

1. 新 DTB 反编译 → `/tmp/m173/new.dts`（§1.1）。
2. 删除 `/chosen/framebuffer@fc800000` 子树（脚本 `/tmp/rmfb.py`，用大括号配平定位，连同尾部 `;`）：

```
removed 198 bytes:
		framebuffer@fc800000 {
			compatible = "simple-framebuffer";
			reg = <0x00 0xfc800000 0x00 0x2b00000>;
			width = <0x770>;
			height = <0xbe0>;
			stride = <0x1dc0>;
			format = "a8r8g8b8";
		};
mentions simple-framebuffer: False
mentions framebuffer@fc800000: False
braces: 1435 1435
```

3. 用树内 dtc 编回：

```
$ build/m1-upstream/clean-tree-73/scripts/dtc/dtc -I dts -O dtb -o /tmp/m173/new-nofb.dtb /tmp/m173/new-nofb.dts
  (rc=0；794 条 Warning，与未修改 new.dts 编译时【完全一致】——反编译再编译的固有 warning，非本次编辑引入)
$ ls -l /tmp/m173/new-nofb.dtb
  -rw-rw-r-- 1 xuqianhui1001 xuqianhui1001 153084 Oct 13 20:26 /tmp/m173/new-nofb.dtb
```

4. **可逆性/无损性双向验证**：
   - **未修改**的 new.dts 用同一 dtc 编回 → 得到 `/tmp/m173/t1.dtb`，与原始 `/tmp/m173/dtb` **sha256 完全相同**、`cmp -l` 字节差 0 ⇒ 反编译→编译链路无损。
   - 反编译 `new-nofb.dtb` 与原始 `new.dts` 解码结果 diff：**唯一差异就是那 9 行 framebuffer 子树**（`9249,9257d9248`）。
   - 解码回读：`simple-framebuffer` 计数 0、`splash-region@fc800000` 计数 1、`/chosen` 只剩 4 行（`#address-cells/#size-cells/ranges`）。

5. 打包（编排者给定命令，原样执行）：

```
$ python3 tools/mkbootimg/mkbootimg.py --header_version 2 --os_version 15.0.0 --os_patch_level 2025-08 \
    --kernel /tmp/m173/kernel --ramdisk /tmp/vk126u/ramdisk --dtb /tmp/m173/new-nofb.dtb \
    --cmdline "console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel printk.devkmsg=on panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 elden_root=LABEL=linux17 androidboot.slot_suffix=_b elden_nocamera=1" \
    --base 0x00000000 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --tags_offset 0x00000100 --dtb_offset 0x01f00000 --pagesize 4096 \
    -o out/boot-elden-m1-73d.img
$ ls -l out/boot-elden-m1-73d.img
  -rw-rw-r-- 1 xuqianhui1001 xuqianhui1001 85549056 ... out/boot-elden-m1-73d.img
```

   - 大小 85549056 B < 96 MiB (100663296 B) ⇒ 满足 `boot_a` 上限（PITFALLS #6）。

### 3.3 产物核验（unpack_bootimg 回读 + sha256）

```
$ python3 tools/mkbootimg/unpack_bootimg.py --boot_img out/boot-elden-m1-73d.img --out /tmp/unp73d
boot magic: ANDROID!          boot image header version: 2       page size: 4096
kernel_size: 20798473         kernel load address: 0x00008000
ramdisk size: 64586468        ramdisk load address: 0x01000000
dtb size: 153084              dtb address: 0x0000000001f00000
os version: 15.0.0            os patch level: 2025-08
command line args: console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel printk.devkmsg=on panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 elden_root=LABEL=linux17 androidboot.slot_suffix=_b elden_nocamera=1
```

回读组件 sha256（与 3.1 输入逐一对齐）：

| 组件 | 73d 内 | 期望 | 一致 |
|---|---|---|---|
| kernel | `78dbf7b1…e2c7a1` | `78dbf7b1…e2c7a1`（新树） | ✅ |
| ramdisk | `35823240…c0478c` | `35823240…c0478c`（vk126 纯） | ✅ |
| dtb | `2cd49ee1…1fa8a08` | `2cd49ee1…1fa8a08`（new-nofb） | ✅ |

- 命令行与现役 vk126/73 逐字段一致（§0 已排除命令行）。
- 解包 `73c`：dtb sha256 = `5d658a2c…8c0d`（= 旧 dtbold），kernel/ramdisk 与 73d 相同 ⇒ 73c/d 构成严格单变量对照（**仅差 DTB**，且 73d 与 73c 的 DTB 又只差 fb 相关）。
- 解包 `73b`：dtb = 新树（`6c07499f…a8ab87`），ramdisk 与 vk126 纯 ramdisk **完全相同**（`35823240…`）⇒ 与 73 的差异只在 ramdisk（.ko/payload）。

### 3.4 纪律核对

- **未触碰设备**：本任务全程无 `fastboot`/`adb`/EDL/按键/插拔。
- **未覆盖现有镜像**：只新增 `out/boot-elden-m1-73d.img`；73 / 73b / 73c 的 sha256 未变。
- 未改 `TASKS/DEVICE/INDEX/RESOURCES/PITFALLS/versions/.githooks`；未做任何 git 网络操作；未对 geekidos-linux 部分克隆做未知 ref `cat-file`。

---

## 4. 下一步判据

> 前置：以下每组都在**同一设备/同一槽/same cmdline**下只变一个变量，用 `fastboot boot`（零写盘），并记录「背光是否亮 / 主机是否出现 cdc_ncm·cdc_acm / 多久回旧系统」三项观测值。

| 结果 | 判定 | 后续 |
|---|---|---|
| **73d 能起**（背光/或至少拉起 gadget、能在 60 s 内出现 CDC） | **锁定 `simple-framebuffer`**：新树 DTB 的 `/chosen/framebuffer@fc800000` 是唯一变量 | ① 到新树 DTS 源码里找该节点来源（是否本地加的还是上游），检查 `simplefb` 绑定要求（保留区是否允许 `no-map`、是否要 `status`）；② 用「保留区去掉 `no-map`」或「改 `status="disabled"`」两种最小改法各出一个小样验证；③ 若上游有同类板子的正确写法，按上游写 |
| **73c 能起**（新内核 + 旧 dtbold） | **锁定 DTB 整体**（内核侧无问题） | 以「旧 dtbold vs 新 DTB」为两端做**二分**：依次加入新树独有差异类（① 仅 fb 节点；② fb + splash 改名；③ fb + coresight 新节点；④ 全量）定位到具体差异；同时确认新树 DTS 源码中 elden 板的相对上游 sm8750 是否有多余节点 |
| **73c 与 73d 都失败** | 指向**内核侧**（新树内核在该板上早期崩/挂） | ① 用 **pristine 7.3-rc7**（未打本地补丁的 `ged6f232d10e3` 同 tag）编译同 config 内核 + **同一 DTB**（如 73d 的 DTB）出镜像；② 若 pristine 也失败 → 主线上游回归，抓 `ramoops`/串口 log（`console=ttyGS0` 已配，若 gadget 都起不来需改用 `ramoops@c2000000` 从旧系统读）；③ 若 pristine 能起 → 定位新树相对 upstream 的本地改动（`git log`/diff elden 相关提交） |

补充判据（三条通用）：

1. **USB gadget 是否出现**是最早的「内核活了」信号（早于背光点亮）；**背光不亮 + gadget 不出现**同时发生 ⇒ 强烈指向早期（USB/DRM 初始化之前）的问题，而不是显示子系统本身。
2. 若某版能进 shell，立刻抓 `dmesg`（尤其 `simple-framebuffer`/`simpledrm`/`request_mem_region`/`reserved-memory` 相关行）与 `/sys/kernel/debug/reserved_mem`，作为终局证据。
3. 换任何变量都重出一张 `fastboot boot` 观测记录；「单次样本无效」，功能性/服务级测试若需要，另行用**持久变体**（RAM 内核 + 磁盘根）验证。
