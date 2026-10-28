# #463 依赖性系列投递前必须先在 pristine 上 `git am`；「搬移类」提交要按行多重集判

## 结论（2026-10-28，B5/M6 第 5 步收尾，lane L2b 设备无关复核）

**B5 6 枚补丁在本树全绿，但对 pristine `24a19b953`（7.3-rc7）`git am` = 0/6**：

- 第 1 枚即冲突（`dsi_manager.c:30`）；`git apply --check` 也只有 **1/6**（0002 纯追加）。
- 缺依赖清单（可复跑，`pristine-missing-deps-curated.log`）：
  11 个符号（`msm_dsi_host_bonded_{cmd_arm_master,cmd_build,cmd_init_trigger,cmd_poll_slave,cmd_stage,cmd_trigger,cmd_wait_master,xfer_prepare,xfer_restore}`、
  `msm_dsi_manager_cmd_failed`、`dsi_mgr_bonded_cmd_xfer`）+ `struct msm_dsi_manager.is_sm8750` 字段
  + 5 组 `dsi.xml` 寄存器定义 ⇒ 全部来自日常线 bonded 载荷提交 `0f1fb1c9c`。
- ⇒ **必须在投递前把「前置系列」拆出来先发**（否则 reviewer 无法 apply，等于不可评审）。

**「行为中性搬移」不能靠自述**，用行多重集 + 目标文件/节区比对：

| 提交 | 判据 | 结果 |
|---|---|---|
| 0001 | 函数数 93→93、`.bss` 32→24 B、指令 −16、`WRITE_ONCE`/`READ_ONCE`/锁/`dsi_write` 全 ±0 | **纯搬移（已证）** |
| 0002 | `dsi_manager.o`/`dsi_host.o` section 逐字节不变、93/93 函数指令数不变 | **纯数据追加（已证）** |
| 0003 | `-`/`+` 行多重集：删 87 / 增 139 / **原样复用仅 28 行** | **不是纯搬移** ⇒ 措辞必须改，或拆 3 枚 |

## 教训

- 「`git apply` 能落」≠「上游能 review」；`git am` 到 pristine 才是投递门槛。
- 同一轮还踩到：`make -B` 会毁 `build/*/.config`（见 #447）；全量 `make Image.gz dtbs` 才是硬门（局部目录编译只算烟雾）。
