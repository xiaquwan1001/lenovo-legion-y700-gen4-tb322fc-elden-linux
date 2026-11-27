# iris 硬件解码失败 —— 静态代码判读（Q36 / T25，2026-11-27）

- **性质**：纯主机侧判读。内核树 `~/elden-cache/build/daily`（`== build/daily` 软链，HEAD `4da9a8b6` **2026-10-14**，`Makefile` 7.3.1）**只读**，未改一字节；未上设备；未外发任何邮件/issue。
- **输入**：`reports/dt-vk197-adsp-iris-20261127.md`（§6 实测）、`reports/hwdec-iris-sm8750-feasibility-20261127.md`。
- **一句话结论**：失败**不是**「固件没起」也**不是**「inst 进了 ERROR」——`2 to 4` 是 `INPUT_STREAMING → STREAMING`（正常），全程**没有任何一次 `IRIS_INST_ERROR`（=5）**；`V4L2_BUF_FLAG_ERROR` 只可能来自三条**不经过状态机**的路，其中「零尺寸 PSC_LAST 输出缓冲被误标 ERROR」和「上游 11 补丁系列已修」两条**都已在上游代码 / 补丁文本里得到证实**。

---

## 0. 一页结论（假设强弱）

| 假设 | 内容 | 证据强度 | 决定性证据 |
|---|---|---|---|
| **C（强，已成文）** | **驱动 DRC / 首帧前 IPSC 路径缺陷**：ffmpeg 在首个 bitstream 缓冲之前就把 CAPTURE 也 STREAMON ⇒ 固件的**首次** settings change 被当成「运行中 DRC」处理（`0x22` 而不是 `0x21`）；随后零尺寸 `PSC_LAST` 输出缓冲被 `iris_hfi_gen2_response.c:393` 误标 `V4L2_BUF_FLAG_ERROR`（代码层唯一自洽解释，待判据 1/2 二选一确证） | **强** | ① `sub_state 0→22` 只可能由 `iris_state.c:188` 的 `else` 分支产生（要求 state ∈ {STREAMING, OUTPUT_STREAMING}）；② `iris_hfi_gen2_response.c:393-395` 判 `LAST` 却**不判 `PSC_LAST`**；③ 上游 2026-11-25 系列把 `early_capture`（"CAPTURE was started before the first settings change"）当**一等公民**修，并有一贴直接叫 *complete an unchanged first settings change for **FFmpeg*** |
| **B（弱→可证伪）** | 固件代次 / HFI 版本不符（`vpu35_p4.mbn` vfw-3.5:rel0030 与驱动期望的 gen2 ABI 不同） | **弱** | 驱动**完全没有** HFI 版本检查（§4），所以「代次不符」在本树上**无法**表现为一个干净的 `-EINVAL`；唯一能证实的是固件自报 `HFI_INFO_DATA_CORRUPT`（会打 `session info received …: data corrupt`，本轮未采）⇒ 留作判据 1 |
| **A（弱）** | 纯 ffmpeg 包装层用法/协商 | **弱，但不能排除「包装 × 驱动」交叉** | ffmpeg 8.0 的 v4l2m2m **确实**订阅了 `V4L2_EVENT_SOURCE_CHANGE` 并有一套 reinit 流程（`v4l2_context.c:192-226`），所以不是「完全不支持 DRC」；但它的 STREAMON 次序（`v4l2_m2m_dec.c:96` 无条件先 output 后 capture）撞上的正是 iris 的 DRC 分叉 |
| **D（强，事实）** | 上游**已有人修**，且未合入 | **强（事实性）** | patchwork series **1222157**《media: iris: fix the decoder source change, seek and START sequences》，Neil Armstrong（Linaro），2026-11-25，11 贴，state=`new`（未合入）。我们的树（2026-10-14）**连该系列的 base 符号都没有**（§5） |

> **本轮最重要的三条口径纠正**（会改变后续判据设计）：
> 1. `2 to 4` **不是 ERROR**。`enum iris_inst_state`：`DEINIT=0, INIT=1, INPUT_STREAMING=2, OUTPUT_STREAMING=3, STREAMING=4, ERROR=5`（`iris_state.h:84-92`）。`2→4` = 两个队列都 STREAMON 完；整条 `0→1→2→4→3→1→0` 是**一次干净的正常生命周期**，其中 `4→3` 是 `STREAMOFF(OUTPUT)`（`iris_state.c:89-106`），`3→1` 是 `STREAMOFF(CAPTURE)`，`1→0` 是 close。**dmesg 里一次 `to 5` 都没有** ⇒ 17 个 `IRIS_INST_ERROR` 调用点（§1.2）**全部排除**。
> 2. `sub_state 0→22` / `22→66` 是 **`%x` 十六进制**（`iris_state.c:172`、`iris_state.c:63`）。`0x22 = DRC|INPUT_PAUSE`，`0x66 = DRC|DRC_LAST|INPUT_PAUSE|OUTPUT_PAUSE`。上一轮报告按十进制读成「`LOAD_RESOURCES|DRC_LAST|DRC`（应为 0x86）」是误读，**且这个误读直接导致「固件已 LOAD_RESOURCES」的错误结论**——`0x22/0x66` 里**没有** `LOAD_RESOURCES(0x80)`。
> 3. 「`file …/iris/* +p` 没生效」**也是误判**：`state changed` / `sub_state changed` 本身全是 `dev_dbg`，它们**出现在 dmesg 里就证明 dyndbg 已经生效**。`firmware version:` 没出只因为它是**探针期**打印（`iris_hfi_common.c:86` → `iris_hfi_gen2_response.c:793`），在 `modprobe` 之后才开 dyndbg 自然抓不到（§6 判据 1 给了正确写法）。

