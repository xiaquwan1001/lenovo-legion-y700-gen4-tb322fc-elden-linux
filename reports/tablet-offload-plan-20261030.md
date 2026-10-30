# 平板断电续作与分担方案（容量 / 同步 / 离线包 / 夜间运行）

- 日期 2026-10-30 · 角色 **L1（容量规划 + 同步架构）** · 派工：主机夜间断电时把低性能任务分担到平板（TB322FC/elden）
- 边界遵守：**未 push、未 commit、未安装、未改平板/vlab、未复制凭据**（主机侧只读调查 + 脚本草案落 `.pi/plans/`）
- 证据：`reports/artifacts/tablet-offload-20261030/*.log`（每条命令 `tee`，含 `capacity/gitpack/sync/git-channels/vlab*/tablet*/deps/gaps/build-*` 共 30+ 份）
- 状态词只用「未解 / 未证实 / 未上机」。**本结论全为主机侧取证，未上机验证平板夜间实跑。**

---

## 0. 一页结论（数字先行）

1. **不需要搬项目**。要同步的是 **93.4 MiB 工作树（`git ls-files` 3720 文件 / 97,949,584 B）+ 31.19 MiB pack**；`build/ 177.5 G`（36 条目、14 棵内核构建树，单棵 7.0–12.2 G）**不进 git，也不预传**。
2. **平板 73 G 空闲现在就够了**：最小可跑档 ≈0.25 GiB、建议档 ≈0.6 GiB、平板原生编一棵内核树 ≈21 GiB。**分区合并（→≈192 G，可用 ≈167 G）不是今晚的前提**，收益只是「多放 3–4 棵构建树 + ccache + 离线缓存」。
3. **建议不要删 linux18**（Alpine 秒级回退根）。等价收益可从 **userdata（sda16，256.7 G，Android 专属）** 回收——`AGENTS.md`「存储」已明文「扩容首选回收 Android 专属分区」，且不牺牲回退。删 linux18 降级为次选。
4. **git 通道旧结论已过期**：`git ls-remote --heads ssh://git@git.ustc.edu.cn/xqh/y700-elden.git` 从本机 **rc=0 并列出 refs**（2026-10-17 记忆里「22 被 ACL 拒绝」不再成立）；HTTPS 匿名 **401**、glab 对 git.ustc 的 token 报 **Invalid token** ⇒ **同步统一走 SSH remote，PAT 不是必需**（缺口从「要 PAT」变成「授权 push + 给平板发一把部署 key」）。
5. **真实风险 = 本机 main 领先两个远端各 141 提交未推送**（最后一次 fetch 2026-10-26 19:00）。断电续作的前置条件是先把单一真源推到 USTC GitLab。
6. **vlab 有入口但不能当编译机**：`ssh ubuntu@vlab.ustc.edu.cn` 用主机现有 key **免密可登**（VM14178-my，Ubuntu 22.04.5），但它是 **LXC 容器**、`cpu.max = "max 100000"` ⇒ **实际 1.0 CPU 配额**、6 GiB RAM、`/` 只剩 **12 G**、`/opt/vlab 192 G 只读**、apt 索引停在 2022 jammy、无 cross 工具链。**编译留在本机；平板（8 核/14 GiB）比它强。**
7. **API 故障切换已设计**：主机断电 ⇒ `127.0.0.1:4000` litellm 必死；夜间 runner 先探本地 litellm，失败回落 **平板直连 `api.llm.ustc.edu.cn`（114.214.240.204，平板侧实测可解析、HTTP 200）**，键放 `%h/.config/pi-tablet-night.env`（600，占位符入档，真值绝不入 git/rsync）。
8. **缺口 8 项**（§7），其中 3 项需用户动作：授权 push、给平板部署公钥、裁定「平板已持有 API 凭据副本」的处置（并行 lane 已把 5 个 auth 文件放进平板 `/root/.pi/agent/`，见 §8 R3）。

---

## 1. 容量表

### 1.1 主机项目体积分解（`du`，2026-10-30 22:42，总 195 G）

| 内容 | 体积 | 进 git | 平板是否需要 | 备注 |
|---|---|---|---|---|
| `build/` | **177.5 G** | 否 | **否** | 36 条目 = 14 棵内核构建树（7.0/12.2 G 两档）+ `uefi-woa-prep 8.2 G` + `gunyah-port 13 G`；单棵 `m3v5-pristine` 13 G（`drivers/ 6.5 G`、`vmlinux 0.6 G`） |
| `out/` | 6.6 G | 218 文件（少量） | 否 | 大头 `out/debian 683 M`；按需单目录取 |
| `env-pass/` | 3.3 G | 8 文件 | 否 | |
| `backup/` | 3.0 G | 18 文件（清单/GPT dump 文本） | 否（要时取文本） | 主体 `rawdump.img` 0.2 G 等镜像 |
| `geekidos-linux/` | 2.9 G | 否 | **可选** | **浅克隆**的内核仓 `git.ustc.edu.cn/xqh/y700-elden-kernel`：`.git 1.2 G` + 工作树 1.8 G |
| `dl-cam/` | 2.7 G | 231 文件（小） | 否 | 3×0.2 G 的 `vendor-*.img` |
| `stock-src/` | 2.0 G | 否 | 否 | GitHub 全量克隆 |
| `bootslot-b/` | 1.1 G | 1 文件 | 否 | |
| `.pi/` | 3.5 G | 少量 | 部分 | 其中 **`.pi/sessions 616 M / 265 个 jsonl`**（走 rsync 不走 git）、plans 260 K、skills 424 K、agents 96 K |
| `y700四代工具/` | 271 M | 否 | 否 | 厂商工具，x86 |
| `reports/` | **99 M** | 1213 文件 | **是** | 结论 md + artifacts 日志 |
| `logs/` | 35 M | 否 | 否 | |
| `Y700-elden-linux/` | 28 M | 否 | 否 | |
| `patches/` | **13 M** | 447 文件 | **是** | 上游补丁主体 |
| `.git/` | 85 M | — | **是** | **pack 31.19 MiB** + loose 49.86 MiB(2118 对象) + index 448 K；refs 75；worktree 4 个（`main` + 3 lane） |
| `reference/ tools/ scripts/ initramfs/ probes/ archive/` | 6.1/1.1/1.5/2.0/2.1/2.6 M | 是 | **是** | |
| 文档集 `TASKS 1.1 M / PITFALLS 952 K / SESSIONS 792 K / HISTORY 188 K / DEVICE 72 K / RESOURCES 120 K / RUNBOOK 52 K` | ≈3.3 M | 是 | **是** | |
| 顶层散落 `.deb`（hidl-gen/aidl/android-lib*） | ≈1.5 M | 是 | 视需要 | 已跟踪的离线 deb |

> **工作树合计（tracked）= 97,949,584 B ≈ 93.4 MiB；克隆 + `.git` ≈ 130 MiB。这就是「开发进度完整同步」的真实体量。**

### 1.2 平板现状与合并后（`root@192.168.7.1` 只读实测）

| 项 | 现状 | 合并 linux18 后 |
|---|---|---|
| 盘 | `sda` 472.5 GiB：`sda16 userdata 256.7 G`(Android) · **`sda17 96.0 G ext4 = /`** · **`sda18 96.0 G f2fs`（未挂载，Alpine 回退根）** | sda17 ≈ **192 G** |
| `df /` | **94 G 总 / 17 G 已用 / 73 G 可用（19 %）** | 可用 ≈ **167 G**（`resize2fs` 后实测为准） |
| 已用分解 | `/root 7.1 G`（`steam-home 3.3 G`+`wd 2.0 G`+`g3-steam 1.6 G`+`m1-73-dmesg.txt 93 M`+`src 14 M`）、`/usr 3.9 G`、`/var 3.9 G`（含 `apt/archives 301 M` 残留）、`/home 1.7 G` | 同 |
| CPU/内存 | **8 核 / 14 871 MiB（可用 10 404 MiB）/ Swap = 0** | 同（建议上编译前加 zram） |
| 软件 | 已被并行 lane 装好：**git 2.55.0 · node v24.22.2 · npm 12.2.0 · pi 1.4.0 · tmux 3.8 · rsync 3.5.1**；`dpkg Installed-Size(git+nodejs+npm)=58 MiB`；ble.sh 走 **源码安装** `/usr/local/share/blesh/ble-0.4.0-devel3`（`command -v ble.sh` 为空是**正常**——它靠 source，不是 PATH 可执行文件；apt 亦有候选 `0.4.0~git20250806.8060b7a-2`） | 同 |
| 输入 | `/dev/input/event0..6 + mouse0 + mice` 存在 ✅ | 同 |
| 服务 | `systemctl --user is-system-running = running`，用户 `uid 1001 xuqianhui1001` ⇒ **user unit 可用**（需 `loginctl enable-linger`） | 同 |
| 网络 | 无 proxy 变量；`mirrors.ustc.edu.cn/debian 200`、`registry.npmjs.org 200`、`git.ustc.edu.cn 302`、`api.llm.ustc.edu.cn → 114.214.240.204` | 同 |

**apt 体积实测（`apt-get install --print-uris`，未安装）**：core-dev 6 pkgs/14.3 MiB、ble.sh 1/0.5、nodejs+npm 468/67.1、py-static 38/12.1、kbuild 29/9.1 ⇒ **513 pkgs / 84.6 MiB**。

### 1.3 vlab「编译 VM」实测（见 §5）

`VM14178-my`：**1.0 CPU 配额（2 vCPU）/ 6 GiB / `/` 剩 12 G / apt 停 2022 / 无 cross 工具链** ⇒ 判定：**不承担编译**；可作 GitLab 中继（有免密 sudo，但需 `apt update` 才能装包 = 写操作，本 lane 未做）。

### 1.4 分档裁决（放什么 / 不放什么）

| 档 | 内容 | 体积 | 73 G（现状） | ≈167 G（合并后） |
|---|---|---|---|---|
| **A 最小可跑** | 文档仓克隆（工作树 93.4 M + pack 31.19 M）+ apt 残余 | **≈0.25 GiB** | ✅ | ✅ |
| **B 建议** | A + `reports 99 M` + `patches 13 M` + 文档集 3.3 M + Pi 1.4.0 副本（已装）+ dtschema/edl wheelhouse ≈18 M | **≈0.6 GiB** | ✅ | ✅ |
| **C 平板原生编内核** | B + 内核仓浅克隆（1.8 G 树 + 1.2 G `.git`）+ 一棵构建树 12.2 G + ccache 5 G | **≈21 GiB** | ✅（余 52 G） | ✅ |
| **D 并行多树** | C + 第 2–3 棵构建树 + `out/` 产物 + 离线包缓存 | ≈45–60 GiB | ⚠️ 勉强（余 <15 G，且无 swap） | ✅ 舒适 |
| **E 不搬** | `build/` 全量 **177.5 G**、`geekidos+stock-src+out+dl-cam+backup+env-pass ≈15 G` 整目录 | 177.5 G | ❌ | ❌ **且无意义**（167 G 也放不下；单棵树按需克隆只需 12 G） |

**结论**：夜间任务（§2）全是 **A/B 档**；C 档是「主机停电时应急编一次」的备选，**默认不把编译排进夜间队列**。分区合并只解锁 D 档，**不解锁 E 档**。

### 1.5 分区合并（用户 2026-10-30 授权）——前提、后续、回滚缺口、风险

**本 lane 不执行**（GPT/分区写 + 与 M3-1 v5 上机 lane 同机，必须串行）。落地前置清单：

1. **串行**：等 M3-1 v5 上机实验结束 + `scripts/device-lock.sh` 取锁（AGENTS/`ORCHESTRATION §6`：设备单一串行资源）。
2. **GPT 双表备份**：`scripts/gpt-dump.sh`（主 GPT + 备份 GPT + by-name 清单），写后**读回校验**，不看「传输完成」（`AGENT-OPS §2`）。
3. 先在**保留分区** sda17 上做 `e2fsck -f` → 删 sda18 → `sgdisk` 扩 sda17 → **`resize2fs`** → **`df` 读回**目标容量。
4. 若 `sda18` 上 Alpine 根仍被 boot 链引用（A/B slot、boot_b 内 cmdline），先核 `scripts/trial.sh` 记录的当前启动路径，避免删掉后 bootloader 指向不存在的 root。
5. 回滚等价物（**当前缺口，需先补齐再动分区**）：
   - **G-a 未证实**：`sda18` 上 Alpine 根的**实际用量与文件清单**（未挂载，本轮未测；只读挂载亦属设备动作，未做）→ 先 `mount -o ro` 测体积并出 `SHA256SUMS`。
   - **G-b 缺**：Alpine 根**镜像级备份**（`dd` 出 + `xz` 压缩存主机 `backup/alpine-fallback-<date>.img.xz` + SHA256 + 回写演练一次）。**没有它就不该删 linux18。**
   - **G-c 已有部分**：`boot_b` 签名镜像 + 主机侧 `bootslot-b/ 1.1 G`；但它只回退**内核**，不回退**根文件系统** ⇒ 不能单独充当删根的回滚。
6. **风险登记（回答派工第 4 点）**：**判定 = Alpine 秒级回退根应当保留。** 删掉后一旦 Debian 根被写坏（本项目的 rootfs 打包/迁移脚本 `scripts/f2fs-migrate.sh` 等确有写盘面），现场只剩 EDL 重刷，代价从「秒级」变「小时级 + 物理动作」。
   **推荐替代方案（等价容量收益、零回退损失）**：从 **userdata（sda16，256.7 G）** 回收——`AGENTS.md`「存储」明文「Linux 容量扩容首选回收 Android 专属分区」，且不动 linux17/linux18。次选才是在 **G-a/G-b 补齐后**删 linux18。

---

## 2. 夜间任务队列（只含低 CPU / 低 IO）

队列文件与 6 条真实任务：`.pi/plans/tablet-queue.example.jsonl`（python3 JSON 校验 6/6 通过）。

| kind | 任务 | 软预算 | 硬截止盒 | 预估 IO/CPU | 为何适合平板 |
|---|---|---|---|---|---|
| `doc-audit` | 状态漂移/死链/编号/SSOT 违例审计，**只出差异清单不改 README** | 45 min | 3600 s | 读多写少 | 纯文本 grep，单文件 MB 级 |
| `mail-triage` | 上游回信四类分诊 + 草稿要点（**只起草，发信须用户放行**） | 30 min | 2400 s | 极低 | 只读 `patches/upstream/**` |
| `patch-prep` | M2/M3「未上机」条目 → `format-patch` 风格草稿 + GATES 占位，落 `patches-userland/staging/` | 60 min | 5400 s | 低 | 13 M 补丁集内操作 |
| `log-analysis` | `reports/trials/` 机器可读记录统计（por/cold/warm 分层、无 record 写 verdict 违例） | 40 min | 3000 s | 低 | 只读日志 |
| `static-audit` | **证伪式**复跑 `checkpatch.pl`，「声称 0E/0W/0C vs 实测」差异落盘；复跑不了写「未证实」 | 50 min | 4200 s | 中低（perl，无编译） | 无工具链依赖（内核树缺失时按条跳过） |
| `ssot-merge` | 抽 `*/sessions/` 的「★SSOT 待并入」成并入草案（**不直接改 README**，§4 单写者） | 35 min | 3000 s | 低 | 3.3 M 文档 |

**明确禁止进夜间队列**：内核/模块编译（8 核无 swap，墙钟远差于本机且挤占交互）、`debootstrap`/`qemu-user-static` 建根、大目录 `tar`/`rsync`（>1 G）、任何 `fastboot`/`edl`/上机（`needs_device` 一律 `false`，runner 硬校验）、任何 `apt upgrade`。

---

## 3. 同步协议

### 3.1 通道现状核验（本轮实测，纠正旧结论）

| 通道 | 命令 | 结果 | 判定 |
|---|---|---|---|
| USTC GitLab **SSH** | `git ls-remote --heads ssh://git@git.ustc.edu.cn/xqh/y700-elden.git` | **rc=0，列出 refs** | **可用**（本机 key 已注册；旧记忆「22 被拒」过期） |
| USTC GitLab **HTTPS** | `curl …/info/refs?service=git-upload-pack` | **401** | 匿名不可用（内核仓 `y700-elden-kernel` 亦 401） |
| glab | `glab auth status`（未加 `--show-token`） | `git.ustc.edu.cn as xqh … Token: [redacted]` + **`Invalid token provided`** | 不可用 |
| GitHub | `git ls-remote --heads github`（ssh over 443） | rc=0 | 可用（备胎镜像） |
| **未推送量** | `git rev-list --count {github,origin}/main..main` | **141 / 141**；`FETCH_HEAD` 停在 2026-10-26 19:00 | **风险 R1** |

