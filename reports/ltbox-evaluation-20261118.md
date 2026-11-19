# LTBox 评估：校验逻辑能否抽成 CLI / 接 MCP（R5）

- 评估对象：`external/ext-repos/LTBox`（= `~/LTBox`），version 3.3.5，GPL-3.0-or-later，
  git HEAD `8f6d141c`（2026-11-07），workspace 四 crate（core / device / patch / gui），198 个 `.rs`。
- 评估方式：**纯静态读码**（read/grep/find）+ 纯主机编译验证。**未执行任何 adb/fastboot/ssh/qdl/edl.py/9008 操作**（设备当前可能停在 fastboot 且带 UNBOOTABLE，见 PITFALLS #672）。
- 相关既有结论已查：`PITFALLS` #669（qdl/edl 静默成功）、#584/#585（ssh+fastboot 混跑挂死）、#387/#487/#525/#572/#672（A/B 槽属性与 retry 语义）、`scripts/slot-attr.py` 头注释（byte6 权威位定义）。

---

## 0. 结论（数字先）

**LTBox 里"我们没有"的校验判据：P0 = 6 条，P1 = 7 条，P2 = 5 条**（第 1 节逐条给 file:line）。
其中 P0 全部集中在"**写之前**"这一层：rawprogram 节点预检、GPT 快照复验、镜像尺寸 vs 分区跨度、EDL-start 型号取证、dump 存在性判据、短读即失败。

**推荐路径：②（抽 crate，做"离线校验"小 CLI），不推荐 ③ 的在线部分、明确不推荐 ① 和 MCP。**
- ① 直接编它的 CLI：**不可行** —— 全仓唯一的 bin 是 GUI（`ltbox-gui/src/main.rs`），除 `--install-udev` / `--install-desktop` / 隐藏的 magiskboot helper 外没有任何 headless 入口（`main.rs:291-303`）。另一个 bin 是 `ltbox-magiskboot`（`ltbox-patch/src/bin/ltbox-magiskboot.rs`，165 B，boot 图工具，不涉刷写）。
- ② 抽 crate（推荐）：`ltbox-core` + `ltbox-device` 的**离线校验子集**（rawprogram XML 预检、GPT dump 对账、AVB/rollback 解析、尺寸/越界判定）依赖面干净：**没有 iced，也没有 tokio**（`crates/ltbox-core/Cargo.toml`、`crates/ltbox-device/Cargo.toml` 全量依赖见第 2 节）。工时 **1.5–2.5 人日**。
- ③ 用 `ltbox-device` 做在线 EDL 后端接我们自己的 CLI：技术可行（`EdlSession` 已封装 GPT 读、dump、写、reset），但**编排逻辑实际不在 core/device，而在 `ltbox-gui/src/workers/flash/*`**（`flash_worker` 1700+ 行、`model`/指纹/ARB/region 全在里面），要复用就要么把 GUI crate 也拖进来，要么重写编排。额外工时 **+2–3 人日**，且引入 USB 独占与 device-lock 冲突（第 3 节）。**不建议**。
- ④ 抄逻辑重写进 bash/python：**法律上不抄代码就可行**（GPLv3 只约束"复制/改编代码"和"分发"；内部自用不分发不触发义务），但要重写 18 条判据 ≈ **2–3 人日**，且永久承担与上游行为漂移的维护成本。**作为 ② 的兜底**。

**D（安全边界）：它不清 UNBOOTABLE、不补 retry、失败也不复位槽属性 —— 和我们上一轮踩的是同一颗雷。**
全仓 `grep -rn "UNBOOTABLE\|unbootable\|BOOT_SUCCESSFUL\|boot_successful" crates/` **0 命中**（不含测试与 i18n 文案）。
它唯一改启动槽的动作是 `EdlSession::set_active_slot_a()`（`edl.rs:1579`）→ 发 Firehose `setbootablestoragedrive`（**设 xbl 所在 LUN 为启动盘**），**不写 LUN4 GPT 的 boot_a/boot_b 属性字节**。它连 GPT 都**只读不写**（`gptman` 只出现在 `read_gpt_for_lun` / `find_partition` / `physical_lun_sector_count`，全是 `read_from`）。

