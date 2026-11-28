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
| **D13** | Phosh 边缘侧滑返回手势 | 🟡 主体可用（2026-11-28 放宽 `-r 45` + 多档手势，弧线/死区角均触发；残留 = 吞事件（Firefox 误滚动）需裁决） | `TASKS/dim/D13.md` |
| **D14** | 数据线(SDP) 充电限流 100 mA ⇒ 净放电 | ✅（2026-11-28 ③ 反向接法上机结项：PD 9 V/1.3 A 供电成立，顺手修 `charge-watch` 两处误动作） | `TASKS/dim/D14.md` |
| **D15** | 每次输入测试都拉起新的 Firefox 窗（用户 2026-11-25 报） | 🟢 | `TASKS/dim/D15.md` |
| **D16** | 我们自己 patch 过的 systemd 单元没部署到设备（`verify.sh` 的 5 条 FAIL 背后） | ✅（2026-11-27 晚：传感器竞态固化成 `elden-sensorproxy-sync` + deploy §19 四件判据，真重启与失败路径双验） | `TASKS/dim/D16.md` |
| **D17** | 开机早期两个 A/B 守护单元都踩「块设备还没枚举」 | 🆕 | `TASKS/dim/D17.md` |
| **D18** | 自研「键盘设置」GUI（用户 2026-11-25 提：震动强度 / 词库引擎 / 按键声音 / 自定义功能键） | 🟡 | `TASKS/dim/D18.md` |
| **D20** | 下载通道（rayburst/aria2）GitHub release 302+SAS hang | 🟢 过时（2026-11-28 用户裁决：不再跟踪，删待办项；原取证留档） | `TASKS/dim/D20.md` |
| **D19** | 无人值守上机闭环（BL ⇄ Linux） | ✅ | `TASKS/dim/D19.md` |
| **D21** | Gunyah 线现状 （拓展项，用户 2026-11-26 要求「至少一个 lane 负责 gunyah」） | ✅ | `TASKS/dim/D21.md` |
| **D22** | 核实「传感器驱动有问题」这个说法（用户 2026-11-26 要求单独 lane 核实） | ✅ | `TASKS/dim/D22.md` |
| **D23** | 崩溃取证通道（用户 2026-11-26「先修取证」） | ⛔ | `TASKS/dim/D23.md` |
| **D24** | droidloom 附属仓库整理 + 上游缺陷/社区分叉评估（用户 2026-11-26 设常设 lane；**首轮已收口 2026-11-26，待办见行内**） | 🟡 | `TASKS/dim/D24.md` |

**维度互斥/依赖**：D1 必须先于 D7（ESP 在机的面）；D3④ 与 D1 共用一次上机窗；D4 与 D1 争同一收发窗口（**分时**）；D2 的 G7 与 D4 不可同轮（都要 a/b 槽控制权）。

### 4.0a★ 2026-11-27 本轮收口（结论一行账；正文在指针处，本节不再展开）

| # | 项 | 结果（判据可复核） | 指针 |
|---|---|---|---|
| 1 | `reboot2` 过时开关退役 | 真件留档（sha `0c68ee5f…`）+ PATH 换 810 B 拒绝壳（`rc=1`）；`scripts/retire-reboot2.sh` 幂等；rootfs 重建会装回 ⇒ 重建后重跑 | `PITFALLS #749`、`reports/upstream-coresight-fixes-20261127.md` §1 |
| 2 | CTCU/TPDA 缺 `MODULE_DEVICE_TABLE`（上游缺陷） | v1 已投 3×250（cover `<20261127113137.931578-1-…>`）；checkpatch 0E/0W/0C；真机 alias + 自动加载 | `patches/upstream/coresight-moduletable-20261127/`（README/GATES/SENT） |
| 3 | SM8750 TNOC 缺 periphid（连带 binding） | v1 已投 3×250（cover `<20261127113158.932414-1-…>`）；dtbs_check/dt_binding_check/checkpatch 全绿；上机 AMBA 未绑定 0/28 | `patches/upstream/sm8750-tnoc-periphid-20261127/` |
| 4 | vk196 持久化部署 | `flash-b.sh` 首次写盘 → `boot_b` 持久跑 vk196；`qbootctl` `_b Active/Successful/Bootable=1`；回滚件 `bootslot-b/boot_b-device-20261127-vk192.img`（sha `68d3dc46…`） | `versions/vk-registry.tsv`、`reports/upstream-coresight-fixes-20261127.md` §4 |


