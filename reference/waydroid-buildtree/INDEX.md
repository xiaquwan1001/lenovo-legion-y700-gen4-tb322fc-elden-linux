# waydroid-buildtree — AOSP 树的「树外本地件」留档

> **为什么有这个目录**：G2 的 Waydroid 构建树在 `/mnt/Samsung/waydroid-build`（**530 G**，外置盘，
> 该盘 2026-10-16 用户告知**将要清空**）。树本身可 `repo init + sync` 重下、`out/` 可重建，
> 但**树外有一批本地独有件不在任何 git 仓里**（repo 清单覆盖、构建脚本、日志）。本目录就是它们的留档。

## 1. 本地代码改动的去向（**权威 = USTC GitLab，不在本目录**）

树里的两个项目有本地提交，**已推 USTC 并已用服务端 `ls-remote` 核对**（2026-10-16）：

| 工作区 | 本地分支 | HEAD | USTC 仓 |
|---|---|---|---|
| `device/waydroid/waydroid` | `elden/lineage-20` | `79de788` | `git@git.ustc.edu.cn:xqh/y700-elden-waydroid-device.git` |
| `hardware/waydroid` | `elden/lineage-20` | `944b06a` | `git@git.ustc.edu.cn:xqh/y700-elden-waydroid-hardware.git` |

- 基线 = 上游 `ghub/lineage-20`（device `2234f4b` / hardware `6e898e9`）。
- 本地提交内容：freedreno-only Mesa3D、Codec2 codec XML（去 OMX）、**elden UDP sensors HAL**、
  **elden vibrator AIDL HAL + 振动强度 RRO**、gatekeeper 修等（C2/C4/C6/C10 的容器侧改动）。
- **全树扫描**：1254 个项目的 `git rev-list --branches --not --remotes` **全为 0** ⇒ 没有任何本地提交只存在于该盘。
- 文本留档：`../../patches/waydroid-buildtree-local-20261016.patch`（两项目 vs 上游合并基的完整 diff，23 文件；
  **取代** 已过期的 `waydroid-buildtree-local-20261011.patch` —— 后者缺 10-13 的 vibrator/haptics 提交）。

## 2. 目录内容（树外本地件）

| 路径 | 是什么 | 为什么不能丢 |
|---|---|---|
| `local_manifests/{00-remotes,01-removes,02-waydroid}.xml` | `repo` 本地清单覆盖：新增 GitHub 远端、移除损坏/不需要的 LineageOS 项目、把 4+4+4 个 WayDroid 相关项目指到指定 revision | **不在任何 git 仓**；缺了就无法复原这棵树的项目集合与分支选择 |
| `repo-manifest.xml` | `repo init` 时的入口清单（`<include name="default.xml">`） | 记录 init 口径 |
| `scripts/build-vendor-c2.sh` | `m vendorimage` 构建入口 | C2/C6/C10 的构建口径 |
| `scripts/setup-newdisk.sh` | 换盘后重建 `out/` 与 ccache 指向 | 换盘/清盘后复建用 |
| `scripts/space-watch{,2}.sh` | 构建期磁盘守护 | 环境经验 |
| `scripts/sync-{resume,resume2,adaptive}.sh` | fetch/sync 断点续传与限速 | 弱网下重下 530 G 的必需件 |
| `PROGRESS.md` | 该树当时的进度记录（2026-10-02） | 一手记录 |
| `logs/build-vendor-c2.log{,.fail1-3}`、`sync.log`、`space-watch{,2}.log` | 构建/同步原始日志 | 失败链证据（`m vendorimage` 三次失败→成功） |

## 3. 重建这棵树（清盘后）

```bash
mkdir -p /mnt/Samsung/waydroid-build && cd /mnt/Samsung/waydroid-build
repo init -u https://github.com/LineageOS/android.git -b lineage-20.0   # 口径见 repo-manifest.xml
mkdir -p .repo/local_manifests
cp <本目录>/local_manifests/*.xml .repo/local_manifests/
repo sync -j8 --no-clone-bundle          # 断点续传用 scripts/sync-resume*.sh
# 取回本地改动：
git -C device/waydroid/waydroid  remote add ustc git@git.ustc.edu.cn:xqh/y700-elden-waydroid-device.git   && git -C device/waydroid/waydroid  fetch ustc elden/lineage-20 && git -C device/waydroid/waydroid  checkout -B elden/lineage-20 FETCH_HEAD
git -C hardware/waydroid         remote add ustc git@git.ustc.edu.cn:xqh/y700-elden-waydroid-hardware.git && git -C hardware/waydroid         fetch ustc elden/lineage-20 && git -C hardware/waydroid         checkout -B elden/lineage-20 FETCH_HEAD
# 构建：bash scripts/build-vendor-c2.sh   （产出 out/target/product/waydroid_arm64_only/vendor.img）
```

> `ustc` 这两个 remote 原先只写在 `.repo/projects/*/config` 里（**随盘清空而丢失**）⇒ 本节 + `RESOURCES/README.md` §3 是它们的唯一文字记录。

## 4. 不在本目录

- **构建产物**：`out/target/product/waydroid_arm64_only/vendor.img`（86 M，含 C2/C10 固化态）——已进云盘包（`~/cloud-backup-y700-elden-20261016/T2-.../`）；
  也可由本目录脚本 + USTC 源重编（`m vendorimage`，1–3 h）。
- **大镜像**：`/mnt/Samsung/l2/*.img`（47 G）、`ccache`、`fiotest` —— 见 `../../reports/cloud-backup-manifest-20261016.md` §5（云全量包已覆盖 / 可重建）。
- **上游项目本体**：1254 个项目的源码（可 `repo sync` 重下）。
