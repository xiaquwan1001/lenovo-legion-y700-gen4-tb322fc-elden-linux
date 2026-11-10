# 2026-11-10（第八段）— Waydroid 网络定案 + droidloom 可行性复评（两件小事）+ IME/GRUB 双 lane 派工

- **日期**：2026-11-10（同日第八段）
- **pi 会话 id**：本段会话（关键词「Waydroid 网络情况依然不明晰 / 评估 droidloom 可行性 / 派 agent 查 GRUB 直接引导掉电」）
- **主题**：① 把 Waydroid「网络不明晰」定案；② droidloom 可行性从「四道未知」压到「两件已知小事」（含设备实测）；
  ③ 两条后台 lane 的派工与状态（IME 报告补齐 / GRUB 直接引导掉电联网调研）
- **结论**：
  1. **Waydroid 网络没有未解问题**（实测）：容器 → `waydroid0` → `wlp1s0` 直连 NAT 通，
     `baidu/ustc/pypi` = 200、`google` = 302；`ping 8.8.8.8` 在**宿主上也是 100% loss**（校园网拦 ICMP），
     容器无 `/etc/resolv.conf` 是 Android 常态（DNS 走 netd/dnsmasq）。`github` 000 = 上游被墙（宿主直连同样 000）。
     ⇒ 判据统一为容器内 HTTP 码（新 `PITFALLS #603`）。
  2. **droidloom aarch64 包能装能跑**（实测）：`droidloom-runtime-0.1.0-30-aarch64`（6.6 MB）摊到设备 `/opt/dl-test`，
     `droidloom-doctor/ctl/d` 直接执行；doctor **13 过 / 1 阻塞 / 1 警告**。
     唯一阻塞 = `CONFIG_NF_TABLES`（`kernel.network_isolation`）；subuid 100000 契约原本 FAIL，**本轮已修**（`usermod --add-subuids 300000-399999`）。
  3. **合成器缺口被证伪到「合成器没广告」，不是内核/驱动**（实测+静态）：`DRM_CAP_SYNCOBJ_TIMELINE`=1、
     wlroots `check_syncobj_eventfd` 判据通过、EGL `native_fence_sync`+`KHR_wait_sync` 齐 ⇒
     `wlr_linux_drm_syncobj_manager_v1_create()` 的条件全满足，只是 phoc 从未调用；
     **phoc 0.59.rc1 源码全树 `syncobj` 0 命中 ⇒ 升级不能解决**，必须自己补一行（新 `PITFALLS #604`）。
  4. **天花板不变**：PI/Widevine 与 Waydroid 同一结论（上游 `threat-model-v2.md` 免责原文未动）⇒
     **不替换 Waydroid**，droidloom 走隔离试验；做完 L1（nftables）+ L2（phoc 一行）才值得投 L3（0.90 GiB image）。
- **产物**：
  - `reports/droidloom-feasibility-20261110.md`（本段权威：§2 网络定案、§3 设备实测表、§4 最小序列、§5 未取证）
  - `patches/fragment-droidloom-nftables.config`（10 条必须显式项；在 `build/daily` 上验证 = **纯 nftables 40 行 diff，
    `CONFIG_ARCH_QCOM=y` 未受影响**，验证后 `.config` 已回滚）
  - `PITFALLS/README.md` #603/#604/#605
  - IME lane 交付：`reports/ime-phosh-fcitx5-invest-20261110.md` §6–§9 补齐（+159/−8，§1–§5 逐字节未动）
- **设备态变化**：① `/etc/subuid`+`/etc/subgid` 各加 `xuqianhui1001:300000:100000`（回退 = `usermod --del-subuids/--del-subgids`）；
  ② `/opt/dl-test`（24 MB，可删）；③ 装 `wayland-utils`（读 registry）。**零刷写、零重启、零内核改动**。
- **后台 lane**：IME（`195bfed9…`）**已交付**；GRUB 联网调研（`3f42772b…`）**仍在跑**，
  交付物 = `reports/grub-direct-vs-secondstage-20261110.md`（机制层 + 假设表 + 业界先例 + 最小判别序列）。
