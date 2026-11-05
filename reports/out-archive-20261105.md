# `out/` 历史镜像归档执行（2026-11-05）—— 114 件 / 7.66 GiB

> 结论先行：`out/*.img` **129 件 → 15 件**（8.78 GiB → 1.12 GiB），114 件历史镜像 `mv` 到
> `backup/out-history-20261105/`（7.7 G，逐件 sha 账 + 回滚脚本）；`versions/vk-kernel-identity.tsv`
> **一行未改**且 `--all` 的新鲜度仍是 `C=0`；`check-doctor` **FAIL=0 / WARN=4**（与归档前同）。
> 同时在本轮取证中实测到**页缓存位翻转**（同文件普通 read 与 `O_DIRECT` read 哈希不一致），
> 已沉淀 `PITFALLS #513`，并修正了归档账里 1 条被污染缓存算错的 sha。

## 0. 为什么不是删

每件 `out/*.img` 在 `versions/vk-kernel-identity.tsv` 都有身份行（构建号 ↔ 内核二进制 sha ↔ 源提交）。
删文件 = 永久失账（2026-10-17 换机后 `out/*.img` 全丢，身份表只能靠 `.manifest` 残件重建）。
本轮口径 = **文件本体一律保留，只换路径**；`out/` 只留在用件与取证件。

## 1. 账目-门禁耦合（事实，带 file:line）

| 事实 | 位置 |
|---|---|
| 身份表 `image` 列是 **basename**，不含目录 | `versions/vk-kernel-identity.tsv` 表头 |
| §5d 新鲜度门 = 「现扫盘生成的表」与「已提交表」逐行比对 | `scripts/vk-identity.py` `fresh()` |
| 扫描源原为 `glob(out/*.img)` ⇒ 文件一移走，生成表就少行 ⇒ `C=1` ⇒ doctor §5d **FAIL** | 本轮实测：`mv out/boot-elden-vk132.img /tmp` 后 `C` 由 0 变 1（已还原） |
| `--gate` 的「新构建硬错 vs 存量欠账」用 `os.path.exists(img)+mtime` 分类 ⇒ 路径错位会把归档件降级成存量 | `gate_lines()` |

因此**不能**「先移文件再改表」，也**不能**重跑 `vk-identity.py` 覆盖表（换机事故配方：
镜像缺失会把整表刷成 `(no-payload)`）。本轮改为**让脚本同时扫归档目录**：

- `scripts/vk-identity.py` 新增 `ARCHIVE_GLOB = backup/out-history-*`、`out_images()`（out/ + 归档目录，
  按 **basename 排序** ⇒ 与归档前的行序逐行一致）、`manifest_for()`（`.manifest` 留在 `out/`，
  归档件回退到 `out/<basename>.manifest` 查找）、`gate_lines()` 的 basename→路径索引。
- 验证：改脚本后**未移文件时** `python3 scripts/vk-identity.py | diff - versions/vk-kernel-identity.tsv` = 空；
  归档 114 件后再 diff 仍为空、`--all` 的 `C` 仍为 0。

## 2. 保留集（15 件 / 1.12 GiB）与判据

| 保留件 | 理由（出处） |
|---|---|
| `boot-elden.img` | `scripts/build-boot.sh` 默认输出名，每次构建重生（`unversioned` NOTE 类） |
| `vk172` `vk173` | 当前 UTS 基准线；设备 `/lib/modules` 与 `uts_dup` 口径以它为准（`versions/vk-ledger-known-issues.tsv`） |
| `vk181-daily` | B5 实验后**日常线还原件**（设备复原用），registry `b5-verify` |
| `vk182-camssv3` | M4 camss v3 上机复验件（registry `m4-v3`） |
| `vk183-fastrpc` | 传感器/fastrpc 上机件，`DEVICE §1.1` 当前在机线的最后一发（`boot_b` 签名源） |
| `m3v5-onboard` / `m3v5-onboard-b` / `m3v5-f2` | M3-1 线现役实验件，`RESOURCES §3` 与 `reports/m3v5-onboard-plan-20261030.md` 在引 |
| `m3v5-daily` | **取证锚点**：2026-11-03 静默损坏件（`PITFALLS #512` 实物证据） |
| `posctrl-20261103` | UEFI DDR 黑匣子**正控载荷**（`reports/uefi-posctrl-20261103-summary.md`） |
| `uefi-20261104R-r1` / `-fixcopylen` | `out/SUPERSEDED.md` 判定的**唯一有效件**（新 shim，`verify_built_image()` 硬断言通过） |
| `uefi-20261104R7-r1` / `uefi-20261104R21-hostdiag-r1` | `TASKS §5` 的 11-04 晚块当前在引（R7 屏上判据、R21 宿主诊断） |

