# hexagonrpc PR 准备台账（可写 overlay，承接 #29 回帖的承诺）

> 2026-11-27 立。口径：`AGENTS.md` §7「投递按系列逐次批准」⇒ 备料/门禁/文本起草不等放行，**fork 推送与开 PR 需用户批准**。

## 1. 结论

能做成 PR，且上游方向与我们一致：

- `linux-msm/hexagonrpc#21`（维护者 z3ntu 自己的 open PR）已经画出**同一套**方案：
  读先查 `/var/hexagon-dsp/$f`、再查 `/usr/share/qcom/$f`；写模式则 copy-up 到可写目录；
  lumag 指定落点 `/var/hexagonrpcd`。PR #21 至今只有 stub（无真写）。
- `#27`（FadyAckad，934 行写侧）是**作者本人关的**（timeline: closed by FadyAckad，1 h 后，无 review 评论），不是被维护者否决。
- 我们有 #21 缺的东西：**真机闭环**（TB322FC 上 DSP 真写 registry、iio-sensor-proxy 三属性 true + 实测出值）。

## 2. 分支现状（已建，绿）

- 工作区：`~/src/hexagonrpc-pr`（`/tmp/hexagonrpc` 的副本，base = `da7a374`，origin = linux-msm/hexagonrpc）
- 分支：`writable-overlay`，6 个 commit，**每个 commit 单独 meson setup+ninja+test 全绿**：

| commit | 内容 |
|---|---|
| `58e6214` | `interface/apps_std`: fwrite(5) 及 ftell/flen/fileExists/fsync/fremove/rmdir/ftrunc/frename/fopen_fd(34)/fclose_fd(35)/fopen_with_env_fd(36) 方法定义（含 fwrite 的 size-word 内联口径） |
| `ce6e6a5` | `listener`: inbuf 上限 256 B → 512 KiB；签名不符回 `AEE_EBADPARM`+零 outbuf 继续监听（不再拆掉 listener） |
| `2960a69` | `hexagonrpcd`: 写侧实现 + `overlay.c/h`（copy-up，`OVERLAY_FD_BASE` 虚拟 fd） |
| `98da3ff` | `rpcd`: `-O DIR` |
| `7530f7f` | `rpcd_builder`: 映射 `sns_reg_version` / `parsed_file_list.csv` |
| `0e3225f` | man page：`-O` 与 overlay 语义 |

文本对齐：整个系列带 `Signed-off-by` + 「AI 辅助、作者复核并上机复现」说明（不用私有 trailer）。

## 3. 开 PR 前仍需补的（真实缺口，不是形式）

1. **读路径没有 overlay-first**：现在 `apps_std_fopen`（只读）只走 mapped 树，overlay 里 DSP 写过的文件在下次 attach 读不回来 —— 与 man page 语义和 #21 讨论不一致。必须补「读先查 overlay 再回退 mapped」。
2. **层次**：overlay 目前挂在 `apps_std`（fd ≥ 1000 分派），绕过了 `hexagonfs_*` 抽象。维护者方案是文件系统级的，review 大概率要求搬到 `hexagonfs`（新增 openat 可写/write/fsync/ftrunc ops 或 `hexagonfs_overlay` 后端）。做完 1+2 ≈ 把 overlay 重写成 hexagonfs 后端（~300–400 行）。
3. **单测**：`tests/` 只有 iobuffer/hexagonfs/hexagonrpc，CI 跑 `ninja test`。需加 `tests/test_overlay.c`（copy-up、fd 分派、seek/trunc/rename、读取回落），否则 reviewer 会要求。
4. 细节：`overlay_stat()` 用 `static char path[]`（单线程假设要写进注释）、`fopen_with_env_fd` 目前忽略 env 变量只用固定 dirfd（需在 PR 里如实说明验证过的面）。

## 4. 建议投递形状

- **PR-A（可立即）**：commit 1/2 + `apps_std`/`rpcd_builder` 两个小修 —— 独立、无争议、每条都有上机依据。
- **PR-B（补完 1–3 后）**：overlay 重写为 hexagonfs 后端 + 单测。
- 两段都附：真机验收命令与输出、AI 披露、以及 #21 的对应关系（作者 z3ntu，避免抢他的活：先在该 PR 里问一句「是否愿意我把 overlay 补到这个分支上」）。

## 5. Gate

- 门禁前必跑：`ninja -C <build> test` 全绿 + 每个 commit 单独可编（已做）。
- 推送/开 PR 前需用户放行（§7），并确认 GitHub 身份 = `xiaquwan1001`（`gh auth status` 已登录，无现成 fork，首次推送会建 fork）。

## 6. 2026-11-27 第二轮（已放行后）

