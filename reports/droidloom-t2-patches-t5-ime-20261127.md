# droidloom 本地 patch 落地（T2）+ 真重启后 IME 持久性（T5）—— 2026-11-27 深夜，上机

- **性质**：U2 `ssh elden` 上机；在机内核 `7.3.1-debug-vk189-suspend-g4da9a8b69fc8-dirty`；droidloom **0.1.0-51**。
- **一句话**：4 条本地 patch 里 **3 条已落地并上机验收全绿**（002 去 `--forward-signals` / 003 宿主 resolver 进 lease / 004 `runuser` 路径），**001（WifiProvisioning 自愈）卡在 Android 镜像重编**；同一次真重启顺带把 **T5 的「默认 IME 持久性」测掉（仍 Fossify ✅）**，中文输入仍缺一步（详见 §3）。
- 构建/部署/回滚手册：`patches/local/droidloom-local-20261127/BUILD.md`（本报告不重复命令）。

## 1. 判据表（T2）

| # | 判据 | 结果 | 证据 |
|---|---|---|---|
| ① | cell 仍 `Android is ready` | ✅ | `droidloomctl status` → `cell u1001 is running from /etc/droidloom/cell.json; Android is ready` |
| ② | 删 `/usr/local/bin/unshare` 后仍能起 | ✅ | shim 移走；进程 = `unshare --mount --pid --mount-proc --ipc --uts --fork --kill-child=TERM --propagation=private /usr/bin/droidloom-supervisor development-enter …`（无 `--forward-signals`；util-linux 2.41.5 原版） |
| ③ | lease DNS = 宿主 resolver ⇒ 可删 `ip dl_dns_redirect` | ✅ | cell `DnsAddresses: [223.5.5.5, 202.38.64.18, 1.1.1.1, 8.8.8.8]`（前两条 = 宿主 `resolvectl` DNS）；`nft list ruleset \| grep -c dl_dns_redirect` = **0**；cell 内 `ping www.ustc.edu.cn` → `202.38.64.246` 直通 |

**承接二进制（关键坑）**：`--forward-signals` 与 lease DNS 两贴都编进 **`droidloomd`**（`development.rs` 在 `droidloom-supervisor` crate 里，而 `droidloomd` 也编这个 crate）。**只换 `/usr/bin/droidloom-supervisor` 不生效** —— 实测重启后 `droidloomd` 仍调 `unshare --forward-signals` 并报 `unshare: 未识别的选项 "--forward-signals"`，cell exit 1。换掉 `droidloomd` 后才通。

## 2. 002/003/004 落地明细

- **编译**：Debian 主机交叉编译（`cargo build --release --locked --target aarch64-unknown-linux-gnu`，29 s 冷启）；纯 Rust 的 9 个 bin 都能出，`droidloom-wayland`/`audio`/`devices`/`gpu-server` 因缺 Arch ARM 的 C 库（`-lxkbcommon`/`-lwayland-server`）**没编也没换**（本组补丁不涉及）。glibc 门槛 `GLIBC_2.39` ≤ 设备 2.41。
- **落地的文件**：`/usr/bin/droidloomd`（002+003）、`/usr/lib/droidloom/droidloom-package-helper`（004）。
- **回滚件**：`/root/droidloom-backup-20261127-t27/`（含 `droidloomd`、`droidloom-supervisor`、`droidloom-package-helper`、`unshare-shim.moved`）。
- **004 的现实意义**：Debian 只有 `/usr/sbin/runuser`（设备实测 `/usr/bin/runuser` = 不存在）⇒ 原件在「以 root 跑 package helper」的路径上必然 `No such file`，本贴是修这个。
- **patch 003 的应用条件**：必须紧跟 002，且需 `--fuzz=2`（002 挪动了 `development.rs` 同段行号）；单独对原文 `--fuzz=0` 会 2/2 hunk 失败 —— **不是补丁坏**。

## 3. T5：默认 IME 持久性 ✅ / 中文输入 🟡

| 项 | 结果 |
|---|---|
| 真重启（`systemctl reboot`，22:11 CST）后默认 IME 是否仍 Fossify | ✅ `settings get secure default_input_method` = `org.fossify.keyboard/.services.SimpleKeyboardIME`（cell 是重启后新起的，非热态） |
| 中文可输入 | 🟡 **未打通**：① Fossify 本身无中文布局（既有结论）；② 本轮装了 **Trime 3.3.13 arm64**（`gh release download`，sha256 `e7535ea4…`，用 `droidloomctl install` 装进 cell，`ime list` 已注册 `com.osfans.trime/.ime.core.TrimeInputMethodService`，`ime set` 可切为默认）；③ 但 Trime 首启落 `SetupActivity`（需人工点选）且自报 **`Skip starting rime: storage not available!`** ⇒ 词库未部署，切过去等于「没输入法」。已**恢复默认 = Fossify 并 force-stop Trime**，设备未留在不可用状态。 |

**下次上机要做的**（有人值守 10 分钟）：打开 Trime 的 SetupActivity 点完向导 → 在任一输入框验证 `nihao` 出「你好」→ `settings put secure default_input_method` 定格选一个（Fossify=英文优先 / Trime=中文优先，**两者不能兼得，需用户裁决**）。
**顺带发现**：cell 的 `/sdcard` = 宿主 `/dev/sda17` 的 `pass_through` 视图（`/dev/sda17 on /mnt/pass_through/0/emulated`），所以 Trime 词库若部署会写进宿主根分区 —— 记录备查。

## 4. T4 结论变化

T2 的 003 落地后，cell 已能直接解析（DNS 走宿主 resolver），**`ip dl_dns_redirect` 这条重定向不再需要**；`/etc/systemd` 侧本来也没有持久化它的 unit（T4 原判「跨重启不持久」= 0 条，本轮复核仍 0）⇒ **T4 可整件关闭（随 T2 落地而作废）**，不必再做持久化 unit。

## 5. 未做 / 下一轮

1. **001 WifiProvisioning 自愈**：属 Android systemui，要跑 droidloom 的包构建器（podman + AOSP 缓存 + Arch ARM sysroot，`docs/BUILDING.md`），**触发 >1 GiB 下载红线**⇒ 未做。后果：cell 跨重启仍可能被「Wi-Fi 永久禁用」咬（issue #48 主因）。**这是 T2 唯一未落地项**，需要先决定是否允许这次大下载。
2. 004 覆盖的 `before/remove`（镜像 setup）路径未单独跑。
3. `package.json` 仍记 release 51 原件 sha（我们只替换了 3 个二进制）。
4. droidloom 重启不自启（user unit + `graphical-session.target` inactive）—— 既有已知项，本轮仍手工起。
