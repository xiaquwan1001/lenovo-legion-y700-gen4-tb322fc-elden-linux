# UEFI 下一步裁决 —— 邮件/GitHub 新回复与新发现核查（2026-11-03）

> 性质：**只读核查 + 裁决**（三条子代理 lane + 编排者独立复核）。零设备接触、零写盘、零发信、零 GitHub 写操作。
> 子报告：`reports/uefi-mail-triage-20261103.md`（邮件）、`reports/uefi-github-scan-20261103.md`（GitHub/API）、`reports/uefi-external-scan-20261103.md`（外部发现）。
> 前置口径：`TASKS/README.md` §4 N1 / §5 Q25；`reports/uefi-ddrcut-fallback-20261101.md` §6-A（四臂全 0）、`reports/uefi-cleanheader-reframe-20261101.md`。

---

## §0 结论（先数字）

| # | 项 | 结论 | 等级 |
|---|---|---|---|
| 1 | 邮件（2026-10-18 起 16 天） | 回复我们 Message-ID 的共 **8 封，全在显示线程**（camcc 回归 / dual-DSI NT36536），**UEFI/UFS 相关 0 封** | 已证（编排者复跑 `read-mail-ustc.py --replies-only`） |
| 2 | 上游 issue #12 | **无新回复**：最后一条 = `sunflower2333`，`2026-10-29T04:19:30Z`（已归档）；`updated_at` 同值；10-29 之后新增评论 **0** | 已证（gh api comments 过滤 + 编排者复跑） |
| 3 | `mu_wide_platforms` | 2026-10-25 以来 **commits 0 / releases 0**（fork 本体停在 2026-10-01） | 已证 |
| 4 | 我方仓库 | issues 0 / PR 0 / discussions 未启用 / stars 2 / forks 0 ⇒ **无外部输入** | 已证 |
| 5 | **真新发现（决定性）** | `7Night-kqx/UniXNU-dada`（**小米 15，SM8750 "sun"**）：README §State 明写「**UEFI firmware, framebuffer, menu, UFS, side buttons, UART7 — works in Mu-Silicium**」，最后 commit `2026-10-27`；同作者 `uefi-dada`（Mu-Silicium fork，含 `Platforms/Xiaomi/dadaPkg`）`2026-10-17` | 已证（gh api 读 README 原文 + commits） |
| 6 | 同一条里可抄的打包链 | `UniXNU-dada/docs/patches/` 内 **`unixnu-bootimg-header-v4.patch`（boot-image v3/v4 校验路径）、`mu-silicium-bootshim-header-size.patch`、`mu-silicium-unixnu-components.patch`、`unixnu-ramdisk.patch`**；README 记 payload 为 **0x300000 FV** 的 host 侧构建 | 已证（目录清单） |
| 7 | 我们基座代次 | 本地 `build/uefi-woa-prep/repos/7-mu-lenovo` = `6b6ac42a`，**2026-10-05**；Mu-Silicium 主仓已到 **v4.1（2026-11-01）** | 已证（`git log -1`） |
| 8 | 10-05 首轮失败的「SCM mailbox / QBSS / **CPU_Vectors** 缺失」是否已被上游修 | 上游同类修复 = **#2166「Fix Synchronous Exception error when booting linux」(2026-10-28)**，实质是 MemoryMapLib 补 TME/CPUCP/**CPU Vectors** 区 + kernel 保留；**本机 `lenovo-y700g4/Library/PlatformMemoryMapLib` 已含 `CPU Vectors 0xA7600000` 与 `Kernel 0xA8000000/Reserv`** ⇒ 该缺口我们已覆盖，**升基座不是必需** | 已证（PR body + 本地 .c 逐行） |
| 9 | 邮件里唯一沾边的新线索 | 2026-11-01 Haozhen Li `[RFC 0/2] firmware: qcom: scm: QSEECOM app loading and listener support`（Konrad 11-02 已回）——**Linux 侧调 QSEE 的上游地基**，与本轮 UEFI 卡点无因果关系 | 已证（邮件原文标题/日期） |

**⇒ `TASKS/README.md` §4 N1 的解冻条件②「出现 SM8750 上 UEFI 真正枚举 UFS 的第三方案例」已满足**（第一方 `xiaomi-piano` 10-28 已判「未证实」、第二方 `oneplus-dodge` 是手机亮屏、**第三方 dada = 同 SoC 且 UFS 通**）。

---

## §1 裁决：只做一件事 —— 先把「载荷被执行」补上，再谈 UFS

