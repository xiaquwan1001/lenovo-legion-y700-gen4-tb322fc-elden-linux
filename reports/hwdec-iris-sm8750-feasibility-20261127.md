# Y700(TB322FC / SM8750) 主线硬件视频解码（qcom iris）可行性 + 上机备料

- 日期：2026-11-27　lane：`hwdec-iris-sm8750`　范围：**纯主机侧**（设备只做只读探测；未刷机、未 reboot、未改设备文件、未 commit）
- 触发：Moonlight V+ 报「检测不到硬件解码」
- 驱动源码基线：`build/daily`（= 生成设备内核的构建树，`.config` `CONFIG_LOCALVERSION="-debug-vk189-suspend"`；其 iris 目录与 `wt/fastrpc-sensorspd-test` **逐文件相同**，仅多 `.o`）@ `4da9a8b69fc85`（Linux 7.3.1）
  - ⚠️ 设备在跑的是 vk192 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`，其 commit `4bdf1711b5c0` **本机所有内核树里都不存在**（`git cat-file -t` 全线 `Not a valid object name`），无法逐字节比对。等价性证据 = 设备 DT 节点属性与 `sm8750.dtsi@4da9a8b` 完全一致（§2 表）+ 设备 `modinfo qcom-iris` 的 of 别名含 `qcom,sm8750-iris`（同表）。**重编前须先核树**：`git -C <tree> log --oneline -1`。
- 证据日志：`reports/artifacts/hwdec-iris-20261127/{vendor-firmware-listing.log,vpu-firmware-sha256.log,device-probe.log}`
- 备料件：`out/hwdec-iris-20261127/`（`fw/*.mbn` 6 个 + `vendor_a.img`，见该目录 `README.md`）

---

## 0. 结论（一页）

**能开，但要补两件小事 + 一个只能上机才能.confirm 的门。** 三态判读：

| 面 | 判定 | 依据 |
|---|---|---|
| 驱动面 | ✅ **已具备，模块已在跑** | `qcom_iris` 已加载（`lsmod` 176128 / refcount 0），`/sys/bus/platform/drivers/qcom-iris/` 存在但**无 bound 设备**；`of_device_id` 表**在** `qcom,sm8750-iris`（`iris_probe.c:384`） |
| 固件面 | ⚠️ **文件有，但没装在 /lib/firmware** | vendor 侧 **6 个** `vpu*.mbn` 全部抽到（sha256 见 §1）；设备 `/lib/firmware/qcom/vpu/` **不存在** |
| DT 面 | ⛔ **唯一硬阻塞：`status="disabled"`** | 上游 `sm8750.dtsi:3013`（注释 3008-3012）disabled，板级 `sm8750-lenovo-elden.dts` **无** `&iris` 覆盖 ⇒ 节点永不 probe（`dmesg` 里 iris 命中 **0** 条） |
| 签名/PAS 认证 | ❓ **未证实（只能上机）** | 驱动走 `qcom_pas_auth_and_reset(IRIS_PAS_ID=9)`（`iris_firmware.c:169`），TZ 验签在主机侧无法判定；但用的是**本机厂商原厂签名的同一份固件**（signed 版含 4808 B 尾部 hash 段，§1），签名链与平台匹配 |
| HFI 版本匹配 | ❓ **未证实（驱动也不校验）** | 驱动只把固件回报的版本 `dev_dbg` 打印（`iris_hfi_gen2_response.c:793`），无最低版本/水印门；不匹配的表现只会是 `core_init` **1000 ms 超时**（`iris_platform_common.h:15` + `iris_core.c:42`） |

**缺什么（按依赖顺序）**：
1. `/lib/firmware/qcom/vpu/vpu35_p4.mbn`（= `/vendor/firmware/vpu35_4v.mbn` 的改名，或改 DT `firmware-name` 指向原名）；
2. 板级 dts 一行 `&iris { status = "okay"; };` + 重编 DTB 并重打 boot.img；
3. 上机验证 PAS ID 9 验签（唯一未知门）。

**为什么建议先试**：vp 固件版本号 `vfw-3.5:rel0030-…` ⇒ VPU 3.5，与上游 `sm8750_data` 绑定的 `iris_vpu35_p4_gen2_desc`（VPU 3.5 / Gen2）**同一代**；设备侧 DT 的时钟/电源域/OPP/IOMMU/保留内存**全部齐备且已在设备 DT 中生效**（§2）。不是"缺一堆东西"的状态。

**Fallback**：即便 iris 开不起来，Moonlight 的软件解码与本问题的关系是另一条线（V+ 的探测只看 `/dev/video*` 与 V4L2 能力），本报告不改那段逻辑。

---

## 1. 固件面（命令 + 原始输出）

### 1.1 vendor 镜像从哪来（没有重新下载）

`reports/sensors-692-real-configs-20261127.md` §1 的流水：官方 ROM `super` 不是顺序切片，是 `rawprogram_save_persist_unsparse0.xml` 里 8 段 used-extent（4 KiB 扇区，super 起始 sector 90504）。源件在盘上，**未下载任何东西**：

```
$ ls -la backup/official-rom-15.10.259/super_*.img
405504      super_1.img       12266729472  super_4.img        1536172032  super_7.img
1650688     super_2.img       12533760     super_5.img        147382272   super_8.img
1041178624  super_3.img       598372352    super_6.img
$ grep -o '<program[^>]*filename="super[^"]*"[^>]*>' backup/official-rom-15.10.259/rawprogram_save_persist_unsparse0.xml
（8 条，start_sector=90504/90760/91272/345480/3340424/3343496/3489672/3864968，SECTOR_SIZE=4096）
```

拼回 + 抽分区（脚本见 `out/hwdec-iris-20261127/README.md`）：

```
$ truncate -s 23622320128 super.img    # 22 GiB 逻辑
$ for spec in "super_1.img 90504 99" ... "super_8.img 3864968 35982"; do
    rel=$(( ($start-90504)*4096 )); sz=$(( $n*4096 ))
    dd if=.../$fn of=super.img bs=1M oflag=seek_bytes seek=$rel iflag=count_bytes count=$sz conv=notrunc status=none
  done
OK super_1.img rel=0 n=405504      ... OK super_8.img rel=15460204544 n=147382272
$ du -h --apparent-size super.img ; du -h super.img
22G	super.img
15G	super.img
$ ~/bin/lpunpack -p vendor_a super.img .
$ ls -la vendor_a.img
-rw-r--r-- 1 xuqianhui xuqianhui 1536176128 11月27 14:13 vendor_a.img
$ sha256sum vendor_a.img
6751d3a5ba6863170af88890773fd721d2348eb442dfef3cbeed78252842e437  vendor_a.img
```

✅ **校验通过**：`1536176128` B + sha256 `6751d3a5…e437` 与 `reports/bigfile-verdict-20261120.md` 记的原厂 `vendor_a` **完全一致** ⇒ 重建无损。

### 1.2 `/vendor/firmware` 里与 iris/VPU 相关的文件（全量）

```
$ debugfs -R "ls -l /firmware" vendor_a.img | wc -l          → 293 行
$ debugfs -R "ls -l /firmware" vendor_a.img | grep -iE "vpu|iris|venus|cvp|vcodec|amphion|media"
   2470  100644 (1)      0      0   2331336  1-Jan-2009 08:00 vpu30_2v.mbn
   2471  100644 (1)      0      0   2324656  1-Jan-2009 08:00 vpu30_2v_unsigned.mbn
   2472  100644 (1)      0      0   2327240  1-Jan-2009 08:00 vpu33_4v.mbn
   2473  100644 (1)      0      0   2321464  1-Jan-2009 08:00 vpu33_4v_unsigned.mbn
   2474  100644 (1)      0      0   2392776  1-Jan-2009 08:00 vpu35_4v.mbn
   2475  100644 (1)      0      0   2386216  1-Jan-2009 08:00 vpu35_4v_unsigned.mbn
```

**命中 6 个，全部是 `vpu*`；无 `*iris*`、无 `venus*`、无 `cvp*`**（cvp 固件也不在 vendor —— 那是 `dspso.bin`/`evass` 线，与本题无关）。全量清单：`reports/artifacts/hwdec-iris-20261127/vendor-firmware-listing.log`。

| 文件 | 大小 (B) | sha256[0:16] | ELF `QC_IMAGE_VERSION_STRING` |
|---|---|---|---|
| `vpu30_2v.mbn` | 2331336 | `619d4f27945b4079` | `video-firmware.3.4-aca23f18…` |
| `vpu30_2v_unsigned.mbn` | 2324656 | `6c6d18229589dcc1` | `video-firmware.3.4-aca23f18…` |
| `vpu33_4v.mbn` | 2327240 | `b07f0d7d4370e9ae` | `video-firmware.3.4-ee557904…` |
| `vpu33_4v_unsigned.mbn` | 2321464 | `1a7a1bf2680434cc` | `video-firmware.3.4-ee557904…` |
| **`vpu35_4v.mbn`** | **2392776** | **`9f6352d526f39bc3`** | **`vfw-3.5:rel0030-87dd8d27…`** |
| `vpu35_4v_unsigned.mbn` | 2386216 | `c040a1c334c26816` | `vfw-3.5:rel0030-87dd8d27…` |

完整 sha256（64 位）+ 逐文件 ELF 段表：`reports/artifacts/hwdec-iris-20261127/vpu-firmware-sha256.log`。

**signed 与 unsigned 的结构差别**（`python3` 解 ELF phdr，证据同上日志）：

```
filename                    size    type0 (p_offset, p_filesz)          last_load_end
vpu35_4v.mbn                2392776 [(0,756), (2387968,4808)]           2386216   ← 尾部 4808 B hash 段
vpu35_4v_unsigned.mbn       2386216 [(0,756), (4096,744)]               2386216   ← 无尾部 hash 段
```

⇒ `vpu35_4v.mbn` 是 **signed** 版（尾部带 4808 B hash/signature 段，`file` = `ELF 32-bit LSB executable, Tensilica Xtensa, statically linked, no section header`），正是 Android 在本机实际加载的那份。**上机必须装 signed 版，不要装 `_unsigned`。**

`vfw-3.5` = VPU 3.5，与驱动 `sm8750_data → iris_vpu35_p4_gen2_desc`（§2）同代。

### 1.3 设备侧现状（只读 ssh）

```
$ ssh elden 'ls -l /lib/firmware/qcom/vpu/'
ls: 无法访问 '/lib/firmware/qcom/vpu/': 没有那个文件或目录
$ ssh elden 'ls /lib/firmware/qcom/sm8750 | head -3'
adsp.b00  adsp.b01  adsp.b02          # 只有已装的 adsp（PAS）分片
```

⇒ 固件**未安装**；`/lib/firmware/qcom/` 目录本身存在（adsp 在用），只是缺 `vpu/` 子目录。

---

## 2. 驱动面（三问，源码行号 + 原文）

源码位置：`build/daily/drivers/media/platform/qcom/iris/`（= `wt/fastrpc-sensorspd-test/…` 同名目录，内容相同）。共 60 个文件，含 `iris_platform_sm8750.h` / `iris_platform_vpu3x.c`（`sm8750_data` 在此）/`iris_probe.c`/`iris_firmware.c`。

### ① `qcom,sm8750-iris` 在 of_match 表里吗？——**在**

`iris_probe.c:358-390`：

```c
static const struct of_device_id iris_dt_match[] = {
	...
	{
		.compatible = "qcom,sm8650-iris",
		.data = &sm8650_data,
	},
	{
		.compatible = "qcom,sm8750-iris",     /* ← iris_probe.c:384 */
		.data = &sm8750_data,                 /* ← iris_probe.c:385 */
	},
	{
		.compatible = "qcom,x1p42100-iris",
		.data = &x1p42100_data,
	},
	{ },
};
```

设备侧交叉印证（`modinfo` 读的是**设备上真在跑的那个 .ko**）：

```
$ ssh elden 'modinfo qcom-iris | grep alias'
alias:          of:N*T*Cqcom,sm8750-irisC*
alias:          of:N*T*Cqcom,sm8750-iris
```

### ② sm8750 平台数据要的固件文件名？——`qcom/vpu/vpu35_p4.mbn`

`iris_platform_vpu3x.c:45-49`（平台数据在 `:187`，绑定链 `:188`）：

```c
static const struct iris_firmware_desc iris_vpu35_p4_gen2_desc = {
	.firmware_data = &iris_hfi_gen2_data,
	.get_vpu_buffer_size = iris_vpu33_buf_size,
	.fwname = "qcom/vpu/vpu35_p4.mbn",        /* ← :48 */
};
...
const struct iris_platform_data sm8750_data = {          /* ← :187 */
	.firmware_desc_gen2 = &iris_vpu35_p4_gen2_desc,  /* ← :188 */
	.vpu_ops = &iris_vpu35_ops,
	.clk_rst_tbl = sm8750_clk_reset_table,   /* sm8750_clk_reset_table = "bus0","bus1","core","vcodec0_core" */
	.clk_tbl = sm8750_clk_table,
	.dma_mask = 0xe0000000 - 1,
	.max_core_mbps = ((7680 * 4320) / 256) * 60,
	...
};
```

⇒ 主线的期望名是 `vpu35_p4.mbn`，**vendor 给的是 `vpu35_4v.mbn`（名字不同，内容同代）**。两条路都合法：
- (a) 安装时改名 `vpu35_4v.mbn → vpu35_p4.mbn`（零 DT 改动）；或
- (b) DT 里加 `firmware-name = "qcom/vpu/vpu35_4v.mbn";` —— 驱动**优先读 DT**：

`iris_firmware.c:85`：
```c
ret = of_property_read_string_index(dev_of_node(core->dev), "firmware-name", 0, fw_name);
if (ret) { *fw_name = core->iris_firmware_desc->fwname; ... }
```

注：`sm8750` **只挂 gen2**（无 `firmware_desc_gen1`）⇒ `has_both_gens == false`，不会走"gen1 回退"分支，`iris_detect_gen2_from_fwdata()` 的 `vfw`/`video-firmware.N` 嗅探对 sm8750 不生效（只影响日志/分支选择，不是门）。

### ③ 固件 HFI 版本 / 水印有没有校验？——**没有版本门；真门是 PAS 验签**

(a) **固件回报的版本只打日志**，`iris_hfi_gen2_response.c:777-795`：

```c
static int iris_hfi_gen2_handle_image_version_property(struct iris_core *core, struct iris_hfi_packet *pkt)
{
	u8 *str_image_version = (u8 *)pkt + sizeof(*pkt);
	...
	for (i = 0; i < IRIS_FW_VERSION_LENGTH - 1; i++) ...
	fw_version[i] = '\0';
	dev_dbg(core->dev, "firmware version: %s\n", fw_version);   /* ← :793 只打印，无比较 */
	return 0;
}
```

`grep -rn "hfi_version\|fw_version\|min_fw\|api_version\|watermark"` 全目录：**没有**任何版本比较/拒绝路径（`watermark` 只命中 HFI 队列的 `rx_wm/tx_wm` 字段注释，`iris_hfi_queue.h:114-115`，与固件签名无关）。

(b) 唯一的"版本不匹配"表现形式是**系统响应超时**（`iris_platform_common.h:15` `HW_RESPONSE_TIMEOUT_VALUE (1000)` / `iris_core.c:42-49`）：

```c
ret = wait_for_completion_timeout(&core->core_init_done, msecs_to_jiffies(HW_RESPONSE_TIMEOUT_VALUE));
if (!ret) { core->state = IRIS_CORE_ERROR; return -ETIMEDOUT; }
```

(c) **真正的门 = TZ 验签**，`iris_firmware.c:16` / `:148` / `:169`：

```c
#define IRIS_PAS_ID				9
...
ret = qcom_mdt_load(dev, firmware, fw_name, IRIS_PAS_ID, mem_virt, mem_phys, res_size, NULL);
if (ret) goto err_release_fw;
...
ret = qcom_pas_auth_and_reset(IRIS_PAS_ID);
if (ret)  { dev_err(core->dev, "auth and reset failed: %d\n", ret); return ret; }
```

⇒ 签名是否被 TZ 接受 = 固件字节 + TZ secboot 策略的问题，**主机侧不可判定**（这也是上游 `sm8750.dtsi:3008-3012` 注释的可操作含义）。我们用的是**本机厂商为这台机器出的 signed 镜像**，签名链与平台同源，因此"能过"是高概率但**未经证实**。

### 驱动就绪度核对（设备只读探测，`device-probe.log`）

```
$ ssh elden 'uname -r'
7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0
$ ssh elden 'lsmod | grep -i iris'
qcom_iris             176128  0        ← 已加载，refcount 0（无用户）
$ ssh elden 'ls /sys/bus/platform/drivers/qcom-iris/'
bind  module  uevent  unbind           ← 驱动已注册，**无 bound 设备**
$ ssh elden 'n=/sys/firmware/devicetree/base/soc@0/video-codec@aa00000; ls $n'
clock-names clocks compatible dma-coherent interconnect-names interconnects interrupts
iommus memory-region name operating-points-v2 opp-table power-domain-names power-domains
reg reset-names resets status
$ ssh elden 'tr -d "\0" < $n/status'      → disabled
$ ssh elden 'tr "\0" "\n" < $n/clock-names' → iface core vcodec0_core iface1 core_freerun vcodec0_core_freerun
$ ssh elden 'tr "\0" "\n" < $n/power-domain-names' → venus vcodec0 mxc mmcx
$ ssh elden 'tr "\0" "\n" < $n/interconnect-names' → cpu-cfg video-mem
$ ssh elden 'tr "\0" "\n" < $n/reset-names' → bus0 bus1 core vcodec0_core
$ ssh elden 'ls /sys/firmware/devicetree/base/reserved-memory/video@9c300000'  → name no-map phandle reg  （reg = 0x9c300000 + 0x800000 = 8 MiB，no-map）
$ ssh elden 'ls /dev/video*' → 无
$ ssh elden 'dmesg | grep -icE "iris|vpu|venus"' → 0
```

**运行时 DT 的每个属性都与驱动 `sm8750_data` 的要求对齐**：6 个 clock 名、4 个 power-domain 名、2 个 icc 名、4 个 reset 名、`opp-table`、`memory-region`（指向 8 MiB `no-map` 区，> `qcom_mdt_get_size()` 需要的 ~2.4 MiB）、`dma_mask 0xe0000000-1`。**没有缺项**——不用补 reserved-memory、不用补时钟。

`Kconfig` 依赖也齐（`CONFIG_VIDEO_QCOM_IRIS=m`，`select QCOM_MDT_LOADER / QCOM_SCM / QCOM_PAS`；`build/daily/.config` 里 `CONFIG_QCOM_PAS=y`、`CONFIG_QCOM_MDT_LOADER=y`）。

---

## 3. 补丁草案（**不落地**，不进 `arch/`）

### 3.1 板级 dtsi 覆盖（唯一必需改动）

目标文件：`build/daily/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`
（**不改** `sm8750.dtsi:3008-3013` 的 `status="disabled"` —— 那是 SoC 公共文件，别的板子要靠它保持关闭）

```diff
--- a/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts
+++ b/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts
@@ -3166,3 +3166,16 @@
 		qcom,tx-port-mapping = <2 2 3 4>;
 	};
 };
