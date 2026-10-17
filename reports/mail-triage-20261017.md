# 邮箱通道验证 + 新邮件分诊（2026-10-17）

> 结论先行：**SMTP(465)/IMAP(993) 均可用，发/收链路在换机后完好**；
> 换机期间（10-13 → 10-17）有 **5 条与我们直接相关的上游往来未处理**，其中 **1 条是维护者明确的数据请求**、**1 条是 DT binding 的直接否决**、**1 条是编译告警**。
> 通道与工具口径见技能 `upstream-mail-ustc`（`.pi/skills/upstream-mail-ustc/SKILL.md`）。

## 1. 通道可用性实测（2026-10-17）

| 项 | 结果 |
|---|---|
| `smtp.ustc.edu.cn:465` TCP | OPEN（202.38.64.46） |
| `mail.ustc.edu.cn:993` TCP | OPEN（202.38.64.8） |
| SMTP 认证 | ✅ `login` OK |
| IMAP 认证 | ✅ `login` OK；文件夹 INBOX / Drafts / Sent Items / Trash / Junk E-mail / Virus Items |
| 发件身份 | `Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>`（= `~/.gitconfig` `sendemail.from`） |
| 已订阅列表 | linux-arm-msm / linux-input / linux-pm / linux-clk / devicetree（INBOX 每天数百封 vger 洪水，订阅生效） |

**⚠ 凭据现状（需处置）**

- `~/.local/bin/{send-mail-ustc.py,read-mail-ustc.py}` 从 **GNOME keyring**（`git-credential-keyring`，键 `smtp.ustc.edu.cn:465`）取密码 —— 换机后 **keyring 里没有该条目**，两个脚本都会直接 `exit`（`keyring 无凭据`）。
- 当前唯一可用凭据 = `~/.gitconfig` 的 `[sendemail] smtppass = <明文>`。**明文密码落在配置文件里**，且与邮箱主密码同级；
  建议：**改用邮箱「客户端专用密码/授权码」后轮换一次**，并把新密码存回 keyring（`git credential approve`），再删掉 `smtppass`。
  在此之前 `git send-email` 仍可发信（本次分诊的收发即用它验证）。
- `git config` 的 `sendemail.smtpserver = mail.ustc.edu.cn`，脚本用 `smtp.ustc.edu.cn` —— 两者都通，不构成问题。

## 2. 与我们直接相关的新邮件（按可操作性排序）

统计口径：IMAP `SINCE 25-Sep-2026`，我们自己的 Message-ID 31 个；命中「对我们 Message-ID 的回复」48 封（含列表重复副本），去重后 **5 个独立线程**。

| # | 时间 | 发件人 | 主题 | 性质 | 建议动作 |
|---|---|---|---|---|---|
| **1** | 10-13 16:03 IST | **Taniya Das**（Qualcomm，clk/dt 维护者） | Re: [Regression v3] SM8750: cambistmclkcc + camcc … | **★ 明确请求数据**：要完整 dmesg/console + `pm_genpd_summary` + `clk_summary` | **回信**（我们 10-15 已采到其中大部分：`q24-n1b`、`q24-n2prime`、`q24-n5` 的 genpd/clk 读数；需按她给的路径重采一份完整快照） |
| **2** | 10-14 13:04 CEST | **Konrad Dybcio** | Re: [PATCH 0/3] usb: dwc3: two connectors sharing one HS data bus | **质疑硬件前提**：「This is an incredibly strange setup. Are you sure it's actually how it's wired up? Are there any hubs inline?」 | 回信给出板级证据（原理图/双连接器 + `port-select-gpios` 实测），否则系列会被弃 |
| **3** | 10-14 13:12 / 13:13 CEST | **Krzysztof Kozlowski** | Re: [PATCH 1/3] / [PATCH 2/3] dt-bindings: snps,dwc3 … | **直接否决**：`usb-psy-name` 全树无使用者（「There is no single usage of it」）、「Power supplies are not referenced by names, but phandles」、「No, you just added it!」 | **撤回 patch 1**，改 `power-supplies` phandle 方向；patch 2 需重写 |
| **4** | 10-15 04:19 CST | **kernel test robot** | Re: [PATCH 3/3] usb: dwc3: … | **编译告警**：`core.c:171 variable 'mux_role' set but not used [-Wunused-but-set-variable]`（arm-defconfig, clang） | 修掉 + 带 `Reported-by: kernel test robot`/`Closes:` 标签发 v2 |
| **5** | 10-13 12:34 CST | **Pengyu Luo**（`reference/upstream-pengyuluo/` 那位） | Re: [REPORT] SM8750 bonded dual-DSI + NT36536 … | **回信但帮不上**：面板驱动上游支持、**DPU 可能不支持**；10bpc/10bpp 双 DSI DSC 上游碎片化，「一旦升级就有回归」，他无精力做；给了 2 张上游工作快照链接 | 归档为 Q28 的**外部上限判断**（不改口径），可选：把这段写进 `TASKS §5 Q28` 的引证 |

