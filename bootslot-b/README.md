# 用 b 槽直接引导 mainline Linux —— 资源与测试方案（2026-09-29）

> 目标：摆脱 `fastboot boot`（RAM-only、每次都要主机），让设备**自己**从 b 槽启动 mainline。
> b 槽本来就是坏的（另一套固件/另一把密钥 `8fcb864f…`），拿来做 Linux 槽最合适。
> **所有被覆盖的原厂分区已备份**：`backup/stock-259/boot_b.img`、`vbmeta_b.img`、`dtbo_b.img`。

---

## 一、难点：b 槽的 AVB 链

`vbmeta_b`（原厂）的 chain descriptor 要求 `boot` 用 **`8fcb864f…`** 签名，我们用不上那把私钥。
`fastboot boot` 能绕过（RAM 引导、不走 AVB），但**正常开机走槽就一定会被 ABL 校验**。

`PITFALLS §61` 记录的两个事实：
- a 槽顶层 `vbmeta` 是 `2597c218…`，且 a 槽能正常启动 → **ABL 接受该 key**；
- b 槽失败时报的是 **chain 级 key mismatch**（说明顶层 `vbmeta_b` 本身被接受了）。

→ 结论：**顶层能过，卡在 `boot` 链**。只要让 ABL 不去校验（或校验我们的 key），b 槽就能引导自编内核。

## 二、已备好的资产（`bootslot-b/`，全部本地生成、自洽）

| 文件 | 内容 |
|---|---|
| `avb.key` / `avb.avbpubkey` | 自签 RSA-4096 密钥（**现役**公钥 sha1 `1e54e86e…`；2026-10-18 换过钥，旧钥 `fc1e3b33…`） |
| `boot_b.img` | **历史 dump**（2026-09-29 时 = `out/boot-elden-vk12.img` + `add_hash_footer`）；**已被后续 dump 覆盖** ⇒ 切勿按名字当作“当前槽内容”，实际身份见下方《现状》表 |
| ~~`dtbo_b.img`~~ | **已不在仓**（空 dtbo 按 G1-29 配方直接写全 0 的 32 MiB 区，不需要此件） |
| `vbmeta_b_flags3.img` | 自签 vbmeta，**flags=3（verification + hashtree 全关）** ← 首选。**现为生成件**：`scripts/build-vbmeta-b.sh` → `out/vbmeta-b/vbmeta_b-flags3.img`（仓里那份已不在，且是换钥前的 `fc1e3b33…`，**不要再用**） |
| ~~`vbmeta_b_flags0.img`~~ | 本轮不造：干净链需要**现役 `dtbo_b` 内容 dump** 才能写 dtbo hash 描述符（`reports/vbmeta-b-resign-20261121.md` §3） |

> **2026-11-21 口径（本表为准）**：`vbmeta_b` 与 `boot_b` 必须共用**同一把** `avb.key`。
> 2026-10-18 换钥后 `vbmeta_b` 没重签 ⇒ 10-18→11-21 这段「自签链不自洽」（顶层 key 与 `chain boot:3`
> 都指旧钥 `fc1e3b33…`，而 `boot_b` footer 是新钥）。判据 = `scripts/build-vbmeta-b.sh --check` 全绿
> （= `check-doctor` **§26**），件账 = `out/vbmeta-b/MANIFEST.md`，成因/证据 = `reports/vbmeta-b-resign-20261121.md`。

三个文件的 digest 已互相校验一致（`avbtool verify/info` 通过）。
`avb.key` 只在本机、只用于这台设备的 b 槽（丢了也能重新生成一套）。

### 现状（2026-10-06 账目审查修正；本节为权威，上方历史表仅存沿革）

| 文件 | 镜像 sha256（前 12） | 镜像内 UTS 实测 | 说明 |
|---|---|---|---|
| `boot_b.img` | `db2d6afbb049` | `7.2.0-debug-g4c68eb5ed4e3-dirty` | **vk46 时代 dump**（与 `out/boot-elden-vk46.img` 同源）；非当前 b 槽 |
| `boot_b-clean.img` = `out/boot_b-live.img` | `e0e453dbb8d6` | `7.2.0-debug-vk47clean-gbd114ca335e1` | **当前 b 槽在机内核（vk47clean）** |
| `boot_b_vk40{,-ram,-persist-diag}.img` | — | `7.2.0-debug-gba28ec16f01f-dirty` | vk40 系列（UTS 与 vk7–vk41 同串，设备自证不了版本） |
| **目标形态** | 见 `out/boot-elden-vk61.img`（`78422c95e3a9`） | `7.2.0-debug-vk47clean-gbd114ca335e1` | vk61 = 原完整 ramdisk 仅换修好的 `/init`，零写盘验收通过、**待刷**（`INDEX` §U2、`TASKS` G1-30） |

> 判定依据：直接对镜像解 gzip 抽 `Linux version`（与 `scripts/build-manifest.sh` 同法）。
> 版本账与已知混淆项：`archive/topics/VK-LEDGER-AUDIT-2026-10-06.md`、`versions/vk-registry.tsv`。

## 三、测试序列（逐条执行，先确认槽位；按 `.pi/AGENT-OPS.md` agent 可先备份后自主执行）

### T1（首选，flags=3）
```bash
cd ~/y700-elden
scripts/build-vbmeta-b.sh                     # 造件（换钥后必须重跑；--check 只验）
fastboot --set-active=a                       # 先确认在 a（PITFALLS §60）
fastboot flash boot_b   bootslot-b/boot_b.img
fastboot flash vbmeta_b out/vbmeta-b/vbmeta_b-flags3.img
fastboot --set-active=b
fastboot reboot
```
**期望**：设备自己起来进 Linux（能 SSH：`ssh root@192.168.7.1`，`findmnt /` = `/dev/sda17`）。
**失败表现**：回到 fastboot（不是砖）。

### T2（T1 失败再试，flags=0 干净链）
> 前置：先有现役 `dtbo_b` 的 dump 才能造 dtbo hash 描述符（`reports/vbmeta-b-resign-20261121.md` §3），
> 目前**没有 flags=0 件**。
```bash
fastboot --set-active=a
fastboot flash vbmeta_b <flags=0 件（尚无）>
fastboot --set-active=b
fastboot reboot
```

### T3（T1/T2 都失败）
→ 说明 ABL 对**顶层 vbmeta 的 key 也强制校验**，只有刷社区改过的 `abl_a`（`restore-259/重签包/abl_a.img`，唯一砖点）
才可能行。到这一步再和用户确认是否值得（EDL 救砖链路已就位）。

### 回退（任何一步都行）
```bash
cd ~/y700-elden/backup/stock-259
fastboot --set-active=a
fastboot flash vbmeta_b  vbmeta_b.img
fastboot flash boot_b    boot_b.img
fastboot flash dtbo_b    dtbo_b.img
fastboot reboot
```

## 四、若成功：收益 / 后续

- 按键开机 → 直接进 Linux（不再需要主机 + `fastboot boot`）。
- 双系统：`fastboot --set-active=a` 回 Android，`--set-active=b` 回 Linux（都用物理键）。
- 待办：ABL 的“启动失败自动切槽”可能干扰（Linux 启动慢/被认为失败）→ 需要观察
  `getvar current-slot` 与 `misc`/`bootloader_message`。
- 风险：b 槽原厂内容被覆盖（已备份 ✅）；b 槽从此不再是 Android 备用槽。
