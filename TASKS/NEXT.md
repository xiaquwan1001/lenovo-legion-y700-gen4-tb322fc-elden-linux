## 4. 下一步（按顺序，含并行项）

> **本节只列开放项，一行一句结论 + 指针。** 历史裁决、已收口条目、N1/N2 全过程与旧编号 1–11 条**逐字**下沉 →
> `sessions/2026-11-03-TASKS-§4-待办沿革.md`（2026-11-03 前的 §4 全文，零删改）；
> **2026-11-14 的第二轮压缩**（19 个长块 → 结论+指针）沉到 `sessions/2026-11-14-TASKS-4-沿革下沉.md`（逐块 `§4-N`）。
> 功能状态只在 §1 任务行维护；未解/未收口只读 §0 与 §5；上游投递队列以 §7 为准。

**🆕 2026-11-21（全天增量，原文逐字 = `sessions/2026-11-21-§4增量块下沉.md`）——结论一行账**：
① AVB 债 ✅ 上机验收通过（vbmeta_b 重签 + `fastboot boot` 10 s 真进 Linux；`reports/vbmeta-b-resign-20261121.md`）；
② 音频 + 两侧马达 ✅ 用户实测确认；
③ 安卓 a 槽：logfs「出厂遗留」证据被推翻、判别顺序改 H5 先行（`reports/android-a-slot-laneC-20261121.md`，PITFALLS #703）；
   **★11-21 晚 H5 三发对照已做完、三发同现象失败 ⇒ H5（`vbmeta_a` 自签）与「`/data` 是 ext4」两项均排除，按用户裁决本轮不再盲试**
   （`reports/a-slot-h5-three-way-20261121.md`；连带确立两条工具事实：`qbootctl -s` 从 Linux 可用 ⇒ **切槽不需物理键**；
   分区可在 Linux 侧 `dd` 写 + 读回校验）。**恢复区「双清」作用域已用原厂 `recovery.fstab` 实证 = 只 userdata + metadata**
   （`formattable` 仅此两项；`linux17` / `boot_b` / `super` 物理分区都不在其中）。
④ UEFI b 槽基建落地（ESP+外置菜单），路 A 实测「有字没菜单」⇒ ~~唯一方向 = 重建带 esp-first 的 Mu~~ **作废（11-21 晚实测）：不需重建——esp-first 的 FD 早已在归档、repack 秒级；84 条补丁重放 OK=84/FAIL=0**（`reports/uefi-mu-espfirst-replay-20261121.md`，原账 `reports/uefi-bslot-plan-20261121.md` §6/§7）；
   **★11-21 晚 p65 上机（零写盘）：UEFI 真交棒起来了（cmdline `elden_bootpath=uefi` = UEFI 专属 token、约 40 s 进桌面、
   ABL logfs `factory_build=0`），但用户目视「没有完整 GRUB 菜单」，且 `efi: UEFI not found` ⇒ 更可能是 Mu 的 LinuxLoader
   直接读了 `boot_b` 起核，而非 ESP 的 GRUB 那一路**（报告 §7 已记账）；**★11-21 晚 p69 一发 + ESP 探针 cfg token 判据已给出答案：
   `BOOTAA64.EFI` **没有被执行** —— cmdline 里 `elden_bootpath=uefi` 有（= Mu LinuxLoader 跑到跳转）、ESP cfg 的
   `elden_esp_grub=20261121T1442` **无**、logfs `R68LOG` 计数 0（而实际喂进去的 FD 里有信标×3）⇒ 走的是「Mu LinuxLoader
   直接交核」，没走 BDS→ESP→GRUB；下一发区分「RAM 形态 UFS 读不出 ESP」vs「本载荷没进 BDS」= flashed 形态复现**
   （`reports/uefi-mu-espfirst-replay-20261121.md` §8、PITFALLS #708）；
⑤ 发行版定 Mobian（`reports/distro-upstream-feasibility-20261121.md`）；
⑥ wl2868c v12 ✅ 进树 `regulator.git for-7.5`；dwc3 v10 SENT-ready 且已投（4 封 250，lore 归档 4/4）；
⑦ 输入法/OSK P3：现机 stock trixie，5 FAIL 已修/1 判据过时已修，GTK_IM_MODULE 二选一待用户拍板（`reports/ime-osk-zero-to-usable-20261121.md`）；
⑧ ~~进 fastboot 三条软路径全灭 ⇒ 只能物理键~~ **2026-11-23 更正（PITFALLS #712）：`reboot bootloader` 一直可用**（~21 s 进 fastboot）；`reports/linux-to-fastboot-20261121.md` 只保留「BCB 不被采纳 / `qbootctl` 写失败」两条仍成立的结论；
⑨ S5 取证件两侧能造（boot/vendor_boot v4 cmdline 改写器 + doctor §27）、fastboot 假 MISS 修掉（#699）。

