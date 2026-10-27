# U6 终审：`qcom_q6v5_pas` 的 DTB 固件在成功路径泄漏（D6 丢弃依据被推翻）

> 出处：`reports/m1-rebase-7.3rc7-execution-20261013.md` §4 **U6**（"若其原始目的在 7.3 的
> `qcom_pas_metadata_release` 路径下仍存在，需复核 diff"）+ §3 **D6**（当时丢弃理由 = "上游 release 路径取代"）。
> 本轮（2026-10-27）只做**静态复核**，产物 = 一枚上游补丁 `patches/upstream/m1-pas-dtbfw-20261027/`。
> 基线 = pristine `24a19b953`（7.3-rc7），**未上机**。

## §0 结论（数字）

| 项 | 结果 |
|---|---|
| D6 丢弃依据 | **不成立** —— 7.3-rc7 的 release 路径只释放**主固件**（`pas->firmware = NULL` 后由 rproc core 释放），DTB 固件在成功路径**无人释放** |
| 代码事实 | 全文件 **`release_firmware()` 仅 1 处**（第 256 行，`qcom_mdt_pas_load()` 失败分支）；`request_firmware()` 在第 245 行把指针存进 `pas->dtb_firmware`（结构体成员），成功路径不再触碰 |
| 后果 | 每次 `rproc_boot()` 泄漏一份 dtb 固件引用；第二次 boot 直接覆盖旧指针再泄漏一次（`adsp_dtb.mdt` / `cdsp_dtb.mdt`，容器/相机反复 reload 时会累积） |
| 7.2 血统树里的写法 | **本来就是正确写法**：`const struct firmware *dtb_firmware;` 局部变量 + `qcom_mdt_pas_load()` 之后**立即** `release_firmware()`（`git -C geekidos-linux show ba28ec16f0:drivers/remoteproc/qcom_q6v5_pas.c`），在机 7.2 内核上 adsp/cdsp 长期正常运行 |
| 补丁 | `0001-remoteproc-qcom_q6v5_pas-release-dtb-firmware.patch`（1 文件 / +5 −4）：把 dtb 固件作用域收进 `qcom_pas_load()`，加载后立即释放，删掉结构体成员 |
| 门禁 | `checkpatch --strict` **0 errors / 0 warnings / 0 checks**；`make drivers/remoteproc/` **rc=0 / 0 warning**（arm64 defconfig）；补丁**直接基于 pristine**提交，`git am` 天然干净 |
| 引入提交 | **定不到**：本地仓是部分克隆的浅边界（`git rev-list --count HEAD` = 4）⇒ 只陈述代码事实，不猜"是哪次回归" |
| 上机 | **未做**（见 §3 判据建议） |

## §1 证据链（可复跑）

```sh
# ① 全文件只有一处 release_firmware，且位于错误分支
$ git -C build/vk151 show 24a19b953:drivers/remoteproc/qcom_q6v5_pas.c \
    | grep -n "release_firmware\|request_firmware\|pas->firmware = NULL"
245:		ret = request_firmware(&pas->dtb_firmware, pas->dtb_firmware_name, pas->dev);
247:			dev_err(pas->dev, "request_firmware failed for %s: %d\n",
256:			release_firmware(pas->dtb_firmware);          ← 只在 ret != 0 分支
356:	pas->firmware = NULL;                                     ← 主固件：交还 rproc core
386:	pas->firmware = NULL;

# ② qcom_pas_start() 只需要 PAS context，不需要 firmware buffer
$ ... | sed -n '313,325p'
	if (pas->dtb_pas_id) {
		ret = qcom_pas_map_carveout(rproc, pas->dtb_mem_phys, pas->dtb_mem_size);
		ret = qcom_pas_prepare_and_auth_reset(pas->dtb_pas_ctx);   ← 仅 ctx

# ③ 同一驱动的 7.2 血统版本是「局部变量 + 立即释放」
$ git -C geekidos-linux show ba28ec16f0:drivers/remoteproc/qcom_q6v5_pas.c \
    | sed -n '/^static int qcom_pas_load/,/^}/p'
	const struct firmware *dtb_firmware;
		ret = qcom_mdt_pas_load(pas->dtb_pas_ctx, dtb_firmware, ...);
		release_firmware(dtb_firmware);        ← 成功/失败都释放
```

`qcom_mdt_pas_load()` 只做 MDT 段加载/映射与 reloc 计算，不接管 firmware 句柄的所有权
（同上两版本一致），因此"谁 request 谁 release"成立。

## §2 为什么这是"上游 bug"而不是"我们的本地件"

- 触发条件与机型无关：**任何**带 `dtb_firmware_name` 的 PAS 描述符（7.3-rc7 里 25 处，含 sc8280xp/
  sm8550/sm8650/x1e80100 全族）都会走到这条成功路径。
- 修复不引入策略件、不含魔数、不动 DT ⇒ 符合 `reports/upstream-policy-20261013.md` 的 A 类。
- 与 Q3（魔数/策略进包）无关；与 B5/Q28 的 DSI 一族无关 ⇒ **可独立投递**，不必等 camss/DSI 重构。

## §3 上机验证判据（未做，留给有设备的一轮）

静态判定已确凿（所有权链闭合），上机只有"量级证据"可加：

1. 重复 `rproc` 起停 10 次（`echo stop > /sys/class/remoteproc/remoteprocN/state` → `start`），
   对比修补前后 `dmesg | grep -c "request_firmware failed"` = 0 且 `slabinfo` 中
   `kmalloc-*`/`filp` 无单调增长；
2. 更硬的判据 = `CONFIG_DEBUG_KMEMLEAK` 打开后跑一次 `rproc_boot()`：修补前应报
   `qcom_pas_load` 的 `request_firmware` 分配点，修补后报点消失（需额外 config，属可选）。

## §4 对 §4 未决项台账的影响

- **U6 → 结项**（结论 = "确实仍存在，且是可上游的真 bug"，补丁已备）。
- **D6 → 从「丢弃登记」改为「应上游修复」**；`m1/clean-tree-7.3rc7` 若要保持"可上游"形态，应把本补丁
  合进 M1 树（而不是继续用 7.3 的泄漏版）。
- **U8 → 同时结项（事实核查）**：`CONFIG_FS_ENCRYPTION` 在 pristine arm64 defconfig、日常线 `build/vk151/.config`、
  设备在机三处**都不存在**（三处均只有 `BLK_INLINE_ENCRYPTION=y`；日常线另有 `F2FS_FS=y` 供 root）
  ⇒ 「vendor fscrypt ABI 只在 `FS_ENCRYPTION=y` 时编译」从"未知"变为"当前不编译"；将来若走加密 userdata
  （M5 候选 d `dm-inlinecrypt`）需**新加 config 片段**。
- 其余 U1/U2/U3/U4/U5/U7 状态不变（U9 全量编译已在后续轮次完成）。
