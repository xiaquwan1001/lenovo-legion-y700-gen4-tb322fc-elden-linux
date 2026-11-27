# hexagonrpc PR #31：可写 overlay（hexagonfs 层次版，已上机 + 已投递）

- 上游 PR：**https://github.com/linux-msm/hexagonrpc/pull/31**（ready for review，2026-11-27）
- 分支：`xiaquwan1001/hexagonrpc:writable-overlay`，基线 `linux-msm/hexagonrpc` **`da7a374`**
- 本目录 = `git format-patch da7a374..<分支>` 原文（6 个提交，可直接 `git am`），与 PR 逐字一致（`75f869d`）
- 工作区：`~/src/hexagonrpc-pr`（本机）；旧草稿 `../hexagonrpc-write-20261127/` 已被本目录取代（保留作证据）

## 与旧草稿（0001+0002）的区别

| 面 | 旧草稿 | 现在（PR #31） |
|---|---|---|
| 层次 | overlay 分派挂在 `apps_std`（fd ≥ 1000） | `hexagonfs_openat_write()` + overlay-backed 文件 ops；`apps_std` 无 overlay 逻辑 |
| 读路径 | 只读 `fopen` 只查 `-R`，**读不回自己写的文件** | overlay-first：`hexagonfs_openat()` 命中 overlay 即服务，目录/虚拟项仍走 `-R` |
| 路径 | apps_std 里手工传 vpath | `hexagonfs_fd.vpath` 由 `hexagonfs` 维护（backend 用 `calloc` 零初始化） |
| 只读树保护 | 无 | 只在 `-R` 里存在的文件 `fremove`/`frename` ⇒ **-EPERM** |
| 方法表 | 注册了未验证签名（ftell/ftrunc 等） | 只声明**观察到**的方法（5/23/24/33/34/35/36） |
| 单测 | 无 | `tests/test_overlay.c`（copy-up/回读/rename/remove/-EPERM），`ninja test` 4/4 |
| 编译告警 | 有 | 0 |

## 上机验收（2026-11-27，TB322FC，真重启，overlay 空目录）

- 二进制：`aarch64-linux-gnu-gcc` 交叉编译（`-Ddefault_library=static`，为静态链接临时把 `libhexagonrpc` 改 `library()`，**该改动不入提交**），
  部署 sha256 **`0a8ef526c4004b83dcfdc86d39a535d6631d53e830ddbdfb89201f0a8afd92d7`** → `/usr/local/bin/hexagonrpcd-patched`
  （回滚件：`/usr/local/bin/hexagonrpcd-patched.bak-20261127`，sha `4a7946b26a6605eb…c192f7f`）。
- 结果：`elden-sensorspd` **active / NRestarts=0 / systemctl --failed 空**；三属性 true；
  `ssccli --sensor accelerometer` 连续出值（Z≈±9.54 m/s²）；
  overlay 真写入 4 件 — `cam_registry_dump.txt` 18628 B、`fstempfile` 6851 B、`sns_reg_version` 9 B（`version=1`）、`registry/DIR` 3 B。
- 触发条件（重要）：**只有 DSP 决定持久化时才写**。正常 boot 会读到 `-R` 树里的 `sns_reg_version` 而不写；
  本次验收是临时把该文件从 `-R` 树移走（等价 first attach）才逼出写路径，验完已还原。
- 部署注意：`-O` 目录必须**预先存在且对运行用户可写**（`/var/lib` 下 unprivileged `mkdir` 失败 ⇒ 写侧静默关闭，日志
  `Could not initialize write overlay …: Permission denied`）。已在 man page 写明；发行版侧建议配 `tmpfiles.d`。

## 待办 / 未定

1. `'w'` 是否应 `O_TRUNC`（现在不截断，与上机版本一致；未做 A/B 上机）。
2. 未声明 ftell/flen/fileExists/ftrunc/mkdir/rmdir（签名属猜测）。
3. CI `Build+test` = `action_required`（首次贡献需维护者批准跑 workflow）；DCO 已 pass。
4. 维护者若要求把提交 rebase 到 #21 分支，直接 `git rebase` 本目录的 6 个 patch 即可。
