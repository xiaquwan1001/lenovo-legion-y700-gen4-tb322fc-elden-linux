# M1-73 树板 DTS 设备侧修复追赶（display/backlight + USB）— 2026-10-13

> 范围：把现役可用树 `geekidos-linux`（`clean/base`，7.2.0/vk64）板 DTS 上累积的**设备侧修复**搬进 M1 干净树
> `build/m1-upstream/clean-tree-73`（`m1/clean-tree-7.3rc7`，tip `1e4077e13f`），重建 DTB、提交、打单变量镜像。
> 纪律：未碰设备、未改 TASKS/DEVICE/INDEX/RESOURCES/PITFALLS/versions/.githooks、未覆盖任何现有 `out/*.img`、未 fetch/推分支。
> 基线：`out/boot-elden-m1-73e.img`（同一内核/ramdisk，仅 DTB 为本轮唯一变量）。

## 0. 结论速览（TL;DR）

- 两份板 DTS 的**功能差异只有 3 处**，其余 3 处是注释：
  1. `reserved-memory` 里 splash 节点名（**hyphen `splash-region@fc800000` → underscore `splash_region`**）—— ABL 按名字查找，PITFALLS #11；
  2. `chosen` 里多出的 **`simple-framebuffer@fc800000`** 节点 —— 与 `splash_mem` 同址争用，clean/base 已删除；
  3. `&sdhc_2` 的 **`no-1-8-v`**（SD 稳定性修复，与显示/USB 目标无关）。
- **`&usb` 节点两份文件功能行完全一致**（`dr_mode="otg"`、`usb-role-switch`、`port-select-gpios`、`eusb_mux` pinctrl、`ports` 端点全同）⇒ **板 DTS 层面没有可搬的 USB 修复**。
- 主嫌疑：**① splash 节点名 hyphen**（ABL 找不到 `/reserved-memory/splash_region` 就关显示，PITFALLS #11），**② simple-framebuffer 与 splash_mem 同址争用**。

## 1. 基线与现场事实核对

| 项 | 值 | 命令/证据 |
|---|---|---|
| clean/base tip | `5b169d5418801563ee0e8fa3a0f284a1ebb868f9` | `git -C geekidos-linux rev-parse HEAD` |
| m1-73 tip | `1e4077e13f7762f5012c8ba88dcc9bd4a0d070f8` | `git -C build/m1-upstream/clean-tree-73 rev-parse HEAD` |
| 73e 镜像 DTB == 当前 M1 树 DTB | 同 sha | `sha256sum /tmp/73e-unpack/dtb …dtb` |
| 73e DTB 内 `i2c@880000` | `status = "disabled"` | `sed -n '719,752p' /tmp/73e.dts` |
| 73e DTB 内 splash | `splash-region@fc800000`（hyphen） | `grep -n 'splash' /tmp/73e.dts` → 586 |
| 73e DTB 内 framebuffer | `framebuffer@fc800000 / simple-framebuffer` | 同上 → 9250/9251 |

⇒ **#108 的 `&i2c0` 修复已包含在 73e 里**（tip 提交即该修复），但 73e 上机仍黑屏/无 USB ⇒ 根因不在 i2c0，而在上表后两行（本轮待搬项）。

## 2. 两份板 DTS 逐处差异表

命令：

```sh
diff -u geekidos-linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts \
        build/m1-upstream/clean-tree-73/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts
```

两文件行数：`3168`（clean/base） / `3147`（m1-73）；`diff` 共 **6 处 hunk**。