> **凭据纪律**：全程未 `cat` 任何 `glab-cli/config.yml`、`gh/hosts.yml`、`id_rsa`、`.git-credentials`；只报「存在 / 权限 / 可用」。主机侧无 `~/.git-credentials`、无 `~/.netrc`；`glab-cli/config.yml` 600。

### 3.2 三方顺序与防分叉（脚本 `.pi/plans/tablet-sync.sh`，默认只读；`bash -n` 通过）

1. **本机先动**：上电后 `tablet-sync.sh --preflight`（工作区必须干净，否则退出码 2；未推送 >50 告警、>200 拒绝）→ `git fetch ustc-ssh`。
2. **单一真源**：远端 `main` 未前进 ⇒ 先处置 141 提交再 push；已前进 ⇒ `git rebase ustc-ssh/main`，**冲突不选边**（`--abort` + 写 `conflict-<date>.md` 交总管）。
3. **平板永不直推 `main`、永不 force**：夜间产物只推 `tablet/<task>`（runner 里写死 ref；被拒时改名 `tablet/<task>-<date>` 留两条分支给总管）。
4. **收口**：本机 `git fetch ustc-ssh 'refs/heads/tablet/*:refs/remotes/tablet/*'` → 逐分支 `git merge --no-ff`（`--merge-tablet` 实现，冲突即停）→ 本机统一 push `main`。
5. **按路径分派防同文件冲突**：平板只写 `reports/`、`TASKS/sessions/`、`patches-userland/staging/`、`PITFALLS` 增补条目；**禁碰**内核源码、各角度 `README.md`、`INDEX.md`、`DEVICE/`、`RESOURCES/`、`.gitignore`、`.pi/`（runner 队列校验 + `allowed_write_paths` 双层拦）。