**另外 1 条非技术但需知道**：Junk E-mail 里 `postmaster@qualcomm.com` 的 `Undeliverable` 是 **`quic_tdas@quicinc.com`（旧地址，邮箱满）**，已于 10-13 按上游 yaml 改用 `taniya.das@oss.qualcomm.com` 重投并送达（她本人已回信）⇒ **不是缺陷，无需再处置**。

## 3. 「与我们有关但非回复」的新动向（可影响我们手上的活）

| 主题 | 与我们工作的关系 |
|---|---|
| `power: supply: qcom_battmgr: fix the battery current sign on Kaanapali` + `expose the charge current limit`（Joonhoe Kim，10-16） | **与我们 10-13 发的 `qcom_battmgr: do not report power_now on SM8750` 同一文件同一区域**；Konrad 已在同线程问「这是所有 SM8750 还是 OEM 特有」（正是问我们那条）。⇒ 两条线**需对齐**，否则 rebase 冲突或重复讨论 |
| `arm64: dts: qcom: sm8750: Make the ADSP remote heap no-map`（Ekansh Gupta，10-16 v1/v4 系列） | 直接关系我们的 **ADSP fastrpc / SSC 传感器**（`PITFALLS #186` 那条 `qcom,non-secure-domain` 修复的邻域）；上游若落地，我们的 DT 需跟随 |
| `qcom: videocc: Fix sleep clock on Glymur/SM8750/Nord`（Shawn Guo，10-17 v3） | 与 Q24 的「display power transition + RPMh 投票」同区域（`TASKS §5 Q24` 的 cx/mmcx 线）；值得对照 |
| `media: qcom: camss: C-PHY` / `csiphy` 多系列（Anusha、George Neacsu、Loic，10-15~10-17） | 与 M4-camss 备料（`patches/upstream/m4-camss-2026-10-13`）可能撞车，投递前需比对 |
| `i2c: qcom-cci: Runtime capability detection` v3（Loic，10-16） | 与我们相机栈 `i2c-qcom-cci` 相关，可能改变 probe 行为 |

## 4. 未回但无需回的

- Q28 `[REPORT v2]`（10-15 20:21 发出）：**至今 0 回复**（INBOX/Junk 全扫）；是否进 lore 归档未复核 —— 需要时用 `lore-query.py` 按 Message-ID 查。
- 列表洪水（ath12k/camss/dpu/qrtr 等）与 `sashiko-bot` 自动评审：只在与我们补丁同一 commit 时读（已在上表 #3/#4 覆盖）。

## 5. 建议的邮件动作队列（本次未自动发送）

1. 回 Taniya：附 `dmesg`（配对加载 + 真实熄屏前后）+ `pm_genpd_summary` + `clk_summary` 三件套（**需设备在场**；无设备则先回执「数据采集中」并给出预计）。
2. 撤回/重写 dwc3 patch 1、修正 `mux_role` 告警 → 发 v2（可在无设备的主机侧完成）。
3. 归档 Pengyu 的回信要点到 Q28 引证（文档侧，1 处编辑）。

## 6. 复现命令

```bash
# 收发链路自检（凭据解析见 §1）
python3 ~/.local/bin/read-mail-ustc.py --days 5
python3 ~/.local/bin/read-mail-ustc.py --days 14 --replies-only
# 本次分诊用的完整 dump（回复正文落盘）
ls /tmp/maildump/            # INDEX.txt + 每封正文
```
