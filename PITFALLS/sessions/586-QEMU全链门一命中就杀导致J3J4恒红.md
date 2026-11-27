# #747 「一命中就杀」的等待逻辑把 QEMU 全链门变成恒假红（J3/J4 结构上不可能 PASS）

> 2026-11-27，修 `scripts/qemu-full-chain-smoke.sh`。发现时机：能力集合配置批（vk194）要过 QEMU 预检，
> 结果**基线件（11-12 的 vk188 Image）同样 2/4** ⇒ 顺着「判据为什么不可能过」查出脚本等待逻辑。

## 结论

脚本原来是：

```bash
for _ in $(seq 1 36); do grep -q "Linux version" $W/serial.log && break; sleep 5; done
kill $QPID
```

即**只要串口出现 `Linux version` 一次就杀 QEMU**。但 J3（`Run /init as init process`）与 J4
（`Console: switching to colour`）发生在**之后**：TCG 下 guest 到 0.9 s 需要 ~12 s 墙钟，
而 5 s 轮询一命中就杀（此时 guest 才跑到 ~0.19 s）⇒ **两条判据永远不出现**，稳红。

## 判据（怎么一眼认出这类门）

- 判据集合里既有「早期事件」又有「晚期事件」，而脚本/框架的终止条件是**任一**事件 ⇒ 晚期判据恒红。
- **反作弊自查**：拿一个已知好件跑该门，若「好件也红」⇒ 先怀疑门，不要先怀疑被测物（本轮就是基线件红的）。
- 更一般：等待循环必须等**最终判据**（或超时），不能等**第一个出现的判据**。

## 修法（已落地）

```bash
BOOT_WAIT=${BOOT_WAIT:-150}
while 未同时出现 J3 与 J4 且 未到 BOOT_WAIT: sleep 3
kill $QPID; echo "[qemu] 用时 Ns（上限 ${BOOT_WAIT}s）"
```

修后：vk194 与 vk188 基线**均 4/4 PASS，12 s**。

## 相关

- 资产侧：`/tmp/qfc` 与 GRUB standalone 每次运行都重建（用户 2026-11-27 提示「早期 QEMU 资产可能是内存不稳期的产物，应清理重编」）⇒ 不再复用旧 `grubaa64.efi`。
- 本轮报告：`reports/capbatch-vk194-20261127.md` §3；门本体 `scripts/qemu-full-chain-smoke.sh`（头注已补 `BOOT_WAIT`）。
- 同族教训：`PITFALLS #452`（门禁自己静默跳过比没有门禁更危险）、`#745`（字数阈值挡不住模板化空句）。