**E（编译）：本机可完整编译全 workspace，系统库齐全。** 实测（仅有主机命令）：
- `cargo check -p ltbox-device --offline` → 10.3 s 绿；`-p ltbox-patch` → 8.9 s 绿；`-p ltbox-gui` → 28.9 s 绿。
- `cargo build -p ltbox-gui --offline` → **44.8 s 产出 649 MB 可执行文件** `/tmp/ltbox-target/debug/ltbox`。
- 现成：`libusb-1.0-0-dev 1.0.29`、`libudev-dev 259`、`libssl-dev 3.5.5`、`cmake/gcc/clang/perl/make/pkg-config`；cargo 1.95.0（`rust-toolchain.toml` 钉的版本，rustup 已自动装好）。
- 唯一前置：**首次解析依赖需要联网**（`avbtool-rs` / `magiskboot` / `kptools` 是 git 依赖，本地无缓存，`--offline` 首次会因 "can't checkout from https://github.com/miner7222/avbtool-rs" 失败）；`cargo metadata`（不带 --offline）跑一次后就全离线可用。

**C（MCP）：不现实，建议放弃。** 不是"难"，是**结构冲突**：无 headless 入口、USB 接口独占且绕过我们的 `flock` device-lock、`EdlSession` 生命周期与常驻进程语义相反、与命令行 fastboot 抢同一 bulk endpoint（第 4 节列 6 条）。

---

## 1. A —— LTBox 有、我们 bash 主路径没有的校验判据

"我们"基线 = `scripts/flash-b.sh`（Linux 内 dd 写 boot_b）、`scripts/linux-gpt-apply.sh`（EDL 写 GPT 主备 + 读回 sha256）、`scripts/edl-peek.sh`、`scripts/slot-attr.py`、`scripts/gpt-audit-tb322fc.py`（**事后**对账）。
已确认我们**有**的：写后读回 sha256（flash-b / linux-gpt-apply）、主备表互指+双 CRC 校验（linux-gpt-apply 内嵌 python）、`timeout -k`、`device_lock_acquire`、GPT 事后逐字节对账（gpt-audit）。下面只列**没有的**。

### P0（会造成"写坏"或"下一次实验注定失败"）

| # | 判据 | 代码位置 | 我们的现状 / 缺什么 |
|---|---|---|---|
| P0-1 | **rawprogram 每个 `<program>/<erase>` 节点在第一次写之前全部预检**（几何 + 镜像偏移 + LUN 容量），任何一个节点坏 → 一个字节都不写 | `crates/ltbox-device/src/edl/rawprogram.rs:638` `preflight_rawprogram_nodes()`；调用点 `:400`（with_wipe）/`:462`（verbatim） | 我们没有 rawprogram 刷写器；`flash-b.sh` 是裸 `dd`，先写后才可能出错。**预检全在前、失败零写入**这条纪律我们没有 |
| P0-2 | **节点必须显式带 `physical_partition_number` + `start_sector`，缺失即拒绝**（否则默认 0 会把写打到 LUN0/sector0 = 主 GPT） | `rawprogram.rs:219` `require_destructive_coords()`；`:105` `plan_program_node()` | 无。我们手工拼 `qdl write <lun>/<lba>` 时**没有**任何"坐标必须显式且合法"的强制 |
| P0-3 | **每个节点 `start_sector + num_partition_sectors` 必须落在目标 LUN 容量内**（含 u64 溢出检查）；`num_partition_sectors` 由不可信 XML 给出，qdl 会零填充到该长度 | `rawprogram.rs:246` `ensure_node_within_lun()`；`guard_node_within_lun()` `:293`；容量采样 `edl.rs:1224` `physical_lun_sector_count()` | 无。qdl 的 `write` 只按我们给的 lba+count 走，越界会写到**紧邻分区** |
| P0-4 | **镜像 sector 数 vs 目标分区 span 的写前核对 + 批量全有或全无**（所有镜像先 open、先比对尺寸，再发第一条 program） | `crates/ltbox-device/src/edl/partition_flash.rs:48` `PreparedFlash::open()`（`:77` 报 "image is N sectors but the partition spans only M"）、`:109` `flash_partition_batch()`、`:139` `apply_partition_batch()` | `flash-b.sh` **没有**：`dd of=/dev/disk/by-partlabel/boot_b` 前不查 `blockdev --getsize64`，镜像大于分区时 dd 会**写一半再 ENOSPC**，留下半个 boot_b |
| P0-5 | **分区选择快照复验**：写入前重读 GPT，逐条比对 start/span/size，不一致即"scan the device again"；且拒绝重复选择 | `edl.rs:1023` `validate_partition_snapshot()` | 无。我们的 linux-gpt-apply 校验的是**表本身**，不是"表与我这次要写的目标是否仍一致" |
| P0-6 | **dump 存在性判据只认 `PartitionNotFound`**，任何传输错误都必须当错误（不能当"分区不存在"） | `crates/ltbox-gui/src/workers/flash/mod.rs:330` `dump_presence()` | 无。我们的脚本里 `dd`/`qdl read` 失败后被 `|| true` 吞掉再按"空/不存在"推理的写法仍有存量 |

