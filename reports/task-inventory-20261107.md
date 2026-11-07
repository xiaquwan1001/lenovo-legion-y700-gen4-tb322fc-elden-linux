# 任务盘点一页纸 — 2026-11-07

> 口径：`TASKS/README.md` §0/§4/§5/§7（现查 `scripts/check-progress-counts.sh --tsv`：**G1 33/35**（🟡2）、**G2 8/12**（🟡2 🆕1 ⬜1）+ G3 端到端 + 拓展 UEFI。
> 设备在机态（唯一权威 `DEVICE/README.md` §1.1）：**U2 在 Linux（vk172，持久根 /dev/sda17），boot_b 未动（fb55997c…），a/b 均 Bootable**。

## 表 1 开放任务

| ID | 一句话目标 | 状态 | 阻塞点 | 下一步（一条命令/实验） | 证据指针 |
|---|---|---|---|---|---|
| G1-29 / N1 UEFI | 间接引导跑通到内核接管 | 进行中 | 卡点已收敛到 **EB→跳内核后不活**；下一步 p37 = 用 logfs 通道判「崩在 EB 内还是 EB 后」 | p37：真内核载荷 `fastboot boot out/boot-elden-vk172.img`（一会话一发），断电→起 Linux→`dd if=/dev/disk/by-partlabel/logfs bs=4096 skip=2016 count=4` 判 posteb/preeb | `TASKS §5 2026-11-06 夜·五块`、`reports/uefi-p34-p36-logfs-20261106.md` |
| T14 | 用户态服务独立固化（去 Alpine 绑定） | 未收口 | Mobian 换根后重建 recipe 未写（7 个 ELF 中 3 个无源、2 个动态 musl） | 跑 `packaging/elden-userland/tools/verify.sh` 基线后按 `reports/userland-dealpine-audit-20261026.md` 补 recipe | `reports/userland-service-inventory-20261025.md` |
| T17 | 驱动模块化 × Alpine→Mobian 换根（S2–S7） | 未上机 | S2 依赖闭包未装；S7 一条 `fastboot boot` 换根未执行（linux18 已删，回退=重启回 boot_b） | 执行 S2：按 `reports/modular-mobian-transition-20261026.md` 装 7 个依赖闭包包 | 同左 |
| C3 | Play Integrity / DRM 等级取证（G2 收官项） | 未证实 | 需装 PI Checker 取三档回包（APK 获取卡用户确认） | 用户确认后装 PI Checker 跑三档 | `reports/c3-identity-drm-20261013.md` |
| C5-U7 | 容器内相机 App 实开预览 | 未上机 | 前置链路（HAL MJPEG 广告/BLOB 流）已定，App 实开未测 | 容器内装 OpenCamera，`cam-loopback.sh start rear` 后实拍一帧 | `TASKS/sessions/2026-11-03-TASKS行81-C5.md` |
| G3 x86 端到端 | Steam 游戏可玩（图形/音频/性能） | 进行中 | Steam 登录界面已达成，FEX/box64 游戏层未接 | 设备上装 FEX 或 box64+Wine 试一款轻量游戏 | `reports/g3-steam-20261028.md` |
| M2-A2 | battmgr 系列过 review | 进行中（上游等回） | 等维护者 review | 复查 lore/patchwork 增量（勿 ping） | `reports/upstream-status-20261105.md` |
| M3 | dwc3 + wl2868c v8 在评审 | 进行中（上游等回） | 11-06 已投 v8；sashiko 两条 High 已被修并被机器确认；等人类维护者 | 盯 patchwork/lore 增量回包 | `out/mail-20261106/REPORT.md` |
| M4 | camss 大件（已投 3 枚通用修复 + v2） | 进行中（上游等回） | sashiko #4「多 RDI 累积位」未判别 | 盯 review；icc 表 fix 素材留给 Hangxiang 不投 | `reports/m4-camss-v2-20261031.md` |
| M5 | dm-default-key 剥离→out-of-tree 封存 | 未收口 | 立项完成、patchset 未产出 | 静态产出 patchset 草稿（主机侧） | `TASKS/sessions/2026-11-06-TASKS行654-M5.md` |
| M6 | Q28 上游化（B5 重构 + RFC） | 进行中（≈35%） | 11-02 已回 Dmitry 四条、承诺 v2 重切 | 在 torvalds master 重切 v2 | `reports/upstream-status-20261105.md` |
| M8 | Q28 dispcc mdss 复位 v3 | 未证实（等 review） | 3/3 已有 Reviewed-by，1/3、2/3 未决 | 只累积 tag 不改内容，等回 | `patches/upstream/q28-dispcc-2026-10-22/README.md` |
| M9-替代 | kexec LPI：改「引导器预置+DT memreserve」 | 未裁决 | Marc 方案被否后我方已撤回内核侧；loader 侧方案待用户拍板 | 用户裁决是否立 loader 侧小项 | `TASKS/sessions/2026-11-06-TASKS行658-M9.md` |
| 内核重基 | 日常树 7.3.0-rc7 → 7.3.1（或 7.4-rc1） | 未开工 | 只差静态成本账 | 主机侧跑一次重基构建计时（不改配置） | `reports/progress-review-20261106.md` §4 |
| T9 suspend | suspend 掉电率 | ⛔ 搁置 | 用户 2026-10-28 裁决最低优先不排期 | — | `reports/qca-fw-download-suspend-20261021.md` |

