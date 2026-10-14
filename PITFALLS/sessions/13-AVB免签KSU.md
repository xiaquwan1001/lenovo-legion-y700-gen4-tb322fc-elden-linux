## 十三、AVB / 免签 / KSU（2026-09-29 实测）

60. **`fastboot boot` 失败会让 `current-slot` 翻到 b**（本轮实测两次：`Booting FAILED (Status read failed
    (No such device))` 之后 `getvar current-slot` 就变成 `b`）。而 **b 槽的引导链是另一套固件/另一把密钥
    （`vbmeta_b` 用 `8fcb864f…`，a 槽是 `2597c218…`），b 槽永远起不来**。
    → **每次进 fastboot 后、任何操作前，先 `fastboot --set-active=a`**；
    `fastboot boot` 报 `Status read failed` 时，接 `fastboot reboot bootloader`，等 6~8 秒再单条重试。
    ⚠ **已作废（#114）**：上方「先 `fastboot --set-active=a`」是**错误规则，AGENTS 已删除**，现口径 = **不要改 active slot**（保护在用的 b 槽）。槽位读状态/mark-successful 改用 `qbootctl`（#126/#133）。本动作勿再照做。

61. **本机两个槽的 AVB 密钥不同**：a 槽 `vbmeta`/`boot`/`recovery` 用 `2597c218aae470a130f61162feaae70afd97f011`，
    b 槽 `vbmeta`/`vbmeta_system` 用 `8fcb864f11f53ed11284615fb67685522085d3a2`。
    社区"免签/KSU"包用的都是 `2597c218`（= a 槽本来就信任的 key）。
    而且 **a 槽原本就有一处 chain key 不一致**（`vbmeta_a` 说 recovery 是 `8fcb864f`，实际 `recovery_a` 是
    `2597c218`）却能正常启动 → 说明该机对 **hash descriptor 摘要不匹配**（init_boot/dtbo）和**部分 chain key 不一致**
    是宽容的，只有 `boot` 链的 key 不匹配才会致命（b 槽就这样）。
    用 `tools/avbtool.py`（LineageOS 版 `avbtool.py`）可离线核对：`info_image --image X`。

62. **本机 `init_boot_a` 早已是 KSU 补丁版**（`strings` 里有 `/data/adb/ksud`、`description=Android KernelSU`、
    `kernelsu.ko`、`KSU_FEATURE`），`init_boot_b` 是 **Magisk** 版。旧补丁与任何 vbmeta 都不配套。
    社区包 `restore-259/KSU/init_boot.img` + `KSU/vbmeta.img` 是**自洽的一对**
    （校验：`sha256(salt ‖ init_boot[:2850816])` = vbmeta 里 init_boot 描述符的 Digest）。
    注意 stock `vbmeta_a` 的 init_boot descriptor 是 **2465792** 字节（新补丁是 2850816），尺寸也会变。

63. **本机已 unlocked，AVB 本来就是宽松态**：ABL 传的 cmdline 含
    `androidboot.verifiedbootstate=orange`、`androidboot.veritymode=disabled`、
    `androidboot.vbmeta.device_state=unlocked`。社区"免签"的核心价值是**在锁定 BL 的机器上 root**；
    本机不需要刷改过的 `abl_a`（它同时是唯一砖点），只刷 a 槽的 `init_boot`/`vbmeta*`/`recovery` 即可。
    详见 `restore-259/AVB-KSU-2026-09-29.md`。

---

