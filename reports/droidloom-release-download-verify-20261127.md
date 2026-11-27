# droidloom release 资产下载验证 + 「rayburst 报无效」取证（2026-11-27，父代理亲测）

> 触发：用户报「子代理用 rayburst 下载 `droidloom-image-0.1.0-49` 时 GUI 提示无效，可能和 UA/请求头有关」，
> 并要求核实下载是否成功、以及考虑「直接编译而不是下载 release」。本文只回答这两件事，全部数字为父会话现查。

## 0. 一句话结论

| 问题 | 答案 |
|---|---|
| 下载成功了吗？ | **早就成功了**。`image-49`（66,862,311 B）与 `base-49`（903,293,629 B）都在盘上且 `zstd -t` 通过；**本轮又补下了 `image-51` + `runtime-51` + `source-51`**（字节数与 GitHub API 逐字节一致） |
| 是 UA/请求头问题吗？ | **不是**。GitHub 302 → Azure Blob SAS，UA 不参与鉴权；父代理用 Chrome UA 跑 **20 条并发 Range**（直连与 mihomo 代理各一次）**20/20 全 206**，代理档 20 MB / 2 s |
| GUI「无效」提示是什么 | aria2-next 日志里**没有** invalid/无效记录，只有 4 条 `Download complete` 通知 + `forceRemove failed: Active download not found`（任务已结束、调用方又去删）+ `TaskView.copyLink` 权限告警（无头 webview 噪声）⇒ **那 4 次其实都下完了**（66 MB @ 11–14 MB/s，5–10 s） |
| 要不要改成「直接编译」？ | **不要拿编译当下载的替代**。51 的源码快照核对过：我们要的 4 处改动（`--forward-signals`、`runuser`、cell DNS 走宿主 resolver、`WifiProvisioning` 自愈）**一处都不在 51 里** ⇒ 编译也拿不到，只能打本地 patch；而首次全量构建要 AOSP pinned 输入 + rootless Podman + Arch Linux ARM sysroot（见 §4） |

## 1. 盘上已有的完整件（现查）

| 文件 | 字节 | 与 release 资产 | 完整性 |
|---|---|---|---|
| `~/dl-droidloom-49/droidloom-image-0.1.0-49-aarch64.pkg.tar.zst` | 66,862,311 | ✅ 相等 | `zstd -t` OK（解压 1,198,776,320 B）· sha256 `8257effad113503e…` |
| `~/下载/droidloom-base-0.1.0-49-aarch64.pkg.tar.zst` | 903,293,629 | ✅ 相等 | `zstd -t` OK（解压 1,449,881,600 B）· sha256 `40712a6eb1bcc451…` |
| `~/dl-droidloom-49/rb-base.zst` | 903,293,629 | ✅ 与上一行**逐字节相同**（`cmp` 通过） | 同上 |
| `~/dl-droidloom-49/droidloom-runtime-0.1.0-49-…zst` | 11,047,451 | ✅ 相等 | `zstd -t` OK |
| `~/dl-droidloom-49/droidloom-base-0.1.0-49-…zst` | **0** | ❌ | **失败残留**（同目录 `.aria2` 控制文件在）；与上面两个完整 base 不是同一份 |

> 注意命名陷阱：`dl-droidloom-49/` 里那个 **0 字节**的 `droidloom-base-…` 会让人以为「base 没下成」，
> 实际完整 base 在 `~/下载/` 与 `rb-base.zst`（两者逐字节相同）。

## 2. 本轮新下的 51 三件（`~/dl-droidloom-51/`，共 79 MB）

| 文件 | 本地字节 | GitHub API size | 结果 |
|---|---|---|---|
| `droidloom-image-0.1.0-51-aarch64.pkg.tar.zst` | 66,871,960 | 66,871,960 | ✅ `zstd -t` OK（解压 1,198,796,800 B）；10.3 MB/s / 6.5 s |
| `droidloom-runtime-0.1.0-51-aarch64.pkg.tar.zst` | 11,131,906 | 11,131,906 | ✅ `zstd -t` OK（解压 34,631,680 B） |
| `droidloom-source-0.1.0-51.tar.gz` | 4,104,435 | 4,104,435 | ✅ 解开可读（`droidloom/` 全树） |

**关键发现（省 903 MB）**：`image-51` 的 `.PKGINFO` 写死

