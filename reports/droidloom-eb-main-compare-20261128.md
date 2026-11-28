# T42 残留：EvilBorsch eb/main 三条 commit vs 我方 00{2,3,4} 逐 hunk 对比（2026-11-28）

- 只读分析 + 本报告一份；未改任何其他文件，未 commit，未上设备，未 clone（commit patch 走 GitHub `.patch`/API `.diff`，rules 文件走 contents API raw）。
- 上游基线：`denialwm/droidloom` main = `e6f18c4`（release 52）；`EvilBorsch:eb/main` = `a0dd66c`，ahead 25 / behind 0（`reports/droidloom-fork-survey-20261128.md` §2.1）。

## 0. 一句话结论

**我方 `00{2,3,4}` 三条 patch 的 diff 正文与上游三条 commit 字节级等同（004 仅邮件头格式不同），本来就是同一批 commit 的搬运 —— 无「照抄替换」工作可做；判定 = 「已替换/等同」，退役条件沿用各 patch 头部 `Retire:` 行。** `60-droidloom-loop.rules` 建议纳入（纯宿主 udev 标记，不触三条上机判据，零运行时风险）。

## 1. 三条 commit 总表

| sha（短/全） | 标题 | 改动文件 | 规模 | 取证方式 |
|---|---|---|---|---|
| `201000a` / `201000a7a50f3bc3f6f15d7b4e6449bd75d2136e` | package-support: Find runuser in /usr/sbin too | `runtime/droidloom-package-support/src/main.rs` | +13 / −2，2 hunk（`@@ -424,9`、`@@ -476,7`） | API `Accept: vnd.github.v3.diff` |
| `5380af3` / `5380af354f4a1d027d365f58c26a481bf2676064` | supervisor: stop Android without unshare --forward-signals | `runtime/droidloom-supervisor/src/development.rs` | +75 / −2，3 hunk（`@@ -380,7`、`@@ -490,7`、`@@ -559,6`） | `github.com/.../commit/5380af3.patch` |
| `2712d37` / `2712d37c58d38ef4f1d4586ef07e5d1596ea7246` | supervisor: host resolvers in the lease, stop Android by powering it off | `development.rs` + `development_network.rs` + `dhcp_responder.rs` | +154 / −90，15 hunk（`@@ -380,14`、`@@ -585,54`、`@@ -16,7`、`@@ -24,14`、`@@ -104,7`、`@@ -493,9`、`@@ -49,7`、`@@ -311,8`、`@@ -427,12`、`@@ -472/488/507/515/548/559`（tests×7）） | `github.com/.../commit/2712d37.patch` |

## 2. 逐 hunk 判定表

对比方法：剥离我方 patch 头部 `# Patch/Source/...` 注释行后与上游 patch 正文 `diff -u` 逐字节比。

| 上游 hunk（sha @ 文件:旧起始行） | 内容 | 对应我方 patch | diff 结果 | 判定 |
|---|---|---|---|---|
| `201000a` @ `main.rs:424` + `main.rs:476` | 新增 `fn runuser()` 双路径探测（`/usr/bin`→`/usr/sbin`），两处调用点改用之 | `004-runuser-sbin-path.patch` | **hunk 正文逐字节等同**；唯一差异 = 我方文件保留了 commit 邮件头（From/Subject/stat，GitHub API `.diff` 格式天然不带） | **等同（已替换）** |
| `5380af3` @ `development.rs:380` | 新增 `signal_namespace_init()`：pidfd 打开 owner 之子、校验父子关系后直发 SIGTERM | `002-remove-forward-signals.patch` | **整文件字节等同**（133 行 vs 133 行） | **等同（已替换）** |
| `5380af3` @ `development.rs:490` | `start_development_cell` 删 `--forward-signals` 参数（−1 行） | 同上 | 同上 | **等同** |
| `5380af3` @ `development.rs:559` | recover 路径 +68 行（pidfd 信号辅助函数块） | 同上 | 同上 | **等同** |
| `2712d37` @ `development.rs:380` | stop 序列改 power-off（`sys.powerctl=shutdown`） | `003-host-resolvers-in-lease.patch` | **整文件字节等同**（430 行 vs 430 行，含 15 hunk） | **等同（已替换）** |
| `2712d37` @ `development.rs:585` | `namespace_init` 简化（−54/+21，删除 5380af3 引入的 pidfd stop 路径中与之重叠的部分） | 同上 | 同上 | **等同** |
| `2712d37` @ `development_network.rs:16,24,104,493` | lease 读宿主 `/run/systemd/resolve/resolv.conf`→`/etc/resolv.conf`（IPv4、非 loopback、≤2 条），写进 DHCP 选项 6 + 测试 | 同上 | 同上 | **等同** |
| `2712d37` @ `dhcp_responder.rs:49,311,427` | `Lease` 增 `dns` 字段、`reply()` 填充、checksum 签名适配 | 同上 | 同上 | **等同** |
| `2712d37` @ `dhcp_responder.rs:472–559`（tests×7） | 测试字面量 `1.1.1.1/8.8.8.8` → 宿主 resolver | 同上 | 同上 | **等同** |

**统计**：3 条 commit、20 个 hunk，全部「等同（已替换）」；0 条需要「并存」；0 条需要「丢弃」。

## 3. 顺序 / fuzz 事实核正