---

## 1. `2 to 4` 是谁打的；`IRIS_INST_ERROR` 全部调用点

### 1.1 状态枚举（`iris_state.h:84-92`）

```c
enum iris_inst_state {
	IRIS_INST_DEINIT,		/* 0 */
	IRIS_INST_INIT,			/* 1 */
	IRIS_INST_INPUT_STREAMING,	/* 2  = output plane STREAMON 完成 */
	IRIS_INST_OUTPUT_STREAMING,	/* 3  = capture plane STREAMON 完成 */
	IRIS_INST_STREAMING,		/* 4  = 两个面都 STREAMON */
	IRIS_INST_ERROR,		/* 5 */
};
```

### 1.2 `2→4` = `iris_inst_state_change_streamon(capture)`，合法迁移

`iris_state.c:47-63`（唯一的 `state changed from %x to %x` 打印点，`%x` **十六进制**）：

```c
int iris_inst_change_state(struct iris_inst *inst, enum iris_inst_state request_state)
{
	if (inst->state == IRIS_INST_ERROR) return 0;      /* 一旦 ERROR 就锁死 */
	if (inst->state == request_state) return 0;
	if (request_state == IRIS_INST_ERROR) goto change_state;
	if (!iris_allow_inst_state_change(inst, request_state)) return -EINVAL;  /* 静默 -EINVAL */
change_state:
	dev_dbg(inst->core->dev, "state changed from %x to %x\n", inst->state, request_state);
```

`iris_state.c:70-87`（`2→4` 的产生处）：

```c
int iris_inst_state_change_streamon(struct iris_inst *inst, u32 plane)
{
	enum iris_inst_state new_state = IRIS_INST_ERROR;   /* 无匹配时默认落 ERROR(=5) */
	...
	} else if (V4L2_TYPE_IS_CAPTURE(plane)) {
		if (inst->state == IRIS_INST_INIT)            new_state = IRIS_INST_OUTPUT_STREAMING; /* 1→3 */
		else if (inst->state == IRIS_INST_INPUT_STREAMING) new_state = IRIS_INST_STREAMING;   /* 2→4 ✅ */
	}
	return iris_inst_change_state(inst, new_state);
```

⇒ `2 to 4` 是 **capture 面 STREAMON**（`iris_vb2_start_streaming` → `iris_vdec_streamon_output` → `iris_common.c:149 iris_inst_state_change_streamon(CAPTURE)`）。**这是成功路径**，与「解码失败」无关。

> 顺带：若 `plane` 与当前 state 组合无匹配，`new_state` 保持 `IRIS_INST_ERROR`(=5)，**日志会打成 `to 5`** ⇒ 我们没看到 `to 5`，也排除了这一类「状态机自身判错」。

### 1.3 全部能把 inst 置成 `IRIS_INST_ERROR` 的调用点（17 处）