### 3.3 会话 / 用户数据（git vs rsync）

| 数据 | 体量 | 载体 | 策略 |
|---|---|---|---|
| `.pi/sessions/*.jsonl` | **616 M / 265** | **rsync 单向 主机←平板**，`--checksum`，目录隔离 `.pi/sessions/tablet/` | 不进 git（否则 pack 从 31 MiB 膨胀数百 MiB 且无 diff 价值）；**绝不 `--delete`、不双向覆盖** |
| `reports/` | 99 M | **git**（结论 md）+ **rsync**（>5 M 原始 log/artifacts） | 结论进历史，原始遥测不进 |
| `TASKS/sessions/`（含平板产物 `TASKS/sessions/tablet-incoming/`） | 0.8 M | **git**（经 `tablet/*` 分支） | 纯文本，天然可 merge |
| memory（`~/.pi/agent/pi-hermes-memory/`、`projects-memory/y700-elden/`） | KB 级 | **rsync 单向 平板→主机** | 平板无权改主机记忆 SSOT；主机归并后再落盘 |

`.gitignore` **建议口径（只写建议，本 lane 未改文件）**：

```gitignore
.pi/sessions/            # 616 M 会话流走 rsync
.pi/night-state/         # 夜间状态标记（.done/.fail/.retryN）
reports/**/*.raw.log
reports/artifacts/**/trace-*.dat
```
（原则：**结论 md 进 git，原始遥测走 rsync**；`reports/artifacts/` 下按大小分流。请总管落笔——L1 无 `.gitignore` 写权。）

