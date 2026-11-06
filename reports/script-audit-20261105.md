# 脚本工具审计与提速（2026-11-05）

> 范围：`scripts/` 下的检查/等待类工具（185 个 `.sh` + 24 个 `.py` 里的常用入口）。
> 唯一验收判据：**判定行逐行不变，墙钟显著下降**（`scripts/doctor/ab-bench.sh` 可重跑）。
> 结论：收尾门禁 12.5 s → **1.4 s**（冷缓存 4.5 s），入库前门 3.8 s → **0.4 s**；
> 设备侧等待从「固定拍 + 弱判据」改为「先判后睡 + 换代判据」，并修掉两处会误判的坑。

## 1. 实测基线（审计当天，主仓 4.4 G `out/` + 129 个镜像 + `build/daily` 在场）

逐命令时间差分析（`PS4='+$EPOCHREALTIME' bash -x scripts/check-doctor.sh 2>trace`）：

| 段 | 旧墙钟 | 性质 | 浪费点 |
|---|---|---|---|
| §6 静态卫生 | 3.75 s | 读 **22052 文件 / 473 MB** | `SKIP` 集漏了 `build/`（16738 文件 / 424 MB）；死脚本判定是 O(185×语料) 子串比较 |
| §5 vk 版本账 | 3.26 s | 129 个镜像 gzip 解压 | 每轮重解压全部历史镜像，无视已提交的 `versions/vk-kernel-identity.tsv` |
| §12 模块化门禁 | 3.25 s | `olddefconfig` 跑两遍 | 落在 fast 档 `fi` 之后 ⇒ **每次 commit 都要付** |
| §5f ABI | 1.05 s | `pahole` 读几百 MB vmlinux | 每轮重算 `of_node` 偏移 |
| 其余 10 段 | 0.9 s | 文本级 | — |
| **全量合计** | **12.5 s** | 全程串行 `$( )` | 上述四段彼此独立 |
| `--staged-fast` | **3.79 s** | 脚本注释与 `INDEX.md` 都写「~0.2 s」 | 就是 §12 那 3.25 s |

设备侧（静态审计，`sum(sleep)` / 轮询形态）：

| 脚本 | 旧形态 | 缺陷 |
|---|---|---|
| `cycle.sh` | `sleep 2` 先睡，60 拍（120 s） | 就绪也要白等一整拍 |
| `to-fastboot.sh` | 45×2 s，先睡后判 | 同上 |
| `kexec-boot.sh` | 60×3 s，只测 `ssh` 应答 | kexec 生效前旧内核还在答 ⇒ **假成功** |
| `flash-b.sh` | 90×2 s，`ping`+`ssh` | 同上 |
| `slot-switch.sh` | `wait_adb` 60×**5 s**（300 s），且用裸 `adb get-state` | 与同文件 `have_adb`（只认 `-s`，PITFALLS #371）**自相矛盾** ⇒ 总线上有第二台手机就误判 |
| `lib-boot-ready.sh` | 4–5 条**顺序** ssh（每条 10–15 s 超时） | 弱链路最坏 ~40 s；且 4 次探测跨秒，不是同一时刻快照 |

## 2. 落地

### 2.1 `check-doctor.sh`：649 行单体 → 调度器 + 12 个子门

- 子门在 `scripts/doctor/`，契约：只打印 `  [ok]/[FAIL]/[warn] 行`，**退出码不参与判定**
  （这样「并发调度」与「单独手跑」语义一致，也不会因一处 `set -e` 把判据变成静默跳过）。
- 子门**并发**执行（互不共享状态），各自落到 `mktemp` 文件后**按节序拼装** ⇒ 报告顺序不变。
- 新增 `--only <N>`（调试单一判据）、`--list`、`--json`；单门超时 600 s（`ELF_SEC_TIMEOUT`）。
- `--staged-fast` 剔除 §12（文档/索引提交与内核 `.config` 无关；手改 `.config` 由收尾轮全量兜住）。
- 判据本体**一行未改**：`s07-08-docs.py` 是把原 heredoc 原样搬出来，只把 `emit()` 从
  「打印 TAG」改成「收集后按 §7/§8 分组打印」。

### 2.2 三处重活各加一层缓存（都带明确的失效键，不用 TTL —— 时间不能证明结论有效）

| 文件 | 缓存键 | 冷 → 热 |
|---|---|---|
| `scripts/static-scan.py`（新，§6 抽出） | 语料改 `git ls-files`（2531 个纳管/未忽略文本，20 MB）；死脚本用 `grep -F`（Aho-Corasick）一次扫完 | 3.75 s → **0.11 s** |
| `scripts/vk-identity.py` | `(path, size, mtime_ns)` → 载荷 `(UTS, kbin_sha, status)` | 3.9 s → **0.23 s** |
| `scripts/check-modular-config.sh` | `.config` + 本脚本 + `ANCHORS` + `KDIR` + `CROSS` + 扫描目录里最新 `Kconfig` 的 `(mtime, path)` | 3.2 s → **0.06 s** |

缓存位置 = **仓库外** `${XDG_CACHE_HOME:-~/.cache}/elden-doctor/<root 路径哈希>/`
（每棵树一份，lane/worktree 互不串）。踩过的坑：第一版放 `$ROOT/.cache/`，
结果 `scripts/check-layout.sh`（§14）立刻把 `.cache` 判成「顶层条目未登记」= FAIL ⇒
工具自己把门禁弄红。缓存是可再生产物，跟机器走、不跟 git 走。