| # | 位置（DTS 位置 / 节点） | clean/base 旧值 | m1-73 新值 | 归类 | 是否搬 |
|---|---|---|---|---|---|
| H1 | `/chosen`（clean ~1210 / m1 ~1210） | 无 `framebuffer` 节点，仅有说明注释 | `framebuffer: framebuffer@fc800000 { compatible="simple-framebuffer"; reg=<0 0xfc800000 0 0x2b00000>; 1904×3040; stride=1904*4; a8r8g8b8 }` | 设备侧修复（显示链路） | **是** |
| H2 | `/reserved-memory`（clean ~1476 / m1 ~1473） | `splash_mem: splash_region { reg=<0 0xfc800000 0 0x2b00000>; no-map; }` | `splash_mem: splash-region@fc800000 { … }`（hyphen） | 设备侧修复（ABL 名字查找，PITFALLS #11） | **是** |
| H3 | `&i2c0`（clean ~1997 / m1 ~1994） | 两段中文注释 | 一段中文注释；**`status="disabled"` 两边相同** | 无关（注释） | 否 |
| H4 | `&mdss_dp0`（clean ~2358 / m1 ~2355） | 多一段 dp5 注释 | 无注释；**`status="okay"` 两边相同** | 无关（注释） | 否 |
| H5 | `&sdhc_2`（clean ~2695 / m1 ~2683） | `no-1-8-v;`（+ UHS-I 损坏说明注释） | 无 | 设备侧修复（SD 稳定性，非显示/USB） | **是**（见 §3 取舍） |
| H6 | `&usb`（clean ~3062 / m1 ~3047） | 两段 dp5 注释 | 无注释；**功能行逐行相同** | 无关（注释） | 否 |

（差异原文与逐条证据见 §2.1–§2.6。）

### 2.1 H1 — `/chosen` 的 `simple-framebuffer@fc800000`

```diff
@@ -1207,13 +1207,14 @@
 		#size-cells = <2>;
 		ranges;
 
-	/*
-	 * The simple-framebuffer is deliberately NOT described here (matching the
-	 * author's working DT): MDSS/DPU drives the panel, and its
-	 * DISP_CC_MDSS_CORE_BCR reset pulls the ABL handover framebuffer out from
-	 * under simple-framebuffer, so fbcon would bind to a dead fb. Leaving it
-	 * out lets fbcon land on the DRM_MSM fbdev instead.
-	 */
+		framebuffer: framebuffer@fc800000 {
+			compatible = "simple-framebuffer";
+			reg = <0x0 0xfc800000 0x0 0x2b00000>;
+			width = <1904>;
+			height = <3040>;
+			stride = <(1904 * 4)>;
+			format = "a8r8g8b8";
+		};
 	};
```

- **归类**：设备侧修复（显示链路）。clean/base 的注释写明理由：MDSS/DPU 的
  `DISP_CC_MDSS_CORE_BCR` reset 会把 ABL 交接的 framebuffer 从 `simple-framebuffer` 脚下抽掉，
  于是 fbcon 绑到一块**死 fb**；不描述它，fbcon 才会落到 DRM_MSM 的 fbdev 上。
- **额外风险（本轮新增观察）**：该节点 `reg=<0 0xfc800000 0 0x2b00000>` 与 H2 的
  `splash_mem` **完全同址同长**；73e 里两者并存 ⇒ `simple-framebuffer` 与
  `&mdss { memory-region = <&splash_mem> }` 争用同一段 `no-map` 区域（见 §2.2）。
- **决定**：**搬**（删除该节点，回到 clean/base 形态）。

### 2.2 H2 — `/reserved-memory` 的 splash 节点名（hyphen → underscore）

```diff
@@ -1468,12 +1469,8 @@
 		/*
 		 * Use this to tell the BL to initialize the display related
 		 * resources, so we can use efifb. Please 's/-/_/'
-		 *
-		 * ABL looks up exactly "/reserved-memory/splash_region"; if the
-		 * node is missing it powers the display off before jumping to the
-		 * kernel. The hyphen form (splash-region) does NOT match.
 		 */
-		splash_mem: splash_region {
+		splash_mem: splash-region@fc800000 {
 			reg = <0 0xfc800000 0 0x2b00000>;
 			no-map;
 		};
```

- **归类**：设备侧修复（ABL 名字查找）。与 PITFALLS **#11** 完全一致：
  `reserved-memory` 节点名必须下划线 `splash_region`，**连字符形式 ABL 不匹配 → 传内核前先关显示**。
