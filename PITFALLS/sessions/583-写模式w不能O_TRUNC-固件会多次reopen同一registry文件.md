# #744 · hexagonrpcd 的 `'w'` **不能** `O_TRUNC`：固件会把同一个 registry 文件反复 reopen 续写

**结论**：SM8750 的 sensors PD 在 attach 期间对同一路径（`/mnt/vendor/persist/sensors/registry/fstempfile` 一类）
**多次 `fopen("w")` 续写**。如果按 POSIX 直觉给 `'w'` 加 `O_TRUNC`，每次都把前一次写的内容清空 ⇒ 最终落盘的 registry
只剩最后一次写的一小段。

**实测（2026-11-27，TB322FC，真重启 + 强制 DSP 重写 registry）**：

| 变体 | 落盘 `fstempfile` | `cam_registry_dump.txt` | iio 三属性 |
|---|---|---|---|
| `'w'` = `O_APPEND`/无 flag（不截断） | **6851 B** | 18628 B | 加速计/环境光/接近 **全 true** |
| `'w'` = `O_TRUNC` | 699 B | 未生成 | `HasAccelerometer=false`、`HasProximity=false`（环境光仍 true） |

`ssccli --sensor accelerometer` 在两种情况下都还能出值（DSP 侧另有内存副本），**所以「传感器能用」不能当作写侧正确的判据**；
判据必须是 **overlay 里的文件字节数 + 三属性**。

**落地**：`apps_std` 的写打开只对 `'a'` 传 `O_APPEND`，`'w'` 传 0（不截断），并在代码里写明原因；
上游 PR `linux-msm/hexagonrpc#31` 的提交正文与 PR 描述都写了这条 A/B 数据。

**可复查**：`reports/hexagonrpcd-overlay-hexagonfs-20261127.md` §2/§3；
补丁原文 `patches/userland/hexagonrpc-pr31-20261127/0003-*.patch`；
判据命令见报告 §4（`find /var/lib/hexagonrpc -type f -printf "%s %p\n"` + `busctl get-property … HasAccelerometer`）。

**通用判据**：任何「DSP 写文件」类后端，默认**不截断**；要截断必须先证明固件对每个路径只打开一次写。
