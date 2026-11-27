# 固件能力集合 → 机器门禁（A2 落地）— 2026-11-27

> 输入真源 = `reports/hw-capability-firmware-20261127.md`（lane B 审计，本轮不重做审计）。
> 范围：lane C 四件事 —— ① 清单 SSOT ② A2 门禁修复 ③ §3.5 toml 路径 bug ④ 门禁自测 a–d。
> 未 commit；未改 `TASKS/`、`INDEX.md`、`DEVICE/`、`reports/README.md`（父会话统一收口）。

## 1. 改了什么

| 文件 | 改动 |
|---|---|
| `rootfs/debian/elden-firmware/required-firmware.tsv`（新增） | 本机固件能力集合 SSOT：8 列 TSV（path/class/owner/local/upstream/upstream_note/shippable/why）。数据 32 行 = 31 条固件路径（§2.3 展开后；4 条 split `.mdt` 各配 1 行通配 `.b[0-9][0-9]`）+ 1 行 `regulatory.db`（REGDB，非固件，标注 De­bian wireless-regdb 管）。通配行约定写在文件头：路径含 `[*?[` 即按 glob（`compgen -G`，至少命中 1 个文件），精确行按 `-f`（允许 `.zst` 变体） |
| `rootfs/debian/elden-firmware/build.sh` | ① 新增 `resolve_kdir()`：显式 `KDIR=` → `build/daily` → 仓库内最新 `build/*/.config` 树（按 mtime）→ 都没有则打 `SKIP A2（未找到内核树；用 KDIR= 指定）`（stderr），置 `A2_STATUS=skip`，不计 ok 也不 FAIL；树存在但非 git 仓库同样 SKIP。② `check_driver_fw()` 重写：覆盖面 = `MODULE_FIRMWARE()`（树存在时）∪ 清单；`USERSPACE` 类在 /lib/firmware 照查，`REGDB` 类跳过并打 `skip` 文案；三态 = `ok` / `MISS`（计 FAIL，阻塞出包）/ `MISS(vendor)`（`local=no`，厂商件本机也缺，单列不阻塞）。末行 `A2 合计 N 条：FAIL=x MISS(vendor)=y` + 新增 `清单覆盖 N 条（MODULE_FIRMWARE m + 清单 k）`。③ 新增 `--check-fw-only` 子命令（SRC= 本地目录，否则拉设备源树到临时根）。④ stage/deb 的 A2 调用文案同步 |
| `patches/distro/mobian-20261123/droid-juicer/lenovo,elden.toml` | `gen80000_{gmu,sqe,aqe}` 的 `destination` 由 `qcom/sm8750` 改 `qcom`，zap 单列保持 `qcom/sm8750`；注释写明：`adreno_request_fw` 先试 `qcom/<name>`、legacy 回退是裸 `<name>`，永远不读 `qcom/sm8750/gen80000_*`（§3.5） |

数字对账：审计 §0.1 的「27 个文件路径」**含** `regulatory.db`；展开后固件 = 26 条 + 4 条通配行 = 31 行（通配行是 `.mdt` 分段的机器判据，不是新需求）+ 1 行 REGDB = 32 数据行。

## 2. 门禁自测原始输出（全部真跑）

### a) 临时 staging 根按清单造占位文件 → 期望 MISS=0 ✅

```
=== a) 完整占位根（SRC=/…/tmp.nyczg4blCI）===
  清单覆盖 31 条（MODULE_FIRMWARE 3 + 清单 31）
  ok   ath12k/PEACH/hw2.0/amss.bin
  …（31 条逐条 ok，略同下 b 列表）…
  ok   qcom/vpu/vpu35_p4.mbn
  skip regulatory.db（REGDB 类：Debian wireless-regdb 管，非本包域）
  A2 合计 31 条：FAIL=0 MISS(vendor)=0
rc=0
```

### b) 删 `qca/tmel_peach_20.elf` → 期望恰好 1 条 MISS ✅（门有牙齿）

```
=== b) 删 qca/tmel_peach_20.elf，期望恰好 1 条 MISS ===
  清单覆盖 31 条（MODULE_FIRMWARE 3 + 清单 31）
  ok   ath12k/PEACH/hw2.0/amss.bin
  ok   ath12k/PEACH/hw2.0/aux_ucode.bin
  ok   ath12k/PEACH/hw2.0/board-2.bin
  ok   ath12k/PEACH/hw2.0/board.bin
  ok   ath12k/PEACH/hw2.0/m3.bin
  ok   ath12k/PEACH/hw2.0/qdss_trace_config.bin
  ok   ath12k/PEACH/hw2.0/regdb.bin
  ok   ath12k/PEACH/hw2.0/tmel.bin
  ok   awinic/y700-gen4-haptic.bin
  ok   awinic/y700-gen4-speakers.bin
  ok   novatek_ts_csot_3k_fw.bin
  ok   qca/brhbtfw20.tlv
  ok   qca/brhbtnv20.bin
  ok   qca/brhperifw20.tlv
  ok   qca/brhperinv20.bin
  MISS qca/tmel_peach_20.elf
  ok   qcom/gen80000_aqe.fw
  ok   qcom/gen80000_gmu.bin
  ok   qcom/gen80000_sqe.fw
  ok   qcom/sm8750/adsp.b[0-9][0-9]
  ok   qcom/sm8750/adsp_dtb.b[0-9][0-9]
  ok   qcom/sm8750/adsp_dtb.mdt
  ok   qcom/sm8750/adsp.mdt
  ok   qcom/sm8750/cdsp.b[0-9][0-9]
  ok   qcom/sm8750/cdsp_dtb.b[0-9][0-9]
  ok   qcom/sm8750/cdsp_dtb.mdt
  ok   qcom/sm8750/cdsp.mdt
  ok   qcom/sm8750/gen80000_zap.mbn
  ok   qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin
  ok   qcom/vpu/vpu35_p4.mbn
  A2 合计 31 条：FAIL=1 MISS(vendor)=0
rc=1
```

