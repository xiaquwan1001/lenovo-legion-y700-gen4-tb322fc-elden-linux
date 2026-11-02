# EDL 工具链选型（TB322FC / SM8750P）—— 跟 `linux-msm/qdl`

> **性质**：只读调研 + 源码克隆 + **主机侧本地构建**（qdl 2.8，libusb-dev 解包到 `~/edl-survey/sysroot`，未用 root/未装系统包）
> + 对官方刷机包的 **`--dry-run`**（不触设备）。**未接触设备**、未进 9008、未写任何分区、未改
> `TASKS`/`INDEX`/`PITFALLS`/`DEVICE`/`AGENTS.md`、未 git add/commit。
> **证据等级词**：`已证` = 命令原文+输出 / 文件:行 / URL+日期；`未证实` = 推断或第三方单点；
> `未上机` = 有产物无实测。

---

## #0 一页结论

| 项 | 结论 |
|---|---|
| **主跟** | **`linux-msm/qdl` v2.8**：工具链基线，刷写/读写/校验/整盘备份一律以它为准 |
| **备胎** | `bkerler/edl`：只用于 loader 检索、Diag、老设备兼容；**不再作为写路径主力** |
| **观察** | `qualcomm/qdlrs`：官方 Rust 版，等 v1.0 + UFS provisioning/VIP/erase 补齐 |
| **不跟** | `strongtz/edl-ng`：除非明确需要 MIT 许可的单文件嵌入工具 |
| **本轮动作** | **无**（用户裁定「先记录文档，暂不动手」）；设备侧验证列入复启条件 |
| **复启条件** | ① 需要整包刷写/救砖；② 需要 `--skipblock=sha256` 省时；③ 原 `qdl/build/qdl` 路径被修好之前 |

---

## §1 实测证据（2026-11-01，主机侧）

| 项 | 内容 | 等级 |
|---|---|---|
| 克隆 | `~/edl-survey/qdl`（`524d31f`，2026-10-30）、`~/edl-survey/qdlrs`（`75fe2f7`，2026-08-25） | 已证 |
| 构建 | `meson setup build -Dzip-container=disabled -Dtests=disabled -Dnbdkit=disabled` + ninja → `build/qdl`（657 KB） | 已证 |
| dry-run | 在 `~/下载/tb322fc`：`qdl --dry-run -f -s ufs xbl_s_devprg_ns.melf rawprogram{1..5}.xml patch{0..5}.xml` → `flashed 47 partitions (562.2 MiB), applied 78 patches`、每 LUN 的 PrimaryGPT/BackupGPT 均解析 | 已证 |
| 包内格式 | 153 条 `program` 全部 `SECTOR_SIZE_IN_BYTES="4096"`、`sparse="false"`；`<erase>` = 0 | 已证 |
| loader | `xbl_s_devprg_ns.melf` 是普通 ELF（`7f 45 4c 46`，非 CPIO 归档）⇒ 走单镜像路径；qdl 的 CPIO 归档分支不参与 | 已证 |

> 说明：dry-run 不建立 Sahara 链路，**不证明** melf 上传与真机读写可用（见 §4）。

## §2 issue 结构（数量不是关键，类型才是）

| 项目 | ★ | 开放 issue | 近 100 次更新 PR/合并 | issue 中位关闭 | 代码量 | 测试/CI | 许可 |
|---|---|---|---|---|---|---|---|
| linux-msm/qdl | 449 | **4** | 80 / **59** | ~57 d | 21.8k C | 15 测试含 HIL，checkpatch/codeql/qcom-preflight | BSD-3 |
| qualcomm/qdlrs | 85 | 10 | 44 / 38 | ~42 d | 3.1k Rust | 无测试 | BSD-3 |
| strongtz/edl-ng | 133 | 5 | 23 / 18 | ~9.5 d | 14.4k C# | 9 测试文件 | MIT |
| bkerler/edl | 2671 | **285** | 28 / 8 | ~35 d | Python | 无 CI | GPL-3 |

关键条目（原文要点）：

- **bkerler**：285 开放里 ~57 条 loader/Sahara、~38 条「加我的机型」—— 本质是 **loader 请求板**；
  `#808/#809/#810`（`cmd_program()` 在设备拒绝 `<program>` 时仍返回 True、`getlunsize()` TypeError 永久卡死
  `skipresponse` 导致 qfil 每隔一张镜像失败）自 2026-08 起 **零处理** ⇒ 写路径不可依赖。
- **qdl**：4 条开放全是协议细节 —— `#320` 无条件 ZLP 在 QCS8550 Sahara 上触发端点超时；`#301`
  `--skipblock=sha256` 在 kodiak/rb3gen2 失败（不加 skipblock 正常）；`#312` Sahara 模式不校验。
