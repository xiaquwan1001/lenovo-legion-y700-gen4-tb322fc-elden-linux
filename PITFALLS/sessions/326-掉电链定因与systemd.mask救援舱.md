# #694 「进锁屏即整机掉电」的掉电链：三件 unit 的组合，以及一条零写盘救援舱（`systemd.mask=` on cmdline）

## 现象（2026-11-19 22:0x–22:36，U2 HA2EXB0E，连续 3 次）

用户目视：**刚进 Phosh 锁屏，屏幕卡住不动，然后整机掉电**（不是重启循环、不是黑屏报错）。此前同一镜像曾 18–30 min 稳定。

取证（掉电样本可用的只有这些）：

- `journalctl --list-boots` 有 5 个短 boot；**每个 boot 的持久日志都只到 `systemd-journald: Time spent on flushing… for 92x entries` 就结束**（≈启动后第 1 秒），之后内核/用户态日志一行都没落盘 ⇒ **硬挂/直接断电，不是优雅 `poweroff`**（无 `Stopping …`/`final.target`/`System is powering off`）。
- `systemctl list-jobs`（掉电前那次成功登入）：`droid-juicer.service` running、`plymouth-quit-wait.service` running、`graphical.target` waiting，后面排着 `greetd`/`hexagonrpcd`/`ath12k-rescan`。
- pstore 空（ramoops 窗被我们的守卫拒掉）、无 Oops、无 panic。

## 定因（按证据强度分层）

- **步骤 1**已证实（可复现的因果）**：只要 `droid-juicer` + `plymouth-quit-wait` 在 queue 里 running，桌面永远不来（= #691/#693）。本轮**在 live 系统上 `systemctl disable --now droid-juicer` ⇒ ~40 s 后整机掉电**，与 #693 记录一致（该条怀疑它在我们自建 GPT 表上做破坏性读）。**⇒ 纪律：不要在 live 系统上停/杀这两件。**
- **步骤 2**高置信、未单变量**：droid-juicer 已 mask 落盘后的下一次开机，队列换 `hexagonrpcd` 顶上（`multi-user.target.wants` 里有它），掉电时间点 ≈ 锁屏出现后几十秒 = #692「attach ADSP sensor PD 硬崩整机」的时序。**没有做 A/B**（每次失败都要人肉复位，代价高），故标「未取证-高置信」。
- **步骤 3**排除**：不是 `usb0-host-route`（本轮存活期它一直在跑）、不是残留 watchdog（设备上 `q28-*watchdog*` 无 unit 无进程，只有内核 `watchdogd` 且已 permanently disabled）、不是 GPU（桌面起来后 phoc/phosh 稳定 ≥10 min）。

## 处置（本轮实走成功，可复用）

**判据**：`systemctl is-enabled <unit>` = `masked`（落盘而非仅 runtime）；`graphical.target` = active；`list-jobs` 为 0 行；`greetd`+`phoc`+`phosh`+`phosh-osk-stub` 四进程在；`scripts/deploy-desktop-shell.sh --check` = MISS=0。

顺序（**别在 live 系统上 stop 危险件**）：

- **步骤 1**造零写盘救援舱**（主机侧，5 s）：
   ```sh
   python3 scripts/boot-img-cmdline.py bootslot-b/boot_b-minbase-labellinux-20261119.img \
     --append "systemd.mask=droid-juicer.service systemd.mask=plymouth-start.service \
   systemd.mask=plymouth-quit.service systemd.mask=plymouth-quit-wait.service \
   systemd.mask=plymouth-switch-root.service systemd.mask=hexagonrpcd.service \
   systemd.default_timeout_start_sec=20" -o out/diag-20261119/boot-diag-nocrash.img
   fastboot boot out/diag-20261119/boot-diag-nocrash.img      # 零写盘
   ```
   `systemd.mask=` 是 cmdline 版 runtime mask ⇒ **开机即不启这些 unit**，不需要先进系统改任何东西（这是本条的真正新知识；以往的做法是「先进去再 mask」，而「先进去」本身就可能掉电）。
- (2) 进系统后（~45 s 到 SSH）**只做一件事**：`systemctl mask <上面六个>`（写 `/etc/systemd/system/*.service -> /dev/null`，落盘）。
- (3) `systemctl reboot` → 正常持久启动（本次 45 s 到 SSH，`graphical.target` active，无 failed unit，桌面四进程齐）。
- (4) 验证 `deploy-desktop-shell.sh --check` = MISS=0；再 `systemctl enable ath12k-rescan`（若被 runtime mask）确认 WiFi 回来（本次 `wlan0` 拿到 114.214.230.246、默认路由经 wlan0）。

## 长期解（未做，登记）

- rootfs 构建器 stage **不装** `droid-juicer` 与 `plymouth*`（我们无 splash、无 Android vendor 抽取需求）⇒ 从源头消失。
- `hexagonrpcd` 在**取证通道**（物理串口或修好 ramoops 窗口）建好前保持 mask；G1-34 传感器恢复必须按 #692 的前置清单做。
- `deploy-desktop-shell.sh` 的 §8b 已能报「未 mask」，但**它只报不改**——本轮之前正是靠人记得跑；建议把它并入开机自检（或让 §8b 同时检查 `is-enabled` ≠ masked 即写一条 systemd drop-in）。

## 复用判据（一句话）

进桌面就掉电 ⇒ 先看 `list-jobs` 里前三名（droid-juicer / plymouth-quit-wait / hexagonrpcd），**用 cmdline `systemd.mask=` 救援舱零写盘进系统落盘 mask**，不要在 live 系统上 `disable --now`。