## 表 2 待测/待取证

| 项目 | 判据 | 设备条件 | 预估成本 |
|---|---|---|---|
| UEFI p37 logfs 三段落盘 | `posteb` 在 ⇒ 崩在 EB 后；只有 `preeb` ⇒ 崩在 EB 内（QUP 句柄线） | fastboot 零写盘 + 可能一次物理断电 | 1–2 发上机，~1 h |
| UEFI 崩因终判 | 若 posteb 在：查交接参数/内核极早期（`[K] dtb=` 魔数） | 同上 + Linux 起来读 logfs | 2–3 发，止损线 = 再 3 发无进展收口 |
| C3 PI Checker 三档回包 | MEETS_DEVICE/ BASIC/ FAIL 三档截图或日志 | 在机 Linux + 容器 + 上行代理（需 `scripts/host-net-proxy.sh`） | ~0.5 h + 用户拿 APK |
| C5-U7 App 预览 | OpenCamera 出预览图（截图存 reports/artifacts） | 在机 Linux + 容器 | ~0.5 h |
| G3 Steam 游戏端到端 | 一款游戏进主菜单可玩 | 在机 Linux | 1–2 h（首次装 FEX/box64 层） |
| T17 S7 换根 | `fastboot boot` 起进 Debian root，`findmnt /` 非 sda17 的验证件 | fastboot 零写盘（回退=重启回 boot_b） | ~1 h + 前置 S2 装包 |
| T14 换根后重建 | 80 条 verify.sh 在 Mobian 根上 FAIL=0 | 换根后 | ~2 h（3 个无源 ELF 是硬点） |
| 内核重基成本账 | 全量构建分钟数 + 模块 vermagic 一致性 | 仅主机 | ~1 h（后台构建） |
| v8 上游回包增量 | patchwork 状态变化 / 维护者意见 | 仅主机（IMAP+patchwork API） | ~10 min/轮 |

## 表 3 需用户拍板（≤5）

1. **UEFI 止损**：p37 起再 3 发无进展即收口（沿用既有止损线）——是否确认？
2. **M9 后续**：kexec LPI 的 loader 侧方案（kexec loader 写 memreserve+预置 LPI 表）是否立项小任务，还是彻底归档？
3. **内核重基**：先做 7.3.1 静态成本账（建议），还是直接评估跳 7.4-rc1？
4. **C3**：授权获取/提供 PI Checker APK（涉及凭据与账号，需用户操作侧配合）。
5. **T17 换根排期**：Mobian 换根（S2–S7）本轮是否执行（影响后续 T14 与日常镜像形态）。

## 建议下一步顺序（3–5 条，含并行）

1. **主机侧并行：M3/M4 上游回包增量复核 + M6 v2 重切备料**——不占设备、是当前唯一「欠债方是我方」的线。
2. **设备侧主线：UEFI p37**（1–2 发零写盘 + 可能一次物理断电）——EB 归因是当前最窄的单点问题，logfs 通道已打通。
3. **设备侧次线（可与 2 同批）：T17 S2 装依赖闭包**（不重启即可做），S7 换根排到物理操作窗口。
4. **主机侧低成本：内核 7.3.1 重基成本账**（后台构建）——为下一个基线决策供数。
5. **用户依赖项（C3 APK）先行催办**，拿到后 C3/C5-U7 可在同一次设备会话内合并完成。
