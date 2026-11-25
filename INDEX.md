# 工作区索引 — TB322FC "elden"（SM8750P）固件与驱动研究

> **入口。** 新会话：**§0（现在一页）→ §2「入口阶梯」**（含时间序权重）→ 需要细节再进对应文档/专题档案。
> **唯一入口 = 本文件**；根目录 = 入口 `INDEX.md` + 项目身份 `AGENTS.md` + 公开 `README`/`PROGRESS`（**公开门面，agent 默认不读**），**7 个角度文件夹**（`DEVICE/` `TASKS/` `RESOURCES/` `RUNBOOK-BRINGUP/` `PITFALLS/` `SESSIONS/` `HISTORY/`），各自 `README.md`（策展 SSOT）+ `sessions/`（会话进度）；标准见 §2。
> 2026-10-03：git 纳管 + 文档收敛（12→6）；自检 `scripts/check-doctor.sh`；不再有 SQLite/生成物。

---

## 0. 现在一页（**唯一的状态入口**；核对日期：2026-11-25）

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

> **🆕 2026-11-25 上午（断电续轮）：三件收口 + 两条定性**：
> ① **候选条可翻页**：`0006-osk-stub-completion-bar-paging.patch`（`GtkScrolledWindow` + 最小按钮宽 + `‹ ›` 翻页）+ RIME
> `menu/page_size: 20`（`~/.local/share/rime/default.custom.yaml`）⇒ 设备实测点 `›` 候选翻页（中/种/周/重/仲 → 州/众/钟/锺/忠）；
> 判据 `ime-single-stack.sh` C9。
> ② **`screen-keyboard-enabled` 断电后回落 false（键盘又不弹）⇒ 改用 dconf `system-db` + key lock 钉死**（需 `dconf-cli`；
> 现在 `gsettings set … false` 报「键不可写」）；`ime-single-stack.sh` C1 同时判锁。
> ③ **「Firefox 崩溃」定性 = 合成器/会话先死**：崩溃注解 `Error reading events from display: 断开的管道`（EPIPE），
> `journalctl -b -1` 见 23:27:00 `greetd: session closed` ⇒ 强相关 = 同会话反复 `pkill -x phosh-osk-stub`
> （`sm.puri.OSK0` 是 `phosh.session` 的 RequiredComponents）。纪律：同会话 pkill ≤1 次，要多次迭代就 `systemctl restart greetd`。
> 全账 `reports/firefox-crash-20261125.md`、`PITFALLS #716`。
> ④ **发热首轮受控基线**：空载 cpuss 39.9–40.3 °C / Firefox 静置 39.2–44.2 °C / 重度交互窗 54–59 °C；调频正常（95% 时间 556 MHz）、
> 无限流、无失控进程 ⇒ 目前是**负载相关**；三条待验假设与采样协议 = `reports/thermal-baseline-20261125.md`（`TASKS` D11）。
> ⑤ 侧滑返回手势 lane 已重派（上一轮子代理被断电打断）。

> **🆕 2026-11-24 22:xx 二轮设备窗（用户报「输入法键盘无法唤起」；已修好并收敛成单栈）**：
> 真因两条（`PITFALLS #716`）——① **`org.gnome.desktop.a11y.applications screen-keyboard-enabled=false`**（11-19 重建根的默认值）
> ⇒ `phosh-osk-stub.c:221-238` 无条件 `visible=FALSE`，收到 `zwp_input_method_v2.activate` 也不弹；
> ② **老路 fcitx5 与新路 osk-stub+RIME 两套部署并存**，应用网格里点 `Fcitx 5` 就用默认参数起 fcitx5（`waylandim` 已加载）抢走 IM 槽
> ⇒ osk-stub 只印 `Input method unavailable`、layer surface 恒 `margin -200`（而 D-Bus `Visible` 仍可读 true ⇒ 别拿它当「在屏上」证据）。
> 处置已落地：**`scripts/ime-single-stack.sh --check|--apply|--rollback`**（7 判据：a11y key / `Completers=rime` / user-data / fcitx5 不自启 /
> indicator+focusd 不自启 / 网格入口 NoDisplay / osk-stub 健康）+ `deploy-desktop-shell.sh` §14 第 ④ 项 + `daily-baseline.sh` §3 加 `IME_STACK`（默认 `osk`）。
> 设备现态：单栈成立（FAIL=0）、fcitx5 `masked`、Firefox 地址栏聚焦即弹键盘（grim 截图）；**未决** = OSK 内候选条显示时机（0.46 `completion-mode` 只有 none/hint/manual，HINT 需客户端 hint，`#709` 同源）。
> 全账 = `reports/ime-single-stack-20261124.md`；同轮工具事实：`/dev/uinput` + `tools/uinput-touch.c`（已入库）可注入**真实触摸**（锁屏 PIN、点输入框都实测可用）；`phoc 0.46` **没有** `#615` 的版本门；
> `pkill` osk-stub 过多会打光 gnome-session required-component 重启预算（OSK 无 D-Bus service 文件 ⇒ 只能 `systemctl restart greetd` 恢复）。

> **🆕 2026-11-24 下午 设备窗轮（用户「可以上机」；3 项实测 + 2 条门修复）**：
> ① **D3 收口：RIME 候选在机可用** —— 真因不是「没部署」（B 案件 11-23 就装好了、divert/hold 在位、`Completers default='rime'`），
> 而是 **`sm.puri.phosh.osk.Completers.Rime user-data` 是空串** ⇒ 源码把空值原样塞给 `RimeTraits.user_data_dir` ⇒ librime 每发
> `deployment_tasks.cc:90 Error creating user data dir:`（**冒号后为空**就是空路径指纹）⇒ schema 从未建成 ⇒ 候选恒空且 UI 无任何报错。
> 修法零重编：建 `~/.local/share/rime`（属主会话用户）+ `gsettings set … user-data <该目录>` + 重启 osk-stub ⇒ osk-stub 自己填出 24 个
> `luna_pinyin*` 档、错误消失、**它持有 `luna_pinyin.userdb/LOCK`**（外部进程开同库报 `Resource temporarily unavailable` = 真在用）；
> 同一对目录跑 `librime-piped --oneshot nihao` = **你好/妳好/逆号/拟好/你**。**剩 = 屏上真打字/震动/方向键三条需人手**（设备在锁屏，无 `/dev/uinput`）。
> ★**同日更正（跨 lane 裁决，主会话已改文档）**：初版写「该错误 ⇒ 候选恒空」**过强**。主机侧 lane 用**设备同版本 librime 1.13.1**
> 做隔离实验：空 user dir 下 `nihao` **照样出 5 个候选**（走 `librime-data` 预编译 bin 回退）⇒ 该错误真正破坏的是
> **用户词典/用户定制/installation_id 持久化 + 部署产物落进进程 cwd**。修复动作与「部署真的成功」的证据不变，但
> 「屏上候选条」判断仍需人手（修复前也有候选，屏上不易区分）。
> 全账 `reports/d3-rime-ondevice-20261124.md`（§0b 更正）、`reports/rime-completer-userdir-20261124.md`；新坑 **PITFALLS #713/#714/#715**。
> ★**#715：设备「不能注入触摸」已过时** —— `/dev/uinput`（`CONFIG_INPUT_UINPUT=m`）+ `ydotoold`+`ydotool`+`wtype`+`grim` 全在：
> `wtype` 能真打字、`ydotool` 能做指针（绝对坐标 0..65535）、自建 `INPUT_PROP_DIRECT` 虚拟触摸屏能被 phosh 当触摸（本轮实测点开 Firefox 下拉/导航）。
> 但 `ydotoold` 的虚拟设备算**键盘** ⇒ OSK 永不展开（`ignore-hw-keyboards true` 实测未即时生效），`loginctl unlock-sessions` 解不了锁屏。
> ② **G1-5 相机基线复核通过（vk189 日常核，11-19 重建根后首次）**：前摄 `gc08a8` 3264×2448 / 后摄 `s5kjns` 4080×3072，
> 10 帧 `rc=0`、60 帧实测 **27.52 / 27.58 fps**、单帧解包后 distinct **892 / 681**（非黑非恒定）、dmesg 零新增错误；
> 顺带把重建根丢的 `v4l-utils` 装回。角色定位写清：这**不能**充当 camss CSIPHY v2 的「上机出流回归」（在机核无该补丁、也无 7.4 板 DTS）。
> `reports/cam-vk189-baseline-20261124.md`。
> ③ **两道门修复**：`deploy-desktop-shell.sh` §2 包状态判据改 `*" ok installed"`（`apt-mark hold` 会把首词变 `hold`，我们自己 divert+hold
> 的正确动作让门常红 = #714）；`ab-mark-successful` 脚本 sha 真漂移已重部署 ⇒ **`--check` MISS=0**（本轮起，此前 2 条）。
> ④ 设备现态：vk189 在机、`/`=`sda17`、桌面/音频/触觉/T9 采样器/槽位体检全 ok、Wi-Fi `ustcnet 114.214.195.94`、电池 69%。
> 本轮未做（有意）：camss 出流回归（结构性不可做，见 ②）、D2 G7/板件 v9（等 binding 进树）、D4 安卓 a 槽（需 a/b 槽窗口）、D7 UEFI flashed 复现（用户裁决往后排）。

> **🆕 2026-11-24 12:5x 放行执行轮（用户「全部放行」）**：① **aw86927 v4 已投**（12:50 CST / 04:50Z，7 封全 250，
> cover `<20261124045040.559317-1>`，账 `patches/upstream/aw86927-v4-prep-20261124/SENT.md`；lore 摄取按已知 ≥1 h 延迟复核）。
> ② **dwc3 v14 误重投并已更正**：v14 其实 01:50Z 已投（`SENT.md` 在案、lore 已归档），本轮 README「未投递」误导导致 04:52Z 又发一套
> （4×250，cover `20261124045220.595001-1`）；04:54Z 在同线程发更正「请忽略本线程、以 01:50Z 线程为准」（250）。
> 教训：投递前必须查本目录 `SENT.md` + lore，README 的「未投」不等于事实（已写进该目录 `SENT.md` §事故记录）。
> ③ **phosh !2005 按 guidog 意见重写并 force-push**（fork 分支 `283c9e8`，替代 `88a0e23`）：删 `output_power_unavailable` 字段
> ⇒ `monitor.h` 零改动；`failed` 里置「屏亮」+ 丢弃僵尸 proxy；`phosh_monitor_set_power_save_mode()` 每次重试拿 proxy（正是 guidog 要的
> 「retry on next press」）。编译门 = 用项目既有 phosh 0.58 构建树的**原样 `-Werror` 全套**做 aarch64 交叉编译，0 warning（报告
> `reports/phosh-mr-2005-rework-20261124.md`）。**MR 描述/回帖已办完（14:4x–15:0x，用户提示 keyring + 代理后）**：keyring 里已有 gitlab token（`secret-tool lookup
> protocol https user xuqianhui1001 host gitlab.gnome.org`）+ **bettbox 混合端口 7890**（直连 406，走代理 200；节点实测
> 香港WAP-优化2/日本JP-HY2/美国USLA-A/台湾-优化 = 200，新加坡SG-A = 406 ⇒ 换节点即可，用完已切回香港WAP-优化2）⇒ 描述改短
> （1960→883）、回帖 `note 2945304`、顺手修掉 CI `check-style`（`g_warning (` 空格 / 续行对齐 / uncrustify 要求的签名对齐）⇒
> **pipeline 1152598（`5300355a`）全部自动 job success**（check-style/commit-log/build×3/unit/integration/deb 包），
> 页面显示 `manual` 只是 `abi-compliance-checker` 等需人工点的 job。报告 `reports/phosh-mr-2005-rework-20261124.md` §3b。

> **🆕 2026-11-24 11:4x 轻负载轮（本轮）**：**aw86927 v4 备料完成、门禁全绿、未投（等放行）** —— `patches/upstream/aw86927-v4-prep-20261124/`（7 封含 cover）；
> 6/6 重写处置 sashiko 对 v3 的四条（[High] 补 `Signed-off-by`、[Medium] `INIT_WORK` 提前到 devres 动作前、[Medium] 新增 `enabled` 闸门堵 close() 后 timer 重启播、[Low] 措辞/changelog 位置），
> 4/6·5/6 收 Joonhoe Kim 的 `Tested-by`（判据 = 与已投 v2 对应两枚 **diff 正文逐字节相同**，只有 hunk 偏移因基线换 7.4-rc3 而变），**6/6 因实质改动故意不收 tag**（已在 cover 请其复测）；
> 门禁：G1 6/6 干净落树 · G2 checkpatch 0 ERROR（2 条已知 `Unknown commit id` 假阳性）· G3 `W=1` 编 `drivers/input/misc/aw86927.o` rc=0/0 warning · G4 `dt_binding_check` rc=0（单 schema，32 s）· G6 mailinfo 7/7；账 = `GATES-v4.md`。
> 投递 = 只剩放行（`bash SEND.sh --yes`，dry-run 已过）。v3 目录已标「被 v4 取代」。
> 负载口径：全程 `-j16`（用户 11-23 定「新内存到位前避开重负载」），编译仅单 `.o` + 单 schema，未跑全量编。

