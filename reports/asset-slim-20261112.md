# 资产/体积精简执行账（2026-11-12，用户「尽可能精简项目体积」）

只删**无损或可再生**件；不动 SSOT、回滚件、在机镜像。前置裁决沿用
`reports/asset-tidy-exec-20261111.md`（用户 11-11「可以精简删除」）与 `reports/project-audit-20261111.md` §2。

**结论先行：本轮净释放 ≈ 4.1 GiB（且全部可回退/可复算）。真正的大头（ROM 16 G / 内核构建对象 35 G /
out 历史归档 7.7 G）属「用户已裁决保留」或「需用户再裁决」，见 §3，本轮不动。**

---

## §1 已执行（净 ≈ 4.1 GiB）

| # | 动作 | 释放 | 可逆性 | 证据/账 |
|---|---|---|---|---|
| 1 | **同内容硬链接去重**：`out/` `backup/` `reports/artifacts/` `dl-cam/` `external/` 内逐字节相同的文件（sha256 全量扫，1556 个 >1 MiB 文件）→ 保留一个实体、其余 `os.link` 同 inode。**删了 0 个文件、改了 0 字节内容**，路径与 `sha256` 全不变 | **1.42 GiB**（170 个链接，最大组：`backup/boot_a-pre-uefi-20261108.img` ×3 = 192 MiB、`out/.migrate-vk152/ramdisk` ×4 = 185 MiB） | 完全可逆（`cp --remove-destination` 即拆链） | 逐条映射在 `/tmp/hardlink-manifest.json`（临时）；判据 `git status` 无内容变化、`check-doctor` FAIL=0 |
| 2 | **`git gc --prune=now`**：把 586 MiB 松散对象收进单一 pack | **.git 1001 MiB → 515 MiB（省 486 MiB）** | 可逆（对象内容不变，仅打包） | `git count-objects -vH`：loose 0、`size-pack` 513.57 MiB；`git fsck` 由 gc 内跑 |
| 3 | **删除被取代的 UEFI 试验镜像**：`out/r21-sbstop/`（p7 世代）、`out/r21-sbstop-p66/`、`-p67/`、`-p68/`（三发均**早于** `dtbo_a` 真根因、全部卡 logo 的失败世代） | **2.2 GiB**（257 M + 3×641 M） | 件可再生：`scripts/uefi-r21-p7-ladder.sh --gen pNN` + `patches/uefi/` 配方；sha 账保留 | `reports/artifacts/uefi-purged-20261112/SHA256SUMS`（35 行，逐件 sha256） |
| 4 | 同步删除 `out/` 中混放的 p7 世代件（同 #3 第 1 项，已在同一行计） | — | 同上 | 同上 |

**保留（不动）**：`out/r21-sbstop-p69/`（flashed 形态**成功**世代，129.2 s 起 Linux）、`-pc1/`（DEVICE §1.1 引用的干净世代取证件）、`-pc2/`（最新一件）——三件合计 1.9 GiB，是 UEFI 线唯一有判据价值的现场件。

`df /` 与目录体量变化：`out/` **8.3 G → 5.6 G**；`.git` **1001 M → 515 M**；项目内 >1 MiB 文件的实际占用再降 1.42 G（du 逐目录体现）。

---

## §2 脚本/数据冗余核查（结论：脚本侧无可删）

- `scripts/` 共 **243** 个可执行/源码文件（2.0 MiB），跨全仓外部引用计数（`rg -o 'scripts/<name>'`，3581 处）：
  **236 个被至少一处引用**。
- 未被外部引用的 7 个（合计 **40.6 KiB**）：`99-unmanaged.conf`（NetworkManager 配置件）、`doc-assets-allowlist.txt`
  （`check-doc-assets.sh` 的数据）、`elden-hapticd.c` / `ffrumble.c` / `eldroid-sensord.c`（`packaging/elden-userland`
  编译源，经 recipe 引用）、`elden-powerlog.initd`、`eldroid-bootctl`（TASKS 内以 `scripts/eldroid-bootctl` 形式引用，
  抽取正则漏计）。**均非死代码，且总量 40 KiB ⇒ 删脚本没有收益，不动。**
