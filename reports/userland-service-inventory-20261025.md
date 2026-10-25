# 用户态驱动/服务独立固化 — 审计与落地（2026-10-25）

> 触发：用户问「考虑先把用户态驱动和服务独立固化？也可以按推荐顺序开始」。
> 性质：**纯主机侧 + 设备只读**（ssh 取文件清单、sha256、进程表；未 flash/boot/reboot，未写任何分区）。
> 结论优先级：本文 §0 是裁决，正文（§2 清单 / §3 新事实 / §5 门禁）为准。
> 证据：`packaging/elden-userland/`（MANIFEST.tsv 73 行、services.tsv 20 行、verify.sh 8 段门禁）。

## 0. 结论

**先固化是对的，而且比原估的「Mobian 前置工作量」更值**：本轮的固化把 `reports/mobian-migration-plan-20261021.md`
里最大的一项成本「**7 类 systemd unit 重写（4–6 h）**」变成了 **`render.py` 一条命令**，同时把
「`/usr/local/sbin` 里 66 个文件只存在于设备」这个**换根即丢**的风险变成可门禁的清单。

一句话结构：**服务语义 1 份真源（`services.tsv` 20 行）→ 渲染 2 套 init（18 个 systemd unit + 18 个 openrc initd）→ 8 段门禁**。
门禁当前 **FAIL=0 / WARN=3**（3 条 WARN 全是**真实的不可重建资产**，见 §3.1，不是噪声）。

同时否掉一个原本以为要做的事：**不需要**「重写 7 类 unit」。实测 10 个自研 initd 里只有
**4 处逻辑**是真需要迁移的钩子（amplitude=255、QRTR svc400 等待、greetd home、wifi log），
其余全是 `command/command_args/depend` 的机械投影。

## 1. 现状测量（设备 = vk152 / Alpine 3.24 / ext4 root）

| 面 | 实测 |
|---|---|
| 自研/改过的服务 | **10 个 initd**（elden-hapticd / elden-powerlog / greetd / iio-sensor-proxy / qbootctl / wifi-scan-refresh / pstore-catch / ssc-udp-relay / waydroid-ipv6 / backlight-floor）+ **3 个 local.d** + 33 个 runlevel 服务条目 |
| 自研二进制 | **7 个 ELF**：`elden-hapticd`(729 312 B) `elden-ime-focusd`(74 392) `eldroid-sensord`(778 944) `ffrumble`(775 544) `waydroid-sensord`(246 456) `waydroid-sensord-udp`(244 768) `reboot2`(709 368) |
| 自研脚本 | `/usr/local/sbin` 47 + `/usr/local/bin` 17（含 `.bak-*` 噪声） |
| 参数文件 | `conf.d` 4 个（elden-hapticd / wifi-scan-refresh / backlight-floor / greetd）+ greetd `config.toml` |
| 内联在 initd 里的逻辑 | 20 行（pstore-catch）、13 行（elden-powerlog）、4 行（greetd checkpath）等 ⇒ 已剥离到 `extra/` 与 `hooks/` |

## 2. 交付物（`packaging/elden-userland/`）

| 文件 | 作用 | 证据 |
|---|---|---|
| `MANIFEST.tsv` | 设备逐条：dst / kind / sha256 / size / mode / 仓库副本路径 | 73 行（66 文本 + 7 ELF） |
| `files/` | 采自设备的文本副本（**逐字**，禁手改） | 66 个文件，708 KB |
| `sources.tsv` | 每个 ELF 的重建命令 + 源文件 + 状态 | 7 行：**4 ok / 3 missing** |
| `services.tsv` | 服务语义唯一真源（14 列：class/deps/env/log/respawn/enabled） | 20 行 = 18 自研/覆盖 + 2 包提供 |
| `provides.tsv` | OpenRC `provide` / systemd `Alias=`（greetd → display-manager） | 1 行 |
| `hooks/*.pre` | 真需要前置的 4 个服务 | hapticd / iio-sensor-proxy / greetd / wifi-scan-refresh |
| `extra/` | 从内联 initd/local.d 剥离出的独立脚本 | 5 个（含 gunyah-modprobe，默认禁用） |
| `tools/sync-from-device.sh` | 只读采设备 → `files/` + `MANIFEST.tsv` | 幂等，73 条 |
| `tools/render.py` | `services.tsv` → 两套 unit（含 OpenRC→systemd 依赖名映射） | 18+18，`--check` 可用 |
| `tools/verify.sh` | 8 段门禁（A 清单 / B 可重建 / C 无幽灵服务 / D 渲染 / E 语义红线 / F 设备漂移 / G 第 4 处真源 / 出口码） | **FAIL=0 WARN=3** |

