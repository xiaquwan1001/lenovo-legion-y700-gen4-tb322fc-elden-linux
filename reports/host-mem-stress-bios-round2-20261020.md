# 新 BIOS 轮（调内存稳定性）压测结论：**未修好**，且拿到 DRAM 级硬证据

- **日期**：2026-10-20 21:39–22:25
- **主题**：用户改完新一轮 BIOS（重点调内存稳定性）后，用「待测且从未编译的树」做内存压测
- **结论（一句话）**：**新 BIOS 设置没有解决问题。** 8 轮干净全量构建里 3 轮崩（`cc1` SIGSEGV/SIGILL、`dtc` SIGSEGV），
  同期 `stressapptest`（30 GB 常驻、自校验）**报 7 个 hardware incidents / FAIL** ⇒ 错误已能直接落在 DRAM 数据通路上，
  不再是「只翻页缓存」那种间接表现。
- **判定级别**：硬件（内存/IMC/CPU 侧），软件/工具链/内核回归已排除（同树同配置有 5 轮成功、产物逐对象 sha 一致）。
- **证据目录**：`logs/memstress-20261020-215329-full8/`（`summary.txt`、`build-{1..8}.log`、`digest-*.sha`、`stressapptest.out`、`cache-probe.log`）。

**本轮 BIOS 参数（用户提供，用于追溯）**：内存控制器电压 `auto → 1.25 V`、分频比（gear）`auto → 1:1`、内存 `3200 → 3000 MT/s`；BIOS 版本仍 `1836`（2026-04-16）、微码 `0x133`。以上三项即为「重点调内存稳定性」的全部改动。

---

## 1. 被测负载（= 用户指定的「待测且未编译的项目」）

| 项 | 值 |
|---|---|
| 树 | `build/m3v2-7.3rc7` = pristine `v7.3-rc7`(`24a19b953`) + **M3-1 v2 两枚 USB/dwc3 补丁**（分支 `m3v2`） |
| 此前状态 | 从未全量编译（只有 `scripts/*.o`），`vmlinux` 不存在 ⇒ 真·首编 |
| 目标 | `make -j28 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image dtbs` |
| 轮次 | **8 轮，每轮 `make clean` 后全量重编**（不是增量） |
| 编译配置 | `CONFIG_ARCH_QCOM=y`、`CONFIG_DEBUG_INFO=y`+`DEBUG_INFO_REDUCED=y`（`PITFALLS #162` 的「死内核」情形已排除） |
| 墙钟 | 单轮 252–296 s；总 1768 s |

并行压测：

| 工具 | 参数 | 作用 |
|---|---|---|
| `stressapptest` | `-M 30000 -m 12`（30 GB / 12 线程，全程 1815 s，32.2 TB 数据经手） | 持续写 + 回读校验 ⇒ 直接暴露 DRAM 单元错 |
| 页缓存三读探针 | 每 120 s 一轮 `detect-memory-corruption.py --tree`（共 9 轮 × 95 978 文件） | 暴露「文件页缓存被翻位」这一 2026-10-20 早些时候的主症状 |
| 产物可重现性 | 每轮对 7 243 个 `*.o/*.a/*.dtb` 取 sha256，轮间比对 | 抓「编译通过但字节被翻」的静默损坏 |
| 体检门 | `kbuild-sanity.sh --before/--after --rounds 3` | 树完整性 / 工具链 / 交叉编译探针 |

---

## 2. 结果

### 2.1 构建

| 轮 | rc | 墙钟 | 结果 |
|---|---|---|---|
| 1 | 0 | 286 s | ✅ |
| 2 | 0 | 293 s | ✅ |
| 3 | **2** | 205 s | ❌ `kernel/sys.c:1037:1: internal compiler error: 段错误`（cc1，RTL `sched2`） |
| 4 | 0 | 283 s | ✅ |
| 5 | **2** | 150 s | ❌ **一次构建 5 个 ICE**：3×`段错误` + 1×`非法指令`(SIGILL) + 1×`段错误`，分散在 `mm_types.h`/`moduleparam.h`/`actbl2.h`/`mmu_notifier.h`/`net/ipv4/ping.c` |
| 6 | 0 | 296 s | ✅ |
| 7 | 0 | 252 s | ✅ |
| 8 | **2** | 3 s | ❌ `dtc` **Segmentation fault (core dumped)** ⇒ `错误 139`（`sm7325-motorola-dubai-csot.dtb`） |

- 成功/失败 = **5 / 3**；失败模式全是**工具进程自己崩**（不是源码错误、不是配置错误）。
- `非法指令`(SIGILL) 是**代码页被改写**的直接证据：cc1 执行到了被翻转成非法指令的字节。

### 2.2 `stressapptest`（最强证据，与编译器无关）

