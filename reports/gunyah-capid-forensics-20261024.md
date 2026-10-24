# Gunyah RM capid 取证成功（A 路，Magisk 零门槛）：**capid 每次开机都变 ⇒ 静态 DT 不可行；发现通道 = SCM SIP `0x02000609` + magic `0xC06B0071`**

> 日期：2026-10-24 深夜 · 设备 `HA2EXB0E`（U2）· 全程在 **stock Android 槽 a** 上操作，`boot_b`（日用 Linux）未被改动。
> 唯一写盘 = `fastboot flash init_boot_a`（Magisk 补丁版，用于提权读 DT），**已用开跑前 dump 的原厂镜像还原**（sha `e8206b81…`）。

## 0. 结论（先数字）

| 项 | 结果 |
|---|---|
| 拿到 capid | ✅ `reg = <tx, rx>`：样本1 `0x90d561f5f0ee2c27 / 0x90d561f5f0ee1c7c`；样本2 `0xea54cae59f233167 / 0xea54cae59f23de12` |
| **稳定性** | ❌ **每次开机都不同**（同机连续两次 `adb reboot` 实测）⇒ **写死进我们的 DTB 没用** |
| interrupts | ✅ **恒定**：`<0 0x3c0 1 0 0x3c1 1>` = GIC **SPI 960 / 961**，flags 1（edge-rising）；父节点 `#address-cells=2`，标准 3-cell GIC 格式 ⇒ **可直接写进主线 DT** |
| 节点全集 | `/proc/device-tree/hypervisor/` 3 个子节点（见 §2），父节点 compatible `qcom,gunyah-hypervisor-1.0`/`qcom,gunyah-hypervisor`/`simple-bus` ⇒ **上游 `gunyah.ko` 能匹配** |
| 发现机制 | ✅ = ABL 里 `RmVmDxe` 调 **SCM SIP**（id `0x02000609`，「GetHypBootInfo」）→ 返回 **hyp boot info 结构体物理地址** → 校验 **magic `0xC06B0071`** → 取 capid → **运行时生成 DTBO 并 merge 进 FDT** |

**⇒ 路线收敛**：主线要拿 capid 只有「自己调同一个 SIP」这一条（DT 静态注入死路）。下一步 = 主线里实现该 SIP 探测 + 建节点。

## 1. 怎么拿到 root（比预想简单，且可完全还原）

- 本机 Android 16（`ZUXOS_1.5.10.259`，内核 `6.6.118-android15`）用 **Magisk 补丁 `init_boot`**：`boot_a` 只有 raw kernel（36 731 392 B，无 ramdisk，header v4），ramdisk 在 `init_boot_a`（8 MiB，header v4，`lz4_legacy`，ramdisk 2 457 793 B）。
- 流程（全在主机侧，不需要 app 里的 Install 流程）：dump `init_boot_a` → `magiskboot unpack` → 手工执行 `assets/boot_patch.sh` 的 ramdisk 步骤（`add 0750 init magiskinit` + `overlay.d/sbin/{magisk,stub,init-ld}.xz` + `patch` + `.backup/.magisk`）→ `magiskboot repack` → `fastboot flash init_boot_a`。
- 资源：Magisk **v30.7** APK（`/tmp/magisk-route/Magisk-v30.7.apk`，sha256 `e0d32d21…`）；补丁镜像 `w/new-boot.img` sha256 `0fe5c9b8…`。
- 提权：装 APK → 打开 app → 点一次「允许」⇒ `adb shell` 里 `/debug_ramdisk/su -c id` = `uid=0(context=u:r:magisk:s0)`。**用户只点了一次。**
- 还原：`fastboot flash init_boot_a <原厂 dump>`（`/tmp/magisk-route/init_boot_a.img`，sha256 `e8206b81…`）。

## 2. 完整节点（live FDT，`android-fdt.dtb` sha256 `b52133f0…`，885 898 B）

```
hypervisor {
	compatible = "qcom,gunyah-hypervisor-1.0", "qcom,gunyah-hypervisor", "simple-bus";
	#address-cells = <2>; #size-cells = <0>;

	qcom,gh-watchdog { compatible = "qcom,gh-watchdog"; interrupts = <0 0 4>; };

	qcom,gunyah-vm { compatible = "qcom,gunyah-vm-id-1.0", "qcom,gunyah-vm-id";
	                 qcom,vmid = <3>; qcom,vendor = "Qualcomm"; };

	qcom,resource-manager-rpc@<tx_capid> {
		compatible = "gunyah-resource-manager", "qcom,resource-manager-1-0",
		             "qcom,resource-manager";
		reg = <tx_hi tx_lo rx_hi rx_lo>;            /* 两个 u64：tx capid, rx capid */
		interrupts = <0 0x3c0 1 0 0x3c1 1>;        /* SPI 960/961, 恒定 */
		qcom,free-irq-start = <0x3c0>;
		qcom,is-full-duplex;                        /* 空属性（bool） */
		qcom,tx-message-size = <0xf0>; qcom,rx-message-size = <0xf0>;
		qcom,tx-queue-depth  = <0x08>; qcom,rx-queue-depth  = <0x08>;
	};
};
```

