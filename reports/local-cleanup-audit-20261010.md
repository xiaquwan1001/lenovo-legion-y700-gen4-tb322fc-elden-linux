# 本地条目清理审计 — y700-elden (2026-10-10)

> **父代执行状态（2026-10-10）**：已执行 **零风险核心删** A1+A2+A7+A9+A10 ≈ **470 MB**（死内核 vk81/82/83、重复 .bak、诊断 Image.gz、垃圾报告 q28-delay-build、空/一次性日志）；均 gitignore，`Image-vk64.gz`/`vk64.img`(boot_b 现役) 完好。**已执行（用户批准）**：A3/A4/A5/A8 批量实验镜像 + 旧 boot_b 备份（boot_b-live/before-cdsp/vk49）= **72 个文件 ≈5811MB**（out/ 9.4G→3.6G，逐项 gitignore+非现役守卫）。**本会话累计回收 ≈6.28GB**（核心 470MB + 批量 5811MB）。**仍保留**：vk84 base/exp(冷A/B未定案)、vk74(Q28定案后收)、vk71(待Q24验收)、modular 线、boot_b-live-20261010(回滚网)、/tmp(常驻logger未停)、subagent-artifacts(runtime GC)。scout agent 因自带 gate 报 failed 但产物完整（见记忆 tool-quirk）。

只读审计。审计本身**未执行任何 rm/修改**。仓库总计 42G（`du --exclude=.git`），其中 `out/` 9.7G、`logs/` 53M、
`.pi/sessions/` ~50M、`/tmp/pi-subagents-uid-1000` 116M。

**关键前提（降低删除风险）**：`.gitignore` 已将 `/out/*`、`/logs/`、`/.pi/sessions/`、`/patches/*.bak`、
`/backup/*`（fw/txt 除外）、`versions/*.lock` 全部忽略；`out/` 仅 `*.manifest` 入库（可复现指纹）。
→ **删除这些 .img / 日志 / 临时产物是纯本地清理，不动 git 历史，且镜像可由 manifest+patches 重建。**

**A 类可回收总计 ≈ 6.0 GB（≈6000 MB）**，其中 ~5.7 GB 为「已完成/被取代的一次性实验镜像」（可经入库
manifest 重建，建议成批删，父代确认后执行）；~300 MB 为无歧义核心安全删（死内核 + .bak + 垃圾报告 + 空/一次性日志）。

---

## A. 安全删清单（可回收 ≈ 6.0 GB）

