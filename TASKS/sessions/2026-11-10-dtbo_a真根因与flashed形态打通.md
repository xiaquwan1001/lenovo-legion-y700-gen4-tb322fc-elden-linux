# 2026-11-10（深夜）— flashed 形态打通：真根因 = `dtbo_a`（Android DTBO overlay），`vbmeta_a` 假设被否证

- **日期**：2026-11-10（同日第四段；前三段见 `2026-11-10-发送清理与p67上机p68备料.md`、`2026-11-10-UEFI落盘信标收口p63-p66.md`、`2026-11-10-flashed形态重判与vbmeta.md`）
- **pi 会话 id**：本段会话（关键词「继续 / vbmeta_a flags3 / dtbo_a 卡 logo / bootmark 判据」）
- **主题**：验证上一段提出的「`vbmeta_a` 校验失败 ⇒ ABL 不交棒」假设，结果一路走到**真根因 = `dtbo_a`**，
  并首次在 **flashed 形态**（写 `boot_a`、`active=a`）跑通「我们的 UEFI → BdsDxe → ESP 内核」
- **结论**：
  1. **`vbmeta_a` 不是墙**：造 Flags=3/我方 key 的 `vbmeta_a` 刷入后仍失败；反过来把 `vbmeta_a` 恢复**原厂 Flags 0**
     （哈希必然与我们的件不匹配）却**照样起 Linux**（27–29 s）⇒ 解锁态（orange）下 ABL 不因哈希失败拒绝交棒。
  2. **真根因 = `dtbo_a`**：原厂 `dtbo_a` 是合法 Android DTBO（magic `D7B7AB1E`、`total_size` 23 348 092 B），
     ABL 在 `BootLinux` 后 `Apply Overlay`（`Load Image dtbo_a` → `Apply Overlay … 175 ms`）把它合进**我们的** Linux DTB
     ⇒ 卡联想 logo、USB 不枚举、无 pstore、~10 s 后 ABL 放弃回落。`dtbo_b` 早在 2026-10-03 已写成全 0
     ⇒ **「`_b` 一直好、`_a` 一直坏」**。清 `dtbo_a` 后：同件 `fastboot boot`（active=a）**34 s** 起、flashed **27 s** 起。
  3. **这是项目第一天的坑**（`PITFALLS/sessions/01`「假 dtbo 必须两个槽都写」、`sessions/02` 第 10 条「ABL 会拿 stock dtbo overlay 我们的内嵌 DTB」），
     历史上只处理了 `_b`；11-09/10 的 p60–p69 **全部打在 `_a`** ⇒ 每发注定卡 logo，与补丁/payload/vbmeta 全无关。
  4. **flashed 形态闭环**：`boot_a`=p69 UEFI（`38202e12…`）+ `dtbo_a` 全 0 + `active=a` ⇒ **129.2 s** 起 Linux
     （= 基线 54.5 s + R70 **+74.3 s** 三级停留，证明停留真的执行）、logfs 信标 `R68LOG n=3 … s9:esp-ld-ok` 全绿、
     cmdline `elden_bootloader=esp`、内核 `vk184-00002-g4da9a8b69fc8`（ESP 里那份 `boot.img`）。
  5. **两条判据纪律被推翻**：① `logfs` 对最近的启动**根本不写**（16:14 失败发与 16:20 成功 `_b` 启动前后 sha 完全相同）⇒
     `#594/#597` 的「信标未变 ⇒ 没跑到」不成立；② `androidboot.slot_suffix` **不能**当槽位判据（我们的 `boot.img` 头里烤死 `_b`，
     ABL 对 Linux 件不追加）——一度据此误判「flashed 落到 `_b`」，改用镜像头埋 `elden_bootmark=a` 才判清。
- **证据指针**：
  - 正文 `reports/uefi-dtbo-a-rootcause-20261110.md`（7 发判据表 + 机理 + 配方 + 回滚）
  - 试验目录 `reports/artifacts/uefi-dtbo-a-blank-20261110/`（C→D）、`uefi-flashed-20261110-174041-bootmark-a-discriminator/`（E）、
    `uefi-flashed-20261110-174233-ctrl-vbmeta-a-orig-flags0/`（F）、`uefi-flashed-20261110-174442-p69-flashed-dtbo-blank/`（G）、
    `uefi-slot-a-stock-android-20261110/`（B）、`uefi-slot-a-ramboot-context-20261110/`（C 的卡 logo 那发）、
    `uefi-fastbootboot-control-20261110/`（active=b 的 RAM 对照）
  - 件 `out/bootmark-a-test.img`（`96f4d9c4…`，= `boot_b` 件原地替换 `elden_nocamera=1`→`elden_bootmark=a`）、
    `out/vbmeta-a-flags3/vbmeta_a-flags3-copy-b-20261110.img`（`e974ebab…`，被 F 否证其必要性）
  - 备份 `backup/dtbo_a.img`（`45f51790…`，写前逐字节核对过 = 在机件）、`backup/vbmeta_a-orig-20261110.img`（`55929c15…`）、
    `backup/boot_a-pre-uefi-20261108.img`（`d4772c11…`，原厂 Android 件）
  - 工具改动 `scripts/uefi-flashed-trial.sh`：新增 `--part`（可刷任意 a 槽分区：`boot_a`/`vbmeta_a`/`dtbo_a`），
    `snap` 增抓 `vbmeta_a/vbmeta_b` sha；回滚提示按 `--part` 分支
  - 坑 `PITFALLS #600/#601/#602`（另：本轮我自己 `fastboot … | head -1` 触了 `#584`，通道短暂假死过一次，纪律照旧）
- **★SSOT 待并入**：已并入 `TASKS/README.md` §0 G1-29 行 + §5「2026-11-10（深夜，`dtbo_a` 真根因）」块、
  `PITFALLS/README.md` #600–#602
- **设备态**：U2；`active=a`；`boot_a`=p69 UEFI（`f4024ba2…`）、`dtbo_a`=全 0（`83ee4724…`）、`vbmeta_a`=原厂 Flags 0（`55929c15…`）；
  在机 `7.3.1-debug-vk184-00002-g4da9a8b69fc8` + `elden_bootloader=esp`；`boot_b` 未动（`4e38bc2c…`，`set_active b` 即回日常）
- **剩余（需人/需批）**：
  - 屏上 BDS/GRUB 菜单交互取证（要人盯屏）与 `boot_a` 冷启动（POR）回归
  - 决定 a 槽常态：保留「UEFI + dtbo 全 0」（Android 不能从 a 起）还是回滚成 Android 件（回滚命令见报告 §4）
  - 把「a 槽 dtbo 清零」写进设备分派脚本，避免下次再踩