- 上游 `eb/main` 上 `5380af3`（2026-11-22T11:21+0300）**先于** `2712d37`（同日 13:23）提交，与我方 BUILD.md §1 的「003 必须在 002 之后」**同序** —— 依赖是上游固有的，不是我们造成的。
- 我方 003 需 `fuzz=2` 的原因：对 **source-51 原始树**打（`development.rs:380/585` 上下文被 002 改过）；上游树两条都在，**不存在 fuzz 问题**。若未来改用 eb/main 树或上游吸收了两条 commit，003 的 `--fuzz=2` 标注即可撤销（见 §4）。

## 4. 可退役性（按三条上机验收点）

三条 patch 我方 2026-11-27 已实测全绿（`patches/local/droidloom-local-20261127/BUILD.md` §4：① `Android is ready` ② 移走 unshare shim 后进程行无 `--forward-signals` ③ lease DNS = `[223.5.5.5, 202.38.64.18, …]` 且 `dl_dns_redirect` 计数 0）。因与上游字节等同，「替换」无动作；退役照旧由上游吸收触发：

| patch | 退役条件（原样沿用 + 本轮精确化） |
|---|---|
| `004` | 上游 main 的 `package-support/src/main.rs` 出现双路径 `runuser()`（`Retire:` 注释判据，`grep '"/usr/sbin/runuser"'` > 0） |
| `002` | 上游 main 的 `development.rs` 无 `--forward-signals`（`strings /usr/bin/droidloom-supervisor \| grep -c forward-signals` == 0，或发行版 util-linux ≥ 2.42） |
| `003` | 上游 main lease 读宿主 resolver（`strings /usr/bin/droidloom-supervisor \| grep -c resolv.conf` > 0 且 cell DNS ≠ 1.1.1.1/8.8.8.8）；届时同轮撤销 fuzz=2 标注 |

## 5. `60-droidloom-loop.rules` 建议：**纳入（低风险，独立于三条 patch）**

- 位置：`packaging/eb-ubuntu/debian/droidloom-runtime/added/usr/lib/udev/rules.d/60-droidloom-loop.rules`（`ref=eb/main`，contents API 取证）。
- 内容（全文 1 条规则）：对 `loop*` 且 `ATTR{loop/backing_file}` 匹配 `/usr/lib/droidloom/*|/var/lib/droidloom/*|…/apex/*|/data/app-staging/*` 的块设备置 `ENV{UDISKS_IGNORE}="1"` —— 只影响 udisks/文件管理器的**显示**，不影响 mount、不影响 supervisor、不触判据①②③任何一条。
- 收益：消除磁盘工具里 49 个 loop 卷的噪声（survey §5 表）；成本 ≈ 0；回滚 = 删一个文件 + `udevadm control --reload`。
- 注意：它是 `.deb` 打包路径下的产物，我们是 pacman 包 repack + 手工部署，落地时应直接放 `/usr/lib/udev/rules.d/` 并记入回滚清单；`backing_file` glob 需与我们的镜像实际挂载路径核对（我们用 `/usr/lib/droidloom/current` 软链，通配 `*` 可覆盖，但 apex 路径要上机确认一次）。

## 6. 净建议（一行）

**零替换动作（00{2,3,4} 与上游三条 commit 字节等同，维持现役 + 原 Retire 判据）；新做两件：① 把 `60-droidloom-loop.rules` 抄进宿主 `/usr/lib/udev/rules.d/`（下次上机顺带），② 上游吸收任一条时按 §4 表退役对应 patch。**

## 7. 不确定项

1. `eb/main` tip `a0dd66c` 是否仍 `behind 0`（本轮未重取 compare；survey 取证时点为 11-27 17:39 push）。
2. rules 文件的 apex `backing_file` 路径 glob 是否与 Y700 实际挂载路径全匹配 —— 需上机 `lsblk -o NAME,BACKING_FILE` 或 `/sys/block/loop*/loop/backing_file` 抽查（本轮无设备授权）。
3. 上游 release 52/53 是否吸收这三条（决定 §4 退役时点）—— 需在下一 release 对 source 树跑 §4 的 grep 判据。
4. `201000a` 上游取证只拿到 API `.diff`（`.patch` 端点三次超时），邮件头比对基于我方文件自带的头部文本；diff 正文层面的等同是字节验证的，不受影响。

## 附：取证命令

```sh
timeout -k 5 40 curl --noproxy '*' -m 30 -sSL https://github.com/EvilBorsch/droidloom/commit/5380af3.patch   # 200，133 行
timeout -k 5 40 curl --noproxy '*' -m 30 -sSL https://github.com/EvilBorsch/droidloom/commit/2712d37.patch   # 200，430 行
curl -H 'Accept: application/vnd.github.v3.diff' https://api.github.com/repos/EvilBorsch/droidloom/commits/201000a  # .patch 端点超时后改走 API，35 行
curl -H 'Accept: application/vnd.github.v3.raw' 'https://api.github.com/repos/EvilBorsch/droidloom/contents/packaging/eb-ubuntu/debian/droidloom-runtime/added/usr/lib/udev/rules.d/60-droidloom-loop.rules?ref=eb/main'
# 逐字节对比：剥离 '# ' 注释头后 diff -u，00{2,3} 全等；004 除邮件头外全等
```
