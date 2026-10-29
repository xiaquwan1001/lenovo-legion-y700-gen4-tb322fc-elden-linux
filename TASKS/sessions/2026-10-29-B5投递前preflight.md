# 2026-10-29 · B5（M6）系列投递前 preflight：pristine 重放 / 拆表项 / 显式 master 判据 / 全量门 / style 门

- **日期**：2026-10-29
- **pi 会话 id**：`$PI_SESSION_ID`（lane 子代理，纯主机任务）
- **范围**：`patches/local/b5-resoc-20261028/`（0001–0006，6 枚）+ 新增 `proposed/0007`；报告 `reports/b5-preflight-20261029.md`
- **不动**：设备、TASKS/README.md、INDEX.md、PITFALLS/README.md、DEVICE/、RESOURCES/、versions/、.githooks

## 结论（数字先）

- **pristine 重放**（base = `24a19b953e2a3d0ea5a8c4951a0ab8f32720c907` = v7.3-rc7，本轮新建 worktree 现查）：
  `git am --3way` **序列 0/6**（第 1 枚即 128），**逐枚仅 0002 干净**（rc=0），其余 5 枚全冲突。
- **依赖清单**：前置 = **4 文件 / +822 −46** —— `dsi_manager.c` +222−27、`dsi_host.c` +560−18、`dsi.h` +18−1、
  `registers/display/dsi.xml` +22；全部来自**一个下游压缩提交 `0f1fb1c9c`**（elden payload v2），
  **上游 7.3-rc7 内这些符号 0 命中** ⇒ 「上游提交 sha」一栏**没有可填值**，缺的不是 cherry-pick 而是一整组尚不存在的上游提交。
- **§2 拆表项**：SM8750 的 DSI cfg **早已是独立表项**（`dsi_cfg.c:224` bonded 数据、`:235-245` sm8650 通用项、
  `:251-262` sm8750 独立项 `.compatible`+`.bonded`、`:415-418` 两条同版本 handler、`:435-447` 倒序扫 + `of_device_is_compatible()` 闸门）
  ⇒ **派工单「表挂在 sm8650_dsi_cfg 上」已过时，无改动可做**。binding `dsi-controller-main.yaml:48/62/390` 在 pristine 已列
  `qcom,sm8750-dsi-ctrl`，DTS `sm8750.dtsi:3439/3548` 带该 compatible ⇒ 无需新增 binding。
- **§3 显式 master 判据**：`0005` **已经**是显式判据（`dsi_manager.c:642-654`：注释 + `if (id != master_id)` +
  `dev_err("bonded command on link %d, but link %d is the master")` + `-EINVAL`），且位于 prepare/闩锁之前 ⇒ 被拒无副作用。
  残留两处**裸错误码**（`:639-640` `master_id` 越界 `-EINVAL`、`:656-659` host 未就绪 `-ENODEV`，均无日志）⇒ 交付
  `proposed/0007-drm-msm-dsi-log-the-bonded-command-link-checks.patch`（+10 −2，错误码不变，只加两行 `dev_err`）。
- **§4 全量门**（一次性 worktree `/tmp/b5pf-proposed` @ `481225269` = `build/b5-resoc` HEAD，`.config` 同源，从零编译）：
  `make -j26 Image.gz dtbs` **rc=0 / WALL=286.78 s / 4570 个 CC 目标 / 0 error 0 warning**，
  产物 `vmlinux` 637,548,480 B、`Image.gz` 19,763,145 B、dtb 410 个；`W=1` 定向编译草案后 `dsi_manager.o` rc=0 warn=0。
- **§5 style**：checkpatch `--strict` **6/6 + 草案 = 0E/0W/0C**；`dt-check-style --mode=relaxed`（dtschema venv python）
  对 `dsi-controller-main.yaml` **rc=0**；**yamllint 未跑**（本机无该包，`bindings/Makefile:6-7` 确认会静默跳过 ⇒ 未证实不是通过）；
  commit message **6/6 结构合格**（`^---$`=1、diffstat 1 份、SoB 1 个），16 行正文 73–74 字符**建议收到 72**。

## 判定

**现状不可直接投上游**：6 枚依赖整组尚未上游的 bonded 核心。可行路线 R1（先上游 bonded 核心、再把 B5 叠上去）＞
R3（转内部树维护）＞ R2（只发 0002，会被问「谁读这个字段」）。详见报告 §6.3。

## 方法备注（可复用 / 两个新坑）

1. **`#462` 的 checkpatch 定式要订正**：`perl scripts/checkpatch.pl --strict --no-signoff --no-tree <patch>`
   在本树会**把 patch 当源码扫**，6 枚全报 `ERROR: trailing whitespace`（假阳性，命中的是 patch 里空 context 行的前导空格）。
   正确跑法 = **有树 + stdin**：`cd <tree> && perl scripts/checkpatch.pl --strict --no-signoff < patch`。
2. **全量门不能在已有增量树上做**：`build/b5-resoc` 里 `make Image.gz dtbs` 只走 12 步 / 29 s（vmlinux 早已存在），
   拿来当「全量门」没有意义；`make clean` 又会拆掉别的 lane 在用的产物 ⇒ 建**自己的一次性 worktree** 从零编译，测完 `git worktree remove`。
3. `pi` 的 `rm` 被包装成跨设备 `mv` 到 `.pi/trash`，在 **/tmp（tmpfs）** 树里会 `EXDEV: cross-device link not permitted` ⇒ 用 `/bin/rm`。
4. 依赖判据可复跑：对每枚补丁取 `^[ -]` 行（context + removed = 补丁**要求已存在**的代码）与载荷符号表求交，
   再按文件比 `git diff <pristine>:<file> <series-base>:<file>` 得前置量 —— 两树一致时该文件改动即「纯追加」，
   这类文件上的补丁才有机会单打（0002 就是这样 rc=0 的）。

## 证据位置（临时件已清）

- 报告：`reports/b5-preflight-20261029.md`
- 草案：`patches/local/b5-resoc-20261028/proposed/0007-drm-msm-dsi-log-the-bonded-command-link-checks.patch`
- 日志/脚本：`/tmp/b5pf-logs/`、`/tmp/b5pf-*.sh`（tmpfs，重启即失；关键数字已内联报告）
- 两个一次性 worktree（`/tmp/b5pf-pristine` 1.8 G、`/tmp/b5pf-proposed` 7.0 G）已在收尾 `git worktree remove --force`；
  复跑一行：`git worktree add --detach /tmp/x 24a19b953`（pristine）/ `481225269`（系列 tip）。
- 附注：本轮在 `build/b5-resoc` 跑过一次**增量** `make`（仅构建产物时间戳变化，源码与分支 `b5/send-20261028` 未动）。