- **M1 树的自相矛盾**：m1-73 文件里这段注释原本就写着 “Please 's/-/_/' / hyphen form does NOT match”，
  但节点名却是 hyphen —— 即 M1 payload 血统知道规则、没落地改名（clean/base 已落地）。
- **消费者核对**：
  ```
  &mdss {
          memory-region = <&splash_mem>;
          /delete-property/ iommus;
          status = "okay";
  };
  ```
  两树都用 **label `&splash_mem`** 引用，所以改名不影响内核侧引用，只影响 ABL 的名字匹配。
- **决定**：**搬**（主嫌疑）。

### 2.3 H3 — `&i2c0` 注释

```diff
@@ -1997,10 +1994,10 @@
 
 /* ST21NFC on QUPV3_SE0 (i2c0, gpio32/33). Vendor compatible is "st,st21nfc";
  * the mainline driver only matches "st,st21nfca-i2c" and needs enable-gpios.
- *
- * 2026-10-06: 本机无 NFC 硬件（G1-10 取消）。`&i2c0 status="okay"` 会导致**硬关机**
- * （PITFALLS #108）；此前文档记“已从驱动批次移除”，但树里仍为 okay ⇒ 任何由本树
- * 构建的 DTB 都会启动失败（dp1 实测回退 boot_b）。此处改回 disabled。
+ */
+/* PITFALLS #108（2026-10-06 单变量定案）：本机无 NFC 硬件，**使能 i2c0 本身**即导致
+ * `fastboot boot` 报 OKAY 后硬关机（USB 串口来不及注册、抓不到日志）。现役 clean/base
+ * 树此处为 disabled；M1 树带的是 #108 之前的版本，必须改回 disabled 才能上机。
  */
 &i2c0 {
 	status = "disabled";
```

- **归类**：无关（纯注释；两树 `status="disabled"` 相同）。73e DTB 反编译复核：`i2c@880000` 为 `status = "disabled"`。
- **决定**：不搬。

### 2.4 H4 — `&mdss_dp0` 注释

```diff
@@ -2358,9 +2355,6 @@
 };
 
 &mdss_dp0 {
-	/* 2026-10-07 dp5 实机：DP 打通（EDID F27G32Q Pro 2560x1440、无 vblank 风暴）。
-	 * 使能 DP0 需与下方 dr_mode=otg + usb-role-switch 同批：ADSP UCSI 活了之后
-	 * msm_dp 不再永久 defer，不阻塞 msm_drm_bind。 */
 	status = "okay";
 };
```

- **归类**：无关（注释；两树 `&mdss_dp0 { status = "okay"; }` 功能相同）。
  对应 clean/base 提交链 `8481c5a614`（使能 mdss_dp0）→ `08791078c8`（回退 disabled）
  → `6c1376907d`（DP 打通：dr_mode=otg + usb-role-switch + mdss_dp0 okay，dp3/dp4/dp5 实机三步定位）。
  **该“已打通”状态的功能行 M1-73 树已具备**（见 H6）。
- **决定**：不搬。

### 2.5 H5 — `&sdhc_2` 的 `no-1-8-v`

```diff
@@ -2685,15 +2679,6 @@
 	vmmc-supply = <&vreg_l9b_2p9>;
 	vqmmc-supply = <&vreg_l8b_1p8>;
 
-	/*
-	 * The SDHCI/SDC2 path on this early SM8750 port is not reliable at
-	 * UHS-I SDR104: filesystem writes (mkfs/mount) get silently
-	 * corrupted/lost while plain raw I/O looks fine. Force 3.3V
-	 * signalling so the card only negotiates High-Speed (SDR104/SDR50/
-	 * DDR50 all need 1.8V and are therefore disabled). Slower, but stable.
-	 */
-	no-1-8-v;
-
 	no-sdio;
 	no-mmc;
```