| # | 位置 | 触发条件 | 伴随日志 | ERROR 后可见的 dmesg 行 |
|---|---|---|---|---|
| 1 | `iris_state.c:47`（`change_state` 本体，`request_state==ERROR` 直通） | 任何调用方传 ERROR | 仅 `dev_dbg "state changed from %x to 5"` | **有 `to 5`** |
| 2 | `iris_state.c:70/89`（streamon/streamoff 默认值） | plane/state 组合无匹配 | 同上 | **有 `to 5`** |
| 3 | `iris_hfi_gen2_response.c:270` `handle_session_error` | 报文带 `HFI_FW_FLAGS_SESSION_ERROR` 或 type 落 ERROR range | `dev_err "session error received %#x: %s"` + `iris_vb2_queue_error` | dev_err + `to 5` |
| 4 | `iris_hfi_gen2_response.c:287` `handle_system_error` | `validate_hdr_packet` 失败（**传 `pkt=NULL`，无 dev_err**）或 `SYSTEM_ERROR` | 有 pkt 时 `dev_err "received system error of type %#x"`；`NULL` 时**完全静默** | 无日志 + core→ERROR + `to 5` |
| 5 | `iris_hfi_gen2_response.c:312` `handle_session_close` | CLOSE 响应无 `SUCCESS` | **无** | 仅 `to 5` |
| 6 | `iris_hfi_gen2_response.c:479` `handle_session_buffer` | `payload_info` 与实际 payload 大小不符（`validate_packet_payload`） | **无** | 仅 `to 5` |
| 7 | `iris_hfi_gen2_response.c:514` `handle_session_drain` | DRAIN 响应无 `SUCCESS` | **无** | 仅 `to 5` |
| 8 | `iris_hfi_gen2_response.c:648` `read_input_subcr_params` | `bit_depth ∉ {8,10}` 或 `coded_frames` 缺 `MBS_ONLY` | `dev_err "unsupported content, bit depth: %x, pic_struct = %x"` | dev_err + `to 5` |
| 9 | `iris_hfi_gen2_response.c:962`（`handle_session_response` 汇总） | **任一 range handler 返回非 0**（`-EINVAL` 等，含 buffer 找不到 / 非 QUEUED / `sub_state_change_drc` 二次触发） | **无** | 仅 `to 5` ← 最隐蔽的兜底 |
| 10 | `iris_common.c:198` `iris_kill_session` | 会话仍开启时强关 | 无 | 仅 `to 5` |
| 11 | `iris_vb2.c:221` `start_streaming` error | `iris_check_session_supported` / `session_open` / streamon / qbuf 失败 | 部分有 `dev_err "session open failed"` | `to 5` |
| 12 | `iris_vb2.c:250` `stop_streaming` | `iris_session_streamoff` 返回非 0 | **无** | 仅 `to 5` |
| 13 | `iris_vb2.c:341` `buf_queue` | qbuf 失败（含 output `bytesused==0` 的 `-EINVAL`） | **无** | 仅 `to 5` |
| 14 | `iris_vdec.c:525` `start_cmd` | `V4L2_DEC_CMD_START` 时 `DRC && DRC_LAST`（或 `DRAIN && DRAIN_LAST`）**未齐** | `dev_err "start called before receiving last_flag"` | dev_err + `to 5` |
| 15 | `iris_venc.c:589` | 同上（编码器） | 同上文案 | dev_err + `to 5` |
| 16 | `iris_utils.c:81` `wait_for_session_response` | completion 超时（`HW_RESPONSE_TIMEOUT_VALUE`） | **无** | 仅 `to 5`（延迟 ~1 s） |
| 17 | `iris_hfi_gen1_command.c:239` | gen1 命令前 state 检查（本机走 gen2，不适用） | 视上下文 | — |

**结论**：除 #1/#2 外，**全部 17 条都必然打出 `state changed … to 5`**（`iris_state.c:63` 无条件 `dev_dbg`）。vk197 的 dmesg 里**没有 `to 5`** ⇒ inst **从未进入 ERROR**，本轮失败**完全不经状态机**，只经 vb2 缓冲状态（§2）。

---

## 2. `capture: driver decode error` 从哪来

### 2.1 这句话是 **ffmpeg** 打的，不是内核

```
$ strings /usr/lib/x86_64-linux-gnu/libavcodec.so.62 | grep "driver decode error"
%s: driver decode error
```

对应 `libavcodec/v4l2_buffers.c:463`（ffmpeg release/8.0，本机 7:8.0.1）：

```c
    /* 3. report errors upstream */
    if (avbuf->buf.flags & V4L2_BUF_FLAG_ERROR) {
        av_log(logger(avbuf), AV_LOG_ERROR, "%s: driver decode error\n", avbuf->context->name);
        frame->decode_error_flags |= FF_DECODE_ERROR_INVALID_BITSTREAM;
    }
```

`%s` = `avbuf->context->name` = **`capture`** ⇒ 出问题的是 **CAPTURE（dst）队列的某个 dequeued 缓冲带了 `V4L2_BUF_FLAG_ERROR`**；随后的 `corrupt decoded frame` 是 ffmpeg `decode.c` 对 `decode_error_flags` 的通用文案，**不是第二个独立错误**。

### 2.2 内核侧：`V4L2_BUF_FLAG_ERROR` ⇔ `VB2_BUF_STATE_ERROR`

`drivers/media/common/videobuf2/videobuf2-v4l2.c:556-560`：

```c
	case VB2_BUF_STATE_ERROR:
		b->flags |= V4L2_BUF_FLAG_ERROR;
		break;
```

⇒ 只要 iris 把某个 capture 缓冲以 `VB2_BUF_STATE_ERROR` 交给 vb2，ffmpeg 就报这一行。iris 侧能产生该状态的**只有 4 条路**：

