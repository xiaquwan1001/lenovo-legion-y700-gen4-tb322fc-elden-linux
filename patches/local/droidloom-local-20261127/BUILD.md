# droidloom 本地 4 patch —— 构建与部署手册（2026-11-27 实测）

> 补丁源：`patches/local/droidloom-local-20261127/00{1..4}-*.patch`（对上 `droidloom-source-0.1.0-51.tar.gz`）。
> 本文只记**怎么把它们变成设备上的二进制并验收**；为什么打、退役判据见各 patch 文件头与 `TASKS/NEXT.md` T2。

## 1. 落地顺序与唯一需要 fuzz 的一贴

```sh
tar xf droidloom-source-0.1.0-51.tar.gz -C ~/elden-cache/build   # → ~/elden-cache/build/droidloom/droidloom
mv ~/elden-cache/build/droidloom ~/elden-cache/build/droidloom-51-src
cd ~/elden-cache/build/droidloom-51-src
patch -p1 --fuzz=0 < .../001-wifi-provisioning-self-healing.patch   # Android Java（要重编镜像，非本机可落地）
patch -p1 --fuzz=0 < .../002-remove-forward-signals.patch
patch -p1 --fuzz=2 < .../003-host-resolvers-in-lease.patch          # ★ 必须在 002 之后、需 fuzz=2
patch -p1 --fuzz=0 < .../004-runuser-sbin-path.patch
```

- **003 单独对未打 002 的树 `--fuzz=0` 会 2/2 hunk 失败**（`development.rs` 380/585 段落被 002 改过）——不是补丁坏了，是顺序+fuzz。落地后复核：`grep -rn 'forward-signals' runtime/` = **仅 1 处注释**；`1.1.1.1/8.8.8.8` 只剩注释/测试字面量。

## 2. 交叉编译（Debian/Ubuntu 主机 → aarch64，**不需要** Arch sysroot 就能编纯 Rust 件）

```sh
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc \
       PKG_CONFIG_ALLOW_CROSS=1 \
       CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc \
       CXX_aarch64_unknown_linux_gnu=aarch64-linux-gnu-g++
cargo build --release --locked --target aarch64-unknown-linux-gnu \
      -p droidloom-supervisor -p droidloomd -p droidloom-package-support -j4
```

- **能编出来的**（纯 Rust，实测 29 s 冷启）：`droidloom-supervisor`、`droidloomd`、`droidloomctl`、`droidloom-doctor`、`droidloom-applications`、`droidloom-package-helper`、`droidloom-update`、`droidloom-gapps`、`droidloom-gpu-gen`。
- **编不出来**（要 Arch ARM sysroot 的 C 库）：`droidloom-wayland`（`-lxkbcommon -lwayland-server`）、以及依赖它的 `droidloom-audio`/`droidloom-devices`/`droidloom-gpu-server`。**这 4 个本轮没动**，仍用 release 51 原件（本组补丁不涉及它们）。
- glibc 门槛实测：`objdump -T` 最高 `GLIBC_2.39` ≤ 设备 `glibc 2.41`（Debian 13）⇒ 可直接用。

## 3. 部署（哪个二进制承接哪一贴）

| 补丁 | 承接二进制 | 设备路径 |
|---|---|---|
| 002 去 `--forward-signals` | **`droidloomd`**（`development.rs` 被 `droidloomd` 主二进制编译进去；只换 `droidloom-supervisor` **不生效**，实测会 `unshare: 未识别的选项`） | `/usr/bin/droidloomd` |
| 003 宿主 resolver 进 lease | `droidloomd`（`development_network.rs` / `dhcp_responder.rs`） | `/usr/bin/droidloomd` |
| 004 `runuser` 路径（Debian 只有 `/usr/sbin/runuser`） | `droidloom-package-helper` | `/usr/lib/droidloom/droidloom-package-helper` |
| 001 `WifiProvisioning` 自愈 | Android 镜像里的 systemui jar | **未落地**（要 AOSP 侧重编镜像） |

```sh
# 备份（回滚件）
sudo mkdir -p /root/droidloom-backup-20261127-t27
sudo cp -a /usr/bin/droidloomd /usr/bin/droidloom-supervisor \
           /usr/lib/droidloom/droidloom-package-helper /root/droidloom-backup-20261127-t27/
# 部署
sudo install -m755 droidloomd /usr/bin/droidloomd
sudo install -m755 droidloom-package-helper /usr/lib/droidloom/droidloom-package-helper
sudo mv /usr/local/bin/unshare /root/droidloom-backup-20261127-t27/unshare-shim.moved   # 判据②
sudo -u <uid> XDG_RUNTIME_DIR=/run/user/<uid> systemctl --user restart droidloom.service
```

## 4. 验收（2026-11-27 22:2x–22:3x 实测，全绿）

| 判据 | 结果 |
|---|---|
| cell 仍 `Android is ready` | ✅ `droidloomctl status` = `cell u1001 is running …; Android is ready` |
| 删掉 `/usr/local/bin/unshare` 后仍能起 | ✅ shim 已移走；进程 = `unshare --mount --pid --mount-proc --ipc --uts --fork --kill-child=TERM --propagation=private /usr/bin/droidloom-supervisor development-enter …`（无 `--forward-signals`，走 util-linux 2.41.5 原版） |
| lease DNS = 宿主 resolver | ✅ cell `DnsAddresses: [223.5.5.5, 202.38.64.18, 1.1.1.1, 8.8.8.8]`（前两条 = 宿主 `resolvectl` 的 DNS）；**`nft list ruleset \| grep -c dl_dns_redirect` = 0**，cell 内 `ping www.ustc.edu.cn` 直接解析到 `202.38.64.246` |
| 侧证 | `droidloomctl applications` 列出 4 项（含 Trime）、`droidloom-doctor` 仍 1 WARN（`security.host_lsm`，与基线同项）、`systemctl --failed` = 0、`adb -s 10.177.0.2:5555` 在线 |

**回滚**：把 `/root/droidloom-backup-20261127-t27/` 三个原件 `install` 回去 + 把 `unshare-shim.moved` 移回 `/usr/local/bin/unshare` + `systemctl --user restart droidloom.service`。

## 5. 没做的事

- **001 未落地**：`WifiProvisioning.java` 属 Android systemui，要跑 droidloom 的包构建器（podman + AOSP 缓存 + Arch ARM sysroot，上游文档 `docs/BUILDING.md`）才出 `image` 包，**>1 GiB 下载红线**，本轮不碰。⇒ 跨重启的「Wi-Fi 被永久禁用」仍会发生（T2 的 001 与 issue #48 主因都等它）。
- 004 覆盖的 `before/remove`（镜像 setup）路径未单独跑；只做了「装上 + 文件路径存在性」核对。
- 镜像/runtime 的 pacman 元数据没改（我们只替换了 3 个二进制文件，`/usr/share/droidloom/package.json` 仍记 release 51 原件 sha）。