### P1（会造成误判、静默短读、难以复现回退）

| # | 判据 | 代码位置 | 我们的现状 |
|---|---|---|---|
| P1-1 | **dump 必须精确等于期望字节数**，否则保留旧备份、不发布新文件（临时文件 + `sync_all` + rename） | `crates/ltbox-device/src/edl/atomic_dump.rs:5` `write_dump()`（`:22` 长度断言、`:30` persist） | PITFALLS #587 只写了纪律（`stat -c%s` 断言）；**没有**写成"原子发布 + 长度断言"的通用函数。flash-b 的 readback 也不比对长度 |
| P1-2 | **GPT 条目区读取多读 2 个 slack 扇区**：USB Firehose 末扇区可能短/花，条目区落在缓冲区末尾时 `gptman` 解析会失败（TB323FU LUN4 128 条目正好顶到 first_usable_lba） | `edl.rs:864` `GPT_READ_TAIL_MARGIN`、`:866` `gpt_read_sectors()`（并把 `first_usable_lba` 夹到 ≤2048，防恶意 GPT 触发 GB 级读） | 无（我们是整段 `read <lun>/0+6` 等固定长度，遇到短读只靠 sha 比对发现，发现后没有"多读 2 扇区"的已知修法记录） |
| P1-3 | **LUN 归属先查静态表（6 机型交叉验证过）再回落到全盘 GPT 扫描；多 LUN 同名标签直接报歧义** | `crates/ltbox-core/src/partition_lun.rs:29` `lun_for_partition()`；`edl.rs:949` `lun_for()`、`:986` `single_matching_lun()` | 我们把 LUN 写死在脚本参数/注释里（LUN0=/dev/sda、LUN4=/dev/sde），**没有**"标签 → LUN"的可校验映射，也没有歧义拒绝 |
| P1-4 | **split-super 镜像齐备预检**（`super_*.img` 缺一个就整体拒绝，而不是跳过） | `rawprogram.rs:339` `preflight_rawprogram_super_images()` | 无（我们的 super 重组走另一条 `scripts/android-super.py` 线，不做"缺件即拒"） |
| P1-5 | **国家码分区写后回读 + 逐字节比对**（不是比退出码） | `crates/ltbox-gui/src/workers/flash/country_verify.rs:51-120` `flash_and_verify_country()`；比对器 `mod.rs:780` `files_identical()`（分块比，不整读） | 我们有 sha256 回读，但**没有**"分块逐字节"和"回读失败 → 标 failed 而不是继续"的分区级状态机 |
| P1-6 | **备份 manifest 记录每件 sha256 + 尺寸 + AVB fingerprint + rollback_index，且 manifest 永不覆盖**（`create_new`） | `crates/ltbox-gui/src/backup.rs:160` `write_backup_manifest()`（`:222` `create_new(true)`）、`:92` `create_backup_dir()`、`:110` `reserve_backup_dir()` | PITFALLS #669 要求备份带 sha；我们没有"manifest 带 rollback_index/指纹 + 目录预留防并发覆盖" |
| P1-7 | **写 abl 前先 dump 备份当前槽 abl，失败路径尽力回灌原 abl**（否则失败后设备停在"Lenovo-key bootloader + testkey 签名链"的混合态） | `crates/ltbox-gui/src/workers/flash/mod.rs:463` `backup_device_abl()`、`:487` `restore_abl_best_effort()`；调用点 `full.rs` 错误路径 | 无。这正是"失败路径留下可复现回退"的具体实现样式 |

### P2（健壮性，但都是"静默错"的来源）

