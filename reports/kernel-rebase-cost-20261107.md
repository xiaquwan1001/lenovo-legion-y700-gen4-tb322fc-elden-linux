# 内核重基成本账：7.3-rc7 → 7.3.1（以及为什么暂不跳 7.4-rc1）— 2026-11-07

> 出处：`reports/progress-review-20261106.md` §4 第 4 项（决策点：日常树仍 7.3.0-rc7，落后两个台阶）。
> 本报告只做**静态成本账**（主机侧、git diff 统计），**没有构建、没有重基、没碰设备、没改内核树**（只在
> `build/daily` 里 `git fetch` 了 `v7.3.1`/`v7.4-rc1` 两个 tag，`.config` 用后还原，见 §5）。
> 树基点：`build/daily` HEAD = `24223e44ad80`（`replay-m1-73-vk127`，2026-10-17），tag `v7.3-rc7` = 自定义 commit，上游 `v7.3.1` = `79a907609d`。

---

## 0. 一句话结论

**7.3-rc7 → 7.3.1 的重基成本 = 2 个文件的冲突面（其中只有 1 个真影响日常线），可一次做完；7.3.1 → 7.4-rc1 是另一个量级（16 467 文件 / 104 万行，msm 3 810+、clk/qcom 17 907+、arm64 qcom DTS 44 511+），且直接压我方正在评审的 M 系列 ⇒ 现在别跳 7.4。**

并且 7.3.1 里有**两条与我们直接相关的行为变化**（不是纯 bugfix 噪声），重基后必须上机复测（§2）。

---

## 1. 数字（`git diff --shortstat`，全部现查）

| 基线对 | 文件 | +/- | 我们关心的 payload 目录 |
|---|---|---|---|
| **v7.3-rc7 → v7.3.1** | **242** | **+2421 / −981** | `drivers/gpu/drm/msm`、`drivers/clk/qcom`、`drivers/usb/dwc3`、`drivers/media/platform/qcom`、`arch/arm64/boot/dts/qcom`、`drivers/interconnect/qcom`、`drivers/soc/qcom`、`drivers/firmware/qcom` **全部 0 改动** |
| v7.3.1 → v7.4-rc1 | 16 467 | +1 042 978 / −369 054 | msm 58 文件 +3810/−1836；clk/qcom 105 文件 **+17907**/−1441；dwc3 6 文件 +6/−20；media/qcom 51 文件 +3163/−357；**arm64 qcom DTS 198 文件 +44511**/−1474；interconnect 16 +1366；soc/qcom 19 +1034；firmware/qcom 4（−159，删多于加）；power/sequencing 7 **+1784** |

补丁面交集（我方 `patches/**` 全部 493 枚补丁触及 236 个源文件，与各基线对的改名文件取交集）：

| 基线对 | 交集文件 | 判读 |
|---|---|---|
| 7.3-rc7 → 7.3.1 | **2**：`drivers/power/sequencing/pwrseq-qcom-wcn.c`、`kernel/reboot.c` | 见 §2：前者要手工并 hunk，后者只在历史 vk53 线（日常线不含） |
| 7.3.1 → 7.4-rc1 | **49** | msm/dsi、dpu、clk、sm8750.dtsi、cambist 时钟、kexec/head.S 等全在 ⇒ M6/M8/Q28 栈与 cambist 都得重耍 |

---

## 2. 7.3.1 的两条行为变化（重基的真正风险，不是冲突）

### 2.1 `pwrseq-qcom-wcn.c`：**WLAN 上电不再"保持原电平"，改为 `GPIOD_OUT_LOW`**

```diff
-	/* FIXME: 应该 GPIOD_OUT_LOW，但会导致 WLAN 掉电 → PCIe link down … */
 	ctx->wlan_gpio = devm_gpiod_get_optional(dev, "wlan-enable",
-						 GPIOD_ASIS);
+						 GPIOD_OUT_LOW);
-	gpiod_direction_output(ctx->wlan_gpio, gpiod_get_value_cansleep(ctx->wlan_gpio));
```

- 这正是本机 **WCN7861 / ath12k / MHI** 那条链的电源时序：7.3.1 把"probe 时拉低再抬起"变成默认。
  与 `TASKS` Q26（WiFi 关联即用，已关闭）与 G1-36（候选榜刷新）、以及 `PITFALLS` 里 MHI `POWER_ON -110` 的历史直接相关。
- 影响面：`patches/replay-2026-10-17/0001-elden-payload-v2-…patch`（下游 vk64 payload 里带这个文件的改动）
  与上游系列 **M3-6（WCN7861 PMU support）** 都碰同一段 ⇒ **重基时必须手工并这一处**，不是机械 cherry-pick。