- **PR #31 已开（draft）**：https://github.com/linux-msm/hexagonrpc/pull/31
  - 分支 `writable-overlay` 已**重写为 6 个提交**并 force-push（旧 6 提交作废）：
    1 `interface/apps_std` 方法定义（fwrite 5/fsync 23/fremove 24/frename 33/fopen_fd 34/fclose_fd 35/fopen_with_env_fd 36）
    2 `listener`（inbuf 512 KiB + 签名不符不拆监听）
    3 `hexagonfs` 写层（`hexagonfs_openat_write()` + overlay-first 读 + vpath + 零初始化 fd + copy-up + `-R`-only 文件禁删/改名 -EPERM）
    4 `rpcd -O DIR` + man page
    5 `rpcd_builder` 映射 `sns_reg_version` / `parsed_file_list.csv`
    6 `tests/test_overlay.c`（copy-up / 回读 overlay-first / rename / remove / -EPERM）
  - 逐提交 `meson setup + ninja + ninja test` 全绿（4/4 测试），无编译告警。
  - GitHub：**DCO pass**；`Build+test` = `action_required`（首次贡献需维护者批准才跑 CI），非我方问题。
- **#21 已留言**（comment 7208156729）：说明 #31 实现了 z3ntu 在此画的方案，并问是否要 rebase 到 #21 分支。
- 与 11-27 上机版本的差异：硬件跑的是「overlay 分派还在 apps_std」的旧版；现在这版只做了构建+单测，**未上机**。PR 正文已如实写明，并承诺上机后再转 ready。

## 7. 下一轮（上机复验，需设备空闲）

1. 交叉编译：aarch64（`gcc-aarch64-linux-gnu` + meson cross file；参照 `reports/README.md` 的 hexagonrpc 构建段）。
2. 上机前备份现役二进制：`/usr/bin/hexagonrpcd` 实际是 `dpkg-divert` 后的符号链接 → 目标 `/usr/libexec/hexagonrpc/hexagonrpcd`
   （现役 sha256 `97fda0c9…eb14`；回滚 = 还原该文件 + `systemctl restart elden-sensorspd`）。
3. 部署新二进制 → `systemctl restart elden-sensorspd` → 判据：
   `systemctl is-active`=active、`NRestarts`=0、三属性 true、`ssccli` 出值、overlay 目录 4 个非空文件、真重启后仍成立。
4. 顺带定 `'w'` 是否应 `O_TRUNC`（PR 里留了问题），两种都测再回报。

## 8. 2026-11-27 第三轮（上机复验完成）

- **上机通过**（真重启、overlay 空目录）：`active` / `NRestarts=0` / `--failed` 空 / 三属性 true / `ssccli` Z≈±9.54；
  overlay 4 文件真落盘（18628 / 6851 / 9 / 3 B）。
- 部署二进制 sha `0a8ef526…a8afd92d7` → `/usr/local/bin/hexagonrpcd-patched`；回滚件 `.bak-20261127` = `4a7946b2…c192f7f`。
- **写验收触发条件**：正常 boot 读 `-R/sensors/registry/sns_reg_version` 就不写；要把该文件从 `-R` 移走（first attach 等价）才进写路径，验完已还原。
- **部署坑**：`-O` 目录须预建且对 `fastrpc` 可写，否则 `Could not initialize write overlay: Permission denied`（写侧静默关闭）。man page 已写；本仓待补 `tmpfiles.d`。
- PR #31 已 **ready for review**；正文含本节数字；DCO pass、CI 等维护者批准。
- 补丁原文入库 `patches/userland/hexagonrpc-pr31-20261127/`；报告 `reports/hexagonrpcd-overlay-hexagonfs-20261127.md`；双推 `d19b530da`；`check-doctor` FAIL=0 / WARN=3（存量 C 类）。

## 8b. 2026-11-27 第四轮（tmpfiles + `'w'` A/B）

- `packaging/elden-userland/extra/etc/tmpfiles.d/hexagonrpc.conf` 新增（系统侧预建 `/var/lib/hexagonrpc 0755 fastrpc fastrpc`），
  `extra/README.md` 登记；非 systemd 侧等价物写在文件注释里（initd `start_pre: install -d`）。
- **`'w'` 的 A/B 定案：不能 `O_TRUNC`** → `PITFALLS #744`；现象 = `fstempfile` 6851→699 B、`HasAccelerometer/HasProximity` 变 false，
  但 `ssccli` 仍出值（所以判据必须看 overlay 字节数 + 三属性）。
- 分支重写为不截断版本（`5aed5eb`），逐提交构建+测试 6/6 绿；**最终二进制 sha `32a7d2c4…3ec47fce20`** 已部署并真重启复验：
  三属性全 true、`NRestarts=0`、overlay 18628/6851/9/3 B。
- PR 正文更新（A/B 数据 + 新 sha）；补丁原文按最终分支重新导出。
- `verify.sh` 现存 2 条 FAIL 是本轮之前就有的设备/仓库漂移（`qbootctl.service.d/override.conf`、`charge-watch.sh`），未处理，登记在此。

## 9. 下一轮候选

1. 本仓补 `packaging/elden-userland/files/etc/tmpfiles.d/hexagonrpc.conf`（`d /var/lib/hexagonrpc 0755 fastrpc fastrpc -`），避免装机时踩上面那条坑。
2. `'w'` 的 `O_TRUNC` A/B：改一行 + 交叉编译 + 部署 + 重启看 registry 是否仍正确（两轮重启，约 10 min）。
3. 看 PR #31 / #21 有无维护者回复（异步）。
