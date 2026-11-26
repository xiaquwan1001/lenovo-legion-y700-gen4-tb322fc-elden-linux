# 工单 S：`hexagonrpcd -s` 开机即硬崩的根因分析与落地路线（2026-11-26）

> 授权边界执行情况：主机只读 + 网络只读 + 设备**只读** ssh（192.168.7.1，在机 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`）。
> 本轮未 start/enable/unmask 任何 unit、未写盘、未 insmod/rmmod、未 fastboot；所有外部命令套 `timeout -k`。
> 唯一写入 = 本文件（过程稿 `.pi/lanes/20261126-sensors-692.md`）。**不 git commit**。
> 状态词：全文只区分「实测 / 静态推断 / 未证实」。

---

## 0. 结论先行

**`-s` 本身不发任何文件——它只是一次 `ioctl(FASTRPC_IOCTL_INIT_ATTACH_SNS)`，把守护进程挂上 ADSP 里的 sensors PD（sensorspd）；随后 sensorspd 立即（~1 s 内）通过 FastRPC 反向调用向 AP 要文件并写 registry，而上游 hexagonrpcd（Debian 在装 0.3.2 与 main 均同）既没有写支持也没有 >256 B 输入缓冲能力。同时本机内核还踩中一条未修复的 fastrpc 驱动 bug：DT 给 compute-cb 配了 `reg=3..8`（sid 非零）时，SENSORS_PD 的消息缓冲被分配进 context bank 而非 ADSP remote heap——lore.kernel.org 2026-10 的补丁（R-b Baryshkov）证明这会让 sensors PD 第一次 RPC 就 SMMU context fault。** 两条缺陷链都发生在 attach 后第 1 秒内，与 #692/#732 的「start 后 SSH 立断」时序吻合。三台同构设备（SM7635 Milos、SG6275P Retroid、X1E80100 SP11）+ 一条内核补丁线程构成上游同族证据；其中 Retroid Pocket G2 与本品同样是「sensorspd 挂 ADSP + fastrpc-adsp」结构，其实测「config 缺输出路径 ⇒ ADSP fault ⇒ 设备重启」是目前对整机硬崩最贴近的先例。**根因双缺陷（内核缓冲分配 + 守护进程无写支持）为高置信静态推断，均未在本机上机证实**——本机所有崩溃通道（pstore/journal/USB）在硬崩时全部失效（#366/#733/#692），证实必须先建取证通道或带补丁内核。

---

## 1. 判据一：`-s` 到底向 ADSP 发了什么

### 1.1 调用链（源码实测：github.com/linux-msm/hexagonrpc，main=da7a374；Debian 0.3.2 同）

> 勘误：工单所给「Codeberg `DylanVanAssche/hexagonrpcd`」**不成立**——Codeberg API 列举 DylanVanAssche 名下仓库只有 libssc/supl-server/imsd 等，无 hexagonrpcd。hexagonrpcd 的真上游 = **github.com/linux-msm/hexagonrpc**（Debian 源包 src:hexagonrpc；binary hexagonrpcd 0.3.2-2）。libssc 确已迁 Codeberg（v0.4.4）。

```
hexagonrpcd -f /dev/fastrpc-adsp -d adsp -s -R <R>
  └─ open("/dev/fastrpc-adsp")                     # rpcd.c:417
  └─ ioctl(fd, FASTRPC_IOCTL_INIT_ATTACH_SNS)      # rpcd.c:422（-s 即此，"Starting … (INIT_ATTACH_SNS)"）
       └─ 内核 drivers/misc/fastrpc.c:2186-2187
            fastrpc_init_attach(fl, SENSORS_PD=2)
            → fastrpc_internal_invoke(fl, true, FASTRPC_INIT_HANDLE,
                  FASTRPC_SCALARS(FASTRPC_RMID_INIT_ATTACH,1,0), args{client_id})
            ⇒ 向 ADSP root PD 发一条「attach 到 sensors PD」的 RPC（1 个入参）
  └─ register_fastrpc_listener()                   # 注册 adsp_default_listener
  └─ run_fastrpc_listener()                        # 监听循环：DSP→AP 反向调用
       ├─ remotectl（本地接口表）
       ├─ apps_std（远程文件 I/O：open/openat/read/stat/opendir/…）
       └─ apps_mem（DSP 内存分配/映射）
  ⇒ 之后 sensorspd 以反向调用从 <R> 取文件（served files）
