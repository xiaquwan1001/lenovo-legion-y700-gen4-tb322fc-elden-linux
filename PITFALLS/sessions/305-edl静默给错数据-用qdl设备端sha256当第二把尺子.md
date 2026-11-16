## #669 EDL 侧「静默给错数据 / 静默不写 / 大块读失联」三类工具缺陷；正解 = 用 `qdl sha256` 让设备端算摘要当第二把尺子

**现象（2026-11-16，设备卡 fastboot 的只读取证）**：用 bkerler `edl.py` 取证时踩到两类**不报错**的行为——

- **1.** **`--lun` 用错不报错**：`eldenesp` 在 **LUN0**（`printgpt` 的 LUN0 表里 `first LBA = 123609088`），
   我先按 `--lun=4` 去读同一 LBA ⇒ 读回 4 KiB **别处的数据**（一个 `<?xml version="1` 头），
   `edl.py` 只回一句 `Dumped sector … as …`。**任何"按名/LBA 读分区"的结论都必须先在 `printgpt` 里确认这块属哪个 LUN。**
- **2.** **单次读整分区不可靠**：`edl.py r eldenesp`（512 MiB 一发）两次都**没有产出**（600 s 超时无文件 / 连接被中断），
   改成 **16 × 32 MiB 分块**（`rs <LBA> 8192 --lun=0`）一轮跑完。`edl.py` 没有分块开关，
   **`qdl` 有 `-u/--out-chunk-size`**。

### 判据 / 处置（本轮定型的三招）

- **第二把尺子 = 设备端摘要**（不经 USB 传数据，比"读回再本地 hash"强）：

  ```bash
  cd ~/edl && ./qdl/build/qdl -R -s ufs ~/下载/tb322fc/xbl_s_devprg_ns.melf sha256 4/321824+24576
  # → 06c081ca…   （= bootslot-b/boot_b.img ⇒ boot_b 内容清白，由第二个独立工具确认）
  ```
  本轮用它把「`boot_b` 内容与主机件一致」从**单工具结论**升成**双工具结论**；
  同时 `edl.py r boot_b` 三次独立读 sha 全同 ⇒ 读路径本身也没坏。
- **默认改用 `~/edl/qdl/build/qdl`（tag v2.9）**做读/校验（`read` / `sha256` / `-u` 分块 / `--dry-run`）；
  `edl.py` 只留 loader/Sahara 与 GPT 小写 ⇒ 这是 `reports/edl-toolchain-survey-20261101.md` §4.5
  早已写下的结论（「bkerler 仅保留 loader/Diag 用途，避免其 qfil 已知返回码 bug bkerler issue 808/809/810」），本轮再次撞到。
- **写路径永不信任退出码**：`cmd_program()` 在设备拒绝 `<program>` 时仍返回 True（bkerler issue 808）、
  `qfil` 会**静默只写一部分分区**却退出 0、`gpt <dir>` 会打印成功但**一字节都不写**（技能 `qualcomm-edl-flashing` §Pitfalls）
  ⇒ 写完一律 `qdl sha256` 或读回比 sha；本轮 `fastboot flash misc` 就是用 EDL 读回比 sha 才确认落盘（`8da2a417…`）。
- **LBA 单位 = 4096 B**（不是 512）：算偏移一律 `byte_offset // 4096`；`sgdisk/gdisk` 按 512 读会整表错位。

### 为什么值得单列一条

「工具静默给错数据」会在**取证**阶段制造假结论：本轮如果只看第一次 `--lun=4` 的读回，
就会写成「ESP 上是个 XML」，进而怀疑 GPT/ESP 被写坏。**规则：9008 取证的每条「读回」都要有
① LUN 归属（`printgpt` 行）② 扇区单位（4096）③ 第二个工具或第二次独立读 三件里至少两件。**

证据：`reports/bl-stuck-20261116.md` §1/§2/§8（含分块脚本与 `qdl` 命令）、
`reports/edl-toolchain-survey-20261101.md` §2/§4、技能 `qualcomm-edl-flashing`（`rs/ws` LBA 单位、qfil 静默部分写）、
`PITFALLS #486`（本机 loader 不放行 `peek` ⇒ 「EDL 直读 DDR」路不通，同类"工具能力边界"）。