- **归类**：设备侧修复（SD 卡稳定性；**与本次显示/USB 目标无关**）。
  理由：SDR104（1.8V 信令）下文件系统写入会静默损坏；`no-1-8-v` 强制 3.3V/High-Speed。
- **取舍**：任务口径为“只搬设备侧修复”，且未列入不搬清单（Q24/Q28/sd-* 显示实验/vk/elden_nocamera）。
  本条是 clean/base 树上带明确理由的**设备侧修复**，故**搬**；标记为“与目标无因果”，
  若后续需要绝对单变量，可单独回退这一行而不影响显示/USB 结论。
- **决定**：**搬**。

### 2.6 H6 — `&usb` 注释（USB 链路结论）

```diff
@@ -3062,14 +3047,8 @@
 };
 
 &usb {
-	/* 2026-10-07 dp5：dr_mode=otg —— peripheral 时 dwc3_drd_init 不跑，role switch
-	 * 永不注册（ucsi EPROBE_DEFER 真根因）。GHWPARAMS0=DRD，硬件支持双角色；
-	 * role-switch-default-mode 缺省即 peripheral，gadget ssh 不变（实机验证）。 */
 	dr_mode = "otg";
 	usb-psy-name = "qcom-battmgr-usb";
-	/* 2026-10-07 dp5：保留 usb-role-switch。删掉它会让 dwc3_get_dr_mode 把
-	 * otg 强制回 peripheral，role switch 永不注册 ⇒ ucsi connector EPROBE_DEFER
-	 * ⇒ PPM init failed（DP 卡死的真根因，实机 dp3/dp4/dp5 三步定位）。 */
 	usb-role-switch;
 	port-select-gpios = <&tlmm 29 GPIO_ACTIVE_HIGH>;
 	pinctrl-0 = <&eusb_mux>;
```

**`&usb` 全节点逐行对照**（`awk '/^&usb \{/,/^};/'`）：

| 行 | clean/base | m1-73 |
|---|---|---|
| `dr_mode` | `"otg"` | `"otg"` |
| `usb-psy-name` | `"qcom-battmgr-usb"` | 同 |
| `usb-role-switch;` | 有 | 有 |
| `port-select-gpios` | `<&tlmm 29 GPIO_ACTIVE_HIGH>` | 同 |
| `pinctrl-0/names` | `<&eusb_mux>` / `"default"` | 同 |
| `maximum-speed` | `"super-speed-plus-gen2x1"` | 同 |
| `ports/port@0, port@2` | `pmic_glink_hs_in` / `pmic_glink_hs_c2_in`，`usb-role-switch` + `mux-state` | **逐行相同** |

- **归类**：无关（注释）。**板 DTS 的 USB 链路（`&usb`/`ports`，以及 typec/`pmic-glink` 的远端端点引用）
  两份文件逐行一致 ⇒ 本任务在板 DTS 层面没有可搬的 USB 修复。**
- **决定**：不搬。

## 3. 搬运清单与取舍

**搬（3 处，全部为设备侧修复）**：

| 项 | 变更 | 归属 |
|---|---|---|
| P1 = H2 | `splash-region@fc800000` → `splash_region`（并补回 ABL 名字匹配说明注释） | clean/base 树落地态（同源 payload + clean/base 修正；PITFALLS #11） |
| P2 = H1 | 删除 `chosen/framebuffer@fc800000`（simple-framebuffer），改为 clean/base 的说明注释 | clean/base 树落地态（“author's working DT”） |
| P3 = H5 | `&sdhc_2` 增加 `no-1-8-v;` + 说明注释 | clean/base 树落地态（SD 稳定性约束） |

**不搬（3 处注释 + 任务显式排除项）**：

- H3/H4/H6：三处纯注释（功能行两树相同），不搬，保持 M1 树自身注释口径。
- 任务显式不搬：Q24（cambist/H1/H2/mxnom）、Q28（dsi round/delay/probe）、sd-* 显示实验、
  vk 编号式临时改动、`elden_nocamera`（cmdline 项，且本轮镜像 cmdline 逐字沿用 73e）。