> **🆕 2026-11-24 轻负载轮（旧内存未换 ⇒ 零编译，只有符号守卫 `--selftest` 与静态门）**：上一会话四条 lane 的产物本轮**独立复核后入库** ——
> D5⑤ `build-kernel.sh` DSI 守卫修好（上游符号真名 `msm_dsi_host_cmd_xfer_commit`，`--selftest` 4/4，现查 `build/elden-tree` 树内核实）；
> D2② Mobian recipes 备料包冻结（`gate.sh` 5/5，硬前置 = 内核 deb）；`n5b-vk64-death-rate.sh` 加 RETIRED 头、`scripts/README.md` 重生成一致（351 入口）。
> **§4.0 D5 维度对账后收口**（11-22 快照的 5 个开放项逐条现查全已处置：BROKEN 3 已改 / STALE 15 = 3 归档+12 头注 / DANGEROUS 余 0 / O_DIRECT 6/6 / DSI 守卫已修）、D6 ①② 也只剩「§5/§7 下沉」一项。
> `check-doctor` **FAIL=0 / WARN=6**（全为已登记豁免：源树不可核、账本例外、4 枚解不出载荷的旧镜像、无版本号拷贝、降级一致、无构建树；本轮补两条报告指针 + `gen-history` 后「无人引用」「HISTORY 落后」两条归零）。
> **🆕 2026-11-24（无人值守轮 + 一次用户放行的设备窗口；逐项证据在对应 report / SENT / GATES）**：
> ① **上游**：`dwc3 v14` 已投（4×250，cover `<20261124015002.1426767-1>`，`linux-devicetree` 已归档 4/4；只修 sashiko 对 v13 1/3 的三条 [Low]）；
> `aw86927 v3` 已投（7×250，cover `<20261124015028.1427393-1>`；[High] unbind 竞态 + [Low] message，只改 6/6）；
> ~~**但 aw86927 v3 三处都查不到**~~ **已更正（03:0xZ 复扫）= 摄取延迟 >1 h，不是投递失败**：v3 已在 `linux-input` 归档（`01:50:38–02:03:12Z`），且 **sashiko 02:03Z 给了 4 条意见**，其中 **[High] patch 6 缺 `Signed-off-by:` 现查为真**（`grep -c` = 0，其余 5 件 = 1）⇒ **必须出 v4**（另 2 Medium 也成立），逐条判别 `reports/comm-triage-20261124-c.md` §2；**不要重投整套 7 封**；
> `M8 mdss v5` 已 ping（1×250，读树现查三枚仍未合入）；`板件 v9` 备料完成但**按住未发**（依赖 dwc3 binding 先进树）。
> ② **设备**（用户放行窗口）：`vendor_boot_b` 已重刷为 ESP（读回 sha `af97b799…`、`blkid` = `ELDENESP/88D0-7871/4096`，原厂件备份 `backup/pre-esp-flash-20261124/`）；
> G7 `g7a2` 两次零写盘上机：起机/role-switch/UDC/typec 全过，**判据 1 按「不高于基线」口径通过**（7 vs 基线 8，§3 原文「=0」是错期望），
> 显示侧 42 条 WARN 归因 DSI PLL 未锁；**判据 3（换口→mux）仍未测**（需插拔线缆；观测面已解决 = `scripts/g7-mux-probe.sh` 读 `gpio29` 电平）。
> ③ **两个真 bug 修掉**：systemd 257 移除了 `reboot` 位置参数（`systemctl reboot bootloader` 报 `Too many arguments.` 且设备不动 ⇒ 改 `--reboot-argument=`，`lib-soft-bootloader.sh` 按版本探测）；
> 该库 `sb_fb_alive` 用裸 `fastboot`（本机 PATH 无此件）⇒ 明明进了 fastboot 也报「软路径失效」，已按 `FB_BIN→PATH→常见落点` 解析。
> ④ **新门 2 个**：doctor §28（软路径库自检 6/6 + 反作弊 + 禁 `eldroid-bootctl` 回归）、§29（上机候选件 sha 账目，**首跑即抓到页缓存单比特翻转**，证据已上交
> `~/hw-stability/evidence/inbox/20261124-y700-elden-rootfs-minbase-pcache-1byte/`；判据一律 O_DIRECT）。
> ⑤ **待用户**（人不在时不要做）：判据 3 插拔测试；`板件 v9` 放行（等 v14 进树）。

> **🆕 2026-11-23 对账（本轮）**：最新会话证据 = 11-23 深夜会话（`ab7efd8c`：dwc3 v12 四枚成稿 + 门禁日志）+ 11-23 白天 lane 批（`857047b3`/`c1ce6146`，§4.0 已记）。
> **🆕 2026-11-23 深夜（上机 + 重大更正）**：① **方向键** 提级尝试（us/terminal 默认层 row2 加 ←↑↓→）经用户实测**否决并回退**（挤占 row2 ⇒ 全键盘变窄、空间利用率下降）；现役 OSK 件 `cde21b9c…`；② **每键震动 ✅ 用户实测有震动**（根因 = `environment.d` 对 greetd/phosh 链无效，改 `/etc/environment` + `restart greetd`）；③ **RIME 输入法 ✅ 用户实测可用**（B 案 wiring + librime，进程加载 `luna_pinyin.table.bin`）；④ **vk192「漂移」= 误报**（该件 UTS 本身就写 vk189-suspend，判别特征 nftables 已验）；boot_b 归位标准 vk192 件（`LABEL=linux17`→`LABEL=linux` 等长改写 + 签名 + 读回 + 冷起）；⑤ **充电「回归」= 假象**：PD 长边供电 + 短边数据并行工作，单口接 PC 时固件把 `input_current_limit` 锁 100 mA（写 2 A 被重置）；⑥ 🚨 **PITFALLS #712 更正**：`systemctl reboot bootloader` 在**无 vendor-reset 钩子**的 vk192 上同样进 fastboot（同启动内对照：无参 reboot 回 Linux、`reboot bootloader` 进 fastboot）⇒ **#690/#701 的「只能物理键」作废**，旧错因 = 静态判据 + 工具 fail-closed 从未真发命令；`elden-to-bootloader --auto` 已恒走 psci 臂并部署；⑦ `patches/local/psci-vendor-reset-20261123/` 入栈（对 `reboot edl` 可能仍有用，**非进 fastboot 必要条件**）；`out/g7-reset-20261123/` 含带钩子件 `647784b7…` 与对照件 `f79dcbcb…`。全账 = `reports/linux-to-bl-vendor-reset-20261123.md`、`reports/onkernel-20261123-h2.md`。
> **🆕 2026-11-23 晚收尾块（grow loop 全天汇总；逐项证据在对应 report/SENT）**：
> ① **dwc3 v13 已投**（用户放行；答 greg k-h 08:20Z）：新线程 4 封 250，cover MID `20261123110858.538884-1`；三枚 patch 与 v12 逐字节同，cover 补全 v4–v12 changelog；G1/G2 实跑净，G3–G6 沿用 v12，G4 重跑后延（编译后延裁决）；lore 摄取滞后待复核（投出 ~2h 未入索引，v11/v12 均在档）；账 = `patches/upstream/dwc3-v13-20261123/`。
> ② **Mobian !46 内容英文化已推**（用户裁决「先英文后中文」）：force-update `2dead7c→ea9fe3d`（英文 22 条目，tomllib 过，SSH push，API 复核 head 已切，pipeline #2 success）；中文版留仓档作后续；D2 下一步三候选见 `reports/mobian-upstream-audit-b-20261123.md`。
> ③ **酷安三篇已发布**（用户授权直发，MCP bridge，65s 冷却）：feed `75235220/75235246/75235266`，配图现拍 phosh 桌面（`assets/coolapk-20261123/`）；发布后核查 block=0；账 = `reports/coolapk-publish-20261123.md`。
> ④ **osk-stub 0.46.0 rime 批 chroot 编译成功**（用户解锁 8 核；实际 j4 过，j8 并发下 qemu-user 派生子进程无输出假死）：产物 `out/osk-stub-rime-20261123/`（B案 wiring+震动+方向键三补丁，NEEDED librime.so.1，sha `d7a0f9fe…`，DEPLOY.md 含 divert 六步）——**设备窗一次 divert 打齐 H2 十条判据的全部物料已就绪**；顺带修正 0003 wiring 两缺陷 + haptic/layout 补丁 hunk 计数重生成（`patches-userland/zh-ime-rime-20261123/`）。
> ⑤ 主机新工具 `~/.local/bin/egress-switch`（校园网/平板 USB 共享网切换，metric 机制）；trixie arm64 chroot 编译环境 = `/tmp/trixie-sysroot/`（789 包闭包，可复用）。
> **🆕 2026-11-23 通信 lane b 轮（D10，只读）**：**Greg Kroah-Hartman 首次回人（08:20Z，Re: v11 3/3）**——唯一要求 = **changelog 必须列全此前所有版本**；v12（09:53Z 已发，lore 已归档）投法两条已修好但 changelog 仍只有 "Changes since v10" ⇒ **v13 硬欠账 = 补全 v9 及更早历代 changelog**（本系列 lore 可见 v4/v5/v7/v8/v9/v10）；建议等 sashiko 对 v12 的报告一并处理，投递仍按 §7 批准制。其余线程零变化；Mobian !46 三天 0 note（mergeable、CI success）。全账 = `reports/comm-triage-20261123-b.md`。
> **🆕 2026-11-23 整理轮增量（grow loop #1，轻负载）**：① 前记「G4–G6 中断」被日志推翻 —— `patches/upstream/dwc3-v12-20261123/logs/` 六道门全部完成（G4 `dt_binding_check` RC=0 等）；② G1 主会话独立复验通过（fresh clone `aebb727447` + `git am` 3/3 + 6 枚 blob sha 逐字一致）；③ **dwc3 v12 已投（用户 11-23 放行）**：新线程形态（krzk 裁决），4 封全 250，cover MID `20261123095310.154352-1`，账 = `SENT.md`；lore 复核待下一轮；④ D10 只读通信 lane 已派。
> **本轮核实（2026-11-23）**：`check-doctor` FAIL=0（WARN=6 全为已登记豁免：源树 slim bundle 态、账本例外、4 枚解不出载荷的旧镜像、本日期条目）；`scripts/README.md` 与 HISTORY days 已重新生成；G1 计数 = 36 完成/37 在册（`check-progress-counts.sh`）。
> **负载约束（用户 2026-11-23 定）**：新内存到位前避开重负载 —— **暂停**：G4 全量 `dt_binding_check`、任何内核全量编、B 选项重建 daily 树。**可做（轻）**：G5/G6 门、D10 通信 lane（只读）、D6 文档卫生、aw86927 Tested-by 备料。
> **新内存到位后的接续清单**（11-23 会话已落盘）：① dwc3 v12 G4（断点日志在 `logs/`，从断点续跑不重做）→ G5/G6 → 发信 → lore 复核；② 设备 BL 窗一次做完：G7 换口重测（先部署整套 `/lib/modules`）+ H2 十条判据 + D1 时间基线上机；③ aw86927 三枚 `Tested-by` 收进 haptics 下版。主机当日三次 panic 证据已上交 hw-stability（`evidence/inbox/20261123-host-crash-day-vmcore/`），项目侧不深挖。
> 新会话**只读本节**就知道「做到哪、卡什么、下一步」。三行都有日期 + 证据指针；
> 与其它文档冲突时**以本节为准**，冲突处按 §2「时间序裁决」处理（旧说法标作废或直接删）。
> 数字口径：完成度以 `TASKS/README.md` §0（脚本 `scripts/check-progress-counts.sh --tsv` 现出）为准，本节只摘结论。

