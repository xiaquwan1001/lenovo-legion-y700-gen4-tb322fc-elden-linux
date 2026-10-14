## 二、内核 / DTS / 构建

9. **`make olddefconfig` 会删掉 `CONFIG_ARCH_QCOM` 整行！** 改 `.config` 后**绝不**跑它。
   用 `scripts/config -e/-d` 后直接 `make`，并每次 `grep ^CONFIG_ARCH_QCOM= .config` 验证。
   （`scripts/build-kernel.sh` 已内置校验；根目录兼容包装 `build.sh`/`iterate.sh`/`pack.sh` 已删除。）
   ⚠ **收窄（#162）**：`olddefconfig` 不止手动跑——`apply-kernel-fragment.sh` 合并片段后会**自动**跑它并删 `ARCH_QCOM`（致 vk81/82/83 无 QCOM 驱动的死内核）。原 `grep ^ARCH_QCOM` 守卫只**编前**查、有漏；现已升级为**编后符号守卫**（缺 gcc_sm8750/msm_dsi_host_bonded_cmd_trigger/rpmh → exit 1）+ 片段后回钉。详见 #162。

9b. **★ 编内核忘了 `export ARCH=arm64` 会毁掉 `.config`**（2026-09-30 实际踩到）：
  裸跑 `make Image.gz dtbs` 时 Kbuild 按**宿主机**（x86_64）解析，把 arm64 的 `.config` 当垃圾、
  弹一堆 `(NEW)` 提示并**覆盖写回**，然后报 `没有规则可制作目标 Image.gz`。
  **永远用 `./build.sh` 或 `scripts/build-kernel.sh`（内置 `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`）**，
  不要手敲 `make`。
  **恢复方法（已实测）**：设备上 `zcat /proc/config.gz > /tmp/device.config` 拉回**正在运行内核的精确配置**，
  覆盖 `linux/.config` 后按正确 ARCH 重编。
  （另有本地备份 `.config.bak-vk13-nosuspend` / `.config.old`，但 `device.config` 最权威。）

10. **ABL 会拿 stock dtbo overlay 我们的内嵌 DTB** → 卡 logo。解决：向两个槽写**假 dtbo**（4KB 全零）。
    假 dtbo 生效的迹象：ABL 日志 `Dtbo hdr magic mismatch`。

11. **`reserved-memory` 节点名 `splash-region`（连字符）→ ABL 找不到 `splash_region` 就关显示**；必须下划线。

12. **`&mdss_dp0` 必须 disabled**：DP 是无 ADSP 就永远 defer 的 DRM component，
    会卡住 `msm_drm_bind` → 没有 card0 → 黑屏。

13. **`CONFIG_PHY_NXP_PTN3222=y`（eUSB2 repeater 要内置，不能是 `=m`）**，否则 M31 PHY 起不来、无 USB。

14. **`CONFIG_BACKLIGHT_AW99706=y`**，否则 panel `Failed to get backlight`。

15. **不要打作者的 Mesa chip-id 补丁**（`...44050000`→`...44050001`）：本机内核报 `0xE844050000`（patchid **00**），
    正好匹配 Mesa **原版** wildcard；打补丁反而 unsupported。

16. **★显示间歇性坏：根因 = 面板 init 失败（DSI DCS 首写超时）→ DPU vblank 超时刷屏（2026-10-08 定位，vk63）**。
    - 现象（同前）：偶见 `drm_crtc_wait_one_vblank` call trace 刷屏，只有背光无文字/无桌面；冷启/重来可恢复。
    - **根因（2026-10-08 可见）**：`panel-novatek-nt36536 ae94000.dsi.0: sending dcs data ff 20 failed: -110` → `Failed to initialize panel: -110`（DSI DCS 首写超时）→ 面板从未使能 → DPU 所有提交 `reset failure: -22` + `vblank timeout`（几百次刷屏）——call trace 全是受害者不是根因。失败 boot 上 greetd/phosh 会话可能不起（`phosh=0`）。
    - 实测：vk63 基线 8 boot 中 5 失败（~62%）；同一镜像 `fastboot boot` 与正常 reboot 都触发 ⇒ **与烧录路径/dtbo_b（全零+AVB footer）无关**，属间歇性 DSI/panel init 竞态；失败时面板三供电（`vreg_1v8_vddio/6v1_vsp/5v8_vsn`）均 enabled、DSI 连接器 `connected/enabled/dpms=On`。
    - 待查：失败时 `dsi host`/PHY 上下文；旧基线（vk62）是否同样存在（历史 #16 即「偶见」，应非 vk63 引入）；是否与快速连续 reboot（面板无冷却）相关——下次可试完全断电冷启对比。详见 `../../TASKS/README.md` §5 Q28、`logs/kmsg-vk63-nodesktop-2026-10-08.log`。
    ⚠ **收窄/推翻（#164、#165）**：根因细化为 bonded 双 DSI 首条 DCS 的**命令 DMA 引擎 hang**（L1）；vblank/CTL reset 风暴是其**下游**（L2），非独立 bug（#164）。冷起另有 **NOCARD**（无 card0、DSI PLL 未锁）模式，「无风暴签名」≠「显示好」，GOOD/BAD 判据须三态（NOCARD/STORM/GOOD，#165）。且真实变量是**冷/暖复位**而非时间（#163）。

---

