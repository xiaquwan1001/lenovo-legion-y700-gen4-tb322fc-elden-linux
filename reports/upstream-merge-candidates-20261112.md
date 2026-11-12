# 上游可合并增量评估 — 2026-11-12（lane D）

> 只读评估 lane：只新增本文件；未改既有文件、未动 `.pi/`、未 commit、未碰设备。
> 目的：找出**主线/上游里值得合并进本地树**的更新，并给每条**合并工作量估计**。
> 前序调研不重做：`TASKS/README.md` §7（M1–M10 台账）、`reports/upstream-status-20261105.md`、
> `reports/external-scan-20261112b.md`（llcc ISLAND1 / gcc-sm8750 USB GDSC / iommu mask 三条的初判）、
> `reports/doc-ime-scope-audit-20261111.md`（phoc 版本门）。

## §0 结论先行

1. **值得合并 12 条**：**必修 3 条**（#1–#3：llcc ISLAND1、gcc-sm8750 USB GDSC retention、sm8750 CDSP compute-CB stream-ID mask），
   **可选 9 条**（#4–#12：pinctrl UAF、uefisecapp 溢出、dwc3 ×3、camss ×1 组、drm/msm ×2、ath12k ×2、cmd-db ×1）。
   总工作量估 **≈10–14 人时（或 ~8–12 agent 轮次）**，其中必修 3 条合计 **≈1.5 人时**。
2. **主线 master 本身对我们几乎零增量**：现查 7.4-rc2 基线 → `torvalds/master@9d66f26fef`(11-11) 在
   `drivers/{clk,soc,gpu,media,net}/qcom|msm|ath12k`、`arch/arm64/boot/dts/qcom` 上**只有一次 treewide `devm_kzalloc_obj` 机械转换**（`4dd10fbbeb9c`），
   无一条功能修。**所以「主线增量」≈ 0，真正的增量全在 patchwork 的 accepted/new 队列里**。
3. **最该先做的是 #1–#3 一次 batch（3 个 `git apply` 全部零冲突，见 §1「冲突风险」列）**：
   三者在 `build/m3v2-7.3rc7`（前向树）与 `build/daily`（payload 树）**两边 `git apply --check` 都 rc=0**，纯数据表/DT 值改动，无依赖、无 ABI。
4. **不建议合并 6 类**（§3）：treewide devm 转换（202 文件纯噪声，且与我们 payload 抢同一批文件）、
   ath12k m3 内存重命名/重构（改名字为主，需前序）、`phy-qcom-mipi-csi2-3ph-dphy` RFC（该文件在我们两棵树里都不存在）、
   traceNoC coresight v7（与我们无交叉）、以及**我们自己投出去的系列**（dwc3 双连接器 v8、wl2868c、ADSP fastrpc non-secure）——不能当外部增量读回本地。
5. **§C 用户态判定：升级 phoc 替不掉任何本地补丁，但也白赚一条**——0.59~rc1 的 `handle_text_input_enable()` 里
   `>= ZWP_TEXT_INPUT_V3_SHOW_INPUT_PANEL_SINCE_VERSION → return` **逐字未变**（§C），所以「点输入框 OSK 不弹」升级不解决；
   而 0.58→0.59 的唯一相关 diff（`input-method-relay.c` keyboard-grab NULL）**正是我们自己已进上游的 `bb1f7465`**（0.59~rc1 NEWS 贡献者含 Xu Qianhui）
   ⇒ 升 0.59 可以**删掉本地那份补丁**（省 1 条 patch，但挡不住 OSK 问题）。

### §0.1 基线现查（可复现）

```bash
cd /home/xuqianhui/y700-elden
git -C build/m3v2-7.3rc7 log -1 --format='%h %ad %s' --date=iso
#   e18a4a66eb 2026-11-06 19:46:29 +0800 arm64: dts: qcom: sm8750-lenovo-elden: add the Lenovo Legion Y700 Gen4
git -C build/m3v2-7.3rc7 log --oneline f66469d990..HEAD
#   e18a4a66eb7 board dts / 479e8f03237 binding   ⇒ 上游基 = f66469d990 "Merge tag 'net-7.4-rc2'" (2026-11-05)
git -C build/daily log --oneline -3
#   4da9a8b69fc PLL_SYSTEM_MUXES / 88cd0bc0f4f payload v2(squash) / 79a907609d5 Linux 7.3.1  ⇒ payload 树 = 7.3.1+大payload
git -C geekidos-linux log -1 --format='%h %ad %s' --date=short   # ba28ec16f01 2026-09-14（与上面前向树无关）
```