```
pkgname = droidloom-image
pkgver  = 0.1.0-51
depend  = droidloom-base=0.1.0-49
```

⇒ **51 复用 49 的 base**（`BUILDING.md`：base 不变则不打新 base 包）。所以「升到 51」只需这两个小包 + 现有 base-49。

命令（可复跑）：

```bash
for n in droidloom-image-0.1.0-51-aarch64.pkg.tar.zst droidloom-runtime-0.1.0-51-aarch64.pkg.tar.zst droidloom-source-0.1.0-51.tar.gz; do
  curl -sSL --proxy http://127.0.0.1:7890 --retry 3 -o "$n" -w "$n %{http_code} %{size_download} %{speed_download}\n" \
    "https://github.com/denialwm/droidloom/releases/download/packages/$n"; done
zstd -t droidloom-image-0.1.0-51-aarch64.pkg.tar.zst   # 输出解压后字节数 = 校验通过
```

## 3. 「rayburst 报无效」的真实成因（日志 + 独立复现）

`~/.local/share/dev.aninsomniacy.rayburst/logs/aria2-next.log`，12:05–12:06 段（本轮 D20 lane 触发）：

```
12:05:30 [notice] Download complete: /tmp/d20-ab/part/droidloom-image-0.1.0-49-aarch64.pkg.tar.zst
12:05:32 [info]   RPC aria2.forceRemove failed: Active download not found for GID 3de0f2769f821b91
12:05:36 [info]   c3195b887a74e90c: connection failed (TLS connect error: … unexpected eof), retry in 10000 ms
12:05:39 [notice] Download complete: …（同类 ×4）
12:06:08 [info]   58ee6191578abcca: connection 0/1/2 stalled, retry …
```

判读：
1. **`Download complete` 是真完成**，不是假绿 —— 该资产只有 66 MB，代理档 11–14 MB/s ⇒ 5–10 s 就结束（D20 报告实测 4/4 成功，缓存目录里也确实落过 66,862,311 B）。
2. **GUI 看到的「无效/异常」更可能是任务收尾期的三件事叠加**：①`forceRemove` 对**已结束**的 GID 返回 `Active download not found`（调用方时序问题，不是下载失败）；②中途 TLS `unexpected eof`（过代理的瞬时断链，aria2 按 `retry=10000` 重试）；③无头 webview 的 `TaskView.copyLink` 权限告警与 `ResizeObserver` 报错（纯 UI 噪声）。
3. **唯一稳定复现的 hang 是「直连档」**：D20 lane 用 RPC 把 `all-proxy` 覆盖成空串后，两次都是 35 s、`connections=0`、`totalLength=0`；而**同一时刻** `curl` 直连同一 URL 是 `206 / 2.9 MB/s` ⇒ 问题在 aria2-next 的「空代理覆盖」出口行为，**不在网络、不在 UA**。

父代理独立复现（排除 UA/头假设）：Chrome UA + 20 条并发 `Range`（各 1 MiB）
- 直连：20/20 `206`，合计 10,485,760 B，单条约 1.3–1.6 s
- 经 `127.0.0.1:7890`：20/20 `206`，合计 20,971,520 B，单条约 1.6–2.0 s

⇒ **多连接打 SAS 完全没问题**，`split=20` 不是根因（与 `reports/rayburst-ab-20261127.md` §三一致）。

**配置建议（仍未改配置，需用户放行）**：给 rayburst 引擎加「`all-proxy` 探活」——代理不可达时**拒绝任务并报错**，而不是退化成直连空等；
另外 GitHub release 的 SAS URL 有效期约 1 h（302 目标里 `se=`），重试必须重新走 302 取新链。

## 4. 「直接编译」可行性（读 `docs/BUILDING.md` + 51 源码快照后的裁决）

构建体系的实际形态：

- 仓库 = **Rust 宿侧程序 + 改造过的 AOSP 组件**；`droidloom-package` 负责编译宿侧、装配 Android 镜像、产出
  `droidloom-runtime` / `droidloom-image`（必要时 `droidloom-base`）。
- 发布链 = 自建 runner：`/mnt/puck/logix/droidloom` 下的 `cache/arch`（rootless **Podman** 存储 + 下载的输入 + **AOSP 源码** + 增量编译产物）、
  `sysroot/`（**Arch Linux ARM 根文件系统**，缺它 runner 拒绝开跑）、`cache/cargo-home`。