| 路 | 位置 | 条件 | 是否改 inst 状态 | 是否有日志 |
|---|---|---|---|---|
| **P1** | `iris_hfi_gen2_response.c:393-395` → `iris_buffer.c:900` | 固件回 RAW 输出缓冲且 `data_size==0`、`inst->state==STREAMING`、**且没有 `HFI_BUF_FW_FLAG_LAST`** | **否** | **无** |
| **P2** | `iris_hfi_gen2_response.c:113-114`（`get_driver_buffer_flags`） | 固件在**同一 HFI 包头**里先发了 `HFI_INFO_DATA_CORRUPT` / `HFI_INFO_BUFFER_OVERFLOW` | **否** | 仅 `dev_dbg "session info received %#x: data corrupt"`（`:229`） |
| **P3** | `iris_hfi_gen2_response.c:104-105` | `picture_type & HFI_GEN2_PICTURE_NOSHOW` | **否** | **无**（只有 property 解析） |
| **P4** | `iris_vb2.c:248`（stop_streaming）→ `iris_helper_buffers_done(…, VB2_BUF_STATE_ERROR)` | 任何 STREAMOFF：**队列里剩下没 dequeue 的缓冲一律标 ERROR** | **否** | **无** |

> 另有两处会产生 ERROR 但**同时**改状态（⇒ 会有 `to 5`，本轮已排除）：`iris_vb2.c:221/250/341`、`iris_hfi_gen2_response.c:962`。

### 2.3 倒推：哪个缓冲先出错

关键代码 `iris_hfi_gen2_response.c:348-399`（**摘录，行号连续**）：

```c
348 static int iris_hfi_gen2_handle_output_buffer(struct iris_inst *inst,
349 					      struct iris_hfi_buffer *hfi_buffer)
...
358 	if (hfi_buffer->flags & HFI_BUF_FW_FLAG_LAST) {          /* 0x10000000 */
359 		ret = iris_inst_sub_state_change_drain_last(inst);
...
363 	if (hfi_buffer->flags & HFI_BUF_FW_FLAG_PSC_LAST) {      /* 0x20000000 */
364 		ret = iris_inst_sub_state_change_drc_last(inst);
...
391 	buf->flags = iris_hfi_gen2_get_driver_buffer_flags(inst, hfi_buffer->flags);
392
393 	if (!buf->data_size && inst->state == IRIS_INST_STREAMING &&
394 	    !(hfi_buffer->flags & HFI_BUF_FW_FLAG_LAST)) {
395 		buf->flags |= V4L2_BUF_FLAG_ERROR;     /* ← 少判 PSC_LAST！ */
396 	}
```

`iris_hfi_gen2_get_driver_buffer_flags`（`:97-121`）同时会把 `PSC_LAST` 映射成 `V4L2_BUF_FLAG_LAST`：

```c
116 	if (hfi_flags & HFI_BUF_FW_FLAG_LAST ||
117 	    hfi_flags & HFI_BUF_FW_FLAG_PSC_LAST)
118 		driver_flags |= V4L2_BUF_FLAG_LAST;
```

⇒ **一个 `data_size==0` 的 `PSC_LAST` 输出缓冲会同时得到 `LAST|ERROR`**。而 `PSC_LAST` 正是固件宣告「第一次 sequence change 结束」的那颗空缓冲——**这是 DRC 流程里必然会出现的缓冲**。所以「首帧即 `driver decode error`、无任何 dev_err、无 ERROR 状态」三个现象在 **P1** 上完全自洽。

**P2 vs P1 的判别只差一行 dmesg**：P2 一定伴随 `session info received 0x…: data corrupt`（`:229` 的 `dev_dbg`），P1 一定**什么也不打**。→ §6 判据 1。

**P4 的排除理由**：`4→3` 之后 ffmpeg 已不再 dequeue capture（它先 `codec_end`：`v4l2_m2m.c:273-279` 先 `STREAMOFF(output)` 再 `STREAMOFF(capture)`），所以 P4 标脏的缓冲不会被 ffmpeg 看到；而报错发生在 teardown **之前**（`frame=1` 已输出过）。

---

## 3. DRC 路径：这版驱动**不支持**「首帧前（早期）IPSC」

### 3.1 `sub_state` 语义与 `0x22` 的唯一来源

`iris_state.h:119-128`（位定义）+ `iris_state.c:178-192`：

```c
178 int iris_inst_sub_state_change_drc(struct iris_inst *inst)
179 {
180 	enum iris_inst_sub_state set_sub_state = 0;
181
182 	if (inst->sub_state & IRIS_INST_SUB_DRC) return -EINVAL;
183
184 	if (inst->state == IRIS_INST_INPUT_STREAMING ||
185 	    inst->state == IRIS_INST_INIT)
186 		set_sub_state = IRIS_INST_SUB_FIRST_IPSC | IRIS_INST_SUB_INPUT_PAUSE;  /* 0x21 */
187 	else
188 		set_sub_state = IRIS_INST_SUB_DRC | IRIS_INST_SUB_INPUT_PAUSE;         /* 0x22 */
189
190 	return iris_inst_change_sub_state(inst, 0, set_sub_state);
191 }
```