- 两树 `&mdss_dp0`、`&usb`、`&i2c0`、`&mdss`、panel/backlight 等显示/USB 链条的**功能内容本来就一致**，
  无需搬运（clean/base 提交 `8481c5a614`/`08791078c8`/`6c1376907d` 的成果，M1-73 树已具备）。

**取舍说明（为何 P3 也搬）**：任务口径是“只搬设备侧修复”，未把 SD 稳定性列入排除清单；
P3 在 clean/base 带明确理由注释，属设备侧修复。它与显示/USB 无因果关系，已在 §7 标为可单独回退项。

**搬后复核**：`diff -u` 仅剩 H3/H4/H6 三处**注释**差异 —— 即两文件功能内容已一致。见 §4。

### 3.1 搬运操作（可复现）

```sh
# 编辑 build/m1-upstream/clean-tree-73/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts
#   P1: splash-region@fc800000 -> splash_region（并补 ABL 名字匹配注释）
#   P2: 删除 chosen { framebuffer@fc800000 {…} }，替换为 clean/base 的说明注释
#   P3: &sdhc_2 在 vqmmc-supply 后插入 no-1-8-v;（+ 说明注释）
diff -u geekidos-linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts \
        build/m1-upstream/clean-tree-73/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts
# => 只剩 H3/H4/H6 三处注释差异（功能内容已一致）
```

## 4. 构建与提交

### 4.1 `make dtbs`

```sh
cd build/m1-upstream/clean-tree-73
rm -f arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dtbs
```

原始输出（全量）：

```
  DTC     arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
```

- `rc=0`；`grep -in 'warn\|error'` ⇒ `(none)` ⇒ **dtc 0 warning**。
- 产出 DTB sha256 = `c801884334804b56bbf4164af841a9d7896e13e3634f5f4f6000c111f983b558`
  （旧/73e = `f19a25e06c722269c9e61d24c482d937791d6ee93ab2c5aa085cbf6dec5a6e7e`）。

### 4.2 提交

```sh
git add -A && git commit -F /tmp/msg73f.txt
```

- 提交号：**`b3815fb1508069adfd28968d255c65dc05ffa6bb`**（分支 `m1/clean-tree-7.3rc7`）
- `1 file changed, 21 insertions(+), 9 deletions(-)`，仅改板 DTS。
- 父提交 = `1e4077e13f`（`dts: elden: disable &i2c0`）。
- 提交信息含：三处修复、搬运来源（clean/base 修复提交链 `8481c5a614`/`08791078c8`/`6c1376907d`）、
  不搬清单、构建门（rc=0 / 0 warning）。

## 5. 镜像 `out/boot-elden-m1-73f.img`（严格单变量：只改 DTB）

```sh
cd /home/xuqianhui1001/y700-elden
python3 tools/mkbootimg/mkbootimg.py --header_version 2 --os_version 15.0.0 --os_patch_level 2025-08 \
  --kernel /tmp/m173/kernel --ramdisk /tmp/vk126u/ramdisk \
  --dtb build/m1-upstream/clean-tree-73/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb \
  --cmdline "console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel printk.devkmsg=on panic=15 \
             clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 elden_root=LABEL=linux17 \
             androidboot.slot_suffix=_b elden_nocamera=1" \
  --base 0x00000000 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 \
  --tags_offset 0x00000100 --dtb_offset 0x01f00000 --pagesize 4096 \
  -o out/boot-elden-m1-73f.img
```

- `rc=0`；大小 `85549056` B（与 73e **逐字节同尺寸**，< 96 MiB 门）；
  sha256 `07b002a61d9ec137b70f5fea31a97c8460692b535778e377b75946e52d8aedf6`。
- 未覆盖任何既有 `out/*.img`（73e 仍在，`20:27`）。

### 5.1 回读校验（`unpack_bootimg.py`）

