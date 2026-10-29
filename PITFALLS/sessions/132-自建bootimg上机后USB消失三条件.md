# #468 自建 boot.img 上机后「USB 整个消失」：三个必要条件缺一个都不行

## 结论（2026-10-29，three 次失败后定位）

给 M4 camss v3 做上机复验时，自建 `boot.img` 刷进 `boot_b` 后，**设备从 USB 总线彻底消失**
（宿主 `lsusb` 无 `05c6/18d1/1d6b:0104`，`192.168.7.1` 无应答 ⇒ 既不能 SSH 也没有串口）。
逐项排除后，**三个必要条件**（缺任一 ⇒ 无 USB）：

| # | 必要条件 | 判据 / 踩坑 |
|---|---|---|
| ① | **cmdline 必须带 `elden_early_gadget=1`** | 该 token 由 initramfs 的 `/init` 解析，决定**在 `switch_root` 之前**就把 NCM gadget 拉起来。缺它 ⇒ 即使内核/rootfs 完全正常，也**没有任何 USB 设备描述符**（不是"网卡没 IP"，是主机看不到设备）。<br>取证：从已知可用镜像里 grep 到 cmdline = `… elden_root=LABEL=linux17 androidboot.slot_suffix=_b **elden_early_gadget=1** elden_q28_nowd` |
| ② | **ramdisk 必须是已知可用的那一份**（`/init` 尺寸是判据） | 同一 rootfs 的两个 cpio 差 26 KB，但 `/init` 差一倍：可用镜像 = **34 584 B**（新版，含 early gadget 逻辑），`out/rootfs-vk127.cpio.gz` = **16 113 B**（旧版，无此逻辑）。<br>取证：`cpio -idv init` 后 `md5sum`，或直接比 ramdisk sha256 |
| ③ | **UTS 必须与设备 `/lib/modules/<UTS>` 逐字一致** | 本机 `CONFIG_USB_DWC3=m` ⇒ USB 控制器是**模块**；自建内核若 UTS 多一个 `+`（kbuild 对 dirty 树的默认行为），`/lib/modules/` 里没有对应目录 ⇒ `dwc3` 永远不加载 ⇒ **同样是无 USB 描述符**。<br>修法：`make Image.gz LOCALVERSION=`（**显式传空参数**，不是 `export LOCALVERSION=`），或直接 `CONFIG_LOCALVERSION_AUTO=n` + 写死 `CONFIG_LOCALVERSION` |

## 附带的两个「构建脚本骗人」点

① **`make Image` 不刷新 `Image.gz`**：`scripts/build-boot.sh` 读的是 `Image.gz`，若只 `make Image`，
   打进镜像的是**上一次的** `Image.gz`（本轮实测：第一次做的 `boot-elden-camssv3.img` 里
   kernel sha 与旧的 `vk181-daily` **完全相同**，白刷一次）。
   判据：解析 boot.img 头 `kernel_size`(offset 8) 后取 `[4096 : 4096+ks]` 算 sha256，**不要信 manifest**。
② **`build-manifest.sh` 的 `kernel_release` 与镜像内 UTS 可能不同**（它跑 `kernelrelease` 时不传
   `LOCALVERSION=`，会多出 `+`）。判据同样以**镜像内 kernel 段**为准。

## 定式

自建 boot.img 上机前，先跑这三条判定，全绿再刷：

```sh
python3 - <<'PY'   # ① kernel/ramdisk sha ② 与已知可用镜像对比
import struct,hashlib
d=open('out/xxx.img','rb').read(); ks,_,rs,_,_,_,_,_=struct.unpack('<8I', d[8:40]); P=4096
r=P+((ks+P-1)//P)*P
print('kernel', hashlib.sha256(d[P:P+ks]).hexdigest()[:12], 'ramdisk', hashlib.sha256(d[r:r+rs]).hexdigest()[:12])
PY
strings build/<tree>/arch/arm64/boot/Image | grep -m1 '^Linux version 7'   # ③ 与设备 uname -r 逐字比
```

**恢复**：设备进 fastboot 后 `fastboot flash boot out/boot-elden-vk181-daily.img` + `fastboot reboot`
（该镜像 = 已知可用；`fastboot fetch` 本机 ABL **不支持**，无法在线备份 boot_b）。