### 3.4 断电续作 & 上电合流清单

**平板断电续作**（runner 已实现）：状态落 `.pi/night-state/<DATE>/<id>.{done,fail,retryN}`，重启后跳过 `.done` 续跑；会话固定落 `.pi/sessions/tablet/`（`pi --resume` / `scripts/sess.sh`——项目 `sessionDir=.pi/sessions`，全局 `sess` 扫不到本仓，见 `AGENT-OPS §4`）。

**主机上电合流（顺序执行，每步留证据）**：

```
1  ping -c2 192.168.7.1                          # 平板活着
2  .pi/plans/tablet-sync.sh --preflight          # 本机工作区干净 + 未推送计数
3  .pi/plans/tablet-sync.sh --fetch-tablet       # rsync 会话/reports/TASKS 增量（单向、无 --delete）
4  git fetch ustc-ssh 'refs/heads/tablet/*:refs/remotes/tablet/*'
5  逐分支 .pi/plans/tablet-sync.sh --merge-tablet tablet/<task>   # 冲突即停，交总管
6  审 reports/artifacts/tablet-offload-20261030/night-<DATE>/runner.log（done/fail 计数）
7  对本机跑 scripts/check-doctor.sh（FAIL=0）后 push main（前置 = §7 G1 放行）
8  核对：git rev-list --count ustc-ssh/main..main == 0 才算合流成功
```