+
+/*
+ * Hardware video decode (iris / VPU 3.5).
+ *
+ * sm8750.dtsi keeps this node disabled because "IRIS firmware is signed by
+ * vendors". Lenovo ships a signed VPU image for TB322FC; it lives in
+ * /vendor/firmware/vpu35_4v.mbn on the stock image and is installed on the
+ * host as <firmware-name> below.
+ */
+&iris {
+	status = "okay";
+	firmware-name = "qcom/vpu/vpu35_4v.mbn";
+};
```

说明：
- 用 `&iris` 标签（`sm8750.dtsi:2956` `iris: video-codec@aa00000`）⇒ 板级覆盖，符合"不动上游 dtsi"的要求。
- `firmware-name` 是**可选但推荐**的：省掉改名，且把"我们用的是 vendor 命名"这件事写在 DT 里。若选择改名为 `vpu35_p4.mbn`，可删掉这一行。
- 若想保留 `signed/unsigned` 两个选择，`firmware-name` 只能指一个（无 fallback 到 `_unsigned`）。

**草案已验证（不落 arch/）**：把上面这份 diff 应用到 `/tmp` 里的副本，用构建树自带的 include 路径预编译 + `dtc` 编一遍：

```sh
cp build/daily/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts /tmp/iris2/patched.dts   # + 追加上述 hunk
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
    -I$KDIR/arch/arm64/boot/dts/qcom -I$KDIR/include -I$KDIR/arch/arm64/boot/dts \
    -o patched.pre.dts patched.dts