| # | 路径 / 组 | 体积 | 内容（一句） | 理由 |
|---|---|---|---|---|
| A1 | `out/boot-elden-vk81-e0e4a.img`,`vk82-fix3.img`,`vk83-fix2.img` | **233M** | 死内核镜像 | PITFALLS **#162**：`olddefconfig` 删 `ARCH_QCOM`→无 QCOM 驱动，上机永不可能点屏；vk84 用的是 vk83 的 **git tag/commit**，非此死镜像；manifest 入库留痕，删镜像安全 |
| A2 | `out/boot-elden-vk42.img.bak`,`out/rootfs-overlaid-vk35.cpio.gz.bak` | **140M** | 冗余备份 | 同名/后继版本已在（`boot-elden-vk42.img` 88M 现存）；`*.bak` 已 gitignore |
| A3 | 一次性实验镜像组：`out/boot-elden-{sd-base,sd-hz120,sd-n2fix,sd-noGC,sd-noN2,sd-noN2N3,sd-noN3, dp1,dp1b,dp2,dp3,dp4,dp5,dp6,dp7, vkD1-nfconly,vkD1a-nfcpin,vkD1b-nfcdev,vkD2-cdsponly, vkX-dtb53,vkY-kern53, vkB1-bin,vkB2-bin,vkB3-bin,vkB4-bin, wifi-bmiss-1,wifi-bmiss-2,wifi-timing-1, inittest,inittest-veh, v1-thermal,v2-audio, vk34recon,vk34recon-ram, vk46,vk46-ram,vk47a-ram, camdp-nocam,camdp-nocam-h1,vk47clean-camdp, cdsp-clean-1,cdsp-split-1,cdsp-split-2,cdsp-vk47clean,cdsp-vk47clean-camrot,cdsp-vk47clean-camrot2}.img` | **~3.5G** | Oct 3–7 一次性 DTB/载荷/相机/NFC/WiFi 实验 boot 镜像 | 全部被 vk62+ 线取代、无现役引用；gitignore；`*.manifest` 入库可重建 |
| A4 | 收口实验镜像：`out/boot-elden-{vk65-m0,vk65-m1,vk65-m2,vk65-m3,vk65b,vk66,vk67,vk68,vk69,vk70}.img` | **968M** | kexec-diag/Q11 lane 变体 | in-flight 白名单注明 **2026-10-09 已收口**（registry 行补登、vk70 已打 tag、wildcard 已删）→ 实验完成 |
| A5 | 被取代 Q28 诊断镜像：`out/boot-elden-{vk72,vk72-q28dsi,vk72-q28dsi2,vk73-q28diag,vk75-q28ab,vk76-freezetrace}.img` | **489M** | Q28 取证早期迭代 | 诊断结论已固化进 PITFALLS #163/#164/#165；现役诊断走 vk74/vk84（见 C）；旧诊断镜像可删（结论在报告/dmesg，不在此 img） |
| A6 | `out/boot-elden-vk79-E0.img`,`boot-elden-vk80-e4amxc.img` | **178M** | 10-10 上午 E0/e4a 变体 | 同方向已被 vk81(死)/vk84 取代；registry 标 dirty、无现役引用 |
| A7 | 诊断内核 Image：`out/Image-{vk47clean,vk73-q28diag,vk78-extracted,vk64-q28,vk64-q28-v2}.gz` | **~98M** | 一次性取证内核 | 对应镜像多已在 A3/A5；**保留 `Image-vk64.gz`（持久 boot_b 内核）**；`Image-vk74-q28power.gz` 见 C |
| A8 | 旧一次性 rootfs/initramfs：`out/{rootfs-vk7,rootfs-vk11,rootfs-thermal-vk36,rootfs-vk48,rootfs-overlaid,rootfs-overlaid-camera,initramfs-full-elden}.cpio.gz` | **447M** | Oct 2–7 载荷快照 | 由 `scripts/`+`patches/` 可重建；modular 载荷（10-09）另在 C |
| A9 | `reports/q28-delay-build-20261010.md` | ~4K | 垃圾报告 | 全文仅 1 句残留 agent 思考（"Before touching shared build state…"），无正文 |
| A10 | `logs/serial-run-20261009.log`(44B,空),`logs/serial-20261003-192251.log`(0B),`logs/serial-vk75fastboot-144450.log`(140K) | ~140K | 空/一次性串口抓取 | 无体积价值、无报告引用；A 类中体量最小 |

> A3/A4/A5/A8 合计 ~5.7G 属「成批可重建实验产物」——技术安全（gitignore + manifest 可重建），
> 但体量大，建议父代整批确认后再删；A1/A2/A7/A9/A10 (~470M) 为无歧义核心安全删。

---

## B. 建议留清单（不删）

