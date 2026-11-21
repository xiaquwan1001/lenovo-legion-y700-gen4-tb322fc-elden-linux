# 用户态部署漂移只读审计（2026-11-21）

> 性质：**纯只读**。设备侧只用 `ssh elden 'sudo -n cat …'` 与 `stat`/`systemctl is-active`/`/proc/cmdline`；
> 未写设备（无 sudo 写 / scp / systemctl 操作），未改仓内 `packaging/`（仅本报告 + `reports/artifacts/userland-drift-20261121/`），未 commit。
> 门禁真源：`packaging/elden-userland/tools/verify.sh elden`（本次唯一判据）。

## 0. 数字（实测）

| 项 | 值 |
|---|---|
| `verify.sh elden` | **FAIL=19 / WARN=40**（WARN 主要是 `设备上不存在` 的 openrc 专属路径与未部署的额外资产） |
| FAIL 行按段拆 | A 段（`files/` 副本 sha ≠ MANIFEST）**3** + F 段（设备 ≠ MANIFEST 副本）**13** + F2 段（设备 unit ≠ 渲染单元）**3** |
| 涉及的**不同路径** | **17** 个 |
| 其中「设备与仓库内容真不同」 | **14**（11 个文本 + 3 个 unit） |
| 其中「仅 MANIFEST 记录过期」 | **3**（`elden-session-user`、`time-sync.sh`、`q28-race-hunt.sh`） |
| 三类归属 | **a) 设备更新未回仓 = 1**（`config.toml`，且仅注释）；**b) 仓更新/设备旧或未部署 = 12**；**c) 仅 MANIFEST 过期 = 3**；**a+b 双向混合 = 1**（`usb-gadget`） |
| diff 规模 | 14 个 diff 文件，**26 个 hunk，461 行变更**（`+`/`-` 合计；含上下文 716 行） |
| 最大单文件漂移 | `slot-attr.py` 178 行（5 hunk）→ `waydroid-session.sh` 48 → `net-up.sh` 35 |
| 设备根画像 | `systemd`（`/etc/elden-init-mode=systemd`），`androidboot.slot_suffix=_b`，`elden_root=LABEL=linux`；开机 2h08m |
| 部署链状态 | `out/stage-debian/` **不存在** ⇒ verify 的期望表全部取 MANIFEST 本体，没有 overlay 干扰 |

> 与派工单的差异（必读）：派工单列的「约 10 个」是 F 段的**部分**样本；实测设备侧漂移为
> **13 个文本路径 + 3 个渲染 unit**，另有 3 个 MANIFEST 自身过期。下文按**实测 17 个**全覆盖。

## 1. 逐文件表格

方向记号：`仓→设` = 设备是旧版（仓里有修复没落地）；`设→仓` = 设备上有仓里没有的东西。

