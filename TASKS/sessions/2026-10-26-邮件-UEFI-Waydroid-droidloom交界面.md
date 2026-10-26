# 2026-10-26 · 邮件 + UEFI 设计 + Waydroid/droidloom 三条外部输入的交界面核查

- **日期**：2026-10-26
- **pi 会话 id**：`01a176b2-78ba-7156-84fc-a08ec1998079`
- **主题**：为「与 Alpine 解耦、迁移 Mobian」提供裁决依据：① 上游邮件差量分诊（窗口 10-23T00:00Z 起）
  ② UEFI 路线与迁移落点的**同分区冲突矩阵** ③ Waydroid/droidloom 的**用户态硬依赖 + 解耦清单**。
  纯只读研究；设备不可达（`ssh 192.168.7.1` 超时）⇒ 零设备操作、零写盘、未发任何邮件。
- **结论（4 条）**：
  1. **邮件**（窗口 3.23 天）：原始 1 101 / 去重 991；**项目相关外部来信 8 封**（Konrad ×4、Krzysztof ×1、Marc ×1、Pengyu ×1、Ulf 离职自动回复 ×1）；
     **需我方行动 5 条，阻塞本轮迁移 0 条**。两处口径更正：① 推翻前份 refs 报告「M3-1 无新回复」——
     Krzysztof 10-23T07:49:43Z 已回「RFC 被从 DT patchwork 摘掉」；② battmgr 线程最后一条 = Konrad 10-23T13:57:29Z（GitHub 链接），现在轮到我们。
     最大增量来自 **Pengyu 10-25T16:56Z**：DT 归口正式交给我们（「squash them and send the whole thing your way」）、
     公开下游源码确认不存在、**DPU 变量 `dsiclk_sel=0` 定案**（本机已满足，变量关闭）。
  2. **UEFI 不阻塞迁移（零耦合）**；迁移使 UEFI 复启条件**变差 1 项**（`linux17` 从"空的可回退 ext4 根"变成 Debian 根，
     `BOOTCHAIN` 路线 A 原计划把 Image/initramfs 放这里）、中性 2 项、变好 1 项（迁移上机本就零写盘）。
     **冲突矩阵 6 行**，裁决 = **C1/C3/C5 由 UEFI 让路（代价 0，文件级可回退）**、**C2 GPT 手术两侧都搁置**、
     **C4/C6 由 Q28 让路**（UEFI 上线即触发 Q28 既有复启条件第 3 条）。
     **复启必留 6 项**：`linux17` 标签名 / Debian 根内一份 GRUB 可读 Image+initramfs / 一个 ≤1 GiB FAT 载体（只能尾部 1024 MiB）/
     原厂 `~/下载/tb322fc/*.elf` / 3 个 `.img`（Mu 构建树 2.3 G 需重下）/ **kexec 通道**。
  3. **Waydroid 对用户态层硬依赖 14 条**（D1–D14，逐条带 `services.tsv` 行号或脚本路径）；`ours` 仅 6 条，其余是包/镜像内部行为。
     **droidloom 改变 7 类接口**（X1–X7），最硬的是 **合成器须 `linux-drm-syncobj`（Phosh 不满足）**。
     **解耦清单 10 行（A1–A10）**：**现在必须抽象只有 3 条** = 容器后端 / 传感器数据源 / 触觉桥暴露方式；
     `waydroid-ipv6` 只改依赖方向、`config_nodes` 只加 `verify.sh` 自检；camera/音频/binderfs/显示/PI 属性投影**一律不抽象**。
  4. **三条输入对「与 Alpine 解耦」的净裁决**：**没有任何一条阻塞迁移**。UEFI 与 droidloom **都不进本轮施工队列**
     （前者卡 UFS DXE + 零可见性，后者卡合成器前置 + 无 aarch64 发布包）；邮件侧 5 条行动全部是主机侧 0.5–2 h 级。
- **证据指针**：
  - 邮件：`reports/mail-triage-20261026.md`（§1 流量/§2 线程表/§3 行动分档/§4 关键词 0 命中 + 命令/§5 工具坑）
  - UEFI：`reports/uefi-migration-interface-20261026.md`（§0 三问/§1 引导链/§2 可利用+恶化/§4 冲突矩阵/§5 复启清单）
  - 用户态：`reports/waydroid-droidloom-userland-interface-20261026.md`（§1 硬依赖 14/§2 改变 7/§3 解耦清单 10/§4 两问）
  - 迁移侧输入：`reports/modular-mobian-transition-20261026.md` §0 J1/J2、`reports/mobian-migration-plan-20261021.md` §4 状态块、
    `reports/m6-debian-candidate-boot-nousb-20261026.md` §2（`linux17` LABEL 未变）
  - 用户态真源：`packaging/elden-userland/{services.tsv,sources.tsv,hooks/elden-hapticd.pre}`、`scripts/{cam-loopback,waydroid-haptics-setup}.sh`
  - 上游资产：`reports/artifacts/uefi-built-20261024/`、`reports/artifacts/uefi-dxe-20261024/`、`~/下载/tb322fc/`
  - 复现命令：三份报告各自的「复现命令」节（全部只读；邮件侧脚本在 `/tmp/scan4.py`，不入库）
- **★SSOT 待并入**：⬜ 以下 5 条需由宿主择机并入对应角度 `README.md`（本轮**未改**任何 SSOT 文件）：
  1. `TASKS/README.md` §5 **Q28**：新增两条上游事实 —— Pengyu 澄清 **`dsiclk_sel=0` 即本机现状**（变量关闭）、
     他**撤回**当年「UEFI 在 SMMU 后写 splash」的说法（「splash 在场时 10/10 可用」）⇒ C4/C6 的最坏假设被削弱。
  2. `TASKS/README.md` §1 **M3-1 / 上游 M-线**：Krzysztof 已把 RFC v3 从 DT patchwork 摘掉 ⇒ 需决定重投 `[PATCH v4]` 还是保留 RFC。
  3. `TASKS/README.md` §4 **N1 UEFI**：issue #12 **窗口内 0 命中**（`UFSDxe`/`mu_wide_platforms` 均 0）⇒ 信息入口仍断；
     新增「复启必留 6 项」清单（`reports/uefi-migration-interface-20261026.md` §5）。
  4. `TASKS/README.md` §5 **Q3 droidloom**：补「解耦清单只 3 条必须抽象（A1/A2/A3）」与「`linux-drm-syncobj` 是硬门槛」的接口级落点。
  5. `PITFALLS`：新增一条（建议 #413）「**`read-mail-ustc.py --replies-only` 与 `--grep` 都会漏信**：
     前者 `OUR_IDS` 硬编码 3 个旧 mid、后者只匹配 Subject+From ⇒ 报数一律用「Sent Items 动态取 mid + IMAP `SEARCH TEXT`」」。