上游侧（`git.kernel.org` 直连被 reset，改走 GitHub 镜像，`blob:none` 部分克隆，**不 clone 全树**）：

```bash
cd build/m3v2-7.3rc7
git -c http.proxy=http://127.0.0.1:7890 -c https.proxy=http://127.0.0.1:7890 \
    fetch --no-tags https://github.com/torvalds/linux.git master:refs/remotes/gh/master
git log -1 --format='%H %ad %s' --date=iso gh/master
#   9d66f26fefacebfeed15de31c1123451a17ff119 2026-11-11 16:48:56 -0800 Merge tag 'vfs-7.4-rc3.fixes.2'
```

**基线 → master 的功能性差分 = 0**（除 treewide）：

```bash
cd build/m3v2-7.3rc7
git diff --stat=120 HEAD gh/master -- drivers/clk/qcom drivers/soc/qcom drivers/gpu/drm/msm \
  drivers/media/platform/qcom drivers/net/wireless/ath/ath12k arch/arm64/boot/dts/qcom \
  drivers/remoteproc drivers/iommu drivers/usb/dwc3 drivers/pmdomain drivers/pinctrl/qcom \
  drivers/thermal/qcom drivers/firmware/qcom | tail -1
#   202 files changed, 582 insertions(+), 950 deletions(-)  ← 逐条看全是 4dd10fbbeb9c 的 devm_kzalloc_obj 机械替换
#   唯一大块 = arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts 129 行 = 我们自己的板文件（master 没有，正常）
```

⇒ **7.4-rc2 之后主线没有给我们任何东西**（连 `sm8750.dtsi` 都逐字相同，见 §1 #3 说明）。下面的清单因此全部来自 patchwork 队列；
每条都做了**双树 `git apply --check`**（前向树 `build/m3v2-7.3rc7` / payload 树 `build/daily`），这是「冲突风险」列的实测依据。

怎么复现每条的 `--check`：

```bash
for id in 14971425 14970417 14924748; do
  curl -sL --noproxy '*' -A laneD "https://patchwork.kernel.org/patch/$id/raw/" -o /tmp/p/$id.patch; done
git -C build/m3v2-7.3rc7 apply --check /tmp/p/14971425.patch && echo clean
```

---

## §1 逐条表

