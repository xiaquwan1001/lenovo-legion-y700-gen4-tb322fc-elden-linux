# M2 A2 与 linux-next 逐 hunk 比对 + 基线切换（2026-10-27）

> 触发：Konrad Dybcio 要求「基线换 `linux-next/master`」，且 A2 需先确认是否已被上游覆盖。
> 范围：**纯主机、零设备**。基线 = `linux-next` **master**（git.kernel.org，2026-10-27 抓取）；
> 对照物兼 `torvalds/linux` master（GitHub raw）。
> 产物：`patches/upstream/m2-a2-linuxnext-20261027/`（v2，已 rebase 到 linux-next 内容）。

## §0 结论（先数字）

| 问题 | 答案 |
|---|---|
| A2 是否已被上游合并 | **没有**。linux-next master 的 `qcom_battmgr.c` 里 `grep -c sm8750` = **0**；`enum qcom_battmgr_variant` 仍只有 `SC8280XP/SM8350/SM8550/X1E80100` 四项 |
| 上游是否已有等效修法 | **没有**。`sm8550_bat_props[]` 里 `POWER_SUPPLY_PROP_POWER_NOW` 仍在**中部**（第 21 项，非末尾），`num_properties` 直接 `ARRAY_SIZE` ⇒ 无「去掉 POWER_NOW」的路径 |
| v1 补丁能否落到 linux-next | **能**，5 hunk 全过（偏移 1/1/27/27），无冲突。文件漂移 = **5 hunk / +38 −11**（7.3-rc7 → linux-next master） |
| 新产出 v2 门禁 | `checkpatch --strict` = **0 errors / 0 warnings / 0 checks**（61 行）；`qcom_battmgr.o` 编译 **rc=0 / 0 warning** |
| **新发现的评审风险** | **高**：linux-next 新增 `qcom,kaanapali-pmic-glink` → 映射到 **`QCOM_BATTMGR_SM8550`**（含 POWER_NOW），见 §3 |
| **v1 提交信息有事实错误** | **是**：v1 写「falls back to QCOM_BATTMGR_SM8350」，实际落到 **SM8550**（DT 第二 compatible 命中）。v2 已改，见 §2 |

## §1 比对方法（可复现）

```sh
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890   # 仅本项目主机代理；--noproxy '*' 直连不通
curl -sSL -o /tmp/ln_battmgr.c \
  'https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/plain/drivers/power/supply/qcom_battmgr.c?h=master'
curl -sSL -o /tmp/master_battmgr.c \
  'https://raw.githubusercontent.com/torvalds/linux/master/drivers/power/supply/qcom_battmgr.c'
# 计数对照（两处 master 结果一致，见 §2 表格）
grep -c sm8750 /tmp/ln_battmgr.c          # 0
grep -n "POWER_NOW" /tmp/ln_battmgr.c     # 450/565/566/803/837/888/920/1332/1496
# 落到 linux-next 内容上的 3-way am（最小仓库只放该文件，见 build/a2-ln/）
```

漂移明细（7.3-rc7 基座 `build/m4-base` ↔ linux-next master）：`wc -l` 1746 → **1773**，5 hunk / **+38 −11**，
内容 = SC8280XP 侧新增 `set_online()` 通知与 `FULL` 判定（`status` 字段提前赋值）、USB 侧
`USB_ADAP_TYPE` 改名、AC 属性表加 `POWER_SUPPLY_PROP_CAPACITY`。**这些都与 A2 无关**，A2 的 5 个 hunk 全部落在未被改动区域。

## §2 v1 → v2 的实质改动（只有提交信息，代码逐字相同）

v1 原话：`the driver has no entry for it, so it falls back to QCOM_BATTMGR_SM8350`。
**实际不成立**——本板 DT 与上游 `sm8750-mtp.dts` 都是

```
compatible = "qcom,sm8750-pmic-glink", "qcom,sm8550-pmic-glink", "qcom,pmic-glink";
```

`of_match` 沿 **compatible 列表顺序**找表项：sm8750 不在表里 → 命中第二项 **sm8550** ⇒ 变体 = **`QCOM_BATTMGR_SM8550`**，
而 SM8550 属性表**含 POWER_NOW** ⇒ 症状（UPower 报 89 W/100 W）与描述一致，但**回归路径描述写错了对象**。
v2 正文改为「resolves to the SM8550 entry listed second in the same node and advertises POWER_NOW」。

**代码零改动**：v1 的「把 POWER_NOW 挪到 `sm8550_bat_props[]` 末尾 + 新描述符 `ARRAY_SIZE - 1`」在 linux-next 上仍然成立
（linux-next 未动该数组顺序），故 v2 = v1 rebase 到 linux-next 内容 + 提交信息纠错。

