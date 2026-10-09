# Q26 静态准备（2026-10-08，主机侧，未上机）

> 目的：在派次级联前先用 manifest + DTB 反编译确认「vk40→vk63 版本 bisect」的变量是否单变量。
> 结论只作为 bisect 计划修正，不改 `TASKS.md`（状态权威仍在 §5 Q26）。

## 0. 结论（数字先行）

1. **vk62 与 vk63 的内核与 ramdisk 逐字节相同**，DTB 唯一差异 = cambist 节点新增 `power-domains=<&rpmhpd RPMHPD_MX>`+`required-opps`。
2. **该 DTB 差量不含任何 WiFi/PCIe/WCN 节点**（反编译全量 diff，256 行差异全为 phandle 重编号 + 上述 2 个属性）。
   ⇒ **vk62 与 vk63 的 WiFi 行为在静态上必然一致**（v63 干净 ⇒ v62 也应干净）。
3. **vk61 与 vk63 是双变量**：内核 Image（`/tmp/kdir-bootb/…/Image.gz` sha `2321e3b9…` vs `out/Image-vk47clean.gz` sha `1c0d3310…`）
   与 ramdisk（`/tmp/bootb-rootfs-newinit.cpio.gz` sha `0fadae6b…` vs `initramfs-full-elden.cpio.gz` sha `35823240…`）**都不同**。
4. ⇒ 若「vk61 时代掉链、vk63 干净」成立，回归点应落在 **vk61→vk62 的「内核 Image + initramfs 更换」**，
   **不在 DTB**，也不在 vk62→vk63。原计划「vk40/vk47/vk53/vk61/vk63 各连一次」会引入混淆。

## 1. 证据

### 1.1 manifest 逐字段（`out/boot-elden-vk{61,62,63}.manifest`）

| 项 | vk61 | vk62 | vk63 |
|---|---|---|---|
| kernel (mkbootimg 实参) | `/tmp/kdir-bootb/…/Image.gz` | `out/Image-vk47clean.gz` | `out/Image-vk47clean.gz` |
| kernel_sha256 | `2321e3b995df5fe3…` | `1c0d3310de55e975…` | `1c0d3310de55e975…` |
| kernel_image_sha256 | (absent) | `39a8db01fd81505b…` | `39a8db01fd81505b…` |
| ramdisk | `/tmp/bootb-rootfs-newinit.cpio.gz` | `out/initramfs-full-elden.cpio.gz` | `out/initramfs-full-elden.cpio.gz` |
| ramdisk_sha256 | `0fadae6be3956a1a…` | `35823240fcd15b4b…` | `35823240fcd15b4b…` |
| dtb | `sm8750-lenovo-elden.dtb` (`9d46693b…`) | `…-cambist-h1.dtb` (`79397e95…`) | `…-cambist-h2.dtb` (`386cc9bd…`) |

> ⚠️ `kernel_git_head` / `kernel_release` 列会误导（`PITFALLS` #131）：vk62/vk63 的 head 不同但实际 Image 都是
> `out/Image-vk47clean.gz`。

### 1.2 DTB 反编译全量 diff（`cambist-h1.dtb` → `cambist-h2.dtb`）

工具：`geekidos-linux/scripts/dtc/dtc -I dtb -O dts`。
- 语义差异仅 1 处：`clock-controller@1760000`（compatible `qcom,sm8750-cambistmclkcc`）新增
  `power-domains = <&rpmhpd RPMHPD_MX>`、`required-opps = <&rpmhpd_opp_low_svs>`。
- 其余 250+ 行差异全为 phandle 值平移（新增 phandle 引用导致后续重编号）。
- `grep -iE 'wifi|wcn|pcie|ath'` 全量 diff → **无命中**。

## 2. bisect 计划修正（建议）

1. **先做 1 次单变量复核**：`fastboot boot out/boot-elden-vk62.img` 连 P40 Pro，量
   「关联→IPv4 时间 + `iw station dump` beacon rx + bmiss 次数」。
   - 若 vk62 干净 ⇒ 证实「v63 干净」不是 vk63 特有，回归点在 vk61→vk62。
   - 若 vk62 掉链 ⇒ 则 cambist/H2 与 WiFi 存在耦合，需重估（与静态结论冲突，优先取证）。
2. **定位 vk61→vk62 变量**：v46/v47clean 内核 + 两种 initramfs 交叉组合（`fastboot boot` 零写盘）：
   - A = vk47clean Image + `bootb-rootfs-newinit.cpio.gz`（旧 ramdisk）
   - B = vk47clean Image + `initramfs-full-elden.cpio.gz`（新 ramdisk）
   - 只在 A/B 间变 ramdisk ⇒ 判定是否 ramdisk/固件引入。
3. **重点怀疑 initramfs 内 ath12k 固件**：G1-11 已证固件由 initramfs 在 switch_root 前加载（`PITFALLS` #127），
   WiFi 固件亦可能随 initramfs 换版；换版 = stock 固件非-20 变体曾 MHI POWER_ON `-110`（Q26 已记）。
4. 原先「vk40/vk47/vk53 全量逐个」降为**后备**，只在 vk61→vk62 内部仍不收敛时再扩。

## 3. 待父进程上机执行的命令（设备接入后）

```bash
# 0) 确认设备与锁
scripts/device-lock.sh fastboot devices

# 1) vk62 单变量复核（关键）
fastboot boot out/boot-elden-vk62.img          # 零写盘
# 起机后 SSH 到设备：
#   iw dev wlan0 station dump | grep -E 'beacon|signal'
#   dmesg | grep -iE 'ath12k|beacon|bmiss'
#   time nmcli -w 180 con up <P40 Pro profile>

# 2) 交叉 ramdisk（需先在主机侧构建 A/B 两个 boot.img）
#    A = out/Image-vk47clean.gz + /tmp/bootb-rootfs-newinit.cpio.gz + cambist-h2.dtb
#    B = out/Image-vk47clean.gz + out/initramfs-full-elden.cpio.gz + cambist-h2.dtb
```

## 4. 未证实 / 风险

- 「vk61 时代掉链」当时实际 boot 的镜像未在 manifest 逐字节留证（可能非当前 `out/boot-elden-vk61.img`）⇒ 结论待 vk62 实测。
- vk61 manifest 的 `/tmp/kdir-bootb` 与 `/tmp/bootb-rootfs-newinit.cpio.gz` 是否仍在主机上，需核实（用于构成 A 组）。
- 静态只证明 DTB 无 WiFi 差；不排除 cambist 电源域通过供电/时序间接影响射频（概率低）。