| # | 上游 commit / 补丁 | 影响我们的 | 类型 | 合并方式 | 冲突风险（实测） | 工作量估计 | 建议顺序 |
|---|---|---|---|---|---|---|---|
| 1 | **llcc ISLAND1 → `res_ways`** https://patchwork.kernel.org/patch/14971425/ （`new`, 11-11, yzddMr6） | `drivers/soc/qcom/llcc-qcom.c` `sm8750_data[]`：本地仍 `bonus_ways = 0x7fffffff`（同文件 884–890 行） | 修 bug（s2idle 下 LPASS 无票 → PS_HOLD 复位） | cherry-pick（1 行） | **零冲突**：`git apply --check` 前向树 rc=0、daily rc=0；patch index `d7a42a8040a1` 与本地 blob **逐字相同** | **0.5 人时 / 1 轮**（1 文件 1 行；无需 dtbs_check；仅 `make drivers/soc/qcom/llcc-qcom.o` 验证）。**当前 `CONFIG_SUSPEND=n` ⇒ 不合并也不爆**，属「重启 suspend 线的前置」 | 1 |
| 2 | **gcc-sm8750 USB GDSC → `PWRSTS_RET_ON`** https://patchwork.kernel.org/patch/14970417/ （`new`, 11-10, **Abel Vesa `Reviewed-by`**） | `drivers/clk/qcom/gcc-sm8750.c` `gcc_usb30_prim_gdsc`(2943) / `gcc_usb3_phy_gdsc`(2955)：本地仍 `PWRSTS_OFF_ON` | 修 bug（s2idle + USB host 恢复后 SMMU fault / xHCI 死） | cherry-pick（2 行） | **零冲突**：双树 rc=0；上下文行与上游 diff 完全对齐 | **0.5 人时 / 1 轮**（1 文件 2 行，`make drivers/clk/qcom/gcc-sm8750.o`）。**同族先例已 accepted**：`clk: qcom: gcc-sa8775p: Use retention for USB power domains`（14957070, 11-06 accepted）⇒ 这条进树概率高，值得先拿 | 1 |
| 3 | **sm8750 CDSP compute-CB stream-ID mask 修** https://patchwork.kernel.org/patch/14924748/ （**`accepted`**, 10-29, `commit_ref=afe52f52d6`, 在 arm-msm-next、**尚未进 master**） | `arch/arm64/boot/dts/qcom/sm8750.dtsi` `compute-cb@12`/`@14`：本地仍是未修掩码 | 修 bug（CDSP 打开后 IOMMU 认不到 CB） | cherry-pick（DT 值） | **零冲突**：双树 rc=0；且 `git diff HEAD gh/master -- arch/arm64/boot/dts/qcom` 无 sm8750.dtsi 变更 ⇒ master 还没有，不存在「已自动吃到」 | **0.5 人时 / 1 轮**（`make dtbs` + `dtbs_check` 0 诊断）。**开 CDSP/NPU 前必修**，与外部 `h0cheung/tb322fc-linux` 的手工展开是同一处 | 1 |
| 4 | **pinctrl: qcom shutdown 路径 UAF** https://patchwork.kernel.org/patch/14954301/ （`handled-elsewhere`=已进 maintainer 树） | `drivers/pinctrl/qcom/pinctrl-msm.c`（我们 TLMM 天天用） | 修 bug（reboot/关机偶发 UAF） | cherry-pick | 零冲突（双树 rc=0） | **0.3 人时 / 1 轮**（`make drivers/pinctrl/qcom/pinctrl-msm.o`） | 2 |
| 5 | **firmware: qcom: uefisecapp GetNextVariableName 溢出** https://patchwork.kernel.org/patch/14951766/ （`new`, 11-05） | `drivers/firmware/qcom/qcom_qseecom_uefisecapp.c`（EFI 变量读写路径，UEFI 线 / G1-29 相关） | 修 bug（栈/缓冲溢出） | cherry-pick | 零冲突（双树 rc=0） | **0.3 人时 / 1 轮**（编译即可；行为验证需上机读 efivar） | 2 |
| 6 | **usb: dwc3: qcom: `read_usb2_speed` 的 hcd 判空** https://patchwork.kernel.org/patch/14956144/ （`RESEND v3`, 11-06） | `drivers/usb/dwc3/dwc3-qcom.c`（**M3-1 双连接器线同一文件**） | 修 bug（NULL deref） | cherry-pick | 零冲突（双树 rc=0） | **0.3 人时 / 1 轮**；但若 M3-1 v9 本地分支也在改该文件，**先合并这条再 rebase 本地分支** | 2 |
| 7 | **usb: dwc3: host: xHCI reset 前等端口离开 RxDetect** https://patchwork.kernel.org/patch/14957329/ （`new`, 11-06） | `drivers/usb/dwc3/host.c`：USB host 接外设时的枚举稳定性 | 修 bug | cherry-pick | 零冲突（双树 rc=0） | **0.5 人时 / 1 轮**（编译 + 上机插拔一次） | 3 |
| 8 | **camss v2 四连**（14964184 `Kconfig` / 14964185 `vfe-4-1` RDI W/M buffer size / 14964186 `video.c` always stop pipeline / 14964187 `camss.c` CSID 无匹配 VFE 不报错） https://patchwork.kernel.org/patch/14964184/ | `drivers/media/platform/qcom/camss/*`（G1 相机线） | 修 bug（无 IOMMU 时的 buffer、RDIO 尺寸、stop 路径、CSID powerup） | **手工移植/整组 cherry-pick** | **前向树 4/4 零冲突；daily 2/4 冲突**（`Kconfig:5`、`camss-video.c:313`）——因为 payload v2 改过这两处 | **2–3 人时 / 2–3 轮**（4 文件；要跑 `make drivers/media/platform/qcom/camss/` + 上机出流一次；daily 需人工解 2 处冲突） | 4 |
| 9 | **drm/msm/dp: enable 失败后跳过 link teardown** https://patchwork.kernel.org/patch/14943452/ （`new`, 11-04） | `drivers/gpu/drm/msm/dp/dp_display.c`（外接 DP 线） | 修 bug | cherry-pick（前向树）/ 手工（daily） | **前向树 rc=0，daily 冲突**（`dp_display.c:1528`，payload 改过该函数） | **1 人时 / 1–2 轮** | 4 |
| 10 | **drm/msm: UBWC 布局校验（3/7）+ RGB 注释（1/7）** 14944889 / 14944891 https://patchwork.kernel.org/patch/14944891/ | `drivers/gpu/drm/msm/msm_fb.c`、`disp/dpu1/dpu_formats.c`（显示合成正确性） | 修 bug（UBWC framebuffer 布局越界/strides 检查缺失） | cherry-pick **只取 1/7 与 3/7** | 1/7、3/7 **双树 rc=0**；**2/7（14944890，把 plane size 计算搬出 DPU）两棵树单测都 FAIL**（`dpu_formats.c:58`）⇒ 该枚要人工移植 | **1 人时 / 1–2 轮**（2 文件 + 上机 phoc 合成一次）；2/7 若要，再 +1–2 人时 | 4 |
| 11 | **ath12k: 注册 regulatory 先于 wiphy** https://patchwork.kernel.org/patch/14952186/ （`accepted`, 11-05） | `drivers/net/wireless/ath/ath12k/mac.c|reg.c`（WCN7861 的 regdom / 信道表） | 修 bug（首个 reg 通知丢失 → 信道/功率表错，疑似我们 bmiss/flap 的协变量） | cherry-pick | 零冲突（双树 rc=0） | **0.5 人时 + WiFi 回归 1 轮**（`make .../ath12k/` + 上机 `iw reg get`/关联一次） | 5 |
| 12 | **soc: qcom: cmd-db probe race（ERR_PTR 解引用）** https://patchwork.kernel.org/patch/14944582/ （`accepted`, 11-04） | `drivers/soc/qcom/cmd-db.c`（RPMh/资源，所有 qcom 板必经） | 修 bug（probe 竞争） | cherry-pick | 零冲突（双树 rc=0） | **0.3 人时 / 1 轮** | 5 |

