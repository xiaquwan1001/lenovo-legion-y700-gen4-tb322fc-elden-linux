# 工作区索引 — TB322FC "elden"（SM8750P）固件与驱动研究

> **入口。** 新会话：**§0（现在一页）→ §2「入口阶梯」**（含时间序权重）→ 需要细节再进对应文档/专题档案。
> **唯一入口 = 本文件**；根目录 = 入口 `INDEX.md` + 项目身份 `AGENTS.md` + 公开 `README`/`PROGRESS`（**公开门面，agent 默认不读**），**7 个角度文件夹**（`DEVICE/` `TASKS/` `RESOURCES/` `RUNBOOK-BRINGUP/` `PITFALLS/` `SESSIONS/` `HISTORY/`），各自 `README.md`（策展 SSOT）+ `sessions/`（会话进度）；标准见 §2。
> 2026-10-03：git 纳管 + 文档收敛（12→6）；自检 `scripts/check-doctor.sh`；不再有 SQLite/生成物。

---

## 0. 现在一页（**唯一的状态入口**；核对日期：2026-11-27（15:0x CST 续轮 #5：§4.0 叙事下沉））

> **★ 2026-11-27 续轮 #5（D6③ 第一批：§4.0 叙事下沉）**：`TASKS/NEXT.md` **28,906 → 21,107 B（−7,799 B / −27%）**，6 个早于 11-26 的 `★` 过程叙事块逐字搬
> `TASKS/sessions/2026-11-27-TASKS-4-久积叙事下沉.md`，原位留一行指针。父代理复核 = 6/6 块在旧文里连续子串、新文逐行不再出现；维度表 24 行与 `T 行 17` 逐字节未动；
> `§4.1 之后` 段 md5 两版相同。残留 = `TASKS/GAPS.md`（§5）与 `TASKS/UPSTREAM.md`（§7，9 个块）同范式下沉。全账 `reports/tasks-next-sink-20261127.md`。

> **★ 2026-11-27 续轮 #4（脚本引用面 T14+T16 收口；零设备）**：T16 把 62 条误分类全部重判 —— **① 退役 37**（脚本头 `RETIRED 2026-11-27：<原因/替代件/可复核报告>`，不删文件）+ **② 补指针 25**
> （`RESOURCES/README.md` §5 新增 25 行、新立 4 个面）；**父代理独立复算：`scripts/` 零引用脚本 = 0**，抽查 4 条退役理由的可复核报告全部存在且真提到该脚本。
> 至此 `scripts/` 363 个入口：活面文档命中 193+、其余全部有「退役头注」或「角度指针」两种落点之一，不再有「只能靠生成索引找到」的哑件。全账 `reports/scripts-ref-audit-t16-20261127.md`。

> **★ 2026-11-27 续轮（T14 脚本引用面前半段 + 父代理降档；零设备）**：按 A7 口径复算 —— `scripts/` **363** 入口、14 份活面文档命中 **193（53.5%）**；
> **审计的「7 条死引用」经父代理逐个 `test -f` 复核 = 5 条误报**（`archive/…-retired-scripts/`、`env-pass/scripts/` 的尾部 `scripts/` 被正则当仓根，文件都在盘），
> 另更正一条与盘上事实相反的旧错述（「q28 取证脚本本机已无」）。落地 = `RESOURCES/README.md` **§5 脚本角度指针 49 行** + 3 个一次性件 `RETIRED` 头注（不删文件）+ 死引用归零。
> **降档依据（反例）**：131 条「保持私有」里只有 **69** 条真有非注释调用点（10 条仅被注释提到、**52 条零引用**）⇒ T14 判「部分完成」，残留登记 **T16（62 条重判）**。
> 全账 `reports/scripts-ref-audit-20261127.md`（含父代理复核节与复现命令）。同轮 D10 复扫：人 0 / 机器人 0；PR #31 CI 仍 `action_required`（窗口内连新 run 都没有，我方无 push 权限点不了 Approve）。

> **★★ 2026-11-27 午间轮（四 lane 收口 + 文档核实 + 判据门加固，**零设备接触**）**
> **设备离线**：`adb devices` 只有 `10AF5J0FHQ0039G`（vivo V2454A）、`fastboot devices` 只有 `MDX5T20730009849`（P40pro），U2 `HA2EXB0E` 无 ssh ⇒ 本轮全主机侧。
> ① **文档核实**（父代理逐条重跑，不采信文档自述）：T11 其实早已由 `ca787f3f` 落地（INDEX 122 744 → 44 416 B）、T10 数字由 158/694 更正为 **165/706**、
> 审计 A11 的 24 个 `.pi/agents/*.bak-alias-1112` 已不在盘 ⇒ **A11 结项**、审计 A7（scripts 孤儿 ~166 + 死引用 7）此前漏进台账 ⇒ 新开 **T14**；全部落 `reports/arch-audit-20261127.md` 新 §7。
> ② **T9 用户态镜像门交付**：`scripts/check-userland-mirror.sh`（三态 + `--selftest`）+ doctor **§32** 接 `verify.sh --offline`；
> 现查 同 sha 配对 **20** ｜ 白名单漂移 **14 对 = 13 组** ｜ 未登记漂移 **0** ｜ 设备专有件 78（父代理自行 sha256 复算一致）。残留 = 13 组「谁是权威」需用户裁定
> （反直觉三条：`init`/`time-sync.sh`/`net-up.sh` 是 **`files/`（设备快照）更新**）。`reports/userland-mirror-gate-20261127.md`。
> ③ **T10 收口 710/710**，但过程抓到**假绿**：子代理把 165 行写成同一句模板用途（字数够、零信息）⇒ 父代理加固判据（空句黑名单 + 同句复用 >3 次作废 +
> 行点名 >4 个报告需另附 ≥40 字说明 + 路径 token 正则收紧），重扫露出 32 篇后逐篇改用报告自身 H1 标题 ⇒ `--check` rc=0 / `--selftest` 15 条断言。
> 教训入库 `PITFALLS #745`。索引 10 篇在 `TASKS/sessions/2026-11-27-reports索引-*.md`。
> ④ **D10 复扫（窗口 11-27T01:10Z→03:2xZ）**：人类 **0** / 机器人 **0** / 我方新增欠账 **0**；四个在飞系列**内容级全未进树**（next-20261126 `a9c48428cbd8`、torvalds 7.4.0-rc4）；
> `hexagonrpc` PR #31 = OPEN / `MERGEABLE`+`UNSTABLE`、+1279−81/17 文件/6 提交、reviews 0/comments 0、**`Build+test` 5 次全 `action_required`**（首次贡献待维护者批准，非我方问题）。全账 `reports/comm-triage-20261127-b.md`。
> ⑤ **D24 第二轮（主机侧）**：上游 open **33**、fork **29**；四条缺陷只有 1 条被既有 issue 覆盖（`#48`）；**「宿主缺 `denial_text_input_panel_manager_v1`」被否证**（上游用普通 `zwp_text_input_v3`）⇒ 改 T3 判据；
> 裁决 = **不整包跟 fork，只 cherry-pick 4 条 patch**（`patches/local/`）+ **先把 49 升到上游 51 再判 IME**（`4df8af9`）。`reports/droidloom-upstream-cluster-20261127.md`。
> ⑥ 收尾门：`check-doctor` **FAIL=0 / WARN=3**（三条 C 类存量：源树不可核 67 行、账本登记例外、身份表降级一致）；`docs-health` **0/0/0**；
> `check-progress-counts` **G1 36/37 · G2 10/13**；`reports-orphan-check --check` **rc=0（710/710）**；`git fsck` rc=0。

> **★★ 2026-11-27（收口）：主线 Linux 上传感器已`可用`** —— `HasAccelerometer/HasAmbientLight/HasProximity` 三 **true**、
> `ssccli --sensor accelerometer` 连续出值（X≈-1.17 Y≈-0.66 Z≈9.55 m/s²）。全账 = `reports/sensors-ssc-restored-20261127.md`
> （真因链：droid-juicer 配置 0 字节占位 + `hexagonrpcd` 的 `-R` 布局不匹配 ⇒ DSP 断言 ⇒ 本板整机复位；换真 vendor 配置 + 扁平 `-R` 树 + udev/代理接线即恢复。新 `PITFALLS #741`）。
> **已做到开机自动生效**：`elden-sensorspd.service`（`/usr/local/bin/hexagonrpcd-patched` + 扁平 `-R` 树）+ `iio-sensor-proxy` enabled，
> 真重启后三属性仍 true、`ssccli` 连续出值。已知残留：attach 末尾一次 `free(): invalid next size`（systemd 自动重拉，不影响出数），
> 那个堆损坏**已由 ASan 定位并修好**（`#742`：`apps_std_procs[]` 按方法号当索引，我们的 34/35/36 占了 32/33/34 + `n_procs` 57 ⇒ 越界），
> 设备现态 `NRestarts=0`、三属性仍 true。剩唯一功能缺口 = **真写后端**（registry 持久化）。
> 全账 = `reports/sensors-ssc-persistent-20261127.md` + `reports/hexagonrpcd-heap-oob-20261127.md`。
> **可写 overlay（registry 持久化）已交付**：`-O /var/lib/hexagonrpc` + copy-up + 真 fwrite/frename/fsync；
> 设备实测 overlay 里出现真写入（`cam_registry_dump.txt` 18.6 KB / `fstempfile` 14.3 KB / `sns_reg_version` 9 B），
> 传感器三属性仍 true、`NRestarts=0`。关键坑两条 = `fwrite` 的 `in sequence<byte>` size word 别重复计入 def、签名不匹配不要 abort 监听。
> 全账 = `reports/hexagonrpcd-writable-overlay-20261127.md` + `patches/userland/hexagonrpc-write-20261127/0002-writable-overlay.patch`。

