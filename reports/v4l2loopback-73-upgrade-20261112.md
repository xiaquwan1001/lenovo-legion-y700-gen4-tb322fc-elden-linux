# v4l2loopback 升级到 7.3.1（vk184）兼容 — 报告 2026-11-12

## §0 结论

**任务完成**。最终判据达成：

- 设备 vk184（U2，7.3.1-debug-vk184-00002-g4da9a8b69fc8）上 `modprobe v4l2loopback exclusive_caps=1 video_nr=100 max_buffers=8` 成功：
  - `lsmod`：`v4l2loopback 53248 0`，且已挂进 videodev 引用链；
  - `/dev/video100` 存在：`crw------- 1 root root 81, 49 /dev/video100`；
  - dmesg：`v4l2-loopback driver version 0.15.4 loaded`，**无任何 WARN**；
  - 参数确认：exclusive_caps=Y、max_buffers=8、video_nr=100。
- 产物已正式部署 `/lib/modules/<UTS>/extra/v4l2loopback.ko` + `depmod -a`；副本存 `out/extmod-7.3.1/v4l2loopback.ko`。

**根因（本任务最重要发现）**：之前的 EFAULT/WARN-929 失败**与 v4l2loopback 版本无关**。是
`build/daily` 的 `.config` 在 vk189-suspend 工作中被改动（SUSPEND/PM_SLEEP/VIRT_DRIVERS/SYSFB_SIMPLEFB 等），
导致 `struct video_device` 布局相对设备上在跑的 videodev 漂移 **56 字节**：
- 设备 videodev（/lib/modules 里那份，sha256 08122191…）：`v4l2_dev` 偏移 **928**（反汇编 +0xe48 路径证实）；
- build/daily 现编产物（sha256 6a3d128a…，11-12 19:27 重编）：`v4l2_dev` 偏移 **984**（DWARF 证实）。
模块按新头文件把 `vdev->v4l2_dev` 写到 984，内核 videodev 在 928 读 → NULL →
`v4l2-dev.c:929 WARN_ON(!vdev->v4l2_dev)` → `video_register_device()` 返回非 0 → insmod 报 "Bad address"(EFAULT)。
旧版 e27cd86 与最新 0.15.4 **都**因此炸；把 build/daily 临时切回设备 /proc/config.gz 后两者都能加载。

**版本选择**：采用上游最新 **v0.15.4**（commit 0f9ee86 "Released 0.15.4"，含 6.15+ 内核适配 #626 等修复），
项目补丁 0001（min-4-buffers）/0002（MJPEG depth 16）成功重打。

## §1 失败取证（升级前）

```
# 设备 dmesg（新旧两版 ko 完全相同）
WARNING: drivers/media/v4l2-core/v4l2-dev.c:929 at __video_register_device+0xe48/0x14b0 [videodev]
pc : __video_register_device+0xe48/0x14b0 [videodev]
lr : v4l2_loopback_add+0x6f8/0x8a0 [v4l2loopback]
x19: ffff000886e16000 (vdev)   x20/x21: 0x64 (=video_nr 100)
x0 : 0x00000000ffffffff (= vdev->minor = -1，刚被函数开头赋值)
v4l2-loopback add() failed video_register_device()
```

- 旧树 e27cd86 编的 ko 上机：同样 WARN 929（排除了"源太老"假设）。
- 反汇编 `build/daily/drivers/media/v4l2-core/videodev.o`：`+0xe48` 路径 = `ldr x2,[x19,#984]; cbz x2 → __warn`；
  DWARF：`video_device.v4l2_dev @ 984`、`.release @ 1152`、`.minor @ 1096`。即 929 行 `!v4l2_dev` 真触发。
- 反汇编**设备上**的 videodev.ko（scp 到 /tmp/dev-videodev.ko）：同一位置是
  `str w0,[x19,#1040]`（minor=-1）、`ldr x0,[x19,#1096]`（release）、`ldr x2,[x19,#928]`（v4l2_dev）→
  设备版布局比 build/daily 小 56 字节。
- `sha256sum`：设备 `/lib/modules/.../videodev.ko` = 08122191… ≠ build/daily = 6a3d128a…。
- `zcat /proc/config.gz` vs `build/daily/.config`：38 行差异（vk189-suspend 改的
  CONFIG_SUSPEND/PM_SLEEP/FW_CACHE/VIRT_DRIVERS/SYSFB_SIMPLEFB/DRM_EFIDRM 等）。
- 排除项维持：minor 用尽（video0..16 仅 17 个，试过 40/100）、vfl_dir 改动（已回滚）均非原因。

## §2 新版本选择

- 上游 tag 列表 `git ls-remote --tags` 最新 = **v0.15.4**（0.15.0→0.15.4 系列，ChangeLog 含
  "added functionality for linux 6.15+ (#626)"、"only use timer_delete_sync compat macro for linux<6.2.0" 等 6.x 兼容修复）。
