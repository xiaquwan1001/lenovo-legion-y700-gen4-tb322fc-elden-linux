# 平板开发环境落地（tablet-offload，2026-10-30）

> 执行：physical-exec L1（本 lane）。设备 = 测试平板（root@192.168.7.1，Debian sid arm64）。
> 证据目录：`reports/artifacts/tablet-offload-20261030/*.log`（每阶段一文件）。
> 纪律执行：未升级/未删除/未重启任何已有包；凭据仅 scp+chmod 600，未打印、未入仓。

---

## 结论速览

| 阶段 | 结果 |
|---|---|
| P0 容量与现状 | **PASS** |
| P1 新增安装 | **PASS**（git 2.55.0 / node 24.22.2 / npm 12.2.0 / rg 15.2.0 / pip 26.2.2 / build-essential 12.12） |
| P2 ble.sh | **PASS**（v0.4.0-devel3 预构建包，真 pty 验证加载；.bashrc 已备份 `.bashrc.bak-20261030`） |
| P3 Pi agent + 模型通道 | **PASS**（pi 1.4.0；直连 USTC 实测回话 "OK"；故障切换脚本 `/root/bin/model-channel.sh`） |
| P4 输入 | **PASS（现状核查）**：phosh + NVTCapacitiveTouchScreen + squeekboard 在位；无物理键鼠设备 |
| P5 git/vlab | **部分完成**：git 配置 PASS；**vlab 认证被阻（无凭据）→ 停** |

**阻塞项（需用户/外部）**：
1. **vlab 凭据**：TCP/22 经 IPv6 可达（`vlab.ustc.edu.cn → [2001:da8:d800:75::226]`，banner "Vlab/taokystrong"），
   但 `git@vlab: Permission denied (publickey,keyboard-interactive)`。平板无私钥、主机无 vlab ssh config。
   → 需用户提供 vlab 账号/密钥后，平板 `ssh-copy-id`（或 scp 私钥 chmod 600）方可打通 ③。
2. **GitLab PAT**：历史 glpat 已失效，HTTPS+PAT 方向仍需新 PAT（④ 同步依赖）。
3. **平台侧 apt 装包曾现 404**（镜像 pdiff 落后），`apt-get update` 后恢复；本 lane 已做 update（只刷索引，未升级任何已装包）。

---

## P0 容量与现状（证据 p0-capacity.log / p0-vlab-ipv6.log）

- 内存 14 GiB（可用 10 GiB），**无 swap**；inode 用 2%（余 620 万）。
- `/dev/sda17 ext4 = / 94G（已用 16G，余 73G）`；`/dev/sda18 f2fs = linux18 96G（未挂载，Alpine 回退根）`。
- 已装 972 包；tmux 3.8 / jq 1.8.2 / rsync 3.5.1 / bash 5.3 已有；缺 git/node/npm/rg/pip/build-essential（后补装）。
- 连通（≤15s 探测）：USTC apt 镜像 200/0.56s；api.llm.ustc.edu.cn 200/0.025s；
  **github.com 与 npmjs.org 直连超时**（无代理出口）；npmmirror 200/0.21s（npm 安装改走此镜像）；
  vlab.ustc.edu.cn:22 经 IPv6 TCP 可达。
- 桌面 = phosh（用户 xuqianhui1001，tty7），输入设备：NVTCapacitiveTouchScreen + pmic 按键 + haptics。

### 容量量化表（放什么 / 不放什么）

| 内容 | 体积（主机实测） | 现状 73G 空闲 | 合并 linux18 后 ≈190G |
|---|---|---|---|
| git 仓（.git pack 等） | **85 MiB** | ✅ | ✅ |
| 工作树（去 build、去 geekidos-linux） | **23G** | ✅（勉强） | ✅ 宽裕 |
| geekidos-linux | 2.9G | ✅ | ✅ |
| reports + sessions（含全局 1.1G pi sessions 按需选同步） | ~0.1G（仓内）+按需 | ✅ | ✅ |
| **build/ 产物** | **178G** | ❌ 不放 | ❌ 仍不建议整放（夜编走 vlab VM；如必须，单 kernel 变体 ~10-20G 可选放） |
| 离线依赖包（apt/npm deb 与 tarball 缓存） | <1G | ✅ | ✅ |