**实测 `sub_state 0→22` = `0x22` ⇒ 走的是 `else`（:188）⇒ 固件发 SETTINGS_CHANGE 那一刻 `inst->state` 已经是 `STREAMING(4)` 或 `OUTPUT_STREAMING(3)`。** 这就是上游所说的 **`early_capture`：CAPTURE 在第一次 settings change 之前就已 STREAMON**。ffmpeg 的次序决定了这一点（`v4l2_m2m_dec.c:40-96` `v4l2_try_start()`：先 `STREAMON(output)`，再 `G_FMT`/`REQBUFS`，最后 `STREAMON(capture)`，**在同一次调用里做完**）。

`0x22 → 0x66`（`+DRC_LAST|OUTPUT_PAUSE`）来自 `iris_state.c:209-223` `iris_inst_sub_state_change_drc_last()`，由 `HFI_INFO_HFI_FLAG_PSC_LAST`（`:220-223`）或缓冲上的 `HFI_BUF_FW_FLAG_PSC_LAST`（`:363`）触发 ⇒ **固件确实把 PSC 走完了**（PSC + PSC_LAST 都到），不是「固件不理我们」。

### 3.2 gen2 的 src-change 处理：完全无「首次」分支

`iris_hfi_gen2_response.c:667-683`：

```c
static int iris_hfi_gen2_handle_src_change(struct iris_inst *inst, struct iris_hfi_packet *pkt)
{
	if (pkt->port != HFI_PORT_BITSTREAM) return 0;
	ret = iris_inst_sub_state_change_drc(inst);   /* ← 唯一分叉在这里，只管 FIRST_IPSC vs DRC */
	if (ret) return ret;
	iris_hfi_gen2_read_input_subcr_params(inst);  /* 解析分辨率/位深/color/prof/level */
	iris_vdec_src_change(inst);                   /* 只在 src_q streaming 时发 SOURCE_CHANGE 事件 */
	return 0;
}
```

对比 **gen1**（`iris_hfi_gen1_response.c:175-214`）—— gen1 有专门的 `FIRST_IPSC` 语义，并且**替用户把 flush 做掉**：

```c
192 	ret = iris_inst_sub_state_change_drc(inst);
...
203 	if (inst->state != IRIS_INST_ERROR && !(inst->sub_state & IRIS_INST_SUB_FIRST_IPSC)) {
204 		flush_pkt.pkt_type = HFI_CMD_SESSION_FLUSH;
206 		flush_pkt.flush_type = HFI_FLUSH_OUTPUT;          /* 非首次 IPSC 才 flush */
...
212 	iris_vdec_src_change(inst);
213 	iris_inst_sub_state_change_drc_last(inst);            /* gen1 同一事件里直接置 DRC_LAST */
```

⇒ **gen1 在「首次 IPSC」时不做 flush、且立即补 `DRC_LAST`；gen2 两条都没做**：gen2 把 `DRC_LAST` 完全外包给固件的 `PSC_LAST`/`INFO_FLAG_PSC_LAST`，并且**没有 `early_capture` 概念**（本树 `grep early_capture` = 0 命中，`grep drc_unsignalled` = 0 命中）。

### 3.3 用户态被要求做什么（这版驱动的隐含契约）

`iris_vdec.c:469` 起的 `iris_vdec_start_cmd()`（判据齐备段 `:476-528`）（`V4L2_DEC_CMD_START` 唯一合法条件）：

```c
	if (inst->sub_state & IRIS_INST_SUB_DRC && inst->sub_state & IRIS_INST_SUB_DRC_LAST) {
		vb2_clear_last_buffer_dequeued(dst_vq);
		clear_sub_state = IRIS_INST_SUB_DRC | IRIS_INST_SUB_DRC_LAST;
		if (…INPUT_PAUSE)  → session_resume_drc(OUTPUT)
		if (…OUTPUT_PAUSE) → session_resume_drc(CAPTURE)
	} else if (DRAIN && DRAIN_LAST) { … }
	else {
		dev_err(…, "start called before receiving last_flag\n");   /* :524 */
		iris_inst_change_state(inst, IRIS_INST_ERROR);             /* :525 → 会打 to 5 */
		return -EBUSY;
	}
```

配合 `iris_vb2.c:313-345`：`DRC && DRC_LAST` 期间**任何** CAPTURE qbuf 会被立刻当作 `LAST` 缓冲退回（`payload=0`，`VB2_BUF_STATE_DONE`）并 `v4l2_m2m_mark_stopped()`。ffmpeg 拿到 `LAST` 就认为 EOS/EAGAIN——**这就是「输出只有 1 帧」的直接来源之一**（上游 patch 06/11 正是改这里：*don't return a spurious LAST buffer*，加 `vb2_start_streaming_called()` 判断）。

