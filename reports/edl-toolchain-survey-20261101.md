# EDL 工具链选型（TB322FC / SM8750P）—— 跟 `linux-msm/qdl`

> **性质**：只读调研 + 源码克隆 + **主机侧本地构建**（qdl 2.8，libusb-dev 解包到 `~/edl-survey/sysroot`，未用 root/未装系统包）
> + 对官方刷机包的 **`--dry-run`**（不触设备）。**未接触设备**、未进 9008、未写任何分区、未改
> `TASKS`/`INDEX`/`PITFALLS`/`DEVICE`/`AGENTS.md`、未 git add/commit。
> **证据等级词**：`已证` = 命令原文+输出 / 文件:行 / URL+日期；`未证实` = 推断或第三方单点；
> `未上机` = 有产物无实测。

---

## #0 一页结论

> ⚠ **§0 已于 2026-11-02 修正**（原结论「qdl 主跟 / edl-ng 不跟」被推翻，改为「按能力分工」）。修正依据与逐条核实见 **§6**；下表为修正后版本。

| 项 | 结论（2026-11-02 修正后） |
|---|---|
| **日常主力** | **`strongtz/edl-ng` 1.6.0**（源码 `~/edl/edl-ng`，.NET AOT）：读/写/擦/GPT/`reset`/`ramdump`/UFS provisioning。**旧 .deb 安装态已真机验证**（2026-11-03 卸载，改源码跟踪）（`printgpt -u 4`、`read-part`、`write-part boot_b`、`reset` 9 s 回 Linux） |
| **整包刷写/校验** | **`linux-msm/qdl` v2.9**（源码 `~/edl/qdl`，tag `v2.9` 干净构建；`~/.local/bin/qdl` 软链到它）：`flashmap`/`contents.xml` 整包、sparse 展开、`sha256` 设备端摘要、`--skipblock=sha256`、`--dry-run`、512/4096 扇区探测。**尚未上机** |
| **备胎** | `bkerler/edl`：只用于 loader 检索、Diag、`peek` 族（edl-ng 与 qdl 都没有 peek；本机 loader 亦不放行，见 PITFALLS #150） |
| **观察** | `qualcomm/qdlrs`：官方 Rust 版，等 v1.0 + UFS provisioning/VIP/erase 补齐 |
| **不跟** | 无（原「edl-ng 不跟」的判定作废，理由见 §6） |
| **切换前置** | qdl 首次上机必须**只读**：`qdl list` → `qdl <melf> read xbl_a /tmp/x.img` → `qdl <melf> sha256 xbl_a`，确认 melf 上传与 4096 扇区语义后再谈写路径 |
| **已知缺口** | qdl **无 `printgpt`**（只能 `read 0/0+34` + 本地 sgdisk），而项目 GPT 取证日常依赖 edl-ng 的 `printgpt` |

---

## §1 实测证据（2026-11-01，主机侧）

| 项 | 内容 | 等级 |
|---|---|---|
| 克隆 | `~/edl-survey/qdl`（`524d31f`，2026-10-30；2026-11-03 已退役，见 §7）、`~/edl-survey/qdlrs`（`75fe2f7`，2026-08-25） | 已证 |
| 构建 | `meson setup build -Dzip-container=disabled -Dtests=disabled -Dnbdkit=disabled` + ninja → `build/qdl`（657 KB） | 已证 |
| dry-run | 在 `~/下载/tb322fc`：`qdl --dry-run -f -s ufs xbl_s_devprg_ns.melf rawprogram{1..5}.xml patch{0..5}.xml` → `flashed 47 partitions (562.2 MiB), applied 78 patches`、每 LUN 的 PrimaryGPT/BackupGPT 均解析 | 已证 |
| 包内格式 | 153 条 `program` 全部 `SECTOR_SIZE_IN_BYTES="4096"`、`sparse="false"`；`<erase>` = 0 | 已证 |
| loader | `xbl_s_devprg_ns.melf` 是普通 ELF（`7f 45 4c 46`，非 CPIO 归档）⇒ 走单镜像路径；qdl 的 CPIO 归档分支不参与 | 已证 |

> 说明：dry-run 不建立 Sahara 链路，**不证明** melf 上传与真机读写可用（见 §4）。

## §2 issue 结构（数量不是关键，类型才是）

| 项目 | ★ | 开放 issue | 近 100 次更新 PR/合并 | issue 中位关闭 | 代码量 | 测试/CI | 许可 |
|---|---|---|---|---|---|---|---|
| linux-msm/qdl | 451 | **11**（+13 PR，2026-11-02） | 80 / **59** | ~57 d | 21.8k C | 15 测试含 HIL，checkpatch/codeql/qcom-preflight | BSD-3 |
| qualcomm/qdlrs | 85 | 15 | 44 / 38 | ~42 d | 3.1k Rust | 无测试 | BSD-3 |
| strongtz/edl-ng | 132 | 5 | 23 / 18 | ~9.5 d | 14.4k C# | 9 测试文件 | MIT |
| bkerler/edl | 2673 | **285** | 28 / 8 | ~35 d | Python | 无 CI | GPL-3 |