| # | 判据 | 代码位置 |
|---|---|---|
| P2-1 | **XML 属性严格解析**：属性存在但不可解析 → 报错，**绝不默认成 0**（"malformed → 0" 会把写导向 sector 0 或整段跳过） | `rawprogram.rs:194` `parse_xml_attr()` |
| P2-2 | `file_sector_offset × sector_size` 溢出/越界检查（否则 seek 到镜像错误区域） | `rawprogram.rs:124-146` |
| P2-3 | `<patch filename="DISK">` 节点同样强制坐标（`byte_offset/physical_partition_number/start_sector/value`） | `rawprogram.rs:16` `plan_patch_xml()`、`:820` `apply_patch_plans()` |
| P2-4 | 刷前检查 **staging 盘剩余空间**（zstd 解压上限按 `fs4::available_space` 限流） | `ltbox-gui/src/workers/flash/mod.rs:726` |
| P2-5 | **会话对象析构时兜底把设备送回 EDL**（不静默留在半开 Firehose 状态） | `edl.rs:1591` `impl Drop for EdlSession` → `reset_to_edl()` |

### 反向：我们该警惕 LTBox 自己也缺的（别把它的洞当判据搬）

1. **主刷写路径没有写后回读**。`full.rs` 全文 **0 次** `dump_partition` 调用（唯一命中 `:1783` 是条注释），rawprogram 写完直接 `set_active_slot_a` + reset；随后**没有**再扫一次 GPT 或回读任何分区。**只有 country 分区做回读**（`country_verify.rs:51`）。→ 它的写后校验只覆盖"country 改动"这一小块；主刷写靠的是"预检 + qdl 库"，而不是读回（PITFALLS #669 的"退出码不可信"因此**没有**被它的主路径覆盖）。
2. **`<patch filename="DISK">` 没有容量边界**（`plan_patch_xml` 只查坐标存在，不查 `size_in_bytes` 落在 LUN 内）→ 与 P0-3 同类的洞，patch 路径没堵。
3. **不碰槽属性**（见第 0 节 D）。

---

## 2. B —— 复用路径：依赖面、工时、风险

### 依赖面实测（`crates/*/Cargo.toml` 全文读过）

| crate | 依赖里有 iced？ | 有 tokio？ | 重依赖 |
|---|---|---|---|
| `ltbox-core` | 否 | 否 | `aes/cbc/sha2`、`ureq`（rustls）、`roxmltree`、`moka`、`chrono`、`tempfile` |
| `ltbox-device` | 否 | 否 | `qdl`（path=vendor/qdl，qualcomm/qdlrs 本地修补版）、`gptman`、`adb_client`(usb)、`nusb`、`serialport`、`rsa`、`ureq`、`zip` |
| `ltbox-patch` | 否 | 否 | `avbtool-rs`(git)、`magiskboot`(git)、`kptools`(git，cmake/C)、`liblzma`(static)、`lz4/zstd` |
| `ltbox-gui` | 是 | 是 | `iced 0.14`、`rfd`、`tracing-*`、`winresource` |

**关键事实：core/device 都不被 GUI 框架侵入**（iced/tokio 只在 gui）。所以"抽 crate"在依赖上是干净的。
**关键陷阱：编排不在 core。** `flash_worker`（`ltbox-gui/src/workers/flash/full.rs:6`）、`read_edl_start_device`（`mod.rs:167`）、`files_identical`（`mod.rs:780`）、`backup.rs`、`country_verify.rs` 全在 **gui crate**，且直接吃 gui 类型（`ConnectionStatus`、`CountryPatchProgress`、`LiveLabels`、`PhaseReporter`）。想复用"编排+校验"就要么连 gui 一起编（也就是把 iced 拖进来），要么把 `workers/flash` 下沉成新 crate —— 那是**给上游做重构**，不是消费它。

### 四条路径

**① 直接编它的 CLI（headless 入口）**
- 事实：无。唯一 bin `ltbox` 是 iced GUI（`main.rs:291-303` 只认 `--install-udev`/`--install-desktop`/`--post-update-relaunch`）；有隐藏的 `dispatch_magiskboot_helper()`（`main.rs:224`）不是刷写入口。
- 现实做法只能是 fork GUI 加 `--headless`：工时 3–5 人日（要把 wizard 的 `WorkflowConfig` 从 UI 事件流里剥出来）+ 持续 rebase 上游 GUI。**不推荐**。