0. **🆕 2026-11-21 深夜收尾 — 待办改「维度制」+ §4 长块下沉 + 中文词库上机**
   - **TASKS §4 重写为 §4.0 维度总表**（D1 设备日常化 / D2 上游化 / D3 输入与桌面 / D4 安卓共存 / D5 脚本卫生 / D6 文档与踩坑 / D7 UEFI·Gunyah / D8 G3 / D9 主机稳定性）：
     每行 = 现状一句 + 可派发粒度开放项 + 是否需设备 + 权威指针；**派子代理先读这张表**。11-18→11-21 六个长块逐字下沉
     `TASKS/sessions/2026-11-21-§4待办区块下沉.md`（TASKS 650→504 行）。
   - **中文输入 v3 已上机**：pypinyin 单字表 → **CC-CEDICT 125 479 条 + jieba 词频**，按首音节 23 分片共 2.2 MB、80127 键，
     热 **15–21 ms**（`shijian`→时间/事件/实践、`womens`→我们的，用户实测）；helper 从「没人装」的旧 overlay-aside 目录移入
     `files/` 并进 `MANIFEST.tsv`（此前 stage 组镜像不会带上它）。提交 `0162dcfb`。
   - **设备**：vk192 日用态未变（`/`=`sda17` 190 G 用 7.7 G · `ab-mark-successful` enabled · `qbootctl -n b` marked successful）；
     `hexagonrpcd`/`droid-juicer` 仍 masked。**G7 件已出**（`dwc3-g7-prep` 子代理，`out/g7-20261121/`）：7.4-rc3 worktree 7/7 apply、6 个 blob 与 `GATES-v11.md` 逐个相同、config 与在机 vk192 逐字节同一份、`boot.img` sha `00912631825bc33a…` / rolehook 变体 `727bb55f…`（`KBUILD_BUILD_TIMESTAMP` 钉住后重链 sha 不变）。**但只覆盖 USB 面**：板 DTS 是上游骨架 ⇒ `dsi@ae94000/ae96000` `disabled`、无 WCN/pcie0、无 Type-C 消费者（换口须 rolehook），且 `usb0`/`ttyGS0` 就是被测的 dwc3 gadget（挂了全盲）⇒ **上机前先定「7.4-rc3 极限 USB 面」vs「v11 落 daily 面」**；全账 `reports/dwc3-g7-prep-20261121.md`。**★当晚 20:37 上机实测 = 失败但归因明确**：该件 DTB 全树只有 **4** 个 `status="okay"`、`ufs@1d84000` = `disabled` ⇒ 无块设备、`root=LABEL=linux` 必失败、`panic=15` 回 BL（journal 无该次条目、pstore 空 ⇒ 从未到 userspace）。件状态改 `BLOCKED_STRUCTURAL_NO_ROOT_FS`；坑 = `PITFALLS #710`（上机前先 `dtc` 算可观测面）。设备已回 vk192 日用态（零写盘）。

0. **🆕 2026-11-21 傍晚（主机侧，无人值守轮次）— dwc3 v11 已 SENT-ready（未投，等放行）**
   - 吃 sashiko 对 v10 的 4 条意见、只动三处，G1–G6 全绿（主会话独立复跑 apply 3/3 + 六枚 blob + checkpatch 0E/0W/0C×3 一致）、G7 上机未做；件 = `patches/upstream/dwc3-v11-20261121/`（`MANIFEST.md`、`GATES-v11.md` §5 = 放行清单）+ `reports/dwc3-v11-20261121.md`；0004 板 DTS 继续 hold。
   - **三处改动原文 + 版本账事实（v10 实投 1/3 = 11-18 版、11-20 重写版从未投出）逐字只在 `TASKS/README.md` §7「2026-11-21 傍晚增量」**（2026-11-21 去重：本节不再复述，避免两处漂移）。

0. **🆕 2026-11-21 深夜 — 设备停在 BL 的真根因 + 7 路子代理产出（主机侧，零设备接触）**
   - **设备（P0）**：ABL 日志原文 `ValidateSlotGuids: BootableSlot _b does not have valid guids` ⇒ `FindBootableSlot`/`LoadImageAndAuth`
     `Device Error` ⇒ `Launching fastboot`。源码级判据 = `PartitionTableUpdate.c:1568`（`boot_<slot>` 与 `abl_<slot>` 的 type GUID 相同即拒），
     `set_active`（`:560-621`）会整表换 GUID 侧 + 切 UFS boot LUN、**非幂等**。已排除：换 `boot_b` 内容 / 重刷 `vbmeta_b` / 写回原厂 `vendor_boot_b`（三条都试过，日志一字不变）。
     修复已脚本化 = `scripts/recover-lun4-slotguid.sh`（dry-run 默认；写盘只经 `linux-gpt-apply.sh`，带读回）。
     ⚠ **GPT 修好后 `boot_b` 要刷 `boot_b-minbase-labellinux-20261119.img`（740d431b，`elden_root=LABEL=linux`）**，不是 `bootslot-b/boot_b.img`（06c081ca，`LABEL=linux17`）。
     全账 = `reports/bootloader-slotguid-brick-20261121.md`、`PITFALLS #697 §6`（本轮再证）。
   - **本轮 7 路子代理产出**（均为 2026-11-21 深夜，文件名带 `20261122`）：
     `reports/scripts-audit-20261122.md`（369 入口：KEEP 344 / STALE 15 / DANGEROUS 7 / BROKEN 3）·
     `reports/mobian-mr-plan-20261122.md` + `reports/mainline-upstream-audit-20261122.md`（已进树 1 系列、SENT 8 系列、可投 4 件；dwc3 v10 吃 sashiko 4 条须出 v11）·
     `reports/ime-osk-zh-matrix-20261122.md`（推荐 R1：`phosh-osk-stub` 单栈 + `Completers=pipe` 拼音 helper，2–3 人时）·
     `reports/daily-linux-deploy-20261122.md`（旧 systemd 分支 9 缺陷；`ab-mark-successful` 重写 + deploy §13）·
     `reports/pitfalls-condense-20261122.md`（7 文件 +16 行、编号零改动）·
     `reports/best-state-and-gap-20261122.md`（历史最佳 = 11-20 23:10 态；30 条补全清单 + 8 组互斥）·
     `reports/android-boot-audit-20261122.md`（H3/H4/H5 排除成立；H1 实为无样本；根因排序 H6 > H7 > H1 > H2）·
     `reports/session-plan-20261121-night.md`（协调面板：P0/P1/P2 与使用权规则）。
   - **★P0 已完成（16:42–16:55）**：EDL 实测 b 侧 `boot_b`/`abl_b` 的 **PartitionTypeGUID 同为占位 `77036CD4…`**（只比 unique GUID 会误判正常）；
     新工具 `scripts/gpt-slot-swap-guids.py` 交换 32 对 `X_a/X_b` 的 type GUID + 写 ACTIVE 位 + 重算双表 CRC（自检：单向/往返），
     经 `linux-gpt-apply.sh --lun 4 --apply --reset` 写盘（读回+设备端 sha256 全 OK）；`boot_b` 刷 `740d431b`（`LABEL=linux`），**未再调 `--set-active`**。
     结果：两次冷起直进 Linux（vk192、`/`=sda17、`LABEL=linux`）；`ab-mark-successful.service` enabled + `Result=success`；
     `qbootctl -n b` = `is marked successful`；`deploy-desktop-shell.sh --check` **MISS=0**（含新 §13）；`check-doctor` **FAIL=0**。
     回退表 = `backup/HA2EXB0E-16+512/edl-apply-readback-20261121-164957/`（2026-11-21 现查：目录内只有 `gpt4-{primary,backup}.bin`、`pre-write-{primary,backup}.bin`、`pre-write-snapshot.json` + 两份 qdl 日志，**无 `rollback/` 子目录**）。
     ⚠ **能力回退要记账**：排查期间 `vendor_boot_b` 被写回**原厂** vendor_boot ⇒ 下午的 **b 槽 FAT32 ESP（UEFI 载体）已不在机**；
     重做件在 `out/uefi-bslot-20261121/esp4k.img`（+ `esp.img`），重刷 = 一条 `fastboot flash vendor_boot_b`，需一次上机验证；
     UEFI 那条线本身仍停在「有字没菜单」，恢复优先级低于日常化。
   - 同轮主机侧落地：`rootfs/debian/stage.sh` 新增 **4e**（`units-extra/*.service` 按 `WantedBy=` 建启用软链——此前只给 `*.timer` 建，
     `ab-mark-successful.service` 会「装了不启用」）；`scripts/fix-ab-mark-successful.sh` 重写（`--mark-once/--check/--install/--uninstall`，
     sh/dash/busybox `-n` + shellcheck + `systemd-analyze verify` 全绿）；`scripts/README.md` 已重新生成（346 入口），`check-doctor` **FAIL=0**。

0. **🆕 2026-11-21 傍晚 — OSK 中文输入打通（R1 落地，用户实测可用）**
   - 现役 `phosh-osk-stub 0.46` 本身就是 IM + 自带候选条：`completion-mode` 只有 none/hint/manual（**无 `always`**，`PITFALLS #709`），
     `manual` 的入口 = OSK 菜单里的 **「Word completion」** 开关（无 gsettings 键）；打开后敲拼音即出候选、点选上屏中文。
   - 候选引擎 = `packaging/elden-userland/files/usr/local/bin/elden-pinyin-completer`（pipe completer，
     `Completers default=pipe` + `Completers.Pipe.command=/usr/local/bin/elden-pinyin-completer`）：
     GB2312 一级字过滤 + 常用词表 + 高频字首选项 + 索引缓存 ⇒ **冷 215 ms / 热 20 ms**。
   - 设备侧依赖 `python3-pypinyin`（已入 `rootfs/debian/daily-baseline.tsv`）。剩余可选提升 = librime one-shot（词库/整句）。
   - **脚本整改批 1 已落地**（7/7 DANGEROUS 加 fail-closed 门：`gpt-restore-tb322fc.py` 缺/错表指纹拒绝出件、
     `gpt-slot-flip-active.py` 写前跑 `ValidateSlotGuids` 判据并指向 `gpt-slot-swap-guids.py`、`ath12k-load.sh` 退役并移出装机名单、
     `f2fs-migrate.sh`/`dev-*-relabel.sh` 的 SN 与 PARTLABEL 硬门、`n5b-vk64-death-rate.sh` 去掉 `reboot2` 软路径）；
     全账 = `reports/scripts-hardening-1-20261121.md`（静态验证 + 合成 GPT 夹具实测，零设备接触）。
   - 上游 MR：`mobian1/droid-juicer !46`（`configs/lenovo,elden.toml`，+116 行，CI 跑过；未在硬件验证已在描述里声明）。

0. **🆕 2026-11-21 晚 — 文档现实性核查与收敛**：INDEX/TASKS/DEVICE 死指针 9 处修平（已删目录/归档件/截断文件名）、TASKS §4 11-20/21 长增量块逐字下沉 `TASKS/sessions/2026-11-21-§4增量块下沉.md`；门禁复跑 FAIL=0。全账 = `reports/doc-reality-audit-20261121.md`。

0. **🆕 2026-11-21 下午 — 收尾：UEFI 纯 b 槽基建已落地、路 A 实测“有字没菜单”；发行版路线定在 Mobian**
   - **UEFI（b 槽）已就位且不碰现有引导**：`vendor_boot_b` = **FAT32 `ELDENESP`（4K 扇区，Linux 可挂）**，内 `EFI/BOOT/BOOTAA64.EFI`（自建 GRUB）；
     菜单**外置**在 `linux17:/boot/grub/grub.cfg`（4 项：Linux / Android a / Android a verity-off / reboot）；
     `linux17:/boot` 已有 `Image`(64 MB，由 `boot_b` 的 gz 内核解压，sha `0a55e52c` = 守卫核)、`initrd.img`、`elden.dtb`；`a 槽安卓`四件在 `/boot/android-a/`。
     `boot_b` 全程未动（sha `740d431b`）、回退 = 清 `misc` 后普通重启。
   - **路 A（RAM 引导归档 R21 Mu）实测**：`fastboot boot` OKAY，**屏上有字但无 GRUB 菜单** ⇒ Mu 跑到 DXE/BDS，但 **R21（11-05）早于 R54（11-08）的 `bdsdxe-esp-first`**
     ⇒ BDS 不把我们 FAT ESP 当候选。**⇒ 下一步 = 换带 esp-first 的载荷（`p65`/`p69`）上机**——**不需重建**：归档 FD 已在盘上、
     repack 秒级 ⇒ `build/uefi-woa-prep/merge-espfirst-20261121/out-p65/uefi-preamble65-r1.img`（`4d1ebc06…`）；
     源码树也已重放好（84 条补丁 **OK=84 / FAIL=0**，基线 = `mu_wide_platforms@6b6ac42a`）。全账 = `reports/uefi-mu-espfirst-replay-20261121.md`；
     原可行性账 = `reports/uefi-bslot-plan-20261121.md` §6/§7。
   - **发行版（用户裁决：选 Mobian）**：Nura（原 pmOS）**AI 政策禁生成式 AI 贡献 ⇒ 不可投**；UBports 要 Halium（Android 内核）⇒ 不投；
     **Mobian 唯一可行**，硬缺口 = **内核 LTS 版本账**（Mobian 只收 6.1/6.6/6.12/6.18，我们在 7.3/7.4）；
     不碰内核的第一件可提交物 = `droid-juicer` 配置 + `mobian-recipes` 的 `wip.toml` 条目。全账 = `reports/distro-upstream-feasibility-20261121.md`。

