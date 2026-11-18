## #676 `proot` + `fakeroot` 不能用来造 Debian rootfs（`signal 11` + `libfakeroot payload not recognized`，6 连败）⇒ `sudo` 真 root + 注册 `qemu-aarch64`

**现象（2026-11-17 夜 → 11-18 早）**：`rootfs-minbase-build.sh` 走 `proot`+`fakeroot` 做 debootstrap second stage，
在 `base-passwd` 处 **signal 11** 崩，或 `libfakeroot: payload not recognized`；**连试 6 次全挂**，
会话被断电打断 ⇒ 一度被记成"网络/断电问题"（这是误判）。

**判据**：`proot` 只做路径重写、不做 ptrace 权限模型，`fakeroot` 的 `LD_PRELOAD` 在 aarch64 交叉 + 多层 proot 下拿不到正确 payload；
`signal 11` 出现在 `base-passwd` 这种纯文件操作用户态工具上 ⇒ **先怀疑执行环境，不要怀疑包**。

**正解**（实测 ~15 min 一次过）：

```sh
sudo apt install -y qemu-user-static binfmt-support      # 或 Arch: qemu-user-static-binfmt
sudo systemctl restart systemd-binfmt
cat /proc/sys/fs/binfmt_misc/qemu-aarch64                # 必须 enabled，interpreter 指向 qemu-aarch64-static
sudo bash scripts/rootfs-minbase-build.sh --out out/p2-minbase-.../rootfs-minbase....ext4.img
```

**顺带修掉的两个真坑**（同源"判据写死"）：

- 门禁取样模块名写死 `ath12k.ko`，而该内核里 ath12k 是 **built-in** ⇒ 门禁恒报缺；取样应「按 `modules.builtin` + `modules.dep` 判定」。
  同族：`PITFALLS #667`（看门狗只认 `card0`）。
- stage 目录里的 `build` **符号链接指到主机路径**，打进镜像后在设备上是一条死链；打镜像前必须 `find -type l -lname '/*'` 复查。

**推广**：凡是"在主机上模拟另一架构的 root"的构建，先花 2 分钟证明**执行器本身能跑一个最简单的包**
（`chroot . /bin/echo hi`、`apt-get download` 单包），跑不通就换真 root/chroot——不要用 6 次失败换同一个结论。

证据：`TASKS/sessions/2026-11-18-A6最小根镜像与P2前置件.md`；脚本 `scripts/rootfs-minbase-build.sh`、`rootfs/debian/build-rootfs.sh`（最小档旋钮）。
