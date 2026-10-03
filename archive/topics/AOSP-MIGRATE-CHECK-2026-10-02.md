# AOSP 迁盘校验 — 2026-10-02（→ 1T Samsung `/mnt/Samsung`）

> 结论一句话：**源码数据零损失**（1219 个 git 对象库全量 `fsck` 通过、1254 个项目工作区齐全）；
> 发现 **1 个迁移前就已损坏的仓库**、**1 份 23G 冗余副本**、**4 处失效的路径引用（已改）**、**1 个 fstab 隐患**。

---

## 0. 现状盘点

| 项 | 值 |
|---|---|
| 新盘 | `/dev/nvme0n1p1` = SAMSUNG **MZVL21T0HCLR (PM9A1) 953.9G**，ext4，UUID `1847ae03-b2ee-4ed4-af0e-ffd8b50a440b` |
| 挂载 | `/mnt/Samsung` — 938G 总 / **已用 551G** / 可用 341G |
| 盘上内容 | `waydroid-build/` **550G**、`ccache/` 166M、`lost+found/`（空） |
| 根盘 | `/` 468G 已用 184G，**可用 261G**（AOSP 树搬走后已松绑） |
| 旧位置 | `~/waydroid-build`、`/mnt/data`（旧盘 UUID `34ba7b2b…`）**均已不存在**，且**没有留符号链接** |

> 注：`setup-newdisk.sh` 里写的目标是另一块 1T（MZVL41T0HBLB / SN `S6B7NF0TA34973`，挂载点 `/mnt/nvme0`）。
> 现在这块是 **PM9A1**，挂载点 `/mnt/Samsung` —— 脚本里的盘型号/挂载点都已过时，仅当历史参考。

---

## 1. 完整性校验（做了 4 层，全部通过）

| 校验 | 方法 | 结果 |
|---|---|---|
| **① 项目齐全** | `.repo/project.list` 逐条比对工作区目录 + `.repo/projects/*.git` | **1254 / 1254**，缺失 **0** |
| **② 对象库完整** | `find .repo/project-objects -type d -name objects` → 每库 `git fsck --connectivity-only`（校验每个 pack/loose 对象的 SHA 与可达性） | **1219 / 1219 库 OK，0 error**（`logs/aosp-migrate-20261002/aosp-fsck2.log`、`aosp-fsck3.log`；`.repo` 共 439G） |
| **③ pack 文件** | pack 数量 1240，逐个查 `.idx` 是否存在、是否有 0 字节 pack | 缺 `.idx` **0**，0 字节 pack **0** |
| **④ 工作区内容** | 随机 24 个仓库（含 12G 的 `prebuilts/clang`、`art`、`external/cldr` 等）`git status --porcelain --no-renames` | **24/24 干净**（无缺失/截断文件） |

**关键内容点验（都在，且状态正确）**

- 本地清单 12 个自建项目全部在位：`device/waydroid/waydroid`、`hardware/waydroid`、`vendor/extra`、
  `packages/apps/WaydroidUpdater`、`external/mesa`、`external/libdrm`、`external/llvm-project`、
  `external/minigbm`、`prebuilts/mesa-tools`、`prebuilts/vndk/v28|v29|v30` — 全 `OK`。
- `.repo/local_manifests/02-waydroid.xml` 第 17 行的 Mesa 覆写仍在（`lineage-18.1-mesa-26.1`）。
- `external/mesa` HEAD = `6ba7c2f4ce2`（`ghub/lineage-18.1-mesa-26.1`，即 **Mesa 26.1.8**），工作区干净。
- **全树唯一一处本地修改** `device/waydroid/waydroid/waydroid_arm64_only/BoardConfig.mk`
  （只留 freedreno、`BOARD_MESA3D_GALLIUM_VA=disabled`、`VIDEO_CODECS=all_free`）**已随之迁盘成功**；
  我已另存一份 → `y700-elden/patches/waydroid-boardconfig-freedreno-only.patch`（防将来 `repo` 操作吃掉它）。
- `out/` 构建现场 11G（soong 状态 / `build.ninja` / `out/target/product/waydroid_arm64_only/`）在位；
  无指向旧盘的绝对路径或绝对符号链接（已 grep 确认）。
- 未同步的 9 项 = `external/mesa3d`（被本地清单 `remove` 后由 `external/mesa` 取代）+ `external/adt-infra`
  + `tools/{base,build,idea,motodev,adt/idea,studio/cloud,swt}`（默认 group 排除，与本构建无关）→ **不是遗漏**。