0. **⚠ 2026-11-21（lane C 只读 + 主会话复核）—— 安卓 a 槽两条旧证据被推翻、判别顺序改写（影响 B 档回收判据）**
   - **`logfs` 只有 segment 0 会被 ABL 重写**：三份 dump 的 seg1..12+ 与出厂包 `backup/official-rom-15.10.259/logfs_ufs_8mb.bin`
     **逐段 sha 相同**（`diff segs: [0]`，主会话重跑验证）⇒ 之前引用的 `Loading Image recovery_a` / `Booting from slot (_a)` /
     `factory_build=1` / `EBS 13311` 全是**出厂遗留**；「ABL 选 recovery_a」= **无证据命题**（`Loading Image <part>` 是每次任务启动的
     头部探测，b 槽同样有 `recovery_b`；真 recovery 会打 `Recovery:1`）。新坑 = `PITFALLS #703`，`#702` 已就地标更正。
   - **现态实读**：在机 `super` = **v1**（头 4 MiB `d516ae04…` = `out/android-min-20261118` 件）· a 链除 `vbmeta_a`（`419e01ac…` ≠ 原厂 `55929c15…`）
     全原厂 · `misc` 前 4 KiB 全 0 · 现役镜像 **vk192**（`uname -r` 里的 `vk189` 是 LOCALVERSION 残留，不是两个版本）。
   - **判别顺序（新）**：① H5 = 刷原厂 `vbmeta_a`（10 min，**需物理键**）→ ② 落点当场取 **seg0 logfs + cmdline** → ③ S2 不再跑（11-20 实测 no-op）、
     S3（原厂 `super` 对照 14.5 GiB）**降为对照**。全账 = `reports/android-a-slot-laneC-20261121.md`、证据 = `logs/a-slot-analysis-20261121/`。
   - 连带：**B 档 37 G `pending` 的解冻判据改由 H5（10 min）先给信号**，不必等 S3。

0. **🟢 2026-11-21 —— 里程碑：项目第一个上游系列进树（`wl2868c v12` → `regulator.git for-7.5`）**
   - Mark Brown 已合入：`84e67d2ee13f…`（binding，2 文件）+ `602f57223457…`（driver，4 文件），均 `Author: Qianhui Xu`；
     上游合并提交 `0216753490ff…`，已在 **linux-next `master`**。**主会话已独立复核**（`git.kernel.org/…/broonie/regulator.git/log/?h=for-7.5` 逐行命中）。
   - **口径修正（重要）**：patchwork 上 arm-msm 副本 `14991614/14991615` 今天仍 `state=new` / `commit_ref=None` ⇒
     **「只有一个 project 的 new / commit_ref 空」不构成「未合并」证据**（`TASKS` §7「三条限定」的实发反例）；判合并只能查维护者自己的树 / linux-next 内容级。
   - 我方动作 = **只剩回填**；邮件全账（窗口 11-15→11-21，人类回帖 5 封 / sashiko 5 封 / 退信 0 / 必须先回 0 件）= `reports/mail-inbox-20261121.md`。
   - 同轮：**dwc3 v10 已 SENT-ready**（G1–G6 全绿，G7 上机未做，等放行）= `patches/upstream/dwc3-v10-20261120/GATES-20261121.md`。
   - ⚠️ 另上报（未验证、不自行处置）：11-18 两封 GitHub 安全告警（新细粒度 PAT 创建、第三方 OAuth 应用被授权）——是否本人操作需用户确认（硬规则 2）。

0. **🆕 2026-11-21 早（主机侧，无人值守轮次；设备 offline）—— b 槽 AVB 债还清（造件 + 生成器 + 门）**
   - **债**：设备在机 `vbmeta_b` 顶层 key 与 chain `boot:3` 都是**旧钥 `fc1e3b33…`**（2026-10-18 换钥后没重签），
     而 `boot_b` 的 AVB footer 已是现役 `1e54e86e…` ⇒ 自签链自身不自洽（槽位启动只能靠 `Flags=3` 不解析描述符绕过）。
   - **产出**：`scripts/build-vbmeta-b.sh` → `out/vbmeta-b/vbmeta_b-flags3.img`（65536 B、Flags 3、顶层 + chain 同钥、
     整链 `verify_image --follow_chain_partitions` rc=0、sha `906e69…`）＋ `check-doctor` **§26**（换钥忘重签⇒FAIL，翻字节反作弊）。
     7 项离线判据全过；用同一校验器跑**在机** `vbmeta_b` 得 2 处 FAIL（修复前对照）。
   - **剩**：一次上机验收 `fastboot flash vbmeta_b` + `fastboot boot bootslot-b/boot_b.img`（设备窗口；回退件在 `logs/forensics-20261120-2210/vbmeta_b.img`）；
     `flags=0` 干净链需先有 `dtbo_b` dump。成因/证据 = `reports/vbmeta-b-resign-20261121.md`。
   - **★设备在线轮（同日 08:3x，`ssh elden-root` 通）**：up 9.1 h / vk192 / b 槽 Linux / `/` 用 7.1 G / **`deploy-desktop-shell.sh --check` = MISS=0**
     （桌面 + greetd + 音频 Speaker + 触觉 ×2 + 启动队列 mask）。**查出并修掉一个「观测能力丢失」**：T9 采样器在 11-19 重建根后
     脚本/两枚 unit/`/var/lib/elden` 三样全无 ⇒ 一直是「没数据」（`PITFALLS` **#700**）；已恢复（timer enabled+active，表 20 列对齐）
     并固化四处（`tick` 模式 + `units-extra/` 手写 timer + `stage.sh` 4d + deploy **§12** + doctor §22 非包锚点）。
     端到端：一次 `rtcwake -m mem -s 45` 前后各采一行，`suspend_stats` **3/0 → 4/0**、`fail=0`。全账 = `reports/t9-sampler-restored-20261121.md`。
   - ~~**同一设备窗口：Linux→fastboot 三条软路径实测全灭（`PITFALLS` #701）⇒ 上机测试只能物理键**~~ **2026-11-23 已更正（`PITFALLS` #712）**：`sync; systemctl reboot bootloader` 在无钩子 vk192 上也进 fastboot；下段只留仍成立的措辞：PSCI 钩子缺（#690）·
     `misc` BCB `bootonce-bootloader` ABL **不采纳**（写后读回校验通过，仍普通重启，用户目视确认）·
     `qbootctl -u b` 写失败（`gpt_disk_commit: Invalid args`；`-i` 未测）。已交付设备侧 `elden-to-bootloader`
     （能力自检 + BCB 备份/读回校验 + `--clear-bcb`）与主机侧 `scripts/to-bootloader.sh`（三态判据，回 Linux 时自动清 BCB）；
     设备收尾态干净（BCB 全 0、`_b` Active/Succ/Bootable 全 1、graphical active）。全账 = `reports/linux-to-fastboot-20261121.md`。
   - **★AVB 债已上机验收通过（同日 09:0x，用户物理键进 BL）**：`fastboot flash vbmeta_b out/vbmeta-b/vbmeta_b-flags3.img` = OKAY →
     `reboot-bootloader` → `fastboot boot <在机件 740d431b…>` = **`Booting OKAY [10 s]` 且真起进 Linux**（ssh 通、`/`=`/dev/sda17`、graphical active）；
     分区读回 sha `906e6922…` = 主机件。**修复前**同一命令 = `Failed to load/authenticate boot image: Device Error` ⇒ 归因结束。
     ⚠ 校准：RAM 引导必须用与在机槽一致的件（先拿仓库旧副本试出「只有背光 + 只有 gadget」= 副本不同，不是刷坏）。
   - **Android S1 的两个真缺陷同日修掉**（本轮实测踩到、样本作废前拦下）：`ensure_active_a` 在 Linux 侧只打印不切槽（且 Linux 侧
     `qbootctl -s/-u` 实测写失败 #701）⇒ 改 fail-closed + 人项指引；S1 第 4 步补 fastboot 分支（`fastboot reboot` 直接启 a 槽）；
     `boot_a` byte6 判读改为解位（只有 UNBOOTABLE 或 retry=0 才算异常）。
   - **同轮（设备窗口就绪度）**：① `scripts/boot-img-cmdline.py` 扩到 **vendor_boot v4**（cmdline 窗口 28..2076，
     等长原地改写）+ `--selftest`（4 正例/4 反例）+ `check-doctor` **§27**；S5 两件已落
     `out/android-v3-bringup-20261120/boot-ttygs0-{boot,vendor_boot}.img`（vendor 侧五段载荷 sha 全 SAME）。
     ② **`fastboot` 假 MISS 修掉**（PITFALLS **#699**）：本机 fastboot 在 `~/.local/opt/platform-tools` 而
     walkthrough 用 `command -v` 判 ⇒ `--step S5 --dry-run` 曾整轮 `MISS` 退出；新 `scripts/lib-hosttools.sh`
     统一解析（`lib-fastboot.sh` 同改）。
