# T2 产出 2 — 磁盘清理建议清单（cleanup-candidates.md）

> 生成：2026-10-10 资产整理子代理（worker）。**只建议、不删任何东西。** 本轮**未执行任何 `rm` / 未跑构建 / 未碰设备**。
> `du -sh` 实测每个顶层目录（`du` 默认不跟随符号链接；`l2 -> /mnt/Samsung/l2` 外置盘已**跳过并注记**；`linux -> geekidos-linux` 按实体 `geekidos-linux` 计）。
> **与既有审计的关系（避免重复劳动）**：`reports/local-cleanup-audit-20261010.md` 已对 `out/`、`logs/`、`.pi/sessions/`、`/tmp` 做过逐文件深审，**且其顶部「父代执行状态」记已执行回收 ≈6.28 G**（A1+A2+A7+A9+A10 核心 + A3/A4/A5/A8 批量，out/ 9.4→3.6 G）。本清单**不重复** out/logs 的逐文件结论，直接**吸收并引用**该审计，只做它没做的「顶层目录 `du` 全量 + 处置建议」，并更新其执行后口径。

## 顶层占用一览（实测 `du -sh`，2026-10-10）

根盘合计（**不含外置 `l2` 45 G**）≈ **42 G**。大头 5 项：`geekidos-linux` 13 G、`mu_wide_platforms` 8.0 G、`build` 4.0 G、`out` 3.5 G、`env-pass` 3.4 G。

---

## A. 顶层目录处置清单（每条：路径 / 大小 / 判定依据 / 建议）

图例：🟥=可删（可再生/可重下/重复） ｜ 🟨=可选回收（有前置闸） ｜ 🟩=留 ｜ ⬛=不动（备份/安全网/私钥/台账）

