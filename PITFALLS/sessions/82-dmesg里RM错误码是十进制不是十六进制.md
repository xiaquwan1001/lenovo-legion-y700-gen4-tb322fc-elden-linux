# dmesg 里 `RM rejected … Error: 10` 是**十进制** ⇒ 0xA MEM_INVALID，不是 0x10 IRQ_INUSE（#393）

> 日期：2026-10-25 · 代价：2026-10-24 整轮「VMM 卡在 IRQ_INUSE」的结论与由此派生的两条假设
> （IRQ 泄漏、DTB 太“空”没 doorbell）**全部建立在错误的错误码上**，白跑一轮冷起复测 + 一晚上 DTB 变体。

## 事实

`drivers/virt/gunyah/rsc_mgr.c:633`：

```c
dev_warn(rm->dev, "RM rejected message %08x. Error: %d\n",
	 message_id, message.reply.rm_error);      /* ← %d，十进制 */
```

⇒ `Error: 10` = **10₁₀ = 0xA = `GUNYAH_RM_ERROR_MEM_INVALID`**；
`0x10 = IRQ_INUSE` 要打印成 `Error: 16`。同理 `Error: 3` = `DENIED`（0x3 恰好同值，别被巧合带偏）。

对照表（十进制打印 → 真实 `enum gunyah_rm_error`）：

| dmesg 显示 | 实际 | 含义 |
|---|---|---|
| `Error: 1` | 0x1 | NOMEM |
| `Error: 3` | 0x3 | DENIED |
| `Error: 10` | **0xA** | **MEM_INVALID** |
| `Error: 16` | 0x10 | IRQ_INUSE |
| `Error: 17` | 0x11 | IRQ_RELEASED |

## 纪律

- 任何 `RM rejected message %08x. Error: %d` 的行，**先把错误码当十进制**，换算成十六进制再去查
  `enum gunyah_rm_error`；`message %08x`（如 `5600000b`）才是十六进制。
- 报告里同时写两种写法（`Error: 10` = 0xA MEM_INVALID），避免下一个会话二次误读。
- 「错误码含义」决定了整条排查路径（IRQ 池 vs 内存 parcel），误读一个数就整轮方向错。

## 本轮据此修正后的真实状态（2026-10-25）

| 路径 | 结果 |
|---|---|
| SHARE 内存 + auth=NONE（普通 VM） | VM_INIT → **0xA MEM_INVALID**（原被误记为 IRQ_INUSE） |
| SHARE 内存 + auth=PVM（SET_FW_CONFIG）| **VM_CONFIGURE（0x09）→ 0x3 DENIED**：RM 明确拒绝「SHARE + PVM」 |
| LEND 内存（±SET_FW_CONFIG、±firmware-address、±size-max、±doorbell） | VM_INIT → **0xA MEM_INVALID**（7 个 DTB 变体全同） |
| `RM rejected message 56000002`（dealloc vmid） | 收尾噪声，非主因 |

⇒ 后续所有假设都必须解释 **0xA**，而不是 IRQ 池。