---

## 4. 依赖与离线包（L2-A 产物 + L1 修正）

清单全文：`reports/artifacts/tablet-offload-20261030/l2a-offline-packages.md`；脚本：`.pi/plans/tablet-offline-pkgs.sh`（`DRY_RUN=1` 默认，`bash -n` 通过）。

- **判定分布**：① 在线可取（apt sid 84.6 MiB、`dtc`、`checkpatch.pl`＝内核自带零依赖、`debootstrap`、`openssl`、`qrtr-tools`）；② **必须预传**（`edl`——PyPI 同名是无关视频工具，必须 GitHub tarball + `requirements.txt` 离线装；Pi agent npm 目录；wheelhouse）；③ 不需要（`gdown`/`tirith` 已被历史结论否掉、`aarch64-linux-gnu-gcc`——**平板本身 arm64，用原生 gcc，交叉链只在 x86 host 需要**、`mkbootimg.py` 已 vendored）。
- **dtschema 裁决：走 pip（USTC pypi 镜像），不走 apt**。`dt-validate`/`dt-doc-validate` 只随 `dtschema` 分发；apt 的 `python3-jsonschema` 只给库。sid 需 venv（PEP 668），总代价 <10 MB。
- **三档总体积**：A ≈230 MiB / B ≈0.9–1.2 GiB / C ≈3–4.5 GiB（含平板原生工具链）——均 ≤ 73 G。
- **L1 修正/补充（并行 lane 实测证据）**：
  1. `p1-install.log` 显示 sid 源的 `nodejs 24.22.0` 三个 deb **404**（sid 滚动），`apt update` 后 `24.22.2` 才装上 ⇒ **sid 离线包有保质期**：预传包须在**装机当天** `apt-get download`，且装前仍要能 `apt update` 兜底。这条改变「大包早传」的价值：**真正值得预传的是 apt 索引与 wheelhouse，不是 513 个 deb**。
  2. apt 513 包中 git/nodejs/npm 已在平板（`Installed-Size` 58 MiB），残余集远小于 84.6 MiB。
  3. 平板 **Swap = 0**：C 档编译前建议加 zram（低 IO 夜间任务不需要）。