| 字段 | 73e | 73f |
|---|---|---|
| kernel sha256 | `78dbf7b1…e2c7a1` | `78dbf7b1…e2c7a1`（== `/tmp/m173/kernel`） |
| ramdisk sha256 | `35823240…c0478c` | `35823240…c0478c`（== `/tmp/vk126u/ramdisk`） |
| cmdline | 同上 | **逐字相同** |
| header_version / pagesize / offsets | 2 / 4096 / 同 | 同 |
| dtb size | 153266 | 153101 |
| dtb sha256 | `f19a25e0…` | `c8018843…` |

⇒ **kernel / ramdisk / cmdline / 头部参数全部不变，唯一变量 = DTB。**

## 6. 改后 DTB（73f）相对 73e DTB 的差异

```sh
${TREE}/scripts/dtc/dtc -I dtb -O dts /tmp/73f-unpack/dtb -o /tmp/73f.dts
diff -u /tmp/73e.dts /tmp/73f.dts
```

```diff
@@ -583,7 +583,7 @@			/* reserved-memory */
-		splash-region@fc800000 {
+		splash_region {
 			reg = <0x00 0xfc800000 0x00 0x2b00000>;
 			no-map;
 			phandle = <0xd8>;
@@ -2235,6 +2235,7 @@			/* &sdhc_2 */
 			vqmmc-supply = <0xa7>;
+			no-1-8-v;
 			no-sdio;
 			no-mmc;
@@ -9246,15 +9247,6 @@			/* /chosen */
 		#address-cells = <0x02>;
 		#size-cells = <0x02>;
 		ranges;
-
-		framebuffer@fc800000 {
-			compatible = "simple-framebuffer";
-			reg = <0x00 0xfc800000 0x00 0x2b00000>;
-			width = <0x770>;
-			height = <0xbe0>;
-			stride = <0x1dc0>;
-			format = "a8r8g8b8";
-		};
 	};
```

⇒ **唯一差异 = P1/P2/P3 三处搬运项**，无其他改动。

> 附注：对**已编译 DTB 反编译**会带 18 条 dtc 风格提示（73e 为 17 条），多出的一条是
> `unit_address_vs_reg: /reserved-memory/splash_region: node has a reg but no unit name` ——
> 这是「下划线命名、无 unit-address」本身带来的提示，clean/base 同样如此；**不是新 bug**。
> 从源码构建（`make dtbs`）时 dtc 为 **0 warning**（上表），因为该提示不在 kbuild 的门内。

## 7. 搬了什么 / 为何不搬 / 剩余风险与下一步

### 7.1 搬了什么

1. **P1（主嫌疑）** `splash-region@fc800000` → `splash_region`：恢复 ABL 按名字精确查找的约定
   （PITFALLS #11：找不到 `splash_region` 就**在跳内核前关显示**）。M1-73 树注释早已写明规则，只是没落地。
2. **P2** 删除 `chosen/framebuffer@fc800000`（simple-framebuffer）：① 它与 `splash_mem` **同址同长**
   （`0xfc800000+0x2b00000`），与 `&mdss { memory-region = <&splash_mem> }` 争用；
   ② MDSS core BCR reset 会抽掉 ABL 交接的 framebuffer，fbcon 会绑到死 fb。
3. **P3** `&sdhc_2` 增加 `no-1-8-v;`：SD 卡 SDR104 写入静默损坏的稳定性修复（与显示/USB 无因果）。

### 7.2 为何不搬什么

