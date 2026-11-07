# wl2868c v9（2026-11-07 备料，**2026-11-07T01:50Z 已投递**）

> 触发：`reports/upstream-delta-20261107.md` §3 第 1 条（我方唯一未答的上游欠账）。
> 状态：**已投递（2026-11-07 09:50 CST，3 封全 `Result: 250`，封面 `<20261107015014.22374-1-xiaqinghuan@mail.ustc.edu.cn>`）**；日志 `out/mail-20261107/send-wl2868c-v9.log`。
> 归档复核（2026-11-07 现查 patchwork API）：`devicetree 1/2 needs-ack` + `arm-msm 2/2 new`；v8 两枚已自动 `superseded`。
> 基线：**发信前已按 §7 重基到当轮 master** `d48723711b`（7.4-rc2 线，`Merge tag 'arm64-fixes'`，2026-11-06 13:18 -0800）；
> 首次验证在 `v7.3-rc7`，重基后全部门禁复跑绿（见下 §"重基后复跑"）。
> 未发信前基线是 `v7.3-rc7`（worktree `/tmp/kw9`）。

## 相对 v8 的改动（只有 1/2 变；2/2 与 v8 逐字节相同）

Rob Herring 11-06 14:10Z 对 v6 1/5 的两条（`<20261106141036.GA2921668-robh@kernel.org>`）：

| # | 他的原话 | 落法 |
|---|---|---|
| 1 | "With paragraphs, you need '>' modifier." | 三处多段 description 改折叠块：顶层 `description: >`、`vin7-supply: description: >`、`vsys-supply: description: >` |
| 2 | "Drop. We don't put providers into examples." | example 里 `vsys_reg: regulator-vsys { compatible = "regulator-fixed"; ... }` 整段删除；consumer 只留 `vsys-supply = <&vreg_vsys>;`（与本树其它 binding 同形：`microchip,mcp16502.yaml`、`ti,tps65132.yaml` 都引用未定义的 supply label） |

**Conor 的 pw-bot `changes-requested`**（`<20261106-lucrative-sadden-741ffe6c43e9@spud>`）不是新意见：
v8 在 11:42Z 投出，Rob 的回信 14:10Z 才到（**晚 28 min**）⇒ 时序竞态，不是"无视"。v9 cover §"About the pw-bot" 已写明。

**Krzysztof 11-04 两条**（5/5 拆补丁 / 3/5 compatible 措辞）v8 已用"板 DTS 整段拆出"覆盖，v9 维持不动。

## 门禁（全部现跑，命令可复现）

```
# 1) am 落地（干净 v7.3-rc7 worktree）
git worktree add -f /tmp/kw9 v7.3-rc7 && cd /tmp/kw9
git am -q <本目录>/v9-0001-*.patch <本目录>/v9-0002-*.patch     # → 2/2 OK

# 2) binding 全门（schema + example 编译）
make ARCH=arm64 DT_SCHEMA_FILES=Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml dt_binding_check
# → rc=0，无输出（同 v8 的 rc=0；v8 的 example 因 provider 曾被 Rob 点名，v9 才是干净的）

# 3) driver 编译（W=1）
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= W=1 drivers/regulator/wl2868c-regulator.o
# → rc=0，产 54 288 B .o，0 warning

# 4) checkpatch --strict
perl scripts/checkpatch.pl --strict --no-tree <本目录>/v9-0001-*.patch   # 0 errors, 0 warnings, 0 checks
perl scripts/checkpatch.pl --strict --no-tree <本目录>/v9-0002-*.patch   # 0 errors, 1 warning（MAINTAINERS 提示，1/2 已做）
```

## 重基后复跑（master `d48723711b`）

```
git worktree add -f /tmp/kw9m d48723711b
git am -q v9-0001-*.patch v9-0002-*.patch          # → 2/2 OK（零冲突）
make ARCH=arm64 DT_SCHEMA_FILES=…/willsemi,wl2868c.yaml dt_binding_check   # → rc=0，无输出
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= W=1 drivers/regulator/wl2868c-regulator.o
                                                    # → rc=0，54 688 B，0 warning
```

## 投递事实（2026-11-07，已执行）

1. 实发 3 封（cover + 1/2 + 2/2；按 `b4`/维护者习惯整列重发），每封均 `Result: 250`。
2. `In-Reply-To`/`References` 串到 v8 cover `<20261106114252.988023-1-xiaqinghuan@mail.ustc.edu.cn>`（与 v8→v7 一致）。
3. 发信后 patchwork 复核：`devicetree 1/2` = `needs-ack`、`arm-msm 2/2` = `new`（2026-11-07 现查）——**未**如预期停在 `changes-requested`（Rob 的两点已落）。

## 未做（明确边界）

- ~~没有发任何邮件~~ **已作废：v9 已于 2026-11-07 投出**；patchwork 未手动改（靠自动 superseded）；held-back 的板 DTS（v6 4/5、5/5）仍留在
  `patches/upstream/wl2868c-v7-20261106/held-back/`，等 `TASKS` §7 的复启条件。
- 没碰设备。