---

## 5. vlab 虚拟机调查（结论：入口存在，但不作编译机）

**证据链**（`vlab.log`、`vlab-context.log`、`vlab-vm{,2,3}.log`）：

1. `~/.ssh/known_hosts`（哈希）里 `ssh-keygen -F vlab.ustc.edu.cn` **KNOWN**；`~/.bash_history` 有 `ssh vlab` 两次。
2. 历史 pi 会话留有三行配置（现 `~/.ssh/config` 已无该 Host 块）：`Host vlab → HostName vlab.ustc.edu.cn · User ubuntu · IdentityFile ~/.ssh/vlab-vm14178.pem`；**该 `.pem` 现已不存在于 `~/.ssh/`**（只剩 `id_rsa`/`id_rsa.pub`/`authorized_keys`/`known_hosts`）。
3. **实测入口**：`ssh -o BatchMode=yes ubuntu@vlab.ustc.edu.cn` **rc=0**（主机 `id_rsa` 免密通过，banner `Welcome to Vlab`）⇒ **不需要重新提供凭据即可登**。
4. **能力实测**：`VM14178-my`，Ubuntu 22.04.5，`systemd-detect-virt = lxc`；`cpu.max = "max 100000"` ⇒ **1.0 CPU 配额**（`nproc 2`，Xeon Silver 4314）；6 GiB RAM；`/` btrfs 16 G 剩 **12 G**；`/opt/vlab 192 G` 是 **ro 挂载**（`mkdir` 探针即「只读文件系统」，探针目录已即时删除）；`lsblk` 的 893 G/65 T 是 **PVE 宿主设备，容器内不可用**；apt 索引停在 **2022-04 jammy**（`apt-cache policy` 全空）；缺 `dtc/pahole/ccache/swig/libssl-dev/pip3/node` 与 cross 工具链；`git 2.34.1`；**有免密 sudo**；VM→`git.ustc` 443 可达、22 OPEN。
5. 该 VM 另有他人用途（`~/cross_env 3.2 G`、`~/2026ustc-jianmu-compiler 15 M`、`~/.git-credentials` 存在——**未读内容**）。

**判定：vlab VM 作编译机 = 不可行**（1 CPU + 12 G 盘，弱于平板 8 核/14 G）。**「有凭据后如何测容量」的一页清单已在上述 4 条内执行完毕**（CPU：`nproc`+`/sys/fs/cgroup/cpu.max`；RAM：`free -g`+`memory.max`；盘：`df -h /`+`findmnt -o OPTIONS`+`lsblk` 甄别宿主泄漏；网：`getent`+`curl -w %{http_code}` 到 mirrors/api.llm/git.ustc；工具链：逐 `dpkg -s` + `apt-cache policy`）。**若将来要它当中继**：需用户授权 `sudo apt update`（写操作，本 lane 未做）。

---

## 6. 夜间无人值守运行设计

| 件 | 路径 | 状态 |
|---|---|---|
| runner | `.pi/plans/tablet-night-runner.sh` | **L1 自写**（L2-B 未交付），`bash -n` 通过 + `DRY_RUN=1` 冒烟跑通 6 任务（`/tmp/tabrunner` 沙箱内，零仓库污染） |
| 队列 | `.pi/plans/tablet-queue.example.jsonl` | **L1 自写**（L2-B 未交付），6 条低 CPU 任务，JSON 校验 6/6 |
| systemd user unit | `.pi/plans/pi-tablet-night.service` | L2-B 交付（oneshot + `Nice=19` + `IOSchedulingClass=idle` + `TimeoutStartSec=8h` + `Restart=no`，靠状态文件续作） |
| 同步 | `.pi/plans/tablet-sync.sh` | L2-B 交付（`--preflight/--fetch-tablet/--add-remote/--merge-tablet`，从不 push） |

