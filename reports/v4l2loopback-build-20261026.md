# v4l2loopback 0.15.4 为 vk163 构建（C5/U7 相机预览解锁件）

> 2026-10-26 · 主机侧 · 承接 `reports/android-compat-20261026.md` §3（C5/U7 卡点 = 当前 UTS 无 `v4l2loopback.ko`）
> 结果：**已构建且 vermagic 与在机 vk163 逐字一致**，待设备恢复后部署即可。

## 结论

- 源码：`build/extmod/v4l2loopback`（github `v4l2loopback/v4l2loopback`，shallow clone，版本 0.15.4）。
- 构建：`KDIR=build/vk151`（7.3 日常线 @ `24223e4`），`ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LD=ld.lld modules`。
- **vermagic 逐字匹配**（关键）：目标 UTS = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk163`。
  构建树 `.config` 里 `CONFIG_LOCALVERSION` 是 `-debug-vk127-…-dirty`，env `LOCALVERSION` 被 Kbuild 覆盖，
  且源码树脏会追加 `+` ⇒ 常规 `make M=` 得到的 vermagic 带 `+`（设备拒载）。
  可复现做法：**临时**把 `include/config/kernel.release` 与 `include/generated/utsrelease.h` 写成目标 UTS →
  `make M=<src> clean modules` → 立即恢复两个生成文件（本次已恢复，`cmp` 无差异）。
- 产物：`out/extmod-vk163/v4l2loopback.ko`
  sha256 `adb1abe4ec1971dea11b3949ef76a663e16ce8024b695f90618981641bb50a16`
  （vermagic 已核；0 warning）。**注意**：早期副本 `778697…` 是「未改写 kernel.release 前」的构建，vermagic 带 `+`，设备拒载；以 `adb1abe4…` 为准。

## 设备部署（2026-10-26 17:5x 已实测通过）

```bash
ssh root@192.168.7.1 'mkdir -p /lib/modules/$(uname -r)/extra'
scp out/extmod-vk163/v4l2loopback.ko root@192.168.7.1:/lib/modules/$(ssh root@192.168.7.1 uname -r)/extra/
ssh root@192.168.7.1 'depmod -a && modprobe v4l2loopback exclusive_caps=1 video_nr=100 && ls -l /dev/video100'
```

判据：`/dev/video100` 出现；随后按 `scripts/cam-loopback.sh` 起 libcamera 软 ISP 生产者，再跑容器相机 App。
若 vk163 已刷 `boot_b`，此模块随 `/lib/modules/<UTS>/extra/` 持久（不在 initramfs 内，root 起来后 `modprobe` 即可）。

## 回退

删除 `/lib/modules/<UTS>/extra/v4l2loopback.ko` + `depmod -a`；`cam-loopback.sh` 自身已对缺失节点报 FAIL（不会静默）。

## 实测结果（2026-10-26，vk163 已在 boot_b）

- 部署路径：`/lib/modules/<UTS>/extra/v4l2loopback.ko`，sha256 `adb1abe4…` 与主机一致。
- `depmod -a` + `modprobe v4l2loopback exclusive_caps=1 video_nr=100` 成功：
  `lsmod` 见 `v4l2loopback 53248 0`，`/dev/video100` 出现，
  `v4l2-ctl --info` = `Driver name: v4l2 loopback / Card type: Dummy video device (0x0064) / Bus info: platform:v4l2loopback-100`。
- 结论：C5/U7 的「节点不存在」卡点已解除；下一步是起 `scripts/cam-loopback.sh` 生产者 + 装相机 APK 实开预览。