**容量结论**：现状 73G 已可承载「repo + 工作树 + 会话 + 离线依赖」全套（约 27G）；
按用户 2026-10-30 授权合并 linux18 后 ≈190G，仅 build/ 仍以"按需子集"处理。

### 容量前提与后续动作（非本 lane 执行，授权记录）

- 授权（用户 2026-10-30）：允许删 linux18（f2fs 96G）并把空间并入 linux17，目标 `/ ≈190G`，保留 Debian 根现状。
- **该操作属 GPT/分区写**：须 GPT 双表备份 + 写后读回，且**必须排在 M3-1 v5 上机实验之后**（同机串行，另 lane 持锁）。
- 回滚等价物缺口清单：
  - boot_b 签名镜像（可引导回退件）：**缺** —— 主机侧未见 `boot_b` 独立归档指针（需总管在 SSOT 落指针或补 dump）；
  - Alpine 回退根打包存主机/外置：**缺** —— linux18 现状未做镜像归档；
  - **风险登记：删除 linux18 = 失去 Alpine 秒级回退根。** 保留等价回退方案（若裁定必须保留）：
    ① 操作前设备侧 `dd if=/dev/disk/by-partlabel/linux18 | gzip > 主机 alpine-root18.img.gz`（96G 原始、f2fs 实占更小，gzip 后预计 <20G），存主机 `RESOURCES/` 外置盘；
    ② 核验 boot_b 可引导 Alpine 内核（fastboot boot 变体 / `boot_b` dump + hash 归档）；
    ③ 回退路径 = 重刷该镜像 + 写回 GPT 原槽位（需 EDL/fastboot 双通道验证其一可用）。
    在 ①②③ 未备齐前，**不得执行**合并。

---

## P1 新增安装（证据 p1-simulate.log / p1-apt-update.log / p1-install2.log）

- 模拟先验：`0 upgraded, 383 newly installed`（无已有包被升级）。
- 首次安装因镜像索引滞后 404 失败（p1-install.log，已留证）→ `apt-get update` → 重装成功。
- 装后版本：
  - git 1:2.55.0-1（git version 2.55.0）
  - nodejs 24.22.2+dfsg（node v24.22.2）
  - npm 12.2.0+ds1-1
  - ripgrep 15.2.0-1
  - python3-pip 26.2.2+dfsg-1
  - build-essential 12.12
- npm 全局 registry 已固化 npmmirror（`~/.npmrc user`）。

## P2 ble.sh（证据 p2-blesh.log / p2-blesh-install.log）

- GitHub 直连不通 → 主机下载转带：`ble.sh master` tarball 因缺 git submodule 构建失败（已留证）→
  改 **v0.4.0-devel3-2 预构建 release**（GitHub API 查得真名；主机下载 417KB scp 上机）。
- 安置：`/usr/local/share/blesh/ble-0.4.0-devel3/`（release 无 Makefile，`make install` 不适用，直接 copy）。
- `/root/.bashrc` 备份为 `.bashrc.bak-20261030` 后追加：
  `[[ $- == *i* ]] && source /usr/local/share/blesh/ble-0.4.0-devel3/ble.sh --noattach`
- 验证：真 pty 下 `bash --rcfile /root/.bashrc -i` → ble.sh term 缓存构建完成、提示符正常（见 log）。

## P3 Pi agent 与模型通道（证据 p3-pi-install.log / p3-keys-transfer.log / p3-model-smoke.log / p3-failover-script.log）