> 计数口径：2026-11-02 用 `gh api search/issues?type:issue|pr&state:open` 重取（原表为 2026-11-01 快照，
> qdl 写「4 条」已不准——那时 v2.9 尚未发布，issue 批量进入）。★ 与开放数为当日值。

关键条目（原文要点）：

- **bkerler**：285 开放里 ~57 条 loader/Sahara、~38 条「加我的机型」—— 本质是 **loader 请求板**；
  `#808/#809/#810`（`cmd_program()` 在设备拒绝 `<program>` 时仍返回 True、`getlunsize()` TypeError 永久卡死
  `skipresponse` 导致 qfil 每隔一张镜像失败）自 2026-08 起 **零处理** ⇒ 写路径不可依赖。
- **qdl**：4 条开放全是协议细节 —— `#320` 无条件 ZLP 在 QCS8550 Sahara 上触发端点超时；`#301`
  `--skipblock=sha256` 在 kodiak/rb3gen2 失败（不加 skipblock 正常）；`#312` Sahara 模式不校验。
- **qdlrs**：开放即 roadmap 缺口 —— `#36` UFS provisioning 未实现、`#37` VIP 未实现、
  `#38` 多镜像/MBN 加载「从 qdl 移植」、`#47` `rawprogram` 的 `<erase>` 直接报
  `unknown instruction (erase)`（实测）。
- **edl-ng**：`#25` 忽略 storage info / 默认扇区大小错、`#31` libusb 写超时；源码确认
  **无 sparse 展开**（`QCEDL.CLI/Commands/RawProgramCommand.cs` 不读 `sparse` 属性）、**无写后校验**。
  ⚠ **原列入的 `#29` 已作废，见 §6.2**：那不是 SM8850 的 edl-ng bug，而是用户传错 loader 格式 +
  该机型要求签名 firehose（auth）；且 v1.6.0 本身已加入 Kaanapali(SM8850+) Firehose 支持。
  两条短板对本机的实际权重：**sparse = 零影响**（TB322FC 官方包 153 条 `program` 全 `sparse="false"`，
  `sparse="true"` 计数 0）；**无写后校验 = 真实差距**（qdl 有 `sha256 <addr>` + `--skipblock=sha256`）。

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

1. ~~**Ubuntu 仓库只有 qdl 2.4**~~ **已结（2026-11-03）**：`apt` 版 qdl `2.4-3` 与 `.deb` 版 edl-ng `1.6.0`
   均已卸载；改 **GitHub 源码自建**，`~/edl/qdl`（tag `v2.9`）+ `~/edl/edl-ng`（源码）。
   构建依赖 `libusb-1.0-0-dev` 已装，不再需要解包 `sysroot`。udev 仍用系统既有
   `/etc/udev/rules.d/99-edl.rules`（qdl 自带 `udev/70-qdl.rules.in` 未安装，因不做 `meson install`）。
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

## §6 修正记录（2026-11-02）

### 6.1 结论变更

原 §0「**主跟 qdl v2.8 / edl-ng 不跟**」→ 改为「**edl-ng 日常主力 + qdl 整包刷写与校验**」的双工具分工。
理由不是 qdl 变差，而是原判定**忽略了两件事**：本机 edl-ng 已真机验证可用；qdl 至今零上机（只有 dry-run）。

### 6.2 关键证据纠错：`edl-ng#29` 与 SM8850

原 §2 写「`#29` SM8850 报 `Could not find Image ID: 59`（多镜像 loader 直接失败）」，据此判 edl-ng 不适配本 SoC。
复核 issue 全文（`gh api repos/strongtz/edl-ng/issues/29` + 3 条评论，2026-11-02 取）：

- 报错原因是用户把 `prog_firehose_ddr.elf` 直接当 loader 传；维护者（0x8008）原话
  「**wrong format - I'll hint that you need one of the .xml files**」⇒ 多镜像 ELF 必须配
  `qsahara_device_programmer.xml`，属用法错误而非工具缺陷。
- 用户改传 `qsahara_device_programmer.xml` 后：`Loader uploaded and started successfully via Sahara`（**上传成功**），
  随后 `Configure command NAKed` / `Program command NAKed`（存储命令被拒），
  ⇒ 维护者结论「**firehose requires auth which you clearly don't have**」，即该机型（Xiaomi K90 Pro Max，SM8850）
  要求**签名 firehose**，本机 TB322FC 无此要求。
