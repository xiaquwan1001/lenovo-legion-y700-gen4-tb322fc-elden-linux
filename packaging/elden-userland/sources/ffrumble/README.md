# ffrumble — 无源二进制的重建规格与 ABI 对齐（T14a，2026-10-26）

## 状态

- 设备二进制 `/usr/local/bin/ffrumble`（775 544 B，静态 musl，**原源码从未入库**）。
- **最小 C 重写已完成**：`scripts/ffrumble.c`（2026-10-25，MIT），构建脚本
  `scripts/build-ffrumble.sh`，产物 `out/ffrumble/ffrumble`（aarch64 静态）。
  `sources.tsv` 该行已 `status=ok`。本目录是行为规格 + 可复跑的 ABI 对齐检查，
  不再重复放一份源码（SSOT 在 `scripts/ffrumble.c`）。

## 行为规格（与原二进制逐字对齐）

```
ffrumble [dev] [ms] [magnitude]
  dev        默认 /dev/input/event2
  ms         默认 600；十进制解析（原二进制 atoi ⇒ "0x2000" 解析成 0，重写版刻意保持一致）
  magnitude  默认 0xffff；0..0xffff，支持 0x 前缀（strtol base 0）
```

流程：`open(O_RDWR)` → `EVIOCGBIT(EV_FF)` 确认支持 → `EVIOCSFF` 上传
`FF_RUMBLE`（weak/rumble 幅度均 = magnitude）→ `write(EV_FF, id, 1)` 起振 →
sleep ms → `write(EV_FF, id, 0)` 停 → `EVIOCRMFF` 释放。
输出行：`rumble ON id=%d dev=%s mag=0x%x %dms`。

## 接口对齐检查（可复跑）

```bash
bash packaging/elden-userland/sources/ffrumble/check-abi.sh /usr/local/bin/ffrumble   # 设备原件
bash packaging/elden-userland/sources/ffrumble/check-abi.sh out/ffrumble/ffrumble     # 重写产物
```

## 反汇编要点（原件核对用，aarch64-objdump）

1. `main` 前段只有一个 `atoi`（ms）与一个 `strtol`（magnitude，base 0）——
   两个解析基址不同，这是重写版刻意保留的"怪癖"（防 0x2000 变 8192 ms 长振）。
2. 三个 `ioctl` 常数依次 = `EVIOCGBIT(0x15)`、`0x40302a0c`（EVIOCSFF）、
   `0x40042a0e`（EVIOCRMFF）；两次 `write` 的 payload 均为
   `{type=0x15 /*EV_FF*/, code=<effect id>, value=1|0}`。
3. 无 NEEDED 动态依赖（静态 musl），无 `fork`/`daemon`——单次前台执行。

## 上机 A/B 实测（2026-10-25，vk152）

`ffrumble /dev/input/event2 900 0xffff`：原件与重写版均触发
`aw86927_haptics_play` 2/2（dmesg 取证），见 sources.tsv 行注。