0. **🆕 2026-11-20 22:00–23:10（U2 HA2EXB0E，当晚目标「恢复到历史最佳」= 达成）— 设备曾卡 fastboot（三层真因已定因并修好）+ PC 声音默认转发到平板**
   - **现态（三次冷起实测，均 ~25 s 直进 Linux，无回落）**：`boot_b` 主启、`qbootctl` = `_b` Active/Successful/**Bootable 全 1**；在机 **vk192**（UTS `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`）；`/` = `/dev/sda17` 190 G（1260 包）；`phoc+phosh` 在；Mesa **26.1.6**；`wlan0` 上网（默认路由）+ `usb0` 192.168.7.1 SSH；六件 mask 在位、`systemctl --failed` 空。
   - **两种门全绿**：`scripts/deploy-desktop-shell.sh --check` = **MISS=0**；`scripts/zero-to-desktop-check.sh` = **S5–S12 全 ok**（S10 之前 MISS 的两项已修：`man-db` 装上、GPU devfreq 真生效 525 MHz/10 ms）。
   - **fastboot 卡死的三层真因（PITFALLS #697，全文 `PITFALLS/sessions/329-fastboot卡死的三层真因-GUID占位与LUN错配.md`）**：① `boot_b` SUCCESSFUL=0 ⇒ ABL 每发抽 retry，7→0 标 UNBOOTABLE 停 fastboot；② `ValidateSlotGuids … Boot GUID 77036CD4… / abl_b GUID 77036CD4…` = 该槽 `boot_*` 与 `abl_*` **type GUID 相同**（出厂 b 侧占位值）；③ `Boot lun: 1 and BootableSlot: _b do not match` = UFS 启动 LUN 未切（**a→LUN1 / b→LUN2**）。机制 = Qualcomm 切槽要**把 type GUID 在两槽间搬家 + 切 LUN**（`boot_control.cpp` `UPDATE_SLOT`）⇒ 「canonical GUID 在哪侧」必须与「哪侧 active」一致。**修法**：切槽只走 `fastboot set_active`；半完成态用 `scripts/gpt-slot-flip-active.py` + `scripts/linux-gpt-apply.sh --lun 4` 补 ACTIVE（写后逐字节/设备端 sha 读回），再 `set_active <同槽>` 触发 LUN 切换，起来后 `qbootctl -m`。
   - **PC → 平板音频（新功能，默认常驻两端）**：上游 `mkckr0/audio-share` 只有 Android 客户端 ⇒ 自写 Linux 客户端，**已收进上游 fork `xiaquwan1001/audio-share` 的 `linux-client/`**（`as-client.c` + Makefile + user unit + 协议/排障 README；本仓 `rootfs/debian/audio-share/as-client.c` 是该文件的镜像，改动先落 fork 再同步回本仓）。协议逐字节取自上游 `NetClient.kt`：TCP 命令字 1/2/3 + protobuf AudioFormat + UDP PCM；**交付形态 = deb 包**（`dist/audio-share-client_0.1.0_arm64.deb`，68 KB：`/usr/bin/as-client` musl 静态 + `/usr/bin/audio-share-gui` GTK3 窗口（服务器地址/端口/输出 sink/播放停止/协商格式/实时码率/开机自启勾选）+ `.desktop` 入口 + hicolor 图标 + `/usr/bin/audio-share-client-run`（读 `~/.config/audio-share-client/config.json`）+ `/usr/lib/systemd/user/audio-share-client.service`），装机/体检 = **`scripts/as-client-deploy.sh [--check]`**（建 deb→scp→dpkg -i→写配置→起单元；旧 `/etc/systemd/user` 单元与 `/usr/local/bin/as-client` 会覆盖包内件，脚本自动搬走）。客户端播放管道非阻塞（拥塞丢 PCM 而非阻塞收流，否则 `pw-cat` 卡住会饿死心跳、被服务端每几秒踢一次）。主机侧改成 user unit `audio-share-server.service`（`as-cmd --bind=0.0.0.0`，原来只绑手机网段 192.168.42.97 ⇒ 平板连不进）+ ufw 放行 192.168.7.0/24 的 65530/tcp,udp。设备侧 user unit `audio-share-client.service` → 192.168.7.9:65530，实测 **384 KB/s = f32/2ch/48 kHz 满速**，冷起自动连（`systemctl --user is-active` = active）。
   - **「平板静音但一切 active」的判据（2026-11-24 实锤）**：`as-cmd` 的采集线程**只在启动时枚举一次 sink**，枚举为空就打 `audio endpoint list is empty` 后**线程永久退出**，服务照旧 listening、客户端照旧 `active (running)` 重连（客户端日志刷 `bad AudioFormat size 0`），但 `GET_FORMAT` 永远是空 protobuf ⇒ 无声。处置：PC 侧 `as-cmd -l` 能列 sink + 重启 `audio-share-server` 即可恢复；判「是不是这条」只看两个日志（服务端 `audio endpoint list is empty` / 客户端 `AudioFormat 尺寸异常 0`），不要先怀疑平板音频栈（`wpctl status` 里 pw-cat 流挂到 Speaker playback 即为端到端正常）。上游未修（返回而非重试）⇒ 冷起/换 sink 后要重启 as-cmd。
   - **顺带修掉两个静默坑**：`deploy-desktop-shell.sh` §8 原来只 `test -f` unit ⇒ 「unit 在、脚本被删、运行值还是 160 MHz/50 ms」也报 ok（现改四件同验：脚本 + unit enabled + min_freq≥525 MHz + polling=10）；设备 `/home/xuqianhui1001/.config/systemd/user` 属主是 root ⇒ 用户级 enable 失败（已 chown）。
   - **驱动/功能面补回（用户点出「恢复历史最佳还包括驱动」后）**：音频真因 = 重建根丢了**自研资产**而非驱动 ——
     自编 tplg 不在 `/lib/firmware/qcom/sm8750/`、UCM2 两文件没装、`alsa-utils` 缺 ⇒ `amixer` 全 WARN、PipeWire 只有 `虚拟输出`；
     补后 Sink = **`内置音频 Speaker playback`**、`audio-alsa-init.sh` 出 `mm1[on,off] L[400] R[400]`、`pw-play` rc=0。
     触觉 = 驱动 `aw86927`+haptics-v3 在、两枚 FF 节点在，缺的是 `ffrumble` 基线工具（`ffrumble /dev/input/event{2,3} 700 0xffff` 两轮阳性）。**两项均已用户实测确认**（扬声器出声 + 两侧马达都震）。
     两项已机械化进 `deploy-desktop-shell.sh` **§10/§11**（多件同验），冷起后仍绿（PITFALLS **#698**）。
   - **证据**：`logs/forensics-20261120-2210/`（boot_b 96 MiB、logfs×3、misc、vbmeta_a/b）、`backup/HA2EXB0E-16+512/edl-20261120-22{08,35}/`（两次六 LUN GPT dump）、`…/edl-apply-readback-20261120-223802/`（写前回退基线，全名 `backup/HA2EXB0E-16+512/edl-apply-readback-20261120-223802/`）；工作账 = `.pi/plans/2026-11-20-恢复到历史最佳.md`。

**做到哪**

0. **🆕 2026-11-20（主机侧，单轮）—— dwc3 v10 的「两连接器」形状第一次进真 elden DTB 的 `dtbs_check` 门，零新增诊断**
   - elden 板 DTS 补齐 `mux-controls`（`gpio-mux` on `&tlmm 29`）+ `port@0` 两个 endpoint（`mux-state` 0/1）+ 两个 `usb-c-connector`；硬件依据 = 真机 live FDT（`reports/artifacts/uefi-eud-20261101/live-fdt.dts`：`port-select-gpios = <&tlmm 29 …>`、`connector@0/@1`、每口一颗 `fsa4480`）+ vendor overlay 的 `&ucsi` `gpios` 同一条线 + 2026-10-29 双口充电实测。件与门账 = `patches/upstream/dwc3-v10-20261120/elden-dts/` + 同目录 `README.md` §7。
   - **门对照**（`CHECK_DTBS=1`、**不带** `DT_SCHEMA_FILES`）：加之前 3 诊断 / 加之后 3 诊断（**新增 0**，3 条都是板级既有噪声）；两个自造负样例分别 5/2 条 USB 诊断 ⇒ 门真咬得住。**关键修正**：v9 那版「在 `sm8750.dtsi` 里无条件把 `port@0` 拆两 endpoint」会让 mtp/qrd 各多 2 条诊断，已改为 dtsi 只加一个 label、板级 `/delete-node/` 重写。
   - 新坑 **#696**（`PITFALLS/sessions/328-dtbs_check加DT_SCHEMA_FILES对无select公共片段恒空转.md`）：`DT_SCHEMA_FILES` 对**无 `select:` 的公共片段**恒空转；另修 `DEVICE` §1.4 SMB1501 地址错（`@0x42/@0x43` 是 `fsa4480`）。
   - **未做**：上机（mux 实际切换/两口枚举）；GPIO 29 的语义/极性/0↔口对应仍无硬件证据（子代理复核降级）；`gpio-mux` probe 即驱低 ⇒ 「保留厂商开机态」需改驱动或换表达。
0. **🆕 2026-11-20 全天（主机；grow-loop #1–#5）—— 三份账/三道门落地、累计回收 ~19 GB；a 槽首启实测得新前置条件（PITFALLS #695）；**设备现离线（需人项插线+上电）**
   - **全账** = `.pi/plans/2026-11-20-进度整理与待办规划.md`（现态实测 + 4 lane 产出 + 排好序的待办 + 4 条待拍板）。
   - **主机侧已落地**：① A 档回收 **8124 MB**（`out/` 87→75 G）；② `check-doctor` **§23 out/ 造件账本门**（`scripts/out-manifest-check.py` + `scripts/out-manifest-exempt.tsv`，含空理由豁免必 FAIL 的反作弊与 4 类 selftest）；③ 上游现查一页账 `reports/upstream-recheck-20261120.md`（**§7 台账落后 1–2 代**：wl2868c 已 v12、dwc3 已 v9 且 Rob Herring 11-18 回「??」、elden DTS v7、fastrpc v3、M8 现役 = mdss block-resets 3 枚），`TASKS §7` 头已加增量块；④ v3 上机执行包 `scripts/android-v3-bringup-walkthrough.sh`（`--dry-run` 默认，父代理复跑 `--verify` 7 件全过）+ `reports/android-v3-bringup-packet-20261120.md`；⑤ arch-audit P1#3 收尾：`scripts/README.md` 生成索引（334 入口）挂 `check-doctor` **§24 新鲜度门**（`gen-scripts-index.py --check` + 删行反作弊，只进全量档，设计/验证 = `reports/scripts-index-gate-20261120.md`）。
   - **11-20 下午续（grow-loop #1–#5，均为主机侧）**：① 大文件裁决 `reports/bigfile-verdict-20261120.md`（`parts/` 15 G 可删已证=官方分片重装后 7/7 逐字节一致；`min-restore` 根**不可删**、`p2` 才是真子集）；② out/ 生命周期账 `versions/out-artifacts.tsv` + **§25**（词表 active/verified/superseded/**pending 禁删**——`slim-v3`、`android-min`(v1 对照)、`slim-v2b`(S4 二分) 三件已标 pending，防止按旧推断误删实验材料）；③ PITFALLS 79 条「正文只在专题报告」回填（**0 孤儿索引行**）；④ py 静态扫描（pyflakes 未用 import 15→0）；⑤ §24 判据改**结构指纹**（文档编辑不再触发，增删脚本仍触发）。
   - **设备侧实测（a 槽）**：`reports/android-a-slot-attempt-20261120.md` —— v1 在机、BCB 清 0、`boot_a` 属性修复后 reset **仍失败并自动回落 b 槽**（logfs 末条 EBS 13.3 s；pstoredump 无 panic 文本）⇒「BCB 是主因」作废；**新前置条件 = 每次上机前复位 `boot_a` GPT 属性**（`0x82` ⇒ ABL 跳过 a 槽），已机械化进 `walkthrough` S1 的 `ensure_boot_a_attrs()`。
   - **四个新硬阻塞**：原厂 `boot.img` = **header v4** 而 `boot-img-cmdline.py` 只支持 v2（⇒ S5 的 `console=ttyGS0` 取证件造不出来）· `qbootctl -a` 是只读查询（设 active = `-s SLOT`）· `metadata` 起点 = **5857704** · **页缓存污染让 buffered sha256「稳定但错」**（v1 件 `637a9965…` vs O_DIRECT `e3d0d26f…`）⇒ 硬门必须 O_DIRECT。
   - **设备现态 = offline**（无 `05c6/18d1` 枚举、`fastboot devices` 空、无 `/dev/ttyACM*`）；**`ping 192.168.7.1` 是假阳性**（走手机热点网关）——判在线只看 `DEVICE/README.md` §1.6 五条。需人项：插线 + 上电 → `sudo scripts/ncm-host-up.sh`。
   - **主机稳定性（规则 12，不深挖）**：本机 10:17/10:27 两次 Pi 子进程 SIGSEGV（MCE=0）、页缓存 sha 漂移、盘上 super 位翻转；证据已交 `~/hw-stability/evidence/inbox/20261120-y700-elden-{pi-child-upstream-lane-segv,pagecache-sha-drift}/`。
0. **🆕 2026-11-19 22:5x（U2 HA2EXB0E）—— 掉电链定因 + 设备已回「最优 Linux 模式」；全仓 8 代理审计产出落 `reports/audit-20261119/`**
   - **掉电链（新坑 #694）**：22:0x–22:36 连续 3 次「进 Phosh 锁屏即整机掉电」。取证 = 每次 boot 的持久日志只到启动后第 1 秒（≈928 行）就断 ⇒ **硬挂不是优雅关机**（无 `final.target`/`System is powering off`）。定因分层：① **已证实** live 系统上 `systemctl disable --now droid-juicer` ⇒ ~40 s 掉电（#693 同族，**禁止再在 live 上停这两件**）；② **高置信未单变量** = droid-juicer 落盘 mask 后顶上来的 `hexagonrpcd`（#692 attach ADSP 硬崩）。
   - **新机制（可复用）**：`scripts/boot-img-cmdline.py --append "systemd.mask=…"` 造 **零写盘救援舱** → `fastboot boot` 进系统 → 只做 `systemctl mask` 落盘 → 正常 reboot。本次 45 s 到 SSH、`graphical.target` active、无 failed unit。全文 `PITFALLS/sessions/326-掉电链定因与systemd.mask救援舱.md`（索引行 #694）。
   - **现态（22:37 起实测）**：`boot_b` 持久启动 / `elden_root=LABEL=linux` / `/dev/sda17` 190 G 用 6.2 G / **greetd+phoc+phosh+phosh-osk-stub 四进程** / Mesa **26.1.6** / **wlan0 = ustcnet 114.214.230.246，默认路由经 wlan0**（`usb0` 192.168.7.1 保留 SSH）/ 时钟正确 / `scripts/deploy-desktop-shell.sh --check` = **MISS=0**。
   - **安卓分区零改动**：`super` 22 G、`userdata` 256.7 G、`metadata` 64 M、`boot_a` 原样（`lsblk PARTLABEL` 复核）；六件 mask = droid-juicer + plymouth×4 + hexagonrpcd（`/etc/systemd/system/*.service -> /dev/null`）。
   - **审计产出（8 代理只读）**：总入口 `reports/audit-20261119/README.md`；`A1-phase-timeline.md`（阶段突破/卡点）、`A2-best-state.md`（最优进度+复现）、`A3-*`（344 脚本分类）、`A4-*`（29 条文档问题+三批顺序）、`A5-forks.md`（14 分叉点）、`A6-*`（152 G 资产批次）、`A7-hygiene.md`、`A8-device-state.md`。**已执行** = 删 2.44 G 构建 scratch（`out/stage-*`）+ 重生成 `reports/README.md`（564 篇/147 组），其余为清单。
   - **遗留（需拍板）**：A6 批次 2/3（~34 G 归档 + ~20 G 中间物）、A4 批二/批三（文档合并/归档）、A3 的 9 项证据型脚本归档、PITFALLS 跳号 159 个人工判。
0. **🆕 2026-11-19 21:5x（U2 HA2EXB0E）—— 共存契约已冻结、安卓 v3 已造件并写入；**上机 3 发均未进桌面，其中 2 发被 BCB 污染；设备现居 Linux（可用）**
   - **共存契约（新，正文 `DEVICE/README.md` §1.7）**：Android = `super 90504..5857671` + `userdata 5972392..73277434`；Linux = `linux17 73277435..123871226` + `boot_b`。
     现场 EDL 读回主表 16 条目**两两不重叠**、无旧破坏设计的单 `linux` 分区 ⇒ `scripts/android-linux-coexist-check.py` rc=0。**实测共存：刷安卓 3 次，Linux 全程可登**（`/` = `/dev/sda17`）。
   - **v3 镜像**：`out/android-slim-v3-20261119/new/`（`system_a.img` **3920 MiB**、`super_min_v3.img` **7109 MiB**；v1 是 5296/8481.5）。
     删全部 41 个预装池目录 + `etc/AI` + `bgmusic` + 18 个无用 leaf 包；**空目录占位 + launcher.db 47→15 行 + 空目录 selinux 标签**三件同办。
   - **上机**：① v3 首启 → 卡 ZUXOS 动画（唯一有效 Android 失败样本）② wipe 后 + adb 免授权件 → 卡 logo 后掉电 ③ 回刷 v1（读回 `e3d0d26f…`）= 同样。
     **现场复核**：`logfs` 每条 a 槽启动都到 `Shutting Down UEFI Boot Services`（≈13.3 s）⇒ ABL 清白；`pstoredump` 无 panic；电池 82%/Charging；
     **`misc` BCB = `boot-recovery`**（EDL 后是 `bootonce-bootloader`）⇒ 后两发很可能是启 recovery，**不算 Android 失败**。
   - **下轮纪律**：清 BCB → 读回校验 → 再 reset；顺序 S1 清 BCB+`qbootctl -a` → S2 原厂 `metadata.img` → S3 原厂 `super` 对照 → S4 二分 v2b → S5 带 `console=ttyGS0` 的 boot 件拿日志。KSU 仍不并入。
   - 全账 = `reports/android-slim-v3-20261119.md` + `TASKS/sessions/2026-11-19-安卓共存契约与v3精简上机.md`；脚本 = `scripts/android-slim-v3-build.sh`。
0. **🆕 2026-11-19 13:20（U2 HA2EXB0E）—— 桌面起来了（Phosh 锁屏，GPU 渲染），全链固化成脚本 + 手册**
   - **链路（全部实测，逐环有判据）**：fastboot 起机 → `resize2fs` **6.25 GB → 190 GiB** → 设备上外网（主机 NAT + 自愈路由 + DNS 上游）→
     时钟冷起自愈（`chronyd -q` step 1.9e7 s）→ 日用基线 **49 包**（`MISS=21→1`）→ greetd+phoc+phosh **三进程**、锁屏截图有顶栏/中文 →
     **Mesa 26.1.6（trixie-backports）= `Adreno (TM) 830` / GLES 3.2**，`glmark2-es2` **Score 2594**。
   - **两个新铲子**：`scripts/deploy-desktop-shell.sh`（9 步幂等自检，`--check` → MISS=0；含包集/用户/greetd appliance/软合成开关/
     usb0 自愈路由/GPU devfreq 固化/会话三进程+截图字节门）、`RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md`（S1–S12 + 速查 + 回退 + 溯源表）。
   - **五个静默失败**（`PITFALLS` #681–#685）：根缺 `udev`（模块零加载）· phosh 必需 `sm.puri.OSK0` · 老 Mesa 不认 Adreno 830
     （pixman 能起但**帧率低**，需 backports Mesa）· RTC 只读且冷起给「镜像构建日 2026-04-13」（日期阈值判据失效）· usb0 无默认网关且主机地址随 gadget 重建消失。
   - **卡点（需人）**：内核未开 `CONFIG_INPUT_UINPUT`（无 `/dev/uinput`）⇒ 锁屏**必须人手滑开**，agent 无法注入触摸做桌面内验证。
   - 全账 = `TASKS/sessions/2026-11-19-EDL到桌面端到端重建.md`。
0. **🆕 2026-11-19 下午（U2 HA2EXB0E，压过下面深夜条）—— 显示修复 = minbase 缺 udev；屏幕出字；槽位 successful 收口**
   - **真因（单变量证据）**：minbase 根**没装 udev** ⇒ `systemd-udevd` 不存在 ⇒ 模块零自动加载 ⇒
     fastrpc/ath12k/音频链全缺 ⇒ DP 组件 defer 拖死 DPU 聚合（11-19 上午/深夜的「显示挂死」全是下游症状）。
   - **修复 + 判据**：主机 NAT（正确出口 = 手机热点 `enx027644563e50`，第一发误加 eno1 由 tcpdump 定位）+ 设备时钟修正
     （2026-04-13 → 现时，TLS 才通）+ `apt install udev` + `enable --now systemd-udevd` ⇒ `modprobe fastrpc` 后
     `/dev/fastrpc-adsp` 出现；ath12k 早启 `-110` = 时序问题，PCI rescan 即复活 ⇒ 固化 `ath12k-rescan.service`（已 enable）。
   - **控制实验（决定性）**：`fastboot reboot` 走持久 `boot_b`（= 上午控制件 `740d431b…`，内核/DTB 零改动）⇒
     **DPU aggregate + DSI×2 + DP + GPU 全 bound**、`/dev/dri/card0` + fb0 1904×3040 + fbcon、音频卡出、**屏幕有字（用户目视）**。
     ⇒ 上午的 nodp DTB 实验**不需要**（DP 不用摘），件留档勿用。
   - **槽位收口**：设备无 python3 ⇒ dd LUN4 主备 GPT → 主机 `slot-attr.py --image` 打补丁（`boot_b` 0x3f→0x7f）→ 写回读回一致
     ⇒ **`fastboot getvar slot-successful:b` = yes**（unbootable=no、retry=7）；件 = `reports/artifacts/slotattr-20261119/`。
   - ~~**遗留小项**：设备 RTC 不保持（重启回 4-13）；wlan0 DOWN 待连网；Phosh 桌面未起~~ **三项均已处置（2026-11-19 13:20，见上条）**：时钟 = `time-sync.sh` 修 + 路由就位补跑；网络 = 自愈路由 + DNS 上游；桌面 = greetd/phoc/phosh 起来（GPU 渲染）。
   - 全账 = `TASKS/sessions/2026-11-19-显示修复=minbase缺udev.md`（+ 上篇 `TASKS/sessions/2026-11-19-显示nodp实验与RAM路径复核.md`：
     11-18 两次 RAM 启动失败真因 = cmdline 根标签 `linux17` vs 实际 `linux`，RAM 路径本身是好的）。
0. **🆕 2026-11-19 深夜（U2 HA2EXB0E）—— 主线 Linux 已重建到「能登入」；~~显示仍缺~~（已于同日下午修复，见上条）；安卓面零改动**
   - **旧 `linux17` 数据确认丢失**：EDL 只读采样 6 点（起点 73277435 及 +10/+50/+134/+275/+359 GiB）非零字节 **全 0**；
     成因 = 11-17/18 恢复原厂时 stock `userdata`(449.7 GiB) 覆盖该区间（`fastboot -w` 再把它 discard 成零）。
   - **已重建（都过读回校验）**：LUN0 GPT 写回手术表（`linux17` 193 GiB + `userdata` 256.7 GiB，主备 `80ab46e5…`/`e5f79c0e…`；
     **`super`/`vbmeta_system`/`boot_a`/`dtbo_a` 未动 ⇒ 安卓装机测试面保留**）；LUN0 `73277435` 写 6 GiB 最小 Debian 根（设备端 sha `abf96ec4…`）；
     `boot_b` = 同 vk192 核/DTB/initrd、仅 cmdline 改 `elden_root=LABEL=linux` 的自签件（读回 `740d431b…`）。
   - **现态**：`ssh root@192.168.7.1`（需先 `sudo scripts/ncm-host-up.sh`）/ systemd PID1 / 内核 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0` / **当时 165 包** / **当时 `/` 2.0 of 5.9 GiB**（数字均为当晚快照；今日现态 = 1253 包 / `/` 190 GiB 且桌面已起，见上条）。
   - **显示仍缺，根因已定界**：`device_component/ae01000.display-controller` = `aggregate not bound`，`ae94000/ae96000.dsi` not bound，
     `(unknown)×2` not registered；`af54000.displayport-controller` 在 `devices_deferred`（`aux_bridge: failed to acquire drm_bridge`）
     ⇒ **DP 组件拖死 DPU master**。同批失败：`ath12k` MHI `-110`、无 `/dev/fastrpc-adsp`、音频卡 deferred。
   - **明早接续**：① 上电 → `scripts/ncm-host-up.sh` → ssh 验活 + `slot-attr.py mark-successful b`；② 显示实验（`out/min-restore-20261119/dp-port2-experiment.patch`）；
     ③ 桌面 = `resize2fs` + `daily-baseline`。全账 / 待办 = `TASKS/README.md` §4 首条 + `TASKS/sessions/2026-11-19-主线恢复最小Linux与显示定位.md`。
   - **设备可用性（压过历史「等送修」口径）**：**不需要送修、无硬件故障证据** —— 「ABL 内存类硬件故障 / 全原厂态仍失败 ⇒ 等送修」已于 **2026-11-19 正式作废**
     （真因 = 非原厂 GPT，11-17 19:2x 单变量定因；20:0x 完整起 Android 16、11-18 最小安卓包、11-19 本最小根 = 三次真实上机）。
     2026-11-19 19:xx 实测设备**未连接**（`lsusb` 无 `05c6:*`/`18d1:*`、`fastboot devices` 空、`adb` 只有 P40pro `MDX5T20730009849` 与 `emulator-5554`）⇒ **离线 ≠ 坏机**。
     在线确认 5 条命令 / 判读规则 / 人项动作 = `DEVICE/README.md` **§1.6**；新旧口径对照表 = `reports/device-status-20261119.md`。
   - 历史（11-18）：`super_min` 上机成功（8.28 GiB、`/system` 5.0 GiB）但 wipe 后卡 ZUXOS 动画（未取证）。

0. **🆕 2026-11-18 小时级状态（U2 HA2EXB0E）—— 精简安卓包已上机成功；当前在 fastboot，未结「卡 ZUXOS 动画」**
   - **已做成（有判据）**：清 `boot_a` UNBOOTABLE（`fastboot --set-active=a`：`yes→no`、retry `6→7`，实测坐实 #677）→ 刷回原厂 `boot_a` 起 Android；
     刷自签 `vbmeta_a_flags1`（`419e01ac…`，Flags=1）→ `ro.boot.veritymode=**disabled**`；**EDL 写 `super_min.img` 8.28 GiB @42.2 MiB/s，
     设备端 `qdl sha256` = 主机 sha（`e3d0d26f…`）→ 连续两发 `boot_completed=1`**；`/system` 从 11.43 GiB → **5.0 GiB**，
     `/system/preinstall`、`/system/etc/AI` 已不存在。
   - **未结**：`fastboot -w` 后 adbd 报 `Could not set SELinux context` 崩溃 → 用户在 recovery 做 factory reset → 联想 logo **~72 s**（正常值，#679）
     → **卡在 ZUXOS 动画**（>10 min）。当前槽属性 `a: unbootable=no/successful=yes/retry=6`（未被再标）。候选原因 =
     「`/data` 与删掉预装池的精简 system 不一致 / factory reset 触发 ZUI 重新格式化」，**尚未取证**。
   - **已登记的 4 条待办**（本次只记不做）：① 干净瘦身镜像（连桌面「预装占位」来源一起处理）；② **KernelSU 修补版 boot**（GKI LKM：magiskboot + `kernelsu.ko` + avbtool 重签）；
     ③ 卡动画取证（recovery logcat / ttyGS0）；④ 设备恢复可用。全账 = `TASKS/sessions/2026-11-18-安卓最小包上机成功与卡动画.md`。
   - 历史（11-17～11-18 上午）：11-17 20:0x 曾恢复原厂 Android 完整启动；11-18 上午「试装最小包 3 发全败」的真因 = `boot_a` 被标 UNBOOTABLE
     （#672），不是镜像问题——当天 19:0x 清标志后**一次通过**，该结论已闭环。`super`/`vbmeta` 回滚件与 GPT 双表 dump 见
     `backup/HA2EXB0E-16+512/edl-20261118/`、`out/edl-supermin-20261118/`。
   - **Linux 侧现状（不变）**：`linux17`/`eldenesp` 条目与槽镜像/ESP 已被原厂件覆盖，但 `linux17` 的 ext4 数据物理保留在 LBA `73277435`（192 GiB）；
     重建路径 = `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md`。取证/时间线 = `reports/bl-stuck-20261118-forensics.md` §7；自检 = `bash scripts/linux-state-audit.sh --host`。

1. **G1 = 36/37**（2026-11-17 脚本现查；`❌` 仅 `G1-10` 无 NFC 硬件、`G1-30` 与 G1-29 同路线）。**在机 ≠ vk192（2026-11-17 20:0x 起跑原厂 Android，见本节 0 条）**；`vk192` 现为**回退件**（`bootslot-b/boot_b.img` 自签 `06c081ca…`、空载件 `out/boot-elden-vk192.img` `bdf47f5f…`，UTS `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`）。
   以下为该版（2026-11-16）**历史判据**：slot `_b` Active/Successful/Bootable 全 1、重启实测回 vk192；模块树 1510 `.ko` 已按新 UTS 部署。
   判据全绿 = DSI `bound ae94000.dsi`+fb0 / WiFi `wlp1s0` UP / `/dev/fastrpc-adsp`+qrtr 400 / SensorProxy 三项 true / Waydroid+zramswap / **s2idle 3/3（fail=0）**。
   本版内容 = **pstore/ram 守卫**（拒绝与 initrd 重叠的 ramoops zone，上游已投 3×250）。→ `DEVICE/README.md` §1.1 首条、`reports/device-session-20261116-vk192.md`；
   前代 vk191（RAM 启动，kernel/dtb 同 vk190）沿革 → `reports/device-session-20261113-vk191.md`。
2. **G2 = 10/13**（Waydroid 主链 + 传感器/音频/GMS/马达/输入法/相机 STREAMING 都通）；**C3 Play Integrity 已实测收口（2026-11-15，SPIC v1.4.0 一次回包）**：`deviceRecognitionVerdict = []` ⇒ **BASIC/DEVICE/STRONG 三档全部不满足**，与书面判读（无 TEE、keymaster 软实现 ⇒ STRONG 结构性不可能）一致、未被推翻；PIF 伪装未做。剩 **C5 App 实开预览 / C8 立项 / C9 打分表**。→ `reports/c3-spic-verdict-20261115.md`、`reports/c3-pi-tiers-closeout-20261110.md`。
3. **G3 = Steam 登录界面 ✅**（2026-10-28 设备实测 3/3，截图判据 10-29 闭环），游戏端到端未做。→ `reports/g3-steam-20261028.md`。
4. **拓展：UEFI 两种形态都通**（2026-11-10 深夜定案：flashed 失败真根因 = 原厂 `dtbo_a` 的 Android DTBO 被 ABL 合进我们的 DTB，清 `dtbo_a` 即通；2026-11-14 夜第 2 轮间接形态也通，判据 = cmdline `androidboot.serialno=51318dc0` 且无 ABL 追加 token，14 s 到 SSH、零写盘）；Gunyah = 有条件重启、非主线。11-14 首轮复测的三次崩溃**不是固件问题**，是主机侧 USB 被隔壁项目 13 个孤儿 `fastboot` 抢走（`PITFALLS #658`）。
   **GRUB 路径断点已在 2026-11-15 夜定案**：Mu UEFI 把 initrd buffer 分配进 DTB 的 `ramoops@c2000000`（8 MB `no-map`），内核 `t=0.0269 s` 就把它注册成 printk 控制台 ⇒ 每行 console 写进那 8 MB ⇒ initrd 被内核自己覆盖 ⇒ 解包 ~120 ms `broken padding`；A/B 单变量（只删 ramoops 节点）= 起进 SSH 32 s、`sum=0x5c53688e` = 主机期望值。修法优先级 = 内核 `pstore/ram` 拒绝重叠 zone（可上游）> GRUB 先占位 > 挪 ramoops。→ `reports/uefi-dtbo-a-rootcause-20261110.md`、`reports/uefi-grub-initrd-rootcause-20261115.md`（§5 另列两条修法）、复现件 `patches/local/uefi-initrd-probe-20261115/`、`PITFALLS #665/#666`、`TASKS` §5 沿革索引「2026-11-10 / 11-15」行。
5. **桌面层两回归已闭环（2026-11-14 晚）**：**T20 电源键短按不熄屏**根因 = `zwlr_output_power_v1` 每屏只许一个请求者，phosh 的第二个请求被 `send_failed` 且资源被销毁 ⇒ `power_mode` 停在 `OFF` ⇒ 屏保管理器 `active` 恒 TRUE、press/release 双短路；修 = phoc（wlroots 放行多请求者）+ phosh（failed 回退为 ON）两枚自编件，已上机验收（短按熄屏/再按亮屏、长按菜单正常）。**T19 撕裂**仍停在「根因层 = 带 modifier 的 dmabuf 导入已锁定、缺 mesa 26.2.5 A/B」。
   → `TASKS/sessions/2026-11-14-T20-电源键不熄屏.md` §7、`PITFALLS` #371、`scripts/{phoc,phosh}-install.sh`
6. **上游**（2026-11-17 更新）：**mdss v5 已发**（答 sashiko `0xa000` 独立域质疑，3/3 只收窄 message）、**wl2868c v11 已发**、**dsi/phy v2 已发**（11-16 22:50/23:03 两发 `250`；`/linux-arm-msm/`+`/linux-kernel/`+`/dri-devel/` 三处归档、正文字节一致；错前缀那封由第二封自述）；dwc3 v9 / gamma v2 / haptics v2 / board DTS 单提交 = **备料在档、等批准**；**唯一在档未发 = Q28 证据回帖**（已修「折行 Cc 会漏发 5 人」）。→ `reports/upstream-status-20261113.md`、`TASKS` §7。
   **★2026-11-17 联网核查（子代理，全账 `reports/upstream-replies-20261117.md`）**：在飞 4 系列**只有 1 个收到人回** = wl2868c v11（Rob 11-16 15:10 UTC：**v11 漏带他的 R-b** ⇒ 下一版补 tag）；pstore v1 / dsi-phy v2 / mdss v5 **零人回**。
   另有两封改变前提的信：① **Bryan 对我方 camss CSIPHY RFC 回信（11-15 17:44 UTC）** —— 先基于 on-list 的 Hangxiang **v25**/Qualcomm **v7** 工作，并直言我方邮件「LLM output…干难懂」；② **`qcom,nsessions` 已于 11-16 被上游合入废弃**（`641dd7dd0f68`）。我方相关主线合入 = 0；同家族上一代 Kaanapali PHY 3 枚已进 phy-next。
   **★2026-11-17 12:17 Q28 证据回帖已发（用户放行）**：`Message-ID <179488903160.260870.8168848839719897744@mail.ustc.edu.cn>`，`/linux-arm-msm/`+`/dri-devel/`+`/lkml/` 三处归档、正文逐字节相同（`sha256 4fe84148…`）⇒ **在档未发件已清零**；下一批 = 6 个待发系列（含新增 `wl2868c v12`）。