> **🆕 2026-11-27 06:0x（无人值守轮：`#692` 后续① 收口 + D10 复扫 + ABL logfs 判据纠偏）**：
> ① **「补齐 ADSP 的 PD 依赖」被否证（不做）**：主线 PDR + in-kernel pd-mapper 齐全（`qcom_pd_mapper.c:665` 把 `qcom,sm8750`
> 映射到 `sm8550_domains`），**本机实测** `PDR: Indication received from msm/adsp/audio_pd|charger_pd`（UP）、`q6apm` 已绑、声卡 `card0` 在
> ⇒ PD 链路四件齐全；而主线 PDR **没有「关 PD」接口**、`qcom_pas_stop()` 不碰 PD，pd-mapper 注销发生在 stop **之后**；
> **同 SoC 反例**（Xiaomi Pad 8 Pro / `piano`，mainline 7.2.10）= `remoteproc0 stop→start` 与 ADSP SSR 都不复位整机 ⇒ 本机复位归**板级 PMIC/AOP/TZ**
> （他方 issue 已由父代理读原文核）。全账 = `reports/sensors-adsp-pd-pdr-20261127.md`（lane 调研 + 父代理逐条重跑）；T6 已改写。
> ①c **`#692` 真根因落到用户态（上游 issue #29 同源）**：sensors PD attach 时要写 `/persist/sensors/registry/**`，
> hexagonrpcd（主线和在机包）**一律拒绝写**、且 listener 输入缓冲只有 256 B ⇒ DSP 断言 `sns_registry`；
> 同族机器 X1P42100 只掉 ADSP（rproc SSR），我们板子**静默硬复位整机** ⇒ 又一条板级复位策略的独立佐证。
> 最小补丁草稿已落 `patches/userland/hexagonrpc-write-20261127/`（v0.5.0 +87 行，本机 `meson test` 3/3 OK，**未上机**）；
> 新待办 **T13** = 交叉编译 + 上机三态判据（预期一次整机复位）。全账 = `reports/hexagonrpc-upstream-registry-write-20261127.md`。
> 顺带纠正：设备上是 **`hexagonrpcd 0.3.2-2`**（非文档所写 0.4.0），`/usr/bin/hexagonrpcd` 是 Debian shell wrapper，**无参调用自动补 `-s`**。
> ② **ABL logfs 判据纠偏（新 `PITFALLS #738`）**：本机 `UEFILOG1.TXT` 目录项 size = **65536（只留最近一次启动）**，
> `reports/uefi-observability-pivot-20261101.md` 的「10 段环形可回溯」在本机现态**不成立**（9 段是陈旧 `_a` 残留）；
> 且 23:11 那次（= #692 最后复位的回落启动）ABL 记的 `Reset by PSHOLD / Hard Reset` 与正常重启同款 ⇒ **该字段不能判根因**（#184/#182）。
> 证据 = `reports/artifacts/sensors-692-logfs-20261127/`（logfs 8 MiB + 只读采集）。
> ①f **★换上真 vendor 配置后 `-s` 不再复位整机**（trial6，2026-11-27）：官方 ROM `super_1..8` 按 `rawprogram*.xml` 的 start_sector
> 稀疏拼回 22 GB → `lpunpack -p vendor_a` → `debugfs rdump /etc/sensors`（`out/vendor-extract-20261127/`，本地不入库）；
> 真 `config/`（139 json）+ 真 `sns_reg.conf` + 扁平 `-R` 树 ⇒ **0 条 `PDM crash`、ADSP 一直 running**。
> 残余：①真写后端（`hexagonfs_mapped` 只读，现在 registry 是 343 条 0 字节骨架）②`-s` 后进程自退（同 boot 二次 attach 会 `Could not register ADSP default listener`）
> ③宿主缺 `81-libssc-elden.rules` 且 `iio-sensor-proxy` masked。全账 = `reports/sensors-692-real-configs-20261127.md`，T13 已重写。
> ①e **同轮续 3 发（trial3/4/5）**：`hexagonrpcd 0.5.0` 的 `-R` 树是**扁平布局**（`<R>/sensors/{config,registry,sns_reg.conf}`、`dsp/<dsp>`），
> 与 droid-juicer 的 Android 布局不符（trial4 三个 `Could not open` 的真因）；按扁平布局重建后**文件服务全绿**（trial5），
> 但 DSP 仍断言 ⇒ 真因是 **droid-juicer 抽出的 sensor config/registry 几乎全是 0 字节占位**（`sns_reg_config`/`json.lst` 均 0 B，139 个 config 只有 1 个非空）。
> 新 `PITFALLS #740`：`scp` 后未 `sync` 就复位 ⇒ 文件尺寸不变、内容全 0（trial3 的「跑不起来」真因）。
> 下一步 = 从官方 ROM 的 `super_1..8.img`（按 `rawprogram*.xml` 的 start_sector 稀疏拼回）`lpunpack` 出 `vendor` 取真配置。全账 = `reports/sensors-692-file-root-20261127.md`。
> ①d **上机 2 发（2026-11-27）+ 串口第一次抓到崩溃现场**：`-s` 时 DSP 断言 `sns_registry_sensor.c:309`，内核**看到了** fatal error
> 并进入 `recovering adsp`，整机死在其后的 PAS 关停/重启段 ⇒ **`#737` 的「串口零行 ⇒ 复位在 Linux 之外」作废**（已在该条追加修订）。
> 本轮补丁（假成功 fwrite）**不足** ⇒ T13 下一步 = apps_std 全方法假成功。另记采集坑：`nohup … >/dev/ttyGS0` 会被 nohup 改写到 `nohup.out`（用户态日志全丢）。
> 全账 = `reports/sensors-692-attach-crash-serial-20261127.md`。
> ①b **V2 取证（PMIC PON 侧）已做、且判不了根因**：主线 `qcom-pon` 只写 reboot-mode magic、**不读任何 reason 寄存器**；
> 用户态也没路（`regmap` debugfs 无 `access`、`registers` 是缓存值 ⇒ 新 `PITFALLS #739`）。ABL 留的 `Reset by PSHOLD`
> ⇒ 可排除「PMIC 看门狗」一支，但 PS_HOLD 分不清 AOP/TZ 谁拉的低 ⇒ H2a/H3 **在 PMIC 侧不可分**，该通道到此为止。
> 上游缺口登记（不立项、不提）：主线缺 PON reason ABI（通用 `power_on_reason.h` 已存在），但 `qcom-pon` 正被 SPMI sub-device 系列（v8–v10）大改 ⇒ 等合并后再评估。
> 全账 = `reports/pmic-pon-reset-reason-20261127.md`。
> ③ **D10 复扫**（`reports/comm-triage-20261127.md`）：窗口内**人类评审新增 0 条**；四个上游系列封数与上轮逐一相同、不建议催；
> `mobian1/droid-juicer !46` 逐字段不变（notes=0）；**新工具事实** = `lore-kernel.gnuweeb.org` 是免 Anubis 的 lore 镜像。
> （**2026-11-27 01:1xZ 已补**：keyring 解锁后 IMAP 三箱实测 —— INBOX 24 / Junk 17 新件，**我方四系列回信 0、退信 0**；
> 并已获用户放行回帖 `linux-msm/hexagonrpc#29`：<https://github.com/linux-msm/hexagonrpc/issues/29#issuecomment-7207186502>，
> 文本存档 `out/upstream-post-20261127/`。）

> **🆕 2026-11-26 23:1x（用户放行上机后接续：`#692` 假说 A **被实验否证**）**：三次零写盘 `fastboot boot` 试验核（`out/fastrpc1-20261126/` sha `2050cf6c…`）+ 在机 vk192 对照，共 6 发实测（报告 §8）：
> ① **先补上一班漏的采集**：试验核 `/dev/fastrpc-adsp`（非 secure）**在**、`qrtr 400` 在、ADSP `running` ⇒ `qcom,non-secure-domain` 生效，旧阻塞项消除（且并不依赖补丁）。
> ② **决定性结果**：`hexagonrpcd … -s` 在**打了 remote-heap 补丁的核**上 **2/2 静默硬复位整机**，在**未打补丁的在机 vk192** 上**同样复位**（C1）⇒ 补丁既非原因也非解药；不带 `-s` 时同一核完全正常（rc=0）。
> ③ **机制**：ADSP `remoteproc stop`（**不跑 hexagonrpcd**）**同样 1–2 s 静默复位**（C2，2/2，且 `echo` 本身未返回 = 卡在停止握手），而 **CDSP stop/start 全绿**（C3）⇒ 复位在 Linux 之外（PMIC/引导层或安全监控），**ADSP 故障与 ADSP 停止共用这条路**。崩时串口 relay **零行**（探针证明通道本来通）、磁盘日志因未回写全丢、`pstore` 空、APSS 硬看门狗启动即禁用。
> ④ **收口**：按 S 报告 §6.3 止损，内核侧停手；`PITFALLS **#737`** 立条（含「禁在本机 stop ADSP」）；TASKS **T6** 已改写为「止损 + 三条后续（PD 依赖/ DSP 侧证据/ 用户态离线推）」。设备已回在机旧核、`--failed`=0、`hexagonrpcd`/`iio-sensor-proxy` 仍 masked、slot `_b`。

