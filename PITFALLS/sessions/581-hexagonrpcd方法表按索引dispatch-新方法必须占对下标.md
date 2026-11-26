# #742 · `hexagonrpcd` 的 `apps_std_procs[]` **按方法号当索引**：加新方法时必须占对下标且 `n_procs` 等于表长，否则越界读全局区（ASan 一次定位）

- 日期：2026-11-27（`#692` 收口后的补丁加固）
- 现象：服务 attach 末尾 SIGABRT，`free(): invalid next size (fast)`；systemd `NRestarts=1`。
- 根因（ASan 原文）：`global-buffer-overflow … READ of size 8 at …`，`invoke_requested_procedure()`（`listener.c`
  `impl = &ifaces[handle]->procs[method]`）读了 `apps_std_procs` 之后 32 字节 —— 因为我们把方法 34/35/36 的实现
  **紧接在 `stat`(31) 之后**（实际落在下标 32/33/34），而 `n_procs` 写成了 57 ⇒ DSP 调 36 时读越界。
- 判据/做法：
  - 表是 `procs[method]` 直取 ⇒ **未实现的方法要显式留 `{ .def = NULL, .impl = NULL, }` 占位**，不能靠"跳过"；
  - `n_procs` 必须**等于表长**（本次修完 = 37），既不能少（方法被当越界拒），也不能多（读越界）；
  - 加方法后的自检：`grep -c '\.def =' hexagonrpcd/apps_std.c` 与 `n_procs` 对账 + 交叉 ASan 跑一发。
- ASan 复现手法（aarch64 交叉、静态 libasan、先 `systemctl disable --now` 让 listener 槽位空闲、重启后再跑、
  报告落 `/tmp/asan.out`）：见 `reports/hexagonrpcd-heap-oob-20261127.md` §2。
- 关联：`#741`（attach 三必踩）、补丁 `patches/userland/hexagonrpc-write-20261127/`。