| 路径 | 体积 | 保留理由 |
|---|---|---|
| `out/boot-elden-vk64.img` + `out/Image-vk64.gz` | ~102M | 设备 U2 **持久 boot_b 现役内核**（handoff：boot_b=vk64 未动） |
| `out/boot-elden.img` (10-10 13:03) | 88M | 当前最新通用构建输出（unversioned，kbin=vk84） |
| `logs/serial-20261010-124836.log` | **9.1M** | **Q28 取证主证据**：handoff §13 明确引用，PITFALLS **#163/#164** 冷/暖+cmd-DMA 差分的原始串口日志（即任务所说「12:48 的 9.4MB」——**是证据，勿删**） |
| `logs/q28-BASELINE-good-vk75-dmesg.txt`,`logs/q28-hunt-20261009-171759/`(2.9M,含 trace/dmesg before-after) | ~3M | Q28 GOOD/BAD 基线差分证据 |
| `patches/config-before-fragment-20261009-210432.bak` | 316K | **#162 钦定「恢复好档」**（sha `a80cbabb`，`ARCH_QCOM=y` 实测在）——虽是 `.bak` 但必须留 |
| `reports/q28-{handoff,upstream-diff,two-layers}-20261010.md` | ~26K | 权威：handoff=断点续接、upstream-diff=上游裁决终版（推翻 §cherry-pick）、two-layers=根因（L1/L2） |
| `versions/*.tsv`（identity/registry/ledger/triage，非 .lock） | ~40K | vk 台账本体，git 入库 |

---

## C. 需父代 / 用户确认清单（有在途或安全语义，勿自行删）

| 路径 | 体积 | 待确认点 |
|---|---|---|
| `out/boot-elden-vk84-q28delay-{base,exp}.img` | 176M | in-flight 白名单；**冷 A/B 进行中**（T1=NOCARD 未定论），恢复点指定镜像。验收/定案前必留 |
| `out/boot-elden-vk74-q28power.img` + `out/Image-vk74-q28power.gz` | ~102M | in-flight；自述「收口 = Q28 定案后删」。根因已定案但冷 A/B 未跑完 → 建议随 A/B 收尾一并回收 |
| `out/boot-elden-vk71-mxc.img`,`vk71-mxnom.img` | 163M | in-flight（Q24 cambist 变体），待设备侧 ≥9 轮验收；验收后二选一（补 vk71 内核 or 删）|
| `out/boot-elden-vk77-modular.img`,`vk77-modkdump.img`,`vk78-modular.img` + `out/modstage-modular/`(88M) + `out/rootfs-overlaid-modular{,-hook}.cpio.gz`(126M) + `out/.modular-ovl/` | ~340M | modular rootfs/loader 工作（10-09，较新），疑似活跃线；确认 loader 线是否收口 |
| `out/boot_b-live.img`,`boot_b-live-20261010.img`,`boot_b-before-cdsp-20261007.img`,`boot_b-vk49.img` | 384M | **设备 boot_b 分区备份 = 回滚安全网**（standing rule #5 不破坏可用系统）。建议保留最新 `boot_b-live-20261010.img`，其余旧的经确认可回收 |
| `reports/q28-{orchestration,upstream-research}-20261010.md` | ~24K | 与 handoff/two-layers/upstream-diff **内容重叠**（orchestration §Lane C≈research；§3≈#162；two-layers≈#164）。据 DOSSER 收敛：留 handoff+upstream-diff+一份根因，其余归档 |
| `.pi/workflows/2026-10-10-{q28-orchestrate,q28-tidy,q28-upstream-fix}.js` | ~21K | 本会话新建编排脚本；lane 已完成 → 可归档/删（父代定，属可复用资产） |
| `.pi/sessions/subagent-artifacts/`（22 组 *_transcript.jsonl + outputs/）| 21M | 会话级 lane 产物、gitignore；runtime 通常自动 GC。**本审计自身的 SUMMARY 也在其中，勿连带删** |
| `/tmp/q28_{serial_logger.pid,seriallog_path,trial_offset,out_dir,bootmarker,logger.out}` | <1K | **常驻 serial logger 标记**（handoff：logger 常驻，pid 在此）。须**先确认 logger 已停**再删，否则断链取证 |
| `/tmp/pi-subagents-uid-1000/`（`async-subagent-runs` 115M 为大头）| 116M | runtime 拥有的运行期 scratch；可能有活跃会话占用。会话结束后可清，交父代/runtime |
| `backup/libvulkan_freedreno.so.orig`(14M),`libgallium-26.1.6.so.orig`(35M) | 49M | GPU 驱动原始 so 备份（Jul 31）；可能是图形 bring-up 取证基线 → 确认可否回收 |
| `patches/config-before-fragment-2026100{1-4}*.bak`,`config-before-vk53*.bak`,`config-vk32-camera-base.bak`,`…-210440.bak` | 2.6M | 陈旧 config 备份（gitignore）；除 B 表 210432 好档外皆过期，可删但体量小，随父代一并处理 |