- 安装方式（二选一取 npm 全局）：`npm i -g @earendil-works/pi-coding-agent@1.4.0 --registry=https://registry.npmmirror.com`；`pi --version` = **1.4.0**，`pi list` 正常。
- 关键坑：**pi 默认不识别 custom-providers.json** —— 主机靠扩展 `better-custom-provider` 注册；平板补装 `pi install npm:better-custom-provider` 后 `--list-models` 出现 11 个 custom 模型。
- 凭据（只 scp、chmod 600、零打印）：`auth.json`（含 ustc-ai-1..4）、`custom-providers.json`、`custom-providers-auth.json`、`models.json` → 平板 `/root/.pi/agent/`，权限 `-rw-------`。
- 模型通道（架构约束落地）：
  - 本机 litellm 仅绑 127.0.0.1:4000，**实测从平板不可达**（192.168.7.2:4000 探测无响应）；
  - 故平板默认通道 = **直连 api.llm.ustc.edu.cn（custom.ustc）**，实测 `pi --model custom.ustc/deepseek-flash -p ...` → **"OK"**；
  - 判定脚本 `/root/bin/model-channel.sh`：先探 host litellm（未来若对 usb0 开放即优先），不可达再探直连（200/401 视为通），双不通报 `channel=NONE`。当前输出：`channel=direct-ustc ... probe 200`。
  - 平板默认模型已设 `defaultProvider=custom.ustc`、`defaultModel=deepseek-flash`。
- **断电语义**：夜间主机断电 → 平板走直连（key 在平板本地 600 权限文件）→ **模型可用性不依赖主机**；
  主机上电后若对 usb0 开放 4000，脚本自动切回池化通道（当前无需改动 litellm 配置）。

## P4 输入（证据 p4-input.log）

- 现状：phosh（phoc）会话在 tty7 运行；触摸屏 NVTCapacitiveTouchScreen 正常；**无物理键鼠**。
- 屏幕键盘 squeekboard 已安装（phosh 原生 OSK），用户会话内按需弹出（userctl 显示 inactive 属按需拉起，非缺失）。
- 方案：
  - **只有触摸**：phosh 自带终端（kgx/console）+ squeekboard OSK + ble.sh（触屏长按可粘贴；夜班建议仍以 SSH 远程操作为主）。
  - **有 USB/蓝牙键鼠（推荐）**：用户将 USB-C 键鼠/坞站插入 → phosh 即插即用（无需配置）；蓝牙经 phosh 设置面板配对。
  - 物理插拔由用户执行；本 lane 不动外设。

## P5 git 配置与 vlab 尝试（证据 p5-git-vlab.log）

- 平板 git 全局：user.name=Qianhui Xu，user.email=xiaqinghuan@mail.ustc.edu.cn（与主机一致）。rsync 已在。
- vlab：`ssh-keyscan` 成功（ED25519 已入 known_hosts，accept-new）；`ssh git@vlab.ustc.edu.cn` → `Permission denied (publickey,keyboard-interactive)`。
  **无凭据 ⇒ 按纪律停**。缺口：vlab 账号/密钥（用户提供后：写入平板 `~/.ssh/`（600）或 ssh-copy-id，再验 `ssh vlab uname -a`）。

---

## 复现命令

```bash
# 各阶段证据
less reports/artifacts/tablet-offload-20261030/p0-capacity.log
# 版本
ssh root@192.168.7.1 'git --version; node --version; npm --version; pi --version; \
  bash --rcfile /root/.bashrc -ic true; ls -la /root/.pi/agent/*.json | head -4'
# 模型通道
ssh root@192.168.7.1 '/root/bin/model-channel.sh; \
  cd /tmp && pi --model custom.ustc/deepseek-flash -p "Reply with exactly: OK" --no-session'
# vlab 现状（预期 Permission denied）
ssh root@192.168.7.1 'ssh -o BatchMode=yes -o ConnectTimeout=8 git@vlab.ustc.edu.cn echo ok'
```

## 遗留（下一步）

1. vlab 凭据接入（用户）→ 平板→VM 编译链路联测。
2. GitLab 新 PAT（用户）→ 平板 `git push` 到 USTC GitLab 联测（进度完整同步 ④）。
3. linux17/18 合并操作：待 M3-1 v5 结束、回滚等价物（boot_b 镜像 + Alpine 根归档）备齐后另立 lane 执行。
4. 夜间任务队列白名单建议（低 CPU/低 IO）：文档审计/静态分析/git 同步/日志取证/模型调用类 agent 任务；**编译默认走 vlab VM**，平板本地编译仅在 VM 不可用时降级（14G RAM 无 swap，`make -j6` 上限）。
