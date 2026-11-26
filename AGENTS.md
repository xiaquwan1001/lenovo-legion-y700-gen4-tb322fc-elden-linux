# y700-elden — 项目说明
**Canonical open work: `TASKS/README.md`**（§7 = M 系列上游化，循环里引用必须带章节；其余按未关闭小节的优先级排）
（grow-loop 工作面声明，2026-11-17 加：说 `grow loop` 时按此文件排优先级与续轮；口径见技能 `pi-autonomous-loop`）

> **项目描述只在本文件。** 做事规范见 **`.pi/AGENT-OPS.md`**（agent 行为/授权唯一入口）；
> 踩坑经验见 **`PITFALLS/README.md`**（开发经验唯一入口）；文档地图与状态见 **`INDEX.md`**（唯一入口）。

**机型唯一**：联想拯救者 Y700 四代 = **TB322FC** = 代号 **elden** = SoC **SM8750(P)**。
研究面 = **让这块板子在主线 Linux 上功能完整**（固件/驱动为主；刷写只是手段）。

## 目标（按优先级）

- **G1 完整 Linux + 上游化**：主线 Linux **功能特性完整**，**正确驱动全部原厂固件**（ADSP/CDSP/WCN7861/GPU/触屏/触觉/功放/tplg/相机…）。
  代码达到上游规范后**按模块向上游提交**（checkpatch/DTC/`dtbs_check` 绿；分级与顺序见 `TASKS/README.md` §7 的 M 系列，以 §7 为准）。
- **G2 安卓容器**：**不依赖 Android 宿主**运行安卓应用（主路线 Waydroid，备胎 redroid）。
  核心验收 = **可用性 + 风控/完整性等级**：GMS 登录、**Play Integrity / SafetyNet**、Widevine 能做到哪一级
  （**取证判定，不预设"不可能"也不承诺**；见 `RESOURCES/README.md` §1.3、`TASKS/README.md` §5 Q1/§6）。
- **G3 x86 模拟运行**：以 **Steam 游戏**为验收载体，跑通 x86 用户态/游戏（Box64 + Wine/Proton 线）。
- **拓展（非主线，不阻塞 G1–G3）**：**UEFI 间接引导**、**Gunyah 高通虚拟化做 VM**。现状/裁决见 `TASKS/README.md` §4/§5、`archive/topics/`。

## 核心原则

- **设备等价**：同型号多台单元**物理地位完全等价**，唯一差异 = 容量；身份 = **(SN, hwboardid, 容量)**（`DEVICE/README.md`）。
  任务按单元**当前状态**分派，产出必须**设备无关**（运行时读实际 GPT/DT）。设备称 **U1 / U2**；
  备份目录 `backup/<SN>-<容量档>/`；**禁用** `new-tablet` 与「两轨分机」旧口径。
- **存储**：Linux 容量按项目体量一次给足（`DEVICE/README.md` §3），扩容首选回收 Android 专属分区；不写死配置。
- **文档 SSOT**：唯一入口 `INDEX.md`（其 §0 = 状态摘要，§2「入口阶梯」= 阅读顺序 + 时间序权重）；分层与清单见 `INDEX.md` §2。
- **构建抢槽位**：开编前 `build-slot take y700-elden:<任务> --jobs N`、收工 `build-slot drop`（预算/口径 = 全局规则 17，本文件不重写）。
- **上机先过 QEMU**：凡是要烧设备/人肉看屏/`fastboot` 的验证，先写一条 QEMU 对照（`scripts/qemu-full-chain-smoke.sh`，单轮 ~35 s），
  QEMU 判不了的面（真外设、EFI-stub 差异、电源域）显式写「需上机」。调研结论 = `reports/qemu-usage-survey-20261112.md`（`-M virt,acpi=off`、`ramfb` 能出字、`virtio-gpu` 不能）。
- **能力缺口默认上游化（2026-11-25 用户定）**：上游缺能力/驱动/控制链/接口时（范例 = 数据线 SDP 只 100 mA，mainline 无 charger 控制链），默认动作 = 查上游是否已有人在做 + 按 `TASKS/README.md` §7 口径**尝试提 PR/MR/issue**（内核邮件系列 / GitLab MR / GitHub PR），并把「缺口」写成台账待办行；本机规避只作「上游未合入前的临时手段」与之并列记录，不得用规避替代立项。投递仍按 §7 逐次批准，立项/备料/门禁/文本起草不等放行。
- **上游发信（2026-10-31 用户授权，已实测一次）**：**允许 agent 代写回信/cover**（含回应维护者「not with LLM」那类线程），**前提三件**：
  ① 开头如实披露 AI 辅助（作者本人校对；内容/测量/决定归作者）；② 每条论断附可复现证据（引用 + 命令/数据）；③ 逐条回应 reviewer 意见，不遗漏、不说套话。
  投递仍按 `TASKS/README.md` §7「按系列逐次批准」；范例 = `out/mail-20261031/{re-krzysztof-wl2868c.txt,claims.tsv,self-review.md}`（Sent[207]）。

---

