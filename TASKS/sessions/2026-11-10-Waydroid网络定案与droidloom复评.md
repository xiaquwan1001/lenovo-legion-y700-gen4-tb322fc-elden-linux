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