| # | 项 | 结果（判据可复核） | 指针 |
|---|---|---|---|
| **N1** | **用户态镜像 13 组「待裁定权威归属」** | ✅ **全部裁定并落地**：门 `同 sha 配对 20→35 ｜ 漂移 WARN 14→0 ｜ FAIL 0`；`verify.sh --offline` FAIL=0；doctor §32 绿；`--selftest` 仍能判红 | `reports/userland-mirror-adjudication-20261127.md` |
| **N2** | **D16 「渲染了但设备上没有」34 条** | ✅ 分类 34/34（部署 18｜豁免 13｜退役 3）→ **设备侧已装 13 件、启用 7 个单元**（backlight-floor / net-selfheal / wifi-scan-refresh / elden-bootlog / pstore-catch / elden-powerlog + 配置），`verify.sh` 在线 **WARN 34→5**（剩 5 = 依赖 `waydroid init` 的那组）；3 件加 `RETIRED` 头并从 MANIFEST 摘除；13 条豁免进新文件 `tools/verify-f-waivers.tsv` | `reports/d16-unit-deploy-classify-20261127.md` |
| **N3** | **T8 `elden-wake` 纳入部署门** | ✅ `deploy-desktop-shell.sh` 新增 §18 四件判据（两 unit sha / path enabled / path active / helper 可执行且 sha），`--check` 两次输出完全一致、MISS=0 | `reports/t8-elden-wake-check-20261127.md` |
| **N4** | **Moonlight 客户端（G3 载体件）** | ✅ **部署 + 配对 + 起流全通**：V+ 6.5.7 aarch64 AppImage 入 `/opt/moonlight-vplus`；Sunshine 侧 PIN 提交成功（新 API 要 `pairing_id`）；设备起 Desktop 流成功（**FFmpeg 软解**，日志 `FFmpeg-based video decoder chosen`）。⚠️ 硬件解码 = 另立 **Q36**（`/dev/video*` 零个、iris 节点 disabled） | `reports/moonlight-client-deploy-20261127.md` |
| **N5** | **硬件视频解码（iris/SM8750）** | 🆕 **备料完成、未启用**：vendor 镜像抽出 6 个 VPU 固件，`vpu35_4v.mbn`（signed，2 392 776 B，`vfw-3.5:rel0030`）= 与 `sm8750_data → iris_vpu35_p4_gen2_desc` 同代；**设备已装 `/lib/firmware/qcom/vpu/vpu35_p4.mbn`**；驱动 `of_match` 有 `qcom,sm8750-iris`、无 HFI 版本门，真门 = `qcom_pas_auth_and_reset(PAS 9)`；**唯一阻塞 = 板级 DTS 要 `&iris { status="okay" }` + 重编 DTB/打 boot.img**（需一次重启窗） | `TASKS/GAPS.md` **Q36**、`reports/hwdec-iris-sm8750-feasibility-20261127.md` |
| **N7** | **D24 droidloom 本地 patch** | ✅ 4 条 patch 落 `patches/local/droidloom-local-20261127/`，在 release 51 源码上 `git apply --check` 按序 **4/4 通过**（003 依赖 002） | `reports/droidloom-local-patches-20261127.md` |
| **N8** | **D10 通信（常设）** | ✅ 窗口 05:55–06:06Z：**0 封新人类信**、7 条在飞系列人类零回复、Mobian `!46` 96 h 无变化、droidloom 四条非我方；**唯一需用户放行** = phosh `!2005` 回 guidog（含 AI 披露要求） | `reports/comms-track-20261127.md` |

### 4.0a 现役待办（2026-11-28 收尾时点；**唯一权威 = 本节 + 各行指针**）

> 只列「下一步可执行」的项；已完成项不在这里复述（它们在各维度文件与 `reports/`）。每条 ≤ 半天，除非标注。

