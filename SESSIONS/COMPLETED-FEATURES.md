# COMPLETED-FEATURES — 已完成子功能合并账（结论 ↔ 会话档案 ↔ git 提交）

> **用途**：把「已完成的子功能」各自的散落描述（会话档案 / 各角度 README / PITFALLS / TASKS）收敛到**一行一处**，并绑定对应 git 提交，减少重复登记。
> **口径**：一行 = 一个已完成子系统。`关键提交` 默认指**本仓库**提交（docs/scripts）；标 **(内核)** 者为内核树提交（不在本仓库，见 `TASKS/README.md` §7）。
> **状态/样本数 SSOT** 仍是 `../TASKS/README.md` §0/§5；本文件只做**合并索引**，不维护数字。
> **生成**：2026-10-14 整理（源：`SESSIONS/README.md` §3 快照 + `HISTORY/days/*.md` + `PITFALLS/`）；新增完成项时手工增补。

| 子系统 | 结论一句话 | 会话档案 | 关键提交 | 权威描述处 |
|---|---|---|---|---|
| 引导链 / 持久根 | b 槽 mainline 直启 + GPT 缩容（linux17=193 GiB）+ 自签 AVB 直启 Linux | `2026-09-29-持久根-b槽直启+gpt手术+睡眠.md`、`2026-10-03-持久根-u2上机与gpt手术.md` | `cbe9525` `4383f79` `19674fc` `2419885` | TASKS §0(G1-1/2/3)、DEVICE §2.2/§2.5 |
| 刷机控制（G1-24） | PSCI SYSTEM_RESET2 vendor reset 落地，`reboot bootloader` 真进 fastboot；logind 关机假成功修复 | `2026-10-03-刷机控制+桌面-psci-reboot与elogind.md` | `94d6d7f` `c1c9744` `47c14aa` | TASKS G1-24、PITFALLS #88 |
| 显示 Q28（**未解**） | 面板首条 DCS `ff 20` 走 bonded 命令 DMA 引擎 hang，~50% 冷起坏发；七臂否证，未根因 | `2026-10-09-q28-密集取证-寄存器差分-+-好-坏基线.md`、`2026-10-10-q28-定案-…`、`2026-10-12-q28-七臂否证.md` | `b4616d5` `f80709d` `306a787` `e6f02f3` | TASKS §5 Q28（唯一当前口径） |
| 显示 Q31（M1-7.3 回归，**已解**） | 上游 revert `44784327815b` ⇒ `PLL_SYSTEM_MUXES=0xc0` 永不写；E1b 补 1 行点亮面板 | `2026-10-14-m1-显示回归定位与根因分析.md`、`2026-10-14-m1-73-baseline-consolidation.md` | `f863612`、`54dc4dd8fe` **(内核)** | TASKS §5 Q31 / §7 |
| WiFi ath12k（Q26 关） | 0001 ath12k MHI 超时 90s→3s + `ATH12K=m`，WiFi 打通 | `2026-09-30-wifi-bt-驱动支持与充电旁路.md` | `4b8874f` `f42eca2` `6ed9666` | DEVICE §1.2、TASKS §5 Q26 |
| 音频 tplg（G1-4） | tplg MI2S SD0→SD1（功放接 i2s1_data1）⇒ 出声；WCD939x 采集 ⇒ 录音 | `2026-10-03-复盘-logind-关机-+-音频-温控重落与出声.md`、`2026-10-04-会话-音频收尾.md` | `31cde62` `cddb1ca` `3fd112c` `11f06ac` | TASKS G1-4、DEVICE §1.2 |
| 触觉 aw86927 | AW86937 固件超 4KB 被写死窗口拒 → 按型号区分 SRAM 窗口，震动成功（vk19 干净基线） | `2026-09-30-触觉-aw86937-马达-sram-修复.md` | `3e84df3` `707c53e` `77daaf7` | DEVICE §1.2、PITFALLS §四 |
| Waydroid 马达透传（C10） | 容器 vibrator HAL→`aw86927` FF 桥 + 自编 AIDL V2 + 固化进 `vendor.img` + 强度档位 RRO | **无 §3 档案**（快照冻结后新增；内容见 PITFALLS §29/§30） | `536f77b` `a048d64` `2df5ca0` | TASKS C10、PITFALLS §29/§30 |
| 传感器 / 自动旋转（G1-34） | SSC/QRTR + iio-sensor-proxy 出 accel/prox/als/compass；开机时序竞态修并持久化 | `2026-10-09-g1-34-重力与自动旋转.md` | `44f464e` `1ec6143`、`5d01d3324` **(内核)** | TASKS G1-34、PITFALLS §16 |
| 相机（G1-5 / Q24） | dma-buf 补齐 + libcamera 软件 ISP + Snapshot 全通、180° 修正；熄屏×相机互斥（未根治） | `2026-10-04-会话-相机出流-+-kexec-定论-+-g1-22-初判.md`、`2026-10-07-相机-g1-5-完整收口.md`、`2026-10-09-相机-模块驱动收尾-…` | `99d49aa` `684196a` `c377ac2` `d8ba26d` `933b78d` | TASKS G1-5 / §5 Q24 |
| 温控分级 | 0010 thermal graded trips：CPU 四级 trip 落地 | `2026-10-02-温控-过热限频与并发限流.md` | `ee9ebfe` `5fcdc6f` | DEVICE §1.3、TASKS §1 |
| GPU（G1-8 基准） | Adreno 830 freedreno/Turnip 工作；vkmark ~25532、es2gears ~164 FPS | （散在 10-11 会话） | `fe2fb6c` `214e06b` | TASKS G1-8、DEVICE §1.3 |
| Waydroid 风控（C2/C3） | GMS 登录成功（人工验证）；Widevine 不存在（仅 ClearKey）⇒ L3 不可用；PI 前置不满足 | `2026-10-11-容器音频与-emulated-storage.md`（C2）；C3 仅报告 | `e6f02f3` `1a97ce5` `0600ba4` | TASKS C2/C3、`reports/c3-identity-drm-20261013.md` |
| 上游化 M1-7.3 | 7.3-rc7 重基树 + WCN 停滞修 + 显示 1 行修；基线分支 `m1-73/baseline` tip `c7da05b1d8` | `2026-10-13-m1-7.3-重基树上机-bringup.md`、`2026-10-14-m1-73-baseline-consolidation.md` | `2ce4dec` `d1c096b` `8867012` `f863612` `c806a81` | TASKS §7 |
| DP(G1-9) / CDSP(G1-11) / BT(G1-7) | DP `dr_mode=otg`+role-switch+`mdss_dp0` 同批打通；CDSP split 固件起 `remoteproc1`；BT 配对+TWS 实听 | `2026-10-05-会话-硬件驱动覆盖.md`、`2026-10-07-收盘-g1-9-dp-打通-+-q21-q24-根因.md` | `6f38865`、`6c1376907` **(内核)** `c132a1bc7` **(内核)** | TASKS G1-9/G1-11/G1-7、DEVICE §1.2 |

---

## 缺口与处置（本轮整理发现）

- **会话视角缺档**：Waydroid 马达透传 C10（2026-10-13）在 `SESSIONS/README.md` §3 与 `sessions/` 无对应行/文件（§3 为 2026-10-14 冻结快照）；内容完整保留在 `../PITFALLS/README.md` §29/§30 与提交 `536f77b/a048d64/2df5ca0`。**不强行回填快照**（避免破坏 `gen-sessions.py`/`check-sessions.sh` 的逐字节校验），改由本表登记。
- **junk / superseded 会话行**：`SESSIONS/README.md` §3 中 `junk` 12 行 / `superseded` 5 行的逐条理由见本轮审计报告 `.pi/lanes/audit-features-20261014.md` §4；`SESSIONS/README.md` §5 记为「待批」。**本轮裁决：表内保留作审计痕迹，不删**；仅其档案文件在 `sessions/README.md` 注明口径（见 §5）。
- **重复短 id**：`01a12d5a` 在 §3 出现 2 次（同 id 两会话）——本表不复制，检索以 pi 原生 `session_search` 为准。