> 附：另有 3 条「零成本顺带」——`14957689`（dwc3 删多余 `pm_runtime_dont_use_autosuspend()`，双树 rc=0）、
> `14944477`（tsens 去 `__init`，双树 rc=0）、`14956589`（dwc3-qcom 把 live SS-link 状态传 PHY，suspend 线前置，双树 rc=0）。
> 三者各 ≈0.2 人时，建议并进 #1–#3 那一批一起 apply；`14944478`（tsens-v1）在 daily 冲突（`tsens-v1.c:145`），只在前向树合。

---

## §1b 用户态上游（C 块）：phoc / phosh / phosh-osk-stevia / fcitx5

只查与我们 11-11 输入法/显示补丁相关的部分（`bb1f7465`、`input-method-relay.c` 的 `show_input_panel` 版本门）。

**现查证据（全部本机可复现）**：

```bash
# 0.58（我们在跑的自编件）与 0.59~rc1（sid 里唯一比它新的）两棵源码都在本机
ls /opt/elden/arm64-sid/build-phoc/          # src58/  phoc-0.59~rc1/  build58/  build59/
grep -rn "SHOW_INPUT_PANEL_SINCE_VERSION" \
  /opt/elden/arm64-sid/build-phoc/src58/phoc-0.58.0/src/input-method-relay.c \
  /opt/elden/arm64-sid/build-phoc/phoc-0.59~rc1/src/input-method-relay.c
#   0.58.0 :259   ZWP_TEXT_INPUT_V3_SHOW_INPUT_PANEL_SINCE_VERSION)
#   0.59~rc1:260  ZWP_TEXT_INPUT_V3_SHOW_INPUT_PANEL_SINCE_VERSION)     ← 同一行、同一个 return

diff -u /opt/elden/arm64-sid/build-phoc/src58/phoc-0.58.0/src/input-method-relay.c \
        /opt/elden/arm64-sid/build-phoc/phoc-0.59~rc1/src/input-method-relay.c
#   唯一实质 diff = handle_input_method_keyboard_grab_destroy() 的 keyboard_grab 取法（= 上游 bb1f7465，我们自己提的那条）

curl -s --noproxy '*' https://sources.debian.org/api/src/phoc/ | python3 -m json.tool | head -30
#   sid = 0.59~rc1-1（最新）；forky = 0.58.0-1   ⇒ **没有 0.59 正式版、也没有 0.60**
```