| 不搬项 | 原因 |
|---|---|
| H3/H4/H6（`&i2c0`/`&mdss_dp0`/`&usb` 注释） | 纯注释；功能行两树相同 |
| `&usb` 链路功能修改 | **没有差异可搬**：`dr_mode="otg"`、`usb-role-switch;`、`port-select-gpios`、`eusb_mux` pinctrl、`ports/port@0,2` 端点逐行一致（clean/base 的 `6c1376907d` 成果 M1-73 树已具备） |
| `&mdss_dp0` | 两树均 `status="okay"`（clean/base 三步定位后的结论态，M1 已具备） |
| `&i2c0` | 两树均 `status="disabled"`；73e DTB 反编译亦为 disabled |
| Q24（cambist/H1/H2/mxnom）、Q28（dsi round/delay/probe）、sd-* 显示实验、vk 编号式临时改动 | 任务显式排除；M1 树本就不含 |
| `elden_nocamera` | cmdline 项，非 DTS；本轮 cmdline 逐字沿用 73e |

### 7.3 剩余风险与下一步

- **风险 A：P1/P2 不是黑屏根因。** 若 73f 上机仍黑屏无背光、USB 仍不枚举，则说明 M1-73（7.3-rc7 重基）的
  问题不在板 DTS 的这三处，而在 **DTS 之外**，下一步按下列顺序查（均为主机侧可先做的静态核对）：
  1. **`&mdss` / `&mdss_mdp` / `&mdss_dsi0` / `&dsi_phy` 的功能属性**与 clean/base 是否逐节点一致
     （本轮只 diff 了板 DTS；但两者是**同一份 payload 文件的不同修订**，理论上已覆盖；若 73f 仍挂需再核 patch 栈差异，
     例如 7.3-rc7 相对 7.2.0 的 DSI/DPU 回移是否缺失）；
  2. **背光链**：`aw99706` 节点 + panel（`nt36536`）的 `backlight`/`panel` 引用 + `pwm`/GPIO（本轮已确认板 DTS 内引用未变）；
  3. **面板/桥驱动是否真编进 73f 内核**：73e 的 kernel 是 vk126 血统，需核对
     `aw99706`/`panel-novatek-nt36536` 是否为 `=y`（模块层此前已排除，但仍建议以 `Image` 内建符号表复核）；
  4. **USB 为何不枚举**：板 DTS 无差异 ⇒ 优先怀疑 **ADSP/UCSI 未起导致 role-switch 端点 defer**
     （PITFALLS #105：无 `/sys/class/typec`），或 7.3 树 `pmic-glink`/ucsi 相关驱动/配置差异；
     建议镜像 cdc_ncm/cdc_acm 与 `qcom-battmgr-usb` 是否 =y。
- **风险 B：P3 与目标无关**，混在同一 DTB 里。若需绝对单变量，可单独回退 `no-1-8-v;` 重打镜像。
- **风险 C：本轮未上机**。按 `.pi/AGENT-OPS.md` §3，本报告只给「未上机」的构建/差异结论；
  `out/boot-elden-m1-73f.img` 是否修好显示/USB **必须有设备证据（`scripts/trial.sh` record）才能写 verdict**。

## 8. 附：原始命令与证据索引

| 证据 | 命令 / 产物 |
|---|---|
| 两树 tip | `git -C geekidos-linux rev-parse HEAD`、`git -C build/m1-upstream/clean-tree-73 rev-parse HEAD` |
| 板 DTS 全量差异 | `diff -u …sm8750-lenovo-elden.dts …sm8750-lenovo-elden.dts`（6 hunk，见 §2） |
| 73e DTB 反编译 | `${TREE}/scripts/dtc/dtc -I dtb -O dts /tmp/73e-unpack/dtb -o /tmp/73e.dts` |
| clean/base 修复提交 | `git -C geekidos-linux show --stat 8481c5a614 / 08791078c8 / 6c1376907d` |
| 构建日志 | `/tmp/dtbs-73f.log`（仅一行 DTC，无 warning） |
| 新 DTB | `build/m1-upstream/clean-tree-73/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb` |
| 提交 | `b3815fb1508069adfd28968d255c65dc05ffa6bb` |
| 镜像 + 回读 | `out/boot-elden-m1-73f.img`；`/tmp/73f-unpack/{kernel,ramdisk,dtb}` |
| DTB 差异 | `diff -u /tmp/73e.dts /tmp/73f.dts` |



