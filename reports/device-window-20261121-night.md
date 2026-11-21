# 设备窗口清单（2026-11-21 夜，待用户放行）

> 生成者 = 主会话（串行持有设备）。设备现态（本次 ssh 实测，2026-11-21 21:0x）：
> `ssh elden` 通（`usb0` 192.168.7.1）、`uname -r` = `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`（LOCALVERSION 残留，现役 = **vk192**）、
> `/`=`/dev/sda17` 190 G 用 7.6 G、`systemctl --failed` 空、`qbootctl -n b` = marked successful、
> 系统时间 NTP 同步（RTC 停在 1970，Q28 T1 已知）、`hexagonrpcd`/`droid-juicer` masked。
> host `adb devices` 里的 `MDX5T20730009849`（P40pro）**不是本机，禁写**。

## 窗口 A（无需物理键，纯 ssh，可随时做）

| # | 项 | 判据 | 回退 |
|---|---|---|---|
| A1 | **D3④ 电源键回归修复**：stock trixie 回退后在版 `phoc 0.46.0-1`（`strings` 0 命中 syncobj），T20 的 `phoc-0.59~rc1-powerfix` + `phosh-0.58.0-powermode` 均不在机 | 装后 `strings /usr/bin/phoc \| grep -c linux_drm_syncobj_manager_v1` ≥1；用户短按熄屏/再按亮屏回锁屏 | `sh scripts/phoc-install.sh --uninstall`（divert 撤销）+ `apt-mark unhold`；备份件别删 |
| A2 | A1 前置核对：trixie 的 phoc 0.46 / phosh 版本是否与 0.59~rc1 件 ABI 兼容（`ldd` + `readelf -d` 比对；不兼容就先重编再装，不硬塞） | `ldd /usr/bin/phoc` 无 `not found`，`greetd` 重启后桌面正常 | 不装，只记录需重编 |
| A3 | **D3④ IPA helper** 核对：`/usr/lib/arm-linux-gnueabihf/libipa*` 不存在（本次实测） | 相机线是否依赖它 = 读 `reports/` 相应结论后再定；无依赖就关掉该项 | — |
| A4 | **D1② hexagonrpcd 保持 mask**（已验证在位）；顺带记录 RTC 漂移量 | `systemctl is-enabled hexagonrpcd` = masked | — |

## 窗口 B（需物理键进 BL / fastboot，零写盘优先）

| # | 项 | 判据 | 风险 |
|---|---|---|---|
| B1 | **D1① b 槽 ESP 重刷**：`out/uefi-bslot-20261121/esp4k.img`（100 MB，sha 见同目录 `esp.img.sha256`）被原厂 `vendor_boot_b` 覆盖 | `fastboot flash vendor_boot_b esp4k.img` 后读回 sha 一致；`fastboot boot` 日用核仍进 Linux | 写 b 槽 ⇒ 先确认 a 槽可弃（现行口径：a 槽已弃，Linux 全靠 b 槽）；失败回滚 = 备份 `bootslot-b/` 现件 |
| B2 | **D7① UEFI flashed 形态复现**（区分「RAM 形态读不出 ESP」vs「没进 BDS」）：依赖 B1 完成 | 屏上出现 GRUB 菜单 / cmdline 里出现 `elden_esp_grub=20261121T1442` 信标 | 与 B1 同窗，同回退 |
| B3 | **D4 a 槽单变量实验**（H6/H7 方向） | 与 B1/B2 不可同轮（槽位控制权互斥，见 TASKS §4.0 互斥表） | BCB 清零纪律先行 |

## 窗口 C（G7 上机，依赖重载 lane 产物）

- 件：`out/g7-routeB-20261121/boot-elden-g7b.img`（子代理正在编，见 `reports/g7-routeB-20261121.md`）
- 前置门（子代理已跑，主会话必须独立复核）：`dtc` 反解后 `status="okay"` 节点 ≥ 8 且含 `ufs`/console/`usb_role`
- 上机：`fastboot boot` 零写盘；USB 面是唯一被测面 ⇒ 挂了只能靠屏幕/串口，用户需在机旁

## 释放条件

- 窗口 A 任一项失败即停，不叠做。
- 窗口 B 必须在窗口 C 之后（B1 会改 b 槽，C 的 RAM 启动件若判死需要 b 槽可回退）。
- 全部结束后：`bash scripts/check-doctor.sh` FAIL=0 + 仓库 clean + 一句收尾。

