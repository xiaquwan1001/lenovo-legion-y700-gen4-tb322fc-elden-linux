# Gunyah RM 在主线 Linux 上跑通：`/dev/gunyah` 出现 + `GUNYAH_CREATE_VM` 成功（真实 RM RPC 往返）

> 日期：2026-10-24 深夜 · 设备 `HA2EXB0E` · 内核 vk127（`7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`，即 Gunyah 移植树 `build/gunyah-port@24223e4`）
> 全程零写盘（`fastboot boot`，未写任何分区）；唯一持久改动 = 设备 rootfs 里一个开机自启钩子（§5，可删）。

## 0. 结论（先数字）

| 判据 | 结果 |
|---|---|
| TZ SIP 取到 hyp boot info | ✅ `arm_smccc_smc(0x02000609)` → `a1=0x8088f000`，magic `0xC06B0071`、version 1、size 96、vm_type 1、**num_dtbos 2** |
| 厂商 DTBO 应用进主线 DT | ✅ dtbo[0]（1013 B）`of_overlay_fdt_apply -> 0` ⇒ `/hypervisor/` 出现（含 RM 节点，**capid 每次开机新值**） |
| `gunyah.ko` | ✅ 绑定 `/hypervisor`；`dmesg: Running under Gunyah hypervisor 51/v1` |
| `gunyah_rsc_mgr.ko` | ✅ 绑定 `hypervisor:qcom,resource-manager-rpc@…`（tx/rx capid 从 DT `reg` 读出、两条 IRQ 请求成功） |
| `/dev/gunyah` | ✅ 字符设备出现（`crw------- 10,262`） |
| **RM RPC 往返** | ✅ `ioctl(GUNYAH_CREATE_VM)` → **fd 4**（= VM_CREATE 请求过 hypervisor msgq → 收到响应 → 建 VM → close 销毁） |
| 第二个 DTBO | ❌ `-EINVAL`（target 是**厂商 DT 路径**：`/soc/qcom,wdt@16410000`、`/firmware/qcom_scm`、`arch_timer` phandle）⇒ **可选**，与 RM 无关 |

## 1. 完整链路（这就是「capid 发现」的正解）

```
TZ SIP 0x02000609 (HYP_INFO_GET_HYP_DTB_ADDRESS, param_id=0)   ← arm_smccc_smc，无入参
  → Results[1] = hyp_boot_info 物理地址（本次 0x8088f000）
      struct hyp_boot_info { u32 magic;   /* 0xC06B0071 */
                             u32 version; /* 1 */
                             u32 size;    /* 96 */
                             u32 pil_enable;
                             { u32 vm_type; u32 num_dtbos;
                               struct { u64 dtbo_base, dtbo_size; } linux_aarch64[4]; } }
  → 每个 dtbo 是一份 FDT overlay，dtbo[0] 就是「hypervisor 子树」：
      hypervisor { compatible="qcom,gunyah-hypervisor-1.0","qcom,gunyah-hypervisor","simple-bus";
                   #address-cells=2; #size-cells=0;
        qcom,gh-watchdog { interrupts=<0 0 4> }
        qcom,gunyah-vm   { qcom,vmid=<3>; qcom,vendor="Qualcomm" }
        qcom,resource-manager-rpc@<tx_capid> {
          compatible="gunyah-resource-manager", ...;
          reg=<tx_capid rx_capid>;        ← 每次开机新发（本轮实测 3 发：0x296f376b12c998f0 /
                                              0x5076575439712e53 / … 各不相同）
          interrupts=<0 0x3c0 1 0 0x3c1 1>;  ← SPI 960/961，恒定
          qcom,free-irq-start/is-full-duplex/tx-rx-message-size/queue-depth } }
  → of_overlay_fdt_apply(dtbo)  ⇒ 上游 gunyah/rsc_mgr 直接 bind
```

