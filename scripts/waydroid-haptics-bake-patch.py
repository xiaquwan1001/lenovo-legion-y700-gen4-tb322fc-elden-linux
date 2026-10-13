#!/usr/bin/env python3
"""waydroid-haptics-bake-patch.py — 幂等打「马达透传固化」的产品配置补丁（TASKS C10 三期）

把 patches-userland/ 的源码同步进 waydroid-build 树，并改产品配置：
  1) hardware/waydroid/vibrator-aidl      <- patches-userland/waydroid-haptics-aidl
  2) hardware/waydroid/vibration-overlay  <- patches-userland/elden-vibration-overlay
  3) device.mk：HIDL vibrator 包 -> android.hardware.vibrator-service.elden + EldenVibrationOverlay
  4) manifest.xml：删掉 HIDL vibrator 的 <hal> 块（否则「声明了但没人提供」）
每次改动前写 .bak-elden-haptics（已存在则不覆盖）。可反复执行。
"""
import os
import shutil
import sys

WB = os.environ.get('WB', '/mnt/Samsung/waydroid-build')
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def sync(src, dst):
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    print('  sync', dst)


def backup(path):
    bak = path + '.bak-elden-haptics'
    if not os.path.exists(bak):
        shutil.copy2(path, bak)


def patch_device_mk(path):
    s = open(path, encoding='utf-8').read()
    if 'android.hardware.vibrator@1.0-service.waydroid' not in s:
        print('  device.mk: 已是自编模块（跳过）')
        return
    backup(path)
    s = s.replace('    android.hardware.vibrator@1.0-service.waydroid',
                  '    android.hardware.vibrator-service.elden \\\n    EldenVibrationOverlay',
                  1)
    open(path, 'w', encoding='utf-8').write(s)
    print('  device.mk: HIDL vibrator -> elden AIDL HAL + RRO')


def patch_manifest(path):
    lines = open(path, encoding='utf-8').read().split(chr(10))
    out, i, removed = [], 0, 0
    while i < len(lines):
        if lines[i].strip().startswith('<hal') and any(
                'android.hardware.vibrator' in l for l in lines[i:i + 8]):
            while i < len(lines) and '</hal>' not in lines[i]:
                i += 1
            i += 1
            removed += 1
            continue
        out.append(lines[i])
        i += 1
    if removed:
        backup(path)
        open(path, 'w', encoding='utf-8').write(chr(10).join(out))
    print('  manifest.xml: removed hal blocks =', removed)


def main():
    os.makedirs(os.path.join(WB, 'hardware/waydroid'), exist_ok=True)
    sync(os.path.join(REPO, 'patches-userland/waydroid-haptics-aidl'),
         os.path.join(WB, 'hardware/waydroid/vibrator-aidl'))
    sync(os.path.join(REPO, 'patches-userland/elden-vibration-overlay'),
         os.path.join(WB, 'hardware/waydroid/vibration-overlay'))
    patch_device_mk(os.path.join(WB, 'device/waydroid/waydroid/device.mk'))
    patch_manifest(os.path.join(WB, 'device/waydroid/waydroid/manifest.xml'))
    print('bake-patch done')


if __name__ == '__main__':
    main()