**② 抽 crate 做"离线校验小 CLI"（推荐）**
- 形态：新 crate（建议放在**我们仓外**的 `tools/ltbox-check/`，`Cargo.toml` 里 `ltbox-core = { path = ".../LTBox/crates/ltbox-core" }`，**不引 ltbox-device**），只暴露纯文件输入：
  - `ltbox-check gpt --main <lun0_primary.bin> --backup <lun0_backup.bin> --lun 0`（等价我们 gpt-audit + linux-gpt-apply 内嵌校验，但用 `gptman` 而不是手写 struct）
  - `ltbox-check rawprogram --xml rawprogram*.xml --imgdir . --lun-capacity 0=...`（**P0-2/P0-3/P1-4 的全部预检**，不连设备也能跑）
  - `ltbox-check avb --img boot.img`（`extract_image_avb_info`：partition_size / rollback_index / fingerprint / 描述符归属，`ltbox-patch/src/avb.rs`）
  - `ltbox-check image-vs-partition --img x.img --span-bytes N`（P0-4 的离线版）
- 依赖面：`ltbox-core` + `ltbox-patch` 的 avb 部分。**注意 `ltbox-patch` 拖 `kptools/magiskboot`（cmake + C），只想读 AVB 就自己拿 `avbtool-rs` 单依赖**（`avbtool-rs = { git = "https://github.com/miner7222/avbtool-rs", tag = "v0.2.0" }`）。
- 工时：**1.5–2.5 人日**（4 个子命令 + 与我们 `gpt-audit`/`slot-attr` 输出格式对齐 + 单测）。
- 风险：低。GPLv3 是**独立可执行文件**，与我们 bash 脚本是 aggregation，不传染；内部使用不分发则不触发分发义务。

**③ 用 `ltbox-device` 当库接在线 EDL**
- 可行部分：`EdlSession::open(loader)` → `scan_partitions` / `lun_for` / `dump_partition` / `flash_partition_batch` / `reset`，封装质量高（P0-1..P0-6 都在里面）。
- 代价：① 编排要自己重写或用 gui worker；② 设备独占（第 3 节）；③ 要接受它的 loader 解密/patch XML 语义；④ **写路径会真的触碰设备**，而我们当前阶段只需要"判据"。
- 工时：**+2–3 人日**，且引入"两套 EDL 栈（我们的 qdl CLI vs 它的 nusb 库）"的长期并行维护。
- 建议：**只在我们真要做"标准化刷写器"时再考虑**；当前不建议。

**④ 抄逻辑重写 bash/python**
- 法律：GPLv3 约束"复制代码"和"分发"。**照文档化算法自己实现**（本报告已给出全部判据与触发条件）不构成复制；分发我们自己的实现也不受 LTBox 的 GPL 约束。
- 工时：18 条判据 × 0.5–2 h ≈ **2–3 人日**；其中 P0-3/P0-4/P1-2 三条需要自己解析 rawprogram/GPT，是主要开销。
- 风险：与上游行为漂移、没有它们的测试集（`edl/partition_flash_tests.rs` 814 行、`rawprogram.rs` 内 12 个单测是现成的对照样本，可以拿来当验收用例）。

**推荐结论：② 为主线（离线校验 CLI，1.5–2.5 人日），④ 只补 ② 覆盖不到的两条（`gpt_read_sectors` 的 clamping 与 `dump_presence` 语义，可以直接照本报告伪码写）。**

---

## 3. C —— MCP 接入是否现实

**结论：不现实。** 不是开发量问题，是**资源模型相反**。具体冲突（每条都能落到代码）：