## 3. 本轮新事实（都不是复述旧报告）

### 3.1 三个 ELF 不可重建，其中两个直接卡死 Mobian 迁移

| ELF | 链接方式 | 源 | 换 glibc 后的后果 |
|---|---|---|---|
| `elden-hapticd` | **静态** | ✅ `scripts/elden-hapticd.c` | 直接可用 |
| `eldroid-sensord` | **静态** | ✅ `scripts/eldroid-sensord.c` | 直接可用 |
| `reboot2` | **静态** | ✅ `rootfs/reboot2.c` | 直接可用（Linux→fastboot 唯一可靠入口） |
| `ffrumble` | **静态** | ❌ **无源** | 可用但**永久不可重建**；马达取证能力丢失风险 |
| `elden-ime-focusd` | 动态 **musl** | ✅ `patches-userland/zh-ime/` | **必须重编**（运行时 + glib/gio） |
| `waydroid-sensord` | 动态 **musl** | ❌ 无 recipe | **必须重编但编不出来** ⇒ 传感器 HAL 直接没了 |
| `waydroid-sensord-udp` | 动态 **musl** | ⚠️ 有 Makefile，缺宿主交叉 recipe | 同上 |

**这是本轮最重要的一条**：`reports/mobian-migration-plan-20261021.md` §0 把风险列为 R1/R2/R3，
但**没有列出「三个动态 musl 二进制」**。它们在 Debian 上要么重编（IME 有源、可做），
要么**无源可重编**（两个 sensord）⇒ **G3（Mobian）的前置必须先补 sensord 的构建 recipe**，
否则换过去之后传感器/容器传感器链直接断，而这属于刚验收过的能力（`sensors` → `HasAccelerometer=true`）。

### 3.2 每次开机有 5 个后台脚本被**两个入口**重复拉起

- `/init`（磁盘根块，`initramfs/init:405-409`）启动 `ath12k-retry / net-up / time-sync / charge-watch / bt-up`；
- `/etc/local.d/elden-bringup.start` 又启动 `q28-boot-watchdog / ath12k-retry / charge-watch / time-sync`。
- 实测：4 个重叠项里 `charge-watch` 当前**只有 1 个进程**（另一份先退出了），`charge-watch.sh` **无 pidfile/flock**
  ⇒ 存在「两个循环同时写充电 sysfs」的竞态窗口，只是尚未被观察到。

**固化后的正确结构**：这些改由 init 系统的服务管理器**唯一**负责，`/init` 只保留
「早期必须早于 init 的东西」（usb-gadget / udhcpd / sshd / tpll 加载），
否则换 systemd 时会出现「systemd 拉一次 + `/init` 再拉一次」。⇒ 记为 **T14 的第二步**（§6）。

### 3.3 OpenRC ↔ systemd 的依赖名**不同名**，是换 init 的静默杀手

`systemd-analyze verify` 实测（18 个 unit 全跑）：

```
Failed to add dependency on localmount, ignoring: 无效的参数     ← 7 个 unit 中招
Failed to add dependency on dbus / seatd / elogind / networkmanager / lxc / bluetooth / udev
```

即 `Requires=localmount` 这类写法在 systemd 上**不报错、直接忽略**；
如果照抄 OpenRC 名字渲染，迁移后服务会**乱序启动**（greetd 早于 seatd ⇒ 无桌面，正是 `PITFALLS #318` 的复现路径）。
已在 `render.py` 内建 `UNIT_MAP`（12 条映射）并让**未映射的依赖名直接 FAIL**（不再静默）。
修完后 `systemd-analyze verify`：**unit 级错误 0**。

### 3.4 `bash` 不接受「函数体里只有注释」

```
$ printf 'f() {\n\t# c\n}\n' | bash -n
bash: 行 3: 未预期的记号 "}" 附近有语法错误
```
渲染 `depend() { # 无依赖 }` 时踩到 ⇒ 已改为 `: # 无依赖`。**这也是「渲染而不是手写」的价值**：
这类坑只在生成的空集上才出现，手写 18 个文件时不会有人去测「依赖为空」的分支。

### 3.5 参数只有一个真源（原来散在 3 个 conf.d + 设备运行时）

