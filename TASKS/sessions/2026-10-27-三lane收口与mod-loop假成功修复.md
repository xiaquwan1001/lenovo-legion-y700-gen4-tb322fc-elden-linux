# 2026-10-27 三条 lane 收口 + mod-loop 假成功修掉（模型 `custom-nexavlinks-com`）

> 承接：三条 lane 上一轮被中断（`b5-resoc` / `aw86927-series` / `devcam-ab`）。
> 本轮 = 用 `custom-nexavlinks-com/deepseek-v4.1-flash` 重派 + 编排者独立复核 + **把会反复骗人的工具缺陷修掉**。
> 判据汇总 `reports/lanes-20261027-verified.md`；新坑 `PITFALLS #447`。

## §1 结果（数字）

| lane | tip | commit | 独立复核 |
|---|---|---|---|
| `b5-resoc` | `ea6c518` | 3（`5a3edf6e2`/`fb8f38d95`/`768b7c11d`） | 判据 5/5；**逐提交** rc=0 / 0 warning |
| `aw86927-series` | `41f9996` | 5 | checkpatch 5/5 `0E/0W/0C`；`dt-doc-validate` rc=0；`aw86927.o` rc=0/0 warning；逐枚 `git apply` 成功 |
| `devcam-ab` | `72acfd3` | 1（lane 侧报告） | SKEW_CAL A/B 无可测差异；设备回基线 `2dd23e54…` |

## §2 修掉的工具缺陷（`PITFALLS #447`）

`scripts/mod-loop.sh --reload` 曾在**模块没换**时逐行打印成功并 `rc=0`，三条独立路径：

1. `.ko` 基名 `qcom-camss` ↔ `lsmod` 的 `qcom_camss` 不匹配 ⇒ `rmmod` 从不执行、`modprobe` 必失败且错误被 `2>/dev/null` 吞；
2. `modules_install` 的目的地取自 `include/config/kernel.release`，`M=` 构建不刷新 ⇒ 装进错误 `<KV>`；
3. 它还依赖全局 `modules.order`，丢失时被**误报成「driver is built-in」**。

修法：不再走 `modules_install` → 直接收 `$KDIR/$DIR` 的 `.ko` 以 `updates/<name>.ko` 上传；名字归一化 `tr '-' '_'`；
`modprobe` 失败非零退出；新增 **build-id 硬校验**。实测：

```
[mod] reloaded qcom-camss (as qcom_camss)
[mod] ✅ build-id match qcom_camss: 1fe5d2ccc6d241ff1c2e134366da51d7897c8f05
```
负向测试（传不存在的模块名）现在 `rc=1` 且打印 `❌ 热载未确认成功`。

## §3 本轮我自己造成并已恢复的事故（必须留痕）

修上面第 2 条时，我用 `make -B -s include/config/kernel.release` 去验证「生成文件能否按需重建」。
`-B` 无条件重建整条 syncconfig 依赖链 ⇒ **把 `build/vk151/.config` 从 12 047 行 / `=m` 1464 项改写成 9 042 行 / 686 项**，
`CONFIG_VIDEO_QCOM_CAMSS` 等 900+ 符号被清掉（日常线内核树的配置被搞坏）。

- **恢复路径**：`.config` 不入 git，但 `out/boot-elden-vk172.manifest` 记了 `config_sha256=91dbc727…`，
  而 `patches/config-vk163-modular-v2-20261026` 的 sha256 前缀正是 `91dbc727` ⇒ 逐字还原，
  复核 `sha / 行数 / =m 数 / CAMSS` 四项回到原值（1464、`CONFIG_VIDEO_QCOM_CAMSS=m`）。
- **连带**：把 `include/config/kernel.release` 复位成树原生 `…-dirty+`（无 LOCALVERSION 的值），删掉 `.stale` 残留。
- **纪律**：验证「生成文件能否重建」只能读 `Makefile` 定义或在**一次性 worktree** 里试；
  日常线树上禁跑 `-B`/`clean`/`mrproper`。与 `PITFALLS #54` 同类——**验证动作本身不能有副作用**。

## §4 设备终态

`uname -r` = `…-debug-vk172`；`/lib/modules/<KV>/updates/` **空**；运行中 `qcom_camss` build-id `2dd23e54…` = 开机那颗；
`build/vk151` 的 camss 源码 `git status` 空（4 行 SKEW_CAL 回到 `0x54`）。全程经 `scripts/device-lock.sh`。

## §5 待人工拍板（未擅自改）

1. **b5-resoc**：bonded 表挂 `sm8650_dsi_cfg`（SM8750 报 v2.9、`io_start` 只匹配该表），靠 `qcom,sm8750-dsi-ctrl` 闸门限定 —— 彻底干净需第 4 步拆独立 SM8750 表项。
2. **aw86927 第 4 提交**：顺手修 pristine 的 `BST_7000MV 0x11→0x09`（厂商公式：0x11=9 V），按惯例应拆独立 `Fixes:` 补丁。

## §6 收尾核对

`scripts/check-doctor.sh` = **FAIL=0 / WARN=2**（WARN 均为既存：vk ledger 已登记例外、`boot-elden.img` 无版本号）。
`versions/vk-kernel-identity.tsv` 已重生成；`HISTORY/days` 已 `gen-history.sh` 补齐。