## §3 ★ 新评审风险：kaanapali 走 SM8550（含 POWER_NOW）

linux-next 的驱动与 binding 同时出现（10 月窗口内新增，v1 投递时的 7.3-rc7 没有）：

| 事实 | 出处 |
|---|---|
| `{ .compatible = "qcom,kaanapali-pmic-glink", .data = (void *)QCOM_BATTMGR_SM8550 }` | `qcom_battmgr.c` `qcom_battmgr_of_variants[]` |
| binding 把 `sm8750` 与 `sm8650`/`x1e80100`/`eliza`/`milos` 放在**同一组**，统一回落 `qcom,sm8550-pmic-glink` | `bindings/soc/qcom/qcom-pmic-glink.yaml` |
| `sm8750-mtp.dts` 与 `sm8750-qrd.dts` **都已有** `pmic-glink` 节点 ⇒ A2 在上游**有真实消费者**（不是自娱自乐） | `arch/arm64/boot/dts/qcom/sm8750-{mtp,qrd}.dts` |
| 上游没有 `sm8750.dtsi` 级 `pmic-glink`，只在板级 | 同左 |

⇒ 维护者最可能的第一问：**「Kaanapali（SM8850，SM8750 的下一代）用同一套 SM8550 属性并保留 POWER_NOW，凭什么 SM8750 要特殊？」**
我方现有证据只覆盖 **TB322FC 这颗 QBG 固件的 `context + 0x6a8 + 4*prop` 取指行为**（v1 正文已写），
**不能推出 kaanapali 也该去 POWER_NOW**，也**不能推出它是 SM8750 独有**。三条处置（见 §5）：
(a) 保持现状，正文点明「未对 kaanapali 做测量、不主张它同样有问题」；
(b) 把它降级成 **DT 属性**（`qcom,no-power-now`）——但「硬件事实进 DT」原则下这个更像固件 quirk，风险是同一条；
(c) 先私下问 Konrad/Dmitry「kaanapali 是否有同款 max-load 行为」，等答复再投。

## §4 交付物

| 文件 | 说明 |
|---|---|
| `patches/upstream/m2-a2-linuxnext-20261027/0001-power-supply-qcom_battmgr-do-not-report-power_now-on.patch` | v2：基线 linux-next master、5 hunk、`+27 −2`、提交信息纠错 |
| `build/a2-ln/` | 最小复现仓（只含该文件 + linux-next 版本作为 base commit），`git am -3` 一次干净 |

门禁原始输出要点：

```
total: 0 errors, 0 warnings, 0 checks, 61 lines checked
CC [M]  drivers/power/supply/qcom_battmgr.o        # rc=0，无 warning
```

编译在 `build/m4-base`（7.3-rc7 全量已配置树）上做：临时换入「linux-next 文件 + v2」后编译，**编完已还原**（`git status` 干净）。
局限：**不是 linux-next 全树编译**（全树需 1.5 GB+ 检出，本轮判定不必要——漂移只在该文件内且已全量替换）。
`checkpatch.pl` 取自 7.3-rc7 树（linux-next 自带的未取），脚本本身无规则差异。

## §5 待拍板（3 条）

1. **形状**：保持 v1 的「挪末尾 + `ARRAY_SIZE - 1`」，还是改独立 `sm8750_bat_props[]`（+22 行重复），
   还是把属性表升进**变体数据结构**（`{ const enum power_supply_property *bat_props; unsigned int num_bat_props; }`）。
   → **建议保持现形状**：A2 是单属性小修，同一系列里重构 5 个 SoC 的变体数据结构会被要求拆成前置准备提交；
   若维护者嫌「顺序魔法」，最小改法是换独立数组（选项 2），**不建议**捆绑大重构。
2. ~~kaanapali 那句要不要写进正文~~ **已定（2026-10-27 夜，按推荐）= 不写进 patch 正文**，改为备一份答复话术
   （`patches/upstream/m2-a2-linuxnext-20261027/REPLY-kaanapali.md`）。理由：正文只陈述本机可举证的事实，
   把「下一代怎么算」留给维护者判断；被问到再答比主动替别人下结论更稳。
3. **是否投 v2**：按「逐系列由用户批准」口径，本轮**只备料不投**。

## §6 下一步

- 若维持现形状：补一封说明（`--no-thread` 单帖 + 正文补「与 kaanapali 的关系」）后投 `linux-pm`；
- 若换独立数组：改 22 行重复表 + 重跑门禁（约 15 min），其余不变；
- 其余系列基线**暂不**整体切 linux-next（M3/M4/M6 的树与门禁都在 7.3-rc7 上；切基线要重建 M1 树，单独立项）。
  全系列对 linux-next 的**去重核对**另见 `reports/upstream-dedup-audit-20261027.md`（结论：只有 aw86927 系列被上游部分占据）。