---

## 逐项对应任务清单

1. **logs/serial-*.log**：共 11 个（总 21M）。**留**：`serial-20261010-124836.log`(9.1M，#163/#164 取证主证据，被 handoff 引用)。可归档：其余历史抓取（09-29/10-03/10-06）。可删：A10（空 44B、0B、vk75fastboot 一次性）。**注意：任务提示的「12:48 的 9.4MB」正是被引用的取证日志 → 标留，非可删。**
2. **out/*.img**：110 个 img + 7 个 Image.gz。死内核 vk81/82/83=233M（A1）；一次性实验（A3/A4/A5/A6，~5.1G）；**现役/待验保留 vk64(持久 boot_b)/vk84-base+exp/vk74（B/C）**。
3. **/tmp/q28_* 与 /tmp/pi-subagents***：q28_* 全为会话标记（offset/serial/pid，<1K）——**须先停常驻 logger 再删（C）**；pi-subagents 116M 为 runtime scratch，会话结束可清（C）。
4. **.pi/workflows/\*-2026-10-10\*.js**：3 个（orchestrate/tidy/upstream-fix，21K），lane 完成 → 可归档（C，父代定）。
5. **reports/q28-\***：6 个重叠文档。核心 3（handoff/upstream-diff/two-layers，B）；orchestration+research 内容被 PITFALLS #162/#164 与 upstream-diff 吸收 → 建议归档（C）；delay-build 为垃圾（A9 删）。
6. **versions/ in-flight vk84 条目**：vk84-q28delay base/exp 登记在 `versions/vk-identity-inflight.txt`，冷 A/B 未完成 → **暂不可回收**；vk74/vk71 待 Q28 收尾与 Q24 设备验收后回收（C）。白名单纪律：收口后必须从该文件删条目，否则长期免检。
7. **其他冗余**：`out/*.bak`(140M,A2)、`patches/*.bak` 陈旧(2.6M,C)、`backup/*.orig`(49M,C)、`.pi/sessions/subagent-artifacts` 旧 lane 产物(21M,C)。仓库内 `*.rej/临时 diff` 未发现（geekidos-linux/edk2 大源码树已排除）。

---

## 返回摘要（给父代）
- **A 类可回收总计 ≈ 6.0 GB（~6000 MB）**：其中 ~5.7G 成批可重建实验镜像（A3–A5/A8），~470M 无歧义核心（死内核 A1 + .bak A2 + 诊断 Image.gz A7 + 垃圾报告 A9 + 空日志 A10）。
- **B 关键项**：① `serial-20261010-124836.log`(9.1M) 是 Q28 取证主证据（#163/#164），**勿删**——正是任务以为可删的「12:48 9.4MB」；② vk64.img+Image-vk64.gz = 设备持久 boot_b；③ `config-before-fragment-20261009-210432.bak`(#162 好档 sha a80cbabb) 虽是 .bak 必须留。
- **C 关键项**：① vk84-base/exp 冷 A/B 未完成，暂不可回收；② boot_b-live*.img 是设备回滚安全网，只留最新；③ `/tmp/q28_serial_logger.pid` 对应**常驻 logger**，删前须确认已停；④ reports 6 份需据 DOSSER 收敛为 handoff+upstream-diff+一份根因；⑤ `.pi/sessions/subagent-artifacts` 含本审计 SUMMARY，GC 时勿连带删。