**判定**：

1. **`show_input_panel` 版本门没被上游修掉，而且短期不会**——0.59~rc1 的 `handle_text_input_enable()` 里
   `if (wl_resource_get_version(...) >= ZWP_TEXT_INPUT_V3_SHOW_INPUT_PANEL_SINCE_VERSION) return;` 逐字保留；
   这条门是 0.58.0 NEWS 里写明的**故意行为**（"text-input-v3: Add basic support for version 2 to work around an issue in GTK 4.24"），
   不是待修的 bug ⇒ 「升级到 0.59/0.60 就能让 OSK 弹」**不成立**（结论与 `reports/doc-ime-scope-audit-20261111.md` §4 D12 一致，此处用 0.59~rc1 源码再确认一次）。
2. **升级能替掉一条本地补丁**：0.58→0.59 在我们关心的文件上**只差 `bb1f7465`**（keyboard-grab NULL），而它已在 0.59~rc1 上游
   （`phoc-0.59~rc1/NEWS` 贡献者含 **Xu Qianhui**）⇒ 升到 0.59~rc1 后 `patches/upstream/phoc-im-keyboard-grab-2026-10-18/` 可以退役。
   **判据**：`grep -n "keyboard_grab = relay->input_method" /opt/elden/arm64-sid/build-phoc/phoc-0.59~rc1/src/input-method-relay.c` 有命中即成立。
3. **升级工作量**：已有 `build59/` 目录与 0.59~rc1 的 debian 化源码 ⇒ 只需重编 + 装机验证 syncobj 补丁仍在（`0001-syncobj.patch`），
   **≈0.5–1 人时**；风险 = 0.59 拉了 wlroots 子项目版本，需重跑一次「Wayland 起来 + phosh 起 + 输入框点击」三判据。
4. **phosh / phosh-osk-stevia / fcitx5：未证**（本 lane 没查；本轮任务范围只要求「升级能否替掉本地补丁」，
   上面第 1/2 条已给出否/是两种答案，故未展开）。

⇒ 用户态侧**没有「必修」项**；唯一动作 = 升 phoc 0.59~rc1 以退役一条本地补丁（可选，性价比中等）。

---

## §2 合并顺序与批次建议

前提：**前向树 = `build/m3v2-7.3rc7`**（= `patches/current-tree` 指向的那棵：7.4-rc2 + 本地板级 DTS，工作区 clean）。
主线上做合并应落在这棵树；`build/daily`（7.3.1 + payload v2 大 squash）只作对照/回退，不往上合。

### 批 1 —— 一次 `git apply`，14 枚零冲突（0 依赖，不需要 rebase）

```bash
IDS="14971425 14970417 14924748 14954301 14951766 14956144 14957329 14952186 \
     14944582 14957689 14944477 14956589 14944889 14944891"
mkdir -p /tmp/up-merge
for id in $IDS; do
  curl -sL --noproxy '*' -A laneD "https://patchwork.kernel.org/patch/$id/raw/" -o /tmp/up-merge/$id.patch
done
cd /home/xuqianhui/y700-elden
git -C build/m3v2-7.3rc7 apply --check /tmp/up-merge/*.patch && echo "ALL CLEAN"   # 已实测：逐枚 rc=0
git -C build/m3v2-7.3rc7 apply         /tmp/up-merge/*.patch
```