| 路径 | du | 判定依据 | 建议 |
|---|---|---|---|
| `geekidos-linux/`（`linux` 指向此） | 13 G | 上游 GEEKiDoS/linux v7.2-elden + 构建产物；工作树已导出 `patches/elden-working-tree-*.patch` + `config-vk40-bringup`，`HEAD=ba28ec16f`（§2.5 P0-b 前置闸已解除） | 🟨 **留源码树**；`make clean` 可回收 ~11 G（**已授权但本轮按禁令未跑**，交父代执行）。**禁删**：现役内核树 |
| `mu_wide_platforms/` | 8.0 G | G1-29 Route A 设备包 clone（`lenovo-y700g4`，含原厂 DXE）；可重下（fork `xiaquwan1001/…`） | 🟨 **留至 G1-29 E4（ABL 是否接受 BootShim）定案**；定案后可 `迁 l2` 或删（可重下）。体量最大且非当前活跃 Q28 线，**迁外置性价比最高** |
| `build/` | 4.0 G | 2026-10-10 起内核构建工作区，体量集中在 `build/m1-upstream`（`build/glibc-arm64` 近空）；`.gitignore` 第 24 行 `/build/` 已在 | 🟥 **可再生构建目录**：`make clean`/整目录删后下次 `build-kernel.sh` 重建，无独有内容。清理首选之一 |
| `env-pass/` | 3.4 G | 过环境栈 + rootfs 归档；§2.5 P2-a 列「中间物 494 M 可删，保留 `env-pass/backup-20261002/linux17-rootfs.tar.gz`（过环境里程碑，不瘦）」 | 🟨 **留主体**；仅 `env-pass/{build,kernel-susfs}` 中间物按 P2-a 可选回收（须保留 linux17-rootfs 归档） |
| `backup/` | 2.6 G | 原厂分区/固件/GPT dump + AVF 资产（`§2.2` 多处钦定不可替代；`HA2EXB0E…/sn.img` 含本机 SN 禁入库） | ⬛ **备份类不动**（简报明确）。§2.5 P2-b（rawdump 压缩）/P2-d（stock-259 核对云包后删）为**有闸**旧案，非本轮 |
| `out/` | 3.5 G | **既有审计已深审并回收 ~6.28 G**；现 41 img + 内核 Image.gz + modular/modstage 载荷 | 见下 §B 专项（吸收审计结论 + 更新口径） |
| `edk2-aarch64-gunyah/` | 1.5 G | Gunyah VM/Windows-ARM64 guest 固件 clone（`AnyLaySys/…`）；仅 C8 观察、非活跃；可重下 | 🟥 **迁 l2/可删**（仅观察资源，可重下）；§1.5 已登记来源 |
| `uefi-firmware-backup/` | 1.3 G | `Project-Aloha/UEFIFirmwareBackup`，`lenovo-y700g4` 原厂 UEFI DXE 备份（`uefi.elf`/`BOOT.MXF…`）；= `mu_wide_platforms/Binaries/` 的来源 | ⬛ **备份类不动**（简报明确）。**注**：与 `mu_wide_platforms` 同名驱动 sha256 逐字节一致（§1.6），二者可去重一份 |
| `bootslot-b/` | 954 M | 自签 b 槽包，**含 `avb.key` 私钥**（禁入库） | ⬛ **不动**（回滚能力载体，丢私钥即失 b 槽自签能力） |
| `edk2-gunyah-qemu/` | 469 M | Gunyah QEMU guest 固件 clone（`qemu-gunyah/…`）；仅 C8 观察；可重下 | 🟥 **迁 l2/可删**（同 edk2-aarch64） |
| `stock-src/` | 402 M | 联想 GPL 源码 clone（§1.1 反查基线）；§2.5「不瘦」明列保留（402 M，可重下但常查） | 🟩 **留**（§不瘦；体量可控） |
| `pkgs-x86/` | 367 M | apk/deb 缓存（ubuntu-base/box64/Strings64）；§2.5 P1-b 可删，`rootfs/debs-manifest.txt` 已记版本 | 🟥 **可删**（P1-b，上游可重下） |
| `y700四代工具/` | 271 M | 厂商工具/解锁工具箱（含 §1.4 引用的实物模板 zip）；§2.5「不瘦」保留 | 🟩 **留**（§不瘦；含取证实物模板） |
| `pkgs-phosh/` | 267 M | apk/deb 缓存；§2.5 P1-b 可删（manifest 已记版本） | 🟥 **可删**（P1-b） |
| `restore-259/` | 254 M | AVB/KSU/EDL 救砖资产 | ⬛ **救砖安全网不动**（简报明确） |
| `rootfs/` | 193 M | 部署基（alpine/dl/debs，debs 已 ignore）；§2.5「不瘦」保留 193 M 部署基 | 🟩 **留**（§不瘦） |
| `probe/` | 180 M | 探针数据（bring-up 历史证据） | 🟨 **留或迁 l2**（历史证据，非必需常驻） |
| `.pi/` | 227 M | AI 记忆/技能/会话（`sessions/` 已 ignore，H1 归档候选） | 🟩 **留**（§不瘦；旧会话按 §3 H1 归档，非删） |
| `bootslot-b-u2/` | 112 M | U2 b 槽 mainline 链（testkey 全链，含回滚链验证） | ⬛ **不动**（同 b 槽载体） |
| `twrp/` | 101 M | TWRP 镜像（可重下） | 🟥 **可删**（可重下；若仍用作 adb recovery 则留） |
| `logs/` | 53 M | 串口/构建/agent 日志；**含 Q28 取证主证据**（见 §C） | 🟩 **留**（`q28-*` 取证目录保留；仅审计 A10 空/一次性小日志可选删） |
| `pkgs/` | 21 M | apk/deb 缓存；§2.5 P1-b | 🟥 **可删**（P1-b） |
| `.git/` | 19 M | 仓库本体（19 M） | ⬛ **不动** |
| `flashing-bundle/` | 15 M | 换机迁移包快照；§2.5 P2-c（tar.gz 已归档 `archive/2026-10-04-root-strays/`） | 🟥 **可删**（P2-c，重复快照，最新一套已归档） |
| `tools/` | 14 M | venv-avb + 上游 mkbootimg（可重建）；§不瘦保留 | 🟩 **留**（§不瘦；体量小、常用作构建输入） |
| `archive/` | 5.7 M | 过程证据归档，只增不改 | 🟩 **不动**（归档层纪律） |
| `initramfs/` | 2.1 M | init/脚本 + busybox（重建输入）；✅ track | 🟩 **留** |
| `edk2-gunyah/` | 1.8 M | Droid-VM/edk2-gunyah 小 clone（1.8 M） | 🟩 **留**（体量可忽略） |
| `qdl/` | 4.3 M | 上游 qdl（`build/qdl` 为构建物）；§不瘦 | 🟩 **留** |
| `reports/` | 132 K | 本轮/主题活跃工作区证据（见 resources-edits 节 E） | 🟩 **留**（主题收口后随迁 `archive/topics/`） |
| `net/` | 160 K | 小体积资产（✅ track） | 🟩 **留** |
| `waydroid-ota/` | 48 K | 小体积资产（✅ track） | 🟩 **留** |
| `versions/` | <50 K | vk 台账 TSV（git 入库，父代专属） | ⬛ **不动**（父代专属，简报禁令） |
| `l2 -> /mnt/Samsung/l2` | 45 G（外置） | 外置盘 super/system 镜像；**本轮 `du` 已跳过、未进入** | ⬛ **不动**（外置盘；§2.5 P3 有闸旧案，非本轮） |

