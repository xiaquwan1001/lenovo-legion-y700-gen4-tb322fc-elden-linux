# hexagonrpcd：允许 registry 写 + 放大 listener 输入缓冲（本地草稿，未上游投递）

- 基线：`linux-msm/hexagonrpc` **`da7a374`（v0.5.0+，2026-10-01）** —— 从 GitHub 浅克隆后 `git diff` 生成，**未改上游任何分支**。
- 动机：`reports/hexagonrpc-upstream-registry-write-20261127.md`。SM8750 的 sensors PD 在 attach 时要写
  `/persist/sensors/registry/**`，v0.5.0 的 `apps_std_fopen_with_env()` 对 `w`/`a` 直接 `AEE_EUNSUPPORTED` ⇒ DSP 断言
  （我们这代板子表现为**整机静默复位**，`PITFALLS #737`；同族 X1P42100 表现为 ADSP SSR，见上游 issue #29）。
- 本补丁做四件（**87 行**，最小面）：
  1. `apps_std_fopen_with_env()`：`w`/`a` 不再拒绝（仍以只读方式打开；写内容**不落盘**）。
  2. 新增 `apps_std_fwrite`（method 5）与 `apps_std_fwrite_def`：恒返回 `written = buf_size, is_eof = 0`（假成功）。
  3. `listener.c`：输入缓冲 `char inbufs[256]` → **堆上 512 KiB**（`HRPC_INBUFS_MAX`），>256 B 的 registry 内容不再被拒。
  4. `rpcd_builder.c`：`/persist/sensors/registry/` 下**补挂** `sns_reg_version`、`parsed_file_list.csv`（原只挂 `registry/` 子目录）。
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