其余 114 件（`vk132`–`vk180`、`vk64`、`vk127`、`dtbo{1,2,3}`、`gh612a/b`、`gunyah1`、`f2fs-root`、
`m8ab-*`、`linuxstop1-7`、`r20-stop1-6`、`uefi-20261104-dxe*` 等 SUPERSEDED 件、
`uefi-ddrmarks-sysram-rd`、`posctrl-markspin*`）→ 归档。

判据口径：**「当前在机/在用线」+「取证锚点」+「最新一条线」** 留 `out/`；历史叙事引用（`reports/` 里的
过去时句子）不算保留理由——归档后路径仍可查（`backup/out-history-20261105/<name>`），账在
`backup/out-history-20261105/ARCHIVE.tsv`。

## 3. 执行与账

```bash
python3 scripts/out-archive.py            # dry-run（列保留/归档、体积、不在账的件）
python3 scripts/out-archive.py --apply    # 真 mv + 写 ARCHIVE.tsv + ROLLBACK.sh
```

- 新增脚本 `scripts/out-archive.py`（幂等：目标已存在则跳过不覆盖；`--date` 指定批次）。
- 归档账 `backup/out-history-20261105/ARCHIVE.tsv`：`sha256 / bytes / image / in_ledger / 路径`（114 行）。
- 回滚 `backup/out-history-20261105/ROLLBACK.sh`（114 条 `mv` 反向命令，`sh` 直接跑）。
- **净释放 = 0 字节**：同一文件系统内 `mv` = rename。要真回收需 `tar.zst`（按 `boot.img` 里
  kernel+ramdisk 的 gzip 比例粗估 2.5–3×，即 ~2.6–3.1 G）或上云后删；本轮**不做**，因为
  用户口径是「设备等价、产物设备无关、零证据损失」。

## 4. 校验（判据与实测）

| 判据 | 结果 |
|---|---|
| `python3 scripts/vk-identity.py | diff - versions/vk-kernel-identity.tsv` | **空**（归档前后各一次） |
| `python3 scripts/vk-identity.py --all \| grep '^C'` | `C 0`（新鲜度门通过） |
| `bash scripts/check-doctor.sh` | **FAIL=0 WARN=4**（与归档前相同；§5d 4 条 warn 未增加） |
| 129 件镜像对基线 `versions/out-images-sha256-20261105.tsv`（**O_DIRECT 读**） | **129/129 一致** |
| `backup/out-history-20261105/ARCHIVE.tsv` 逐件 sha（O_DIRECT） | 114/114 一致（其中 1 件修正，见 §5） |

基线表本轮改造：`versions/out-images-sha256-20261105.tsv` 增加第 7 列 `path`（相对仓库根），
复算命令从 `print $1"  out/"$3` 改为 `print $1"  "$7`（**勿再拼接 `out/`**）。

## 5. 本轮新增证据：页缓存位翻转（与归档无关，但决定校验方法）

归档账第一版把 `uefi-20261104-dual.img` 记成 `35c9cd18…`，而基线是 `351640e2…`。排查结果：

| 读法 | sha256 |
|---|---|
| 普通 read（`sha256sum`，命中页缓存） | `35c9cd18…`（错，≥7 字节与磁盘不同） |
| `dd if=<file> iflag=direct` | `351640e2…` = 基线（**磁盘内容完好**） |

同一现象在 `out/boot-elden-vk158.img` 上先出现一次（页缓存 `932ea232…` vs `O_DIRECT` `b882abcd…`，
重启后普通读也恢复正确）。⇒ **本机存在内存/页缓存级位翻转**，`sha256sum` 单次读通不代表文件好、
也不代表文件坏。取证纪律见 `PITFALLS #513`：**基线校验一律走 `O_DIRECT`**。

⚠ 另一条危险动作：`echo 3 > /proc/sys/vm/drop_caches` 在本机**直接把主机卡死并自动重启**
（2026-11-05 15:36 实测，第二次同症状）。要清缓存用「重启」或用 `O_DIRECT` 绕过，**不要再发。

## 6. 未做 / 待裁决

- **`out/` 里的非镜像产物未动**：`debian/`（683 M）、`stage-debian/`（135 M）、`modstage-vk{163,172}/`
  （183 M）、`m3v5-onboard/`（107 M）、`corrupt-20261102/`（106 M）、`uefi-*/` 小目录、
  `*.cpio.gz`（4 件 ≈ 259 M）、`vk1xx-*kernel.gz`（9 件 ≈ 180 M）、`vk134-Image`（61 M）、
  mail 草稿目录。它们是**构建/取证素材**而非产物镜像，清理需各自的前置闸（`debian/` 是 Debian 根
  tarball 源、`corrupt-20261102/` 是损坏取证件），单独立项。
- **真回收空间**（tar.zst 或上云后删）未做：用户口径未批准压缩归档。
- `reports/` 里 114 条历史叙事引用仍写 `out/<name>.img`（过去时句子，按口径不改）；
  `scripts/check-doc-assets.sh` 对 `out/*` 早有豁免，doctor §13 仍绿。