> **🆕 2026-11-26 22:2x（网关额度中断后的收尾轮；本段全部数字为收尾轮独立重跑）**：
> ① **门禁**：`check-doctor` **FAIL=0 / WARN=3**（均为存量：① slim bundle 源树不可核 ⇒ 67 行身份「暂不可核」② `vk-ledger-known-issues.tsv` 已登记例外 ③ 身份表降级一致 C=2）；本轮修掉两条 FAIL（scripts 索引过期 / 其反作弊②残留）并清掉 `out/boot-elden.img` 重复副本（与 fastrpc1 同 sha `2050cf6c…`，21:51 构建副产物）。
> ② **传感器 #692 工单（S2）真相**：假说 A **仍未判**，而且不是被否定 —— `journalctl -b` 的 **-1/-2/0 三 boot 中 `hexagonrpcd` 计数 0/0/0**（上轮 21:52 只完成「第二次上机 + 证据采集」，决定性 `-s` 从未跑）；补丁语义在试验核里可证（`assigned reserved memory node adsp-rpc-remote-heap`），但**补 DTB 后 `/dev/fastrpc-adsp` 是否真出现没采** ⇒ 已写成下一班第一条命令。产物归位：`out/fastrpc1-20261126/`（sha `2050cf6c…` O_DIRECT 两读一致，已登记 `versions/out-candidate-sha.tsv`），证据 `reports/artifacts/sensors-692-trial-20261127/`；设备已回在机旧核（`…-00005-g4bdf1711b5c0`）。全账 = `reports/sensors-692-backport-test-20261126.md` §7。
> ③ **droidloom 重 boot 后回归（新实测）**：`nft dl_dns_redirect` = **0 条**（T4 判据实测 FAIL）；「开机自启」**不成立** —— 真正的起停件是 **user 1001** 的 `droidloom.service`（`WantedBy=graphical-session.target`，该 target inactive），手工起后 cell 地址面齐全（两侧 `/30`）但 `ping` 100% 丢包、`adb 10.177.0.2:5555` 不在；总线上的 `MDX5T20730009849` = 华为 ELS-AN00（非本机）。见 `reports/droidloom-cell-network-20261126.md` §9。
> ④ **T10 口径落地**：`scripts/reports-orphan-check.py`（13 条反作弊自测全过，`--check` 可当门）⇒ 三刻度实测 readme 50/694、top 143/694、**all 536/694（孤儿 158）**；A16 的「468 篇 / 32.5%」在三种语料上都复现不出来，**以 all 刻度 158 为唯一口径**，剩余工作 = 补 158 篇指针（`TASKS/NEXT.md` T10）。

> **🆕 2026-11-26 夜 2（整理轮：三条审计 + 6 处门禁加固；**计划 = `.pi/plans/2026-11-27-整理三线派工.md`**）**：
> ① **架构审计**（`reports/arch-audit-20261127.md`，18 条，父代理逐条复核）：P0 两条 = 顶层杂件 `=50KB`（已移 `/tmp`）与 **`fabric.json` 双说法**（`.pi/AGENT-OPS.md`/`.pi/ORCHESTRATION.md`/`.pi/CONCURRENCY.md` 仍写「配置真值」）⇒ 已改口 `settings.json` 的 `subagents` 段 + 删 `.pi/fabric.json`/`.pi/fabric/`。
> ② **门禁加固（本轮已落地并各带阴性对照）**：**§31 reports 索引门**（新建 `scripts/doctor/31-reports-index.sh`；此前 694 篇的唯一查全入口**无门**且漂 60 篇）· **死脚本门不再被自吞**（`static-scan.py` 的 `SELF_OUTPUT` 加 `scripts/README.md`；父代理用 tracked 孤儿探针实证「重建索引即从 DEAD 消失」）· **资产门前缀绕道收紧**（`check-doc-assets.sh`：宽前缀 `scripts/ch…`/`patches/0…` 现判 MISSING，真截断 `PITFALLS/sessions/01` 仍过）· **`layout.tsv` 的 `vcs` 列有语义**（`ignore` 区不得有 ≥5 MiB 或 `.img/.bin/.mbn/.elf/.ko` 的 tracked 件）。
> **🆕 2026-11-26 21:4x（收敛执行：用户放行「允许删和化简」）**：入口面两处必读文件 **314.5 → 169.2 KB（-46%）**
> —— `INDEX.md` §0 的 27 个旧块逐字下沉 `archive/topics/INDEX-§0-沿革-20261118-25.md`（122.7→44.4 KB）、
> `PITFALLS/README.md` 368 行按「第一句判据」收敛（191.8→124.8 KB，不钉字数，被裁尾巴里的正文路径强制保留）；
> `.pi/memory/failures-kernel.md` 199 KB / 346 条按主题拆 7 件（每件 ≤47 KB，`mem -t project` 跨件命中不变）；
> `reports/artifacts` Top16 试验目录 **449 MB → 45 MB**（tar.zst，抽样逐文件 sha 复核后才删原件，清单 `archive/artifacts/MANIFEST.tsv`）；
> 并清 `.pi` 残留（24 个 `*.bak-alias-1112`、`tmp-tasks/` 3 张任务卡归档、`reports/ rambuild/ mcp.json` 补登记）。
> 全账 = `.pi/plans/2026-11-27-文档精简拆分归档.md` §7。**随后放行两项**：T12 会话归档 gzip 工具先行 + 只压 >30 天
> ⇒ `.pi/sessions` **1.08 G → 666 M**（省 373 MiB，`/resume` 仍只见近期）；T10 `reports/artifacts` 的 173 条 gitignore
> 规则收敛成 32 行统一块（ignored 条目数前后同为 542，探针 `.img` 忽略 / `.md` 可见）；顺带修掉 `gen-sessions.py --check`
> **先清空再重写、守卫在最后**的门级缺陷（`PITFALLS #736`：跑「校验」会被自己盖章，还实测把 171 篇刷成 D 后恢复）。
> **仍未做**：468 篇无角度指针的报告补指针（NEXT T10 右列）。
> ③ **文件去重**（`reports/fs-dedup-20261127.md`）：`backup/` 内 10 组同 sha 大件中 **7 组早已同 inode**（上轮 `disk-audit` 的「9.9 G 待回收」**已不成立**），本轮再硬链 1 对（hyp 8 MiB，inode/nlink/sha 三向复核）；`out/`/`runs/`/`bootslot-b/` 按判据不动。`.pi/sessions/` gzip 收益 23.9% 但 `sessfind`/`recent-sessions.sh`/doctor §15 全按 `*.jsonl` 硬匹配 ⇒ **先改工具再压**（未做）。
> ④ **文档精简计划**（`.pi/plans/2026-11-27-文档精简拆分归档.md`，6 批）：最大三批 = INDEX §0 下沉（~80 KB）· PITFALLS 索引瘦身（~130 KB，需你裁定裁剪幅度）· `reports/artifacts` Top15 tar.zst（~385 MiB）。**口径修正**：全仓 tracked md = **2229**（旧记 1356 少算）；`docs-health` 154 篇是**刻意只覆盖 agent 脑袋层**（1.1% 不是缺口）。
> ⑤ **进度复核（本轮独立重跑，非采信文档）**：`check-doctor` **FAIL=0 / WARN=3**（存量三条）· `docs-health` 0/0/154 · G1 **36/37** / G2 **10/13** · 设备在机 vk192 镜件、`--failed`=0、`hexagonrpcd*`/`iio-sensor-proxy` 仍 masked。**一处分歧已澄清**：现 `input_current_limit=2000000`、`voltage_now=5.68 V`、电池 **+80 mA**（98%）——短边 PD 在位时 charge-watch 顶到 2 A 顶档，`PITFALLS #734` 的 900 mA/4.40 V 是 **SDP-only** 档，非矛盾。