dtc -I dts -O dtb -o patched.dtb patched.pre.dts
```

输出（只有 sm8750.dtsi 里既有的 `unique_unit_address` 警告，与本补丁无关）：

```
patched.dtb 153121 B
$ fdtget patched.dtb /soc@0/video-codec@aa00000 status          → okay
$ fdtget patched.dtb /soc@0/video-codec@aa00000 firmware-name   → qcom/vpu/vpu35_4v.mbn
```

⇒ 语法与标签引用正确、DTB 属性如预期。**未写入仓库任何 `arch/` 路径。**

编译 & 打包（构建树 = `build/daily`，DTB 打进 boot.img，见 `scripts/build-boot.sh:48,111`）：

```sh
KDIR=/home/xuqianhui/y700-elden/build/daily
git -C $KDIR log --oneline -1        # 先核树（见开头的基线说明）
make -C $KDIR ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/sm8750-lenovo-elden.dtb
fdtget $KDIR/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb \
       /soc@0/video-codec@aa00000 status        # 期望 okay
scripts/build-boot.sh                # → boot-elden-vkNNN.img（含新 DTB）
```

### 3.2 `/lib/firmware` 安装清单

| 源（主机） | 目标文件名（设备） | 权限 / 属主 |
|---|---|---|
| `out/hwdec-iris-20261127/fw/vpu35_4v.mbn`<br>sha256 `9f6352d526f39bc3f25b6d670ba9f4a18ebd9dea57e043683b70a301e22ee6c7` | `/lib/firmware/qcom/vpu/vpu35_4v.mbn`（或改名 `vpu35_p4.mbn`，见 3.1） | `0644 root:root`，需 `mkdir -p /lib/firmware/qcom/vpu` |

- **只装 signed 版**（`_unsigned` 会在 `auth and reset` 阶段失败，因为缺尾部 hash 段）。
- 备选源（若不想用 ROM 抽取件）：设备原厂分区自身的 `/vendor/firmware/vpu35_4v.mbn`——两份 sha256 应一致（本轮无法读设备 vendor 分区核对，**未证实**）。
- 不需要装 `vpu30_*` / `vpu33_*`（那是别的 VPU 代次）。
- 不需要 initramfs 里的 firmware（iris 是模块、按需 `request_firmware`，rootfs 挂上后再 probe 就行；若配成早期 probe 才需要）。

---

## 4. 上机验收步骤（物理动作由用户执行）

前置：`scripts/device-lock.sh` 拿锁；本次改动 = **1 个 DTB（需重打 boot.img）+ 1 个固件文件**，都可回退（旧 boot.img 与删固件）。

```sh
# 0) 取锁
scripts/device-lock.sh acquire hwdec-iris