| # | 待办 | 判据（怎么算做完） | 阻塞/前置 | 指针 |
|---|---|---|---|---|
| **T1** | droidloom：给上游 `#48` 补我方复现数据（校园网封校外 UDP/53、探针 204 实测、`10.177.0.2` 在线证据） | 评论发出 + `reports/droidloom-cell-network-20261126.md` §8 记 issue URL | **需用户点头**（外部发帖） | `reports/droidloom-upstream-lane-20261126.md` §D2-1 |
| ~~**T2**~~ | droidloom：**裁决已改（2026-11-27，D24 第二轮）= 不整包跟 fork，只取 4 条 patch**（`patches/local/` 形态，各带退役判据）：`WifiProvisioning` 自愈（`gotakllc@4e995f2`，author = 维护者本人、11-26T20:07Z、**未进 main**）/ 宿主 resolver 进 lease（`EvilBorsch@2712d37`）/ 去 `--forward-signals` / `runuser` 路径 | ① cell 仍 `Android is ready`；② **删掉 `/usr/local/bin/unshare` 后仍能起**；③ lease DNS = 宿主 resolver ⇒ 可删 `ip dl_dns_redirect` | ✅ **2026-11-27 深夜：3/4 已落地并上机验收**（002 去 `--forward-signals` + 003 宿主 resolver 进 lease + 004 `runuser` 路径；承接二进制是 **`droidloomd`** 不是 `droidloom-supervisor`，只换后者不生效）——判据全绿：cell `Android is ready`、删 `/usr/local/bin/unshare` 后仍起、cell `DnsAddresses` 前两条 = 宿主 resolver 且 `dl_dns_redirect` = 0 + cell 内 `ping www.ustc.edu.cn` 直通。**残留 = 001（WifiProvisioning 自愈）未落地：属 Android systemui，要跑包构建器（podman+AOSP 缓存+Arch ARM sysroot，>1 GiB 下载红线）⇒ 待裁决**。构建/部署/回滚 = `patches/local/droidloom-local-20261127/BUILD.md`；整包 fork 仍不做 | `reports/droidloom-upstream-cluster-20261127.md` §3/§5；**2026-11-27 父代理解包 `source-51` 核对：这 4 处 51 里都没有**（`development.rs:493` 仍 `--forward-signals`、`package-support/main.rs:429/479` 仍 `runuser`、`development_network.rs:33` + `dhcp_responder.rs:434` 仍硬编码 `1.1.1.1/8.8.8.8`、`WifiProvisioning` 已改名）⇒ 升级不等于修好，patch 仍要打（`reports/droidloom-release-download-verify-20261127.md` §4） ；**001 WifiProvisioning 自愈（需重编 Android 镜像）用户 2026-11-27 深夜裁决：暂缓不做**（磁盘需 ~120GiB、Arch 容器+AOSP 首编数小时，收益可由宿主 unit 替代，评估见 `.pi/plans/2026-11-27-T2-001收益与T5解释.md`） |
| ~~**T3**~~ | droidloom：IME 主因判定实验（占位 IME 状态机缺陷 vs 宿主缺 `denial_text_input_panel_manager_v1`） | ✅ **2026-11-27 晚全链收口**：① `denial_text_input_panel_manager_v1` 假说早前已否证 ② **51 未修**（仍 `onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE`，宿主无 OSK 窗口）③ 已按「默认允许外发」策略**直接提上游 issue**：**<https://github.com/denialwm/droidloom/issues/65>**（含 49/51 两版日志、复现命令、`mInputShown` 差异、Fossify 绕行对照、AI 披露；正文原件 `reports/artifacts/droidloom-ime-issue-20261127/body.md`） | 已完成（等上游回复） | `reports/droidloom-upgrade-51-ime-20261127.md` §2 |
| ~~**T4**~~ | droidloom：把 cell DNS 重定向做成**跨重启持久**（独立 systemd unit，additive） | 重启后 `nft list ruleset \| grep dl_dns_redirect` 命中且 cell `VALIDATED`（**已实测 FAIL**：2026-11-26 22:0x 重 boot 后 = 0 条，`reports/droidloom-cell-network-20261126.md` §9） | ✅ **2026-11-27 深夜作废（随 T2 的 003 落地）**：cell 直接走宿主 resolver，`dl_dns_redirect` 无需存在（复核 `nft … \| grep -c dl_dns_redirect` = **0**、cell 内 `ping www.ustc.edu.cn` 直通）；仓内也无任何脚本/unit 装这条规则 ⇒ 不做持久化 unit | `reports/droidloom-cell-network-20261126.md` §8 待办 / §9 |
| ~~**T5**~~ | droidloom：中文输入（Fossify 无中文布局）+ 整机重启后默认 IME 持久性实测 | ✅ **默认 IME 持久性已测（2026-11-27 深夜，真重启）**：重启后新起的 cell 里 `settings get secure default_input_method` 仍 `org.fossify.keyboard/...SimpleKeyboardIME`。🟢 **中文输入已打通（2026-11-27 深夜经 T30 闭合：Trime=默认、「nihao」→「你好」）**；历史：已装 Trime 3.3.13（`droidloomctl install`，`ime list` 已注册、可 `ime set`），但首启落 `SetupActivity` 且自报 `Skip starting rime: storage not available!`（词库未部署）⇒ 已恢复默认 Fossify + force-stop Trime。**下次需有人值守 10 分钟**走完向导并裁决「Fossify=英文 / Trime=中文」二者取一 | 需一次有人值守窗口 | `reports/droidloom-real-ime-20261126.md` 残余风险 ；**用户 2026-11-27 深夜选 Trime**（不要 Fossify）；真正阻塞 = Trime 3.3.13 首启要 SAF 选数据目录 + setup 向导，见 **T30** |
| **T6** | 传感器 `#692`：**✅ 2026-11-27 收口（出数实证）** —— 内核侧假说 A 已否证、PD 依赖面已排除、PMIC/PON 侧判不了根因（都不重开）；真因链 = droid-juicer 配置 0 字节占位 + `hexagonrpcd` 的 `-R` 布局不匹配 ⇒ DSP 断言 ⇒ 本板整机复位。换真 vendor 配置 + 扁平 `-R` 树 + 宿主 udev/代理接线后 **`HasAccelerometer/AmbientLight/Proximity` 三 true、`ssccli` 连续出值（Z≈9.5）** | 已完成（验收判据见报告 §2 五步） | 残留（不阻塞出数）：①**开机自动生效已落地**（`elden-sensorspd.service` + `iio-sensor-proxy` enabled，真重启后三属性 true）②~~attach 末尾 `free(): invalid next size`~~ **已修（2026-11-27 ASan）**：`apps_std_procs[]` 索引错位 + `n_procs` 57，现 `NRestarts=0`（`PITFALLS #742`） ③registry 无真写后端（343 条 0 字节骨架，标定会丢） | `reports/sensors-ssc-restored-20261127.md`、`PITFALLS #741`④**可写 overlay 已交付（2026-11-27）**：`-O /var/lib/hexagonrpc`，DSP registry 真落盘（`cam_registry_dump.txt` 18.6 KB / `fstempfile` 14.3 KB / `sns_reg_version` 9 B） |
| **T7** | 上游：v11 备料已在（`cover-scope-section.txt`），**等下个真实修订触发**再发（不回 sashiko 机器人线程） | 维护者提同一问题或新 review 到达 | upstream-gated | `reports/dts-v10-sashiko-20261126.md` |
| **T8** | `elden-wake` 纳入 `deploy-desktop-shell.sh --check`（与 udev/phosh/phoc 同级判据） | 设备 `--check` 幂等命中该判据 | 无 | `reports/panel-wake-service-20261126.md` §4 |
| ~~**T9**~~ | ✅ **2026-11-27 已交付（父代理独立复核）**：`scripts/check-userland-mirror.sh` 落地（`--check`/`--diff <名>`/`--selftest`，三态 0/1/2；现查 同 sha 配对 **20** ｜ 白名单漂移(WARN) **14 对 = 13 组** ｜ 白名单外 **0** ｜ 设备专有件 78；父代理自行 sha256 复算 20/13 与门一致，`--selftest` 反样本 rc=1 真红）；doctor 新增 **§32**（`scripts/doctor/32-userland-mirror.sh`）＋接线 `packaging/elden-userland/tools/verify.sh --offline`（42 条 ok / FAIL=0）；`check-doctor` 仍 **FAIL=0**。**残留（需用户裁定，不阻塞门）**：13 组同名不同内容的「谁是权威」（`init` 380 行差、`charge-watch.sh` 189 行、`q28-watchdog.sh` 52 行…，逐组 mtime/方向/待裁定问题见报告；注意 **`init`/`time-sync.sh`/`net-up.sh` 三组是 `files/`（设备快照）更新**，与直觉相反） | 已完成（门绿）；残留 = 13 组权威归属裁定 | 已交付 | `reports/userland-mirror-gate-20261127.md`、`scripts/check-userland-mirror.sh`、`scripts/doctor/32-userland-mirror.sh` |
| ~~**T10**~~ | ✅ **2026-11-27 收口（710/710，rc=0）**：回填 165 篇 + 判据门加固。**过程有假绿**：首轮回填 165 行写成同一句模板用途（字数够、零信息），父代理加固判据（空句黑名单 + 同句复用 >3 次作废 + 行点名 >4 个报告需另附 ≥40 字说明 + 路径 token 正则收紧），重扫露出 32 篇，逐篇改用报告自身 H1 标题作用途 ⇒ **`--check` rc=0 / `--selftest` 15 条断言 FAIL=0**；10 篇主题索引在 `TASKS/sessions/2026-11-27-reports索引-*.md`。教训 = `PITFALLS #745` | 已完成 | — | `reports/reports-index-backfill-20261127.md`（含父代理复核节）、`scripts/reports-orphan-check.py` |
| ~~**T39**~~ | ✅ **2026-11-28 全部收口**：① 指针回填 —— `--check` rc=0 / 758–759 篇 **100%** / 孤儿 0（8 行落角度语料）；② 判据统一 —— 新增 **doctor §33**（`scripts/doctor/33-reports-orphan.sh`，三态 + 委托 `reports-orphan-check.py --check` + 自带 `--selftest` 反作弊 + 「唯一孤儿是 §31 探针则复扫」的并发隔离），§8f 降级为「粗筛，真值以 §33 为准」，`.pi/AGENT-OPS.md` §5 与 §4.1 H2 同步。**父代理独立自证**：造一个临时孤儿文件（`reports/` 下临时 md，验完即删）⇒ `--only 33` FAIL=1；删掉 ⇒ FAIL=0；全量 `check-doctor` FAIL=0 / WARN=5
| ~~**T40**~~ | ✅ **2026-11-28 10:36 CST 已实发**（`Result: 250`，MID `<20261128023628.24408-1-xiaqinghuan@mail.ustc.edu.cn>`，lore 线程 7 封 / 16 939 B gzip 实证，Subject 未改写）—— 正文同时回应 Bryan：1/3 与主线 `1facae9bc3c1` 重复 ⇒ 请 drop、3/3 已被主线 crop seed 取代 ⇒ dropped；本机 checkpatch v2=2E/4W → v3=0E，代码 diff 与 v2 逐字节同。**iris colorspace v3 外发**（media-ci 判我方 v2 `Fails one or more mandatory checkpatch tests`）：只改 commit message（`Fixes:`/`Cc:` 收进 trailer、`commit <sha> ("title")` 引用不折行），代码 diff 与 v2 逐字节相同；同信说明「1/3 与主线 `1facae9bc3c1` 重复 ⇒ 请 drop」「3/3 已被主线 crop seed 取代」 | 判据 = 本机 checkpatch 复现改前红/改后 0E、`Result: 250`、lore 线程回填 + `SENT.md` 记账 | 备料子代理产出 v3（父代理发信，按「默认外发 + 立刻报备」） | `patches/upstream/v4l2-compliance-iris-20261127/`、`reports/comms-track-20261128-b.md` §3 |
| **T41** | **Debian GitLab 账号（用户 2026-11-28 申请中，未批）用于 Mobian 上游化通道**：批下来后的动作 = ① 在该 GitLab 建 `mobian` 相关 fork/分支以替代现在走 `mobian1`（gitlab.com）+ salsa 的只读观察；② 复核 `patches/distro/mobian-20261124/mobian-recipes-elden-mr2/` 的硬前置（内核 deb）是否已具备，具备即按 §7 逐件投 MR；③ 把 SSH 公钥登记到该实例并记进 `~/.ssh/config`（**凭据/口令一律不入库**） | 判据 = 账号可登录 + 至少一个 MR 能建；在此之前**阻塞**，不做替身通道 | **外部审批**（用户申请中） | 本条本身即登记；账号/口令不得写入记忆或仓库 |
| **T42** | **droidloom 社区分支调查**（用户 2026-11-28 提：上游只给 Arch 有限支持、开发调试不便）：枚举 forks（ahead 数/改了什么/活跃度）、社区通道、打包面（AUR/Debian/RFP）、非 Arch 构建脚本、调试便利性对比，给出 3 条以内可执行选项 + 判据 + 代价 | 判据 = 调查报告（落 `reports/`，lane 进行中）里每个数字都可用 `gh api` 复查；选项必须指出「跟谁/为什么/怎么验」 | 无（并行 lane 进行中） | 派发口径见 `.pi/ORCHESTRATION.md`；本地现状 = 4 条本地 patch（`patches/local/droidloom-local-20261127/`）|
| **T28** | **phosh：输入法弹窗「键盘意图」上游化**（IME popup / keyboard-intent）：梳理 phosh-phoc 下输入法弹窗（OSK 弹出/收回、输入面板 intent、`zwp_input_method` 路径）现行为与缺口，判定哪些属上游缺能力、按 §7 口径尝试提 patch/MR，本机规避只作临时手段并列记录 | 出「现状→缺口→上游已否→拟投递件」台账一行账；能提的起草好（不自动发，按外发纪律报备） | 需先做只读调研（可并行子代理，待网关恢复） | 本轮用户 2026-11-27 深夜指定为明早待办。**2026-11-28 早（无人值守）主机侧已完成**：T28 = `reports/phosh-ime-popup-research-20261128.md`（含「现状→缺口→上游已否→拟投递件」一行账）；T29 = `reports/phosh-gestures-assessment-20261128.md`（16 项问题清单 + 6 件可上游项 U1–U6，只列不起草）；**手感/观感类判优劣仍需设备窗 + 人目视** |
| **T29** | **phosh：手势导航交互 + 视觉效果完善，并做上游化评估**：现役 phosh/phoc 手势导航（边缘滑动/上滑回桌面/多任务）交互手感与视觉（动效/圆角/过渡）打磨；同时评估哪些改动可上游（phosh 或 wlroots/phoc），产出上游化评估结论 | 出「交互/视觉问题清单 + 每项本机改法 or 上游评估」；上游可投递项列出 | 需设备窗+目视（手势手感需人）；上游评估部分可先主机侧做 | 本轮用户 2026-11-27 深夜指定为明早待办。**2026-11-28 早（无人值守）主机侧已完成**：T28 = `reports/phosh-ime-popup-research-20261128.md`（含「现状→缺口→上游已否→拟投递件」一行账）；T29 = `reports/phosh-gestures-assessment-20261128.md`（16 项问题清单 + 6 件可上游项 U1–U6，只列不起草）；**手感/观感类判优劣仍需设备窗 + 人目视** |
| ~~**T30**~~ | **T5 续：把 Trime 落成默认中文输入法（走 adb，不需用户目视）** | ⚠️ **2026-11-28 判据作废（假绿，见 T32）**：真机上键盘从未出现在宿主；当时的「键盘可见/能出中文」是在 `adb screencap`（整条 Android display）里看到的。默认 IME 已回退 `com.android.droidloom.ime/.HostInputMethod`。以下为历史记录 —— ✅ **2026-11-27 深夜收口（纯 adb，无人工目视）**：① 默认 IME = `com.osfans.trime/.ime.core.TrimeInputMethodService`（`ime set`）；② librime 自部署 `3 success, 0 failure`（luna_pinyin_simp/luna_pinyin/stroke，无 `storage not available`）；③ 软键盘「朙月拼音」点 `n i h a o` → 候选首项「你好」→ 输入框 `text="你好"` 读回；④ 向导 Step3 `DONE` 后重启 app 落 MainActivity（不再弹 Setup）。**根因更正**：`storage not available` **不是缺 SAF 目录** —— Step1 默认的 **app-specific storage**（`/storage/emulated/0/Android/data/com.osfans.trime/files`）就够，真因是「向导没走完 ⇒ rime 不启动」。**残留**：整机重启后默认 IME 未本轮复核（settings 库持久项，T5 已同口径测过 Fossify） | 已完成 | — | `reports/droidloom-trime-default-20261127.md` |
| ~~**T31**~~ | **iris v4l2-compliance v2（单贴）投递**：v1 3 贴中的 1/3 与主线 `1facae9bc3c1` 重复、3/3 被主线 `iris_vdec_s_fmt()` 的无条件 crop seed 取代 ⇒ v2 只留 colorspace 1 贴（Bryan 要的 `Fixes:` + `Cc: stable` 已加） | 判据 = lore 线程回填（`t.mbox.gz` 200、Subject 未改写、挂 v1 cover 下）+ `SENT.md` 记账 | ✅ **2026-11-28 08:37 CST 已实发**：用户登录图形会话后 `git send-email --confirm=never` ⇒ **`Result: 250`**，MID `<20261128003737.1300698-1-xiaqinghuan@mail.ustc.edu.cn>`；lore 复核 **HTTP 200 / 15 377 B**，线程 6 封、Subject 未改写（`patches/upstream/v4l2-compliance-iris-20261127/SENT.md`）。等 Bryan/Hans 表态 | `patches/upstream/v4l2-compliance-iris-20261127/0002-v2-fill-default-colorspace.patch`、`reports/v4l2-compliance-v2-20261128.md` |
| ~~**T32**~~ | ✅ **2026-11-28 收口（层次结论 + 默认 IME 回退）**：**「键盘不出」在 droidloom 的宿主投影层，不是 Trime/焦点/抢占**。图形 IME（Trime 与 Fossify **都复现**）在 cell 内 `mInputShown=true`/`mImeWindowVis=3`、`adb screencap` 能看到键盘，但宿主 `grim` 无键盘 —— droidloom 架构明确「headless input method **never shows a window**」（`docs/architecture.md:419`），图形 IME 窗口不投影到宿主。切回 `com.android.droidloom.ime/.HostInputMethod`（headless + 宿主 phosh OSK）后**宿主键盘出现、可输入**（用户 09:1x 真机确认）。**T30 的验收是假绿**（用 `adb screencap` 整条 Android display 判键盘，宿主从没显示过）。已改 `default_input_method` = `com.android.droidloom.ime/.HostInputMethod`（持久） | 已完成（层次结论 + 可用配置恢复）；残留 = ~~① 宿主 OSK 无中文~~ **已解决**（宿主 OSK 的 RIME completer 桥接，实测「关于提取」落进 Android 输入框）② 让 Trime 可见需 droidloom 支持投影图形 IME —— 已提 **droidloom issue #69**（<https://github.com/denialwm/droidloom/issues/69>），等维护者（跟进项 = **T37**） | — | `reports/trime-droidloom-keyboard-20261128.md`（含截图 `reports/artifacts/t32-droidloom-ime-20261128/`）、`PITFALLS #753`、`reports/upstream-userland-20261128.md` §1 |
| **T33** | **phosh 圆角/刘海避让在本机等于关闭 ⇒ 尝试自建 gmobile 设备条目**（用户 2026-11-28 裁决：记入待办，下次尝试自建；**先搜素材库**）：`border_radius=0`，因为 gmobile display-panels 设备表 26 条里无 `lenovo/elden/sm8750`（上游 38 条也无） | 素材**已交付**（2026-11-28）：加载键已确认 = DT compatible **`lenovo,elden`**（文件名 `lenovo,elden.json`）；只能重编 `libgmobile`/上游 MR（运行时 JSON 无效）；几何真值 = 1904×3040、8.8" 16:10、**无挖孔**、原厂 **有硬件圆角**（`vendor.display.enable_rounded_corner=1`）；圆角半径 = **80 px**（原厂 Android persist dump 的 `RoundedCorner{radius=80}`，非估算）；草稿条目 + 构建步骤 + 验收 5 条已落盘 | **已提上游 MR !131**（<https://gitlab.gnome.org/World/Phosh/gmobile/-/merge_requests/131>，`mergeable`/pipeline **success**）；本机侧残余 = **T34**，review 跟进 = **T37** | `reports/gmobile-panel-entry-prep-20261128.md`、`patches-userland/gmobile-elden-20261128/{lenovo,elden.json,lenovo,elden.upstream.json}`、`reports/upstream-userland-20261128.md` §2 |
| ~~**T34**~~ | ✅ **2026-11-28 收口（主机编 + 上机验收）**：trixie arm64 sysroot（`out/sysroot-trixie-arm64`）+ `rootfs/cross-aarch64-gmobile.ini` 交叉编 `libgmobile 0.3.1` 带条目 → 设备 `dpkg-divert`+`apt-mark hold` 装（原件 sha `293fea73…` 留 `.bak`/`.dpkg-dist`）。**判据 1 绿**：装前 `panel=NULL`、装后 `border-radius=80`（用 `gm_device_tree_get_compatibles()` 复现 phosh 取法）。**判据 2 按实测改写**：装前/装后整屏 sha256 相同 —— 不是没生效，而是 `corner_shift=7 < PHOSH_TOP_BAR_MIN_PADDING=9`（本机 `Scale: 3.0`，80 px ⇒ 26.7 逻辑 px；反解 ≳95 px 才动顶栏），用 `radius=600` 对照证管线生效（首墨 x 27→417）。判据 3/4/5 全绿（`systemctl --failed`=0、`deploy --check` MISS=0、三条回退件 + hold 记账）。顺手修 `build-sysroot.sh` 默认路径（旧用户名）与写死 `/TB322FC` 的 cross file | 已完成（本机保留 inert 件；`!131` review 跟进 = T37） | — | `reports/gmobile-t34-build-deploy-20261128.md`、`PITFALLS #754`、`reports/artifacts/gmobile-elden-20261128/` |
| **T35** | **D13 吞事件走上游（用户 2026-11-28 10:0x 确认「弧度已正常、但边缘滑动仍透传给应用」，裁决：封装起来，且要方便日后做逐级 UI 返回意图传递）**：在 phoc #125 按维护者形状提手势 MR（`PhocGestureSwipe` 绑左右边缘 + 识别时 cancel 触摸序列），替代「lisgd 旁听 ⇒ 事件照送应用」；设计目标含「应用返回 → 应用栈 → shell 关闭」的逐级意图 | MR 提交且 pipeline/编译通过；本机 phoc 装上后 **PiliPlus/Firefox 内边缘滑动不再传给应用**，且返回意图可按层级消费一次（不重复关两层） | **等 #125 维护者回复**（note `2948914`）；需 wlroots 0.18 dev + 交叉编 phoc（本机现无 dev 包） | `reports/droidloom-osk-keypad-hide-20261128.md` §A、`reports/d13-gesture-leniency-20261128.md` §3、`TASKS/dim/D13.md`、`reports/upstream-userland-20261128.md` §3 |
| **T36** | **D13 人手验收 3 项**（自动化判不了的）：OSK 弹出时左缘滑动、全屏视频内滑动、真人左右手各一次 | 用户目视「顺/误触」判过 | 需用户 + 设备窗 | `TASKS/dim/D13.md`（2026-11-28 落地节 末） |
| **T37** | **三处上游线程跟进**（等回复，常设 D10 顺带）：gmobile **!131** review、droidloom **#69** 表态、phoc **#125** 形状 | 每轮 D10 报 state/notes 变化；有 review 则当轮回应（含给出本机 `grim` 截图） | upstream-gated | `reports/upstream-userland-20261128.md` |
| **T38** | 🟡 **2026-11-28 第二阶段已拆成两条（报告 `reports/t38-keypad-split-20261128.md`）**：①「再唤不出」= `onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE`，与 droidloom **issue #65** 同签名 ⇒ **已知上游缺陷**（dismiss 后 `Editor.needs_enable()` 不再 `enable()`），并入 T37 跟进、本机不做规避；②「点一个数字就自隐」**仍缺一次真人触摸**：`uinput-touch` 注入的触摸到不了宿主 OSK 层表面（全键盘也一个字符不进，见 `PITFALLS #755`），自动化判不了触点归属。③ 顺带观察：切到密码框后 OSK **仍是数字键盘**（布局滞留，未定因）（用户 2026-11-28 报；`inputType=phone` ⇒ 宿主 OSK 走 `PosKeypad`）。已复现：点 `1` → 输入框不变、失焦，应用发 `HIDE_SOFT_INPUT fromUser=true`；再点输入框 `onRequestShow` 有、宿主 OSK **不出现**（`mInputShown=false`） | 根因分离（触点归属 vs `droidloom-wayland` dismiss 后未重新 `enable()`）+ 修复或明确上游缺陷；判据 = 电话字段可连续输入多位且键盘不自隐 | 需单变量实验（`DROIDLOOM_TRACE=input` 重启 droidloom-wayland；会重建窗口）+ 可能涉及 droidloom 源码 | `reports/droidloom-osk-keypad-hide-20261128.md` §B（含 3 张截图） |
| ~~**T11**~~ | ✅ **2026-11-26 已执行（`ca787f3f`，2026-11-27 复核确认）**：早于 11-25 的 27 块逐字搬 `archive/topics/INDEX-§0-沿革-20261118-25.md`（81.8 KB），`INDEX.md` 122 744 → **44 416 B**；随后 11-26/11-27 增量回填到 57 KB（§0 = 33.6 KB / 190 行），即「近 3 天保留」口径本身；目标 ≤120 行是**每轮滚动执行**的软线，不是一次到位 | 已完成 | — | `.pi/plans/2026-11-27-文档精简拆分归档.md` B1、`archive/topics/INDEX-§0-沿革-20261118-25.md` |
| ~~**T12**~~ | ✅ **2026-11-26 已收口**：5 处 `*.jsonl` 硬匹配改「`.jsonl` + `.jsonl.gz`」（`sessfind`/`sess`/`recent-sessions.sh`/`doctor/15-timeline.sh`/`gen-sessions.py`），>30 天会话 237 个批量 gzip（mtime 用 `copystat` 保留，`/resume` 只见近 30 天）⇒ **498.7 → 125.3 MiB（省 373 MiB）**；工具侧正/负样本各验一次（手工 `.jsonl.gz` 探针能被 `sessfind`/`sess`/`recent-sessions` 读到） | 已完成 | — | `PITFALLS #736` + 本节 |
| ~~**T22**~~ | ✅ **2026-11-27 收口（两发零写盘上机验收）**：配置批 `HW_RANDOM_QCOM` + `CORESIGHT_{CTCU,TPDM,TPDA,TNOC}` 全 `=m`，编进 vk194/vk195；**vk195 上机判据全绿** —— `amba 未绑定 28 → 0`（TPDM 22 + TPDA 5 + TNOC 1 + CTCU 1）、TRNG `qcom_rng` 绑定（`rng_available` 含 `qcom_hwrng`，`/dev/hwrng` 出字节）、显示 connected / `wlan0` UP / 声卡 / 17 video / 8 input / ADSP+CDSP 正常；设备已回 `boot_b` = vk192，未刷写任何分区 | 残留（都不是阻塞）：① `coresight-ctcu`/`coresight-tpda` 靠 `/etc/modules-load.d/elden-coresight.conf` 兜（上游缺 `MODULE_DEVICE_TABLE`）② TNOC 的 DT periphid 属上游待修（同族 kaanapali 也缺）③ 两者草稿在 `patches/upstream/coresight-moduletable-20261127/`，**投递待 §7 放行** | — | `reports/capbatch-vk194-20261127.md`（§6 上机 / §7 上游缺陷）、`PITFALLS #748`、`DEVICE/CAPABILITIES.md` 行 13/15/16 |
| ~~**T15**~~ | droidloom：**先把现役 `0.1.0-49` 升到上游 `0.1.0-51`** 再判 IME | ✅ **2026-11-27 晚已执行（设备侧 additive 覆盖安装）**：runtime-51 11,131,906 B + image-51 66,871,960 B（sha 与主机逐字节一致）`tar --zstd -xf -C /` 覆盖，base-49 复用；`droidloomctl status` = `Android is ready`、`droidloom-doctor` **READY/0 blockers**（1 WARN `security.host_lsm` 与旧基线同项）；回滚 = 覆盖 `~/dl-droidloom-49/` 两包。残留三项见报告 §4（① 占位 IME issue 待放行 ② T2 四条本地 patch 未打 ③ `package-state.json` 仍记 release 49） | 已完成 | — | `reports/droidloom-upgrade-51-ime-20261127.md` |
| ~~**T16**~~ | ✅ **2026-11-27 收口（父代理独立复核通过）**：62 条（52 零引用 + 10 仅注释）全部重判 —— **① 退役 37**（脚本头加 `RETIRED 2026-11-27：<原因/替代件/可复核报告>`，不删文件）+ **② 补指针 25**（`RESOURCES/README.md` §5 新增 25 行、新立 4 个面：桌面栈构建/调试、自检门禁、主机环境、Win-x86 转译 PoC）+ **③ 0 条**| 已完成：`scripts/` 现查**零引用脚本 = 0**（父代理独立复算，含文档面语料）；抽查 4 条退役理由的「可复核报告」全部存在且真提到该脚本（`reports/script-audit-edl-20261118.md` 3 处、`reports/audit-20261119/A3-scripts-audit.tsv` 1 处、`reports/script-cleanup-audit-20261112.md` 1 处、`reports/scripts-index-20261120.md` 1 处） | 已完成 | — | `reports/scripts-ref-audit-t16-20261127.md`、`RESOURCES/README.md` §5 |
| ~~**T14**~~ | ✅ **2026-11-27 收口（③档残留已由 T16 补齐）**：`scripts/` **363** 入口按 A7「14 份活面文档」口径重算 = 命中 **193（53.5%）**；死引用自报 7 条 → **父代理复核 5 条是误报**（`env-pass/scripts/…`、`archive/…-retired-scripts/…` 的尾部 `scripts/` 被审计正则当仓根，文件全在盘）+ 1 条跨树误读（`checkpatch.pl` 指内核树）+ 1 组纠正「q28 取证脚本本机已无」这个与盘上事实相反的旧错述。已落地 = `RESOURCES/README.md` §5 的 **49 行指针** + 3 个 `RETIRED` 头注 + 死引用归零。**残留见 T16**（③「保持私有」131 条里只有 **69** 条真有调用点）。 | 已完成 | — | `reports/scripts-ref-audit-20261127.md`（含父代理复核节）、`RESOURCES/README.md` §5 |
| ~~**T25**~~ | Q36 硬件解码（iris `/dev/video17` dec / `18` enc 但解码报 `capture: driver decode error`） | ✅ **2026-11-27 晚收口（上机，backport patchwork 1222157）**：11 贴以 `patch -p1 --fuzz=3` 全落（我方树比系列 base 老 6 周，`git apply` 从 03 起因上下文漂移失败；唯一缺符号 `iris_vb2_signal_eos()` 本地按其上游语义补 4 行）⇒ **H.264 `frame=90` + HEVC `frame=90`，且 framemd5 与软解逐帧 90/90 零不一致**；不改内核不改 DT，只换 `qcom-iris.ko`（`out/iris-backport-1222157/`，sha `9b815bc359012c1b…`）。**根因表述更正**：`:393` 少判 `PSC_LAST` **不是修复点**（backport 后该行未变），真修复 = 系列 09/10 的 `early_capture`/`drc_unsignalled` 分支让零尺寸 `PSC_LAST` 走「重入队」而非置 ERROR | 残留（2026-11-28 06:1x 对账：①②已排除）~~① Moonlight 判据未验~~ **✅ 已验**（`out/iris-backport-1222157/moonlight-hwdecode-20261127.log`：`hevc_v4l2m2m` 绑 `/dev/video17` Iris Decoder、`FFmpeg-based video decoder chosen`、0 decode error）；~~② 给 Neil 回 `Tested-by:`（未做）~~ **✅ 已发 v2**（2026-11-27 23:26 CST，`send-mail-ustc.py --send` 已发送 OK，MID `<179579316333.2255507.474175752663313@mail.ustc.edu.cn>`，lore linux-media 线程 13 封实证；v1 因 Cc 折行漏 `linux-media` 被列表拒，v2 把列表放 To）。**仅剩**③ 系列合入后撤 backport | `reports/iris-backport-1222157-20261127.md`、`TASKS/GAPS.md` Q36 |
| ~~**T26**~~ | `qcom_iris` 开机**不自动加载** | ✅ **2026-11-27 晚收口：真因是我方 `/etc/modprobe.d/elden-blacklist-iris.conf`（`blacklist qcom-iris`，vk192 实验保险丝），不是 udev 缺陷**。取证链：alias/`modules.alias` 覆盖 OK → `udevadm test` 排了 `kmod load` → `modprobe -R <of modalias>` 解析出 `qcom_iris` → 但 `modprobe <alias>` rc=0 不加载 ⇒ `modprobe -c` 见 `blacklist qcom_iris`。处置 = 改名 `.conf.disabled`（留档不删）；冷启实测 `lsmod` 命中、`/dev/video17` 自动出且权限变 `crw-rw----+`（root:video + uaccess ACL，普通用户可直接用）。**未用 `modules-load.d`** | 已完成 | — | `reports/iris-backport-1222157-20261127.md` §4 |
| ~~**T23**~~ | 上游：**sm8750 TNOC periphid v1 与 Jie Gan `[PATCH 0/4] Fix the TraceNoC probe issue`（patchwork 1214623）正面重叠** | ✅ **2026-11-27 晚已收口（用户裁 ①）**：回自己线程自认 superseded（`<179578582079.1094405…@mail.ustc.edu.cn>`，SMTP 250，lore 线程 5 封实证、10 277 B），**未发 v2**；`kaanapali` 同型草稿保留在盘但 `SEND.sh` 硬拒绝（dup） | 已完成 | — | `patches/upstream/sm8750-tnoc-periphid-20261127/SENT.md` 末节、`out/mail-20261127/re-superseded-sm8750-tnoc-periphid.txt` |
| ~~**T24**~~ | 订阅 `coresight@lists.linaro.org`（用户已放行；目标 = 后续系列不再被「非成员」压审） | ✅ **2026-11-27 晚已订上（用户网页完成）**。邮件路三条全否证（`-join@` 触发确认但 `-confirm+<token>@` 回复无效、`-request@` 的 `confirm <token>` 报 token 不匹配；token 属站点账号注册）。**自证判据（下一封发列表时看）**：再发到该列表的信不再出现 `coresight-bounces … awaits moderator approval`，且 HyperKitty 归档可见。步骤留档 = `reports/coresight-list-subscribe-20261127.md` | 已完成（自证待下一封） | `reports/coresight-list-subscribe-20261127.md` |
| ~~**T13**~~ | ✅ **2026-11-27 随 T6 收口**：真 vendor 配置（`super` 8 段稀疏拼接 → `lpunpack -p vendor_a` → `debugfs rdump /etc/sensors`）+ 扁平 `-R` 树 `/var/lib/hrpcd-root` + `81-libssc-elden.rules` + `iio-sensor-proxy` ⇒ 三属性 true、`ssccli` 出真值 | 已完成 | 后续可选：34/35/36 假成功（常驻）+ 真写后端（registry 持久化） | `reports/sensors-ssc-restored-20261127.md` |
| ~~**T10-补**~~ | ✅ **2026-11-26 已收口（gitignore + 判据脚本两部分）**：`reports/artifacts` 的 **173 条逐目录规则 → 32 行统一块**（默认不入库 + 白名单 md/txt/清单/patch/diff/小图；抓手 = 「ignored 条目数前后同为 542」+ 探针）；**468 篇这个数不复现** —— A16 手数为 225/32.5%、468/59%，落地脚本在三种语料刻度上分别为 644/551/158 孤儿 ⇒ 以 `scripts/reports-orphan-check.py` 的 `all` 刻度（158）为唯一口径。**剩余 = 158 篇补指针**（见上条 T10） | 已完成 | 158 篇孤儿补指针 = 未做 | `reports/fs-dedup-20261127.md`、`reports/arch-audit-20261127.md` A16 |

