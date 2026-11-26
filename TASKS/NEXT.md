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
>
> **★常设 lane（用户 2026-11-23 定，硬规则）**：每轮并行派发**至少一条通信 lane（D10）** —— 查邮件 INBOX + 我方在 **Mobian（gitlab.com/mobian1/*、salsa.debian.org/Mobian-team/*、droid-juicer MR）** 与 **phosh/phoc（gitlab.gnome.org/World/Phosh/*）** 的 MR/issue 回复；**只读，不回复不外发**（发信/推 MR 仍按 §7 逐次放行）。
>
> **★2026-11-23 派发（并行 4 lane + D10，全主机侧、零设备）**：A = **D2 G7 路线 A 第二步**（解除 `connector@0/1 ↔ typec-mux@42/43` devlink 环 → 新 DTB/镜像；出口门 = 静态 phandle 图无环 + `dtc` okay ≥34 + `dtbs_check` 新增 0；报告 `reports/g7-routeA-dtfix-20261123.md`）· B = **D5 批 3**（`ath12k-load.sh` bind 设备名、`arm-console-run.sh` #584 SIGPIPE、`q28-por-rounds.sh` P1、`gpt-restore-tb322fc.py` fail-closed 表指纹门；`reports/scripts-hardening-3-20261123.md`）· C = **D6 文档卫生**（`docs-health` 清零 + PITFALLS DEMOTE 只测算不搬；`reports/doc-audit-20261123.md`）· D = **D2 Mobian 首件**（droid-juicer `configs/lenovo,elden.toml` 成品 + MR 描述，不投；`reports/mobian-firstmr-20261123.md`）· E = **D10 通信**（`reports/comm-triage-20261123.md`）。**主机负载口径（用户 2026-11-23 放行）**：新 CPU（i7-14700KF / 28 线程）允许更高并行 ⇒ 跨维度 lane 上限 2→4，编译仍 `-j26` 起（留交互核）。
>
> **★2026-11-23 下午收口（全部已独立复核入库，`857047b3` + `c1ce6146`）**：① **G7 rev2 双向 devlink**（`reports/g7-routeA-dtfix-20261123.md`；dtbs 32/新增 0，镜像 sha `79164085…`）**flight-2 已上机**（用户物理键进 BL，零写盘）：role switch 不再卡 `waiting_for_supplier`、fsa4480 四件 mux/switch 注册、ADSP/CDSP 双 running、**card0+DSI-1 connected（7.4-rc3 显示栈超预期）**；**真根因教训：`/lib/modules/<UTS>` 整套没进根**（部署后 `modprobe fsa4480` 即注册）——入 PITFALLS 级教训：RAM 载起新核必须连模块一起部署。遗留：0×180 devlink 失败 5 条（上游 mtp 板对照待查，可能为 connector 平台设备 fw_devlink 语义而非我方错）+ altmode bound 但 `/sys/class/typec` 空 + ucsi PPM init failed；**换口测试未达**（用户换边后设备自动重启回 vk192，pstore 空，重启根因未取证）——**用户裁决：再进 BL 的重测往后排**。② **D5 批 3+4 全收口**（4 脚本 + STALE 15 = 3 归档 12 头注 + O_DIRECT 硬门 6/6，反例 rc=90）。③ **D1**：hexagonrpcd 门 + 时间基线件 + 真 bug（`daily-baseline.sh --root DIR` 解析错使构建侧 no-op，已修）。④ **D10**：krzk 点名 v11 投法两条（披露进 `---` 下 + 新线程）⇒ **dwc3 v12 投递 lane M1 已派（用户放行发信）**；aw86927 白拿 3 枚 `Tested-by`（Joonhoe Kim，TB323FU）收进下版。⑤ **D3 lane H2**：RIME 后端 A/B 双案骨架 aarch64 编译过、主推 A（零上游改动）；震动 12 行 env-gated patch；方向键缺（布局 0 命中）已补 terminal.json/vk-driver patch；10 条需上机判据（`reports/ime-rime-backend-20261123.md`）。⑥ 主机当天两次 panic 已上交 hw-stability（内存稳定性，项目侧不深挖）。

**★2026-11-25 夜轮（用户「检查待办+派发」+四项点名调查；计划 = `.pi/plans/2026-11-25-派发-调查四项.md`，零设备：平板不在线）**：4 lane 并行 —— A 通信+Mobian/phosh 上游化（`reports/mobian-phosh-upstream-20261125.md`）· B droidloom × GMS × 目标 APK（`reports/droidloom-app-compat-20261125.md`）· C 电源「按需节点+休眠」（`reports/power-on-demand-20261125.md`）· D 长短边 USB 总账（**✅ `reports/usb-ports-consolidation-20261125.md`**：口位 ×10 维度事实表 / Q35 两支清单 / SDP→`be5e7367bceb`→backport 30 行口径 / 速查块 / 4 条冲突清单；父代理复核 `patches/upstream/charger-icl-20261125/upstream-be5e7367bceb.patch`、`scripts/{g7-mux-probe.sh,ncm-host-up.sh,acm-sh.py}` 均在位）。同轮从 vivo V2454A 提走两个目标 APK 备用（`~/apk-20261125/`：Limbus 1.118.0 三片分片包 1.34 GiB、小红书 9.49.1 单包 174 MiB，sha 账在 `MANIFEST.md`）。

> **★2026-11-26 拆分**：本表只留「号 / 维度 / 状态 / 详情」；**开放项、需设备、权威指针逐行在 `TASKS/dim/D##.md`**
> （每份 = 拆分前原行逐字；索引 = `TASKS/dim/README.md`）。要看某维度的现状全文就点进去，别在本表里塞长文。

**★2026-11-25 夜轮 4 lane 全收口（父代理独立复核后回填）**：
① **A（mail-io）** `reports/mobian-phosh-upstream-20261125.md` —— 增量窗口 01:45Z→11:25Z **人类评审 0 封**，机器人 3 条新意见：**dwc3 v15 得 2×`[Low]`**（1/3 的 `Changes since` 段要移到 `---` 下、else 分支 `port@0` 补 `$ref: graph.yaml#/properties/port`、then 分支 pattern 改 `[2-9a-f]`）⇒ 待出 **v16**；**elden 板 v8 得 2×`[Medium]`**（均已在 cover 声明，**不改 DT**，等维护者来信时引 cover）；新退信事实 = **`abel.vesa@linaro.org` 死地址**（R2 独退，下次用 `abel.vesa@oss.qualcomm.com`，本次不补发）；账错已修 = M11 ping 的 MID 记成了 dry-run id（现记实发 `<179559762994.96050.5…@mail.ustc.edu.cn>`）。Mobian 面：`droid-juicer !46` notes **1 全 system / 人类 0**、48.2 h 零变化，仓库 6 个 open MR（最早 !45 自 10-11）⇒ **队列慢，不必催**；`mobian-recipes`（salsa）`devices/qcom/{configs/wip.toml,packages,droid-juicer}` **三处仍空**、15 个 open MR 无我方 ⇒ 我们 MR-2 的硬前置（内核 deb）未变；**7.x staging 可用**（`mobian-sdm670-7.3` 11-24 仍在提交）且 **0 条 sm8750 分支** ⇒ 缺口只剩 `mobian-sm8750-7.4` + `debian/`。phosh 面：`!2005` `mergeable`、notes 6（人类 2）、pipeline manual/Blocked、**最新人类 note 仍是 guidog 11-14**；phoc `#125`（edge-swipe-back）自 2020 **仍无 MR**，14 个 open MR 无关 ⇒ 我们的 lisgd 路线仍是最优解；设备 phosh/phoc 0.58 对上游/sid 0.59 落后 1 minor。**外部门（需用户）**：IMAP 存储层自 11-25T03:44:39Z 起 INBOX/Junk/Sent 三处均无新件（配额/反垃圾/服务端延迟待确认），此前「INBOX 无退信」不可当结论。
② **B（android-compat）** `reports/droidloom-app-compat-20261125.md`：J1=登录已验证/Integrity 免责/商店落 `uncertified`；J2=Limbus **现役 `0.1.0-30` 单 APK 装法起不来**（只有 split 包）；J3=小红书**预期能起**但相机/定位/中文输入/推送缺组件。父代理用真包追加 §7 实物核对：Limbus 1.118.0（非 APKPure 1.119.1）、Unity IL2CPP + `libvkquality`/`libswappy`/FMOD、**新发现 Firebase 12.6 + `credentials-play-services-auth`（无 GMS 时最可能先卡在 Application 初始化）**；小红书 157 个 `.so` 全 arm64，6 个风控库逐字命中。上游口径变化三条（`KNOWN_ISSUES.md` 已删须钉 commit、`linux-drm-syncobj` 变可选、upstream 已到 `0.1.0-49`）。
③ **C（worker）** `reports/power-on-demand-20261125.md` 已合指进 PLAN 头与 D11（四个观测面 + 「`suspend_stats/*_hw_sleep` 恒 0 不可当驻留时长」）。
④ **D（impl-worker）** USB 总账 + 派生的 **M12 口径更正**（日常线源码本就带可写 ICL，见 D14 行）。

**★2026-11-23 晚增量（收尾块）**：① **dwc3 v13 已投**（新线程 4 封 250，cover MID `20261123110858.538884-1`，答 greg k-h changelog 历代要求；patch 与 v12 逐字节同，G1/G2 实跑，G4 重跑后延）；② **Mobian !46 英文化已推**（`ea9fe3d`，pipeline success，中文版留档）；③ **osk-stub rime 批 chroot 编译产物就绪**（`out/osk-stub-rime-20261123/`，设备窗一次 divert 收 H2 十条判据）；④ D2/D3 审计报告入库（Mobian 下一步三候选 / IME A·B 案上机差距清单）；⑤ 酷安进度三篇已发（`reports/coolapk-publish-20261123.md`）。D2 行的「dwc3 v11 投递」开放项作废（已至 v13）；D3 行开放项 ①④ 合并进「设备窗批」。

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

> **★2026-11-25 重启验收**：`systemctl reboot` 后新 `boot_id`、up 1 min，`lisgd-edge-swipe` **active + enabled**（lisgd 自动盯上真触屏 `event4`）、`wm.keybindings close` 仍是 `['<Alt>F4', 'XF86Back']`（dconf 持久）、`systemctl --failed` 仅已知 `qbootctl` ⇒ **常驻与持久化都成立**，不依赖会话手工启动。 另测**自愈**：`kill -9 lisgd` ⇒ 8 s 内被 systemd 重拉（新 pid，服务仍 active）⇒ `Restart=always` 生效。、`.pi/lanes/20261125-phosh-edge-swipe-back-brief.md` |

**维度互斥/依赖**：D1 必须先于 D7（ESP 在机的面）；D3④ 与 D1 共用一次上机窗；D4 与 D1 争同一收发窗口（**分时**）；D2 的 G7 与 D4 不可同轮（都要 a/b 槽控制权）。

### 4.0a 现役待办（2026-11-26 收尾时点；**唯一权威 = 本节 + 各行指针**）

> 只列「下一步可执行」的项；已完成项不在这里复述（它们在各维度文件与 `reports/`）。每条 ≤ 半天，除非标注。

| # | 待办 | 判据（怎么算做完） | 阻塞/前置 | 指针 |
|---|---|---|---|---|
| **T1** | droidloom：给上游 `#48` 补我方复现数据（校园网封校外 UDP/53、探针 204 实测、`10.177.0.2` 在线证据） | 评论发出 + `reports/droidloom-cell-network-20261126.md` §8 记 issue URL | **需用户点头**（外部发帖） | `reports/droidloom-upstream-lane-20261126.md` §D2-1 |
| **T2** | droidloom：试 `EvilBorsch/droidloom` `eb/main`（ahead 24）——`.deb` 或只取 3 patch（`--forward-signals` / host resolvers / quick stop）重编 runtime | ① cell 仍 `Android is ready`；② **删掉 `/usr/local/bin/unshare` 后仍能起**；③ lease DNS = 宿主 resolver ⇒ 可删 `ip dl_dns_redirect` | 需备份当前 runtime；可回退 | 同上 §D2-2 + §D3 |
| **T3** | droidloom：IME 主因判定实验（占位 IME 状态机缺陷 vs 宿主缺 `denial_text_input_panel_manager_v1`） | `wayland-info \| grep -c denial_text_input_panel` 与「换 sway/headless 后 `showSoftInput` 是否成功」三选一定论 | 现已有绕行（Fossify IME），不阻塞使用 | `reports/droidloom-ime-keyboard-20261126.md` §5、D24 §D2-3 |
| **T4** | droidloom：把 cell DNS 重定向做成**跨重启持久**（独立 systemd unit，additive） | 重启后 `nft list ruleset \| grep dl_dns_redirect` 命中且 cell `VALIDATED`（**已实测 FAIL**：2026-11-26 22:0x 重 boot 后 = 0 条，`reports/droidloom-cell-network-20261126.md` §9） | T2 若落地可整件删 | `reports/droidloom-cell-network-20261126.md` §8 待办 / §9 |
| **T5** | droidloom：中文输入（Fossify 无中文布局）+ 整机重启后默认 IME 持久性实测 | 重启后默认 IME 仍 Fossify；中文可输入 | 需一次重启窗 | `reports/droidloom-real-ime-20261126.md` 残余风险 |
| **T6** | 传感器 `#692`：内核侧实验**已止损**（2026-11-26 实测假说 A 否证）。**2026-11-27 又否证一条**：后续①「补齐 ADSP 的 PD 依赖」**不是主线缺口、也不做**——主线 PDR + in-kernel pd-mapper 都在（`qcom_pd_mapper.c:665` 把 `qcom,sm8750` 映射到 `sm8550_domains`），本机实测 `audio_pd`/`charger_pd` 均收到 PDR UP、`q6apm` 已绑、声卡 `card0` 在；而主线 PDR **没有「关 PD」接口**，`qcom_pas_stop()` 全程不碰 PD；同 SoC 另一台机（Xiaomi Pad 8 Pro，mainline 7.2.10）`remoteproc0 stop→start` 与 ADSP SSR **都不复位整机** ⇒ 本机「ADSP 一停就复位」是**板级（PMIC/AOP/TZ）面** | 已关闭的判据：不要 `-s`、不要 `stop` ADSP。**V2 已做（2026-11-27）= PMIC/PON 通道判不了根因且已榨干**：主线 `qcom-pon` 不读任何 reason 寄存器、用户态也读不到（`regmap` debugfs 无 `access`，见 `PITFALLS #739`）；ABL 唯一留下的 `Reset by PSHOLD` ⇒ 可**排除 PMIC 看门狗**这一支（前提性），但 PS_HOLD 分不清 AOP/TZ 谁拉的 ⇒ H2a/H3 **PMIC 侧不可分**。剩余唯一通道 = **ADSP ramdump / QMI-PDR（需用户放行 + 预算，工作量大）**；V3 二值对照仍在（需放行） | V2 无需授权（只读）；V3 需放行（一次整机复位）；**不要再试「补 PD 依赖」**（形态不存在，已排除） | `reports/sensors-adsp-pd-pdr-20261127.md`（+ `reports/artifacts/sensors-692-logfs-20261127/`）+ `PITFALLS #737` |
| **T7** | 上游：v11 备料已在（`cover-scope-section.txt`），**等下个真实修订触发**再发（不回 sashiko 机器人线程） | 维护者提同一问题或新 review 到达 | upstream-gated | `reports/dts-v10-sashiko-20261126.md` |
| **T8** | `elden-wake` 纳入 `deploy-desktop-shell.sh --check`（与 udev/phosh/phoc 同级判据） | 设备 `--check` 幂等命中该判据 | 无 | `reports/panel-wake-service-20261126.md` §4 |
| **T9** | 用户态镜像一致性门：新建 `scripts/check-userland-mirror.sh`（`packaging/elden-userland/files/**` ↔ `scripts/**`/`rootfs/persistent-overlay/**`，28 对同内容 + 13 组同名漂移），并把它与 `packaging/elden-userland/tools/verify.sh` 挂进 doctor | 新建门三态自测过 + doctor 多一节；漂移组逐组判定「谁是权威」 | **13 组漂移的权威归属需用户裁定**（`init` 380 行差、`charge-watch.sh`/`time-sync.sh`/`net-up.sh` 是已上线服务件） | `reports/arch-audit-20261127.md` A9/A10 |
| **T10** | `reports/` 孤儿指针（入库边界部分已收口，见下条）：**口径已落脚本** `scripts/reports-orphan-check.py`（自带 13 条反作弊自测，`--check` 可当门）；现查三刻度 = readme 50/694（7.2%）、top 143/694（20.6%）、**all 536/694（77.2%）⇒ 孤儿 158 篇** | `scripts/reports-orphan-check.py --check` rc=0（all 刻度 0 孤儿）；每条补的指针行过反作弊（一行 ≤4 个报告名 + ≥8 字用途） | 无需用户确认（补指针不改入库边界）；158 篇可分批 | `scripts/reports-orphan-check.py`、`reports/arch-audit-20261127.md` A16 |
| **T11** | `INDEX.md` §0 旧块下沉（§0 现占全文 80.6%、每会话必读）：早于 2026-11-25 的 27 块逐字搬 `archive/topics/`，§0 收敛到 ≤120 行 | `check-doctor` §15/§30 仍绿；§0 保留近 3 天 + 指针 | 无（有 TASKS 拆分同型范式） | `.pi/plans/2026-11-27-文档精简拆分归档.md` B1 |
| ~~**T12**~~ | ✅ **2026-11-26 已收口**：5 处 `*.jsonl` 硬匹配改「`.jsonl` + `.jsonl.gz`」（`sessfind`/`sess`/`recent-sessions.sh`/`doctor/15-timeline.sh`/`gen-sessions.py`），>30 天会话 237 个批量 gzip（mtime 用 `copystat` 保留，`/resume` 只见近 30 天）⇒ **498.7 → 125.3 MiB（省 373 MiB）**；工具侧正/负样本各验一次（手工 `.jsonl.gz` 探针能被 `sessfind`/`sess`/`recent-sessions` 读到） | 已完成 | — | `PITFALLS #736` + 本节 |
| **T13** | `#692` 用户态收口：hexagonrpcd **无 registry 写支持**（上游 issue #29 同源）⇒ sensors PD attach 即断言，我们板子上放大成整机复位。最小补丁草稿已落仓（v0.5.0 `da7a374` +87 行，`meson`/`ninja`/`meson test 3/3` 全绿） | ① 交叉编译 aarch64 到 `/usr/local/bin/hexagonrpcd-patched`（不碰 Debian 包装器）② **已上机 2 发（2026-11-27）= ❌「假成功 fwrite」版不足**：两发 0.1 s 内仍触发 DSP 断言 `sns_registry_sensor.c:309`，且**串口抓到 Linux 已进 SSR recovery 后整机才死**（修正 `#737`）；下一步 = **apps_std 全方法假成功**版（先 `fremove`24/`frename`33/`ftrunc`/`mkdir`/`rmdir`/`fileExists`，签名取 AOSP `apps_std.idl`）再上机 | 上机 = 预期**一次整机复位**（零写盘，自回 `boot_b`）；投递上游（回帖 #29 / 并 PR #21）需**用户放行外部发帖**，先不投 | `reports/hexagonrpc-upstream-registry-write-20261127.md`、`patches/userland/hexagonrpc-write-20261127/` |
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