> **🆕 2026-11-26 晚（droidloom 可用化 + 面板唤醒通道；**现役待办 = `TASKS/NEXT.md` §4.0a**）**：
> ① **droidloom 装上并可用**：0.1.0-49 正式摊装（cell + 开机自启），**cell 联网修复**（captive-portal 探针改 vivo 204 + 独立 nft `ip dl_dns_redirect` 把 cell DNS 转校内 resolver + 解禁 `Droidloom` 网络）⇒ `dumpsys connectivity` = `VALIDATED`、宿主 `adb devices` 出 `10.177.0.2:5555 device:droidloom`（**从此 UI 问题可 adb 自动化复现**）。
> ② **小红书**：全屏真因 = droidloom 按包名给「非可调整 App」分配手机尺寸窗口 ⇒ 修法 = `~xuqianhui1001/.config/droidloom/window-policy-v1.json` 的 **per-app 覆写**（1904x3040），实测窗口 `1902x3039`；**键盘**真因 = 占位 IME `onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE` ⇒ 绕行 = 装 **Fossify Keyboard** 并切默认 IME（占位器保留可回退），三轮「输入-失焦-再点」9 图全过；**Limbus** 命中 AppSealing `Root_Detection=1`（非 emulator）⇒ 不投（Steam 版能跑）。
> ③ **面板熄屏的 SSH 唤醒通道**（`PITFALLS #735`）：熄屏时 `dpms=On`/`bl_power=0`/`connected` 三条 sysfs 会骗人、`screencap` 也仍返回成功图 ⇒ **唯一判据 = 合成器出帧**（`grim` 成功且 >60 KB）；唤醒 = 注入输入事件。已落 `scripts/wake-screen.sh` + 设备 `elden-wake.path/.service`（enabled）⇒ `ssh elden 'elden-wake'` / `ssh elden-root 'touch /run/elden-wake.trigger'`，两种熄屏状态（停帧 / 真 DPMS off）均 0.7 s 内唤醒。
> ④ **D24 常设 lane 首轮收口**（`TASKS/dim/D24.md`、`reports/droidloom-upstream-lane-20261126.md`）：上游 29 open / **27 fork**，`EvilBorsch/droidloom` `eb/main` **ahead 24** 逐条命中我方两个本地规避（`unshare --forward-signals`、host resolvers）⇒ 结论 **「只当实验」**、不作 G2 主线；升级风险表见 §D3。
> **🆕 2026-11-26 午后（上游两件投出 + 三线攻坚派工 + 首轮三条收口）**：
> ① **M6 DSI-PHY v3 与 elden 板 DTS v10 已投**（`05:20:54Z` / `05:20:58–05:21:04Z`，全 250，lore 两处 3/3 命中）：M6 v3 带 Jianfeng Liu 的第三方 `Tested-by`（diff 与 v2 逐字节相同）；
> v10 的 1/2 补回 Krzysztof 对 v8 给的 `Acked-by`、2/2 修 sashiko 指出的 `pmic@2f` 缺 `vin12/vin34/vin5/vin7-supply`（同指 `wl2868c_vsys` stand-in）。
> ② **sashiko 对 v10 2/2 的 2×`[Medium]` 均不需动作**：binding 不在目标树（等 `regulator.git for-7.5`，cover 已专节写明）、缺 core boot/电源节点（cover 已声明本版不含）⇒ **不回机器人线程**。
> ③ **GitLab 面**（`--noproxy` 公开 API + phoc issue 渲染页现查）：`droid-juicer !46` 人类 note **0**、74 h 零变化（仓库队列月级，不催）；phoc `#125` 最后 note 仍 **2023-02-17**、open MR **13**（!827 于 11-25 更新待核）。
> ④ **三线攻坚已派 4 lane（并行）**：传感器（#692 = `hexagonrpcd -s` 一 start 就硬崩的根因 + 零崩溃风险验证计划）、Gunyah（进不进日常线 + 成本）、droidloom（重装 + Limbus split / 小红书部署）、v10 sashiko 裁决（有/无 core 节点惯例核对）。派工单 = `.pi/plans/2026-11-26-三线攻坚派工.md`。
> ⑤ 运维：16 个未推提交已补推 GitHub + USTC；`check-doctor` **FAIL=0 / WARN=3**（存量三条）；设备 U2 在线、在机 **vk192 镜件**（UTS `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`）、`--failed`=0、`hexagonrpcd*`/`iio-sensor-proxy` 仍 masked（#732 后的安全态）。全账 = `reports/comm-triage-20261126-d11.md`。
> ⑥ **首轮 lane 收口三条（父代理逐条重跑复核，2026-11-26T06:5xZ）**：
> · **传感器 #692 根因到「双缺陷链」**（`reports/sensors-hexagonrpcd-20261126.md`）：`-s` = 一次 `INIT_ATTACH_SNS`，文件是 sensorspd 反向来取；真凶候选 ① 内核 `fastrpc_get_args` 对 `SENSORS_PD` 仍走 context bank（`build/daily:1102`）而**上游三处树（torvalds master / char-misc-next / char-misc-linus）都没有那 1 行修复**（父代理现查 → patchwork `handled-elsewhere` 但树上无痕）② hexagonrpcd（真上游 = `github.com/linux-msm/hexagonrpc`，**不是** Codeberg）无写支持 + listener 输入缓冲 256 B 上限 ⇒ registry 写必失败。另纠正：#733 后「pstore 空」不再能当非 AP panic 的证据。
> · **Gunyah = 裁定不做、不进日常线**（`reports/gunyah-daily-line-20261126.md`，§9 = 父代理复核表）：进不了不是卡点而是结构事实（上游 `drivers/virt` 无目录、patchwork 系列 0），移植树已删、每级内核 0.3–0.5 人日周期性支出且「跑子 VM」已终局不可行；止损判据 R1/R2/R3 写死。
> · **v10 sashiko 两条 Medium 裁定 (A)**（`reports/dts-v10-sashiko-20261126.md`）：都不算新缺陷（binding 等 7.5、core 节点自 v6 起声明不含），**合照 qcom 惯例**（`sm8750-mtp` 首版带 PMIC/RPMh/console，UFS +4 个月、USB +11 个月）⇒ 不改 DTS、不回机器人，文本已备 `patches/upstream/elden-dts-v11-20261126/cover-scope-section.txt`。
> ⑦ **droidloom 重装收口（lane D，`reports/droidloom-deploy-20261126.md`）**：上游 **0.1.0-49** 三包正式摊装（`/opt/dl-test` 手工摊装已不存在），doctor `ready=True blockers=0`、cell `Android is ready`、开机自启；**小红书装上且上屏**（`IndexActivityV2` 1440x2400）但 **cell 无网**；**Limbus 三 split 安装成功却启动即被 AppSealing（INKA）杀**。台账 = `TASKS/G2.md` 新块。
> ⑧ **三个后续已出结论**：**cell 无网 = 双根因**（SSID `"Droidloom"` 被 `WifiConfigStore` 持久化永久禁用（一次性供给器不复查，与上游 #48 同构）+ cell DHCP responder 硬编码 DNS `1.1.1.1/8.8.8.8` 而校园网封校外 UDP/53）⇒ `reports/droidloom-cell-network-20261126.md`；**Limbus 命中项 = `Root_Detection=1`（非 emulator）** —— 从 AppSealing 自己的明文报告 `…/.sealing_reports/…` 直接读到（`Emulator_*` 全空、`msg [20059] …rooting device is not allowed`、43–82 ms）⇒ **打回 lane D3 的「结构性不可过」机制判定**，但仍是「不投」（Steam 版能跑）；**小红书画面不全 = freeform 任务 1440x2400 被 droidloom 原样当窗口尺寸**（非分辨率/非缩放），已把任务 resize 到全屏且 dpi 改 690，但 restart 后回退 ⇒ `reports/droidloom-display-sizing-20261126.md`。
> ⑨ **在跑**：lane S2（fastrpc 试验核已 `fastboot boot`，发现试验核只注册 `fastrpc-adsp-secure` 无 `/dev/fastrpc-adsp`，已令其收口还原并释放设备锁）。

> **🆕 2026-11-26 晨（无人值守轮，设备在线但四 lane 均只读）**：
> ① **gunyah 线分界写死（TASKS **D21**，`reports/gunyah-lane-20261126.md`）**：主线 `drivers/virt/gunyah` 仍不存在
> （driver 系列停 2024-02 v17）⇒ 无接收面不投；`gunyah_wdt` **早已在主线**（`drivers/watchdog/gunyah_wdt.c`）且本机 hyp 空实现
> ⇒ 既不能当看门狗也无上游化空间；移植树 `build/gunyah-port`/`out/gunyah-73` 已随 11-25 清理消失 ⇒ 任何上机读回先要重建（≈0.5 天）。
> ② **「传感器驱动有问题」核实（TASKS **D22**，`reports/sensor-claim-verify-20261126.md`）= 部分成立但归因层错**：内核/DTB/fastrpc/QRTR
> 四层实测健康（`qcom,non-secure-domain` 是真在 DTB 的 0 长 boolean、`/dev/fastrpc-adsp` owner=`fastrpc:fastrpc`、
> `qrtr-lookup` 有 **400 SSC**，而 `journalctl -b \| grep -c hexagonrpcd` = 0）⇒ **推翻**旧报告「svc 400 未注册」；
> 真缺口 = trixie `iio-sensor-proxy 3.7-3` 无 libssc + 部署层四件未装。**用户态备料已出**（`reports/sensor-libssc-prep-20261126.md`）：
> Debian testing/unstable **已有官方 SSC 版包**（`iio-sensor-proxy 3.9-1` NEEDED `libssc.so.2` + `libssc 0.4.4-2.1`，ABI 对 trixie 兼容）
> ⇒ 路线 A 零构建；路线 B 本机交叉构成功。卡点 = udev 规则仍不认 `ssc-accel`（`PITFALLS #451`）。
> ③ **elden 板 DTS v9 已投出（2026-11-26T00:21:57Z，3/3 `Result: 250`）**：回应 Krzysztof「cover/changelog 必须明写 waiting on bindings」
> ⇒ cover 第 12 行专节；补丁 diff 与 v8 逐字节相同；`dt_binding_check` rc=0/5420 DTC、`dtbs_check` elden 诊断 1→0（加 wl2868c binding）。
> **lore `linux-arm-msm` 三封全命中**（父代理用 Firefox 渲染独立复核；curl 直取/走代理均 Anubis 403）。
> 沿革：07:00 CST 首次 `--send` 被 keyring Login collection 锁挡住（`fatal: could not read Password for smtp://…`），用户登录图形会话后重跑即通。
> 台账 = `patches/upstream/elden-dts-v9-20261126/SENT.md`；下一步 = 盯 review（1/2 可先合，2/2 等 7.5-rc1）。
> ④ **B5 APSS watchdog 静态复核**（`reports/b5-apss-wdt-static-review-20261126.md`）：`0x16410000` 双推收敛（XBL XPU 表 +
> 同族 `WDT=PDP−0x10000`），vendor DT/reserved-memory **无冲突**，上机判据清单 §4（头号风险 = hyp/TZ 独占则 `readl(WDT_STS)` 同步外部中止）。
> ⑤ **通信复扫**（`reports/comm-triage-20261126.md`）：dwc3 v16 拿到 sashiko 首个「no issues」；M8/M10 换址补发进档 0 回音；
> **IMAP 收件侧与 phosh API 因 keyring 锁无法核验（如实记错误码）** ⇒ **2026-11-26T02:4xZ 图形会话已登录（seat0/tty2 + gnome-keyring 在跑）⇒ 这两项下一轮可直接补核**。
> ⑥ **传感器上机尝试 = 装包成功、出数失败，且 #692 已复现（2026-11-26 08:2x，用户放行后执行）**：`libssc2`/`libssc-bin`/`iio-sensor-proxy 3.9-1` + udev 规则都到位，
> 但 iio-sensor-proxy 报 **`'registry' sensor unavailable … is hexagonrpcd running?`** ⇒ **registry 由 hexagonrpcd 供给，纯用户态 libssc 绕不开 #692**（早轮设想否证）；
> 手动 `start hexagonrpcd`（带 `-s`）当场硬崩，又因其 **本来就 enabled** 而我 `unmask` 时未 `disable` ⇒ **5 次「phosh 转圈→关机」启动循环**（`PITFALLS #732`），
> 已用零写盘救援 + initramfs SSH 挂 `sda17` 修根恢复安全态（`hexagonrpcd*`/`iio-sensor-proxy` 全 masked、`--failed`=0、桌面正常）。
> **前置硬门 = 先建取证通道（物理串口或修 ramoops）**；全账 `reports/sensor-ssc-deploy-20261126.md`。
> ⑦ **传感器落地件已备**：`scripts/deploy-ssc-sensors.sh`（`--check` 只读体检矩阵 / `--from-debian` 官方包 + sha256 / `--dry-run` / `--rollback`，
> 全程不碰 `hexagonrpcd*`）——放行后一条命令即可上机验 SSC 出数。
> ⑧ **droidloom Debian 包收尾**：runtime 缺 `libwayland-server0` 实证补齐 + 交叉 `--sysroot` 绝对化（**`PITFALLS #730`**），双架构重建。
> ⑨ **「插着线却充不进电」已定因并修好（2026-11-26 10:5x CST，`PITFALLS #734` + `reports/usb-charging-dualport-20261126.md`）**：长边数据线（连 PC）+ 短边 PD 线时，ADSP 只从长边 SDP 取电且默认 `ICL=100000` ⇒ 电池 **−770 mA**；
> 真根因 = **`charge-watch` 服务从未装到设备**（脚本在、unit `not-found`，并根丢启动接线）；三档实测：100 mA −770 mA / **500 mA 仍 −270 mA** / 900 mA **+126…137 mA**。
> 已装 unit 并 `enable --now`，ICL 被顶到 900 mA 且 ≤2 s 自愈（代价 = 超规范取电、`v_bus` 4.45–4.52 V）。
> **11:2x 收尾**：sag guard 已加且**阈值被上机数据改过**（4.60 V 是误判线 ⇒ 4.40 V / floor 500 mA，`--selftest` 10 断言），`deploy-desktop-shell.sh` **§17** 把三件判据固化（设备 `--check` MISS 3→0 幂等）⇒ 重建根不会再丢。剩 = 反向接法需人插拔实测。