**实现 = 两个小模块 + 一个静态测试程序**（都在 `build/gunyah-port/`）：
- `elden-hypprobe/hypprobe.ko` —— 只读探针：打 SIP、hexdump HBI 与 DTBO（调试用，`in-tree` 外置模块）。
- `elden-gunyah-dtbo/dtbo.ko` —— 正式件：打 SIP → 校验 magic → `kmemdup` 每个 DTBO（overlay 只引用不拷贝）→ `of_overlay_fdt_apply()`；debugfs `elden-gunyah/dtbo{0,1}` 导出原始 blob。
- `elden-rmtest/rmtest.c` —— 静态 aarch64 程序：`open("/dev/gunyah")` + `ioctl(GUNYAH_CREATE_VM)`。

## 2. 关键前置：板 DTB 必须带 `__symbols__`

dd 目录里主线默认 `dtc` **不加 `-@`** ⇒ 没有 `__symbols__` ⇒ 厂商 DTBO 的 `__fixups__` 无法解析 ⇒ `of_overlay_fdt_apply` 一律 `-EINVAL`（本轮第一版就是这个现象，两个 overlay 都 -22）。
修法（已落补丁 `patches/gunyah/0001-arm64-dts-qcom-elden-enable-dtc-symbols.patch`）：

```make
DTC_FLAGS_sm8750-lenovo-elden.dtb := -@
```

带该 DTB 的镜像：`out/boot-elden-dtbo1.img`（sha256 `5d6ba622…`，DTB sha256 `d35adfda…`，201 582 B；其余与 vk127 同）。

## 3. 复现（两条命令）

```bash
scripts/to-fastboot.sh && fastboot boot out/boot-elden-dtbo1.img   # 或任何带 -@ DTB 的 vk 镜像
scripts/gunyah-rm-bringup.sh            # 构建/安装 dtbo.ko + rmtest → 拉起栈 → 验 RM RPC
#   HOOK=1 scripts/gunyah-rm-bringup.sh  # 顺带装开机自启钩子
```

脚本内判据全打印：`/hypervisor OK`、capid 原值、`/dev/gunyah`、rsc_mgr 绑定名、`GUNYAH_CREATE_VM -> <fd>`。

## 4. 坑（已入 PITFALLS #389）

- **DTB 无 `__symbols__` ⇒ overlay -EINVAL**（不是 overlay 格式错、也不是 magic 错）。
- **`rmmod` 承载 overlay 的模块时若 RM 已绑定 ⇒ 整机复位**（实测：`rmmod dtbo` 后 20 s 内设备重启，`/dev/gunyah` 消失）。腾挪 debugfs/重载 dtbo 前必须先 `rmmod gunyah_rsc_mgr gunyah_qcom gunyah ...`。
- `dtbo[1]` 的 -EINVAL 是**预期**：它改的是厂商 DT 路径（`/soc/qcom,wdt@16410000` 禁 watchdog、`/firmware/qcom_scm` 加 `qcom,max-queues=2` + SPI 962、`arch_timer` 加 `always-on`），主线节点名/路径不同。需要时逐条手工适配（不是 RM 的前置）。

## 5. 设备持久改动（可回退）

- `/etc/local.d/50-gunyah.start`（Alpine local hook）：开机 `modprobe dtbo` + gunyah 栈；DTB 没有 `__symbols__` 时它会静默失败、不影响启动。
- `/lib/modules/<UTS>/extra/dtbo.ko`、`/tmp/rmtest`。
- 回退：删该 hook 文件即可（模块留着无害）。

## 6. 下一步（G2 真正要的东西）

RM 通了以后，VMM 才有意义：
1. `gunyah_vcpu.ko`/`gunyah_irqfd.ko`/`gunyah_ioeventfd.ko` 已编好，`GUNYAH_VM_SET_DTB_CONFIG`+`GUNYAH_VM_START` 需要一份**给 guest 的 DTB**（对照第三方先例 `Droid-VM/edk2-gunyah`/crosvm-gunyah）。
2. USB 直通唯一实现 = `Droid-VM/crosvm fb86c7b0`（仿真 xHCI + usbfs）⇒ 与 RM 已通的组合是 WoaA 的可行栈。
3. 若要上游化：`dtbo.ko` 的「SIP → hyp boot info → overlay」应做成 DT 缺节点时的 fallback（或由 bootloader 注入），而不是常驻外置模块。