1. **没有 headless 入口**（同 B①）：MCP server 必须先重构成 `ltbox-cli`，工时先付 3–5 人日。
2. **编排层绑在 GUI crate**：`flash_worker`/`read_edl_start_device`/`files_identical` 都在 `ltbox-gui`，且签名带 `ConnectionStatus`、`PhaseReporter`、`LiveLabels`、`CountryPatchProgress`（`workers/flash/mod.rs` 顶部）。做 MCP 等于**给上游做一次分层重构**，上游每次 GUI 改动都会冲突。
3. **USB 接口独占 + 绕过 device-lock**：它用 `nusb` / `adb_client(usb)` 直接 claim USB 接口（`edl.rs:272` `find_edl_device()`、`adb.rs` libusb 路径）。我们的 `scripts/lib-device-lock.sh` 是 `flock` **文件锁**，只对"自愿拿锁的脚本"有效；常驻 MCP 进程只要不调用我们的锁，就和 `flash-b.sh`/`qdl`/`edl.py` 竞争同一个 05c6:9008 接口 → 谁先 open 谁赢，另一方拿到的是 `PortNotFound`/claim 失败而不是"锁忙"。
4. **`EdlSession` 生命周期与常驻进程相反**：一次 `open()` 完成 Sahara 握手 + Firehose 配置；`Drop` 里**兜底 `reset_to_edl()`**（`edl.rs:1591`）让设备继续停在 9008。常驻 MCP 若持有 session，设备就一直被占；每次调用重开又会多一轮 Sahara → 每步都伴随端口消失/重枚举（`edl.rs:481` `wait_for_stable_port_with` 就是为这种失稳写的）。
5. **与命令行 fastboot 互斥**：`fastboot.rs` 是**裸 USB bulk 协议实现**（`command()` `:211`），全文**没有 flash/erase/set_active 任何写命令**（`grep -n "flash\|erase" fastboot.rs` → 0 命中，只有 `reboot`/`reboot-bootloader`/`reboot-fastboot`/`getvar`），与 `fastboot` 二进制抢同一 endpoint；它的 `open()` 还会在本机做多设备消歧（`MultipleDevices` 直接报错）。我们的工作流大量用 `fastboot getvar`/`fastboot boot` 采样（PITFALLS #583/#584），交替时极易复现"设备在 fastboot 但看不到"。
6. **它会主动切设备状态**：ADB 路径发 `adb reboot edl`（`edl_transition.rs:136`），fastboot 路径**故意不用 `oem edl`**（`:151-153` 注释：某些机型 misbehave），而是先 `reboot` 回系统再走 ADB。MCP 调用等于让工具**替我们决定设备的电源/槽状态** —— 与我们"实验前先 `slot-attr.py show` 并把结果打进日志"的纪律直接冲突。

**如果要 MCP 形态，正确做法不是包 LTBox，而是包我们自己的只读判据**：MCP server 只暴露 `gpt_audit`/`slot_attr_show`/`readback_verify`/`image_vs_partition` 这类**输入是文件、输出是 JSON** 的离线工具（即 B② 的产物），**不持有 USB**，设备采集仍由受 device-lock 保护的 shell 完成。这样 MCP 层零 USB 风险。

---

## 4. D —— 安全边界：UNBOOTABLE / retry / 失败后槽属性

| 问题 | 事实 | 证据 |
|---|---|---|
| 会清 UNBOOTABLE 吗？ | **不会。全仓 0 处涉及** | `grep -rn "UNBOOTABLE\|unbootable\|BOOT_SUCCESSFUL\|boot_successful" crates/` → 无匹配（`ltbox-gui/src/main_tests.rs:1906` 只有一条 i18n 文案 "Unable to detect the active slot. Connect using ADB and retry."） |
| 会补 retry 吗？ | **不会。** 没有 read-modify-write GPT 属性字节的代码 | `gptman` 在 device crate 只出现 `read_from`（`edl.rs:883,892,1000,1010,1229`），无 `write_to` |
| 切槽怎么做的？ | **不发槽切换**，只发 Firehose `setbootablestoragedrive`（设 xbl 所在 LUN=1 为启动盘） | `edl.rs:1579-1589` `set_active_slot_a()`；调用点 `full.rs:1824`、`simple.rs:91` |
| 写完 `boot_a` 后属性会怎样？ | **原样保留。** 全量刷把 `boot_a` 写新镜像，但 `boot_a` 条目 byte6 的 bit7/bit6/bits3-5 一个都不动 → 如果事前是 `0xf7`（UNBOOTABLE，PITFALLS #672），刷完仍 UNBOOTABLE，ABL 仍拒绝执行 | 同上 + `rawprogram.rs` 写路径不碰 GPT 条目（只写数据区）；唯一可能改属性的是原厂 `patch*.xml` 的 `<patch filename="DISK">`（`rawprogram.rs:16-42`），**是否覆盖 boot 属性字节完全取决于厂商包内容，LTBox 不做任何保证，也没有写后 GPT 校验**（`grep -n "gptman" crates/ltbox-device/src/edl.rs` 全是读） |
| 失败后复位槽属性？ | **不会**（没有可复位的代码）；失败路径的行为是"**故意留在 EDL 等重试**" | `Drop for EdlSession` → `reset_to_edl()`（`edl.rs:1591-1603`）；`full.rs:1606` 注释 "leaves the device in EDL rather than resetting into that mismatch" |
| 有没有做对的安全动作？ | **有 3 处，值得抄**：① pre-EDL 中止若流程自己把设备弄进了 fastboot，则**重启回系统**再返回错误（`mod.rs:19-40` `should_reboot_fastboot_to_system_after_pre_edl_abort` / `reboot_fastboot_to_system_after_pre_edl_abort`，调用点 `full.rs:337,527,549,619`）；② 失败路径**尽力回灌原 abl**（`mod.rs:487`）；③ 型号/指纹不匹配时**在写第一个字节前**中止（`mod.rs` `read_edl_start_device`，`full.rs:317-340`） | 见左 |
| 对 TB322FC 特别说明 | `capabilities("TB322FC")` = `rollback: Unprotected`（`ltbox-core/src/model/capabilities.rs:114-119`）→ **ARB/rollback 检查在 TB322FC 上整段跳过**。所以它那套漂亮的 rollback 逻辑（`rollback.rs:73/104/131/139/159`、`mod.rs:167-320`）对我们的机型**不产生校验**，不能当作"我们有 ARB 检查"的依据 | 同上 |

