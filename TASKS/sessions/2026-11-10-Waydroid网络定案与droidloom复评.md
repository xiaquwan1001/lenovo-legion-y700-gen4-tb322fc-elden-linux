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

---

## 追加 2（同日晚，上机实做）：L1 打通，L3 卡在 rootfs 的目录属主契约

### A. L1 内核 nftables —— ✅ 打通（零写盘 1 发全绿）

件 **`out/boot-elden-vk187b.img`**（sha `7be34b3d…`），`fastboot boot` 12 s 起飞、12 s 到 SSH。
判据全过：`nft list ruleset` rc=0（Waydroid 的 `lxc` 表已从 `iptables-legacy` 迁到 nft，counter 在涨）、
`nft add table/chain/rule` + `delete` OK、`droidloom-doctor` **ready=True blockers=0**、
DSI connected、`wlp1s0` UP、`waydroid` RUNNING、容器 `baidu=200`。

**踩到并修掉的坑（`PITFALLS #607`）**：首版 `vk187` 用 `LOCALVERSION=-vk187` ⇒ 设备上**没有**
`/lib/modules/7.3.1-debug-vk187-*` ⇒ 所有 `=m` 驱动（`icc_bwmon`/`camcc_sm8750`/`cambistmclkcc_sm8750`…）加载不了
⇒ `msm_dpu` 的 icc/clk 依赖永久 defer ⇒ **无 `/dev/dri`** ⇒ phoc `Found 0 GPUs`、doctor `graphics.render_node` fail。
修法 = `LOCALVERSION=-vk184`（源提交同为 `4da9a8b69f`，UTS 自动逐字相同）复用现成 87 M 模块树。
**顺带**：`build/daily` 的 HEAD 是 7.3-rc7 血统，现役 vk184 是 7.3.1 血统 ⇒ 必须 `git checkout vk184` 再编。

### B. L3 image 包 —— 下载/摊装完成，起 cell 卡在 rootfs 属主契约

- `droidloom-image-0.1.0-30-aarch64`（964 196 458 B）已下、已传设备、已 `tar --zstd` 摊到 `/opt/dl-test`
  （2.5 GiB，四个分区镜像 `system/vendor/product/system_ext` 齐全）。
- 手工铺好了 `droidloom-package-helper setup` 的等价物（`/etc/droidloom/{cell.json,runtime.env,package-state.json}`、
  `/etc/polkit-1/rules.d/49-droidloom.rules`、user units、`/var/lib/droidloom/users/1001/data`）。
- **presenter 侧已实证可用**：在 headless sway（有 `wp_linux_drm_syncobj_manager_v1`）下 `droidloom-wayland` 起来无 bind 失败；
  在 phoc 0.58 下必然 `global bind failure`（本轮再次复现，`PITFALLS #604`）。
- **卡点（结构性，不在我们能力边界内）**：`droidloomd` 的 `host_storage::check_parent()` 要求
  **`data_dir` 的所有祖先目录都是 `uid==0` 且 `mode & 0o022 == 0`**。本 rootfs 的 `/`、`/etc`、`/usr`、`/var`
  是 **`1000:1000` + `0775`**（Mobian/Alpine 迁移遗留，不是 Debian 标准）⇒ 直接报
  `unsafe Android storage parent: /var/lib/droidloom/users/1001/data`。
  **不去改 `/` `/etc` `/usr` `/var` 的属主/权限**（会波及全系统，风险远大于收益）。
- 同一族契约还卡住了 `droidloom-package-helper prepare`（要求 `/etc` 是 `root:root` + `0755`），
  所以 setup 只能手工铺（已铺好，可回退）。

### C. 结论与退出

**L1 = 完成**（C12 的内核门槛解除，`doctor ready=True`）。
**L3 = 被 rootfs 属主契约挡住**，两条出路都超出「隔离试验」的成本边界：
① 修 `/` `/etc` `/usr` `/var` 的属主（全系统风险）；② 在 chroot/独立 rootfs 里跑 droidloom（等于新起一套系统）。
⇒ 按「隔离试验、不替换 Waydroid」的立项前提，**C12 停在 L1 收口**，L3 记为「已知阻塞、待将来 rootfs 重做时顺手解决」。
设备侧临时物全部可删：`/opt/dl-test`（2.5 GiB）、`/etc/droidloom/`、`/etc/polkit-1/rules.d/49-droidloom.rules`、
`/usr/share/droidloom/`、`/usr/lib/droidloom` 软链、`/var/lib/droidloom/users/1001`、user units。