覆盖 §1 的 #1 #2 #3 #4 #5 #6 #7 #11 #12 + #10 的 1/7&3/7 + 三条零成本顺带。
**批内无先后依赖**（互不碰同一文件；已逐枚验证）。

### 批 2 —— 需手工移植（本地 payload 与上游抢同一文件）

| 文件 | 上游项 | 冲突原因 |
|---|---|---|
| `drivers/media/platform/qcom/camss/{Kconfig,camss-video.c}` | 14964184 / 14964186 | payload v2 改过 `camss-video.c` 的 `video_stop_streaming()` 与 camss 的 Kconfig 开关 |
| `drivers/gpu/drm/msm/dp/dp_display.c` | 14943452 | payload v2 改过该函数（1528 行附近） |
| `drivers/gpu/drm/msm/disp/dpu1/dpu_formats.c` | 14944890（2/7） | 上游已重排该函数，两棵树都对不上（**要先做一次人工 diff 对齐**） |
| `drivers/thermal/qcom/tsens-v1.c` | 14944478 | payload 改过 `tsens-v1.c`（145 行）；**只在前向树合，别在 daily 合** |

做法建议：**先在前向树把批 1 做完并跑通编译/上机，再单独一人一轮处理批 2**（每次只带 1 组，冲突当场解，不攒）。

### 批 3 —— suspend 线重启时才做（#1 #2 是它的前置）

`CONFIG_SUSPEND` 现为 `n`（两棵树都是，实测 `grep '^# CONFIG_SUSPEND' build/*/.config`），
所以 #1/#2/#7/`14956587-89` 这组**现在合并也不会有可观测效果**，但**必须在那条线开工前先落地**，
否则会从零 triage「s2idle 后 PS_HOLD 复位」（#1）与「resume 后 arm-smmu fsr=0x402 + xHCI 死」（#2）两个假象。
顺序：批 1 → 开 `CONFIG_SUSPEND` → `14956587+14956588+14956589`（PHY/PHY combo/dwc3-qcom 的 SS-link 状态串）→ 上机 s2idle A/B。

### 批 4 —— 大件，先调研后决定（不建议现在合）

`ath12k` v5 link-id 11 连（14967215–14967225，**accepted**）与 `camss` SOF/QoS v3 11 连（14959674…）：
两组在本机两棵树上 `git apply --check` 都在**第一枚就 FAIL**（`ath12k/hw.h:246`、`camss-csid.c:1356`），
说明它们基于比 7.4-rc2 更新的树（含我们缺的前序提交）⇒ 要整组移植得先把前序找齐，成本 ≥1 天，见 §5。

---

## §3 明确不合并的清单

