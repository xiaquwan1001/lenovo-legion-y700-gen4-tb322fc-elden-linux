# 板件 v9 门禁账（2026-11-24，**已备料，未投递**）

> v9 = 板件的 USB 部分（`sm8750.dtsi` label + 板件 mux/两连接器），**依赖 dwc3 两连接器 binding 先进树**。
> 内容与 `../elden-dts-v8-prep-20261121/` 的 `0001/0002` 逐字节相同，只改代次标号并单独成系列
> （v8 prep 的「方案 B」：v8 = qcom.yaml + v7 原文；USB 部分等 binding 落地后作 v9 单投）。

## 0. 数字结论（2026-11-24 现跑，基线与依赖都按「最终会合入的版本」）

| 门 | 命令形状 | 结果 |
|---|---|---|
| 基线 | worktree @ `aebb727447` | = **v7.4-rc3** |
| 依赖（本轮的变动点） | 先 apply `dwc3-v14-20261124/v14-0001`（**v14**，不是 v10/v11）+ `wl2868c-v12` 1/2 | 2/2 rc=0 |
| G1 落树 | 再 apply v9 1/2、2/2 | **2/2 干净**（`0002` 有 1 条「new blank line at EOF」空白告警，与 v8 prep 原记录一致） |
| G2 checkpatch | `--strict --no-signoff --no-tree` ×2 | **0E/0W/0C**（8 行 / 121 行） |
| G4 `dt_binding_check` | 全量（不带 `DT_SCHEMA_FILES`） | **rc=0，0 条诊断**；`DTC [C]` **5421**（比无 wl2868c binding 的 5420 多 1） |
| G5 `dtbs_check` | `CHECK_DTBS=1` elden + mtp + qrd | **3/3 `DTC [C]`，`^arch/.*dtb:` 诊断 0** ⇒ v14 对 `port@0` 的新约束（禁 plain `endpoint`/`endpoint@2+`）对板件无影响 |
| G6 DTB 一致性 | `md5sum sm8750-lenovo-elden.dtb` | **`2d2d92662785a7aa07edb6aba78a9341`** = v10 那轮记录值（binding 只影响校验，不改 DTB 生成结果） |
| G7 上机 | — | 未做（板件 USB 面未在真机跑过；mux 状态 ↔  receptacle 极性本身就是已知缺口） |

## 1. 为什么用 v14 而不是 v10 做依赖

v14 是当前在档最新代（v11→v13 已投，v14 备料修 sashiko 三条 [Low]）。v14 相对 v10/v11 把 `port@0`
收紧了：mux 分支内禁 plain `endpoint` 与 `endpoint@2+`。**板件正是这条新约束的首个消费者**，因此
用 v14 复验才有意义（用 v10 复验只能证明旧形状）。交叉依赖全账 = `../../reports/upstream-recheck-20261124.md` §6。

## 2. 复现命令

```sh
cd /home/xuqianhui/y700-elden
git -C build/elden-tree worktree add --detach /tmp/v9 aebb727447
cd /tmp/v9
git apply ../../../home/xuqianhui/y700-elden/patches/upstream/dwc3-v14-20261124/v14-0001-*.patch
git apply /home/xuqianhui/y700-elden/patches/upstream/wl2868c-v12-20261117/v12-0001-regulator-dt-bindings-*.patch
git apply /home/xuqianhui/y700-elden/patches/upstream/elden-dts-v9-prep-20261124/v9-000{1,2}-*.patch
make -j26 ARCH=arm64 O=/tmp/kb-v9 defconfig
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-v9 dt_binding_check
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-v9 CHECK_DTBS=1 \
     qcom/sm8750-lenovo-elden.dtb qcom/sm8750-mtp.dtb qcom/sm8750-qrd.dtb
md5sum /tmp/kb-v9/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
```

## 3. 未做 / 边界

- **未投递**（按 `TASKS/README.md` §7 逐系列批准），且**从属依赖**：dwc3 binding 未进树前投本系列只会
  换来「等 binding」。
- **未重跑** v8 prep 的两条负样例（同 `mux-state`、去 `mux-controls`）——它们测 DT 自身形状，与 binding
  代次无关，11-21 结论继续有效。
- 临时 worktree / `O=` 构建目录**已在收尾时删除**。