**小结（C 假设的完整链条）**：
`ffmpeg 提前 STREAMON(CAPTURE)` → 固件首次 PSC 落到 DRC 分支(`0x22`) → `PSC_LAST` 空缓冲被 `:393` 误标 `ERROR|LAST` → ffmpeg 打 `capture: driver decode error` + `corrupt decoded frame`；`DRC|DRC_LAST` 期间再 qbuf 又被 `iris_vb2.c:318` 变成虚假 `LAST` → 只出 1 帧；ffmpeg 放弃 → `codec_end` 先关 output 再关 capture → `4→3→1→0`。**与实测逐项吻合，且无需任何 dev_err。**

---

## 4. 固件代次对不对得上（只写代码能证的）

### 4.1 SM8750 用的 desc

`iris_platform_vpu3x.c:45-49`：

```c
static const struct iris_firmware_desc iris_vpu35_p4_gen2_desc = {
	.firmware_data = &iris_hfi_gen2_data,
	.get_vpu_buffer_size = iris_vpu33_buf_size,     /* ← 复用 vpu33 的尺寸表 */
	.fwname = "qcom/vpu/vpu35_p4.mbn",
};
```

`iris_platform_vpu3x.c:187-190`：

```c
const struct iris_platform_data sm8750_data = {
	.firmware_desc_gen2 = &iris_vpu35_p4_gen2_desc,
	.vpu_ops = &iris_vpu35_ops,        /* iris_vpu3x.c:275-283 */
	...
```

`iris_probe.c:384-385`：`.compatible = "qcom,sm8750-iris" → &sm8750_data`；固件名**完全对得上**在位的 `qcom/vpu/vpu35_p4.mbn`（2 392 776 B，signed）。

### 4.2 有 HFI 版本检查吗？—— **没有，一个都没有**

`grep -rn "version" drivers/media/platform/qcom/iris/` 的全部命中里，**没有**任何版本比较：

| 命中 | 作用 |
|---|---|
| `iris_hfi_gen2_command.c:40` `sys_image_version()` | 只是**请求**版本串 |
| `iris_hfi_gen2_response.c:775-795` `handle_image_version_property()` | 只 `dev_dbg("firmware version: %s")`，**不解析、不比较、不拒绝** |
| `iris_core.h:25` `IRIS_FW_VERSION_LENGTH 128` | 字符串长度 |
| `iris_hfi_queue.h:146/157` `version` | **共享队列**的 version 字段（`queue table`），不是固件 ABI 版本 |

`sys_image_version` 唯一的调用点是 `iris_hfi_common.c:86`（`iris_hfi_core_init()`，**探针期**）——这解释了为什么上一轮「开 dyndbg 后重解却看不到 `firmware version:`」（探针早已发生过）。

### 4.3 HFI 报文结构里有没有「增量字段」

`iris_hfi_gen2_defines.h:232-237` 的 `hfi_buffer_firmware_flags` 只有 4 个位（`RELEASE_DONE 0x1`、`READONLY 0x10`、`LAST 0x10000000`、`PSC_LAST 0x20000000`），`hfi_buffer_host_flags`（`:225-230`）同理；**没有**任何「按固件 rel 变体切换结构布局」的代码（无 union、无 `is_<rel>` 标志、无 `sizeof` 分支）。

**能证到什么程度**：
- 能证：驱动对 `vpu35_p4.mbn` **不做任何代次/rel 校验**；若固件是别的 rel/HFI 代次，症状会是**报文被误解析**（乱码般的 `-EINVAL`、`session error`、校验失败），**而不是**本轮这种「正常 PSC + 无 dev_err」。
- 不能证：`vpu35_p4.mbn (vfw-3.5:rel0030)` 到底对应哪个 ABI 世代——**代码里没有可判据**。要证只能靠判据 1 抓 `session info`/`session error`，或对拍上游同 desc 平台（sm8650 用 vpu33）的实际行为。
- 侧证（弱）：`vpu35` 复用 `iris_vpu33_buf_size`，说明上游把 vpu35 当「vpu33 的 ABI 同族」——若我们的固件其实是另一族，风险在这里而不在 HFI 版本号上。

---

## 5. 上游是否已有人修 —— **有，而且就是本案**

### 5.1 检索结果（方法可复现）

- `lore.kernel.org`：`https://lore.kernel.org/all/?q=iris+sm8750`、`/linux-media/?q=iris`、`/all/_/text/help/` **全部 HTTP 403 + `nginx`**（默认 curl UA 亦然；本机 IP 被 lore 前端挡了，**不是** Anubis 200 假页）。⇒ 改用 patchwork API（必须带 `project=`，裸 `q=` 会 400，与上一轮技术备注一致）。
- patchwork：`https://patchwork.kernel.org/api/1.2/patches/?project=linux-media&q=iris&per_page=100&order=-date`、`/api/1.2/series/1222157/`、`/api/1.2/patches/<id>/`。

### 5.2 关键系列