---

## 执行记录（2026-11-21 21:15 前后，全部 ssh-only，零物理动作）

| 项 | 实测结论 | 动作 |
|---|---|---|
| OS 基线 | **Debian 13 trixie 原装**：`phoc 0.46.0-1` / `phosh 0.46.0-3+deb13u1` / `libwlroots-0.18.so`（不是 11-14 那套 sid+0.58/0.59） | — |
| A1 电源键 | **不需要重装自编 phoc**：T20 根因是「第二个 `zwlr_output_power_v1` 请求者」；`droidloom` 已不在机（`systemctl is-enabled droidloom` = not-found、`/opt/dl-test` 不存在）⇒ 现机只有 phosh 一个请求者，走的是上游单请求者路径。**待用户按一次电源键确认**（不能由 agent 代按） | 未改 |
| A1-件 ABI | 两枚旧自编件（`phoc-0.59~rc1-powerfix` / `phoc-0.58.0-syncobj`）在设备上 `ldd` **各缺 2 个库**：`libgnome-desktop-3.so.21`（trixie 只有 `.so.20`）、`libdisplay-info.so.3`（trixie 只有 `.so.2`）⇒ **直接装会起不来**；真要装必须用 trixie chroot 重编（不是本窗范围） | 未装 |
| A3 IPA helper | 更严重的事实：**整机没有 libcamera**（`dpkg -l | grep -c libcamera` = 0、无 `libcamera/ipa/`）⇒ 相机栈随 stock trixie 回退**整体丢失**，`IPA helper` 不是「缺一个 helper」而是「整条栈要重装 + 自编 libcamera 0.7.1」 | 记为新待办 |
| A4 hexagonrpcd | 仍 masked（设计如此）；`droid-juicer` masked；`systemctl --failed` = 0 单元 | 无动作 |
| **D1④ RTC** | `/dev/rtc0` = `rtc-pm8xxx`，`since_epoch` 423503（1970-01-05）⇒ 断电必归零；`fake-hwclock` 原**未装** | **已装并启用**：`fake-hwclock-load.service`（Before=fsck-root）、`fake-hwclock-save.service`、`fake-hwclock-save.timer` 全 enabled，`/etc/fake-hwclock.data` = `2026-11-21 13:09:57`；`hwclock` 无（util-linux-extra 未装，不需要） |
| 日用体检 | `bash scripts/deploy-desktop-shell.sh --check` = **达标（MISS=0）**：启动队列 mask 齐、greetd active、phoc/phosh/osk 三进程、音频就绪、触觉 aw86927×2 + ffrumble、T9 采样器 active（表 25 行）、A/B mark-successful enabled | 无动作 |
| IME 栈 | `fcitx5 5.1.12` / `fcitx5-chinese-addons 5.1.8` / `phosh-osk-stub 0.46.0` / `fonts-noto-cjk` 全在位；`phosh-osk-stub --allow-replacement` 在跑；`/usr/local/bin/elden-pinyin-completer`（19:20 版）在位 | 无动作 |
| 音频 | `pipewire`/`wireplumber`/`pipewire-pulse` 三件 installed，**用户会话内** active（root 下查是 inactive，别误判） | 无动作 |
| 内核告警 | `dmesg` 有 `DSI PLL(0) lock failed` ×4（T74，开机期）+ `qcom_pmic_glink` device-link 失败 6 条 + `disp_cc_*_clk_src orphan reparent failed -110` 4 条；但 DSI-1 active、桌面正常 ⇒ 记为**已知噪声**，非新回归 | 观测 |

### 由此产生的新待办（建议进 TASKS §4.0）

1. **D1/E 相机栈恢复**（G1 回归）：装 libcamera(+ipa) 并重建自编 0.7.1 + `deploy-camera-modules.sh`，判据 = `cam --list` 认到 2 台 + 后摄 4096×3072 ≥25 fps（旧基线 `reports/camera-vk127-20261017.md`）。
2. **D3 自编 phoc/phosh 是否还要回装**：只有当需要 syncobj（droidloom）或 T20 类 phoc 补丁时才需要，且必须 trixie chroot 重编（旧件 ABI 不匹配）。