**净结论**：D 面上 LTBox **没有**替我们解决上一轮的伤；把它当刷写器用，同一颗雷仍在（`scripts/slot-attr.py` 头注释 + PITFALLS #672 仍是唯一权威处置）。它值得抄的是"中止时别把设备丢在 fastboot"和"失败回灌 abl"这两个**失败路径纪律**，不是槽属性。

---

## 5. E —— 编译可行性（实测）

**环境**（本机实测）：
```
cargo 1.95.0 (f2d3ce0bd 2026-03-21)   rustc 1.95.0   # rust-toolchain.toml 钉的版本，rustup 已自动装好
libusb-1.0-0-dev 1.0.29 / libudev-dev 259 / libssl-dev 3.5.5
cmake / cc / gcc / clang / perl / make / pkg-config      # kptools(CMake+C)、liblzma(static) 需要
```

**最小验证命令（纯主机，无 USB/设备）**：
```bash
cd external/ext-repos/LTBox
cargo metadata --locked --format-version 1 >/dev/null   # 仅首次需要联网：拉 avbtool-rs/magiskboot/kptools 与全部 crate
CARGO_TARGET_DIR=/tmp/ltbox-target cargo check -p ltbox-device --offline --locked   # 10.3 s
CARGO_TARGET_DIR=/tmp/ltbox-target cargo check -p ltbox-patch  --offline --locked   # 8.9 s（会跑 kptools 的 cmake）
CARGO_TARGET_DIR=/tmp/ltbox-target cargo build -p ltbox-gui    --offline --locked   # 44.8 s → /tmp/ltbox-target/debug/ltbox (649 MB)
```

**实测记录**：
- `cargo check -p ltbox-device`：59 个 crate 编译，10.30 s，绿。
- `cargo check -p ltbox-patch`：含 `kptools v0.2.1+kp0.13.9`（cmake/C）8.94 s，绿。
- `cargo check -p ltbox-gui`：121 个 crate（含 iced 0.14），28.92 s，绿。
- `cargo build -p ltbox-gui`：44.75 s，**链接成功**，产出可执行文件（说明 libusb/libudev/ssl 链接面无缺）。
- **坑**：首次 `cargo metadata --offline` 必然失败（git 依赖不在本地缓存，报 `can't checkout from 'https://github.com/miner7222/avbtool-rs'`）。**不带 `--offline` 跑一次 `cargo metadata`** 即可把依赖抓全，之后全离线可用（本次已把缓存填好，`~/.cargo` 里现在有）。
- 编译不写仓库：全程 `CARGO_TARGET_DIR=/tmp/ltbox-target`，仓库 `git status` 干净。

---

## 6. 可直接搬的判据（5 条，按收益排序）

1. **写入前的"零写入失败"契约**：任何多点写入必须先把全部目标（坐标、镜像存在性、镜像尺寸 vs 分区跨度、LUN 容量）在一个**不碰设备的** planner 里算完；planner 有任何一条错，就不发第一条写命令。
   → 搬成 `qdl`/`dd` 前的 `preflight()`：`file_size ≤ blockdev --getsize64 <part>` + `partition ∈ GPT(LUN)` + `start+count ≤ LUN容量`。
   参考实现：`rawprogram.rs:638` + `partition_flash.rs:48`。

2. **无法确定"不存在"时，不许当不存在**：dump/read 只有明确 `PartitionNotFound` 才允许走"分区缺失"分支；其他一切错误（超时、短读、USB stall）必须中止。
   参考：`mod.rs:330 dump_presence()`。与 PITFALLS #587（`dd` 静默短读）是同一条命。