> **🆕 2026-11-25 夜 2（四项点名调查轮，零设备：平板不在线）**：4 lane 全收口 + 1 条派生构建 lane。
> ① **Mobian/phosh 上游化 + 通信**（`reports/mobian-phosh-upstream-20261125.md`）：增量窗口**人类评审 0 封**，机器人给
> **dwc3 v15 2×`[Low]` ⇒ 待出 v16**、**elden 板 v8 2×`[Medium]`（不改 DT，已入 cover）**；`abel.vesa@linaro.org` 死地址（下次用 OSS 址）；
> Mobian `droid-juicer !46` 人类 0 note / 48 h 无变化、`mobian-recipes` qcom 三处目录仍空、**7.x staging 可用但 0 条 sm8750 分支**；
> phoc `#125`（edge-swipe-back）自 2020 仍无 MR ⇒ 我们的 lisgd 路线仍最优。**外部门（需用户）＝ IMAP 存储层自 03:44:39Z 冻结**。
> ② **droidloom × GMS × 目标 APK**（`reports/droidloom-app-compat-20261125.md`）：登录已验证 / Integrity 免责 / 商店落 `uncertified`；
> **Limbus 现役装法起不来（只有 split 包）**，且实物里发现 Firebase 12.6 + `credentials-play-services-auth`（无 GMS 时首启风险）；小红书预期能起但相机/定位/输入/推送缺件。
> 实物件 = `~/apk-20261125/`（自 vivo V2454A 提出，含 sha 账）。
> ③ **电源**（`reports/power-on-demand-20261125.md`）：四个观测面（`pm_test`/`wakeup_sources`/`pm_wakeup_irq`/`pm_print_times`）+ 已合指进 PLAN。
> ④ **长短边 USB 总账**（`reports/usb-ports-consolidation-20261125.md`）⇒ 派生 **M12 口径更正**：日常线源码本就带可写 ICL（`reports/m12-daily-already-writable-20261125.md`）。
> ⑤ **D19 看门狗缺口有了候选解**：`gunyah_wdt`（SMCCC vendor-hyp）在树、设备有 `gunyah-wdt` 平台设备 ⇒ 仅需 `CONFIG_GUNYAH_WATCHDOG=m`；候选核件 lane 已派（`out/gunyah-wdt-20261125/`）。

> **🆕 2026-11-25 夜（放行轮）：板 DTS v8 已投 + WARN 6→3 + 日常线重新可编**：
> ① **elden 板 DTS `[PATCH v8 0/2]` 已投**（09:13Z，3×250，cover `<20261125091309.124354-1@…>`）：1/2 补 `qcom.yaml`
> `lenovo,elden`（v7 漏的那行），2/2 = v7 板件原文；**Cc 里带上 Pengyu Luo**（关系声明需他在线程里）。
> ② **`check-doctor` WARN 6 → 3**（全账 `reports/warn-remediation-20261125.md`）：`posctrl-markspin` 4 件移入
> `backup/out-history-20261105/retired-uefi-posctrl/`（UEFI 正控载荷、非内核，不删只退出扫描面）、删无版本号
> `out/boot-elden.img`、**重建 `build/daily`**（worktree @ `4da9a8b69fc8` + `config-daily-c3-uinput-20261113`）
> ⇒ 模块化门禁 3 PASS、`Image.gz` 真编译通过（21 057 110 B，符号守卫 OK，UTS `7.3.1-debug-vk189-suspend-g4da9a8b69fc8`）。
> 剩下 3 条 = 源树不可核（断链 sha 已指名，网络取不到 ⇒ 不可复刻）/ vk 账本已登记例外 / 身份表降级一致（前者的连体）。
> ③ **坑：`PITFALLS #727`** —— partial clone 上查缺失对象会**静默联网回填**，代理链路挂死时表现为「命令永久卡住」；
> 只读核对一律 `GIT_NO_LAZY_FETCH=1`。

> **🆕 2026-11-25 傍晚（上游面轮）：dwc3 v15 已投 + 全系列重复性核查 + M12 结项**：
> ① **dwc3 双连接器 `[PATCH v15 0/3]` 已投**（08:12Z，4×250，cover `<20261125081219.3661014-1@mail.ustc.edu.cn>`）：
> **`linux-usb` 已补进 Cc**（v12–v14 缺的正是它，Greg 11-24 的第二条要求），新线程；1/3–3/3 与 v14
> **diff 段 `cmp` 逐字节相同**（patch-id `aa6ed734`/`5688adec`/`60721b9f`，只换 Date+Subject），只有 cover 是新的；
> Greg 第一条（真机测试）落成 cover 的 `Testing on hardware` 段（`reports/g7-routeA-dtfix-20261123.md` §8：role switch
> `waiting_for_supplier=0` ×2、`muxchip0` 注册、HS gadget 在 connector0 枚举、devlink 7≤基线 8）+ 显式 `Not tested`（物理换口未做）。
> lore 复核 `linux-usb` 线程 4/4 归档。全账 `patches/upstream/dwc3-v15-20261125/{SENT.md,CHECKLIST.md,logs/}`。
> ② **全系列重复性核查 = `reports/dup-check-20261125.md`（触发 = M12 撞车：我方补丁与已收录的 `be5e7367bceb` 重复）⇒ 2 停 5 继续**：
> **⛔ M3-DTS 板件 v8/v9 备料停投** —— **Pengyu Luo 2026-07-26 已投同一个 `sm8750-lenovo-elden.dts`**（1170 行骨架，
> 且他同期把该机 NT36536 面板推进 qcom for-next）；**⛔ M4 csiphy 2.4.0 v2 不再作独立系列** —— 上游 Wenmeng v7 `[06/23]`
> 已把 `qcom,sm8750-csi2-phy` 定到 kaanapali（2.3.0 表）并带 Bryan R-b，我方只剩「13 条值差 / 净行为 4 条 0x0000 写」的 delta 素材。
> 继续的 5 个 = dwc3 / M8 mdss / M10 fastrpc / M11 pstore / aw86927。
> ③ **M12 充电控制链结项 = 已被上游覆盖**：Joonhoe Kim 2026-10-07 的 `[PATCH] power: supply: qcom_battmgr: Allow setting
> the USB input current limit` 被 Sebastian Reichel **2026-11-08 收录为 `be5e7367bceb`**（30 行，与我方 `0001` 语义逐条相同）
> ⇒ 我方系列作废（`patches/upstream/charger-icl-20261125/` 标 ⛔、`SEND.sh` exit 99），**只留作本机 backport 参考**
> （`upstream-be5e7367bceb.patch`）；本机 A/B 判据与脚本（`probes/m12-icl-ab.sh` / `-upstream.sh`）保留可复用。
> **★ 同晚上机复核：上游件与 Venkat v2 都已实测通过** —— 零写盘 `fastboot boot` 三发（`out/m12-upstream-20261125/`），
> 写 900000↔500000 回读一致、`unknown message`=0、`usb_type` 门放行；顺带把 `Tested-by` 回给 Venkat
> （`out/mail-20261125/re-venkat-battmgr-v2.txt`，08:14Z 投出，lore 摄取未到）。
> 同轮取证更正：`usb_type=Unknown [SDP] …` 的现场值是 **SDP**（方括号里才是当前值）⇒ 「ADSP 判 Unknown」作废，
> 见 `reports/m12-upstream-test-20261125.md` + `PITFALLS #726`。
> 教训 = `PITFALLS #724`（查缺口必须查维护者树）· 工具事实 = `PITFALLS #725`（checkpatch 喂 stdin，别传文件路径）。
>
> **📚 更早的 §0 块**（2026-11-18 → 2026-11-25 上午，共 27 块）逐字下沉 → `archive/topics/INDEX-§0-沿革-20261118-25.md`；
> 本页只留**最近 3 天**的结论块（2026-11-26 整理轮审计 A18 + `.pi/plans/2026-11-27-文档精简拆分归档.md` B1 已执行）。

