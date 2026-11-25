# 下一批任务书（2026-11-26 整理）

> ★执行状态 checkpoint（2026-11-26 23:1x，主会话落盘）：
> - 已完成：20+3 提交双远端推送清零；dwc3 v16 已投（4×250，lore 命中，`patches/upstream/dwc3-v16-20261125/SENT.md`）；投递全面放行+提交推送绑定已入册（`TASKS §7` / `.pi/AGENT-OPS.md §3`）；droidloom-base 903 MB 验证入账（sha `reports/artifacts/droidloom-base-0.1.0-49.sha256`）；rayburst hang 取证报告入库（TASKS 新 D20 行）；D6③ 文档下沉完成（−16 KB，7 个 session 文件，check-doctor FAIL=0）。
> - 在跑 lane（workflow a1c02737-9bc9-44ff-954d-ceec7c1a9555）：① comm-triage（mail-io/ustc-dsf，run ed015237）② droidloom-deb（impl-worker/ustc-dsf2，run cf033857）③ device-s2idle（physical-exec/ustc-dsf，run 9dc7c4d6，设备独占）——各自产出见 lane 内 task；完成由主会话复核（规则 7）后统一 commit+push。
> - 未派：B5 APSS watchdog 静态复核（下一 cohort）、C3 键盘 GUI 遗留 UI（设备空闲窗）、C1 上机（等 B5）。
> - git：检查点同轮提交推送，领先=0。

> ★晨批 checkpoint（2026-11-26 06:0x–06:5xCST，新会话）：
> - **应用户要求派的 4 lane 全部完成并已独立复核**（规则 7：关键数字我亲自重跑）：
>   ① **lane G gunyah** → `reports/gunyah-lane-20261126.md`（子 VM 已结项、gunyah_wdt 早已在主线无上游化空间、素材在但移植树已删）；台账新增 **D21**。
>   ② **lane S 传感器说法核实** → `reports/sensor-claim-verify-20261126.md`（内核/DTB/fastrpc/QRTR 四层健康，缺口全在 Debian 用户态；**svc 400 在 hexagonrpcd mask 下已注册** ⇒ 可绕 #692 验出数）；台账新增 **D22**。
>   ③ **lane M B4 通信复扫** → `reports/comm-triage-20261126.md`（dwc3 v16 sashiko 全绿；elden DTS v8 有 Krzysztof 意见需回应；**IMAP 与 phosh API 因 keyring 锁无法核验，已如实记录错误码**）。
>   ④ **lane W B5 APSS watchdog 静态复核** → `reports/b5-apss-wdt-static-review-20261126.md`（基址 `0x16410000` 可信中等偏强，无 reserved-memory 冲突，上机判据清单已出）；D19 行已回填。
> - **B1 droidloom deb 收尾（自做，已提交推送 `315f482f`）**：runtime 补 `libwayland-server0` 依赖（三个 host 二进制 ELF NEEDED 实证）+ `build.sh` 交叉 sysroot 绝对化（PITFALLS **#730**）；amd64/arm64 **双架构重建**，sha 入账 `reports/artifacts/droidloom-deb-20261126.sha256`。
> - **需用户**：① GDM 停在登录界面 ⇒ keyring 锁定 ⇒ IMAP/phosh token 取不出（解锁图形会话即可）② 传感器步骤 C（纯用户态 libssc 验 SSC 出数）需放行（无串口/ramoops 取证通道）。
> - 未派/未做：C2 s2idle 日常化（需设备窗）、C1 APSS wdt 上机（待判据执行）、D16 传感器 unit 接回。
> 来源：TASKS §4.0 维度表（2026-11-25 深夜口径）+ 最近 3 轮会话结论 + `reports/upstream-status-20261125.md` / `reports/dwc3-v16-20261125.md`。
> 本文件只做整理与派发计划，不执行。设备锁串行、主机侧并行；投递类一律逐次等用户放行。

## 0. 进度速览（数字）