# 1) 装固件（rootfs 可写时；也可在打包 rootfs 时预置）
adb push out/hwdec-iris-20261127/fw/vpu35_4v.mbn /tmp/
ssh root@elden 'mkdir -p /lib/firmware/qcom/vpu && \
  install -m 0644 /tmp/vpu35_4v.mbn /lib/firmware/qcom/vpu/vpu35_4v.mbn && \
  sha256sum /lib/firmware/qcom/vpu/vpu35_4v.mbn'
#    期望 9f6352d526f39bc3f25b6d670ba9f4a18ebd9dea57e043683b70a301e22ee6c7

# 2) 打含新 DTB 的 boot.img 并刷入（§3.1 的补丁先应用 + 编译）
#    boot.img 刷写按 RUNBOOK 的 vkNNN 流程；刷完必须重启

# 3) 起来后第一件事：看驱动有没有 bind
ssh root@elden 'dmesg | grep -i iris'
#   关心的关键字（成功路径）：
#     qcom-iris aa00000.video-codec: ...        ← probe 进
#     firmware version: vfw-3.5:rel0030-...     ← HFI 系统响应回来了（dev_dbg，需 loglevel 8）
#   失败模式对照表：
#     "firmware download failed -2"            → /lib/firmware 路径/文件名不对（-ENOENT）
#     "auth and reset failed: -22"             → TZ 拒签/参数错（最可能的卡点）
#     "auth and reset failed: -5"              → TZ 拒绝（PAS 未授权）
#     probe 后 1000 ms 无响应 → 超时 -110      → HFI 协议/固件不匹配
#     完全无 iris 日志                          → DTB 没生效（回看 fdtget）