```

- 文件**不是**由 `-s` 主动推送的；是 attach 成功后 sensorspd 反向来取。attach 与取文件是两个阶段。
- `-R`（served root）在两个版本里的期望物理布局（`rpcd_builder.c` construct_root_dir，0.3.2 与 main 逐字一致）：

| DSP 侧看到的虚拟路径 | 物理来源（`<R>` = served root） | 缺失行为 |
|---|---|---|
| `/vendor/etc/sensors/config/` | `<R>/sensors/config/` | map_or_empty（可缺） |
| `/vendor/etc/sensors/sns_reg_config` | `<R>/sensors/sns_reg.conf`（**文件名带点**，非 Android 的 `sns_reg_config`） | **hfs_map 必须存在**，缺失 ⇒ open 失败返回 DSP |
| `/persist/sensors/registry/registry`（与 `/mnt/vendor/persist/...` 双挂） | `<R>/sensors/registry/` | 目录则 DSP 可读 registry 条目 |
| `/vendor/etc/acdbdata/acdbdata` | `<R>/acdb/` | 映射文件 |
| `/sys/devices/soc0/` | `<R>/socinfo/` | map_or_empty |
| `/usr/lib/qcom/adsp/` | `<R>/dsp/adsp/`（`-d adsp`） | map_or_empty |

- attach 后第 1 秒内 DSP 会做的 registry 工作（SP11 实测记录，静态引用）：写 `registry/DIR` 标记、`sns_secure_database.bin`、经临时文件改名写 `parsed_file_list.csv`；需要 **fopen 写模式、fwrite、fsync、fremove、ftrunc、frename**（apps_std 方法表里 0.3.2/main 全部为空实现，listener 对不支持方法回 `AEE_EUNSUPPORTED`），且这些请求的**输入缓冲 >256 B**——main 的监听循环 `listener.c:458` 遇 `inbufs_len > 256` 直接 `"Large (>256B) input buffers aren't implemented"` 并退出线程。0.3.2 同样有此 256 B 上限（listener.c:177）。
- 本机 Debian 包面（设备实测）：`/usr/bin/hexagonrpcd` = wrapper 脚本，默认 `device=/dev/fastrpc-adsp`、`dsp=adsp`、`fw_dir=/var/lib/droid-juicer/sensors/`、`extra=-s`；真二进制 `/usr/libexec/hexagonrpc/hexagonrpcd`（0.3.2）。unit `hexagonrpcd.service` = `RestrictAddressFamilies=none` + `PrivateNetwork=yes`（需 drop-in 放开 AF_QIPCRTR，已知件）。

## 2. 判据二：设备上缺不缺这些文件（设备实测）

| 位置 | 现状 | 判定 |
|---|---|---|
| `/usr/share/qcom/`（默认 served root） | **不存在** | `-R` 缺省时全空 |
| `/var/lib/droid-juicer/sensors/`（11-26 崩溃那次 `-R` 指向的） | 存在，3.3 MB，但为 **Android 布局**（`vendor/etc/sensors/{config,sns_reg_config,hals.conf}` ×143 + `mnt/vendor/persist/sensors/registry/registry/` ×345 树）；是 11-26 08:32 从 `backup/stock-elden/vendor-etc-sensors` + persist 分区内容**手工拼的**，droid-juicer 本体从未运行（masked） | **布局与 hexagonrpcd 期望不匹配**：`<R>/sensors/sns_reg.conf`、`<R>/sensors/config`、`<R>/acdb`、`<R>/socinfo`、`<R>/dsp/adsp` 全都不存在（文件在 `<R>/vendor/etc/sensors/` 与 `<R>/mnt/vendor/persist/` 下） |
| droid-juicer 应产出的布局（包内 `google,sargo.toml` 实文） | `<R>/dsp`、`<R>/acdb`（=vendor/etc/acdbdata 改名）、`<R>/etc/sensors`、`<R>/sensors/registry/registry` | **连官方 toml 也与 hexagonrpcd 0.3.2/main 对不上**（`etc/sensors` vs `sensors/config`；无 `sns_reg.conf` 改名）；本机无 sm8750 toml（devices.d 仅有 sargo/fp4/fp5/blueline/bonito-sdc/spacewar） |
| `/persist`（分区 sda6） | 存在但 Linux 侧**未挂载**；registry 内容已抽出在 `/var/lib/droid-juicer/sensors/mnt/...` | 数据在手，无丢 |
| `/lib/firmware/qcom/sm8750/` | 96 文件：`adsp.mdt`(8364 B) + `adsp.mbn.zst`(6.3 MB) + adspr/sps/ua/uo.jsn 等；dmesg 实测 remoteproc 正常 boot adsp | **ADSP 固件在位**；`find … '*sensor*' -o '*sns*'` = 0 ⇒ 无 sensor 专属固件文件（sensorspd 在 adsp 固件内，开机即注册 qrtr svc 400） |
| `/vendor/firmware` | GPT 手术后已删除 | 不存在（符合预期，D22 已记录） |
| Android 侧对照（仓内 `backup/stock-elden/vendor-etc-sensors`） | 143 文件齐全；`sns_reg_config` 实文：`version=1 / file=input=json.lst / file=output=/mnt/vendor/persist/sensors/registry/registry` | config 数据面齐全，缺的只是**布局重组 + 可写 registry + 会写的守护进程** |

**小结**：固件不缺；缺的是三件——①按 hexagonrpcd 期望布局重组的 served root（含 `sns_reg.conf` 改名）；②一个**可写**的 registry 树（DSP 每次启动要写 DIR 标记/secure db/parsed_file_list）；③**支持写**的 hexagonrpcd（上游没有，见 §4）。

## 3. 判据三：崩溃时序能推出什么（三种假说的区分）

### 3.0 取证基线先修正（本轮新事实，覆盖 #692 的旧推理）

- **#733（2026-11-26 实测）**：本机 DDR 内容不跨复位存活（ramoops ECC 780/780 不可恢复，换地址逐字相同）⇒ **「pstore 空 / journal 无 Oops」不能再当「不是 AP 侧 panic」的证据**。#692 现场报告里该推理作废。
- 已知时序硬事实：start 后 SSH 立断（<10 s）；用户目视「phosh 转圈 → 整机掉电」；~1 min 自回 Linux（= 复位而非长挂）；journal 持久部分只到启动第 1 s（异步 flush 特性，非崩溃时刻）；USB gadget 随崩一起消失。

### 3.1 假说与可信度（全部静态推断，0% 已证）

| # | 假说 | 可信度 | 依据 |
|---|---|---|---|
| A | **内核 fastrpc SENSORS_PD 消息缓冲分配 bug**：本机 ADSP compute-cb `reg=3..8`（sid 非零，DTB+in-tree dtsi 双证）+ 在机代系内核 `fastrpc_get_args` 未含 `&& pd != SENSORS_PD` 修复 ⇒ INIT_ATTACH_SNS 的第一条 RPC 的消息缓冲被分配进 context bank（SMMU IOVA），而 sensors PD 直连该缓冲 ⇒ SMMU context fault / bus stall ⇒ sensors PD fatal ⇒ 平台级复位 | **高（~85%）** | lore 补丁在 SM8150 两台机器实证同签名（attach 即 `fsr=0x402 iova=0x1fffff000` → `PDM: service 'sensor_process' crash` → crash detected）；解释秒级崩溃、**与 served 文件内容无关**（11-19 那次 served root 全空也一样崩） |
| B | **hexagonrpcd 无写支持/无 >256 B 缓冲 ⇒ sensorspd registry 工作失败 ⇒ ADSP fatal ⇒ 整机复位** | **中（~55%，与 A 叠加）** | 三平台实证：#19（Milos 要写 `…/registry/DIR`）、SP11（refused write aborts the whole ADSP）、**Retroid SG6275P（与本品同构：sensorspd 在 ADSP + fastrpc-adsp）「config 缺输出路径 ⇒ ADSP fault `EX:qsh_process:sns_registry_4` ⇒ 设备重启」**；时序吻合（attach 后 1 s 内做 registry 工作）。注意：即使 A 修好，B 也在崩溃面上（SP11 证明 registry 工作一开始就会来） |
| C | AP 侧 SMMU/内核 panic（其它路径） | 低-中（~15%，不可排除） | #733 之后「无 Oops」失去证明力；但无独立证据指向具体机制。remoteproc recovery=enabled 下 DSP fatal 通常走 SSR 而非 AP 死，C 需要额外机制才能解释整机掉电 |

说明：「ADSP watchdog / 固件自毁」与 A/B 是同一故障链的两种命名（DSP 侧 fatal 的触发表述）；真正需要区分的是**「DSP fatal 引发的复位」vs「AP 侧 panic」**，以及 A 与 B 谁是第一击。三假说与「5 次开机循环」全部兼容（hexagonrpcd 当时 enabled，每次开机必跑 `-s`）。

### 3.2 区分方案（每条标注崩溃风险）

| # | 方案 | 能区分什么 | 崩溃风险 |
|---|---|---|---|
| 1 | **先打内核补丁再试**：把 lore 的 1 行修复（`if (ctx->fl->sctx->sid && ctx->fl->pd != SENSORS_PD)` 走 remote heap）打进 vk 新内核，`fastboot boot` 零写盘；补丁内核上 `timeout -k 5 30 hexagonrpcd -f /dev/fastrpc-adsp -d adsp -s`（无 served root 也行） | 存活 ⇒ A 被证实并已修复；仍崩 ⇒ 排除 A，指向 B/C | **不零**（仍在 `-s` 崩溃面上），但这是直接检验第一假说的最短路径；补丁有 SM8150 两台机器实证 + R-b |
| 2 | **不带 `-s` 的 attach**：`timeout -k 5 30 hexagonrpcd -f /dev/fastrpc-adsp -d adsp`（INIT_ATTACH = ROOT_PD，msg buffer 走 context bank 是标准路径，adsprpcd 全球同款流程） | 存活 ⇒ fastrpc 通道/监听循环/反向调用本身健康，崩溃面收敛到 SENSORS_PD；同时验证 served-root 布局改动无副作用 | **基本零**（不触碰 SENSORS_PD；严格说仍是本机第一次真实 DSP RPC，非绝对零） |
| 3 | **`-s` + served root 指向空目录**（工单原提议） | 若修完 A 后仍崩，用它区分「attach/传输层」vs「文件服务/内容」 | **不零**——带 `-s` 就在崩溃面上；只是去掉文件变量 |
| 4 | **物理 UART**（非 USB gadget）抓最后一屏 + `dmesg -w` 落盘 | 唯一能区分 C（AP panic 栈）与 A/B（DSP 侧 SMMU/fatal 行）的通道；#733 已证 pstore/ramoops 在本机不可用，kdump 只覆盖 panic 不覆盖硬复位 | 零（纯观测） |
| 5 | `earlycon` | 同 4，需物理串口机位；USB gadget（ttyGS0）随崩消失，无增量价值 | 零（纯观测） |

**推荐顺序**：4（若用户有 UART 机位，先建）→ 2（零崩溃面收敛）→ 1（补丁内核，需构建+放行）→ 剩余二分（3 及 registry 面）放在 1/2 结论之后。

## 4. 判据四：上游同类崩溃报告（均有原文出处）

| 出处 | 内容要点 |
|---|---|
| **linux-msm/hexagonrpc issue #19**（2026-01-30，z3ntu，Milos/SM7635；全文本轮抓取） | 「ADSP 试图以写模式打开 `/mnt/vendor/persist/sensors/registry/registry/DIR`」，无写支持则传感器全不工作。后续评论：wompix（2026-11-06，**Retroid Pocket G2 / SG6275P，stock adsp.mdt、mainline 7.3 内核、sensorspd 在 /dev/fastrpc-adsp——与本品同构**）：该固件无**可写 registry** 就拒绝启动；「config 缺输出路径使 ADSP fault（`EX:qsh_process:sns_registry_4`）**并使设备重启**」；PR #26/#27 真写支持实测 accel 398 Hz/gyro 798 Hz 出数、深度 suspend 存活。另条 gotcha：daemon 起不来 + systemd 循环重启时，ADSP sensor 进程会保持不可用直到重启 |
| **FadyAckad/fedora-linux-surface-pro-11 docs/sensors.md**（X1E80100 SP11，2026-11-23 更新；raw 本轮抓取） | 「**A refused registry write aborts the whole ADSP**：upstream 的 daemon 拒绝 `fopen(.../registry/registry/DIR, w)` 并在 method 24（`apps_std_fremove`）退出 ⇒ `crash detected in adsp` + 每 5 s crash-restart 循环（CDSP 连带、电量图标抽风）」；registry 工作需 >256 B 输入缓冲（upstream 不支持即退）；framework 按 sns_reg_config 里的 mtime 戳校验 config，不匹配即全量重解析；fork（branch sp11-sensors，head 40e5041）补：mapped 目录写支持（fopen 写模式/fwrite/fsync/fremove/ftrunc/frename）、unsupported 回 AEE_EUNSUPPORTED 不退出、>256 B 缓冲（adsp_listener_get_in_bufs2）、persist 树映射。维持者 lumag 指导：真写入应放 /var 下可写目录，/usr/share/qcom 应保持只读并大声失败 |
| **lore.kernel.org/linux-arm-msm**（检索 2026-11-26；直连 403，经 Firecrawl 代理成功） | `[PATCH v2] misc: fastrpc: Allocate message buffer from remote heap for sensors PD`（Robin Snyders / Piyush Raj Chouhan，2026-10-02/03，R-b Dmitry Baryshkov）：SM8150 SLPI 上 hexagonrpcd attach sensors PD 即 SMMU context fault（`fsr=0x402, iova=0x1fffff000`）→ `PDM: service 'sensor_process' crash` → `crash detected in slpi`；修复 = SENSORS_PD 的消息缓冲强制走 remote heap（1 行）；修后 attach 干净、QRTR svc 400 出数。补丁待并入主线（截至检索日未见 applied 记录） |
| **hexagonrpc PR #13 / #21 / #26 / #27** | #21 = 写 stub（draft）；#13 = 方法定义格式重构；#26/#27 = 真写支持（wompix 接手，基于当前 main da7a374 + `-S DIR` 状态目录选项，`/var/lib/hexagonrpcd` 种子化）；FadyAckad 已关闭自己的 PR（#27 前身），待续 |
| **lore 上 hexagonrpcd 其余检索** | 无更多「attach 即整机硬崩」的同名报告；lore 命中的 `sm8750 ADSP fastrpc non-secure-domain` 补丁串（Qianhui Xu, 2026-11）即 D22 已在机的那条，与本崩无关 |
| **codeberg libssc issues** | 未逐条翻（libssc 是 QMI 客户端，不在 fastrpc 崩溃面；其 docs 明说 Android 参考守护进程 sscrpcd 负责「读 /mnt/persist/vendor/ 与 /vendor/etc/sensors 并执行 FastRPC ioctl」） |

## 5. 判据五：不走 `-s`，SSC 能不能拿到 registry

**不能（静态 + 源码双证）。**

- registry 的**消费者在 DSP 侧**：sensorspd 通过 FastRPC 反向文件服务（apps_std）读 `<R>/sensors/sns_reg.conf` 指定的输入清单（json.lst → config json）并把 registry 输出写到 served 的 `/persist/sensors/registry/registry` 树。libssc docs 的 Android 参考实现 `sscrpcd` 即「读 /mnt/persist/vendor/ 与 /vendor/etc/sensors，执行 FastRPC ioctl」；Android 下 `sns_reg_config` 的 `file=output=/mnt/vendor/persist/sensors/registry/registry` 由同一条反向写链路落盘。
- **libssc 无 AP 下发 registry 的 API**：`grep -rn fastrpc libssc-src` = 0 命中；libssc 只经 QRTR 发 QMI（SUID/Config/Report）。`'registry'` 在 libssc 里只是 SUID 发现请求的 `data_type` 哨兵（`libssc-sensor.c:302`），用于探测「sensorspd 是否已完成配置加载」——它不可用 = sensorspd 没吃到 served files（与 11-26 设备实测 `registry unavailable after 30s` 一致）。
- **droid-juicer 的作用面**：只是装根时的**提取器**（把 vendor/persist 的传感器文件抽到 `/var/lib/droid-juicer`，见其 sargo toml），自己不与 DSP 通信；消费方只有 fastrpc 守护进程（Android: sscrpcd；Linux: hexagonrpcd）。
- ⇒ **AP 侧直接供给路线不存在**，故无「最小验证命令」；最小的正向验证 = 先让一个会写的 hexagonrpcd 带正确 served root 跑起来（依赖 §6 计划）。libssc/ssccli 侧的「svc 400 可用性」单点检查（零 fastrpc 依赖，但只证明服务在册，不证明 registry）：
  `timeout -k 3 15 ssccli --sensor accelerometer --timeout 10`（预期 `registry unavailable`，因为无守护进程）。

## 6. 收尾三块

### 6.1 根因假设排序（带可信度，全部未上机证实）

1. **【85%，静态】内核 fastrpc SENSORS_PD 消息缓冲走 context bank 而非 remote heap**（本机 sid=3..8 非零 + 在机内核未含 lore 2026-10 修复）⇒ 首条 SENSORS_PD RPC 即 SMMU context fault ⇒ sensors PD fatal ⇒ 整机复位。解释：秒级崩溃、served root 内容无关（11-19 空根也崩）、5 连循环（enabled 必跑）。
2. **【55%，与 1 叠加】hexagonrpcd 无写支持 + 无 >256 B 缓冲 ⇒ sensorspd registry 工作失败 ⇒ ADSP fatal ⇒ 整机复位**。三平台实证；修好 1 之后它仍会触发（SP11 证明 registry 工作在 attach 后立刻开始）。**两个都要修，只修其一大概率仍在崩溃面上。**
3. **【15%，不可排除】AP 侧 panic**：#733 证伪了「pstore 空 ⇒ 非 panic」的旧推理；无独立证据，需物理 UART 才能排除。
4. 旧候选「ADSP 固件自毁/版本不符」：降权——固件在位且 Android 侧同套固件跑 sensorspd 正常（c0-baseline 42 传感器）；崩溃有明确的两条软件缺陷链可解释，无需固件假设。

### 6.2 零崩溃风险验证计划（按序；带 `-s` 的步骤标注了风险）

| 步 | 动作 | 风险 | 判据 |
|---|---|---|---|
| V0 | （可选，用户有 UART 机位时）接物理串口 | 零 | 崩溃最后一屏可见 |
| V1 | vk 新内核 = 在机树 + lore 1 行 SENSORS_PD 补丁；`fastboot boot` 零写盘 | 构建侧零；上机零写盘 | `uname -r` 为新版本；dmesg 无新告警 |
| V2 | 补丁内核上：`timeout -k 5 30 hexagonrpcd -f /dev/fastrpc-adsp -d adsp`（**无 -s**） | 基本零 | 进程存活、journal 无 SMMU/remoteproc 异常 ⇒ 通道健康 |
| V3 | 同内核：`timeout -k 5 30 hexagonrpcd -f /dev/fastrpc-adsp -d adsp -s`（单次、保持 masked 状态用裸命令跑、不做 unmask、dmesg -w 落盘、人在场可 POR） | **有**（崩溃面本体；这是计划中唯一不零的步） | 存活 ⇒ 假说 1 证实并修复；崩 ⇒ 停手，转 V0 取证 + 假说 2/3 |
| V4 | 只有 V3 存活后才动文件面：按 §1.1 布局重组 served root（`sensors/sns_reg.conf` 改名、config、registry 双挂）+ 换 write-support hexagonrpcd（wompix #27 commits on da7a374 + `-S DIR` 状态目录） | 中（新代码面） | ssccli 出数 / iio-sensor-proxy `HasAccelerometer=true` 三真 |
| 全程 | `hexagonrpcd{,-suspend,-resume}` 保持 masked（现安全态）；试 `-s` 一律裸命令单次、先 disable 口径（#732 铁律）、失败即停不再重试 | — | — |

### 6.3 若不可行的止损口径

- **取证通道（物理 UART）与补丁内核（V1）两者都不具备时，不做任何形式的 `-s` 尝试**——这是 #692/#732 两次实测换来的硬门；hexagonrpcd 维持 masked = 已验证的安全态（qrtr svc 400 在册、系统正常、只是无加速度计）。
- 若 V3（补丁内核）仍崩：停手保现场（保留补丁内核 boot 镜像 hash + 崩溃后 `journalctl -b -1` 尾部），**必须先建物理 UART** 才允许继续；同时把「TB322FC 上 SENSORS_PD remote-heap 补丁无效」作为新事实上报，并在 linux-msm/hexagonrpc #19 / lore 补丁线程补一条设备样本（发信按用户放行口径）。
- 功能止损：加速度计恢复不设 deadline；在止损状态下，自动旋转等上层功能维持 D16 的「故意关闭」口径，不投入绕行方案（用户态绕开已被 11-26 实测否证）。

---

## 附：每条判据的复现命令

```sh
# 判据1（主机，只读网络）
git clone --depth 5 https://github.com/linux-msm/hexagonrpc.git /tmp/hexagonrpc-src
sed -n '417,430p' /tmp/hexagonrpc-src/hexagonrpcd/rpcd.c          # INIT_ATTACH_SNS ioctl
sed -n '28,105p'  /tmp/hexagonrpc-src/hexagonrpcd/rpcd_builder.c  # served-root 虚拟↔物理映射表
sed -n '455,467p' /tmp/hexagonrpc-src/hexagonrpcd/listener.c      # >256B 输入缓冲退出
curl -sSL https://github.com/linux-msm/hexagonrpc/archive/refs/tags/v0.3.2.tar.gz | tar xz   # Debian 同源版
# 设备（只读）
timeout -k 3 25 ssh elden-root 'cat /usr/bin/hexagonrpcd; /usr/libexec/hexagonrpc/hexagonrpcd --help 2>&1 | head'

