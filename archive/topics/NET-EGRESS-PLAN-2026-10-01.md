# 资源下载与出口选择（y700-elden / waydroid 构建）

> **本文只记「本项目要下的资源 → 走哪条出口」。**
> 网络可达性矩阵、测速方法论、排雷（代理环境变量污染等）已移到全局：
> 技能 `~/.pi/agent/skills/networking/network-egress-selection/SKILL.md`、
> 记忆 `~/.pi/agent/memory/{HINDSIGHT,FAILURES}.md`。

## 1. 本机出口（概览）

| 出口 | 接口 | 谁在用 |
|---|---|---|
| 教育网有线 | `enp6s0`（网关 `114.214.176.1`） | **IPv6 默认走这里**；IPv4 需显式路由 |
| 手机热点 | `wlp5s0`（网关 `192.168.43.1`） | **IPv4 默认走这里**（metric 600 < 20050） |
| 设备直连 | `enx…`（`192.168.7.2`） | 主机 ↔ Y700 |

## 2. 本项目资源清单 → 出口

| 资源 | 量 | 出口 | 预期速率 | 状态 |
|---|---|---|---|---|
| **AOSP（LineageOS 树里的 AOSP 部分）** | 增量 100–300 GB | ✅ **USTC 镜像 `/aosp/`（走 IPv6 → 自动有线）** | ~100 MB/s | 已切换 |
| **LineageOS GitHub 仓库** | 大头（剩余） | ⚠️ **代理**（`ghub` remote = github.com；无 AAAA，教育网到不了） | 1.3–1.9 MB/s | 唯一瓶颈 |
| Alpine 包（宿主/设备 rootfs） | 数十 MB–GB | ✅ USTC `/alpine/` 或 `dl-cdn` via IPv6 | 50–100 MB/s | 备用 |
| apt（Ubuntu 26.04） | 若干 GB | ✅ 已配 `mirrors.ustc.edu.cn/ubuntu` | 50–100 MB/s | 现成 |
| pip | 若干 | ✅ 已配 USTC pypi | 50–100 MB/s | 已切换 |
| Android NDK（dl.google.com） | ~1 GB | IPv6 或代理（**路线已放弃**） | ~10 MB/s | 不需要 |
| Waydroid 官方镜像（SourceForge） | 0.8 GB | 代理 | — | 已完成 |
| 内核/EDL/boot 资产 | MB 级 | 本地 / 设备直连 | — | — |
| USTC 云盘备份 | GB | ✅ 有线（校内） | 高 | 备用 |

## 3. 已落地的配置改动（可复现）

```bash
# ① AOSP 镜像 TUNA → USTC（USTC 有 AAAA，IPv6 默认走有线口，免改路由）
git config --global url."https://mirrors.ustc.edu.cn/aosp/".insteadOf \
                   "https://android.googlesource.com/"

# ② PyPI → USTC
pip config set global.index-url https://mirrors.ustc.edu.cn/pypi/web/simple

# ③ 续传脚本 ~/waydroid-build/sync-resume2.sh：
#    - no_proxy 已含 ustc.edu.cn（保证 AOSP 直连、不走代理）
#    - precheck 改为 USTC；github 仍走 127.0.0.1:7897 代理
nohup ./sync-resume2.sh >> sync.log 2>&1 &

# ④ 需要强制 CERNET 段走有线时（临时，重启失效）
sudo bash ~/y700-elden/scripts/net-egress.sh mirrors
```

验证是否真吃到有线：
```bash
curl --noproxy '*' -s -o /dev/null -w '%{remote_ip}\n' \
  https://mirrors.ustc.edu.cn/aosp/      # 期望 2001:da8:d800:95::110（IPv6 → 有线口）
```

## 4. 当前瓶颈与待决策

- `repo sync` 实测 **~1.9 MB/s，全部卡在 GitHub 经代理**；`.repo` 428 GiB，磁盘剩 359 G。
- 选项：
  - **A. 换更快的 Clash 节点**（若能到 10 MB/s，剩余时间砍到 1/5）—— 需要用户；
  - **B. 接受现状**，断点续传慢慢跑。
- GitHub 公共镜像（ghproxy.net / gh-proxy.com 等）实测只有 25–49 KB/s，**不建议**。

## 5. 相关资产

| 文件 | 内容 |
|---|---|
| `scripts/net-egress.sh` | `test / mirrors / all / revert / status`（临时路由，需 sudo） |
| `scripts/wd.sh` + 设备 `/usr/local/sbin/wd-ctl.sh` | Waydroid 快速状态/启停（0.3s 快照） |