- 与上游 `drivers/virt/gunyah/{gunyah.c,rsc_mgr.c}` 的消费面完全对齐（`compatible` 命中 + `reg` 两个 u64 + 两条 `interrupts`），`qcom,*` 属性上游忽略。
- 节点名后缀 = **tx capid**（十六进制）⇒ 名字里就带 tx capid，可作交叉校验。

## 3. capid 是「每次开机新发」的（决定性负面结果）

| 样本 | 触发 | tx | rx |
|---|---|---|---|
| 1 | `adb reboot` 后 | `0x90d561f5f0ee2c27` | `0x90d561f5f0ee1c7c` |
| 2 | 再 `adb reboot` | `0xea54cae59f233167` | `0xea54cae59f23de12` |

两者高 48 bit 相同、低 16 bit 不同 ⇒ 一个**每次开机新生成的 GUID 基** + 一对队列索引。
⇒ 任何「把 capid 写进 DTB/固件」的方案都不成立；Gunyah RM 必须在**每次开机**重新发现。

## 4. 发现机制（静态取证，`vendor-RmVmDxe.efi` 反汇编）

`reports/artifacts/uefi-dxe-20261024/vendor-RmVmDxe.efi`（57 344 B）里 `GetHypBootInfo` 路径：

```
LocateProtocol(QcomScmProtocol)
ScmSipSysCall(This, SipId = 0x02000609, ArgCnt, Req=sp+0x30, Rsp=sp+0x10)     ; 0x272c-0x2744
  ...
  ldr x19, [sp+0x18]                      ; Rsp[1] = hyp boot info 的物理地址
  gBS->AllocatePages(..., 8 pages)        ; 0x2760-0x277c
  gBS->CopyMem(dst, x19, ...)             ; 拷贝到自有缓冲
  ldrb/bfi 组装大端 u32 @0x00 → cmp #0xc06b0071     ; ★ magic = 0xC06B0071
  cmp 大端 u32 @0x14, #2                            ; 版本/类型字段 == 2
  ... capid 组装从 @0x18 起（大端 u64）
```

配套字符串（同一 PE）：`GetHypBootInfo Status: %d`、`Hyp Boot Info Magic Cookie Invalid`、`BootSharedImemCookiePtr != NULL`、
`MergeRmDtbo Status: %d`、`Merge Overlay: %d`、`fdt_set_blob_handle: %d`、`/hypervisor/qcom,resource-manager-rpc`、
`fdt_get_uint64_prop_list: %d`、`Could not allocate memory for CapIdProp`。

⇒ 链条：**hypervisor/QTEE 写 hyp boot info（含 RM capids）→ ABL RmVmDxe 用 SIP 取到地址 → 造 DTBO → merge 进 FDT**。
我们的主线只缺最前一步（SIP 探测）。

**旁证（已排除的误区）**：`/vendor/lib/modules/gh_rm_booster.ko` 的 `gh_rm_vm_get_hyp_res` 是 **RM RPC**（需要先有 RM 连接），
不是发现通道；`hvc_gunyah.ko`（console）、`gunyah_loader.ko` 也都与 capid 发现无关。

## 5. 下一步（主线侧实现，未开始）

1. **探针模块**：`arm_smccc_smc(0x02000609, ...)` 取返回的物理地址 → `memremap` → dump 前 0x100 字节 → 校验 magic `0xC06B0071` + 版本 2，并按 §4 的字节序规则解出两个 capid。
   *待定细节*：SIP 的 ArgCnt/入参（转储里 x2 未在本窗口设置，需回看调用者）与结构体 0x18 起的精确布局（大端 + 半字交换）。
2. **建节点**：在 `qcom_scm`/gunyah 侧加一个小驱动，用上面拿到的三组数（tx,rx,SPI 960/961）在开机时 `of_changeset` 建出 `hypervisor/qcom,resource-manager-rpc@…` 节点，或直接给 `rsc_mgr` 加一个「capid 由探测提供」的路径。
3. 之后才是 `/dev/gunyah` → RM RPC → VMM。

## 6. 本轮未做 / 风险

- 未在主线内核上真正发起该 SIP（SIP ABI 还有 1 个参数语义待确认）。
- `init_boot_a` 的 Magisk 补丁**已还原**；`boot_a`、`vbmeta`、`boot_b` 全程未动。
- 设备当前 slot 已 `set_active b`，回到 vk127 Linux。