| # | 对象 | 理由 |
|---|---|---|
| N1 | `4dd10fbbeb9c` + `0af298e62e5c`（treewide `devm_kzalloc_obj` 家族，**202 文件**，含 `llcc-qcom.c`/`arm-smmu.c`/`dwc3/*`/`msm/*`/`camss/*`） | **纯机械转换、零行为变化**；且与我们 payload 抢同一批文件 ⇒ 现在合并只是给未来 rebase 制造 200 处冲突。**正确做法：等 7.5 合并窗口自然进入**（我们下次 rebase 到 7.5 时白拿）。判据：`git diff --stat HEAD gh/master -- <paths>` 里除它以外没有功能改动。 |
| N2 | `ath12k` m3/aux_uc 内存重命名+重构（14943062/14943063，accepted） | 改名为主、无功能修；daily 树 `qmi.h:152`/`qmi.c:3225` 冲突；还会把后续 ath12k 补丁的上下文全打乱。**收益 ≈ 0**。 |
| N3 | `phy: qcom-mipi-csi2: clamp settle count to six`（14954828，RFC） | 目标文件 `drivers/phy/qualcomm/phy-qcom-mipi-csi2-3ph-dphy.c` **在我们两棵树里都不存在**（未见该驱动）；且是 RFC。 |
| N4 | `arm64: dts: qcom: sm8750: bind traceNoC on the platform bus` v7（14966086/7） | coresight/ETF 线，与我们的显示/相机/UFS/传感器零交叉；我们也没有 trace 使用场景。 |
| N5 | **我们自己投出去的系列**：dwc3 双连接器 v8（14957383/14957385）、wl2868c v6（14942833–14942836，superseded）、ADSP fastrpc non-secure v3（14971025） | 这些是**我方外发**，本地原件在 `patches/upstream/*`；从 patchwork 往回抓会把「评审中的版本」当上游增量，属于口径错误。真要用走本地目录。 |
| N6 | `drm/msm` GPU 线：IFPC/runpm 6 连（14946131–14946136）、`a8xx` alpha 精度（14950943）、DPU WB（14975400 等） | GPU/相机超分与 G1 显示点亮无关；我们的显示问题在 DSI/DPU 时序（Q28/E1b 线），不在这些路径。**未证收益**，不做。 |
| N7 | `14944890`（UBWC 2/7，plane size 计算搬出 DPU） | 两棵树单测都 FAIL（`dpu_formats.c:58`）⇒ 必须先人工对齐上游对该函数的重排；单枚价值（代码整理）不足以付这个成本。 |

**与本地 Q28/Q24/payload 冲突的落点（提醒，不是拒绝理由）**：
`sm8750.dtsi`（#3）、`camss-*.c`（#8）、`dp_display.c`（#9）、`tsens-v1.c`（顺带）——这四处都在 payload v2 的改动范围内，
合并时**只改数据/分支，不碰我们自己的寄存器级补丁**；Q28（bonded DSI）与 Q24 相关代码本批一条都不涉及（无冲突面）。

---

## §4 验证门（每条合并后必跑，命令可复制）

构建纪律：**必须走 `scripts/build-kernel.sh`**（`ARCH=arm64`、`CROSS_COMPILE=aarch64-linux-gnu-` 都在 `scripts/env-build.sh` 里；
裸 `make` 会按宿主 x86 重写 `.config`），并发用 `JOBS=26`。

```bash
cd /home/xuqianhui/y700-elden

# 门 1：只编受影响的 .o（秒级，批 1 用这个就够）
. scripts/env-build.sh
kbuild drivers/soc/qcom/llcc-qcom.o drivers/clk/qcom/gcc-sm8750.o \
       drivers/pinctrl/qcom/pinctrl-msm.o drivers/firmware/qcom/qcom_qseecom_uefisecapp.o \
       drivers/usb/dwc3/dwc3-qcom.o drivers/usb/dwc3/host.o drivers/usb/dwc3/core.o \
       drivers/soc/qcom/cmd-db.o drivers/thermal/qcom/tsens.o
# 相机批另跑：kbuild drivers/media/platform/qcom/camss/
# 显示批另跑：kbuild drivers/gpu/drm/msm/

# 门 2：整树（Image.gz + dtbs），改了 DTS 必须跑
JOBS=26 scripts/build-kernel.sh            # 默认 Image.gz + dtbs

# 门 3：DT 校验（只在动了 .dts/.dtsi 时；#3 / 批 2）
. scripts/env-build.sh
kbuild CHECK_DTBS=y qcom/sm8750-lenovo-elden.dtb 2>&1 | tee /tmp/dtbs_check.log
grep -c "Warning\|Error" /tmp/dtbs_check.log      # 期望 0（注意 dtbs_check 不覆盖 binding 元 schema）

# 门 4：上机判据（零写盘 fastboot boot 即可，见 DEVICE/README）
```

上机判据（对应 §1 条目；每条都要「有数字」）：