| 文件 | 类别 | 建议 | diff 行 | 关键差异（一句话） |
|---|---|---|---|---|
| `/etc/greetd/config.toml` | **a** | sync-from-device（或直接忽略） | 4 | 仅 2 行注释：设备把「PAM pam_elogind」改成「pam_elogind/pam_systemd」并加 `2026-11-19 重建：minbase 根…`；`[terminal]/[default_session]` 逐字相同 ⇒ **功能等价**，无修复可回。 |
| `/usr/local/sbin/cam-mode.sh` | **b** | 重部署 | 21 | 设备写死 `CAMAS='sudo -u xuqianhui1001 … USER_RUNTIME_DIR=/run/user/1000'` 并 `pgrep -u 1000`；仓改为**现查会话用户/uid/提权工具**（Debian 根无 `sudo` 时回退 `runuser`，两者都无则显式报错）。设备版在无 sudo 的根上会**静默空转**。 |
| `/usr/local/sbin/charge-watch.sh` | **b** | 重部署 | 21 | 设备缺 `wait_for_usb()`（等 `qcom-battmgr-usb` 节点 ≤120 s）且轮询 `sleep 10`；仓为 `sleep 2`。设备版开机首 19 s 无人顶 ICL、插电看似不充（T18 结论）。 |
| `/usr/local/sbin/elden-session-user` | **c** | 仅更新 MANIFEST | 0 | 设备 sha = 仓 sha = `015fbb3ba596`(3704 B)；MANIFEST 仍记 `88483d4f…`/852 B（旧版）。**内容等价**。 |
| `/usr/local/sbin/net-up.sh` | **b** | 重部署 | 35 | 设备 `IF=wlan0` 写死 + 只探一次；仓按 sysfs `wireless` 目录探测接口名（Debian 根是 `wlp1s0`）且在循环里反复重探。设备版在 systemd 根上必报 `wlan0 never appeared`。 |
| `/usr/local/sbin/q28-boot-watchdog.sh` | **b** | 重部署 | 18 | 设备判据 `[ -e /sys/class/drm/card0 ]`；仓改「存在任一 cardN」+ 日志打印 `cards=[…]`（PITFALLS #667：UEFI/GRUB 路径 msm 是 card1）⇒ 设备版会把**正常启动判成坏发并自动重启**。 |
| `/usr/local/sbin/q28-watchdog.sh` | **b** | 重部署 | 4 | 同上，`status` 只显示 `card0=yes/no`；仓列全部 cardN。 |
| `/usr/local/sbin/slot-attr.py` | **b** | 重部署（高优先） | 178 | 设备为 **2026-11-18 审计前**版本：无 `alt_lba` 定位备表、无短写循环、无写回 CRC 自验、无整盘镜像守卫、无 `--selftest`；`main()` 少 `sys.exit()`。设备版**只改主表**⇒ 主备不一致风险。 |
| `/usr/local/sbin/time-sync.sh` | **c** | 仅更新 MANIFEST | 0 | 设备 sha = 仓 sha = `f82f3bf40639`(3397 B)；MANIFEST 仍记 `c5736ac0…`/1252 B（旧版）。**内容等价**。 |
| `/usr/local/sbin/usb-gadget` | **a+b 混合** | 手工合并后各自落地 | 24 | 仓：序列号锚定原厂 SN（PITFALLS #549，拒绝 `HA2CB1KY` 模板常量）；设备：仍硬编码 `HA2CB1KY` **但**多一个 `acm.GS1`（OOB root shell 通道）。**两边各有对方没有的东西**。 |
| `/usr/local/sbin/waydroid-session.sh` | **b** | 重部署 | 48 | 设备 265 B 只剩 `XDG_RUNTIME_DIR=/run/phosh` 硬编码 + `exec waydroid session start`；仓有 `pick_runtime_dir()` 等 socket（≤30 s）、`waydroid0` 网桥兜底、Session-RUNNING/Container-down 自愈。设备版在 Debian 根（`/run/user/1001`）直接失败。 |
| `/usr/local/sbin/waydroid-ui.sh` | **b** | 重部署 | 29 | 同上一半：设备 `XDG_RUNTIME_DIR=/run/phosh` 硬编码、无 socket 等待（autostart 会早于 phoc 建 socket）。 |
| `/etc/modules-load.d/elden-dma-heap.conf` | **b（仅注释）** | 重部署或忽略 | 2 | 设备只有 `system_heap` 一行；仓多 2 行注释（2026-11-21 libcamera dma-buf provider 说明）。**加载语义等价**。 |
| `/usr/local/bin/q28-race-hunt.sh` | **c** | 仅更新 MANIFEST（并另案记「设备未部署」） | 0 | 仓副本 `6166fc6f…`(8345 B) = 2026-11-16 的 `DMBASE_VB` 覆盖修复；MANIFEST 仍记 `036a6279…`(8122 B) = 初始导入 207e7077 版。设备上**根本没有此文件**（WARN gone）。 |
| `/usr/lib/systemd/system/greetd.service` | **b** | 重部署（render + override） | 27 | 设备是**发行版原件**（mtime 2025-04-08，`ExecStart=greetd`、`RestartSec=1`、无 `Environment=LIBSEAT_BACKEND=seatd`、无 pre-hook）；仓为渲染件（seatd/elogind 依赖、pre/stop hook、`RestartSec=5`、`WantedBy=multi-user.target`）。**override 从未落地**。 |
| `/usr/lib/systemd/system/iio-sensor-proxy.service` | **b** | 重部署（render + override） | 26 | 设备是发行版原件（`Type=dbus`、2025-07-26）；仓为渲染件（`Type=simple` + `ExecStartPre=…/iio-sensor-proxy.pre` 等 QRTR svc400，G1-34）。设备眼下该服务 **inactive**。 |
| `/usr/lib/systemd/system/qbootctl.service` | **b** | 重部署（render + override） | 24 | 设备是 systemd 上游 `systemd-bless-boot` 衍生件（`ExecStart=/usr/bin/qbootctl -m`、`RemainAfterExit=yes`、带 LGPL 头）；仓为渲染件（`ExecStart=/usr/local/sbin/qbootctl-mark.sh` + `EnvironmentFile`）。PITFALLS #181 的「无它约 7 次重启进 fastboot」保护口径以仓为准。 |