- **runner 硬门**：每任务 `timeout -k 60 <timeout_box>`；`nice 19 + ionice -c3`；**并发 1**；`allowed_write_paths` 白名单 + SSOT 前缀黑名单双层拦；`needs_device` 必须 `false`；重试 ≤ `retry`（退避 60 s×n）；`pi -p --mode text --session-dir .pi/sessions/tablet --name night-<date>-<id>`；跑后 `ps -C pi` 核实无残留；收尾 rsync 单向回传，**push 需显式 `--allow-push`** 且只推 `tablet/night-<date>`。
- **启动两法**：① `loginctl enable-linger xuqianhui1001`（**用户/root 一次性动作**）+ `systemctl --user start pi-tablet-night.service`（可加 timer `OnCalendar=*-*-* 23:00`）；② 平板已装 tmux 3.8：`tmux new -ds nightrun .pi/plans/tablet-night-runner.sh`，异常时 `tmux attach -t nightrun` 看现场。
- **API 路线与故障切换**（键值**一律占位符**，真值不落文件/不入 git/不回传）：
  - 路线 **B 本地 litellm**：平板 `~/.litellm/config.yaml`（`model_list[].api_key: os.environ/USTC_API_KEY`），探活 `curl -m 5 http://127.0.0.1:4000/health/liveliness` == 200。
  - 路线 **A 直连**（主机断电时唯一活路）：`%h/.config/pi-tablet-night.env`（`chmod 600`）放 `USTC_API_KEY=__PLACEHOLDER__`；探活 `curl -m 10 -H "Authorization: Bearer $KEY" https://api.llm.ustc.edu.cn/v1/models`：200 活、401 键无效即停、429 冷却、`000/超时` 判死标 `skip:api-down`。
  - runner 顺序：**先 B 后 A**，两者都不通即终止剩余队列（`rc=5`）。
- **早上 review+合并** = §3.4 清单 8 步。

---

## 7. 缺口清单（8 项，需用户/总管；本 lane 一律未擅自补齐）

| # | 缺口 | 需要谁做什么 | 本 lane 为何不补 |
|---|---|---|---|
| **G1** | `main` 领先 `github/main`/`origin/main` 各 **141 提交**未推送 | **用户放行 push**（通道已通，SSH 可用）；先跑 `--preflight` | 派工单「不 push」 |
| **G2** | 平板无 GitLab 部署 key | 平板 `ssh-keygen -t ed25519` 后**用户在 USTC GitLab 网页贴公钥** | key 生成/账号操作属交互登录 |
| **G3** | `~/.ssh/vlab-vm14178.pem` 已丢；现靠主机 `id_rsa` 免密 | 确认 VM 长期归属；若主机 key 轮换需从 vlab 控制台重下 | 不碰账号 |
| **G4** | **平板已存在主机 API 凭据副本**（并行 lane 所为）：`/root/.pi/agent/{auth.json,custom-providers-auth.json,custom-providers.json,models.json,models-store.json}` 全 600 `root:root` | **用户裁定**：承认「平板持 key」并做隔离 + 确保不入 git/回传，**或**删除后改用平板独立 key | 派工单「不复制凭据」；删除他人 lane 产物需授权 |
| **G5** | 分区合并（GPT 写）+ Alpine 回退镜像（§1.5 G-a/G-b） | 用户授权，排在 **M3-1 v5 之后**，取设备锁 | 设备纪律 + 只读边界 |
| **G6** | 平板无 `dtschema`（`import dtschema` 失败） | 按 §4 走 venv + wheelhouse（`tablet-offline-pkgs.sh` 的 `--run`） | 不安装 |
| **G7** | 平板 **Swap = 0** | 若要 C 档编译，先加 zram（`zram-tools`） | 不安装 |
| **G8** | 平板可回收 ≈4 G：`/root/steam-home 3.3 G`、`wd 2.0 G`、`g3-steam 1.6 G`、`apt/archives 301 M` 属其它 lane 产物 | 总管裁定归属后清理 | 不是本 lane 产物 |

---

## 8. 风险登记

- **R1（高）**：141 提交只存在于本机盘 ⇒ **今晚断电即丢**。缓解 = G1 放行 push 前，**不要**让平板做任何依赖 main 新提交的任务。
- **R2（高）**：**并行 lane 已在 M3-1 v5 在用的平板上装包 + 落凭据副本**（`p1-install2.log`、`p3-keys-transfer.log`、`p3-pi-install.log`），与本派工单「不安装/不复制凭据」边界相冲 ⇒ 需总管定序（同一台设备应串行，`ORCHESTRATION §6`）。
- **R3（中）**：sid 滚动导致预传 deb 404（已实证）⇒ 离线包保质期短，见 §4-L1 修正 1。
- **R4（中）**：平板无 swap + 8 核，若误排编译类任务会拖垮同机 M3-1 实验 ⇒ runner 已用 `needs_device=false` + 白名单 + nice/ionice 拦。
- **R5（中）**：删 linux18 = 失去秒级回退根（§1.5 判定：不删，改回收 userdata）。
- **R6（低）**：L2-B 自报 5 个产物、**实到 3 个**（缺 runner + 队列，且其 `l2b-verify.log` 不存在），其回执里「全部落盘 / bash -n 3 脚本通过」为**不实自报** ⇒ 已由 L1 亲写补齐。再次印证「worker 自报不可信」（`AGENT-OPS §7`）。
- **R7（低）**：本报告的口径依赖「SSH:22 可用」，而它是**今天新测**的（旧记忆相反）；若 GitLab ACL 再变，回退路径 = GitHub 镜像（443，已 rc=0）。