- **★SSOT 待并入**：`TASKS/README.md` §5 **Q3（droidloom）** 行可补一句「2026-11-10 设备实测：doctor 13 过/1 阻塞，
  阻塞只剩 NF_TABLES（片段已备）；合成器缺口 = phoc 少一行，0.59.rc1 也没有」；§5 **Q1/C3** 行可补「Waydroid 网络已定案，
  判据改 HTTP 码」。本轮只写会话记录 + 报告 + 片段 + PITFALLS，未改 TASKS。

---

## 追加（同日晚）：droidloom 正式立项 C12 + 试验条件就位

### A. 立项
- `TASKS/README.md` §2 新增 **C12 droidloom 隔离试验**（🟡 已立项），**G2 分母 12 → 13**；
  `scripts/check-progress-counts.sh` 的 `--selftest` 断言与 §0 口径注同步改（`8/12` → `8/13`）。
- 明确「**不替换 Waydroid**」：只做隔离试验，退出条件写在 C12 行内。

### B. 试验条件（本轮已就位，除注明外均已实测）

| 项 | 状态 | 证据 |
|---|---|---|
| runtime 包（aarch64） | ✅ 设备上摊开可执行 | `/opt/dl-test`，`droidloom-doctor/ctl/d` 直接跑 |
| doctor 体检 | ✅ **13 过 / 1 阻塞 / 1 警告** | 阻塞 = `kernel.network_isolation`（NF_TABLES） |
| subuid 100000 契约 | ✅ 已修（可回退） | `usermod --add-subuids 300000-399999 --add-subgids 300000-399999 xuqianhui1001` |
| **图形前置** | ✅ **已用 headless sway 验证通过** | `sway 1.12` + `libwlroots-0.20.2` 在 `WLR_BACKENDS=headless` 下广告 `wp_linux_drm_syncobj_manager_v1` v1；`droidloom-wayland` 在其下**无 global bind failure** |
| **内核 nftables** | ✅ **件已备：`out/boot-elden-vk187.img`** | vk184 + 仅 nftables（快照 `patches/config-vk186-nftables-20261110`，14 行纯 nftables diff，9/9 符号一致，`ARCH_QCOM` 未动）；UTS `7.3.1-debug-vk187-00002-g4da9a8b69fc8`，sha `7197997b…`；**未上机** |
| image 包 0.90 GiB | ⬜ 未下 | 需要时下 `droidloom-image-0.1.0-30-aarch64` |
| GApps | ⬜ 无本地 `LiteGapps-arm64-17.0.zip` | 需自建，未做 |
| Debian 上的 `cell.json` | ⬜ 未铺 | 上游路径是 Arch 打包路径（`/etc/droidloom/cell.json` + `runtime.env` + `droidloom-package-helper prepare` 走 `pkexec`） |

### C. 起编点纠错（重要，别再犯）
`build/daily` 的 **HEAD 是 7.3-rc7 血统**（`24223e44ad`），而**现役内核 vk184 是 7.3.1 血统**（`4da9a8b69f`，tag `vk184`）。
第一次从 HEAD 编出 `vk186`（UTS `7.3.0-rc7-…`）⇒ **作废**，必须 `git checkout vk184` 再编，
否则「只差 nftables 一个变量」不成立。重编后 `vk187` 的 UTS 与现役同源（`g4da9a8b69fc8`），只差 `-vk187-` 标签与 nftables 配置。

### D. 下一步（按成本）
1. **零写盘上机 vk187**：`fastboot boot out/boot-elden-vk187.img` → 判据 `nft list ruleset` 不报错 + `droidloom-doctor` 的 `kernel.network_isolation` PASS。
2. 下 image 包（0.90 GiB）+ 手工铺 `/etc/droidloom/cell.json`（照 `usr/share/droidloom/cell-template.json` 与 `packaging/cell-spec-arm64.json`）。
3. `droidloomctl start` → 判据 `droidloomctl applications` 列得出 Android 应用。