```
Thread 1 found 1 hardware incidents
Thread 2 found 2 hardware incidents
Thread 3 found 1 hardware incidents
Thread 4 found 1 hardware incidents
Thread 8 found 1 hardware incidents
Thread 11 found 1 hardware incidents
Stats: Found 7 hardware incidents
Stats: Completed: 32187334.00M in 1815.31s 17731.06MB/s, with 7 hardware incidents, 0 errors
Status: FAIL - test discovered HW problems
```

30 GB 常驻、写后回读比对的 1815 s 里出现 **7 次数据不一致**，分布在 6 个线程 ⇒ **DRAM 侧有确定性错误**，
不需要靠「编译器 ICE」来间接推断。

### 2.3 页缓存探针 = 0（重要口径修正）

9 轮全树三读法 `page_cache_corrupt=0`，而同期 ICE 连发。说明本轮的翻位主要落在
**进程匿名内存（cc1 的堆/栈/私有页）**，不是文件页缓存 ⇒ 2026-10-20 早些时候那套「页缓存三读法」
**不能作为内存合格判据**（真阳性会漏）。合格判据应是 `stressapptest` + 构建 ICE + 产物 sha 三类。

### 2.4 产物可重现性

5 个成功轮的 7 243 个对象 sha256 **完全一致**，轮间差异只出现在已知非确定性对象
（`usr/initramfs_data.o` 含 cpio mtime、`vmlinux.o` 链接了 `version-timestamp.o`）。
⇒ 成功轮的编译产物可信；失败轮不出产物，未污染下游。

⇒ 顺带结论：**`build/m3v2-7.3rc7` 的 M3-1 v2 补丁本身可正常全量构建**（5 轮 0 错），
失败与补丁无关。

---

## 3. 判读

| 观察 | 含义 |
|---|---|
| 同树同命令 8 轮里 3 轮崩 | 随机性 ⇒ 不是代码/配置问题 |
| `cc1` 出现 SIGILL | 执行流拿到被改写的指令字节 ⇒ 内存/缓存/执行通路损坏 |
| `stressapptest` 7 次 miscompare | **DRAM 单元级**错误（本次不依赖页缓存推理） |
| 页缓存探针 0 命中 | 翻位落在匿名内存，页缓存检测不敏感 ⇒ 之前「三读法干净」不代表内存好 |
| 失败集中在压力最高时（30 GB stress + 28 编译线程） | 与电压/频率余量/温度强相关，典型 Vmin 边缘 |

**新 BIOS 这一轮的设置没有把余量补回来**：错误率约 **1 次致命事件 / 2.7 轮构建**，
且 `stressapptest` 在 30 min 内就红。这已经越过「概率事件、偶发」的范畴。

---

## 4. 下一步（按判别力/代价排序）

1. **单条内存定位**（信息量最大、只需开箱）：只插一条 → `scripts/host-mem-build-stress.sh --repeats 4 --clean-between`
   + `stressapptest -M <该条容量-2G>`。逐条换，哪条红就锁定哪条（61 GiB = 2×32 或 4×16，需确认）。
2. **同轮次对照组**（分离「DRAM」与「CPU/IMC」）：
   - 只跑 `stressapptest -M 50000 -m 16`（无编译）30 min；
   - 只跑构建（无 stress）8 轮。
   两者都红 ⇒ 内存本身；只有「高 CPU 负载 + 内存」才红 ⇒ 更偏 IMC/CPU 侧（14700KF 属 Vmin shift 重灾型号）。
3. **BIOS 里逐项降级**（一次只改一项，每项跑 4 轮）：
   关 XMP/EXPO 到 JEDEC（2133/2400）→ 若仍红，再 `SA/IO 电压 +offset`、`PL1/PL2=125 W`、`no_turbo`、关 E 核。
   目的是找到「能连跑 4 轮全绿」的配置，而不是追求性能。
4. **memtest86+ ≥4 轮**（整夜）：抓不到 cache 内翻转，但一旦红就是判决性证据，可直接支撑 RMA。
5. 短期兜底：**不要在本机生成需要长期采信的产物**（内核镜像/manifest/邮件附件），
   或生成后立刻跨机复核（本机 sha 不可信）。
6. 长期：换 ECC 平台（W680/服务器板 + ECC UDIMM），把静默翻转变成可报告的 CE/UE。

---

## 5. 交付物

| 文件 | 说明 |
|---|---|
| `scripts/host-mem-build-stress.sh`（新） | 本报告的压测编排器：体检门 + stressapptest + 页缓存探针 + N 轮 clean 构建 + 产物 sha 比对 + 日志嫌疑扫描 + 汇总；支持 `--repeats/--clean-between/--stress-mb/--timeout` |
| `logs/memstress-20261020-215329-full8/` | 本轮全部原始证据（`summary.txt` 为一页摘要） |
| 本文件 | 结论与下一步 |