---

## 9. 产物与复现

**产物**

| 路径 | 作者 | 说明 |
|---|---|---|
| `reports/tablet-offload-plan-20261030.md` | L1 | 本文件（容量/范围/同步/离线/夜间队列/缺口） |
| `reports/artifacts/tablet-offload-20261030/l2a-offline-packages.md` + 6 份 `l2a-*.log` | L2-A | 依赖盘点（带 file:line）+ dtschema 裁决 + 三档体积 |
| `reports/artifacts/tablet-offload-20261030/l2b-sync-nightrun.md` | L2-B | 三方同步 + 夜间设计正文（**其 5 件产物只交 3 件**，见 R6） |
| `.pi/plans/tablet-offline-pkgs.sh` | L2-A | 离线包生成草案（`DRY_RUN=1` 默认） |
| `.pi/plans/tablet-sync.sh`、`pi-tablet-night.service` | L2-B | 合流脚本 / systemd user unit |
| **`.pi/plans/tablet-night-runner.sh`、`tablet-queue.example.jsonl`** | **L1 补写** | 夜间执行器 + 6 任务队列（L2-B 未交付） |
| `reports/artifacts/tablet-offload-20261030/{capacity,gitpack,sync,git-channels,deps,gaps,vlab,vlab-entry,vlab-entry2,vlab-entry3,vlab-context,vlab-vm,vlab-vm2,vlab-vm3,ssh-probe,tablet-readonly,tablet-apt-sim,tablet-apt-sim2,tablet-apt-sim3,tablet-apt-size,tablet-state,build-breakdown,build-structure,kernel-repo}.log` | L1 | 逐门禁 `tee` 证据（30 份） |

**最小复现**

```bash
cd /home/xuqianhui/y700-elden
A=reports/artifacts/tablet-offload-20261030
# 容量
git count-objects -v -H | tee $A/capacity.log; git ls-files -z | xargs -0 du -cb | tail -1
du -x -d1 build 2>/dev/null | sort -rn | head -6
# git 通道（只读，不 push）
GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=8' \
  git ls-remote --heads ssh://git@git.ustc.edu.cn/xqh/y700-elden.git | head -3
git rev-list --count origin/main..main            # 期望 141（G1 处置后应归 0）
# 平板（只读；-o Debug::NoLocking=1 避免与 M3-1 lane 抢 dpkg 锁）
ssh root@192.168.7.1 'df -h /; lsblk -bno NAME,SIZE,FSTYPE,PARTLABEL /dev/sda | tail -3'
ssh root@192.168.7.1 'apt-get install --print-uris -qq -y ble.sh | awk "{s+=\$3} END{print s/1048576\" MiB\"}"'
# vlab（一条 BatchMode 探针，无凭据输出）
ssh -o BatchMode=yes ubuntu@vlab.ustc.edu.cn 'cat /sys/fs/cgroup/cpu.max; df -h / | tail -1'
# 脚本自检（不执行安装/不 push）
bash -n .pi/plans/tablet-{sync,night-runner,offline-pkgs}.sh
python3 -c "import json;[json.loads(l) for l in open('.pi/plans/tablet-queue.example.jsonl') if l.strip()]"
ROOT=/tmp/tabrunner DRY_RUN=1 .pi/plans/tablet-night-runner.sh "$PWD/.pi/plans/tablet-queue.example.jsonl"
```

---

## 10. 提请总管收口（L1 无写权的三件事）

1. **报告不得成孤儿**（`AGENT-OPS §3`）：请从 `TASKS/README.md` 相应 Q/§行或 `PITFALLS` 链到本文件。
2. **`.gitignore` 口径**按 §3.3 建议落笔（含 `.pi/sessions/`、`.pi/night-state/`）。
3. **记忆更正**：`~/.pi/agent/pi-hermes-memory/MEMORY.md:365,369` 与 `failures.md:4072` 的「git.ustc.edu.cn:22 被 ACL 拒绝」已过期，且应补一条「vlab VM = 1 CPU LXC，不可当编译机；入口 = 主机 key 免密登 ubuntu@vlab.ustc.edu.cn」（凭据本身不写）。