### 1.1 「调试残留 vs 真修复」判定

* **没有发现调试残留**：全部 14 份设备副本里无 `set -x`、无被注释掉的判据、无临时分支；
  唯一形似的是 `iio-sensor-proxy.service:9 #Environment="G_MESSAGES_DEBUG=all"`，那是**发行版原件自带**的注释示例。
* 设备侧唯一的「非上游改动」是 `config.toml` 的两行注释（重建期手写说明）与 `usb-gadget` 的 `acm.GS1` 通道。
  前者是**文档性**改动，后者是**运维便利**（OOB root shell，安全面需评审，见 §2.3）。
* 结论：这 19 个 FAIL 里 **12 个是「仓已修、设备没跟上」**，不是设备上有未回仓的修复。

### 1.2 附带的记录性缺陷（不产生 FAIL，但会让门禁失真）

1. `MANIFEST.tsv` 里 `/usr/local/bin/slot-attr.py` 与 `/usr/local/sbin/slot-attr.py` **同 sha 重复登记**，
   而设备上 `/usr/local/bin/slot-attr.py` 不存在（WARN gone）⇒ 两条登记有 1 条是幽灵。
2. `/usr/local/bin/{q28-race-hunt.sh, scale.sh, bwrap, …}` 一批 MANIFEST 行在设备上均不存在（WARN），
   说明这批 `/usr/local/bin` 资产在 2026-11-19 换根后整体未部署，MANIFEST 未跟上。
3. 3 个 unit 的漂移说明 Debian 根组装链**没有覆盖 `services.tsv` 的 override 单元**——
   这是比单个脚本漂移更结构性的缺口。

## 2. 建议的下一步动作

### 2.1 c 类（3 个，零风险，先做）：只改 MANIFEST 三行

* 谁：仓单写者（总管/`doc-audit` 授权下）在 `main` 上改 `packaging/elden-userland/MANIFEST.tsv`。
* 命令（改完自检）：
  ```
  bash packaging/elden-userland/tools/verify.sh --offline   # A 段 3 条 FAIL 必须归零
  bash packaging/elden-userland/tools/verify.sh elden       # F 段剩余应为 13
  ```
* **不要**用 `tools/sync-from-device.sh` 做这件事：它没有路径过滤参数，会**整份重采**
  `files/` 与 `MANIFEST.tsv`，把 §1 里 12 个「仓更新」直接回退成设备旧版（等于销毁修复）。
* 新值：`elden-session-user 015fbb3b…/3704`、`time-sync.sh f82f3bf4…/3397`、`q28-race-hunt.sh 6166fc6f…/8345`。

### 2.2 b 类（12 个）：走既有组装+安装链重部署，禁手工 scp