关闭方式（怀疑缓存脏时）：`static-scan.py` 走 `git` 实时语料（无持久缓存）；
`vk-identity.py --no-cache` / `VK_PAYLOAD_CACHE=off`；`check-modular-config.sh --refresh` /
`MOD_CFG_CACHE=off`。

### 2.3 设备侧等待：`scripts/lib-wait.sh` + `scripts/lib-ssh.sh`（新）

- `wait_until <标签> <超时> <探测>`：**先判后睡** + 退避 `0.3/0.5/1/1/2/2/3 s`，
  且最后一拍只睡「剩余预算」（旧自检显示 `$SECONDS` 整秒精度会让 1 s 预算在 0.8 s 就放弃）。
- 换代判据：`wait_reboot`（重启前拍 `boot_id`，只认它**变了**）与 `wait_fresh_boot`
  （拿不到指纹时用 `uptime < 上限` 证明是这一次开机）。
- `lib-ssh.sh`：统一 53 处内联的 `ssh -o …`（实测 7 种写法，其中不带 `BatchMode` 的会卡在密码提示），
  并提供 `S_kv` **一次往返取多个状态**。
- 接线：`cycle.sh`、`scripts/to-fastboot.sh`、`scripts/kexec-boot.sh`、`scripts/flash-b.sh`、
  `scripts/slot-switch.sh`（同时修掉 `wait_adb` 的序列号缺陷）。
- `lib-boot-ready.sh`：就绪判定 4–5 条 ssh → **1 条**（同一时刻快照）。
  自检用例抓到过这次改造最危险的形态：探针里 `$( )` 若用双引号包，会在**主机**上展开
  （主机 uptime 冒充设备 uptime，判据静默失效）—— 现已改为单引号并留了注释。

### 2.4 自检（无设备可跑）

`scripts/test-lib-wait.sh`：用 `$PATH` 前面的假 `ssh/fastboot/adb` 模拟设备，覆盖
「就绪时不付首拍」「超时预算准确」「**boot_id 未变期间不得判成功**」「adb 只认正确序列号」
「boot-ready 只发 1 条 ssh」等 16 项，全绿（`ALL PASS`）。

## 3. 验收数据（`scripts/doctor/ab-bench.sh`，主仓、基线提交 `aea0eab`、每组 3 次取中位数）

**审计当天**（`out/` 129 个镜像 + `build/daily` 在场，即最重的情形）：

| 档 | 旧版 | 新版（冷） | 新版（热） | 加速 |
|---|---|---|---|---|
| `--staged-fast`（pre-commit） | 3.78 s | — | **0.40 s** | **9.4×** |
| 全量 | 10.98 s | 4.54 s | **1.37 s** | 2.4× / **8.0×** |

判定行 48 行逐行相同，汇总行相同（`FAIL=0 WARN=5`，均为既有 WARN）。

**合入后复测**（另一 lane 收尾时把 `build/` 清掉了 ⇒ 旧版 §6 语料与 §12 olddefconfig
都不再有那么大，旧版自己也变快；这也说明「用比值当唯一判据」会随环境漂，
所以 `ab-bench.sh` 对 fast 档另设了绝对值上限 1.0 s）：

| 档 | 旧版 | 新版（冷） | 新版（热） | 加速 |
|---|---|---|---|---|
| `--staged-fast` | 0.66 s | — | **0.38 s** | 1.7× |
| 全量 | 5.06 s | 1.43 s | **1.43 s** | 3.5× / **3.5×** |

判定行（滤掉两条工具自身观测噪声后）47 行逐行相同，FAIL 行集合相同，`ACCEPT: PASS`。
> 观测噪声 = 旧版医生跑在「已含新子门」的树上：① §6a 把检查器自己当成了「设备锁块被复制」；
> ② 它的排版里少一条 `[ok] 设备锁单一真源`。这两条与判据无关，比对时显式过滤并在此留痕。

## 4. 未做 / 待验证

- **设备侧脚本未上机验证**：审计期间设备被另一 lane 的 UEFI 实验占用（`fastboot devices`
  有设备、`ping 192.168.7.1` 不通）。已做的是 `bash -n` + `shellcheck -S warning`（除两条
  既存 SC2034/SC2164 外无新增告警）+ stub 自检。**下一个设备任务应先跑一次
  `cycle.sh --wait` 与 `scripts/slot-switch.sh status`，确认升级后的等待语义正常。**
- `scripts/static-scan.py` 的 DEAD 判据仍受「历史会话曾提到过某脚本名」影响（旧版同病），
  本次只提速未改语义 —— 若要真正抓「写了但已不用」，需另立「近 N 天文内引用」口径。
- 未合并的候选：`waydroid-*`/`q28-*` 一次性实验脚本归入 `archive/`、`serial-*` 家族去重。

## 5. 回滚

```bash
git revert <本报告所在 merge 提交>      # 一把退回旧 doctor 与旧等待实现
# 单点回滚：
git checkout aea0eab -- scripts/check-doctor.sh scripts/vk-identity.py scripts/check-modular-config.sh
rm -rf scripts/doctor .cache
```

## 6. 复现验收

```bash
scripts/doctor/ab-bench.sh                      # 新旧 A/B + 判定行 diff（约 30 s；BASE= 可换基线提交）
scripts/check-doctor.sh                         # 全量：期望 FAIL=0
scripts/check-doctor.sh --staged-fast           # 入库前档：期望 < 1 s
scripts/test-lib-wait.sh                        # 等待语义自检：期望 ALL PASS
```