| 条目 | 判据命令 | 通过条件 |
|---|---|---|
| #1 llcc | 先开 `CONFIG_SUSPEND=y`；`cat /sys/power/state`；`rtcwake -m mem -s 20; dmesg | grep -iE 'llcc|PS_HOLD'` | 20 s 后自动醒、**不重启**；无 `Reset by PSHOLD` |
| #2 USB GDSC | 插 USB host 外设 → `echo mem > /sys/power/state` → 唤醒；`dmesg | grep -iE 'arm-smmu|Host System Error'`；`lsusb` | 0 条 SMMU fault / Host System Error；`lsusb` 列表与睡前一致 |
| #3 CDSP CB mask | 起 CDSP 后 `ls /dev/fastrpc-*`；`dmesg | grep -iE 'cdsp|smmu'` | 无 `fsr=` fault；`compute-cb@1` 能 attach |
| #4 pinctrl UAF | `reboot`（或 `poweroff`）3 次，`dmesg -w` 抓 KASAN/`Unable to handle` | 无 UAF 栈 |
| #5 eefisecapp | `efivar -l | head`；`cat /sys/firmware/efi/efivars/...` | 不崩、变量可枚举 |
| #6/#7/#顺带 dwc3 | 插拔 3 次；`dmesg | grep -c xhci`；`lsusb -t` | 枚举成功、无 NULL deref WARN |
| #8 camss | 出流一次（既有流程）；`dmesg | grep -i vfe` | 出帧、stop 后无 `vfe` 残留错误 |
| #11 ath12k | `iw reg get`；`wpa_cli status`；关联 30 min `dmesg -k | grep -c bmiss` | regdom 正确、bmiss 不劣于合并前 |
| #12 cmd-db | `dmesg | grep -i cmd-db`；`cat /sys/kernel/debug/qcom_cmd_db/...`（若有） | 无 ERR_PTR 相关 WARN |

---

## §5 未证 / 盲区

1. **本报告的主线侧只到 `torvalds/master`（11-11 16:48 -0800）+ patchwork 快照（11-12 18:30 CST）**。
   `kernel.org` 直连被 reset（`Recv failure`，见 §0.1），**linux-next 全树没拉**（GitHub 无官方镜像）⇒
   `clk-next` / `arm-msm-next` / `ath-next` 里已 accepted 但未进 master 的内容，我**只用 patchwork 的 `state`/`commit_ref` 代理**判断，
   **未逐条核对 maintainer 树**。已修正是有 `commit_ref` 的只有 #3（`afe52f52d6`）。
2. **`ath12k` v5 link-id 11 连（accepted）的收益未证**：它修的是「未校验 hardware link id 的 OOB」+ 多 device 逻辑，
   而 WCN7861 是单 device 场景；我们 WiFi 线的 bmiss/flap 与它是否相关**没有任何证据**。整组在两棵树上都 apply 不了（缺前序）⇒ 建议单独立项调研，不进本次合并。
3. **`camss` SOF sequence tracking + CPU latency QoS v3 11 连**同理：apply 不了、且是 11 枚大改；对 G1 相机「出流+App 实测」是否有帮助**未证**。
4. **daily（7.3.1 payload）与 7.4 前向树的行为差异未评估**：批 2 里 camss/dp 的「手工移植」若移植到 7.4 树，
   会和 payload 在 7.3.1 上的既有验证结果脱钩；**是否需要在 daily 上重做一遍上机验收，未证**。
5. **未查的 project**：`linux-pm`、`linux-input`、`linux-sound`、`linux-mmc`、`linux-bluetooth`、`netdev`。
   我们音频（q6apm/WSA）、触觉（aw86927，自己投的）、BT（wcn7850-bt）、UFS 相关的外部修可能被漏掉。
   判据：本次只按 `linux-arm-msm / linux-clk / dri-devel / linux-media / linux-usb / linux-wireless` 六个 project 扫。
6. **所有条目都没有编译、更没有上机**（本 lane 只读、零写盘）；工作量估计基于「文件数 + 是否冲突 + 是否要跑 dtbs_check/上机」，
   不是实测工时。
7. `build/geekidos-linux` 那条 1.9 G 仓在 7.2 血统（`ba28ec16f01`，2026-09-14），**与前向树无关**，本报告未把它当基线
   （`patches/current-tree` = `build/m3v2-7.3rc7` 已核实）。