- **G1 36/37**（仅上游化 M 系列在飞）；**G2 10/13**（C5 剩 App 预览、C8、C9）；**G3** PoC+Steam 登录 ✅；UEFI 两形态通。
- 上游化：**1 系列已进树**（wl2868c → regulator for-7.5，项目首件）；**7 个在飞等回信**（dwc3 v15/等 v16、M8、M10、M11、aw86927 v4、M2 A2、phosh !2005）；**2 个已作废**（M12 被上游覆盖、camss csiphy 2.4.0 降级 delta）。
- 工作区 clean，check-doctor FAIL=0 / WARN=3（存量豁免）；git 领先 github/main 20（**待推送**）。
- 昨日亮点：s2idle 首闭环 ✅、M12 上机 A/B 终局验证 ✅、droidloom x86 编译通过、D13 边缘侧滑常驻化 ✅、D19 无人值守闭环 ✅（gunyah_wdt 已否）。

## 1. 待办分类清单（★2026-11-26 更新：去重后；投递类已全面放行，见 `TASKS/README.md` §7 投递口径）

### A. 等用户（2026-11-26 更新：投递全面放行，A1/A2 已消项）
| # | 事项 | 说明 |
|---|---|---|
| ~~A1~~ | ~~dwc3 v16 投递放行~~ | **2026-11-26 全面放行** ⇒ 转入 B 组执行（发信 + lore 复核） |
| ~~A2~~ | ~~elden 板 DTS v8 放行~~ | **已于 2026-11-25T09:13Z 投出**（3×250，cover `20261125091309.124354-1`），等评审；Pengyu trailer 形式（Co-developed-by）不代签 |
| A3 | **IMAP 存储层冻结**（11-25T03:44Z 起 INBOX/Junk/Sent 无新件） | 需用户核配额/反垃圾/服务端 |
| A4 | M8/M10 死地址补发后的回信放行 | 已换现址补发（11-25T02:23Z），无需再动作，除非又退信 |
| A5 | D1 plymouth 关机蓝字 mask 拍板 | `systemctl mask plymouth-reboot plymouth-halt plymouth-poweroff`（`reports/shutdown-console-spam-20261125.md`） |
| A6 | D15① 「每次测试拉起新 Firefox 窗」具体动作 | 问清是哪个测试命令 |
| ~~A7~~ | ~~git 领先 20 提交~~ | **已推送（2026-11-26，4 批 × github+origin）**；此后提交+推送绑定（`.pi/AGENT-OPS.md` §3 新硬规则） |

### B. 主机侧（零设备，可立即派子代理）
| # | 工单 | 产出/验收 | 模型建议 |
|---|---|---|---|
| B1 | **droidloom deb 化**：照 Fedora spec（`fork/fedora-rpm-packaging`）写 `packaging/debian/` + 构建脚本；aarch64 交叉缺 wayland-server:arm64 待解 | `droidloom*.deb` 可 `dpkg -i` 干跑通过；aarch64 交叉编译通路打通或列明缺件 | custom.ustc-pool/ustc-dsf |
| B2 | **droidloom-base 903 MB 包重下**：断点续传，落地必须 `zstd -t`（PITFALLS 会话 362 口径） | sha256 入账 `~/apk-20261125/MANIFEST.md` 同款账 | 可并入 B1 |
| B3 | **D6③ 文档下沉**：TASKS §5 Q 表沿革与 §7 增量块下沉到 `TASKS/sessions/`（体积收益 `du` 现算；只挪不改语义；下沉后 `check-doctor` FAIL=0） | 各文件瘦身 + 指针保留 | custom.ustc-pool/ustc-dsf2 |
| B4 | **D10 常设通信复扫**（每轮必派，只读）：INBOX 增量 + lore/patchwork（内容级判定）+ Mobian/phosh MR 状态；重点盯 dwc3 v15/v16、M8/M10 补发回执、M11 ping 回音、aw86927 v4、phosh !2005 | `reports/comm-triage-20261126.md`；只读不改 | custom.ustc-pool/ustc-dsf |
| B5 | **APSS watchdog 备料复核**：`patches/local/apss-wdt-20261125/` 双推基址 0x16410000 的静态复核（同族 SoC dtsi 对表 + vendor DTB 保护区核对），为上机读回做准备 | 复核备忘 + 上机判据清单（写内存→读回→KEEPALIVE→真复位路径） | custom.ustc-pool/ustc-dsf2 |

