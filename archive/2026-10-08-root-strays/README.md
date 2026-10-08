# 根目录散件归档（2026-10-08）

复核根目录纪律（=6 维护文档 + `AGENTS.md`，`INDEX.md` §2）时清出的**游离 rootfs 暂存树**。

## 内容与判定

根目录出现 `bin/ boot/ etc/ lib/ root/ sbin/ usr/ var/ init`（合计 ~178 MB，1678 文件），是**Alpine rootfs 暂存树的重复副本**：

- 与权威暂存目录 `rootfs/alpine/`（`rootfs/build-rootfs.sh` 的 `$R/alpine`，被 `.gitignore` 排除）**逐文件一致**（1678=1678），唯一差异：
  - 根目录版有 `lib/firmware/qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin`（md5 `8834f23234d53ee6c942c0915ce06352`）
  - `rootfs/alpine` 版为压缩态 `.zst`（md5 `652c44de7cb7f1214a647bc9b7e2de80`）
- 该 tplg 源产物另存于 `scripts/audio-tplg/out/Lenovo-Y700-Gen4-tplg.bin`（同 md5），**无独有内容丢失**。
- 未跟踪（`git ls-files` 命中 0）；全仓脚本/hook（`build.sh pack.sh cycle.sh iterate.sh .githooks/* scripts/*.sh`）无引用。

## 处置

删除根目录 9 个路径（`bin boot etc lib root sbin usr var init`）。内容可由 `rootfs/alpine` + `scripts/audio-tplg/build.sh` 重建。

## 身份证据（删除时点）

```
bin/busybox                     md5 10c6f0fedb03a0277410a76d0074cfe9  (= rootfs/alpine 同路径)
init                            md5 dfc277158b12099c835617d2906d5157  (= rootfs/alpine/init)
boot/elden.dtb                  md5 db4149e03b643224033f107161a54a02  (= rootfs/alpine/boot/elden.dtb)
etc/alpine-release              3.24.2
文件计数                        根目录 1678  vs  rootfs/alpine 1678
```

## 追加：空挂载点目录（同批）

同源 rootfs 暂存还留下 11 个**空**目录（0 文件、未跟踪）：`dev/ home/ media/{usb,cdrom,floppy} mnt/ opt/ persist/ proc/ run/lock srv/ sys/ tmp/`。
与 `rootfs/alpine/` 对应目录同源，**无内容**，一并删除。`net/` 有 4 个已跟踪文件，是项目目录，保留。