- 反向证据：edl-ng **v1.6.0 changelog 明确含**「Add Firehose support for Kaanapali (SM8850+) and above」(PR #20)。

### 6.3 本机反证（真机，非静态）

| 证据 | 内容 | 等级 |
|---|---|---|
| 安装态 | `/usr/local/bin/edl-ng` → `/usr/share/edl-ng/edl-ng`，`--version` = **1.6.0**（.NET AOT） | 已证 |
| GPT | `edl-ng printgpt -u 4 -l <melf> --memory Ufs` 正常列 LUN4 全表（含 `spunvm`/`xbl_sc_logs`/`dpm`） | 已证（PITFALLS #150、`2026-11-02-UEFI四臂判别与收尾.md`） |
| 写 | `edl-ng write-part boot_b ... -u 4 -l <melf>` 实际写通过 | 已证（`reports/uefi-ddrcut-fallback-20261101.md:131`） |
| reset | `edl-ng reset` 约 9 s 回 Linux，`boot_id` 不变槽 | 已证 |
| 短板核实 | 无 sparse（源码级确认）、无写后校验（命令表无 verify 类）——两条成立，但见 §2 的权重修正 | 已证 |

### 6.4 复现与计数刷新（2026-11-02）

- qdl dry-run 重跑（自建 v2.9）：`qdl --dry-run -f -s ufs xbl_s_devprg_ns.melf rawprogram{1..5}.xml patch{0..5}.xml`
  → `flashed 47 partitions (562.2 MiB written in 0.2 s), applied 78 patches`，与 §1 一致 | 已证
- 上游计数（`gh api search/issues`）：qdl **11 open issue + 13 open PR**（原报告写「4 条」应为发行前快照，予更正）；
  edl-ng 5 issue + 2 PR；bkerler 仍 285 开放（`#808-#810` 自 2026-08 未修，判定不变）；qdlrs 15 开放 | 已证
- **qdl v2.9 于 2026-11-02 正式发布**；二进制 `--version` 报 `v2.9-rc1-6-g524d31f`（原报告写 v2.8，予更正） | 已证

## §7 目录与安装态变更（2026-11-03）

**用户裁定：以后只用 GitHub 上游源码构建，不用 apt/.deb 打包版**（避免版本误导）。据此：

| 动作 | 内容 |
|---|---|
| 卸载 | `apt remove qdl`（`2.4-3`）、`apt remove edl-ng`（`1.6.0`）——`/usr/bin/qdl`、`/usr/local/bin/edl-ng`、`/usr/share/edl-ng/` 全部消失 |
| 归一 | `~/edl-ng`、`~/edl-survey`、`~/edl-tool`、`~/qdl` → 合并为 **`~/edl/`** 单根目录：`qdl/`（v2.9）、`edl-ng/`（`v1.6.0-2-g4a658ee`）、`bkerler-edl/`（保留带 `.venv` 的那份）、`qdlrs/`、`survey/`（issue 快照） |
| 新建构建 | `~/edl/qdl` tag `v2.9` → `meson setup build -Dzip-container=disabled -Dtests=disabled -Dnbdkit=disabled` + `ninja -C build` → `qdl version v2.9`；`~/.local/bin/qdl` 软链。dry-run 复跑：47 分区 / 562.2 MiB / 78 patch（与 §1 一致） |
| 依赖 | 装 `libusb-1.0-0-dev` ⇒ 手工解包的 `sysroot/` 废弃（进回收站） |
| 清理 | 旧 qdl 克隆 `524d31f`、bkerler 重复解包 `edl-master`、`edl.gh.tgz`/`t.tgz`、旧二进制 `v2.9-rc1-6` 全部移入 `~/.pi/trash/files/`（可恢复，非 `rm`） |
| 影响 | §0/§4 中「edl-ng = 日常主力」是 **2026-11-01/02 旧安装态**的结论，取证价值不变，但**当前机器上没有 edl-ng 可执行**（源码需 .NET 8 SDK 才能重建）；现行唯一可用客户端 = `~/edl/qdl/build/qdl` |
| 索引 | `~/edl/README.md`（职责表/用法/追新/清理清单） |

## 证据指针

- issue 快照：`~/edl/survey/{bkerler_edl,linux-msm_qdl,qualcomm_qdlrs,strongtz_edl-ng}.json`
- 源码（2026-11-03 起，单根目录 `~/edl/`）：`qdl`@`v2.9`、`edl-ng`@`4a658ee`、`qdlrs`@`75fe2f7`、`bkerler-edl`
- 二进制：`~/edl/qdl/build/qdl`（`qdl version v2.9`），软链 `~/.local/bin/qdl`；目录说明见 `~/edl/README.md`
- dry-run 输入：`~/下载/tb322fc/`（`xbl_s_devprg_ns.melf` + `rawprogram{1..5}.xml` + `patch{0..5}.xml`）
