# #732 `systemctl unmask` 一个**本来就 enabled** 的 unit = 让它每次开机自启（本次 = 5 次启动硬崩循环）

## 现场（2026-11-26 08:3x–09:1x，U2 HA2EXB0E）

目标 = 试通 SSC 传感器（`hexagonrpcd -s` attach sensorspd）。步骤里做了：

```sh
systemctl unmask hexagonrpcd        # ← 关键：它在 default.target.wants/ 里本来就是 enabled（2026-11-19 起）
mkdir -p /etc/systemd/system/hexagonrpcd.service.d   # drop-in: -f /dev/fastrpc-adsp -d adsp -s -R /var/lib/droid-juicer/sensors
systemctl start hexagonrpcd
```

`start` 后 SSH 立刻断，用户目视「phosh 转圈卡住 → 整机掉电」；随后 **5 次连续短 boot**，每个 boot 的持久 journal
都只写到启动第 1 秒的 `systemd-journald: Time spent on flushing…`（= 硬崩签名，与 #694 同）。设备进入
「开机即崩」循环，最后靠用户物理 POR + 主机侧救援才断开。

## 机理

- `mask` 只是 `/etc/systemd/system/<unit> -> /dev/null`，与 `enabled`（`*.wants/` 里的 symlink）是**两件独立事实**。
- `unmask` 只删 `-> /dev/null`，**不动`.wants` 链接** ⇒ 单元立刻恢复「每次开机启动」。
- 于是 `-s`（attach ADSP sensor PD = #692 硬崩面）在每次开机都跑 ⇒ 循环。
- 判据：`ls -l /etc/systemd/system/*.wants/ | grep <unit>`（`systemctl is-enabled` 在 masked 时会只报 `masked`，**不告诉你它同时 enabled**）。

## 处置（本次实走）

- **救援镜像**：`python3 scripts/boot-img-cmdline.py <daily.img> --append "systemd.mask=<unit>.service …"` + `fastboot boot`（零写盘）。
   ⚠ 旧镜像 cmdline 的 `elden_root=LABEL=linux17` 与现根 LABEL **`linux`** 不符（`PITFALLS #728`）⇒ 会落到 initramfs。
- **落 initramfs 也行**：**该 initramfs 自带 SSH**（`root@192.168.7.1`，host key 会变），进去后
   `mount -o rw /dev/sda17 /mnt/root` → 在 `/mnt/root` 上 `ln -sf /dev/null …/etc/systemd/system/<unit>.service`、
   删 `default.target.wants/<unit>.service`、删 drop-in、删我们加的 udev 规则 → `sync` → `umount` → `reboot -f`。
- **修复后判据**：`is-system-running=running`、`graphical.target=active`、`--failed=0`、`phoc`/`phosh` 各 1。

## 硬规则

- **要临时跑一个 enabled 的危险 unit**：先 `systemctl disable <unit>`（保留 .wants 语义要显式记录），或**保持 masked 只做单次
  `systemctl start`**，并先接受「崩了就是开机循环」的后果；`unmask` 绝不能当成「临时允许一次」。
- 动 `#692` 类风险面前，**先建取证通道**（物理串口 / ramoops），否则崩了连日志都留不下（本次 5 个 boot 全是空壳）。
- 事后复查口径：`systemctl is-enabled` 不够，必须看 `*.wants/` 链接。
