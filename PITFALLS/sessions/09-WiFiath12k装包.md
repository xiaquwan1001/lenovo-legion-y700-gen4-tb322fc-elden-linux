## 九、WiFi / ath12k / 装包（2026-09-29）

42. **WiFi(PEACH) 缺的不是 board-2.bin，而是 `qdss_trace_config.bin`**：本机 PEACH 定制 ath12k 在 TME-L 后
    强制下载 QDSS trace 配置，缺文件就 `qmi failed to download QDSS config: -2` 直接不建网卡。
    放 `vendor peach/qdss_trace_config_v2.cfg` → `/lib/firmware/ath12k/PEACH/hw2.0/qdss_trace_config.bin`。

43. **★禁区：在线 ath12k 设备绝不能 `remove`/`unbind`**：实测两次都把内核挂死→重启→fastboot。
    只能对「首探失败、已未绑定」的设备 `bind`。

44. **开机首探 MHI `-110` 是竞态**：ath12k 在 ~1.9s probe，WCN 未就绪→MHI 超时→设备留未绑定。
    - ⚠️ **处方已作废（#263/#264/#265，2026-10-14/15）**：「同一实例内延迟重试 / 只 bind 不 unbind」**无效**（连每轮 SoC 全局复位也无效）。正解 = 让驱动 core 重跑整轮 probe，内核内自愈形态 = `ath12k_pci_probe()` 在 `ath12k_core_init()` 返回 `-ETIMEDOUT` 时返回 `-EPROBE_DEFER`（计数上限 4，成功清零）。**本条保留**：首探在 ~1.9 s 失败、设备留未绑定这一现象，以及「历史判据只到 bind 层、不看 MHI 实例状态 ⇒ 会误判已修」。
    用只 bind 不 unbind 的延迟重试脚本（`scripts/ath12k-retry.sh`，已挂 `/init`）解决。
    另有稳定性隐患：bind 成功后运行一段时间内核崩（待查）。

45. **主线能充电，不必改电源驱动**：`qcom-battmgr-bat STATUS=Charging`，“插着净掉电”只是 PC USB 口供电不足。

46. **USB 离线装包（推荐，避开设备侧代理超时）**：主机 qemu-aarch64 跑 rootfs 的 apk `fetch --recursive` →
    scp → 设备 `apk add --allow-untrusted --no-network`。
    ⚠️ 设备 `/etc/apk/world` 残留未装的包（如 epiphany）会让 `apk add` 去补整条依赖树→上百包，先摘掉。

47. **持久 root 只有 2.3 GiB**：Phosh(~900MB) 能装；Plasma Mobile(~1.6GB) 装不下。装大桌面前先看 `df /`。

---