# 4) 节点与设备
ssh root@elden 'ls /dev/video*'                       # 期望 /dev/video0（+1 个）
ssh root@elden 'v4l2-ctl --list-devices'              # 期望 "qcom-iris" / platform:aa00000.video-codec
ssh root@elden 'v4l2-ctl -d /dev/video0 --list-formats-out'   # 期望 H264/HEVC/VP9/AV1

# 5) 真解码（最小闭环，不依赖 Moonlight）
ssh root@elden 'v4l2-ctl -d /dev/video0 --list-framesizes=H264'

# 6) Moonlight / V+ 再测「硬件解码」
#    选 1080p60 H.264 或 HEVC 串流；同时看
ssh root@elden 'cat /sys/kernel/debug/pm_genpd/*/status 2>/dev/null; cat /sys/class/devfreq/*/trans_stat 2>/dev/null | head'
#    V+ 侧日志应出现 V4L2/V4L2M2M 解码器而非 avcodec 软解
```

判据（三态，不许含糊）：
- **PASS** = `ls /dev/video*` 有节点 + `v4l2-ctl --list-devices` 出现 iris + Moonlight 跑 1080p60 且 CPU 单核 <30%。
- **FAIL（固件门）** = 出现 `auth and reset failed` ⇒ 签名/PAS 门过不了，路线退化为「等厂商签名固件或放弃 HW 解码」，并记录具体 errno。
- **未证实** = 其它任何状态；保留 `dmesg` 全文落 `reports/artifacts/hwdec-iris-<date>/`。

---

## 5. 残余风险 / 缺证据清单

1. **PAS ID 9 验签（唯一真门）**：主机侧无法判定。证据只有"这是本机厂商原厂 signed 镜像"。若 FAIL，本路线在不动 TZ 的前提下走不通。
2. **HFI 报文兼容性**：驱动不做版本校验，但 Android 厂商 vidc 驱动与主线 iris 的 HFI 结构若不一致，表现是 1000 ms 超时。上游 `sm8750_data` 由 Linaro 2025 年提交（`iris_platform_vpu3x.c` 版权头 `Copyright (c) 2025 Linaro Ltd`），其测试固件名 `vpu35_p4.mbn` 与 vendor 的 `vpu35_4v.mbn` 是否**逐字节同源**，本轮**缺证据**（需拿到 linux-firmware 里的 `qcom/vpu/vpu35_p4.mbn` 比对 sha256；本机无该文件，也未联网取）。
3. **vk192 源码树不在盘上**：`4bdf1711b5c0` 无法 `git cat-file`。补丁按 `4da9a8b69fc85` 写，重编前必须核树；若两版 `sm8750-lenovo-elden.dts` 有差异，补丁需 rebase。
4. **未读设备 vendor 分区原件**：`/vendor/firmware/vpu35_4v.mbn`（设备侧）与 ROM 抽取件的 sha256 一致性**未证实**。
5. **8 MiB `video_mem` 是否够**：静态够（固件 2.4 MiB + `qcom_mdt_get_size`），但 iris 运行时可能需要更多 carveout；上游 dtsi 就给了 8 MiB，按上游走，**未上机验证**。
6. 本报告**未**改任何设备文件、未刷机、未 commit；`out/hwdec-iris-20261127/` 里 `super.img`（15 G 实占）已删，`vendor_a.img`（1.5 G）+ `fw/`（13.9 MB）保留备料。

---

## 父代理追加（2026-11-27 14:24，设备侧只写固件，无重启）

- 已把 `out/hwdec-iris-20261127/fw/vpu35_4v.mbn` 装成设备侧 **`/lib/firmware/qcom/vpu/vpu35_p4.mbn`**（`-m 644 root:root`，sha256 `9f6352d526f39bc3…`，与 `out/` 原件逐字节一致）。
  这一步**不改变任何行为**：节点仍 `disabled`，`qcom-iris` 仍无 bound 设备。
- 仍未做（需一次重启窗）：板级 `&iris { status="okay"; };` + 重编 DTB/打 `boot.img`。本报告 §0 的补丁草案已在 `/tmp` 副本上 `cpp+dtc` 编过（`fdtget status → okay`），未写任何 `arch/`。
- `out/hwdec-iris-20261127/vendor_a.img`（1.5 GB）已删（可按下表命令从 `backup/official-rom-15.10.259/super_*.img` 重建），只留 `fw/`（14 MB）。