**卡什么**

- **⛔ 卡什么 = Linux 侧归零，不是设备坏（2026-11-17 20:0x 起设备已回原厂 Android 16；21:4x adb 在线复核见下）**：`linux17`/`eldenesp` GPT 条目与槽镜像都已被原厂件覆盖，**只有 `linux17` 的 ext4 数据物理保留在 LBA `73277435`（192 GiB，位于现 `userdata` 区间内，未被 mkfs 覆盖前可救）** ⇒ 下一步 = `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` §3 S3a（先重建条目、**不格式化**）→ S4/S5/S6；**需 C1 放行（S3a 保数据 vs GPT-minimal 重装）**。
  **2026-11-17 21:4x 只读复核（`SN=HA2EXB0E bash scripts/linux-state-audit.sh --device`，未写盘；快照 `reports/artifacts/linux-state-20261118/audit.tsv`）**：`DRIFT = 设备上无 linux17/eldenesp`、`F.rootfs 缺失（库里无全量 rootfs 归档）`、`/lib/modules 目录数 = 0`；adb `HA2EXB0E` 在线、`sys.boot_completed=1`、slot `_a`、`uname -r 6.6.118-android15`、`/data` 450 G（用 6.3 G）。
  **★2026-11-17 22:0x 路线已定（用户放行：走重装最小化 + 可进 EDL）=「GPT-minimal 重装 + EDL 直写」**（不再走 S3a 保数据）：① **P0 已做**（EDL 只读 dump 六 LUN 主备表 → `backup/HA2EXB0E-16+512/edl-20261118/`，12 文件 + `SHA256SUMS.txt`；主备表条目逐字节相等、头/条目 CRC 全 OK）；② **两张最小表已生成且自检通过**（`out/gpt-minimal-20261118/lun0_{main0,backup0}.bin` = 10 项 / `linux` LBA 90504..123871226 = 472.19 GiB；`lun4_{main4,backup4}.bin` = 74 项，删 `init_boot_a/b`+`vendor_boot_a/b`）；③ ✅ **2026-11-18 11:29 最小 rootfs ext4 镜像已出**（`out/p2-minbase-20261118/…`（**已归档** 2026-11-21，`versions/out-artifacts.tsv` 行 15）：`backup/out-history-20261121/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img`（**2026-11-21 现查：镜像本体未随归档，该目录只有同名 `.sha256` 清单 + `boot-minbase-labellinux.img`**，见 `versions/out-artifacts.tsv` 行 15）：6 GiB 稀疏/实占 2.1 G、label=`linux`、160 包、1510 个 `.ko`、44 M 固件、15 项门禁全绿、sha256 `d22c6a00…`；构建器 = `scripts/rootfs-minbase-build.sh`（`podman`/`proot` 路线实测不行，必须真 root））+ boot 件 `backup/out-history-20261121/p2-minbase-20261118/boot-minbase-labellinux.img`（cmdline `elden_root=LABEL=linux`，sha `7ea9370b…`）；**⇒ P2 前置件已齐，卡在 C2（写盘批准）**，然后 P1（写 LUN0 表）→ P2（`qdl write 0/90504 <ext4.img>` → 上台 `resize2fs` → 刷 `boot_b`/`dtbo_dummy`/`vbmeta_b` → 冷起验 `findmnt /` = `LABEL=linux` + ssh 通）→ P3（LUN4 表）→ P4（`mark-successful b`）。
  ⚠️ **回退口径已改（2026-11-18）**：不再写「删条目 ≠ 删数据」——`linux` 起点 LBA 90504 = 原 `super` 起点，P2 的头 6 GiB 会覆盖 `super` ⇒ **P2 之后 Android a 槽不再可起**，真回退 = 写回旧表 **+ 重刷官方 `super`**（`backup/official-rom-15.10.259`，~20 min，11-17 已实测走通）。→ `RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md` §4 P2 行。
  **★历史（18:5x 定性降级，已被 20:0x T1/T2 推翻，留档防回流）**：真因 = **非原厂 GPT**（LUN0 条目名 + LUN4 槽属性），只写 88 KiB GPT 即恢复；「硬件类唯一存活解释」与送修单均作废（佐证 `#482`/`#486` 的判读错误）。全账 = `reports/bl-stuck-20261118-forensics.md` §7；历史案例 10 例 / 决策树 = `reports/bl-history-and-playbook.md`；回退件清单 = `DEVICE/README.md` §1.1 首条。
  > **作废（2026-11-19）：上句的「送修单」已整体标作废，设备不需要送修也不需要换主板** —— `DEVICE/service-repair-note-20261117.md` 顶部已写 `⛔ 作废（2026-11-19）` 抬头；
  > 新旧口径对照 + 在线判定 + 上机计划 = `reports/device-status-20261119.md`；上机判据 = `DEVICE/README.md` §1.6。