### c) `KDIR=/nonexistent-kdir` → 期望 SKIP 文案且不被计为 ok ✅

```
  SKIP A2（未找到内核树；用 KDIR= 指定）
  清单覆盖 31 条（MODULE_FIRMWARE 0 + 清单 31）
  …（清单 31 条照查，全 ok）…
  A2 合计 31 条：FAIL=0 MISS(vendor)=0
  （MODULE_FIRMWARE 段已 SKIP，覆盖面不含内核树声明）
rc=0
```
非 git 目录同型：`SKIP A2（内核树 … 不是 git 仓库，无法 git grep；用 KDIR= 指定）`。
补充三态实测：`local=no` 行缺件 → `  MISS(vendor) awinic/y700-gen4-haptic.bin（厂商件，本机也缺）`，`A2 合计 31 条：FAIL=0 MISS(vendor)=1`，rc=0（不阻塞出包）。

### d) 真机现跑（`KDIR=build/daily`，源 = 设备 /lib/firmware，只读）✅

```
$ timeout -k 5 300 env KDIR=build/daily bash rootfs/debian/elden-firmware/build.sh --check-fw-only
  清单覆盖 31 条（MODULE_FIRMWARE 3 + 清单 31）
  ok   ath12k/PEACH/hw2.0/amss.bin …（30 条 ok，同 b 列表但 tmel 在位）…
  ok   qcom/vpu/vpu35_p4.mbn
  skip regulatory.db（REGDB 类：Debian wireless-regdb 管，非本包域）
  A2 合计 31 条：FAIL=0 MISS(vendor)=0
rc=0
```
⇒ 在机 27/27 需求全在位（审计 §0.1 结论被机器门禁复证），MODULE_FIRMWARE 3 条仍被 ∪ 覆盖。

## 3. 已知不覆盖（原因）

1. **`MODULE_FIRMWARE` 宏拼接 glob**（`ath12k/QCN9274/hw2.0/*` 等，`ATH12K_FW_DIR` 拼接）仍不被 `driver_required()` 正则抓到 —— 清单已逐条覆盖 ath12k/PEACH 需求，宏 glob 只是冗余来源，抓到反而要造不存在的目录占位。
2. **`name-map.tsv`/A 门（DT `firmware-name`）与 DTS 默认路径 `build/vk151`** 未动 —— 不在 lane C 范围；DTS 路径漂移是独立问题（`--check`/`--dts-only` 现状：DTS 文件不存在时 `dts_required` 静默为空，A 门退化，待父会话收口）。
3. **SSC 传感器树（§3.8 布局漂移）** 不在本清单（不在 /lib/firmware，属 A' 门域，本轮未动）。
4. **REGDB（`regulatory.db`）只登记不判**：Debian alternatives 符号链，本包永不 ship；启动 -2 是时序问题（§3.9）非缺件。
5. `shippable`/`upstream` 列是审计结论的转写，不做机器校验（分发合规需逐次批准，见 `TASKS/README.md` §7）。

## 4. 回退方式

三个文件相互独立：`git checkout -- rootfs/debian/elden-firmware/build.sh patches/distro/mobian-20261123/droid-juicer/lenovo,elden.toml && rm rootfs/debian/elden-firmware/required-firmware.tsv` 即回到改前状态（`--check-fw-only` 子命令随 build.sh 一并消失，旧行为 = A2 静默失效，不建议回退）。

## 5. 验证

- `bash -n` 通过；`build.sh --help` 正常（含新用法行）。
- `--check`（remote 模式）回归：`源树文件数: 122` + 提示语，rc=0，行为同改前。
- `bash scripts/check-doctor.sh`：本轮改动前 FAIL=3（反作弊探针残留 + 两个索引过期，均为父会话域瞬态）；本轮改动后同机复跑 **FAIL=0 WARN=6**，FAIL/WARN 集合较基线只减不增，无本轮引入项。
- 自测中抓到并修掉的两个实现坑（已写进代码注释）：`resolve_kdir` 的 SKIP 文案若走 stdout 会被 `driver_required >` 重定向混进门禁路径集；`trap … RETURN` 引用 local 变量报 unbound（需现场展开）。
