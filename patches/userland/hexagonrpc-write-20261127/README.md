# hexagonrpcd：允许 registry 写 + 放大 listener 输入缓冲（本地草稿，未上游投递）

- 基线：`linux-msm/hexagonrpc` **`da7a374`（v0.5.0+，2026-10-01）** —— 从 GitHub 浅克隆后 `git diff` 生成，**未改上游任何分支**。
- 动机：`reports/hexagonrpc-upstream-registry-write-20261127.md`。SM8750 的 sensors PD 在 attach 时要写
  `/persist/sensors/registry/**`，v0.5.0 的 `apps_std_fopen_with_env()` 对 `w`/`a` 直接 `AEE_EUNSUPPORTED` ⇒ DSP 断言
  （我们这代板子表现为**整机静默复位**，`PITFALLS #737`；同族 X1P42100 表现为 ADSP SSR，见上游 issue #29）。
- 本补丁做六件（**369 行 diff / 约 190 行代码**）：
  1. `apps_std_fopen_with_env()`：`w`/`a` 不再拒绝（仍以只读方式打开；写内容**不落盘**）。
  2. 新增 `apps_std_fwrite`（method 5）与 `apps_std_fwrite_def`：恒返回 `written = buf_size, is_eof = 0`（假成功）。
  3. `listener.c`：输入缓冲 `char inbufs[256]` → **堆上 512 KiB**（`HRPC_INBUFS_MAX`），>256 B 的 registry 内容不再被拒。
  4. `rpcd_builder.c`：`/persist/sensors/registry/` 下**补挂** `sns_reg_version`、`parsed_file_list.csv`（原只挂 `registry/` 子目录）。
  5. 新增 `fopen_fd`(34)/`fclose_fd`(35)/`fopen_with_env_fd`(36) 三个方法的实现（DSP 在 attach 末尾必调 36，未实现会让服务退出）。
  6. `apps_std_interface.n_procs` 32 → 57（否则 method 34–36 在查表前就被当越界拒掉）。
- 验证（本机）：`meson setup /tmp/hrpcd-build . && ninja -C /tmp/hrpcd-build` **全绿**；`meson test` **3/3 OK**
  （`iobuffer`/`hexagonfs`/`hexagonrpc`）。**未上机、未交叉编译到 aarch64。**
- 已知局限（务必先读再上机）：
  - **写不持久**：DSP 每次 attach 会重放写请求；若其判定"写完仍未生效"会再次断言 ⇒ 上机前要按报告 §5 的风险协议准备（预期整机复位 → 自动回 `boot_b`）。
  - `fwrite` 一律假成功，包括非 registry 路径的写（当前 0.5.0 没有任何写后端）。
  - `mkdir/rmdir/ftrunc/fremove/frename`（method 24/33 等）**未实现**；上游 issue #29 说它们的固件需要，我们的 SM8750 是否需要未取证。
  - 与上游进度可能冲突：`apps_std.def` 在 PR #21 里是另一套生成机制；本补丁按 v0.5.0 的 `interface/apps_std.c` 手写 def。
- 应用方式：
  ```sh
  git clone --depth 1 https://github.com/linux-msm/hexagonrpc /tmp/hrpcd && cd /tmp/hrpcd
  git apply /path/to/0001-hexagonrpcd-allow-registry-writes-and-large-inbufs.patch
  ```

## 0002-writable-overlay.patch（**已部署，2026-11-27**）

在 0001 之上加一个**真可写 overlay**：`-O DIR`（设备上 `/var/lib/hexagonrpc`，`fastrpc:fastrpc`）。
- `hexagonrpcd/overlay.{c,h}`：overlay 根 + 父目录自动创建 + `stat/open/read/write/seek/fsync/ftrunc/remove/rename/mkdir/rmdir`。
- `apps_std`：写模式打开→先 `copyup()`（把 mapped 树的原文拷进 overlay，不存在则建空）→ `open(O_RDWR[|O_APPEND])`；
  返回 fd 加 `OVERLAY_FD_BASE(1000)` 与虚拟 fd 区分；`fread/fwrite/fseek/fclose/fsync` 按区间分派。
- 方法表改成**指定下标初始化**（`[N] = {...}`），并补 `fwrite(5)/ftell(8)/flen(10)/fileExists(22)/fsync(23)/fremove(24)/frename(33)`；
  **`fwrite` 的 def 是 `WORD(fd) + BLOB_SEQ(data) + OUT_BLOB + OUT_BLOB`**——`in sequence<byte>` 的 size word 就在 prim buffer 里，
  定义里**不能再多写一个 WORD**（这是本轮上机报 `Method 5 invoked with less arguments` 的真因）。
- `listener.c`：**签名不匹配不再 abort 整个监听循环**（回复 `AEE_EBADPARM` + 4 字节零 outbuf 继续服务），
  这样某个方法签名猜错不会把 DSP 挂在半 attach 状态（也是本轮能继续迭代的关键）。

实测（设备，`2026-11-27`）：`elden-sensorspd` active、`NRestarts=0`、三属性 true、`ssccli` 连续出值；
overlay 里出现真实写入 —— `cam_registry_dump.txt` 18.6 KB、`fstempfile` 14.3 KB、`sns_reg_version` 9 B、`registry/DIR` 3 B。

> **已被 `../hexagonrpc-pr31-20261127/` 取代（2026-11-27）**：本目录两枚补丁是本地草稿（overlay 在 `apps_std` 层、无读回落、无单测），现已整理为上游 PR #31 的 6 个提交。保留作证据。
