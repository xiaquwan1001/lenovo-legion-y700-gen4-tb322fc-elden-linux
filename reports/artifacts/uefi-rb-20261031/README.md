# uefi-rb-20261031 — UEFI 重打包口径纠正的证据目录（2026-10-31 深夜 → 11-01 上午）

对应报告：`reports/uefi-cleanheader-reframe-20261101.md`；坑：`PITFALLS #479/#480`。

| 子目录 | 内容 | 复现命令 |
|---|---|---|
| `a2-replay/` | **同源重建 A2**：`SM8750_EFI.fd`（`088d99fe…`，与 10-24 原件 `eb00db73…` 只差 6 字节时间串）+ `uefi-v0.img` + `manifest.txt` + `build.log.gz` | `scripts/uefi-build-variant.sh <out> --ufsdxe vendor --rmvmdxe mu --shim cachefix --clean` |
| `repack/` | 同一载荷、不同 v0 header 的对照：`N2-repack-v0.img`（接受）/ `N2-repack-with-oldid-v0.img`（接受，旧 id）/ `C10-oldheader-newgz-v0.img`（= `N2-v0b.img` 原件，sha `90659a4d…`，拒绝）/ `X1-repack-v0.img`（接受）/ `R2-repack-v0.img`（PrePi 红条 FD，接受） | `python3 build/uefi-woa-prep/repos/7-mu-lenovo/ImageResources/mkbootimg.py --kernel <gz> --header_version 0 --base 0x10000000 --kernel_offset 0x8000 --pagesize 4096 -o <out>` |
| `entryspin/` | A2/X1 的 FD 把 PrePi 入口 `0x8c68` 改成 `b .` 后打包（证明 ABL 会跳到该入口） | 见报告 §1 #4 |
| `abortshims/` | 80 B 自写 shim：`shim-brk`（`brk #1`）/ `shim-spin`（`b .`）+ 源码 `.S` + v0 镜像 | `clang --target=aarch64-linux-gnu -c shim-<k>.S -o s.elf && llvm-objcopy -O binary s.elf s.bin` |
| `../uefi-boot-20261101-*/` | 每发上机的现场：`run.log`、`usb-watch.txt`（1 Hz USB + 3 s `getvar` 活性）、`boot.txt`、`fastboot-pre.txt`、`ssh-{pre,post}.txt`、`abl-log.txt`（解析后的 `UEFILOG1.TXT`；原始 `logfs.img` 未入库，脚本会现取） | `scripts/uefi-boot-trial.sh --image <img> --label <L>` |
