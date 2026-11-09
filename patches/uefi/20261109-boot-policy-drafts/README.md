# 20261109-boot-policy-drafts — 「正式化」两份草案（**均未编译、未上机**）

对应 `TASKS/README.md` §5「2026-11-08（深夜）」块剩余项 ④：把路线 B 从「靠 ESP 上的实验文件抵消写死赋值」
变成正常启动路径。两份草案都只动 **loader 侧**，能与 FD 侧 R62（`p61`）并存；**不要同时上机**（判据会互相掩盖）。

| 文件 | 来源 | 做法 | 已知优劣 |
|---|---|---|---|
| `0001-r63-formalize-esp-first-default.patch` | 2026-11-09 静态分析（`README-r63-formalize.md`） | `BootIntoFastboot` 改为「ESP 上存在 `\fastboot.force` 才置 TRUE」；删除 `LEspForceBoot()`/`\espboot.force`；`menu.cfg` 多条目未写 `#timeout` 时默认 5 s；新增「选中项不存在则顺延下一个存在条目」；`LoadImageAndAuth` 的 ESP-first 加 `!BootIntoRecovery` 前置 | 顺延/超时语义完整；但后门走 **FAT 文件**，flashed 形态（`fs=1`）拿不到 FAT（`PITFALLS #571`）⇒ 那个形态没有后门 |
| `0001-linuxloader-formalise-boot-policy.patch` | 同日另一份草案（署名 R66） | 删除裸赋值；把后门改成 **UEFI 变量 `EldenFastboot`（BOOT+RT+NV）**；`\menu.cfg` 门控写进注释；回退链加 `[L] fallback fastboot st` 判据 | 后门在 flashed 形态也可用、不碰 FAT（`#562`）；但没有「条目顺延」与「默认 5 s」两块语义 |

**建议**：若要长期保留「开发态 fastboot」后门 ⇒ 采用 **R66 的变量型**后门；若要菜单语义完整 ⇒ 把 R63 的顺延/超时
合并进 R66。两者都未编译，合并后必须先跑「未上机可验证」那 5 条（见 `README-r63-formalize.md` §4）再上机。

## 顺序（重要）

1. `p61`/R62 先上机（`fs=1 → ≥2`）—— 否则本类改动在 flashed 形态**观察不到效果**；
2. loader 侧正式化单独出 `Loader-r66.efi`（或 r67），用 `scripts/esp-put-loader.sh` 只换 ESP 文件；
3. 判据（最小集）：`\loader.log` 出现 `bootfastboot 0 → pre-auth → post-auth → pre-bootlinux`、**不再出现 `force-boot`**；
   放 `\fastboot.force` 或设 `EldenFastboot=1` 时应回到 `to-fastboot`；`boot_b` sha 与 GPT 槽属性不变。
