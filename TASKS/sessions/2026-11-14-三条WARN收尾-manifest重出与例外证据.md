# 会话：三条 WARN 收尾（vk183 manifest 重出 / 例外逐行证据 / UEFI 载荷放过）

- **日期**：2026-11-14（夜，与文档收敛同会话的收尾段）
- **pi 会话 id**：本会话（见 `.pi/sessions/2026-11-14T*.jsonl`）
- **主题**：按用户口径「能重出的重出 / 已知例外尽可能给深入描述证据 / 历史无配方的放过」处理 `check-doctor` 剩余 3 条 WARN。
- **结论**：
  1. **「registry 号无 manifest（vk183-fastrpc）」→ 已重出**：新增 `scripts/manifest-from-image.py`（只写镜像内客观字段：
     `mkbootimg.py read_image` 分出的 kernel/ramdisk/dtb/cmdline + 解 gzip 得内核 UTS 与解压后 sha256；树侧字段写 `(absent:…)`，
     头两行标 `reconstructed_from=image`）。重建件 `out/boot-elden-vk183-fastrpc.manifest` 的
     `kernel_payload_sha256=5543b181e162…` 与 `versions/vk-kernel-identity.tsv` 第 70 行**逐字一致**（独立交叉验证）。
     源树 `build/vk151` 已删 ⇒ `config_sha256` 不可得，已登记 `versions/manifest-incomplete-allowlist.txt`。
     身份表按「先写 `/tmp` + 全表 diff 确认仅 vk183 一行变化」的安全流程更新（**未盲跑生成器**）。
  2. **「账本已登记的例外」→ 逐行证据**：`versions/vk-ledger-known-issues.tsv` 加第 4 列，299 行填满
     （132 行 = 身份表同源 `uts/payload/src/refs/flags`；146 行 = manifest 留档；21 行 = 无镜像无 manifest，明标不可再生）；
     表头补每种 kind 的判据与复核命令。解析侧只读前 3 列，不改语义。
  3. **「4 件 posctrl-markspin 内核段不可读」→ 放过**：它们是 **UEFI 正控载荷**（不是 Linux 内核），且已归档在
     `backup/out-history-20261105/`。不重出、不登记为内核例外（会污染「内核身份」语义），保留 WARN 原文。
  4. **门结果**：`check-doctor` **WARN 4 → 2**（FAIL 恒 0）；`--staged-fast` FAIL=0 / WARN=1。
- **证据指针**：
  - 执行账 `reports/docs-slim-20261114.md` §8（三条 WARN 的逐条处置 + 数字 + 交叉验证值 + 保留理由）。
  - `python3 scripts/vk-identity.py --gate` rc=0；`--check` rc=0；`bash scripts/check-doctor.sh` → FAIL=0 / WARN=2。
  - 重建件的可用性：`scripts/manifest-from-image.py <img> --dry-run` 可复算同一份字段。
- **★SSOT 待并入**：
  - 剩余 2 条 WARN 属**已登记豁免/用户裁定放过**（见上 §2/§3），不是待办；若要清零只能删 `backup/` 不可再生件（需用户点头）。
  - `scripts/static-scan.py --inventory` 生成的 `versions/scripts-inventory.tsv` 未重生（新脚本 `manifest-from-image.py`
    会在下一次整理轮进表），非阻塞。
  - 其它历史镜像若日后要找身份，先用 `manifest-from-image.py` 重建 manifest（脚本头已写明「源树已删时不要硬跑 build-manifest.sh」）。