# 判据2（设备只读）
timeout -k 3 25 ssh elden-root 'ls /usr/share/qcom 2>&1; find /var/lib/droid-juicer/sensors -maxdepth 4 | head -20; \
  ls /persist 2>&1; ls /lib/firmware/qcom/sm8750 | wc -l; find /lib/firmware/qcom -iname "*sns*" -o -iname "*sensor*" | wc -l'
timeout -k 3 25 ssh elden-root 'cat /usr/share/droid-juicer/configs/google,sargo.toml'   # droid-juicer 期望布局

# 判据3（仓内核 + 设备只读）
cd /home/xuqianhui/y700-elden/geekidos-linux
git show reb731/m4/v3-keep-1793243164:drivers/misc/fastrpc.c | sed -n '1100,1106p'   # if (ctx->fl->sctx->sid) buf_alloc …（未修复）
git show reb731/m4/v3-keep-1793243164:arch/arm64/boot/dts/qcom/sm8750.dtsi | sed -n '2292,2297p'  # compute-cb reg=<3>
timeout -k 3 25 ssh elden-root 'od -An -tx4 /proc/device-tree/soc@0/remoteproc@6800000/glink-edge/fastrpc/compute-cb@3/reg; \
  cat /sys/class/remoteproc/remoteproc0/recovery'

# 判据4（只读网络）
curl -sSL https://github.com/linux-msm/hexagonrpc/issues/19            # Milos + Retroid 实测
curl -sSL https://raw.githubusercontent.com/FadyAckad/fedora-linux-surface-pro-11/main/docs/sensors.md
# lore：直连 403，走代理抓 https://lore.kernel.org/linux-arm-msm/?q=hexagonrpcd
#   → <20261003150559.6926-2-pc1598@mainlining.org>（SENSORS_PD remote-heap 补丁 v2 全文含 diff）

# 判据5（主机源码 + 设备只读）
git clone --depth 3 https://codeberg.org/DylanVanAssche/libssc.git /tmp/libssc-src
grep -rn fastrpc /tmp/libssc-src --include='*.c' | wc -l               # 0 命中
sed -n '302,306p;655,672p' /tmp/libssc-src/src/libssc-sensor.c          # 'registry' = SUID 哨兵
```