> 模型/别名/并发/限流口径见全局 `~/.pi/agent/rules/cross-project.md` + `~/.pi/agent/custom-providers.json` 与 `~/.pi/agent/settings.json` 的 `subagents` 段（现值真源；fabric.json 已于 2026-11-21 随 fabric 卸载删除）+ 技能 `ustc-model-gateway`、`subagent-dispatch`（本文件不重复）。

## 项目记忆（2026-11-13 收束：只留「违反即事故」的一行判据；细节在指针处）

- **开工三件事**（2026-11-14 立，硬规则）：① 先核实**最近 2–3 轮会话进度 vs 文档描述**（`scripts/recent-sessions.sh 3` + `*/sessions/` 最新 2 篇），不一致**以会话里有实测证据的那条为准**并同轮改文档；② 先查 `PITFALLS` 既有结论；③ 确认在机内核/槽位与网络现态。全文 = `.pi/AGENT-OPS.md` §0；裁决规则 = `INDEX.md` §2「时间序裁决」。
- 版本账：**禁重跑** `scripts/vk-identity.py`（镜像缺失会清空整表）；清镜像只走 `scripts/out-archive.py`（默认 dry-run）。
- 内核构建只走 `scripts/build-kernel.sh`（裸 `make` 按宿主 x86 重写 `.config`）；RAM 起新核前先部署整套 `/lib/modules/<UTS>`。
- 设备侧脚本只写 **POSIX sh**、整文件 `scp` 到 /tmp 再 `sh`；设备侧查进程统一用 `ps -eo comm | grep -cx`（Alpine 期用 busybox applet 时 `pgrep -x` 恒假阴性；现根 `pgrep` 来自 procps-ng，但统一写法免分发行版）。
- `pkill -f`/`pgrep -f` 自匹配的成因与判据见技能 `pkill-self-match`；本仓设备侧模式写字符组（`[t]tyACM`）+ `grep -vw $$`。
- `PITFALLS` 编号只补不重排；正文行首 `N. ` 会被当成条目定义（有序列表写 `- **…**`）；条目标题必须含 `## #NNN`。
- **不要在本机平板上编译**（过热 → 断电重启到 BL）：内核用 aarch64-linux-gnu，musl 用户态用 `~/toolchains/aarch64-linux-musl-cross`。
- **自编件替发行版同名包的二进制，只 `install` 会被 apt 静默冲刷**（实测：phoc 被换回原件，功能消失但进程/桌面全正常）。必须 `dpkg-divert --divert <bin>.dpkg-dist` + `apt-mark hold`；脚本 `scripts/phoc-install.sh`，细则 `PITFALLS #654`。
- 「收尾」= 产物落盘 + SSOT 同步 + 设备安全态 + `check-doctor` **FAIL=0**（WARN 必须逐条列出并归类：本轮修 / 已登记豁免；C 类存量 WARN 不阻塞收尾）+ 工作区 clean（全文 `.pi/AGENT-OPS.md` §5）。
- 子代理派发口径 = 全局 `AGENTS.md` 硬性规则 8 + 技能 `subagent-dispatch`（别名/provider 清单不在本文件重写，现查 `custom-providers.json`）；本项目编排形状/递归条件见 `.pi/ORCHESTRATION.md` §4。
- **其余判据不在本文件**（b 槽签名、双层压缩、kexec 取证、`build/*` 删除前 bundle、geekidos-linux 浅克隆、顶层布局登记、EDL 工具链、Q28 坏发协变量、`.pi/trash` 保护）：
  见 `.pi/memory/`（`MEMORY.md` / `failures-kernel*.md` / `failures-device.md` / `notes-display.md` / `notes-q28-vk127-20261017-18.md`〔Q28/vk127 线历史，2026-11-24 拆出〕）与 `PITFALLS/`；检索用 `mem <关键词>`。

## 细节

- vk127 baseline / EDL / layout / git 修复 / 门禁的成对事实与脚本指针：`.pi/memory/MEMORY.md`（2026-11-17 拆后约 47 KB）。
- 相机 / C5 / Waydroid 容器（HAL、IPA、AE、vendor.img）：`.pi/memory/notes-camera-waydroid.md`；2026-10-17 换机/迁移/重建：`.pi/memory/notes-migration.md`。
- 81 条设备侧细粒度坑（Alpine/busybox、Waydroid 容器状态机、codec/audio/camera、SSH 部署）：`.pi/memory/failures-device.md`（条目数现查：`grep -c '^---$'`）。
- 刷机/AVB/kexec/EDK2-Mu/UEFI/内核打包证据与寄存器级细节：`.pi/memory/failures-kernel-{boot-uefi,boot-flash,slot-avb,display,gpu-comp,power-io,misc}.md`（2026-11-26 按主题拆分，每件 ≤50 KB，条目/条数**现查** `grep -c '^---$' .pi/memory/failures-kernel-*.md`；索引件 = `failures-kernel.md`）。
- 协作口径（物理 POR、目视纠正、按字母顺序执行、电话/观测节奏）：`.pi/memory/USER.md`。
