# #743 · FastRPC `in sequence<byte>` 的 **size word 就在 prim buffer 里**：def 里别再多写一个 `WORD`；且签名不匹配不要 abort 监听循环

- 日期：2026-11-27（hexagonrpcd 可写 overlay 轮）
- 现象：DSP 调 `fwrite`（method 5）时服务打印 `Method 5 invoked with less arguments than expected`，
  然后 **`run_fastrpc_listener` 直接返回** ⇒ DSP 停在半 attach（传感器三属性 false、服务 `inactive`）。
- 根因与修法：
  1. `apps_std_fwrite(in FILE sin, in sequence<byte> buf, rout long bytesWritten, rout long bEOF)` 的 def 应为
     `WORD(fd) + BLOB_SEQ(data) + OUT_BLOB + OUT_BLOB` —— **序列的 size word 已经被 `HRPC_ARG_BLOB_SEQ` 消费**
     （`count_sizes4()` 里 `size = *(uint32_t *)pos * d`），我们多写了一个 `WORD` ⇒ 期望 8 字节 prim 而 DSP 只给 4。
  2. `invoke_requested_procedure()` 在签名校验失败时**不该 `return 1`**（那会结束整个监听循环）：
     改成回 `AEE_EBADPARM` + 分配 4 字节零 outbuf 并 `return 0` 继续服务 ⇒ 单个方法猜错不拖死 DSP 附着过程。
- 判据：
  - 诊断消息要**带方法号**（`Method %u invoked with %u/%u buffers, signature mismatch`），否则只能靠猜；
  - 写新方法时对照 AOSP `apps_std.idl`（`idl/apps_std.idl`）逐参数数：`in sequence<T>` = 1 个 size word + 1 个 inbuf。
- 关联：`#742`（方法表按索引 dispatch）、`#741`（attach 三必踩）、`reports/hexagonrpcd-writable-overlay-20261127.md`。
