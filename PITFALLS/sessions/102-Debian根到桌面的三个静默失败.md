# #423 overlay 解包顶掉 usr-merge；#424 `.pre` hook 从不安装且无 shebang；#425 跨发行版名字差异；#426 drop-in 文件名排序；#427 debootstrap 根没有桌面用户；#428 一次探测接口名必失败

- **日期**：2026-10-26
- **场景**：M6/T19，把 `out/stage-debian/`（overlay，139 MB）推到 Debian 目标根 `linux17` 并启动（vk175）

这三条是「Debian 根能起 systemd、但到不了桌面」的**全部**直接原因，逐条都是**静默失败**。

## #423 `tar -C <root> -xf -` 会把 usr-merge 的符号链接换成真目录

Debian/Ubuntu 的 `/lib`、`/bin`、`/sbin` 是 `-> usr/*` 的**符号链接**。overlay 里有自己的
`lib/`（`firmware`、`modules`）⇒ 普通 `tar` 解包时**用目录替换链接**，于是：

```
/lib/ld-linux-aarch64.so.1  →  No such file or directory
chroot: failed to run command '/bin/sh': No such file or directory
```

（内核其实找的是 `/usr/lib/ld-linux-aarch64.so.1`，链接没了就整个根"动态链接全废"。）

- 现象极具误导性：`ls -l /bin/sh` 正常、`/usr/bin/dash` 也在，**只有执行才炸**；先怀疑的是 loader 版本、musl/glibc 混用。
- 判据：`ls -ld <root>/lib` 显示 `drwx...`（而不是 `lrwxrwxrwx -> usr/lib`）即已中招。
- **修法**：`tar --keep-directory-symlink`（GNU tar，跟进去而不是替换）+ 解完断言 `/bin /sbin /lib` 仍是链接。
  已固化为 **`rootfs/debian/install-overlay.sh`**（psuh→解包→断言 usr-merge→报 `INSTALL-OK`）。
- 手工修复路径（本次实际做的）：把真目录里的 `firmware/`、`modules/` 并回 `usr/lib/`，`rmdir lib`，再 `ln -s usr/lib lib`。

## #424 systemd 单元引用 `ExecStartPre=/usr/local/libexec/elden/<svc>.pre`，但**没人安装那个文件**

`render.py` 把 `hooks/<svc>.pre` 的**内容**内联进 OpenRC initd（Alpine 侧不需要额外文件），
而 systemd 单元渲染成 **引用一个路径** ⇒ 该文件因此前只存在于仓库，从不落盘：

```
greetd.service: Unable to locate executable '/usr/local/libexec/elden/greetd.pre'
greetd.service: Failed at step EXEC spawning … (status=203/EXEC)
```

连带 `elden-hapticd` / `net-selfheal` / `wifi-scan-refresh` / `iio-sensor-proxy` 全 203/EXEC。
greetd 死 ⇒ **没有桌面**（`phosh`/`phoc` 一个进程都没有，但系统 `degraded` 起来、`card0-DSI-1` 在）。

- 最难的地方是**门禁一直全绿**：`systemd-analyze verify` 对「目标根才有那个二进制」是预期噪声，
  被 `grep -v "is not executable"` 过滤掉了 ⇒ 幽灵路径和真噪声一起被滤掉。
- **修法**：① `stage.sh` 安装 `hooks/*.pre` → `/usr/local/libexec/elden/`（0755）；
  ② 新增门禁 **D2**：单元里每个 `Exec*=绝对路径` 必须在 `overlay ∪ PKGROOT` 存在，否则 FAIL；
  ③ `PKGROOT` 默认 `/opt/elden/mobian-rootfs`（833 包完整根）——**不能**用 `CHROOT`（那只是依赖模拟根，
  不含 greetd/qbootctl/iio-sensor-proxy）；④ `MANIFEST` 里 `repo_src=-` 的设备侧二进制降级为 WARN 并点名（T14 债务）。

## #425 同一个服务在两个发行版里「名字不同」，写死就必挂

| 对象 | Alpine | Debian | 写死的后果 |
|---|---|---|---|
| greetd 运行用户 | `greetd` | **`_greetd`** | `hooks/greetd.pre` 里 `getent passwd greetd` 失败 → `exit 1` → greetd 203/EXEC |
| 无线接口 | `wlan0` | **`wlp1s0`**（systemd net.ifnames） | `net-up.sh` 等 90×2 s 后失败，`net-up.service` failed，WiFi 永不自动连 |