3. **短读即失败 + 原子发布**：dump 到临时文件 → 断言 `size == 期望` → `fsync` → rename；失败保留旧件。
   参考：`atomic_dump.rs:5`。这条能直接消掉"用半截 dump 做判据"的整类事故。

4. **主备 GPT 都要"独立可验"**：除了双 CRC + 互指（我们 `linux-gpt-apply.sh` 已有），还要在读回时**逐字节**比，并且**把 LUN 与 4096 扇区单位写进日志**（PITFALLS #669 的"第二把尺子"）。
   参考：`gpt_read_sectors` 的 clamp（`edl.rs:866`）与 `GPT_READ_TAIL_MARGIN`（`:864`）—— 我们如果遇到"printgpt 能解但读回不一致"，先怀疑**USB 末扇区短读**，用多读 2 扇区规避。

5. **实验前必须采集并落盘的"会失败的状态"**：任何会改 `boot_a/boot_b`、切启动盘、反复重启的动作前，先 `slot-attr.py show` 原始行 + `fastboot getvar current-slot` 写进日志（失败路径也保留），结束后 `mark-successful` + 补 retry 并再贴一次 `show`。
   参考（反面教材）：LTBox 完全不做这件事，`set_active_slot_a` 直接 reset 走人（`edl.rs:1579` / `full.rs:1824`）；正面纪律见 PITFALLS #672 与 `scripts/slot-attr.py` 头注释。

---

## 附：评估用到的命令（全部只读）

```bash
grep -rn "UNBOOTABLE|unbootable|BOOT_SUCCESSFUL" crates/          # 0 命中 → D 结论
grep -n "gptman" crates/ltbox-device/src/edl.rs                  # 5 处，全 read_from → GPT 只读
grep -rn "verify|readback|sha256" crates/ltbox-device crates/ltbox-patch   # 回读只存在于 country 路径
grep -n "pub fn " crates/ltbox-device/src/edl.rs crates/ltbox-device/src/fastboot.rs   # fastboot 无 flash/erase
```

---

## 9. 落地账（P0 六条，主机侧、可离线验证）

判据只搬**判据**，不引 LTBox 的 GPL 代码、不编它的 crate、不接 MCP（结论见 §0 C）。

| P0 | 判据 | 落地位置 | 提交 | 门 |
|---|---|---|---|---|
| P0-1 | rawprogram 全节点预检（字段完备 + 引用件存在） | `scripts/rawprogram-preflight.py`（R1/R5） | `8d615a01`+`48b9652b` | doctor §18 |
| P0-2 | destructive 节点缺 LUN/sector 直接拒 | 同上 R1 | 同上 | doctor §18 |
| P0-3 | `start+count` 落 LUN 容量内 | 同上 R2（`--gpt-for` 多 LUN） | 同上 | doctor §18 |
| P0-4 | 镜像 sector 数 vs 分区 span（全有或全无） | 同上 R4（sparse 头按 expanded size） | 同上 | doctor §18 |
| P0-5 | 写前重读 GPT 复验快照（与备份/预期一致）+ 重名拒绝 | `scripts/gpt-preflight.py`（`check`/`snapshot`/`verify`/`compare`）；`linux-gpt-apply.sh` 内联 python 换成 `compare` + 落 `pre-write-snapshot.json` | 本轮 | doctor §21 |
| P0-6 | dump 只认 `PartitionNotFound` | `scripts/dump-verdict.py`（三值 present/absent/error）+ `scripts/lib-dump-verdict.sh`；`t2-stock-lun45.sh` 去掉 `qdl read … \|\| true`，写前基线与写后读回都过判定 | 本轮 | doctor §21 |

**P1/P2 未做**（P1-1..P1-7、P2-1..P2-5）：判据与代码位置见 §1 表，处置队列登记在
`.pi/plans/2026-11-18-脚本审查修复BACKLOG.md`（LTBox 段）。其中 P1-1（短读即失败 + 原子发布）
已由 `dump-verdict.py` 覆盖「短读即 error」这一半，**原子发布（临时件 + fsync + rename）仍未做**。

**判据口径的两处有意收紧**（比 LTBox 更保守，写在这里以免以后被当成"抄错"）：
- `verify`：`attr` 变化默认只是 WARN（槽属性基线本来就随实验变），`--strict-attr` 才升 FAIL；
- `absent`：必须同时满足「rc≠0 + 只有 not-found 签名 + 没有传输签名 + 没留下非空半件」，任一不满足都落 `error`。