`WIFI_SCAN_INTERVAL=150`（必须 <180）、`BACKLIGHT_FLOOR=1024`、`HAPTIC_ARGS=--amp-a 0xffff --amp-b 0xffff`
现在同时出现在 `services.tsv` 的 env 列**和**设备 `conf.d`（真源仍是 conf.d，services.tsv 只给默认值），
并被 `verify.sh §E` 逐条断言 ⇒ 迁移时改错会被门禁挡住。

## 4. 与 f2fs / Mobian 迁移的接口（这才是本轮的收益）

| 迁移项 | 原估 | 现在 |
|---|---|---|
| systemd unit 重写 | 4–6 h，7 类 | **`python3 tools/render.py`（秒级）+ 部署 hooks/extra（30 min）** |
| 参数迁移 | 3 个 conf.d 手抄 | conf.d 文件原样搬（两种 init 都读）+ 默认值有门禁 |
| 语义回归（qbootctl/greetd/传感器/扫描/马达） | 靠人记 | **`verify.sh §E` 5 条断言** |
| 新增前置（本轮发现） | — | ① `ffrumble` 补源（~60 行 EV_FF 客户端）；② `waydroid-sensord(-udp)` 补宿主构建 recipe |

⇒ **Mobian 的 G3 从「4–6 h 重写」变成「半天补两个构建缺口」**，且第二个缺口（sensord recipe）
无论走不走 Mobian 都该补（现在它只存在于设备的已编译文件里）。

## 5. 门禁实测输出（可复跑）

```bash
$ bash packaging/elden-userland/tools/verify.sh
[A] ok 73 行已核对
[B] ok 4 / WARN 3（ffrumble、waydroid-sensord、waydroid-sensord-udp 无源）
[C] ok 20/20（含「包二进制」与「解释器+脚本」两种合法情形）
[D] ok 18 systemd + 18 openrc；bash -n 全过；systemd-analyze unit 级错误 0
[E] ok qbootctl 默认启用 / greetd respawn / QRTR 400 等待 / 扫描 150s<180 / amplitude 255 / 关机标记外置
[F] ok 66 条与设备逐字一致（ELF 只提示 DIFF，因重编会改 sha）
[G] ok build-rootfs.sh 白名单 24 项全在 MANIFEST（第 4 处真源不再漂）
==== verify: FAIL=0 WARN=3 ====
```

## 6. 下一步（按序，均为低风险）

1. **（30 min，零设备写）** 补 `ffrumble` 源：按 `reports/motor-haptics-vk127-20261017.md` 的用法
   （`ffrumble /dev/input/eventN <ms> <magnitude>`）重写 EV_FF 客户端 ⇒ `sources.tsv` WARN 从 3 降到 2。
2. **（1–2 h，零设备写）** 补 `waydroid-sensord(-udp)` 的宿主构建 recipe（在 debootstrap/docker 里装
   `libgbinder-dev libglibutil-dev` 后 `make -C patches-userland/waydroid-sensord-udp`），并把产物路径写进 `sources.tsv`。
3. **（T14 第二步，需改 boot.img）** `/init` 与 local.d 的 5 个重复入口收敛：`/init` 只留早期必需，
   其余交给服务管理器 —— 这是换 f2fs/Mobian 时必须先做的一步（否则新 init 上会双启）。
4. **（需用户批准重启）** 回到原计划的 **G0**：用当前 initramfs 重打 boot.img → `fastboot boot`（仍 ext4 根）
   验证 fstype 自动探测零回归。设备现在在 Linux（vk152），需要一次 `reboot2 bootloader`。

## ★SSOT 待并入

- `TASKS/README.md` §4：新增 **T14**（用户态固化，本轮完成第一步：清单/渲染/门禁；剩 ffrumble 源、sensord recipe、init 入口收敛）。
- `TASKS/README.md` §0 运维行：可加一句「用户态服务已可双 init 渲染（`packaging/elden-userland/`，verify FAIL=0）」。
- `reports/mobian-migration-plan-20261021.md` §4 S6：**7 类 unit 重写** 降级为「render.py + hooks」；
  风险表新增 **R4：动态 musl 二进制在 glibc 发行版上必须重编，其中 waydroid-sensord(-udp) 无 recipe**。
- `PITFALLS/README.md`：新增一条（#unknown → 按现有编号续）三连击：
  ① OpenRC 服务名 ≠ systemd 单元名（`Requires=localmount` 静默失效）；
  ② `bash` 函数体只有注释 = 语法错误；
  ③ `while read` 循环里裸调 `ssh` 会吞掉循环的 stdin（只处理第一行）。
