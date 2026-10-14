# Lane 报告：DEVICE × RUNBOOK 数字/口径重复登记 → 改引用

- 日期：2026-10-14
- 边界：`RUNBOOK-BRINGUP/**`、`DEVICE/**`（独占）；未触碰 INDEX/TASKS/AGENT-OPS/SESSIONS/.githooks/versions
- 规则：重复登记 → 删复述、只留一句指针「见 <SSOT> §x」；保留原语境一句话
- 结论：9 条审计项全部处理，**改动 2 文件 9 处**（RUNBOOK 7 处、DEVICE 2 处）；旧数字 `160–200 / 64–96 / 3.44 GB / 30852 / 550 G` 在边界内已无复述（仅 SSOT 保留）

## 逐条 旧 → 新

### 1. RUNBOOK 容量建议值 → DEVICE §3.2
- RUNBOOK:25（§0.0 表 LINUX_GIB 行）
  - 旧：`| ... | 512G 档建议 160–200；256G 档 64–96 |`
  - 新：`| ... | 值域见 \`../DEVICE/README.md\` §3.2 |`
- RUNBOOK:279（Phase 3 注释）
  - 旧：`# 容量按 ../DEVICE/README.md §3.2 一次给足（256G 档 64–96；512G 档 160–200）；输入必须是本单元自己的 dump`
  - 新：`# 容量值域见 ../DEVICE/README.md §3.2（一次给足）；输入必须是本单元自己的 dump`
- 保留：`一次给足` 操作口径 + `export LINUX_GIB=...`（:29）不动。

### 2. RUNBOOK rootfs 归档规格 → RESOURCES §2.2
- RUNBOOK:45
  - 旧：`| **持久 rootfs 归档** | \`env-pass/.../linux17-rootfs-20261002.tar.gz\` | 3.44 GB / 30852 项 |`
  - 新：`| ... | 规格（大小/项数）见 \`../RESOURCES/README.md\` §2.2 |`

### 3. RUNBOOK 备份目录命名 / 禁用 new-tablet → DEVICE §2.5
- RUNBOOK:26（§0.0 表 BAK 行）
  - 旧：`| \`BAK\` | 备份目录 | 命名规范 | \`backup/${SN}-${CAP}/\`（**勿再叫 \`new-tablet\`**） |`
  - 新：`| \`BAK\` | 备份目录 | 命名规范见 \`../DEVICE/README.md\` §2.5 | \`backup/${SN}-${CAP}/\` |`
- 保留：`export BAK="backup/${SN}-${CAP}"`（:30-31）变量定义；:32 历史兼容映射句 `下文 backup/new-tablet/ 一律读作 $BAK` 保留（属阅读提示，非规则复述）。

### 4. RUNBOOK 两种「RAM 启动」不得混 → PITFALLS #92/#93
- RUNBOOK:228-229
  - 旧（两句）：`> ⚠️ **本 Phase 的「RAM 版」= 纯 RAM 变体（无桌面/会话服务，\`findmnt /\`=\`rootfs\`）**，只用于硬件/引导首验。` + `> **功能/服务级验收（...）必须用持久根**（Phase 4/5）或 \`fastboot boot\` **持久变体**（零写盘，见 \`PITFALLS\` #93）。`
  - 新（一句）：`> ⚠️ **两种「RAM 启动」不得混（详见 \`PITFALLS\` #92/#93）**：本 Phase 的「RAM 版」= 纯 RAM 变体（无桌面/会话服务，\`findmnt /\`=\`rootfs\`），只做硬件/引导首验；**功能/服务级验收（桌面、PipeWire、蓝牙音频、Waydroid）必须用持久根**（Phase 4/5）。`
  - 保留操作结论：RAM 变体只做硬件/引导首验、功能验收用持久根。

### 5. RUNBOOK 先查本地既有结论 → PITFALLS #87
- RUNBOOK:86
  - 旧：`⇒ **动手前先 grep 本地既有结论**（本机型答案早在 2026-08 的记录里；流程教训 \`PITFALLS\` #87、复盘 ...）。`
  - 新：`⇒ **动手前先查本地既有结论**（见 \`PITFALLS\` #87；复盘 \`archive/topics/复盘-2026-10-03-BL解锁.md\`）。`