- **qdlrs**：开放即 roadmap 缺口 —— `#36` UFS provisioning 未实现、`#37` VIP 未实现、
  `#38` 多镜像/MBN 加载「从 qdl 移植」、`#47` `rawprogram` 的 `<erase>` 直接报
  `unknown instruction (erase)`（实测）。
- **edl-ng**：`#29` SM8850 报 `Could not find Image ID: 59`（多镜像 loader 直接失败）、
  `#25` 忽略 storage info / 默认扇区大小错、`#31` libusb 写超时；源码确认 **无 sparse 展开、无写后校验**。

上游动向（`已证`）：qdl 2026-10-08 提交 `github/qc_transition_prep`（准备迁入 Qualcomm org）、
CI 增 `qcom-preflight-checks.yml` 与 `CODEOWNERS: qdl-maintainers`；qdlrs 反向把 qdl 当参考实现（#38）。

## §3 能力映射（现用 edl.py → qdl）

| 现用 | qdl 等价 |
|---|---|
| `printgpt` | **无对应动词**（GPT 解析仅供按名寻址）→ `read 0/0+34` + 本地 sgdisk，或 nbdkit 暴露 LUN |
| `r <part> out` | `qdl <melf> read <part> out` |
| `rs <lba> <n> --lun=N out` | `qdl <melf> read N/<lba>+<n> out` |
| `w <part> file` / `ws` | `qdl <melf> write <part> file` / `write N/<lba> file` |
| `e <part>` | `qdl <melf> erase <part>` |
| 写后校验 | `qdl <melf> sha256 <part>`（设备端算摘要）；或 `--skipblock=sha256` 跳过相同内容 |
| `qfil rawprogram patch` | `qdl -s ufs <melf> rawprogram*.xml patch*.xml`（sparse 自动展开 + patch） |
| 整 LUN 备份 | nbdkit 插件把 LUN 暴露为块设备 → `dd`/`sgdisk`/`mount` |
| reset | `qdl <melf> reset`；`-R` 不 reset |
| （无） | `--dry-run`、`--serial`、`-u/--out-chunk-size`、`-i/--include`、`-l/--finalize-provisioning`、`chipinfo`、`ramdump` |

额外事实（`已证`）：qdl 首次读时按 `{512,4096}` 探测并缓存扇区大小（`src/firehose.c:569-635`，`--debug` 可见），
不再有 edl.py 默认 512 造成的 LBA 单位误算。

## §4 风险与待办（未做，仅登记）

1. **Ubuntu 仓库只有 qdl 2.4**（resolute/universe）→ 需自建 2.8（本机已在 `~/edl-survey/qdl/build/qdl`）或 Debian trixie-backports。
2. 需装仓库自带 `udev/` 规则 + 停 ModemManager；USB 2.0 口/线（既有 PITFALLS 仍适用）。
3. **未上机**：melf 上传、`read xbl_a`/`sha256 xbl_a` 在 4096 扇区下的语义、`--skipblock` 在 SM8750 的表现。
   建议并入既有「第 0 号 9008 只读验证」一次完成。
4. qdl 无 `printgpt`：短期本地 sgdisk；若要上游补 `gpt` 动词，约 150 行，是合适的第一个 PR。
5. bkerler 仅保留 loader/Diag 用途 —— **避免其 qfil 已知返回码 bug**（#808-#810）。

## §5 文档漂移（本轮发现，已就地修一处）

- `RESOURCES/README.md` §2.1 原写「自研 EDL 客户端 `qdl/build/qdl`」，**该路径已不存在**：
  `/qdl/` 在 `.gitignore` 第 14 行、git 从未跟踪该目录、换机后未恢复 ⇒ 仅存于历史文档。
  本轮已更新该行为实际可用二进制 + 本报告指针。
- 其他历史引用（保留原文，恢复 EDL 能力前需先确认路径）：
  `restore-259/README.md:74`、`restore-259/AVB-KSU-2026-09-29.md:108,127`、`RUNBOOK-BRINGUP/README.md:47,437,452`、
  `PITFALLS/sessions/08-恢复Android免解BLroot资产.md:12`。

## 证据指针

- issue 快照：`~/edl-survey/gh/{bkerler_edl,linux-msm_qdl,qualcomm_qdlrs,strongtz_edl-ng}.json`
- 源码：`~/edl-survey/qdl`@`524d31f`、`~/edl-survey/qdlrs`@`75fe2f7`、`~/edl-ng`@`4a658ee`
- 二进制：`~/edl-survey/qdl/build/qdl`（v2.8）；依赖 sysroot：`~/edl-survey/sysroot`
- dry-run 输入：`~/下载/tb322fc/`（`xbl_s_devprg_ns.melf` + `rawprogram{1..5}.xml` + `patch{0..5}.xml`）