**当前口径（2026-10-06 立，2026-11-03 复核）**

- **本轮主线** = 尽可能覆盖硬件驱动；判据 =「命令 + 原始输出」可复现。
- **本轮不投入**：Q24（2026-10-23 停止采样——根因已指名、日常线免疫，只读 §5 Q24）。UEFI/G1-29 已于 2026-11-01 恢复推进；G1-26/27/28 已出列。
- **迭代通道**：`fastboot boot`（零写盘）/ `--flash`；**kexec 定位 = 不需显示/网络的调试快环**（K3 裁决）——`mask=1` 全链零掉电、目标内核能起（写盘 marker + `nokaslr` 实证），但带磁盘根时死于 Q28 同源 bonded DSI 初始化，且 `0154` 对 kexec 机制性无效 ⇒ **本机 kexec 拿不到显示**；工程侧见 §7 M9，全过程见归档。
- **内核基线**：`clean/base`（= vk64 内核源 `d02658e63`，tag `baseline/clean-base`）为唯一功能基线；分界与旧树处置见归档。
- **boot_b 形态 / 上机纪律 / 归因分层**：只在 `DEVICE/README.md` §1.1、`PITFALLS` #3/#115 维护，本文件不复述。

### 4.0 维度总表（**唯一派发入口**，2026-11-21 建立）

