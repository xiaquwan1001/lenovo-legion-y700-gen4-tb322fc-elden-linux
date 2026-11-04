# pakaging/elden-userland/build — 7 个 ELF 的宿主侧重建配方（T14 收尾，2026-11-04）

> 目的：把「`sources.tsv` 说可重建」变成「**任何人一条命令就能演练、并有门禁数字**」。
> 真相仍在 `scripts/build-*.sh` / `scripts/host-arm64-chroot.sh`（本目录是统一入口 + `--dry-run`），
> 逐 ELF 的映射在 `artifacts.tsv`，机器检查在 `tools/verify.sh --rebuildable`。

## 用法

```bash
bash packaging/elden-userland/build/all.sh                 # 全部 dry-run（只打印命令，零写盘）
bash packaging/elden-userland/build/all.sh --apply         # 真跑（root 配方需 sudo）
bash packaging/elden-userland/build/ffrumble.sh --dry-run  # 单个配方
bash packaging/elden-userland/tools/verify.sh --rebuildable # 门禁：ok/missing + 配方可演练
bash packaging/elden-userland/tools/verify.sh --rebuild     # 门禁：真编 4 个静态件并比 sha
```

`--dry-run` 的硬承诺：**不建目录、不编译、不 chroot、不写系统**；`run()` 只打印以 `+` 开头的命令。

## 7 个 ELF 的重建矩阵（2026-11-04 实测）

| ELF | 源 | 配方 | 产物 | 与清单 sha |
|---|---|---|---|---|
| `elden-hapticd` | `scripts/elden-hapticd.c` | `elden-hapticd.sh` → `scripts/build-hapticd.sh` | `out/hapticd/` | **identical**（aca55cb1…） |
| `eldroid-sensord` | `scripts/eldroid-sensord.c` | `eldroid-sensord.sh` → `scripts/build-sensord.sh` | `out/sensord/` | diff（设备件 musl 静态 / 宿主 glibc 静态） |
| `ffrumble` | `scripts/ffrumble.c`（2026-10-25 重写） | `ffrumble.sh` → `scripts/build-ffrumble.sh` | `out/ffrumble/` | diff（同上；已上机 A/B 同调用次数） |
| `waydroid-sensord` | `patches-userland/waydroid-sensord-udp/` | `waydroid-sensord.sh`（chroot make） | `out/sensord-host/` | **identical**（22028ffd…） |
| `waydroid-sensord-udp` | 同上（同一产物两个文件名） | `waydroid-sensord-udp.sh` | `out/sensord-host/` | **identical**（22028ffd…） |
| `elden-ime-focusd` | `patches-userland/zh-ime/elden-ime-focusd.c` | `elden-ime-focusd.sh`（chroot） | `out/ime-host/` | diff（产物 `7b8b0b46…`/72 240 B vs 清单 `d2304827…`/74 392 B；sources.tsv 注明是同一 recipe 的另一版） |
| `reboot2` | `rootfs/reboot2.c` | `reboot2.sh` | `out/reboot2/` | diff（重建 `ef12c5ba…`/597 920 B vs 清单 `0c68ee5f…`/709 368 B；原 sources.tsv 那行是裸命令、产物落 /tmp 且未 strip，本轮固化为仓库内产物） |

## musl / glibc 取舍（唯一需要判断的地方）

`waydroid-sensord(-udp)` 与 `elden-ime-focusd` 都是**动态链接**件，interpreter 决定它能跑在哪种根上：

- **glibc 版（默认，本机已验证）**：`/lib/ld-linux-aarch64.so.1` ⇒ Debian/Mobian 根。
  构建 = arm64 Debian sid chroot（`/opt/elden/arm64-sid`），`scripts/host-arm64-chroot.sh` 建立；
  产物与 MANIFEST **逐字一致**。代价：需要 root（本机 `kernel.apparmor_restrict_unprivileged_userns=1`，
  `unshare -r chroot` 不可用）+ 首次 debootstrap ~10 min。
- **musl 版（备选，本机无 chroot ⇒ 未证）**：`/lib/ld-musl-aarch64.so.1` ⇒ Alpine 根。
  同一份源码在 Alpine aarch64 chroot 内 `make`（`apk add build-base pkgconf g++ gbinder-dev glib-util-dev glib-dev`）。
- **为什么必须两套都能出**：Waydroid 只按**文件存在**判定「宿主有 HAL」，换根后 musl 件会
  `exec` ENOENT 而报错文案不提 loader ⇒ Android 卡 bootanimation（PITFALLS #431、
  `scripts/deploy-sensord-routec-debian.sh` 头部注释）。
- **不做的方案**：静态链接 / musl-cross-make —— 上游 `Makefile` 依赖 `pkg-config` 找
  gbinder/glibutil 的 `.pc`，静态交叉链没有对应的 `.pc`；改 Makefile 超出本任务范围。