---

## 1. 使命与范围（3 行；目标定义只在一处）

- **机型唯一**：只研究 **TB322FC / elden / SM8750(P)**，不做别的机型移植；研究面 = 让本机在主线 Linux 上功能完整（固件/驱动为主，刷写只是手段）。
- **G1 / G2 / G3 / 拓展 / 核心原则（设备等价 / 存储 / 构建并发 / 上游发信授权）= 唯一正文在 `AGENTS.md`**（每轮自动注入，此处不复述）。
- **术语**：设备称 **U1 / U2**；备份目录 `backup/<SN>-<容量档>/`；禁用 `new-tablet` 与「两轨分机」旧口径；容量裁定见 `DEVICE/README.md` §3。

---

## 2. ★ 文档结构（文件夹＝角度；会话进度进 sessions/）

> **文档 v2（2026-10-14 起）**：每个**角度** = 一个**文件夹**，内含 `README.md`（该角度**策展 SSOT 正文**，唯一维护面）+ `sessions/`（**以会话为单位**的进度文件）。
> **会话进度文件**：命名 `YYYY-MM-DD-<主题>.md`（同日多主题加 `-2`）；文件头记 日期 / pi 会话 id / 主题 / 结论 / 证据指针 / **★SSOT 待并入**。
> **记录时的区分度**（取代自检脚本的计数/索引）：写入时就靠 文件夹(角度) + 文件名(日期+主题) + pi 会话 id 区分。
> **会话检索** = pi 原生项目会话（`.pi/sessions/*.jsonl`，项目级 `sessionDir`）：`scripts/sess.sh` / `/resume`；不手抄索引表。
> **SSOT**：数字/结论只在该角度 `README.md` 维护，其余用链接；跨会话新增先落 `sessions/`，由宿主择机并入 `README.md`。
> **阅读顺序只在一处声明**：唯一路径 = 下面「入口阶梯」（按新鲜度加权；与 `.pi/AGENT-OPS.md` §0 开工三件事是同一阶梯）。

### ★ 会话结束时写什么（唯一规则，8 条）

> 目标：**增量记录**——每次会话只新增文件，不改旧文件；状态数字只有一处出口。

1. **只写 1 个新文件**：`<角度>/sessions/YYYY-MM-DD-<主题>.md`；同一会话多主题加 `-2`。**不新建目录、不改已存在的 sessions 文件、不建索引表**。
2. **可用角度 5 个**：`TASKS/`（任务/进度/未解）、`PITFALLS/`（踩坑）、`DEVICE/`（单元/镜像状态）、`RESOURCES/`（资产/资源）、`RUNBOOK-BRINGUP/`（bringup 流程与相变记录）。
   `SESSIONS/` **冻结不写**；`HISTORY/` 由脚本生成**不手写**；`RUNBOOK-BRINGUP/` 已有正文（Phase −1…9 + `sessions/`），属可写角度。跨角度时写**主角度**一个文件，其余角度补一行指针。
3. 文件头只写 6 个字段：`日期 / pi 会话 id / 主题 / 结论 / 证据指针 / ★SSOT 待并入`。`pi 会话 id` 取 `$PI_SESSION_ID`。
4. **状态数字只改一处**：`TASKS/README.md` §0（总览）/ `TASKS/GAPS.md` §5（Q 行）。任务行状态标记在 `TASKS/G1.md`/`G2.md`（2026-11-26 拆分，README 留路由表）。其它任何地方**不写状态数字**，只写指针。
5. **会话全文不复述、不复制**——它就在 `.pi/sessions/*.jsonl`；文件里只放「结论 + 指向证据的路径/命令」。
6. **索引只放一句话主题**：`PITFALLS/README.md` 的索引行 ≤800 B，结论/命令/数字一律在正文。超长会被 `check-doctor §8` 判 FAIL。
7. **不写死计数**：任何「共 N 条 / N 个文件 / N 个提交」都必须现查（`scripts/gen-history.sh --stats`、`ls`、`check-doctor §8`）。写死必漂，且漂了没人发现。
8. **收尾判据**（`.pi/AGENT-OPS.md` §5）：产物落盘 + SSOT 同步 + `check-doctor.sh` **FAIL=0** + `git commit` + 工作区干净。


### ★ 时间序裁决（同一事实出现多个说法时的**唯一**规则）

> 目的：文档里**不准并列两说**。历史上多次出现「旧结论 + 勘误 + 再勘误」同时躺在正文里，
> 新会话无法判断哪个算数 —— 实测代价 = 每轮开工先花几十分钟考古。

1. **同一事实只允许一个「当前口径」**，写在**离它职责最近的那一份 SSOT** 里（状态 → 本文件 §0 / `TASKS`；设备事实 → `DEVICE`；经验 → `PITFALLS`；行为 → `.pi/AGENT-OPS.md`）。
2. **胜负判定 = 证据强度优先，其次日期**：会话内**实测证据（命令 + 原始输出）** > 带日期的报告（`reports/*.md`）> 文档叙述；同类证据取**日期更新**者。无日期、无证据的叙述直接输。
3. **输了的那条只有两种待遇**：① 与现状无沿革价值 → **删**（commit 信息写明「删除旧口径 + 依据」）；② 有沿革价值（曾被当真、影响过判断）→ 就地改成一行 `~~旧说法~~ **作废（YYYY-MM-DD，真因 + 指针）**`，**不得**在别处再复述一遍旧的。
4. **改口径必须同轮改完所有引用点**（grep 旧结论的关键词），并在提交信息里写「口径更正（YYYY-MM-DD）：旧 X → 新 Y（证据）」。发现新的实测证据与本文件 §0 冲突时，**先改本文件 §0 的结论与核对日期**，再改下游文档。
5. **本节自身有门**：`scripts/check-doctor.sh` §15 做两项比对（落后就 WARN、矛盾就 FAIL）：
   §0「核对日期」vs **最新会话证据日期**；以及 **§0 写的「在机 `vkNN`」必须出现在 `DEVICE` §1.1 首条**
   （§1.1 只允许一个 `★★` 权威行 —— 2026-11-14 之前那里同时挂着 vk190/vk191 两套说法，就是本节的实测代价反例）。

### ★ 入口阶梯（**唯一**路径；数字越小越权威，冲突时上位胜 —— 这就是时间序权重）

| # | 读什么 | 为什么它在这个位置 |
|---|---|---|
| 0 | 本文件 **§0 现在一页**（做到哪 / 卡什么 / 下一步） | 最新会话证据的摘要，标题带核对日期 |
| 1 | **`scripts/recent-sessions.sh 3`** + `*/sessions/` 最新 2 篇的「结论 / ★SSOT 待并入」 | **比任何 README 新**：本轮及上两轮的实测结论 |
| 2 | **`.pi/AGENT-OPS.md` §0**（开工三件事）→ §1–§5 | 行为唯一入口；§0 直接要求先做第 1 行 |
| 3 | **`PITFALLS/README.md` §0**（零号纪律）+ 索引 | 动手前必查的既有结论 |
| 4 | **`TASKS/README.md`**（索引：§0 数字 + 章节路由）→ `TASKS/{G1,G2,NEXT,GAPS,ANDROID-COMPAT,UPSTREAM}.md` | 状态数字与台账的唯一出处；§1–§7 正文在章文件，`§N` 旧写法按 README 路由表解析（2026-11-26 拆分） |
| 5 | `DEVICE` §1.1（在机）/ `RESOURCES` §3（资产）/ `RUNBOOK-BRINGUP`（步骤） | 按需展开 |
| 5b | **`RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md`**（＋`scripts/linux-state-audit.sh`） | **设备状态被改后重建 Linux 的唯一入口**：8 项清单 / S0–S9 步骤 / 卡 BL 误判防护 / 反向回 Android |
| 5b2 | **`RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md`**（＋`scripts/deploy-desktop-shell.sh`） | **EDL/fastboot → 可用桌面的端到端链路（2026-11-19 实测）**：S1–S12 每步命令/判据/失败形态/回退 + 一页速查 + 溯源表 |
| 5c | **`RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md`**（＋`scripts/gpt-minimal-build.py`） | **分区表如何简化 + 最小 Debian 刷机件清单**（LUN0 18→10 项、单 `linux` 472 GiB）；与 5b 是同一目标的两层 |
| 6 | `reports/*.md`（按日期）→ `archive/` · `SESSIONS/` · `PROGRESS.md` · `HISTORY/` | **只作沿革与证据，不得当「当前结论」引用** |