- **camss：delta 已按 Bryan 要求重基完成（2026-11-17 下午），只差一次上机出流回归**：本机 vendor `camera.ko` CSIPHY = **2.4.0**（地址 103/103 同、13 个 data 字节不同）。**v2 = `patches/upstream/camss-csiphy-24-v2-20261117/`（2 枚，基线 = 7.4-rc3 + kaanapali v25 `[01..03]` 前缀），6 道门全绿**（apply / checkpatch **0E0W0C** / `W=1` / `dt_binding_check` / 表 **13-13** 且与 vendor **103-103** 全等 / `git am` 2-2）。关键新事实：v25 `[03/15]` 的 `mipi_csi2_dphy_3nm_kaanapali` **复用 `lane_regs_x1e80100[]`（4nm v2.1.2 表）**，而 Qualcomm 自己的 SM8750 CAMSS v6 `[4/7]` 指向 `csiphy_res_kaanapali`（subject 写 **v2.3.0**），v2.3.0 与 2.4.0 的 18 张 2ph 表逐字节同值 ⇒ 上游现用值与 Qualcomm 两处口径都不一致（只写 cover 提问段，不替 Kaanapali 下结论）。**剩 = ① 一次上机出流回归（或 cover 声明无实测，需用户裁决）；② 投前再看 `SM8750 CAMSS v6 1/7` 是否已进 tree（进则删本系列 binding 那枚）**。→ `reports/camss-v25-rebase-20261117.md`、`reports/camss-csiphy-v6-vs-240-20261113.md`、`reports/upstream-replies-20261117.md` §3.1、`PITFALLS #648`。
- **fastrpc**：`qcom,nsessions` **上游已废弃并合入**（`641dd7dd0f68`）⇒ 倒过来变成我们的欠账：板级 DTS 里若还写该属性就要按驱动侧策略删除/改写；`accel/qda` 仍 v4（未合、无 v5）。
- **T14/T17 用户态固化**：S3+S4+S6 离线复核已过，**唯一缺口 = `hapticd` 二进制不可重建**（自家 ELF，chroot 步骤已闭合）。→ `reports/t14-s3s4s6-offline-verify-20261114.md`。
- **T9 待机**：改成间接采样（设备 timer 30 min 追加 `/var/lib/elden/suspend-resource.tsv`），**要 1–2 天数据才能判**，取数是人的动作。→ `TASKS` §4 T9、`PITFALLS #651`。
- **已结项、勿重推**：Q28/Q32 =「已规避」（运营线 8/8 无坏发）、Q24 = 根因指名（7.2 缺 `skip retention by default`）、Gunyah = 非主线、`#106` = 历史记录（2026-10 之后无复现样本，未取证）。

**下一步（按顺序）**

