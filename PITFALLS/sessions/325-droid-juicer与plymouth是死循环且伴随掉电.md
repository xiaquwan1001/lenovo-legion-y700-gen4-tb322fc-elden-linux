# #693 自建根上的两件「开机卡死 / 整机掉电」——`droid-juicer` 与 `plymouth-quit-wait` 不是"慢"，是**死循环**；且不是普通卡死（连 syslog 都不刷了）

## 现象（2026-11-19 晚，同日多次复现，用户目视 + 照片 `IMG_20261119_182647.jpg`）

- 开机停在 fbcon 的 systemd 服务清单；`systemctl list-jobs` 里 `droid-juicer.service` 与
  `plymouth-quit-wait.service` 恒在 `running`（几分钟不动），`graphical.target` 永远 waiting；
- **kill -9 两个进程也没用**：job 仍 `running`（进程被 systemd 立即重拉——`Restart=` 语义/`Type=oneshot`+`RemainAfterExit`），mask 与 kill 之间有竞态，非交互一轮 ssh 做不完两步；
- **同会话内做过 mask+kill 的那次，设备直接掉电重启**（不是 panic：journal `-b -1` 末行 =
  `bluetoothd sap-server: Operation not permitted`，无 Oops、无 panic 行、pstore 空、内核 `Hard watchdog permanently disabled`）；
- 掉电时间点 = mask 生效后 ~40 s，与 `droid-juicer` 的「扫全盘分区抽 Android 固件」在**自建 GPT 表**上
  读到不该读的扇区（我们的 `linux`/`eldenesp` 在它眼里是 Android 的 `super`/`userdata`）的时序吻合 —— **强烈怀疑它对分区表做了破坏性操作或触发了 UFS 层错误**，这是最危险的一种可能，未取证，不得再裸试。

## 为什么"上一次能起、这次起不来"是假象

13:00 那次能进桌面 = 两件恰好没卡住；16:39 起每次都卡。**判据不能是"上次能起"**，
只能是：`systemctl is-active graphical.target` = active 且队列里没有 >60 s 的 `running` job。

## 判据（主机侧一条链，不等屏幕）

```
ssh elden-root 'systemctl is-system-running'                      # starting 卡 >90 s 即异常
ssh elden-root 'systemctl list-jobs | grep -w running'            # 谁 running 一目了然
ssh elden-root 'systemctl is-active graphical.target'             # inactive = 桌面永远不来
```

## 处置（本轮实走有效的顺序 —— 一次 ssh 只做一件事，防再掉电丢进度）

处置顺序（本轮实走有效的顺序 —— 一次 ssh 只做一件事，防再掉电丢进度）：

- **stop 在 mask 之前单独做**（`systemctl stop droid-juicer.service plymouth-quit-wait.service`），
  确认 `list-jobs` 里 running 消失后再 mask；
- mask 落盘后**不要再做别的写操作**，立即验证；
- 若仍复发 ⇒ 不再在设备侧反复试，改走**镜像侧**：在 `out/min-restore-*/rootfs-minbase-*.ext4.img`
  上用 debugfs 删掉这两个 unit 的 enable 链接后重写根（写盘流程见 `LINUX-STATE-REPRO.md` §3 S3）。
- 长期解 = `deploy-desktop-shell.sh` §8b 在**每次开机后**跑（不 mask 就报 MISS），以及
  rootfs 构建器 stage 里**不装** `droid-juicer` 与 `plymouth`（我们无 splash、无 Android vendor 抽取需求）。

## 与 PITFALLS 323（启动队列被droid-juicer与plymouth卡死）的关系

该条 = 现象（队列卡死 ⇒ 桌面不来）；#693 = 同现象的**升级事实**：mask+kill 组合动作与
设备掉电相关、且两件不是慢而是死循环。323 条的处置仍然成立，但**多加一条安全约束**：
**对这两件禁止在同一轮里做 mask+kill 之外的组合写操作**，先 stop 单独验证。