> `reports/` 内部查全用 **`reports/README.md`**（机器生成目录，`scripts/reports-index.py` 产；`--check` 过期即 rc=1。**篇数不写死**：现查 `ls reports/*.md | wc -l`）。
> 它**不是入口**，不承载结论，只解决「reports 里到底有什么、哪篇没人引用」——2026-11-15 实测有 135 个报告/台账文件名全仓只出现 1 次（**快照，已过时；现数以本文件顶部报告总数与 `scripts/reports-index.py` 重跑为准**）。

> **权重规则（硬）**：第 1 行（最近会话）与第 4–6 行冲突时，**先按会话读**，并在**同一提交**内把下行文档改成一致；
> 不允许「两边都写着，读者自己判」。`README.md` / `PROGRESS.md` 是**公开门面**，agent 默认不读（不占入口位）。

### ★ 根目录四文件的职责边界（单一事实源；2026-10-15 收敛）

> 收敛前：机型规格出现 4 处、G1–G3 目标在 4 个文件各复述一遍 ⇒ 必然漂移（实测 `README.md`
> 的机型表与 `AGENTS.md` 重复、目标段与 `INDEX.md` §1 重复）。现按「一条事实只有一个正文位置」
> 收敛如下，**其余位置一律只给链接**：

| 文件 | 唯一职责（正文位置） | 不得复述 |
|---|---|---|
| **`AGENTS.md`** | **项目身份**：机型唯一性、G1–G3 目标定义与优先级、核心原则（设备等价/存储/SSOT） | 不写进度数字 |
| **`INDEX.md`**（本文件） | **路由**：入口阶梯（含时间序权重）、文件夹地图与 SSOT 口径、§0 现状摘要、快速命令 | 不写状态数字（指向 `TASKS` §0）、不复述目标（指向 `AGENTS`） |
| **`README.md`** | **公开门面**：面向 GitHub 读者的定位、免责/许可、快速开始 | 机型表/目标只留速查副本 + 指向 `DEVICE`/`AGENTS` |
| **`PROGRESS.md`** | **公开时间线**：诚实进度叙事（含被推翻的结论） | 不写权威台账（指向 `TASKS`） |

细节（机型规格、分区、单元台账）以 `DEVICE/README.md` 为准；状态数字以 `TASKS/README.md` §0 为准。

### 规范入口（agent 行为唯一入口）

| 入口 | 文件（权威） | 装什么 |
|---|---|---|
| **行为/规范** | **`.pi/AGENT-OPS.md`** | agent **自主优先**、物理干预边界、设备安全纪律、研发纪律、文档写入权限、汇报/时间盒；并发细则见 `.pi/CONCURRENCY.md`，三层编排见 `.pi/ORCHESTRATION.md` |

> 项目描述（机型/目标/设备等价）在 `AGENTS.md`；各角度 `README.md` 不再复述规范与经验。
> （原「1 分钟版」三步已于 2026-11-14 并入上方「入口阶梯」第 0/2/3 行，不再单列。）

### 角度文件夹（`README.md` = 权威正文；子目录 = 以会话/单元为单位的记录）

| 角度 | 文件夹 | 装什么 |
|---|---|---|
| **设备状态 + 设备描述** | **`DEVICE/`** | 机型规格、固件清单与通路、驱动矩阵、单元台账 U1/U2、状态→任务分派、GPT 参数、**§3 Linux 容量策略** |
| **任务 / 进度 / 未解 / 方案** | **`TASKS/`** | **唯一任务台账 + 进度权威**（§0）；G1/C/A 任务（§1–4）；**§5 查漏补缺（GAPS，Q 编号以表内为准）**；**§6 G2 安卓兼容方案**；**§7 上游化（M 系列，以 §7 为准）** |
| **资源 / 资产 / 会话** | **`RESOURCES/`** | §1 外部参考 · §2 本地资源 · **§3 文件与资产台账（git 边界/可清理）** · §4 会话检索（pi 原生） |
| **上机手册** | **`RUNBOOK-BRINGUP/`** | 任一单元从原厂状态做到 b 槽直启 + 持久根的 Phase −1…9 |
| **开发经验 / 踩坑** | **`PITFALLS/`** | **开发经验唯一入口**：`README.md` = §0 零号纪律 + 索引表（条数以该表实际行数为准，勿在此写死）；正文在 `sessions/NN-*.md`（含 **§15 过时/废弃登记**） |
| **会话档案（逐会话）** | **`SESSIONS/`** | ⚠ **已冻结的历史快照（2026-10-15 起不再增补）**：`README.md` = 索引表/统计/内核时间线 + `sessions/YYYY-MM-DD-<名称>.md`。**新会话一律不进本目录**；会话身份与全文检索 = pi 原生会话（`scripts/sess.sh` / `/resume`）。此处保留仅为档案 + `check-sessions.sh` 校验基准 |
| **git 提交史（逐提交）** | **`HISTORY/`** | 提交视角权威：`README.md` = 规范/查询入口（**不写死数字**）+ `days/YYYY-MM-DD.md`（机械生成）。统计现查 `scripts/gen-history.sh --stats` |

### 顶层布局（5 区 + AI 大脑；**逐项 = 机器表**）

> **机器真源 = `versions/layout.tsv`**（人读 `scripts/check-layout.sh --list`），门 = `check-layout.sh`（`check-doctor.sh` §14：
> **每条路径必须在本节出现且磁盘存在**）。规则：**根目录新增条目先登记 `versions/layout.tsv`**，未登记即 FAIL。
> 本节只回答「这个目录能不能删、要不要入库」的**分区级**口径；逐条职责/删除风险读 `RESOURCES/README.md` §3。

| 区 | 顶层条目（与 `layout.tsv` 同源） | 版本控制 |
|---|---|---|
| 入口 | `AGENTS.md` `INDEX.md` `README.md` `PROGRESS.md` `LICENSE` | track |
| 角度文档 | `DEVICE/` `TASKS/` `RESOURCES/` `RUNBOOK-BRINGUP/` `PITFALLS/` `SESSIONS/` `HISTORY/` `archive/` | track |
| 源码/补丁/工具 | `scripts/` `tools/` `patches/` `patches-userland/` `reference/` `versions/` `packaging/` `initramfs/` `rootfs/` `probes/` `net/` `waydroid-ota/` `restore-259/` `cycle.sh` `elden-net.sh` `.githooks/` `.gitignore` | track |
| 证据/备份 | `reports/`（md 入库，大件 ignore）· `backup/`（**不可再生**：删前必须云盘或 bundle 兜底）· `assets/`（原厂安卓资产提取树，2026-11-19 起；专有、仅本机用、不入库，脚本可重建） | track / ignore |
| 工作区（**可再生成**） | `out/` `logs/` `runs/` `bootslot-b/` `env-pass/` `dl-cam/` `wt/` + 软链 `linux` | ignore（`runs/` = lane 实跑回执工作区，2026-11-20 起） |
| **缓存（可再生 / 同机可共享；物理在 `~/elden-cache/`）** | `build/`（36 G 内核树）· `geekidos-linux/`（6.4 G 上游克隆）· `Y700-elden-linux/`（28 M 旧克隆）· `external/`（895 M 第三方工作区）· `dl-cam/`（630 M 相机交叉编译，仓库内只留 231 纳管源件 + 12 软链） | ignore（**台账 = `versions/cache-ledger.tsv`**：逐条「能不能删 / 能不能共享 / 怎么重建」；门 = `scripts/cache-audit.sh --check`） |
| ↳ **现状（2026-11-26）** | ① 11-19 清理掉的内核树与上游克隆已于 11-21 恢复（恢复配方见 `versions/layout.tsv` 表头）；② **11-26 缓存搬家**：上表五个缓存目录物理移到 `~/elden-cache/`，仓库只留软链 ⇒ 仓库目录 123 G → **80 G**；逐条判读 = `versions/cache-ledger.tsv` | — |
| AI 大脑 | `.pi/`（规范/并发/编排/技能/记忆/会话；分工见 `.pi/README.md`） | track |


### 证据层（`archive/`，追加为主）

> 专题档案＝**过程证据**；结论一律以领域层为准，archive 不得被引用为「当前结论」。
> **追加为主**；允许为更正错误 / 回填结果做带日期的最小修订（不改写既有结论口径，权威恒在领域层）。

### 机器可查（无 SQLite，无生成物）

> **项目资产归属（2026-11-02）**：记忆/技能/会话全在仓库内——`.pi/memory/`（记忆 SSOT，`~/.pi/agent/projects-memory/y700-elden` 只是软链，自检 `scripts/check-project-memory.sh`）、
> `.pi/skills/`（项目技能，Pi 按工作目录叠加加载）、`.pi/sessions/`（会话轨迹，ignore）。lane 工作树在 `../wt/`、外部工作区在 `../external/`（均 ignore，`scripts/lane.sh` 默认 `WT_ROOT=<repo>/wt`）。