1. **camss CSIPHY**：① 重基 **已完成（2026-11-17 下午，v2 = `patches/upstream/camss-csiphy-24-v2-20261117/`，基线 = v25 `[01..03]` 前缀，6 道门全绿）**；② **剩**一次上机出流回归（`s5kjns`/`gc08a8` 30 fps）——未做前不发信/不发补丁；③ **★2026-11-18 复核：暂不投** —— Qualcomm 11-14 发 `Add CAMSS support for SM8750 and Eliza` **v7（23 枚）**，把我方 `0001` binding 与 `0002` cfg 都做掉了（Krzysztof 已判「应 squash 依赖」）⇒ 等 v8 落地再定形状（预期：`0001` 删、`0002` 收敛为 `.data` 指向 2.4.0 表的一处改动）。→ `reports/camss-v25-rebase-20261117.md`、`reports/upstream-delta-20261118.md` §2.1。
2. **上游待批准批次**（**2026-11-16 已对 mainline **7.4-rc3 final `aebb727447` 全部重跑顺序 apply**，详见 `reports/artifacts/apply-check-7.4rc3-20261116/`）：
   `board DTS` 单枚 / `dwc3 v9` 4 枚 / ~~`m8-mdss v4` 3 枚~~（**v5 已于 11-14 投出** ⇒ 剩「等回复」，见上第 6 条与本文件 §0-6；v5 与 v4 diff 只差 3/3 message，apply 结论沿用） / `dpu-gamma v2` 1 枚 / `m6-dsi-pll v2` 1 枚 / `haptics v2` 6 枚（**本轮已 rebase 0006** —— 去掉只存在于 linux-next 的 `interrupt.h` 上下文行，6/6 rc=0）—— **均 rc=0，逐系列等用户放行**；
   **新增待放行（2026-11-17）**：`wl2868c v12` = v11 原样 + 在 1/2 trailer 补回 Rob 的 `Reviewed-by`（他已重给）；
   **★2026-11-17 13:20 整批已发（用户放行）**：板 DTS **v7**（单提交）/ dpu-gamma **v2** / dsi-phy muxes **v2（m6 件）** / haptics **v2**（6+cover）/ dwc3 **v9 3 枚**（`0004` 板 DTS 暂 hold，因改尚未上游的板文件）/ wl2868c **v12**（补回 Rob 的 R-b）= **17 封全 `Result: 250`**，
   逐 MID 在 `linux-arm-msm` / `linux-devicetree` / `dri-devel` / `linux-input` / `linux-usb` / `lkml` 全部命中（每系列 `SENT.md` 有 MID 清单）。
   **已投的不再在列**：`dsi-phy v2`（11-16 两发 250）、`wl2868c v11`、`mdss v5`、Q28 证据回帖（11-17 12:17）；
   **卡源**：`dispcc-reset-v2` 与 `m8-mdss v4` 内容重复（发 v4）；`camss 2.4.0 delta` **已重基为 v2（`patches/upstream/camss-csiphy-24-v2-20261117/`，6 门全绿）**，停在「缺一次上机出流回归」（见上条）。
3. **设备窗口才做**：A10 两发（`set_active a` 或物理 POR）、B6/B18 需先建树出镜像。
4. **中文输入法候选窗：配置层已全绿（2026-11-15 T1–T5 全做，`scripts/ime-candidates-check.sh` = 11 PASS / 0 FAIL）**；**行为层未验** —— 画候选的那一半（`elden-ime-candidates.py`）仍按 #646 撤下，重做要求见 `PITFALLS #646` + 前置条件 `LD_PRELOAD=libgtk4-layer-shell.so.0`。→ `TASKS/sessions/2026-11-15-IME候选回归台账.md` §3b/§3c
5. **UEFI GRUB 路径：取证已完成（2026-11-15 夜）；修法 ① 已成可上游 2 枚系列并全绿备料**（内核 `initrd_phys_range()` + `ramoops_probe()` 逐 zone 判重叠，重叠段 `dev_warn` 跳过、四段全跳 → `-ENODEV` 干净退出；门禁 = `gh/master` apply-check 2/2 + checkpatch 0 error + 构建 0 error/0 warning + QEMU 两发 A/B）。**2026-11-16 真机已验**：`set_active a` → Mu UEFI → 嵌入菜单 GRUB → 64 MB initrd `0xc1ab0000-0xc584a5e0` 整段盖住 ramoops ⇒ dmesg 三段 zone 逐条 `ignoring … overlaps the initrd`，60 s 进 SSH；同日无守卫内核对照 = 黑屏 → 20 s 关机 → 回落 b 槽 ⇒ 真机有/无对照成立。14:03 ESP 归位（日常嵌入菜单 `f5dcf599…`）+ a 槽暖启 44 s + POR 冷启菜单正常；该轮另修 `q28-boot-watchdog` 只认 `card0` 的误判（`PITFALLS #667`）。
   **已发 2026-11-16 12:00:49（USTC）**：To Kees/Tony/Guilherme，Cc lkml + linux-arm-msm，3 × 250，线程根 `20261116040049.434247-1-xiaqinghuan@mail.ustc.edu.cn`，**等回复**；树 = `build/daily` `v7.3.1-5-g4bdf1711b5`（未打 vk 号、未进版本账；**该树已于 2026-11-19 磁盘清理删除**，版本标识以本行文字为准，影响见 `reports/disk-cleanup-20261119-validation-impact.md`）。→ `patches/upstream/pstore-ram-initrd-overlap-20261116/`（README + 0000 cover + 2 枚 + `logs/`（含 `40-sent.txt`））、`reports/pstore-ram-initrd-guard-20261116.md` §5、评审 `reports/pstore-ram-initrd-review-20261116.md`、`scripts/qemu-ramoops-initrd-ab.sh`、真机件 `reports/artifacts/uefi-pstoreguard-20261116/`、`reports/artifacts/uefi-daily-v8-20261116/`、`PITFALLS #666`。
6. ~~**LastFile2 打印版（v2）缺屏上取证**~~ **→ 已撤销（2026-11-16，不需再拍）**：v2（`b9fb14cb…`）只是把同一测量改成「只打印不写盘」的通道变体，不产生新判据——「LoadFile2 fill 后 64 MB 内容正确」已由 v1 grubenv 侧证（`lf2_addr=0xc23e0000 / len=64595425 / sum=0x5c53688e`）与 11-16 真机守卫臂双重覆盖。件留 ESP（`.lf2v2.bak`）与 `out/`，不再列入待办。→ `reports/uefi-grub-initrd-rootcause-20261115.md`。
7. **T9 取数**：`scp elden-root:/var/lib/elden/suspend-resource.tsv .` 后按同一 boot ≥3 周期看趋势。
8. **磁盘 A 类清理已执行完（2026-11-16）**：两轮共释放 **15.25 GiB**（项目 91 G → 76 G；A1–A14 无失败项，第二轮 = `stock-src`、`dl-cam/ndk`、`out/r21-sbstop-{p69,pc2}`、`out/mu-memmap-20261115`、`out/{espboot-20261108,espboot-20261110,fbdiag-20261108,dbg-uefi-initrd-20261115}`、`y700四代工具`）。三项评估 = `backup/official-rom` super 15 G **可压不可删**（脚本零引用、净省 ~6 G，需同轮改引用行）、`backup/out-history` 8.13 G **无可删**（114 个 .img 全被 `versions/*.tsv` 引用）、`.pi/sessions`+`reports/artifacts` **建议保留**。→ `reports/disk-cleanup-20261115.md` §2（执行记录 + 复核命令）。
9. **主机侧待办已对账到 2026-11-17（子代理）**：`reports/todo-inventory-20261113.md` 的 72 条 → `reports/todo-reconcile-20261117.md`（17 已闭环 / 9 已作废 / **6 条主机侧可做** / 25 需设备窗口 / 15 需用户批准）。主机侧 6 条按价值 = B14 T14 重建 recipe、B15 Gunyah 两空、B13 脚本欠账、B18 libcamera 闪光灯、C-I12、B17 分诊盲区（合计 ~10–13 h）。文档/工件卫生 = `reports/doc-hygiene-20261117.md`。
10. **2026-11-18 主机侧 lane（只读，未改 SSOT 的 5 份报告已入库；本轮结论已并进本节）**：**单一可执行清单 = `reports/todo-next-20261118.md`**（A 主机 11 条 / B 设备 12 条 / C 待批准 11 条 / D 已作废 15 条；价值序首位 = dwc3 v10 + haptics v3 答 sashiko 的 2×High+1×High）。其余 = `reports/progress-audit-20261118.md`（数字三方一致 36/37·10/13；9 处文档滞后已同轮改完）、`reports/mail-inbox-20261118.md`（11-14 后人类回帖 2 封、bot 8 封；`read-mail-ustc.py --replies-only` 判据失效待修）、`reports/upstream-delta-20261118.md`（**camss v2 暂不投**：Qualcomm 11-14 v7 23 枚已做掉我方 0001/0002 形状，等 v8；dwc3/haptics 重基目标换 `refs/heads/master`）、`reports/doc-slim-plan-20261118.md`（可净减 ~44 KB，**第一刀 C1–C8 已于 2026-11-19 执行完**（C9 = PITFALLS 索引行合并，判「收益 < 风险」不做））。孤儿报告补指针：`reports/stale-cleanup-b-docs-20261119.md`（check-doctor §13 曾报无人引用）。

**怎么核实本节没漂**（开工前先跑，见 `.pi/AGENT-OPS.md` §0）

```sh
scripts/recent-sessions.sh 3          # 最近 3 轮会话的收尾结论（正文在 .pi/sessions/*.jsonl）
scripts/check-progress-counts.sh --tsv   # G1/G2 完成度现查
sed -n '/### 1.1/,/### 1.2/p' DEVICE/README.md | head -20   # 在机内核/槽位/判据
scripts/check-doctor.sh --only 15      # §15：本节「核对日期」是否落后于最新会话证据
```

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
4. **状态数字只改一处**：`TASKS/README.md` §0（总览）/ §5（Q 行）。其它任何地方**不写状态数字**，只写指针。
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
| 4 | **`TASKS/README.md`** §0 / §4 / §5 / §7 | 状态数字与台账的唯一出处 |
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

### 顶层布局（4 区 + AI 大脑；**逐项 = 机器表**）

> **机器真源 = `versions/layout.tsv`**（人读 `scripts/check-layout.sh --list`），门 = `check-layout.sh`（`check-doctor.sh` §14：
> **每条路径必须在本节出现且磁盘存在**）。规则：**根目录新增条目先登记 `versions/layout.tsv`**，未登记即 FAIL。
> 本节只回答「这个目录能不能删、要不要入库」的**分区级**口径；逐条职责/删除风险读 `RESOURCES/README.md` §3。

| 区 | 顶层条目（与 `layout.tsv` 同源） | 版本控制 |
|---|---|---|
| 入口 | `AGENTS.md` `INDEX.md` `README.md` `PROGRESS.md` `LICENSE` | track |
| 角度文档 | `DEVICE/` `TASKS/` `RESOURCES/` `RUNBOOK-BRINGUP/` `PITFALLS/` `SESSIONS/` `HISTORY/` `archive/` | track |
| 源码/补丁/工具 | `scripts/` `tools/` `patches/` `patches-userland/` `reference/` `versions/` `packaging/` `initramfs/` `rootfs/` `probes/` `net/` `waydroid-ota/` `restore-259/` `cycle.sh` `elden-net.sh` `.githooks/` `.gitignore` | track |
| 证据/备份 | `reports/`（md 入库，大件 ignore）· `backup/`（**不可再生**：删前必须云盘或 bundle 兜底）· `assets/`（原厂安卓资产提取树，2026-11-19 起；专有、仅本机用、不入库，脚本可重建） | track / ignore |
| 工作区（**可再生成**） | `build/` `out/` `logs/` `runs/` `bootslot-b/` `env-pass/` `dl-cam/` `wt/` `external/` `geekidos-linux/` `Y700-elden-linux/` + 软链 `linux` | ignore（`build/` 删前先 bundle + 导 diff；`runs/` = lane 实跑回执工作区，2026-11-20 起） |
| ↳ **2026-11-19 现状** | `build/` 的内核树与 `geekidos-linux/`＋软链 `linux` **已被磁盘清理删除**（`build/` 只剩 phoc/phosh 源码）；重建命令见 `versions/layout.tsv` 表头注释，影响与处置 = `reports/disk-cleanup-20261119-validation-impact.md` | — |
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
  顶层布局真源 = **`versions/layout.tsv`**（项数现查 `scripts/check-layout.sh --list | wc -l`；4 区：入口/文档 · 源码/补丁 · 证据/备份 · 工作区；人读面 = 本节「顶层布局」表，门 = `scripts/check-layout.sh`）。
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
| 任务台账 / 未解（Q 表）/ 待办 / 上游化（M 系列） | `TASKS/README.md` §1–§2 / §5 / §4 / §7 |
| 上游投递现状（当前一页） | `reports/upstream-status-20261113.md` |
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
