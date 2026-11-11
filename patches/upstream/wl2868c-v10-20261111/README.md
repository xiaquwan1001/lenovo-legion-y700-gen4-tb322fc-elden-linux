# wl2868c v10（2026-11-11）

- 触发：sashiko `<sashiko-outbox-205554@kernel.org>`（2026-11-09）对 v9 2/2 的 3 条 Medium
  + v7 评审未结转的 2 条 Low；权威方案 `reports/wl2868c-v10-plan-20261111.md`。
- 文件：`v10-0000-cover-letter.patch`（AI 披露 + changelog 在 `---` 线下 + 5 条逐项回应）、
  `v10-0001`（binding：example 加 `vin12-supply`；MAINTAINERS 驱动 F: 移出）、
  `v10-0002`（driver：①SYS_EN 才播种 ②GPIOD_OUT_HIGH→supply→显式释放→startup 延时→ID 读，
  devres 逆序=物理下电序 ③vsys→vin7 回退（`-ENODEV` 才回退，不吞 -EPROBE_DEFER）
  + 自审 S1（is_enabled 用 chip->regmap）+ S5（wl2868c_reset→reset_assert））。
- binding 本体（anyOf/属性）**未改**：方案 §5 判定三条 Medium 全部只动驱动即可成立。
- 门禁：`GATES.md`（git am 干净 / checkpatch 0E0W0C ×2 / W=1 rc=0 / dt_binding_check rc=0 /
  get_maintainer self-test 无新增告警）。基线 = 7.2 pristine `25f7927e6ccb`。
- 投递：`out/mail-20261111/send-wl2868c-v10.log`；核对结果见该目录 README。
- 已知取舍：1000 µs 延时与 150 µs enable_time 无可引用 datasheet 页码（cover 已如实注明）；
  `GPIOD_OUT_HIGH` 语义依赖板 DTS 写 `GPIO_ACTIVE_LOW`（elden 已核）。
