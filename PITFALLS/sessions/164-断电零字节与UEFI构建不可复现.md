# 断电后的「零字节文件」与 UEFI 构建的时间戳不可复现（2026-11-05 上午，R21 收尾）

日期 2026-11-05 · pi 会话 id `01a1a959-3abb-72e6-8a5b-b622e60b0041` · 主题 掉电损坏的识别与恢复 / 构建等价性判据
结论 掉电会把「已写未落盘」的页按 0 重放：源码→0 字节、追加内容→NUL 尾巴；UEFI 构建带编译时间戳，两次构建 sha 必不同，等价性要用逐块比对
证据指针 `reports/uefi-noavb-dtbo-bootchain-20261104R.md` §9；`scripts/uefi-build-variant.sh`；`scripts/uefi-repack-v2aligned.py`
★SSOT 待并入：无（已并入 PITFALLS/README.md 索引 #509/#510/#511，2026-11-05）

## #509 掉电后的三种损坏形态：**0 字节 / NUL 尾巴 / 元数据已增长但内容全 0**

- 2026-11-05 09:32 前断电，实测同一台机同时出现三种形态：
  1. **源文件 0 字节**：`build/uefi-woa-prep/repos/7-mu-lenovo` 里 15 个刚被补丁改写的文件
     （主仓 10 + `Common/MU_TIANO` 2 + `MU_BASECORE` 5）长度全变 0 —— `git status` 看起来只是
     「M」，看不出被清空；**`git diff --stat` 会显示「整文件删除」（-10837 行）**才是警报。
  2. **产物 0 字节**：`reports/artifacts/uefi-20261104R21-hostdiag/` 九个文件全 0（脚本刚 `rm -rf` 完重建时断电）。
  3. **尾部 NUL**：`reports/*.md` 末尾被追加内容的位置变成 2456 个 `\x00`，文件 `git diff` 只显示
     「Binary files differ」；`file` 仍报 UTF-8 text，`grep` 却报 binary file matches。
- 判据与处置：
  - 收尾/接手前先 `find . -size 0 -newermt '<昨天>'`、`git status --short`、`git diff --stat`；
    出现「整文件删除」= 被清空，不是有意删除。
  - 源码一律 `git checkout -- <files>` 恢复，**不要手工补**；补丁与补丁清单（manifest 的 `patches=`）
    是唯一权威，重建比修补可靠。
  - 报告类文件出现 NUL 尾巴 ⇒ 丢弃尾部重建；若正文与 `HEAD` 一致，直接 `git checkout -- <file>`。
- 注意：`git checkout` 之后再构建，脚本的 `build.log` 是**中文 locale** 的输出
  （`成功应用补丁 …`），用 `grep 'Applied patch'` 判会误判成「补丁没打」。

## #510 UEFI FD **不跨构建可复现**：差的是 `__DATE__`/`__TIME__` 与它引起的立即数偏移

- 同一份补丁序列、同一天不同时刻两次构建，`SM8750_EFI.fd` sha 不同（本次相差 63 832 B / 4 处聚集）。
- 定位法（可复用）：镜像 kernel 段是 gzip(`payload-v2aligned.bin`)，解压 → 外层 FV（`_FVH`）→
  LZMA 压缩段（GUIDed section `98584eee-1439-5942-9d6e-dc7bd79403cf`）→ 内层 DXE FV。
  逐块 diff 后差异只有两类：PE 里的构建时间字符串（`Nov  4 2026 23:18:14` vs `Nov  5 2026 09:39:49`，
  紧邻 `<null time>`/`<null guid>`，即 EDK2 的 `__DATE__`/`__TIME__`）与由长度/布局变化带出的
  `adrp/add` 立即数（如 `84e00f91` → `84a00f91`）。
- ⇒ **判等口径**：不要比 FD/镜像 sha；比 ①`Build/.../LinuxLoader.efi` 里的关键字串
  （`strings | grep 'diag st='`）、②两发 payload 的**逐块 diff 是否只落在时间字符串区**。
  同日连续两次构建若不是这批字符串差异，说明真的编进了不同代码。

## #511 屏上 / NV 都不可用时，把标记**回传给宿主**：fastboot 响应是第四条通道

- 本树三条通道全废（`ConOut` no-op / LinuxLoader 的 `SerialPortWrite` 不上屏 / NV 变量不跨上电，见
  `#506` 与报告 §8）。可行替代：在 fastboot 命令处理里把「最后一条标记」`AsciiSPrint` 进 `Resp`
  再 `FastbootFail()`，宿主读 `diag st=%r last=[%a]` 即知停在哪个阶段。
- 关键前提：解析 cmdline 必须在**调用 `BootLinux` 之前当场做**（全局 `SbStopStage` 此刻仍是 −1），
  且诊断模式**不能**先 `FastbootUsbDeviceStop()`，否则 USB 已停、判据「掉线=崩在前面」失效。
