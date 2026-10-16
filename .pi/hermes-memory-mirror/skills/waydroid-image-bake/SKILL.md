---
name: "waydroid-image-bake"
description: "Waydroid 容器侧改动「固化进镜像」而不是运行时 bind 挂载：改 waydroid-build 产品配置（HAL 模块/RRO）→ m vendorimage → 原子替换 /var/lib/waydroid/images/vendor.img → 验证与回退；含 vendor.img 100% 满的坑、Settings 强度档位要靠静态 RRO、产品 Soong namespace。触发词：Waydroid 改动固化、vendor.img 重建、vendorimage、镜像是满的 ENOSPC、Settings 不显示振动强度、静态 RRO、overlay 放到 /vendor/overlay、刷 vendor.img 回退。"
version: 1
created: "2026-10-13"
updated: "2026-10-13"
---
## When to Use
当某容器侧改动（自编 HAL / 资源覆盖 / init 服务 / 新增二进制）不能停在运行时 bind 挂载、需要「刷一次就长期有效」时。

## Procedure
1. 源码放仓库（如 patches-userland/...），再同步进 waydroid-build 树；写一个幂等的 patch 脚本（本仓 scripts/waydroid-haptics-bake-patch.py 可参考）来同步 + 改产品配置。
2. 产品配置：在 device/waydroid/waydroid/device.mk 的 PRODUCT_PACKAGES 增删模块；模块目录必须落在产品 Soong namespace 允许的路径（hardware/waydroid/* 可用；vendor/extra/* 会被拒）；RRO 用 runtime_resource_overlay + vendor: true 装到 /vendor/overlay。
3. 换掉某个 HAL 时同步改 device/waydroid/waydroid/manifest.xml（删掉旧 HIDL <hal> 块），否则「声明了但没人提供服务」。
4. cd waydroid-build && source build/envsetup.sh && lunch lineage_waydroid_arm64_only-userdebug && m vendorimage（增量通常几分钟）。
5. 部署：停容器（kill waydroid daemons + lxc-stop）→ scp 到 *.new → mv 原子替换 /var/lib/waydroid/images/vendor.img（先备份旧镜像）→ 起容器 → 验证。
6. 验证铁证：ls -l /proc/$(pidof <hal>)/exe 指向 /vendor/bin/hw/<自编名>；grep -c <名> /proc/mounts = 0（不依赖 bind）。RRO 则 cmd overlay list 看 [x] + cmd overlay lookup <target> <resid> 看生效值。

## Pitfalls
- vendor.img 是「按内容自动裁」的紧凑 ext4（无 BOARD_VENDORIMAGE_PARTITION_SIZE），通常 100% 满：不要原位塞文件——`install` 会先把目标截断成 0 字节再 ENOSPC（能把镜像里的二进制弄成 0 字节，靠 bind 挂载掩盖）。要加内容就重建镜像，或先 truncate+resize2fs。
- Settings（及系统 UI）的开关/档位常由「应用自己的资源」决定，与 HAL 能力无关；先 grep 资源名和默认值，再用静态 RRO 覆盖，验证查 cmd overlay lookup 的实际值。
- 静态 RRO 必须 android:isStatic="true" 且落在系统分区（/vendor/overlay 等）才会开机自动启用。
- 替换 vendor.img 属于「当前可用系统」的一部分：先备份镜像（cp 一份带时间戳），部署用 .new + mv 原子替换，失败即时回退。
- 改完镜像要全量重启容器（servicemanager/init 都在启动时读 manifest/rc）。

## Verification
1. cmd overlay list | grep <pkg> → [x]；cmd overlay lookup <target-pkg> <target-pkg>:integer/<res> → 期望值
2. dumpsys <service> 能力位仍符合预期（如 vibrator: mCapabilities/mSupportedEffects）
3. ls -l /proc/<hal pid>/exe + grep -c <hal> /proc/mounts = 0
4. 功能回归：一次短振/一次长振+取消，看 daemon 日志与 logcat