- clone 至 `build/extmod/v4l2loopback-new`（depth 1, branch v0.15.4，未动旧树 `build/extmod/v4l2loopback`）。
- 复核：0.15.4 同样在 `v4l2_loopback_add` 里 `v4l2_device_register()` + `dev->vdev->v4l2_dev = &dev->v4l2_dev`，
  逻辑与旧版等价 —— 证实 WARN 与版本无关。

## §3 补丁与构建

补丁（`patches/extmod/`）：
- **0001-v4l2loopback-min-4-buffers.patch**：直接适用（`vidioc_reqbufs` 的 `req_count > dev->buffer_count` 上限逻辑在 0.15.4 原样存在，补丁插在其后）。上游无等价逻辑（0.15.4 仍是"共享设备级 buffer 数、写端决定"）。
- **0002-v4l2loopback-mjpeg-sizeimage-2bytes.patch**：适用（两处 hunk 偏移 -3 行成功；0.15.4 仍 depth=32）。

构建（scripts/deploy-v4l2loopback.sh 同款临时 vermagic 手法 + **config 切换**）：
```bash
# 1) 临时切 build/daily 到设备 config（根因修复）
cp build/daily/.config /tmp/.v4l2-config.bak
ssh root@192.168.7.1 'zcat /proc/config.gz' > /tmp/dev-config
cp /tmp/dev-config build/daily/.config
make -C build/daily ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig prepare
# 2) 临时 vermagic（kernel.release + utsrelease.h → 设备 UTS），编完恢复
make -C build/daily M=$PWD/build/extmod/v4l2loopback-new ARCH=arm64 \
     CROSS_COMPILE=aarch64-linux-gnu- LD=ld.lld modules -j26
# 3) 恢复 build/daily：.config 还原 + olddefconfig + prepare（已验证 CONFIG_SUSPEND=y 等回齐）
modinfo out/extmod-7.3.1/v4l2loopback.ko | grep vermagic
# → 7.3.1-debug-vk184-00002-g4da9a8b69fc8 SMP preempt mod_unload aarch64
```

**改动/新增文件清单**：
- 新增 `build/extmod/v4l2loopback-new/`（上游 v0.15.4 clone + 0001/0002 补丁 + 编译产物）；
- 新增 `out/extmod-7.3.1/v4l2loopback.ko`（正式产物副本）；
- 临时改过又**已还原**：`build/daily/.config`、`build/daily/include/config/kernel.release`、
  `include/generated/utsrelease.h`、`include/generated/autoconf.h`/`include/config/*`（prepare 重生成，已按 vk189 config 恢复并验证）；
- **未改**：scripts/（deploy-v4l2loopback.sh 未动）、patches/（原样重用）、旧树 build/extmod/v4l2loopback、设备 boot 相关。

## §4 上机判据（vk184 实测，全部通过）

```
# /tmp insmod 冒烟
insmod /tmp/v4l2-new.ko exclusive_caps=1 video_nr=100 max_buffers=8 → rc=0
lsmod → v4l2loopback 53248 0
ls -l /dev/video100 → crw------- root root 81, 49
dmesg → v4l2-loopback driver version 0.15.4 loaded（无 WARN）

# 正式部署（先 modprobe -r 清掉 /tmp 实例）
cp ko → /lib/modules/7.3.1-debug-vk184-00002-g4da9a8b69fc8/extra/ ; depmod -a
modprobe v4l2loopback exclusive_caps=1 video_nr=100 max_buffers=8 → 成功
/sys/module/v4l2loopback/parameters/exclusive_caps → Y
/sys/module/v4l2loopback/parameters/max_buffers    → 8
/sys/module/v4l2loopback/parameters/video_nr       → 100,-1,-1,...
```
- 既有 /dev/video0..16 未受影响（v4l2loopback 是独立 minor，未触碰）。
- 相机生产者配方不变：`bash scripts/cam-loopback.sh start front 1280x720 30`（NV12、写端 gst）。
- ⚠ 遗留注意：**vk189-suspend config 与设备 config 不一致**的问题仍存在——未来任何按 build/daily 现配置编、
  却在 vk184 上跑的模块都可能踩同一布局漂移；换新内核镜像部署后此 ko 需重编（vermagic/布局随内核走）。

## §5 回滚方式

1. 设备：`modprobe -r v4l2loopback && rm /lib/modules/<UTS>/extra/v4l2loopback.ko && depmod -a`
   （若被占用：先 `pkill gst-launch`/停容器相机，见脚本内注释）。
2. 主机：产物在 `out/extmod-7.3.1/`，删目录即可；`build/extmod/v4l2loopback-new/` 删目录即可；
   旧树 `build/extmod/v4l2loopback` 与旧 ko `out/extmod-vk172/` 均未动，可直接走原 deploy 脚本回退。
3. build/daily 的 config/generated 已恢复为 vk189-suspend 状态（`diff /tmp/.v4l2-config.bak .config` = 空，
   `include/config/auto.conf` 含 CONFIG_SUSPEND=y / CONFIG_VIRT_DRIVERS=y），备份在 `/tmp/.v4l2-config.bak`、`/tmp/.v4l2-rel.bak`、`/tmp/.v4l2-uts.bak`。