> 一行 = 一个「大方向」。**派子代理先读本表**：按维度派、不同维度可并行（主机侧），同维度内 ≤2 lane；
> 需设备的一律由主会话串行执行。每 lane 交付物必须落 `reports/` + 一句可复核判据。
> 详细沿革（11-18 → 11-21 六个长块）已逐字下沉 → `TASKS/sessions/2026-11-21-§4待办区块下沉.md`。
> **★历次 §4 增量叙事（11-21 → 11-25，6 块）已下沉**：逐字原文在 `TASKS/sessions/2026-11-27-TASKS-4-久积叙事下沉.md`；当前待办只读本表与 §4.0a。
>
> **★常设 lane（用户 2026-11-23 定，硬规则）**：每轮并行派发**至少一条通信 lane（D10）** —— 查邮件 INBOX + 我方在 **Mobian（gitlab.com/mobian1/*、salsa.debian.org/Mobian-team/*、droid-juicer MR）** 与 **phosh/phoc（gitlab.gnome.org/World/Phosh/*）** 的 MR/issue 回复；**只读，不回复不外发**（发信/推 MR 仍按 §7 逐次放行）。
> **★2026-11-26 拆分**：本表只留「号 / 维度 / 状态 / 详情」；**开放项、需设备、权威指针逐行在 `TASKS/dim/D##.md`**
> （每份 = 拆分前原行逐字；索引 = `TASKS/dim/README.md`）。要看某维度的现状全文就点进去，别在本表里塞长文。

| # | 维度 | 状态 | 详情 |
|---|---|---|---|
| **D1** | 设备日常化与运维 | ✅ | `TASKS/dim/D1.md` |
| **D2** | 上游化（主线 + Mobian） | — | `TASKS/dim/D2.md` |
| **D3** | 输入法与桌面体验 | ✅ | `TASKS/dim/D3.md` |
| **D4** | 安卓共存 / G2 | — | `TASKS/dim/D4.md` |
| **D5** | 脚本与工具卫生 | ✅ | `TASKS/dim/D5.md` |
| **D6** | 文档与踩坑精简 | — | `TASKS/dim/D6.md` |
| **D7** | UEFI / Gunyah（非主线） | — | `TASKS/dim/D7.md` |
| **D8** | G3 x86 / Steam | — | `TASKS/dim/D8.md` |
| **D10** | 通信跟踪（常设，每轮必派） | — | `TASKS/dim/D10.md` |
| **D9** | 主机稳定性与取证 | — | `TASKS/dim/D9.md` |
| **D11** | 设备发热 / 功耗 | — | `TASKS/dim/D11.md` |
| **D12** | 会话整体重启风险（Firefox「崩溃」真因） | ✅ | `TASKS/dim/D12.md` |
| **D13** | Phosh 边缘侧滑返回手势 | 🟡 | `TASKS/dim/D13.md` |
| **D14** | 数据线(SDP) 充电限流 100 mA ⇒ 净放电 | 🟡 | `TASKS/dim/D14.md` |
| **D15** | 每次输入测试都拉起新的 Firefox 窗（用户 2026-11-25 报） | 🟢 | `TASKS/dim/D15.md` |
| **D16** | 我们自己 patch 过的 systemd 单元没部署到设备（`verify.sh` 的 5 条 FAIL 背后） | 🆕 | `TASKS/dim/D16.md` |
| **D17** | 开机早期两个 A/B 守护单元都踩「块设备还没枚举」 | 🆕 | `TASKS/dim/D17.md` |
| **D18** | 自研「键盘设置」GUI（用户 2026-11-25 提：震动强度 / 词库引擎 / 按键声音 / 自定义功能键） | 🟡 | `TASKS/dim/D18.md` |
| **D20** | 下载通道（rayburst/aria2）GitHub release 302+SAS hang | 🟡 | `TASKS/dim/D20.md` |
| **D19** | 无人值守上机闭环（BL ⇄ Linux） | ✅ | `TASKS/dim/D19.md` |
| **D21** | Gunyah 线现状 （拓展项，用户 2026-11-26 要求「至少一个 lane 负责 gunyah」） | ✅ | `TASKS/dim/D21.md` |
| **D22** | 核实「传感器驱动有问题」这个说法（用户 2026-11-26 要求单独 lane 核实） | ✅ | `TASKS/dim/D22.md` |
| **D23** | 崩溃取证通道（用户 2026-11-26「先修取证」） | ⛔ | `TASKS/dim/D23.md` |
| **D24** | droidloom 附属仓库整理 + 上游缺陷/社区分叉评估（用户 2026-11-26 设常设 lane；**首轮已收口 2026-11-26，待办见行内**） | 🟡 | `TASKS/dim/D24.md` |

**维度互斥/依赖**：D1 必须先于 D7（ESP 在机的面）；D3④ 与 D1 共用一次上机窗；D4 与 D1 争同一收发窗口（**分时**）；D2 的 G7 与 D4 不可同轮（都要 a/b 槽控制权）。

### 4.0a★ 2026-11-27 本轮收口（结论一行账；正文在指针处，本节不再展开）

| # | 项 | 结果（判据可复核） | 指针 |
|---|---|---|---|
| **N1** | **用户态镜像 13 组「待裁定权威归属」** | ✅ **全部裁定并落地**：门 `同 sha 配对 20→35 ｜ 漂移 WARN 14→0 ｜ FAIL 0`；`verify.sh --offline` FAIL=0；doctor §32 绿；`--selftest` 仍能判红 | `reports/userland-mirror-adjudication-20261127.md` |
| **N2** | **D16 「渲染了但设备上没有」34 条** | ✅ 分类 34/34（部署 18｜豁免 13｜退役 3）→ **设备侧已装 13 件、启用 7 个单元**（backlight-floor / net-selfheal / wifi-scan-refresh / elden-bootlog / pstore-catch / elden-powerlog + 配置），`verify.sh` 在线 **WARN 34→5**（剩 5 = 依赖 `waydroid init` 的那组）；3 件加 `RETIRED` 头并从 MANIFEST 摘除；13 条豁免进新文件 `tools/verify-f-waivers.tsv` | `reports/d16-unit-deploy-classify-20261127.md` |
| **N3** | **T8 `elden-wake` 纳入部署门** | ✅ `deploy-desktop-shell.sh` 新增 §18 四件判据（两 unit sha / path enabled / path active / helper 可执行且 sha），`--check` 两次输出完全一致、MISS=0 | `reports/t8-elden-wake-check-20261127.md` |
| **N4** | **Moonlight 客户端（G3 载体件）** | ✅ **部署 + 配对 + 起流全通**：V+ 6.5.7 aarch64 AppImage 入 `/opt/moonlight-vplus`；Sunshine 侧 PIN 提交成功（新 API 要 `pairing_id`）；设备起 Desktop 流成功（**FFmpeg 软解**，日志 `FFmpeg-based video decoder chosen`）。⚠️ 硬件解码 = 另立 **Q36**（`/dev/video*` 零个、iris 节点 disabled） | `reports/moonlight-client-deploy-20261127.md` |
| **N5** | **硬件视频解码（iris/SM8750）** | 🆕 **备料完成、未启用**：vendor 镜像抽出 6 个 VPU 固件，`vpu35_4v.mbn`（signed，2 392 776 B，`vfw-3.5:rel0030`）= 与 `sm8750_data → iris_vpu35_p4_gen2_desc` 同代；**设备已装 `/lib/firmware/qcom/vpu/vpu35_p4.mbn`**；驱动 `of_match` 有 `qcom,sm8750-iris`、无 HFI 版本门，真门 = `qcom_pas_auth_and_reset(PAS 9)`；**唯一阻塞 = 板级 DTS 要 `&iris { status="okay" }` + 重编 DTB/打 boot.img**（需一次重启窗） | `TASKS/GAPS.md` **Q36**、`reports/hwdec-iris-sm8750-feasibility-20261127.md` |
| **N6** | **D20 下载通道空等** | ✅ **主假设被否证**：降连接数无效（20 连接与 1 连接都 4/4 完整）；真因 = **HTTP 403（SAS 过期）+ `max-tries=0` 无限重试**（`status=active`、0 字节、RPC `errorMessage` 恒空）。落地建议 = `~/.local/share/dev.aninsomniacy.rayburst/config.json` 的 `preferences.maxTries: 5`（**待用户点头**，属改本机工具配置） | `reports/rayburst-redirect-ab-20261127.md` |
| **N7** | **D24 droidloom 本地 patch** | ✅ 4 条 patch 落 `patches/local/droidloom-local-20261127/`，在 release 51 源码上 `git apply --check` 按序 **4/4 通过**（003 依赖 002） | `reports/droidloom-local-patches-20261127.md` |
| **N8** | **D10 通信（常设）** | ✅ 窗口 05:55–06:06Z：**0 封新人类信**、7 条在飞系列人类零回复、Mobian `!46` 96 h 无变化、droidloom 四条非我方；**唯一需用户放行** = phosh `!2005` 回 guidog（含 AI 披露要求） | `reports/comms-track-20261127.md` |

### 4.0a 现役待办（2026-11-26 收尾时点；**唯一权威 = 本节 + 各行指针**）

> 只列「下一步可执行」的项；已完成项不在这里复述（它们在各维度文件与 `reports/`）。每条 ≤ 半天，除非标注。

| # | 待办 | 判据（怎么算做完） | 阻塞/前置 | 指针 |
|---|---|---|---|---|
| **T1** | droidloom：给上游 `#48` 补我方复现数据（校园网封校外 UDP/53、探针 204 实测、`10.177.0.2` 在线证据） | 评论发出 + `reports/droidloom-cell-network-20261126.md` §8 记 issue URL | **需用户点头**（外部发帖） | `reports/droidloom-upstream-lane-20261126.md` §D2-1 |
| **T2** | droidloom：**裁决已改（2026-11-27，D24 第二轮）= 不整包跟 fork，只取 4 条 patch**（`patches/local/` 形态，各带退役判据）：`WifiProvisioning` 自愈（`gotakllc@4e995f2`，author = 维护者本人、11-26T20:07Z、**未进 main**）/ 宿主 resolver 进 lease（`EvilBorsch@2712d37`）/ 去 `--forward-signals` / `runuser` 路径 | ① cell 仍 `Android is ready`；② **删掉 `/usr/local/bin/unshare` 后仍能起**；③ lease DNS = 宿主 resolver ⇒ 可删 `ip dl_dns_redirect` | 需备份当前 runtime；可回退；整包 fork 触「>1 GiB 下载」红线（EB 无发布 `.deb`） | `reports/droidloom-upstream-cluster-20261127.md` §3/§5；**2026-11-27 父代理解包 `source-51` 核对：这 4 处 51 里都没有**（`development.rs:493` 仍 `--forward-signals`、`package-support/main.rs:429/479` 仍 `runuser`、`development_network.rs:33` + `dhcp_responder.rs:434` 仍硬编码 `1.1.1.1/8.8.8.8`、`WifiProvisioning` 已改名）⇒ 升级不等于修好，patch 仍要打（`reports/droidloom-release-download-verify-20261127.md` §4） |
| **T3** | droidloom：IME 主因判定实验（占位 IME 状态机缺陷 vs 宿主缺 `denial_text_input_panel_manager_v1`） | **②「宿主缺 `denial_text_input_panel_manager_v1`」已被否证（2026-11-27）**：上游契约用普通 `zwp_text_input_v3`、原文 "Denial needs no changes" ⇒ 判据改为「占位 IME 状态机 / 升级后再判」：现役 `0.1.0-49` 应**先升 `0.1.0-51` 再判**（release 50 有 5 条提交直接改 IME/键盘路径 + 新增 `TaskAction::KeyboardInset`） | 现已有绕行（Fossify IME），不阻塞使用；升级需设备窗 | `reports/droidloom-ime-keyboard-20261126.md` §5、`reports/droidloom-upstream-cluster-20261127.md` |
| **T4** | droidloom：把 cell DNS 重定向做成**跨重启持久**（独立 systemd unit，additive） | 重启后 `nft list ruleset \| grep dl_dns_redirect` 命中且 cell `VALIDATED`（**已实测 FAIL**：2026-11-26 22:0x 重 boot 后 = 0 条，`reports/droidloom-cell-network-20261126.md` §9） | T2 若落地可整件删 | `reports/droidloom-cell-network-20261126.md` §8 待办 / §9 |
| **T5** | droidloom：中文输入（Fossify 无中文布局）+ 整机重启后默认 IME 持久性实测 | 重启后默认 IME 仍 Fossify；中文可输入 | 需一次重启窗 | `reports/droidloom-real-ime-20261126.md` 残余风险 |
| **T6** | 传感器 `#692`：**✅ 2026-11-27 收口（出数实证）** —— 内核侧假说 A 已否证、PD 依赖面已排除、PMIC/PON 侧判不了根因（都不重开）；真因链 = droid-juicer 配置 0 字节占位 + `hexagonrpcd` 的 `-R` 布局不匹配 ⇒ DSP 断言 ⇒ 本板整机复位。换真 vendor 配置 + 扁平 `-R` 树 + 宿主 udev/代理接线后 **`HasAccelerometer/AmbientLight/Proximity` 三 true、`ssccli` 连续出值（Z≈9.5）** | 已完成（验收判据见报告 §2 五步） | 残留（不阻塞出数）：①**开机自动生效已落地**（`elden-sensorspd.service` + `iio-sensor-proxy` enabled，真重启后三属性 true）②~~attach 末尾 `free(): invalid next size`~~ **已修（2026-11-27 ASan）**：`apps_std_procs[]` 索引错位 + `n_procs` 57，现 `NRestarts=0`（`PITFALLS #742`） ③registry 无真写后端（343 条 0 字节骨架，标定会丢） | `reports/sensors-ssc-restored-20261127.md`、`PITFALLS #741`④**可写 overlay 已交付（2026-11-27）**：`-O /var/lib/hexagonrpc`，DSP registry 真落盘（`cam_registry_dump.txt` 18.6 KB / `fstempfile` 14.3 KB / `sns_reg_version` 9 B） |
| **T7** | 上游：v11 备料已在（`cover-scope-section.txt`），**等下个真实修订触发**再发（不回 sashiko 机器人线程） | 维护者提同一问题或新 review 到达 | upstream-gated | `reports/dts-v10-sashiko-20261126.md` |
| **T8** | `elden-wake` 纳入 `deploy-desktop-shell.sh --check`（与 udev/phosh/phoc 同级判据） | 设备 `--check` 幂等命中该判据 | 无 | `reports/panel-wake-service-20261126.md` §4 |
| ~~**T9**~~ | ✅ **2026-11-27 已交付（父代理独立复核）**：`scripts/check-userland-mirror.sh` 落地（`--check`/`--diff <名>`/`--selftest`，三态 0/1/2；现查 同 sha 配对 **20** ｜ 白名单漂移(WARN) **14 对 = 13 组** ｜ 白名单外 **0** ｜ 设备专有件 78；父代理自行 sha256 复算 20/13 与门一致，`--selftest` 反样本 rc=1 真红）；doctor 新增 **§32**（`scripts/doctor/32-userland-mirror.sh`）＋接线 `packaging/elden-userland/tools/verify.sh --offline`（42 条 ok / FAIL=0）；`check-doctor` 仍 **FAIL=0**。**残留（需用户裁定，不阻塞门）**：13 组同名不同内容的「谁是权威」（`init` 380 行差、`charge-watch.sh` 189 行、`q28-watchdog.sh` 52 行…，逐组 mtime/方向/待裁定问题见报告；注意 **`init`/`time-sync.sh`/`net-up.sh` 三组是 `files/`（设备快照）更新**，与直觉相反） | 已完成（门绿）；残留 = 13 组权威归属裁定 | 已交付 | `reports/userland-mirror-gate-20261127.md`、`scripts/check-userland-mirror.sh`、`scripts/doctor/32-userland-mirror.sh` |
| ~~**T10**~~ | ✅ **2026-11-27 收口（710/710，rc=0）**：回填 165 篇 + 判据门加固。**过程有假绿**：首轮回填 165 行写成同一句模板用途（字数够、零信息），父代理加固判据（空句黑名单 + 同句复用 >3 次作废 + 行点名 >4 个报告需另附 ≥40 字说明 + 路径 token 正则收紧），重扫露出 32 篇，逐篇改用报告自身 H1 标题作用途 ⇒ **`--check` rc=0 / `--selftest` 15 条断言 FAIL=0**；10 篇主题索引在 `TASKS/sessions/2026-11-27-reports索引-*.md`。教训 = `PITFALLS #745` | 已完成 | — | `reports/reports-index-backfill-20261127.md`（含父代理复核节）、`scripts/reports-orphan-check.py` |
| ~~**T11**~~ | ✅ **2026-11-26 已执行（`ca787f3f`，2026-11-27 复核确认）**：早于 11-25 的 27 块逐字搬 `archive/topics/INDEX-§0-沿革-20261118-25.md`（81.8 KB），`INDEX.md` 122 744 → **44 416 B**；随后 11-26/11-27 增量回填到 57 KB（§0 = 33.6 KB / 190 行），即「近 3 天保留」口径本身；目标 ≤120 行是**每轮滚动执行**的软线，不是一次到位 | 已完成 | — | `.pi/plans/2026-11-27-文档精简拆分归档.md` B1、`archive/topics/INDEX-§0-沿革-20261118-25.md` |
| ~~**T12**~~ | ✅ **2026-11-26 已收口**：5 处 `*.jsonl` 硬匹配改「`.jsonl` + `.jsonl.gz`」（`sessfind`/`sess`/`recent-sessions.sh`/`doctor/15-timeline.sh`/`gen-sessions.py`），>30 天会话 237 个批量 gzip（mtime 用 `copystat` 保留，`/resume` 只见近 30 天）⇒ **498.7 → 125.3 MiB（省 373 MiB）**；工具侧正/负样本各验一次（手工 `.jsonl.gz` 探针能被 `sessfind`/`sess`/`recent-sessions` 读到） | 已完成 | — | `PITFALLS #736` + 本节 |
| **T15** | droidloom：**先把现役 `0.1.0-49` 升到上游 `0.1.0-51`**（`Package release 51` = `4df8af9`，11-26T18:22Z）再判 IME | **资产已备好（2026-11-27 父代理亲测）**：`~/dl-droidloom-51/` = `image-51` 66,871,960 B + `runtime-51` 11,131,906 B + `source-51` 4,104,435 B（字节与 API 逐字节一致、`zstd -t` 全过）；**`image-51` 的 `.PKGINFO` 依赖 `droidloom-base=0.1.0-49`** ⇒ base 复用现有 903 MB，不用重下。装完判据 = `droidloomctl status` 仍 `Android is ready`、`showSoftInput` 是否仍失败 | 需设备窗（安装 + 重启）；本机禁用编译（过热回 BL） | `reports/droidloom-release-download-verify-20261127.md`、`reports/droidloom-upstream-cluster-20261127.md` §2/§4 |
| ~~**T16**~~ | ✅ **2026-11-27 收口（父代理独立复核通过）**：62 条（52 零引用 + 10 仅注释）全部重判 —— **① 退役 37**（脚本头加 `RETIRED 2026-11-27：<原因/替代件/可复核报告>`，不删文件）+ **② 补指针 25**（`RESOURCES/README.md` §5 新增 25 行、新立 4 个面：桌面栈构建/调试、自检门禁、主机环境、Win-x86 转译 PoC）+ **③ 0 条**| 已完成：`scripts/` 现查**零引用脚本 = 0**（父代理独立复算，含文档面语料）；抽查 4 条退役理由的「可复核报告」全部存在且真提到该脚本（`reports/script-audit-edl-20261118.md` 3 处、`reports/audit-20261119/A3-scripts-audit.tsv` 1 处、`reports/script-cleanup-audit-20261112.md` 1 处、`reports/scripts-index-20261120.md` 1 处） | 已完成 | — | `reports/scripts-ref-audit-t16-20261127.md`、`RESOURCES/README.md` §5 |
| ~~**T14**~~ | ✅ **2026-11-27 收口（③档残留已由 T16 补齐）**：`scripts/` **363** 入口按 A7「14 份活面文档」口径重算 = 命中 **193（53.5%）**；死引用自报 7 条 → **父代理复核 5 条是误报**（`env-pass/scripts/…`、`archive/…-retired-scripts/…` 的尾部 `scripts/` 被审计正则当仓根，文件全在盘）+ 1 条跨树误读（`checkpatch.pl` 指内核树）+ 1 组纠正「q28 取证脚本本机已无」这个与盘上事实相反的旧错述。已落地 = `RESOURCES/README.md` §5 的 **49 行指针** + 3 个 `RETIRED` 头注 + 死引用归零。**残留见 T16**（③「保持私有」131 条里只有 **69** 条真有调用点）。 | 已完成 | — | `reports/scripts-ref-audit-20261127.md`（含父代理复核节）、`RESOURCES/README.md` §5 |
| ~~**T13**~~ | ✅ **2026-11-27 随 T6 收口**：真 vendor 配置（`super` 8 段稀疏拼接 → `lpunpack -p vendor_a` → `debugfs rdump /etc/sensors`）+ 扁平 `-R` 树 `/var/lib/hrpcd-root` + `81-libssc-elden.rules` + `iio-sensor-proxy` ⇒ 三属性 true、`ssccli` 出真值 | 已完成 | 后续可选：34/35/36 假成功（常驻）+ 真写后端（registry 持久化） | `reports/sensors-ssc-restored-20261127.md` |
| ~~**T10**~~ | ✅ **2026-11-26 已收口（gitignore + 判据脚本两部分）**：`reports/artifacts` 的 **173 条逐目录规则 → 32 行统一块**（默认不入库 + 白名单 md/txt/清单/patch/diff/小图；抓手 = 「ignored 条目数前后同为 542」+ 探针）；**468 篇这个数不复现** —— A16 手数为 225/32.5%、468/59%，落地脚本在三种语料刻度上分别为 644/551/158 孤儿 ⇒ 以 `scripts/reports-orphan-check.py` 的 `all` 刻度（158）为唯一口径。**剩余 = 158 篇补指针**（见上条 T10） | 已完成 | 158 篇孤儿补指针 = 未做 | `reports/fs-dedup-20261127.md`、`reports/arch-audit-20261127.md` A16 |

### 4.1 常设项（每轮/每收尾都做，不占维度）
- **H1 资产清理** —— 正文 = `RESOURCES/README.md` §3；**2026-11-25 用户授权轮已实删 79 G**（`/tmp` 本项目 8 件 + `build/` 链接产物，`/` 82%→73%），执行记录与「明确不删」清单 = `reports/disk-cleanup-20261125.md`，取证 = `reports/tmp-forensics-20261125.md` / `reports/build-residue-verify-20261125.md`；`out-archive.py` KEEP 表同日修正（vk189/vk192 免误归档）。
- **H2 完整性巡检** —— `bash scripts/check-doctor.sh`（FAIL=0）+ 镜像基线复算**必须走 O_DIRECT**（`PITFALLS #513`）+ 仓 `git fsck`；WARN 逐条归类到「本轮修 / 已登记豁免」。
- **需要物理 POR 的样本一律排在最后**（用户在机旁时一次做完）。

### 4.2 收尾轮次纪律（2026-10-23 用户定，仍有效）

- TF 卡（G1-6/Q10）已收口出列；Q28 补采样与 Q32 已于 2026-10-24 收口 ⇒ 现无待取 POR 样本；判据备查 → 归档。

### 收尾轮次纪律（2026-10-23 用户定，仍有效）

- **需要物理 POR 的样本一律排在最后**（用户在机旁断电/开机时一次做完），其间只做不重启的项。
- TF 卡（G1-6/Q10）已收口出列；**Q28 补采样与 Q32 已于 2026-10-24 收口**，其余「需要 POR」项全部关闭 ⇒ 现无待取 POR 样本；判据备查 → 归档。
---