**产物（在根盘，未随迁）**：`~/mesa-out/` = 7MB，含 `mesa-vendor-26.1.8_waydroid_arm64_only.tar.gz` +
分好的 `lib64/{libgallium_dri,libgbm_mesa,dri_gbm,libgbm_mesa_wrapper}.so` + `egl/*` + `manifest.txt`（sha256）。
这是**上次构建的成品**，建议一起备份（见 §4）。

---

## 2. 发现的问题（与处置结果）

> ✅ **2026-10-02 19:15 已按本报告处置完毕**（只余 fstab 需你 sudo）：
> ② 23G 冗余副本已删 • ① 坏仓库已按方案 B 从清单移除（`repo manifest` 解析 1253 项，gcc-4.9 已不在清单）
> • `tmp_pack_*` 33 个/4.1G 垃圾已清 • `~/mesa-out` 已迁新盘并留软链 • `~/y700类原生安卓/l2` 45G 已迁新盘
> （**三个大镜像两侧 sha256 逐个比对一致**后才删源）并留软链。
> 空间：**根盘可用 261G → 306G**；新盘 573G 已用 / **319G 可用**。
> ③ fstab 补 `nofail` 需 sudo，脚本已备好：`sudo bash ~/y700-elden/scripts/fix-fstab-samsung.sh`（幂等、自动备份、自带校验）。

### 2.1 ⚠️ 唯一损坏的仓库 —— **不是迁移造成的，是迁移前 fetch 中断**
`prebuilts/gcc/linux-x86/x86/x86_64-linux-android-4.9`

- 症状：2 个 ref 文件内容为空（`refs/remotes/m/lineage-20.0`、`refs/remotes/github/lineage-19.1`）→
  `fsck: badRefContent`；`.git/index` **0 字节**（`索引文件比预期的小`）；工作区只有 **88K**（本应 ~1G）。
- 时间线：空 ref 的时间戳 **10-01 15:46**；`sync.log` 里从 attempt 18→20（**10-02 01:43–01:56**）报的
  是**同一条** `fatal: bad object refs/remotes/github/lineage-19.1`，最后 `giving up after 20 attempts`。
  → 即：**树还在旧位置时就坏了**，`mv` 只是把坏状态原样搬过来。
- 影响：**不影响本构建**（arm64 Waydroid vendor 走 `prebuilts/clang`，这个 x86 的 gcc-4.9 主机工具链用不上）。
  但它是 `repo sync` 唯一持续的失败源。
- 两个修法（任选，都需联网）：
  ```bash
  cd /mnt/Samsung/waydroid-build
  # A) 重下这一个项目（~1G，恢复后 repo sync 就干净了）
  rm -rf .repo/projects/prebuilts/gcc/linux-x86/x86/x86_64-linux-android-4.9.git \
         .repo/project-objects/LineageOS/android_prebuilts_gcc_linux-x86_x86_x86_64-linux-android-4.9.git \
         prebuilts/gcc/linux-x86/x86/x86_64-linux-android-4.9
  ~/bin/repo sync -j4 prebuilts/gcc/linux-x86/x86/x86_64-linux-android-4.9

  # B) 本构建用不到 → 直接从清单里去掉（加一行，随时删掉该行即回退）
  echo '  <remove-project name="LineageOS/android_prebuilts_gcc_linux-x86_x86_x86_64-linux-android-4.9" />' \
    >> .repo/local_manifests/01-removes.xml
  ```
  > 顺带垃圾：`.repo/project-objects/**/tmp_pack_*` 共 **44 个 / 4.1G**，全是 fetch 中断留下的临时包，纯垃圾：
  > `find .repo/project-objects -name 'tmp_pack_*' -delete`

### 2.2 🔁 23G 冗余副本（可删，回收 23G）
`/mnt/Samsung/waydroid-build/waydroid-build/` —— 一次失败的复制留下的残骸：只有 `.repo`（**23G**，310 个对象库）
+ `setup-newdisk.sh`，时间戳停在 **10-01 19:09**，没有任何工作区/`project.list`。

已核实它是**严格子集**：310 个对象库**全部**也存在于主 `.repo`（共 1219 个，独有 **0** 个）；`local_manifests/` 与
`setup-newdisk.sh` 与主树**逐字节相同**。→ 无独有数据，可安全删除：
```bash
rm -rf /mnt/Samsung/waydroid-build/waydroid-build     # 回收 23G
```