- 无逐字节重复脚本（`md5sum scripts/*` 无同值组）。

---

## §3 大件（**2026-11-12 用户裁决：先不动** —— 本节只留账，下次不要再提议）

> 用户原话：「裁决大件文件先不动」。⇒ ROM 16 G、内核构建对象 35 G、`wt/reb-731` 13 G、`out-history` 7.7 G、
> `dl-cam/ndk` 2 G、Gunyah clones 1.8 G **一律不删不压**。仅在磁盘压力真正出现（`df /` 可用 < 100 G）时
> 重新提请裁决，并把本节数字当基线。

| 路径 | 体积 | 是什么 | 现状/障碍 | 若要精简的建议 |
|---|---|---|---|---|
| `backup/official-rom-15.10.259/` | **16 G** | 官方 259 全量线刷包（`super_1..8.img` 占 15 G，`super_4.img` 单件 12 G） | 11-11 裁决「官方固件不可再生 ⇒ 保留」；实测 `zstd -3` 压缩率仅 1.68/2.0（前 2 G 样本）、`super_7` 0.43 | ① 只把 `super_*.img` 打成 `tar.zst` + 恢复脚本（保小分区件可直刷）；② 或只保留 unbrick 必需分区件（abl/xbl/devcfg/gpt/vbmeta/boot…，约 1 G） |
| `build/` 四棵内核树 | **35 G**（`daily` 13 G / `uefi-woa-prep` 8.2 G / `m3v2` 4.9 G / `base-7.2` 2.4 G） | `.o`/`vmlinux` 等构建中间物 | 保留理由 = 增量重建速度（11-11 用户裁决保留 `build/daily|m3v2`） | 只清**已停用线**的对象（`wt/reb-731` 13 G 自 11-08 未动、`base-7.2`），源与 `.config` 全留 |
| `wt/reb-731/` | **13 G** | 7.3.1 重建 worktree（含 `drivers/` 6.4 G 对象） | 11-05/11-10 用户裁决保留（可复现源 + 回滚依赖） | `make clean` 级清理（源/补丁/`.config` 不动）⇒ 约 2 G |
| `backup/out-history-20261105/` | **7.7 G** | 114 件历史 `out/*.img` 归档 | `scripts/vk-identity.py` 与 `check-doctor §5d` **扫这个目录**，删/压会破版本账门 | 若要清，必须同轮改 `vk-identity.py` 扫描口径 + 归档账，属「改门禁」而非「清文件」，需单独一轮 |
| `dl-cam/ndk`（1.7 G）+ `sysroot`/`aosp` | 2.0 G | 相机烘焙用 NDK/AOSP 头 | 11-11 保留理由 = 当时外网不通、删了没有离线重烘焙能力 | 现在 `gh`/外网可用 ⇒ 可删并记 Google NDK 下载源；重烘焙前先下载 |
| `build/uefi-woa-prep/repos/{1,3,4}-*gunyah*` | **1.8 G** | Gunyah VM 线克隆（edk2-gunyah 1.5 G、qemu-for-gunyah 198 M、edk2-gunyah-qemu 165 M） | Gunyah **2026-10-25 已终局裁决不做**；均为可从 GitHub 重克隆的纯 clone | 可直接删（clone URL 记在 `build/uefi-woa-prep/repos/clone.sh`） |

> 说明：`build/uefi-woa-prep/repos/7-mu-lenovo`（5.6 G）是 UEFI 载荷**构建源**，`5-mu_wide_platforms` 亦在用，均不动。

---

## §4 与 SSOT 的对齐

- `TASKS/README.md` §5 顶部「镜像件口径」注已写明历史 UEFI 试验件只留账；本轮把 `r21-sbstop`/`p66`/`p67`/`p68`
  真正删掉后，**磁盘与文档口径一致**（p69/pc1/pc2 仍在，`.manifest` 与 sha 账在 §1 第 3 行）。
- 删件 sha 账 = `reports/artifacts/uefi-purged-20261112/SHA256SUMS`（**入库**），按此可判「某个历史发次用的是哪件」。