---

## B. `out/` 专项（吸收 `local-cleanup-audit-20261010.md`，更新执行后口径）

> **不重复审计逐文件表**；仅给「父代执行后仍留盘项」的处置更新。审计可回收 ~6.0 G 已执行 ~6.28 G。

| 项 | du | 判定依据 | 建议 |
|---|---|---|---|
| `boot-elden-vk71-mxc.img` / `-mxnom.img` | 163 M | `versions/vk-identity-inflight.txt` Q24 变体，审计列「待设备验收」；**简报口径更新：用户裁决已判死可删** | 🟥 **可删**（据用户裁决；删后须**同步从 inflight 白名单删条目**，否则长期免检——见审计 C6 纪律） |
| `boot-elden-vk74-q28power.img` + `Image-vk74-q28power.gz` | ~102 M | in-flight；自述「收口=Q28 定案后删」。Q28 根因已定案但冷 A/B 未跑完（PITFALLS #164/#165） | 🟩 **留**（在途，随冷 A/B 收尾一并回收） |
| `boot-elden-vk84-q28delay-{base,exp}.img`（+ manifest） | 176 M | in-flight（白名单）；冷 A/B 进行中（T1=NOCARD 未定论），恢复点指定镜像 | 🟩 **留**（未定案前必留） |
| `boot-elden-vk64.img` + `Image-vk64.gz` | ~102 M | 设备 U2 **持久 boot_b 现役内核**（handoff：boot_b=vk64 未动） | 🟩 **留**（现役，勿删） |
| `boot-elden-vk77-modular/-modkdump/-vk78-modular.img` + `modstage-modular/` + `rootfs-overlaid-modular*.cpio.gz` | ~340 M | modular 载荷/loader 线（10-09，较新），疑似活跃线 | 🟨 **留待确认** loader 线是否收口（审计 C 项） |
| `boot_b-live-20261010.img` | 88 M | 设备 boot_b 分区备份=回滚安全网（standing rule #5）；审计执行后仅留此最新一份（旧 boot_b-live/before-cdsp/vk49 已批删） | ⬛ **不动**（回滚网；已是唯一份） |
| `boot-elden.img`（通用无名构建） | 0 | **简报/审计 B 表提到的 88 M `boot-elden.img` 实测已不存在**（清理时已无） | 🟨 **无需处置**（文件已 absent；`boot-elden-vk84` 为其 kbin 后继，manifest 已入库溯源） |
| 其余 vk42–vk63 基线/slim/`dtbo-dummy.img` | ~1.9 G | 历史基线（多为 vk47clean 同一内核二进制，见 §4.3「号与内核解耦」）；审计未列删（保留理由：可复现实验基线） | 🟨 **可选瘦身**：如需回收，按「有 manifest 可重建」原则成批处理，交父代逐项确认（非本轮建议强删） |

---

## C. `logs/` 专项（Q28 取证保留，简报明确）

| 项 | du | 判定依据 | 建议 |
|---|---|---|---|
| `logs/q28-BASELINE-good-vk75-dmesg.txt`、`q28-T1-nocard-vk84exp-dmesg.txt`、`q28-hunt-20261009-171759/`、`q28-BAD-*`、`q28-cycle-*`、`q28-forensics-*`、`q28-control-coldboot-*` | 数 M | Q28 GOOD/BAD 基线差分 + 冷/暖/cmd-DMA 差分**原始取证**（`q28-DOSSIER`/`q28-handoff`/PITFALLS #163/#164 引用） | 🟩 **保留**（简报明确「logs/q28-* 取证目录保留」，勿删） |
| `logs/serial-20261010-124836.log` | 9.1 M | Q28 取证主证据（即任务以为可删的「12:48 9.4MB」，审计 B 项纠正：是证据） | 🟩 **保留** |
| 空/一次性串口日志（审计 A10：`serial-run-20261009.log` 44B、`serial-20261003-192251.log` 0B、`serial-vk75fastboot-144450.log` 140K） | ~140K | 空/无引用 | 🟥 **可选删**（体量极小，审计已判可删；非必做） |