### C. 设备窗（串行，一次窗排一批）
| # | 工单 | 判据 | 依赖 |
|---|---|---|---|
| C1 | **APSS watchdog 上机读回验证**（D19 遗留头号）：`0x16410000` 节点 + 补丁，零写盘 `fastboot boot`；看 `/dev/watchdog0`、SETTIMEOUT/GETTIMELEFT 非 0、停喂真复位 | hang 类实验可进无人循环（autotest-cycle.sh） | B5 |
| C2 | **s2idle 日常化**：电源键短按=挂起（logind suspend 而非 shutdown），5 min 驻留验收；顺带 `cam-mode.sh off` 日常化 + `wifi-scan-refresh` 150→170 s（D11 三条零风险项） | `suspend_stats success 递增/fail=0`，唤醒后 DSI/WiFi/触控全好 | 无 |
| C3 | **D18 遗留**：osk-sound v2 已用户确认 ✅；剩「换引擎细化参数提示文案」「Terminal shortcuts 功能键」UI 项（后者要重编 gresource，可选） | 截图 + `deploy-desktop-shell.sh --check` MISS=0 | 无 |
| C4 | **D16 解耦项**：hexagonrpcd masked（#692 硬崩）→ 传感器线（加速度计/自动旋转）在串口/ramoops 取证通道建好后再解；本轮只确认 mask 状态未漂 | 只读核 | #692 未解 |
| C5 | **D7 低优先**：UEFI flashed 形态复现、`boot_a` 冷起回归（非主线，排最末） | 见 §4.0 D7 行 | 空闲窗 |

### D. 需人手（真人判读/物理）
- D3①b 长句连续选词；D13 真人真机左/右边缘侧滑验收各一次 + OSK 弹出时边缘滑动不误触；D11 灭屏态体感确认。
- 物理 POR：现无待取样本。

## 2. 互斥与依赖

- C1/C2/C3/C4 共用设备窗，**分时串行**；建议顺序 C2 → C3 → C1（C1 失败可回退 reboot，不碰日常核）。
- B1–B5 全并行（B4 与其它无文件交集）。
- dwc3 v16 投递（A1）若放行，放行前 B4 口径按「v15 在飞」。

## 3. 收尾门

每轮：`check-doctor` FAIL=0 + WARN 归类；产物落 `reports/`+台账回填 TASKS §4.0/§7；工作区 clean；设备回安全态（vk189 在机、充电中、无残留实验内核）。

## 用户回座后三件事（2026-11-26 07:5x 落盘；每件都已备成一条命令）

1. **解锁图形会话（GDM 登录）** —— 一次解锁同时解开三件被 keyring 挡住的活：
   - IMAP 收件侧复扫（`reports/comm-triage-20261126.md` 里 A/J 行记的是 `KeyringLocked`）
   - phosh !2005 现查（GitLab API 406 + CAPTCHA，token 在 keyring）
   - **elden 板 DTS v9 投递**：`cd patches/upstream/elden-dts-v9-20261126 && bash SEND.sh --send`
     （本地六段断言 + `--dry-run` 3 封 `Result: OK` 已过；发完记 `SENT.md` + lore 复核）
2. **放行传感器上机**（唯一可能硬崩的步骤，脚本已备）：
   `bash scripts/deploy-ssc-sensors.sh --from-debian`（装 libssc2/libssc-bin/iio-sensor-proxy 3.9 + udev 规则 + pin/hold；
   不碰 `hexagonrpcd*`）→ 再跑 `--check` 看 15 项矩阵；回退 `--rollback`。
   前置建议（非必须）：先把串口/ramoops 取证通道建好，因 `/dev/ttyACM0` 是 USB gadget、硬崩会连证据一起没。
3. **C2 电源日常化**（需人按键）：电源键短按 = 挂起（s2idle 已闭环），顺带 `cam-mode.sh off` 日常化 + `wifi-scan-refresh` 150→170 s。