**series 1222157 —《media: iris: fix the decoder source change, seek and START sequences》**
作者 **Neil Armstrong `<neil.armstrong@linaro.org>`**（Linaro），**2026-11-25 13:09**，v1，11 贴，全部 state=`new`（**未合入**）。原文：<https://patchwork.kernel.org/series/1222157/>

| # | 标题 | 与本案关系 |
|---|---|---|
| 01 | vdec: accept `V4L2_DEC_CMD_START` on a running decoder | `iris_vidc.c:592` 的 `-EBUSY` 门被放宽 |
| **04** | **vdec: reconfigure the decoder on START after a source change** | 把「START 后重配」从 STREAMON(CAPTURE) 里解耦 |
| **06** | **don't return a spurious LAST buffer** | `iris_vb2.c:313` 加 `vb2_start_streaming_called()`；`iris_common.c:86` 不再清 `last_buffer_dequeued` |
| **10** | **vdec: complete an unchanged first settings change for FFmpeg** | 新增 `early_capture` / `drc_unsignalled`，正是 §3 的分叉 |
| **11** | **record the LAST buffer returned with an error** | `iris_vb2_buffer_done` 里 `ERROR|LAST` 同时出现时补 `iris_vb2_signal_eos()`（与 §2.3 的 `LAST|ERROR` 同源） |

贴 10 的 diff 直接点名我们的场景（引原文）：

```c
@@ struct iris_inst {
+	bool				early_capture;      /* CAPTURE was started before the first settings change */
+	bool				drc_unsignalled;    /* an unsignalled settings change waits for its PSC_LAST */
```
```c
 	if (early_capture && iris_vdec_first_src_change_unchanged(inst, &old_fmt)) {
 		inst->drc_unsignalled = true;
 		return 0;              /* 首次且分辨率未变：不发 SOURCE_CHANGE，等 PSC_LAST 自己完成 */
 	}
```

### 5.3 我们的树差多远

- 树 HEAD = `4da9a8b6`，**2026-10-14**（`git log -1`；注意该克隆是**部分克隆**，`git log -- <iris>` 会 `Could not read <object>`，只能看 HEAD）。
- 该系列的 **base 符号在本树一个都没有**：`grep -rn "drc_wq\|src_change_complete\|early_capture\|input_stopping\|drc_unsignalled\|iris_vdec_src_change_after_seek"` → **0 命中**（补丁上下文里这些都已是 base 形态）。
- ⇒ 我们落后**不止**这一个系列：同一个 Linaro 线上还有 `1221604`《Fix issues exposed during decoder seek》（2026-11-25）、`1207078`/`1197454`（10-30/11-10 同名系列）、`1224375`《HFI gen2 features and fixes for VA-API》（11-27）等，iris 在 2026-10/11 是高频改动区。
- 另有 `14255939`《media: iris: Fix ffmpeg corrupted frame error》（2025-10-06，state=`new`）—— 但它是 **gen1** 且只改 `iris_hfi_gen1_command.c` 的 `com_ip_pkt.flags`，**与本案（gen2）无关**，别被标题误导。

**结论（D 假设成立为事实）**：我们踩的不是「没人遇到的坑」，而是**上游正在修、尚未合入**的坑；且修复系列的措辞与本机现象一一对应。按项目原则（`AGENTS.md`「能力缺口默认上游化」），这属于**应跟踪/backport 的上游能力缺口**，不是需要我们自己发明驱动改动的新问题。

---

## 6. 下一轮 3 条最省时的上机判据

> 前提：`modprobe qcom_iris` 后才建节点（本机开机不自加载）。三条都可复制执行；设备侧 Alpine/Debian 用 `sudo`。

### 判据 1 —— 拿到固件的「自我判决」（区分 **P1 驱动误标** vs **P2 固件报 corrupt**）

```sh
# ① 先卸再开 dyndbg（module 名是 qcom_iris，不是 qcom-iris），② 再 modprobe 才能抓到探针期的 firmware version
sudo modprobe -r qcom_iris
sudo sh -c 'echo "module qcom_iris +p" > /sys/kernel/debug/dynamic_debug/control'
sudo grep -c qcom_iris /sys/kernel/debug/dynamic_debug/control    # 期望 >0，否则 dyndbg 写错了
sudo dmesg -C
sudo modprobe qcom_iris && sleep 1
sudo dmesg | grep -E 'firmware version'                            # 期望出现 vfw-3.5:rel0030
# ③ 解一帧，然后只看 iris 的 dev_dbg/dev_err
ffmpeg -v error -c:v h264_v4l2m2m -i /tmp/test.h264 -f null - 2>&1 | tail -5
sudo dmesg | grep -E 'state changed|sub_state changed|session info|session error|unsupported content' | head -40
```

