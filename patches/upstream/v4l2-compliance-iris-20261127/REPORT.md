# iris v4l2-compliance driver-quality 系列（**v1 已投 2026-11-27**，v2 只剩 1 贴，待发）

> **状态（2026-11-28 早更新）**：v1 **已于 2026-11-27T15:20Z 外发 4 封**（lore 归档见 `SENT.md`），**Bryan O'Donoghue 16:04Z 在 1/3 回帖要 `Fixes:` + `Cc: stable`**。
> 对 mainline 机械对账后：**1/3 = 已合入主线的重复**（`1facae9bc3c1`）、**3/3 = 被主线 s_fmt 重写取代**、**只 2/3 仍成立** ⇒ v2 = rebase 到 v7.4-rc3 的单贴
> `0002-v2-fill-default-colorspace.patch`（checkpatch 0/0/0、`git apply --check` OK、模块编译过），**投递被 keyring 锁阻** ⇒ 需用户登录后发，命令见 `reports/v4l2-compliance-v2-20261128.md` §4。
> **性质**：主机侧写补丁 + U2 上机实测。设备 = `ssh elden`，在机内核 `7.3.1-debug-vk189-suspend-g4da9a8b69fc8-dirty`；
> 承接前提 = 已 backport 上游 1222157（`patches/backport-iris-drc-1222157/`，解码已通）。

## 0. 与 1222157 是否重叠（任务书要求「先判」）

**逐条结论：不重叠。** 1222157 修的是「解码时首帧 DRC / PSC_LAST / START 序列」（功能性，解码成败），本系列全是 **v4l2 ABI 合规性**（colorspace 字段、bus_info 前缀、selection 矩形、控件），两批改的文件有交集（`iris_vdec.c`）但**没有一行重叠**。

grep 证据（对 `patches/backport-iris-drc-1222157/0001-combined-applied-on-4da9a8b6.patch`）：
`bus_info` 0 命中；`sel_crop`/`compose`/`s_selection`/`g_selection` 0 命中；`colorspace` 1 命中但只是 `iris_vdec_capture_fmt_unchanged()` 里的**比较**，不是设默认值；`MIN_BUFFERS` 3 命中是 `iris_vdec_update_min_capture_bufs()` **更新**已有控件，不创建；`reqbufs`/`EBUSY` 命中是 `iris_vdec_start_cmd` 的 EBUSY 门，不是 REQBUFS 语义。

## 1. 实测：改前 / 改后

`v4l2-compliance -d /dev/video17`（iris 解码节点）：

| | 结果 |
|---|---|
| 改前（backport 1222157 后，未动 v4l2 合规） | **39 过 / 9 败**（48 项） |
| 改后（本系列 3 贴） | **47 过 / 1 败**（48 项） |

（注：任务书 §6 记的「41 过 / 7 败」是 **backport 之前**的数；backport 让更多测试可跑，基数从 41→48。）

## 2. 逐条判据表（9 项）

| # | 失败（v4l2-test 位置） | 与我们改动的状态 | 处置 |
|---|---|---|---|
| 1 | `v4l2-compliance.cpp(669)` bus_info 前缀 `plat:` | **修好** | 贴 0001：`plat:` → `platform:` |
| 2 | `formats.cpp(414/537)` G_FMT `!colorspace` | **修好** | 贴 0002 |
| 3 | `formats.cpp(414/537)` TRY_FMT `!colorspace` | **修好** | 贴 0002 |
| 4 | `formats.cpp(414/537)` S_FMT `!colorspace`（且 S_FMT!=G_FMT） | **修好** | 贴 0002（含 S_FMT 归一化，保证幂等） |
| 5 | `formats.cpp(1617/1747)` Cropping width/height=0 | **修好** | 贴 0003（`inst->crop` 未 seed 时回退 CAPTURE 尺寸） |
| 6 | `formats.cpp(1769/1842)` Composing width/height=0 | **修好** | 同贴 0003（compose 与 crop 同源 `inst->crop`） |
| 7 | `buffers.cpp(788)` `q2.reqbufs != EBUSY` | **修好（非补丁）** | backport 1222157 的 `iris_vdec_start_cmd` EBUSY 门 + `vb2_start_streaming_called()` 改动已使该语义正确；本系列无需再动（复核：现在 `REQBUFS/CREATE_BUFS/QUERYBUF: OK`） |
| 8 | `controls.cpp(1180)` 缺 `V4L2_CID_MIN_BUFFERS_FOR_CAPTURE`（表现为 `VIDIOC_(UN)SUBSCRIBE_EVENT` FAIL） | **未修** | 见 §3（控件其实存在于 `/dev/video17`，但 compliance 的 event 子测试找不到，需更细定位；**不臆造补丁**） |

> #7 的「修好」是 backport 的副产物，不算本系列功劳，报告里如实写。

## 3. 唯一残留（诚实登记，不凑数）

`V4L2_CID_MIN_BUFFERS_FOR_CAPTURE` **确实注册了**：`v4l2-ctl --list-ctrls` 可见
`min_number_of_capture_buffers 0x00980927 (int) : min=1 max=32 step=1 default=4 value=4 flags=read-only, has-min-max`（`iris_ctrls.c:401` 创建）。
但 `v4l2-compliance` 的 `v4l2-test-controls.cpp(1180)` 在 **SUBSCRIBE_EVENT/DQEVENT** 子测试里 `node->controls.find(...) == end()` 判它「不在」。可能原因（**未定论**）：① 该控件是 `read-only`，compliance 用于「可订阅事件」的控件集合排除了只读项；② `v4l2_fh` 的 ctrl_handler 与 per-instance handler 的挂接方式使该 std 控件未进 event 枚举路径。**要修得先在设备上打点确认是 ① 还是 ②，本轮不下结论、不写补丁。**

## 4. 产物

| 文件 | 内容 | 自检 |
|---|---|---|
| `0001-media-iris-report-a-platform-bus_info-prefix.patch` | bus_info 前缀 | `patch -p1 --fuzz=0` OK |
| `0002-media-iris-fill-in-a-default-colorspace-for-decoded-formats.patch` | colorspace 默认 + S_FMT 归一 | OK |
| `0003-media-iris-seed-the-crop-rectangle-when-only-CAPTURE-is-formatted.patch` | crop/compose seed | OK |
| `SEND.sh` | 默认 dry-run，`--send` 才发（linux-media + linux-arm-msm），硬拒绝重复发送 | — |

- **三贴顺序应用**在「backport 后的树」上 `--fuzz=0` 全过，最终逐字节 == 当前树（已复核 `diff -q` 全等）。
- **编译**：`make M=drivers/media/platform/qcom/iris modules` 通过；部署后解码功能**未回归**（H.264/HEVC 各 `frame=90`、framemd5 与软解 0 不一致）。
- 源码树当前状态 = **backport 1222157 + 本系列 3 贴**（都在 `drivers/media/platform/qcom/iris/`；`git checkout -- drivers/media/platform/qcom/iris/` 一键全撤）。

## 5. 发信前须知

- `Signed-off-by:` 是占位 `Elden Upstream <upstream@example.invalid>`，**发前必须换成真实作者**。
- 0002 的「默认 BT.709」是有主观选择的一贴（解码器本应在解析首帧后填真实 colorspace）；维护者可能要求改成「随 SOURCE_CHANGE 更新」，需准备好回应。**这正是它该做成 RFC/单贴先问、而不是直接当 fix 塞的理由。**
- 真发信走 `patches/upstream/` 的既有惯例（`git send-email` / USTC 通道，见技能 `upstream-mail-ustc`），本文件不代替投递。