- **「首次构建需要全量下载/编译；之后的构建复用缓存」**——原文档话。
- 只有「改 SurfaceFlinger」这类单组件场景有快路：`droidloom-update … framework-build --surfaceflinger-only`，
  **前提仍是已有一份准备好的 ARM64 workspace**（= 首次全量构建产物）。

对「我想改的其实是宿主侧那 4 处」的直接核对（解包 `source-51` 后 grep）：

| 想要的改动 | 51 源码现状 | 结论 |
|---|---|---|
| 停机不用 `--forward-signals` | `runtime/droidloom-supervisor/src/development.rs:493` **仍在用** `--forward-signals` | 需本地 patch |
| `runuser` 路径 | `runtime/droidloom-package-support/src/main.rs:429/479`、`tools/droidloom-update/src/install.rs:90` **仍在用** | 需本地 patch |
| cell DNS 走宿主 resolver | `development_network.rs:33` 与 `dhcp_responder.rs:434` **仍硬编码** `1.1.1.1` / `8.8.8.8`（全仓 `resolv.conf` 零命中） | 需本地 patch（`EvilBorsch` 那条正是改这个） |
| `WifiProvisioning` 一次性位 → 自愈监听 | 51 源码里 **`WifiProvisioning` 零命中**（已改名/重构） | 需先定位新实现再判定 |

⇒ **编译不是「下载」的替代品**：51 官方包已经包含全部上游代码，我们缺的只是本地 patch；
反过来，如果真要打 patch，编译面也**不是整包**——改宿侧 Rust（supervisor/package-support）只需 cargo + 一份 aarch64 sysroot，
不需要碰 AOSP。**本项目另有一条硬约束：不许在平板上本机编译**（过热→掉电回 BL），所以只能主机侧交叉编。

## 5. 建议路径（按代价排序）

1. **现在**：升级到 51 用 release 包（已备好 79 MB，`image-51` 依赖 `base-49`，base 不用重下）。
   设备侧动作见 `.pi/plans/2026-11-27-设备窗待办汇总.md` §3a。
2. **要那 4 处改动时**：取 `EvilBorsch/eb/main` 的对应 4 条 commit 做 `patches/local/droidloom-*`（T2 已定「只 cherry-pick 不整包跟」），
   在主机侧交叉编一次 `droidloom-runtime`（宿侧 Rust，cargo，sysroot 一次性准备）。
3. **只有要改 Android 框架（SurfaceFlinger 等）时**才需要全量 AOSP 构建，那时再谈 Podman + AOSP 缓存，代价按 GB/小时计。
4. **rayburst 不用再碰这条下载**：curl 一条命令 6.5 s 下完 66 MB；要修也是修「`all-proxy` 空串退化直连」这个引擎行为（需放行改配置）。

## 6. 复现清单

```bash
# ① 已有件完整性
zstd -t ~/dl-droidloom-49/droidloom-image-0.1.0-49-aarch64.pkg.tar.zst ~/下载/droidloom-base-0.1.0-49-aarch64.pkg.tar.zst
cmp -s ~/下载/droidloom-base-0.1.0-49-aarch64.pkg.tar.zst ~/dl-droidloom-49/rb-base.zst && echo base-same
# ② 51 依赖关系
zstd -dc ~/dl-droidloom-51/droidloom-image-0.1.0-51-aarch64.pkg.tar.zst | tar xO .PKGINFO | grep depend
# ③ UA 无关的证明（20 并发 Range）
for i in $(seq 0 19); do s=$((i*1048576)); timeout 40 curl -sS -L -o /dev/null -w "%{http_code} " \
  -r $s-$((s+1048575)) 'https://github.com/denialwm/droidloom/releases/download/packages/droidloom-image-0.1.0-49-aarch64.pkg.tar.zst' & done; wait; echo
# ④ 51 源码里 4 处改动是否已上游
tar xzf ~/dl-droidloom-51/droidloom-source-0.1.0-51.tar.gz -C /tmp && grep -rn -- "--forward-signals\|runuser" /tmp/droidloom/runtime | head
grep -rn "1.1.1.1" /tmp/droidloom/runtime/droidloom-supervisor/src/
```