### 2.3 🔧 失效的路径引用 —— **已改好**（旧路径 `~/waydroid-build`、`/mnt/data` 全机已不存在）

| 文件 | 改动 |
|---|---|
| `y700-elden/scripts/mesa-build.sh` | `TREE` → `/mnt/Samsung/waydroid-build`（可用 `AOSP_TREE=` 覆盖）；`CCACHE_DIR` → `/mnt/Samsung/ccache` |
| `y700-elden/scripts/extract-mesa-libs.sh` | `TREE` 同上 |
| `y700-elden/scripts/wd.sh` | `sync` 子命令 `cd` 到新树、`df` 看 `/mnt/Samsung` |
| `/mnt/Samsung/waydroid-build/space-watch2.sh` | `MNT=/mnt/Samsung` |
| `/mnt/Samsung/waydroid-build/PROGRESS.md` | 顶部加迁盘横幅；ccache 路径更正 |

`repo`/`git-lfs` 仍在 `~/bin`、`~/.repoconfig` 在位、`git` 全局 `insteadOf` 现指 **USTC** AOSP 镜像
（`https://mirrors.ustc.edu.cn/aosp/` ← `android.googlesource.com`，PROGRESS.md 里写的清华源已被它取代）→ 工具链无遗漏。

### 2.4 ⚠️ fstab 隐患（需你本人 sudo，我没动）
```
UUID=1847ae03-b2ee-4ed4-af0e-ffd8b50a440b  /mnt/Samsung  ext4  defaults  0  2
```
**缺 `nofail`**：这块盘一旦没插/掉盘，开机会卡在 fsck+掉进 emergency shell（当初 `setup-newdisk.sh`
是特意写 `defaults,nofail,x-systemd.device-timeout=10` 的，手工那行漏了）。建议：
```bash
sudo sed -i 's#\(UUID=1847ae03[^ ]*  /mnt/Samsung  ext4  \)defaults#\1defaults,nofail,x-systemd.device-timeout=10#' /etc/fstab
sudo systemctl daemon-reload && findmnt /mnt/Samsung
```
（顺带：`/mnt/data` 那条 nofail 条目指向已下线的旧盘，留着无害，也可删。）
另：挂载点权限 `drwx------ (700)` — 只有你本人可进入；若以后要让容器/其他用户读，改 755。

### 2.5 📦 有意**没**搬的（确认一下是否符合你的预期）
| 位置 | 大小 | 判断 |
|---|---|---|
| `~/y700类原生安卓/l2/` | **45G**（`super.img.raw` 23G、`system_a.img` 12G、`system_a.pristine.img` 12G） | `move-to-newdisk.sh` 里的可选 `MOVE_L2=1` 项，**没执行**。原厂 super/system 拆包，重取很贵 → 想搬就 `mv` 过去再留软链 |
| `~/mesa-out/` | 7M | 构建**成品**，建议随源码一起进新盘/云盘 |
| `~/下载/lineage-20.0-*-waydroid_arm64_only-{system,vendor}.zip` | 1.2G | 可重下，不必搬 |
| `~/bin/{repo,git-lfs}`、`~/.repoconfig` | 22M | 属主机工具，留在根盘正确 |

---

## 3. 一句话答案

**没有损失**：1254 个项目 + 1219 个对象库（439G）全部通过校验，本地清单/构建配置/唯一本地改动都在；
`mv` 是整目录搬迁、旧目录已清空，未发现截断或缺文件。
**收尾状态**：① 坏仓库已从清单移除 ✅ ② 23G 冗余已删 ✅ ④ l2(45G)+mesa-out 已迁盘 ✅
**仅剩 ③**：给 fstab 补 `nofail`（需 sudo）。

## 4. 建议的最小备份集（很小，但能复现整条构建）
`~/y700-elden/patches/waydroid-boardconfig-freedreno-only.patch`（唯一本地改动）、
`/mnt/Samsung/waydroid-build/.repo/local_manifests/`（3 个 xml，Mesa 覆写）、
`~/y700-elden/scripts/{mesa-build,extract-mesa-libs,mesa-deploy,waydroid-mesa-swap}.sh`、
`~/mesa-out/`（成品 tar + manifest.txt）。→ 可用 `ustc-cloud-drive` 技能推一份。
