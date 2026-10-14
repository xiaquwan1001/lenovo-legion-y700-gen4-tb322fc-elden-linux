## 八、恢复 Android / 免解 BL root 资产（2026-09-29）

39. **1.5.10.259 免解 root 原理**：高版本固件改了分区签名；老法（改分区 + 旧签名）会**卡机**。
    社区重签包 = **改过的 `abl`（信任自签密钥）+ 自签 `vbmeta`/`vbmeta_system`**，让系统以为仍是原厂签名。
    → **abl 与 vbmeta 必须配套一起刷**，不能只刷一半。资产见 `restore-259/`。
    build 核对：三个 vbmeta 的 fingerprint 均 = `ZUXOS_1.5.10.259_260611_PRC`；分区描述符不带槽后缀。
    重签包里 `boot_a.img` 与官方 `boot.img` **sha256 相同**（没改 boot），真正改的是 `abl_a.img`。

40. **回 Android 两步走**：① 先 `fastboot --set-active=<另一槽>`（非破坏，见第 1 条）；
    ② 不行才按 `restore-259/README.md` 刷重签包（abl 有砖风险，需 qdl+`xbl_s_devprg_ns.melf` 兜底）。

41. **EDL 救砖链**：`fastboot oem edl` 或 `adb reboot edl` → `~/y700-elden/qdl/build/qdl -s ufs restore-259/xbl_s_devprg_ns.melf read/write <分区> <文件>`。
    原厂固件目录 `~/下载/tb322fc/`（**不含 dtbo/vendor_boot/recovery/super**，不能全量恢复，只能逐分区）。

### 八之二、Android 应用数据备份 / 解密（2026-09-29）

用 **adb 从运行中的 Android** 导出 `Android/data/<pkg>` 即得**明文**（FBE 已透明解密）；
**不要**用 raw 分区 dump（那是 FBE 密文）。

- 本机 Android 16 的 `adb shell` 属于 `ext_data_rw` 组，**无需 root 就能读** `Android/data`：
  `adb exec-out 'tar -C /sdcard/Android/data -cf - <pkg> 2>/tmp/err' > pkg.tar`
  （只有 `-rw-------` 的 `tombstone_*` 崩溃转储读不到）。
- **Hollow Knight**（`com.TeamCherry.HollowKnight`）：存档 = `<25B 头>+base64(AES-256-ECB(json))+0x0b`，
  密钥公开 `UKu52ePUBwetZ9wNX88o54dnfKRu0T1l`。工具 `scripts/hk-save-decrypt.py`，已验证**逐字节可逆**。
- **Limbus Company**（`com.ProjectMoon.LimbusCompany`）：本地 `save_slot_*.json` = BOM+base64(AES 密文)，
  密钥未公开、无社区解密器；但**存档在服务器**，本地只是缓存，备份价值在 17 GB 素材。
- 备份产物在 `~/android-backup/`（含 README / sha256 / decrypted）。

---