修法：`greetd.pre` 逐个试 `greetd` / `_greetd`，owner 用解析到的名字；`net-up.sh` 用 `WIFI_IF` env →
`/sys/class/net/*/wireless` 探测 → 最后才回落 `wlan0`。
（`hooks/net-selfheal.pre` 本来就写的是 `^wlan.*UP`，天然可移植 —— 说明「判据写模式、别写死名字」是对的做法。）

## 顺带：`qbootctl -m` 早期失败不是槽坏，是 udev 还没建 `/dev/disk/by-partlabel`

```
qbootctl[433]: get_number_slots: Failed to open bootdev dir (No such file or directory)
qbootctl[433]: No slots found, is this an A/B device?
→ status=1/FAILURE
```

`strings` 实证 Debian 的 qbootctl 用 `/dev/disk/by-partlabel`（Android 系用 `/dev/block/by-name`）。
早起一次失败就完事 ⇒ **槽 retry 照常递减**（PITFALLS #181 的触发链）。
修法 = `qbootctl-mark.sh` 重试包装（等到目录出现，最多 30 s；末尾用 `-c`/`-n` **复核**真的标成功，
失败则 `exit 1` 并 dump 全槽信息 —— 明确失败优于静默成功）。

## 证据

- `reports/m6-switch-root-breakpoint-resolved-20261026.md` §8
- `linux17:/var/log/journal/*/system.journal`（可 `chroot <root> journalctl -D /var/log/journal` 读）
- `rootfs/debian/stage.sh`（门禁 D2/I）、`rootfs/debian/install-overlay.sh`（#423 固化）
- `packaging/elden-userland/hooks/greetd.pre`、`files/usr/local/sbin/{net-up.sh,qbootctl-mark.sh}`


## #426 systemd drop-in 按**文件名排序**合并，`10-` 会被上游包的 `phrog.conf` 盖掉

Debian 的 `greetd-phrog` 包提供 `/usr/lib/systemd/system/greetd.service.d/phrog.conf`（把 ExecStart
改成图形 greeter）。我们在 `/etc/systemd/system/greetd.service.d/10-elden.conf` 里 `ExecStart=` 清空后重设，
**结果没生效**——因为 `/etc` 与 `/usr/lib` 的 drop-in 是**按文件名统一排序**合并的，`10-` < `phrog.conf`（`1` < `p`），
后排序者覆盖 ⇒ 仍然跑 phrog。

- 判据：`systemctl show <unit> -p ExecStart --value` 看**最终** argv，不要只看 `systemctl cat`（两者都显示，会以为生效了）。
- 修法：名字取 `zz-elden.conf`（排序最后）。**不要**用 `10-`/`90-` 这种直觉编号。

## #427 debootstrap 出来的根**没有任何发行版之外的用户** ⇒ greetd appliance 模式直接死循环

`/etc/greetd/config.toml` 是 appliance 模式（`initial_session.user = xuqianhui1001`）。Debian 根里没这个用户：

```
greetd: error: configured default session user 'xuqianhui1001' not found
greetd: error: check_children: greeter exited without creating a session
```

systemd 每 5 s 重拉一次 ⇒ `greetd.service: activating`、**连 greeter 都不出**（屏幕停在 VT7 空白），
而 `card0-DSI-1` 是 `connected/enabled`、背光正常 ⇒ 很容易误判成"显示栈问题"。

- 修法：`rootfs/debian/ensure-desktop-user.sh`（uid **1001** 必须与 Alpine 侧一致，否则 `/home` 与 Waydroid/会话属主全错；
  组列表按「目标根里真实存在」过滤：Debian 有 render/netdev，Alpine 用 video/audio/input/plugdev），并接进 `build-rootfs.sh`。

## #428 在循环外只探测一次接口名 ⇒ ath12k 异步绑定必然探测失败

`net-up.sh` 曾写成"开头解析一次 IF 再等它出现"。ath12k 是异步 probe（本机 ~9–21 s 才出 phy），
开机 3 s 时 `/sys/class/net/*/wireless` 还不存在 ⇒ 探测失败 ⇒ 回落 `wlan0` ⇒ 永久等一个不存在的名字：

```
net-up: wlan0 never appeared     ← Debian 上真实接口是 wlp1s0
net-up.service: failed
```

更阴的是**WiFi 最后还是通的**（NetworkManager 自己的 autoconnect 连上了）⇒ 掩盖了这个 bug，
只在 `systemctl --failed` 里露一条。修法 = 探测放进等待循环（名字消失则作废重探）。