- 文本搜索：`rg` / `grep`（`PITFALLS/README.md` 找踩坑、`RESOURCES/README.md` 找资源、`TASKS/README.md` 找任务）。
- 会话回忆：pi 原生会话选择器（`/resume`）/ `scripts/sess.sh`；**逐会话快照** `SESSIONS/`、**逐提交史** `HISTORY/`（`scripts/gen-sessions.py` / `gen-history.sh` 再生）。
- 机器账自检：`scripts/check-doctor.sh`（退场入口 / vk 版本账 §5+§5d / manifest §5e / **§5f ABI 敏感项一致性（`.config`↔模块树）** / 静态卫生 /
  **§7 入口文档完整性（围栏·截断·证据指针泄漏）** / **§8 索引↔磁盘对账（编号撞车·索引行超长）** /
  **§9 SESSIONS 快照** / **§10 HISTORY 对账** / **§11 提交钩子生效性** / **§14 顶层布局注册表** /
  **§15 时间序健康（§0 核对日期 vs 最新会话证据；见 §2「时间序裁决」）**）。
  顶层布局真源 = **`versions/layout.tsv`**（项数现查 `scripts/check-layout.sh --list | wc -l`；5 区：入口/文档 · 源码/补丁 · 证据/备份 · 工作区 · 缓存（`~/elden-cache/`，台账 `versions/cache-ledger.tsv`）；人读面 = 本节「顶层布局」表，门 = `scripts/check-layout.sh`）。
  **入库前门已接线**（`core.hooksPath=.githooks`）：`pre-commit` 跑 `--staged-fast`（§7/§8/§9/§10/§11/§13/§14，实测亚秒级（量级见 `reports/script-audit-20261105.md`）；§12 内核 config 门不在这一档）。
  全量 `scripts/check-doctor.sh` 现为**并发子门**（`scripts/doctor/`），稳态 **~1.4 s**（旧版单体串行 12.5 s）；口径与实测见 `reports/script-audit-20261105.md`。
- **打包前门**：`scripts/assert-kernel-sane.sh`（config 锚点 / System.map 符号 / UTS 对齐 / 非陈旧 / **§1b ABI 敏感项**，后者调 `scripts/check-abi-config.sh` 比对 SSOT config 的 27 项）。
- 版本对账：**`versions/vk-kernel-identity.tsv`**（构建号 ↔ 内核二进制 ↔ 源提交，含每个镜像的失真标记）。
  它是本目录**唯一入 git 的派生表**（破例理由：兼作版本欠账账本）；由 `scripts/vk-identity.py` 重生成，
  `check-doctor` §5d 强新鲜度（过期即 FAIL）。“vkN 是什么”的口径见 `PITFALLS` #135。

---

## 3. 去哪读（**细节指针**；本节不写状态、不写结论）

> 本文件 §0 = 唯一状态入口；数字 = `TASKS/README.md` §0；设备/镜像 = `DEVICE/README.md` §1.1/§2.2。
> 本节只回答「某个细节去哪找」，不重复任何结论。

| 要查什么 | 去哪 |
|---|---|
| 任务台账 / 未解（Q 表）/ 待办 / 上游化（M 系列） | `TASKS/README.md`（§0 + 路由表）→ `TASKS/G1.md`、`G2.md`、`NEXT.md`(§4)、`GAPS.md`(§5)、`UPSTREAM.md`(§7)、`ANDROID-COMPAT.md`(§6) |
| 上游投递现状（当前一页） | `reports/upstream-status-20261125.md` |
| 在机内核 / 槽位 / 单元台账 / 存储策略 | `DEVICE/README.md` §1.1 / §2.2 / §3 |
| 动手前的坑 | `PITFALLS/README.md` §0 + 索引 |
| 从原厂到 b 槽直启的操作步骤 | `RUNBOOK-BRINGUP/README.md`（Phase −1…9） |
| 换机缺口 / 资产与 git 边界 | `RESOURCES/README.md` §3.5 / §3 |
| 文档去重执行账 / 审计依据 | `reports/docs-slim-20261114.md`（本轮：入口收敛二轮）、`reports/docs-slim-20261113.md`、`reports/doc-dedup-audit-20261112.md` |

**已定不做 / 搁置（勿重推）**：正文只在 `TASKS` §4「本轮不投入」+ §1 各 ID 行（`G1-26/27/28` 已出列、`G1-10` 无 NFC 硬件、
`G1-30` slim initramfs）与 `RUNBOOK` §0.5（BL 解锁已定稿关闭）；`kexec` 定位见 `TASKS` §4「迭代通道」条。
**两条不变的硬约束**（内核必须自编 / 传感器栈要 forky-sid 级 `iio-sensor-proxy`+`libssc2`）= 正文在 `DEVICE/README.md` §1.1 末条。


**保留但需知道的旧账**：换机缺口（`RESOURCES` §3.5 + `versions/migration-gaps-2026-10-17.tsv`）、
宿主 rootfs 方向（Alpine → Debian/Mobian，2026-10-26 用户定，`reports/mobian-migration-plan-20261021.md` + `TASKS` T14/T17）、
单元台账（`DEVICE` §1）。
---

## 4. 快速入口命令

```bash
cd ~/y700-elden          # ★ 启动入口即此（旧 cd 包装与根目录兼容包装 build.sh/iterate.sh/pack.sh 均已移除 → PITFALLS §15.1）
# 【收尾自检】退场入口 / vk 版本账与内核身份 / manifest 完整性 / 静态卫生（全绿再收工）
scripts/check-doctor.sh
# 【版本对账】“这个 boot.img 里到底是哪个内核” / 重生成对齐表
python3 scripts/vk-identity.py --gate                    # 只看命名/溯源规则结果
python3 scripts/vk-identity.py > versions/vk-kernel-identity.tsv   # 重生成（随后连表一起提交）
# 【脚本账】全量可执行入口清单（live / hist-only / unreferenced；整理轮用，勿手改表）
python3 scripts/static-scan.py --inventory | sed '1d' > versions/scripts-inventory.tsv
# 【动手前 30 秒】引导链类问题（解锁/AVB/降级/GPT/EDL）先查本地既有结论（PITFALLS #87）
grep -rn -iE "unlock|解锁|sn\.img|rollback|testkey|073" \
  .pi/skills/*/references/*.md *.md archive/topics/*.md | grep -v '^Binary'
```

```bash
# 目标形态：b 槽直启 Linux（~5–9 s 进 Phosh），日常不需 fastboot
sudo bash elden-net.sh && ssh -o StrictHostKeyChecking=no root@192.168.7.1
# 内核迭代＝统一入口 scripts/iterate.sh（四档环，细则 RUNBOOK §迭代）
scripts/iterate.sh mod <driver-dir>              # 环0：=m 模块热载 ~30s 不重启（需先应用 fragment-modular）
#   成功判据 = build-id 匹配（脚本会自己打印 ✅/❌ 并在未确认时 rc=1；见 PITFALLS #447）
LOCALVERSION=-debug-vkNN scripts/mod-loop.sh <driver-dir> --reload <mod-name>
#   设备 UTS 与本树 KV 不一致时脚本会 REFUSING；跨 KV 只能用 --bootstrap 或 --allow-mismatch
scripts/iterate.sh kernel VERSION=vkNN           # 全量重编（零写盘快环：kexec 可用，但目标无显示/USB，见 §4「迭代通道」条）
scripts/iterate.sh kernel --flash VERSION=vkNN   # 写回 boot_b（设备写：按 .pi/AGENT-OPS.md 先备份后执行）
scripts/device-lock.sh --status                  # 谁占着设备；并发子代理写操作前必查
# ★ 绝不跑 olddefconfig（会删 CONFIG_ARCH_QCOM → 死内核，PITFALLS #162）
ssh elden-root 'sync; reboot bootloader'   # 唯一软路径进 fastboot（PITFALLS #650）
#   ⛔ 作废（2026-11-19）：`./cycle.sh --soft`（sysrq-b 暖复位，到不了 ABL）与 `eldroid-bootctl` 均不可用（PITFALLS #690）
fastboot boot bootslot-b/boot_b-minbase-labellinux-20261119.img  # 零写盘·持久变体（vk192 核/DTB/initrd + 磁盘根，cmdline LABEL=linux），功能测试用（PITFALLS #93）
#   历史：boot_b-f2fs-root.img 的 cmdline = LABEL=linux18，而 linux18 已于 2026-10-31 删除 ⇒ 该件永久起不来，勿用
fastboot boot <img>                        # 零写盘·纯RAM变体（无桌面/服务）仅内核/引导级验证；先 blank 活跃槽 dtbo 否则卡 logo（PITFALLS #1/#10）
# 新单元开工三件套（先写台账，再备份，再手术）
fastboot getvar serialno; adb shell getprop ro.boot.hwboardid   # → 写进 DEVICE/README.md §2.2
sh scripts/gpt-dump.sh                                          # 打印本单元 backup_lba（禁跨容量档复用）
# b 槽三件套备份：本 ABL **无 fastboot fetch**（实测与报错全文见 PITFALLS #290）
ssh root@192.168.7.1 'dd if=/dev/disk/by-partlabel/boot_b of=/tmp/boot_b.img'  # 再取回；或从官方线刷包解出
python3 scripts/slot-attr.py show                               # 槽位属性（在 GPT attribute，非 misc）
# 设备侧三态判据（显示问题）：NOCARD / STORM / GOOD
scripts/q28-devprobe2.sh          # 在设备上跑（SSH 读全 dmesg + 查 card0）
scripts/trial.sh                  # 一次设备实验 = 一条机器可读记录（reports/trials/，--reset 必填）
```
