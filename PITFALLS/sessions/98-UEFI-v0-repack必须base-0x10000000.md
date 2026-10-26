# 98 · UEFI 异类载荷 repack v0：`--base` 必须是 0x10000000（0x0 被 ABL 静默不交棒）

- 日期：2026-10-26（上机实测）
- 设备：HA2EXB0E（fastboot），镜像：`reports/artifacts/uefi-visibility-20261026/lenovo-y700g4-{A2,N2}.img`（header v3）

## 现象

| repack | 结果 |
|---|---|
| header v3（原样） | `Booting OKAY [10.1 s]`，设备**留在 fastboot**（`fastboot devices` 仍应答），`slot-unbootable` 不变 ⇒ 载荷未执行 |
| v0，`--base 0x0 --kernel_offset 0x8000`（kernel_addr `0x8000`） | **同上**：`Booting OKAY` 但留在 fastboot，不交棒 |
| v0，`--base 0x10000000 --kernel_offset 0x8000`（kernel_addr `0x10008000`） | **真交棒**：`Booting FAILED (usb_read failed: No such device)`，USB 掉线；载荷死于 UEFI 早期，设备自复位回 **stock Android 槽 a**（`adb devices` 见 HA2EXB0E），`slot-unbootable:b=yes`、`current-slot=a` |

⇒ 「`Booting OKAY` + fastboot 仍应答」= **ABL 没跳**，不是「UEFI 进去了又退出」。
判据等价于 #387：真交棒时 USB 会掉线。

## 根因/规则

- 本机 ABL 对 header v3/v4 不交棒（#387），必须 repack **v0**；
- v0 的 `kernel_addr = base + kernel_offset`，**必须落在 DRAM**（`0x10008000` 可，`0x8000` 不可）。
  2026-10-24 报告里写的 `--base 0x0` 是错的（当时实际生效的应是默认 base `0x10000000`）。
- 用仓库 `scripts/mkbootimg.py` 时显式给 `--base 0x10000000`；用 Mu 的
  `ImageResources/mkbootimg.py` 时默认就是 `0x10000000`，不要再传 `--base 0x0`。

## 复现

```bash
python3 - <<'EOF'
import struct
d=open('reports/artifacts/uefi-visibility-20261026/lenovo-y700g4-A2.img','rb').read()
ks=struct.unpack_from('<I',d,8)[0]
open('/tmp/A2.kernel','wb').write(d[4096:4096+ks])
EOF
python3 build/uefi-woa-prep/repos/7-mu-lenovo/ImageResources/mkbootimg.py \
  --kernel /tmp/A2.kernel --header_version 0 --base 0x10000000 --kernel_offset 0x8000 \
  --pagesize 4096 -o /tmp/A2-v0.img
fastboot boot /tmp/A2-v0.img     # 期望 Booting FAILED (usb_read failed) = 已交棒
```

## 恢复

```bash
# 载荷崩溃后设备回 stock Android 槽 a：
adb reboot bootloader
fastboot set_active b
fastboot reboot          # 回 Linux（f2fs linux18）
```

## 本轮结论（UEFI 可见性）

- A2（BootShim cache 补丁 + 厂商 UFSDxe）**仍死于 UEFI 早期**，没有出现 UEFI 画面 ⇒
  「缺 cache maintenance」不足以解释早期死亡（假说未证实）。
- N2（纯 Mu + cache 补丁）在同一 fastboot 会话里 `Booting OKAY` 未交棒（与 A2 同 header/base，行为却不同）⇒
  ABL 对异类载荷的 handoff 还有未识别条件，**不要把它当稳定判据**；下轮要么加可见性（UART/早显），要么用已知可跑的 tb322fc FD 做对照。
- 结论口径：**UEFI 早期死亡未解**，只新增「v0 + base 0x10000000」这一条硬规则。
