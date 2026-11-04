# HANDOFF · 2026-11-04 收尾 —— UEFI 线：`continue` 已能进 BootLinux，卡在随机同步异常

> 上一轮入口：`.pi/plans/2026-11-04_handoff-uefi-dxe-to-linux.md`（DXE→BDS 之后无 ESP）。
> 本轮证据正文：`reports/uefi-noavb-dtbo-bootchain-20261104R.md`。
> 新坑：`PITFALLS/sessions/162-UEFI进DXE之后的取证纪律.md` #506–#508。

## 0. 一句话状态

`fastboot continue` 不再报 `Load Error`（dtbo 32 MiB 的坑已修），流程进入 `BootLinux`，
随后在 DXE heap 里出现 `Synchronous Exception at 0xCFE99xxx` + 递归打印，**且随机复现**
（同一镜像有时不崩）。内核加载区是 `0xA8080000`，异常地址不在内核区 ⇒ 尚未真正交接给内核。

## 1. 本轮确立的结论（不要重复踩）

| # | 结论 | 依据 |
|---|---|---|
| 1 | 这棵树 `GetAVBVersion()` 恒 `NO_AVB`（`VERIFIED_BOOT*/_LE` 全 0），`LoadImageAndAuthVB2` 整段被编译掉 | `llvm-dis` 后 `ret i32 0`；`llvm-nm` 无 VB2 符号 |
| 2 | R7 把 `gST->ConOut->OutputString` 换成 no-op ⇒ **AsciiPrint/DEBUG 一律不可见**，探针只能 `SerialPortWrite` | `patches/uefi/20261104R7-loadmap`；R15 起全部改写 |
| 3 | `dtbo_b` = 32 MiB > `DTBO_MAX_SIZE_ALLOWED`(24 MiB) 且内容全 0 ⇒ `EFI_LOAD_ERROR`（continue/boot 都中） | `fastboot getvar partition-size:dtbo_b`；Linux 侧 `od` 全 0 |
| 4 | 修法：先读一页表头；magic 不合法 ⇒ `EFI_NO_MEDIA`（当无 overlay）；合法按 `total_size` 装载且缓冲区按 4 KiB 取整 | `patches/uefi/20261104R{16,17}` |
| 5 | NV 变量取证不可用（`[S] prev` 未出现），改用 cmdline `sbstop=N` 宿主可编程停机点 | R19/R20 |
| 6 | 崩溃**随机**（同镜像有时复现）⇒ 二分类实验每档要重复多次 | 用户实测 |

## 2. 下一轮第一步（照做即可）

```bash
# 1) 造测试件：R20 镜像 + 注入 cmdline 令牌
cd /home/xuqianhui/y700-elden
python3 - <<'PY'
src="out/uefi-20261104R20-stage-bisect-r1.img"
for n in (1,2,3,4,5,6):
    d=bytearray(open(src,'rb').read())
    tok=("sbstop=%d " % n).encode()
    d[64:64+len(tok)]=tok          # v2 header: cmdline 字段在 offset 64
    open("out/r20-stop%d.img"%n,'wb').write(d)
PY

# 2) 上机：ABL fastboot → 载 UEFI
fastboot boot out/uefi-20261104R20-stage-bisect-r1.img
# 3) UEFI 侧 fastboot（序列号 51318dc0）里跑内存镜像路径
fastboot -s 51318dc0 boot out/r20-stop5.img
#   判据：回 "…: Aborted" ⇒ 到达第 5 阶段；USB 掉线（usb_read failed）⇒ 崩在第 5 阶段之前
```

推荐二分顺序：5 → 3 → 4 → 2（每档重复 3 次，注意随机性；`sbstop=7` 会主动停机，别先用）。

## 3. 关键地址

- `Kernel` 区：`0xA8000000 + 0x10000000`，`KernelLoadAddr = 0xA8080000`；
- `DXE Heap`：`0xB90C0000 + 0x1D500000`（`PlatformMemoryMapLib.c`）——异常地址 0xCFE99xxx 落在这里；
- LinuxLoader 载入：`0xCFEB5000`（R19）/`0xCFEB6000`（R17），size `0x45000`。

## 4. 备选路线（若老路继续随机崩）

- 方案 A（原始 handoff 建议）：arm64 GRUB / 自写 loader 直接 `LoadImage` 启动 Linux，绕开
  `BootLinux` 的 Android 语义（dtbo/vendor_boot/AVB）；
- 也可先做「内核直接搬运」实验：把内核 Image + DTB 预置在 UEFI FD 里，BDS 里 `LoadImage`
  （EFI stub）启动，验证 UEFI→Linux 交接本身是否可行。

## 5. 设备状态

- 最后一次实验后设备停在异常死循环；长按电源重启即回 ABL fastboot（`HA2EXB0E`），
  `fastboot continue` 可正常回 Linux（`boot_b` 全程未写，sha256 `fb55997c…`）。