上一轮（11-01/11-02）已经把结论钉死在**前置条件**上：三条变体在同一 slot 路径上 `stage1=0`，即**载荷第一条指令都没跑**；
而 10-30 唯一「真交棒」的 A2 用的是厂商 UFSDxe 且带着**脏 header**。因此本轮**不去碰 UFS 层**，只补「载荷能不能被执行」。
dada 正好提供了同一 SoC 上已被验证过的打包链路，这是唯一低成本、可证伪的下一步。

### P1（主机侧，0 设备风险，≤2 h）
1. **搬打包链**：取 `UniXNU-dada/docs/patches/{unixnu-bootimg-header-v4,mu-silicium-bootshim-header-size}.patch`，
   落到 `patches/uefi/20261103-v4header/`；对照我们现壳（v0 header + 4096 page）做单变量：**只改 header 代次与 payload 尺寸（0x300000）**。
2. **装对 UFSDxe 并记身份**：用**树内** `lenovo-y700g4/PatchedBinaries/UFSDxe.efi`（`00ae059f…`，三补丁
   `0xa998` Sleep→Wakeup / `0x114c4` 绕 gear 检查 / `0x1b080` `EnableUfsIOC`→`mov w0,#0;ret`），构建日志与报告必须落 sha
   （11-02 教训：E1 装进去的是 dodge 两补丁件 `e76b555f…`，成败不可解释）。
3. **静态自校验门**：header 全字段 dump（magic/版本/page_size/kernel_size/ramdisk_size/entry）+ BootShim 入口落在已映射区，
   `scripts/assert-kernel-sane.sh` 同类硬门；产物 `out/uefi-20261103-v4header.img` + sha256。

### P2（设备侧，**单发、零写盘**）
- `fastboot boot out/uefi-20261103-v4header.img`（不动 `boot_b`、不改 GPT、不改槽位）。
- 取证三件：① `logfs` **10 段环**全段解析（`scripts/abl-log.sh`；11-01 已证前 9 段仍在盘）；② DDR 标记页读回（`blackbox.ko`）；③ 60 s USB 枚举采样。
- **判据**：`stage1 ≠ 0`（= 载荷真被执行）**且** 至少一条 UEFI 侧痕迹。二者缺一即「打包仍未被执行」，不进退。

### P3（门禁）
- `stage1 ≠ 0` 且 UFS 仍报 `EFI_DEVICE_ERROR` ⇒ 才值得做 UFSDxe 三补丁/UFS 层的差分与对照（届时才有单变量意义）。
- `stage1` 仍 `= 0` ⇒ **UEFI 线再次搁置**，把 dada 打包链与 v4 header 记为复启资产（复启条件照旧，不写 tiny DXE）。

---

## §2 本轮明确不做

| 不做 | 理由 |
|---|---|
| 回帖 issue #12 | 上游已给「你的系统版本问题」+ 建议 USB ACM gadget，我方无新事实；10-29 已发更正评论 |
| 升 Mu 基座到 v4.1 | §0#8：与本机症状同签名的 #2166 缺口本机已覆盖；升基座 = 一次引入大量新变量 |
| 写 tiny DXE（上游建议） | 成本最高、无证据；dada 已证明 SM8750 UFS 不需要它 |
| 设备写操作（`boot_b` / GPT / 槽位） | 本轮唯一设备动作是 `fastboot boot`（零写盘） |
| 跟评 QSEECOM RFC | 与本轮 UEFI 卡点无因果；属 G1 上游化的独立机会，另案 |

---

## §3 证据指针

- 邮件：`reports/uefi-mail-triage-20261103.md`；独立复核命令 `python3 ~/.local/bin/read-mail-ustc.py --replies-only --days 16`
- GitHub：`reports/uefi-github-scan-20261103.md`；独立复核 `gh api repos/sunflower2333/mu_wide_platforms/issues/12/comments --jq '.[]|[.created_at,.user.login]|@tsv' | tail -3`
- 外部：`reports/uefi-external-scan-20261103.md`；dada 原文 `gh api repos/7Night-kqx/UniXNU-dada/readme`、`…/repos/7Night-kqx/UniXNU-dada/commits`
- 基座代次：`git -C build/uefi-woa-prep/repos/7-mu-lenovo log -1 --format='%H %ci'`
- 本机内存图已含 CPU Vectors：`build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/PakalaPkg/Device/lenovo-y700g4/Library/PlatformMemoryMapLib/PlatformMemoryMapLib.c:22,31`