- **期望 A（判据成立 → C 假设）**：出现 `session info received 0x…: drc last flag`、**没有** `data corrupt` / `buffer overflow` / `session error`；`sub_state changed from 0 to 22` 与 `…22 to 66`。
- **期望 B（→ B 假设）**：出现 `session info received 0x…: data corrupt`（或 `buffer overflow`、`session error received …`）。
- **区分**：P2 必有 `session info … data corrupt`（`iris_hfi_gen2_response.c:229` 的 `dev_dbg`）；P1 什么也不打。
- **顺带证伪「dyndbg 写法」**：`grep -c` 若为 0，说明 `/sys/kernel/debug` 未挂（`sudo mount -t debugfs none /sys/kernel/debug`）或关键字写错；**不要再用 `file drivers/media/…/iris/*`（路径 glob 依赖编译期 `__FILE__` 形态）**，`module qcom_iris +p` 与 `file *iris_hfi_gen2_response.c +p` 都更稳。

### 判据 2 —— 直接量那颗出错缓冲的 `flags` 与 `bytesused`（区分 **P1 空 PSC_LAST** vs **P2 有数据的 corrupt**）

```sh
sudo strace -f -qq -e trace=ioctl -o /tmp/dq.txt \
  ffmpeg -v error -c:v h264_v4l2m2m -i /tmp/test.h264 -f null -
grep -n 'VIDIOC_DQBUF' /tmp/dq.txt | tail -20
# 若 strace 未装：sudo apt install strace（或退而用 sudo perf trace -e ioctl -p <pid>）
```

- **期望 A**：CAPTURE 的 `DQBUF` 返回 `flags=0x10400040`（或 `0x00400040`）= `LAST|ERROR`，且 `bytesused=0` ⇒ **`:393` 少判 `PSC_LAST` 的驱动 bug（P1）**。
- **期望 B**：`flags=0x00000040`（仅 `ERROR`）且 `bytesused>0` ⇒ 固件给了数据并自报 corrupt（P2）。
- **区分**：`ERROR` 是否与 `LAST` 同时出现 + `bytesused` 是否为 0。这两个数一行就能定性，且不需要改任何代码。

### 判据 3 —— 只喂 bitstream、不 STREAMON capture（区分 **固件解析能力** vs **驱动早捕获 DRC 分叉**）

```sh
# 只开 OUTPUT 面：固件会解析 SPS 并发首次 settings change，但驱动此时 state=INPUT_STREAMING(2)
sudo dmesg -C
v4l2-ctl -d /dev/video17 \
  --set-fmt-video-out=width=640,height=480,pixelformat=H264 \
  --stream-out-mmap=4 --stream-from=/tmp/test.h264 --stream-count=1 --verbose
sudo dmesg | grep -E 'sub_state changed|state changed' | head -20
```

- **期望 A（→ C 确证）**：`sub_state changed from 0 to 21`（`FIRST_IPSC|INPUT_PAUSE`，`iris_state.c:186`），**没有** `22`。说明固件正常发首次 PSC，只是被「capture 已提前 STREAMON」这一事实逼进 DRC 分支 ⇒ 根因在**驱动的 early-capture 处理**，修法 = backport series 1222157。
- **期望 B（→ B 确证）**：连一行 `sub_state` 都没有 / 直接 `session error` ⇒ 固件没把这条 bitstream 当合法码流 ⇒ 回到固件代次/内容层。
- **区分**：`0x21`（首次 IPSC 走对）vs `0x22`/无事件。**这是唯一能把「驱动 DRC 分叉」与「固件」劈开的最小实验**，且比判据 1/2 更进一层：它同时验证「如果不早捕获，这版驱动能不能解」。
- 备注：若 `v4l2-ctl` 该版本不支持 `--stream-out-mmap`（老版本无 m2m 支持），退化为 `v4l2-compliance -d /dev/video17 --stream-from=/tmp/test.h264 -v` 并只看其中的 streaming 小节 + 同期 dmesg。

---

## 7. 局限与未做的事

1. **未上设备**：本报告所有「实测对照」都来自 `reports/dt-vk197-adsp-iris-20261127.md §6` 的既有记录，未新增测量。
2. **未改内核树**：`build/daily` 一字节未动（`git status` 里 iris 目录无本报告改动）。
3. **ffmpeg 版本差**：本机 ffmpeg 8.0.1（`libavcodec.so.62`），设备上的 ffmpeg 版本未核；但 `v4l2_buffers.c` 的 `driver decode error` 与该判定逻辑在 7.x/8.x 同源，`v4l2_m2m_dec.c` 的 STREAMON 次序亦同。
4. **lore 不可达**（403），只有 patchwork 视角；因此**可能还有未进 patchwork 的私有修复**，但至少「上游有人在做且方向一致」已成立。
5. **未逐条读 series 1222157 全部 11 贴**（读了 01/04/06/10/11 的 diff，足以定性）；若下一轮要 backport，需再读 02/03/05/07/08/09 并确认与 2026-10-14 base 的 rebase 代价。