### 6. RUNBOOK kexec 根因口径 → TASKS §4（保留操作命令）
- RUNBOOK:381-383（旧口径「硬挂整机 / 挂死分支点尚未定位」已过时）
  - 旧：`- ⚠️ **2026-10-05 定论**：...硬挂整机...；挂死分支点**尚未定位**...。**日常改用 \`--boot\` / \`--flash\`。**`
  - 新：`- ⚠️ **根因/结论口径见 \`../TASKS/README.md\` §4**（2026-10-08 定位 = device_shutdown 内 cpufreq_suspend × .shutdown 遍历多触发叠加掉电；唯一可靠规避 = 整段跳过 device_shutdown，但目标内核仍引导失败）。**日常改用 \`--boot\` / \`--flash\`。**`
- 保留：DTB 不走 kexec、`CONFIG_KEXEC_FILE=y`、只喂未压缩 `Image`、`--load-only` 先验等操作命令（:384-390）不动。

### 7. DEVICE AOSP 树体量「550 G」→ RESOURCES §2.3
- DEVICE:135（§3.1）
  - 旧：`| 设备侧构建（内核树 + 模块 + ccache） | **25–40 GB** | 主机树 605 M + Android 树 550 G（AOSP 不在设备侧） |`
  - 新：`| ... | 主机树 605 M + AOSP 树（体量见 \`../RESOURCES/README.md\` §2.3；AOSP 不在设备侧） |`

### 8. DEVICE §3.1 rootfs「3.44 GB / 30852 项」→ RESOURCES §2.2
- DEVICE:131
  - 旧：`| Linux rootfs（...） | 归档实测 **3.44 GB** → 装开后 **15–20 GB** | \`env-pass/.../linux17-rootfs-…tar.gz\`（30852 项） |`
  - 新：`| Linux rootfs（...） | 装开后 **15–20 GB**（归档规格见 \`../RESOURCES/README.md\` §2.2） | \`env-pass/.../linux17-rootfs-…tar.gz\` |`
  - 保留：DEVICE 决策相关值「装开后 15–20 GB」与依据路径。

### 9. 容量策略「一次给足 / 不预设固定值」两处复述
- SSOT 保留在 **DEVICE §3（§3.1 估算表 + §3.2 决策规则，含 512 档 160–200 / 256 档 64–96）**。
- RUNBOOK 侧只留操作解释并指向 DEVICE §3：见第 1 条（:25 值域指针、:279 值域指针）；:29 `一次给足，勿预设` 与 :431「默认按上界一次给足」原本即为指针，未动。

## 验证
```
$ grep -n -e '160–200' -e '64–96' -e '3.44 GB' -e '30852' -e '550 G' RUNBOOK-BRINGUP/README.md DEVICE/README.md
DEVICE/README.md:142:   按 §3.1 的上界一次划足（**512 档建议 160–200 GiB；256 档建议 64–96 GiB**...）   # ← SSOT，保留
$ grep -n 'new-tablet' RUNBOOK-BRINGUP/README.md DEVICE/README.md
RUNBOOK-BRINGUP/README.md:32:> 下文 \`backup/new-tablet/\` 一律读作 \`$BAK\`（历史兼容映射，保留）
DEVICE/README.md:121:| 备份目录规范 | \`backup/<SN>-<容量档>/\`（**禁用 \`new-tablet\`**） |   # ← SSOT，保留
```
指针落点已核：RESOURCES §2.2(:129)/§2.3(:153)、DEVICE §2.5(:121)/§3.2(:141)、TASKS §4(:109)、PITFALLS #87/#92/#93 均存在。

## 备注 / 未改
- RUNBOOK:32 的 `new-tablet` 是历史文档→$BAK 的映射提示，非命名规则复述，按「保留原有语境」保留。
- DEVICE:121 与 DEVICE:142 是 SSOT 本体，保留原值。
- 未越界改动：INDEX/TASKS/AGENT-OPS/SESSIONS/.githooks/versions 均未触碰。