* 谁：`physical-exec`，**必须持设备锁**（`scripts/device-lock.sh`），且需用户放行写设备。
* 顺序与命令（先干跑）：
  ```
  scripts/device-lock.sh bash -c '
    bash rootfs/debian/stage.sh                    # 组 out/stage-debian（免 root，可重复）
    bash rootfs/debian/install-overlay.sh --dry-run
    bash rootfs/debian/install-overlay.sh          # 只写 LABEL=linux17
  '
  bash packaging/elden-userland/tools/verify.sh elden
  ```
* 风险：
  1. **`greetd.service` 会把当前正在跑的组合换掉**（设备现在是发行版原件，greetd `active`）。
     渲染件引入 `Environment=LIBSEAT_BACKEND=seatd`、`ExecStartPre`、`WantedBy=multi-user.target`——
     若 `seatd.service` 未在位或 pre-hook 失败，会从「现在能起」变成「起不来」。
     ⇒ 先确认 `seatd`/`elogind` 在设备上 enabled+active，再单独灰度这一个 unit。
  2. `iio-sensor-proxy.service` 现在 **inactive**，渲染件是 `Type=simple`+QRTR svc400 前钩子；
     换完需现场核 `HasAccelerometer`，否则会「看起来 active 但永远无 accel」。
  3. `slot-attr.py` 换代后 **必须跑 `--selftest`**（合成 GPT：show / 主备同改 / 缺条目必拒）；
     设备旧版只改主表，任何「拿旧版 mark-successful」的历史操作都应视为主备可能不一致。
  4. `install-overlay.sh` 默认 `LABEL=linux17`，现役是 `_b` 槽——**确认内核对得上再动手**，
     否则会写到一个不启用的根上（本次设备 `elden_root=LABEL=linux`、`slot_suffix=_b`）。
* 部署后复验（只读）：`verify.sh elden` 的 F/F2 段应只剩 c 类与 `usb-gadget`。

### 2.3 a 类 / 混合（2 个）：一次人工合并，然后双向收口

* `config.toml`：设备的两行注释有价值（记录了 2026-11-19 minbase 重建与 pam_systemd 事实）。
  ⇒ 由单写者把这两行**手工并进** `files/etc/greetd/config.toml` 并更新 MANIFEST（等价于 sync-from-device，但只这两行）。
* `usb-gadget`：**必须人工评审再合**，两侧都别直接覆盖：
  * 取仓的 SN 锚定逻辑（PITFALLS #549 是真修复，硬编码 `HA2CB1KY` 会让同型号多机在
    `192.168.7.1` 固定 IP 下按 iSerialNumber 认错设备）；
  * 评审设备侧 `acm.GS1`（getty OOB root shell over USB，`/dev/ttyACM1`）是否**要保留**：
    它是永久性、免认证的 root 通道，属安全面决策，不能当作 drift 顺手带进仓。
  * 决策后一次改 `files/usr/local/sbin/usb-gadget` + MANIFEST，再随 §2.2 下发。

### 2.4 门禁侧的长期修法（可选，交总管定）

`verify.sh` 目前把「MANIFEST 过期」和「设备落后」都记为 FAIL，二者处置完全不同。
建议后续在 A 段单独出一行统计（`副本 sha ≠ MANIFEST: N`）并在报告里标注「仅清单过期」，
避免每次审计都要人工重算三类；本次不改 `packaging/`，仅记建议。

## 3. 证据与复现

* 设备副本采集脚本：`reports/artifacts/userland-drift-20261121/fetch-device-copies.sh`（`ssh -n … sudo -n cat`，只读）
* 门禁原始输出：`reports/artifacts/userland-drift-20261121/verify-elden-20261121.txt`
* 逐文件 diff：`reports/artifacts/userland-drift-20261121/<basename>.diff`（14 个；两个等价文件无 diff）
* 复现：
  ```
  timeout -k 10 300 bash packaging/elden-userland/tools/verify.sh elden | tee /tmp/v.txt
  grep FAIL /tmp/v.txt
  bash reports/artifacts/userland-drift-20261121/fetch-device-copies.sh        # 只读拉取
  for f in reports/artifacts/userland-drift-20261121/*.diff; do cat "$f"; done
  ```