### 4.1 常设项（每轮/每收尾都做，不占维度）
- **H1 资产清理** —— 正文 = `RESOURCES/README.md` §3；**2026-11-25 用户授权轮已实删 79 G**（`/tmp` 本项目 8 件 + `build/` 链接产物，`/` 82%→73%），执行记录与「明确不删」清单 = `reports/disk-cleanup-20261125.md`，取证 = `reports/tmp-forensics-20261125.md` / `reports/build-residue-verify-20261125.md`；`out-archive.py` KEEP 表同日修正（vk189/vk192 免误归档）。
- **H2 完整性巡检** —— `bash scripts/check-doctor.sh`（FAIL=0）+ 镜像基线复算**必须走 O_DIRECT**（`PITFALLS #513`）+ 仓 `git fsck`；WARN 逐条归类到「本轮修 / 已登记豁免」；**reports/ 孤儿只以专职门 `python3 scripts/reports-orphan-check.py --check`（doctor §33，FAIL 级）为准，§8f 只是粗筛（只 WARN、绿了不算无孤儿）**。
- **需要物理 POR 的样本一律排在最后**（用户在机旁时一次做完）。

### 4.2 收尾轮次纪律（2026-10-23 用户定，仍有效）

- TF 卡（G1-6/Q10）已收口出列；Q28 补采样与 Q32 已于 2026-10-24 收口 ⇒ 现无待取 POR 样本；判据备查 → 归档。

### 收尾轮次纪律（2026-10-23 用户定，仍有效）

- **需要物理 POR 的样本一律排在最后**（用户在机旁断电/开机时一次做完），其间只做不重启的项。
- TF 卡（G1-6/Q10）已收口出列；**Q28 补采样与 Q32 已于 2026-10-24 收口**，其余「需要 POR」项全部关闭 ⇒ 现无待取 POR 样本；判据备查 → 归档。
---