- **上机判据**（重基后第一件事）：冷起后 `nmcli dev wifi connect` 能否关联、`dmesg | grep -E "ath12k|mhi"` 有无 `-110`、
  以及**二次 suspend/resume 后 WiFi 是否还在**（该 FIXME 的原始动机就是 link down 后不可恢复）。

### 2.2 `kernel/reboot.c`：`emergency_restart()` 增加 `nbcon_cpu_emergency_enter()` + `printk_trigger_flush()`

- 与我们的 **PSCI `SYSTEM_RESET2` vendor reset 钩子（`reboot bootloader`/`reboot edl`，G1-24）** 与 **Q28/`dsi_bonded_cmd_failed` 闩锁**取证栈相关：
  崩溃/急停路径的 printk 现在会**先把 nbcon 控制台推进原子模式并 flush**。
- 我方日常线不 patch `kernel/reboot.c`（只有历史 `patches/kernel-history/elden_vk53-hw/0019-…kexec-diag…`）⇒ **无冲突**，
  但重基后要复验：`reboot bootloader` 仍进 fastboot（22 s 判据）、崩溃现场 printk 不再丢。

---

## 3. 结论与建议动作

1. **做 7.3.1 重基（成本可控）**：唯一冲突文件 `pwrseq-qcom-wcn.c` 一人一处手工并；
   全量构建 + 模块 vermagic 一致性（`LOCALVERSION=` 空、`ARCH=arm64 CROSS_COMPILE=…`）+ **WiFi/reboot 两条上机判据**。
2. **暂不跳 7.4-rc1**：49 个交集文件 + clk/qcom 1.8 万行改动，会把 M6（bonded DSI v2，4 枚刚确认在 master 上可 apply）
   与 M8（dispcc 复位 v3，已有 Reviewed-by）一起打回重做。
3. 重基前先把 **M6 v2 / M8 v3 的投递落地**（见 `reports/m6-v2-recut-plan-20261107.md`）；
   否则基线一动，评审中的系列就要重发。

---

## 4. 成本估算（人时）

| 步骤 | 估时 | 判据 |
|---|---|---|
| fetch + worktree 建 7.3.1 基线 | 10 min | `git worktree add` + `git describe --tags` = v7.3.1 |
| 并 `pwrseq-qcom-wcn.c` 一处 hunk | 20 min | 全量构建 0 error/0 warning，`git apply` 无 conflict 标记 |
| 全量构建 `Image.gz dtbs modules`（`-j26`） | 40–60 min（后台） | `modinfo` vermagic == UTS 逐字相等 |
| 上机 2 条判据（WiFi 关联 + `reboot bootloader`） | 20 min + 一次真 POR | 见 §2 判据 |
| 合计 | **~1.5–2 h（其中 1 h 可后台）** | — |

---

## 5. 复现命令（本报告的每个数字）

```bash
cd build/daily
git fetch --depth=1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git refs/tags/v7.3.1:refs/tags/v7.3.1
git fetch --depth=1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git refs/tags/v7.4-rc1:refs/tags/v7.4-rc1

git diff --shortstat v7.3-rc7 v7.3.1
git diff --shortstat v7.3.1 v7.4-rc1
for d in drivers/gpu/drm/msm drivers/clk/qcom drivers/usb/dwc3 drivers/media/platform/qcom \
         arch/arm64/boot/dts/qcom drivers/interconnect/qcom drivers/soc/qcom drivers/firmware/qcom; do
  printf '%-40s %s\n' "$d" "$(git diff --shortstat v7.3-rc7 v7.3.1 -- $d)"
done

# 补丁面交集（我方 493 枚补丁的 +++ b/ 文件集 × 基线对改名文件集）
python3 - <<'PY'
import re, glob
files=set()
for p in glob.glob('/home/xuqianhui/y700-elden/patches/**/*.patch', recursive=True):
    for m in re.finditer(r'^\+\+\+ b/(\S+)', open(p, errors='ignore').read(), re.M):
        files.add(m.group(1))
open('/tmp/our-files.txt','w').write('\n'.join(sorted(files)))
print(len(files))
PY
LC_ALL=C sort -o /tmp/our-files.txt /tmp/our-files.txt
git diff --name-only v7.3-rc7 v7.3.1 | LC_ALL=C sort -u > /tmp/chg731.txt
LC_ALL=C comm -12 /tmp/our-files.txt /tmp/chg731.txt     # → 2 个文件
```

> 注：`git fetch --depth=1` 的浅历史让 `git log <tag> -- <file>` 只显示 tag 提交本身，**归因不可用**；
> 本文只用「文件级 diff + 内容判读」，不用 commit 归因。
> `.config` 在验证 `CONFIG_ZRAM=m` 时曾临时替换，**已还原**（备份 `/tmp/daily-config-before-zram-20261107`，同内容 `git` 无跟踪）。