---

## D. 运行时 scratch（不在仓库内，交接提示，勿误删）

| 路径 | 大小 | 判定依据 | 建议 |
|---|---|---|---|
| `/tmp/q28_serial_logger.pid` 等 `q28_*` 标记 | <1K | **常驻 serial logger**（handoff：pid 在此） | ⬛ **先确认 logger 已停再删**，否则断取证链 |
| `/tmp/pi-subagents-uid-1000/` | ~116 M | runtime 拥有的运行期 scratch（本会话 subagent 产物在此） | 🟨 会话结束后由 runtime GC；**勿连带删本审计/整理产物** |

---

## E. §1 外部参考：过时 / 疑似死链条目登记（**标『待核』，不删、不改**，按简报「只登记」）

> 本轮**未联网核验**（简报要求「待核」，非「已核」）。下列为 §1 中最可能随时间失效的条目，交后续会话或父代择机 `curl --noproxy '*'` 核验后再决定去留。**社区 GitHub 参考仓（redroid-doc / waydroid_script / gunyah 系列 / mu_wide_platforms 上游等）默认可用、非死链候选**，不在本表。

| §1 位置 | 条目 | 现状标记 | 待核点 |
|---|---|---|---|
| §1.1 | 第三方解锁签名服务 `https://lenovobl.neko.ink/`（NekoYuzu 工具） | ⛔ 已判无效、不再使用 | 站点/服务是否已下线（死链）？取证 blob 已在 `backup/…/sn-neko-zuxos.img`，链接可留作溯源或标死 |
| §1.1 | 联想官方解锁入口 `https://www.zui.com/iunlock` | ⚪ 无需申请（1.5.x 过不了 ABL） | 入口是否仍在线/改版？项目实际走降级 1.1 路线，此链接重要性低 |
| §1.1 | ROM基地教程 `m.romjd.com/jiaocheng/content/29817`（2026-04） | 已消化进 §0.5 | 教程页是否仍可访问？内容已吸收，死链不影响项目 |
| §1.1 | ROM乐园 `romleyuan.com/lec/read?id=1427` | 交叉印证来源 | 同上，页存活待核 |
| §1.6 | `sunflower2333/mu_wide_platforms`（上游，2026-10-01 更新） | 已落盘本地 fork | 上游是否改名/删除影响「可重下」前提（影响 §A `mu_wide_platforms` 的删/迁决策）→ 删前先核可重下 |

---

## 处置汇总（一句话）

- **立即可回收（低风险）**：`build/` 4.0 G（可再生）+ edk2 clone（`edk2-aarch64-gunyah` 1.5 G + `edk2-gunyah-qemu` 469 M，可重下）+ pkgs 三件套（`pkgs-x86`/`pkgs-phosh`/`pkgs` ≈ 655 M，P1-b）+ `flashing-bundle/` 15 M（P2-c）+ `twrp/` 101 M + out 里 `vk71-mxc/mxnom` 163 M（用户判死，删后同步 inflight 白名单）≈ **约 6.9 G**。
- **迁外置腾根盘（更稳）**：`mu_wide_platforms` 8.0 G + `uefi-firmware-backup` 1.3 G（与前者去重一份）+ edk2 clone → 迁 `l2`，收口 G1-29 E4 前不删只迁。
- **有闸旧案（交父代按 §2.5 P 级）**：`geekidos-linux make clean`（~11 G，已授权，本轮禁令未跑）、`env-pass` 中间物（P2-a）、`backup` rawdump/stock-259（P2-b/d）。
- **绝不碰**：`backup/`、`restore-259/`、`uefi-firmware-backup/`（备份）、`bootslot-b*`（含私钥/回滚）、`out/boot-elden-vk64*`（现役 boot_b）、`out/boot_b-live-20261010.img`（回滚网）、`out/vk74/vk84*`（Q28 在途）、`logs/q28-*`（取证）、`versions/`（父代专属）。
- **本清单全程未执行任何删除。**
