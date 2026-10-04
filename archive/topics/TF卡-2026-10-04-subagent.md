# TF 卡写稳定性 — 主机侧静态分析 + 资产准备（2026-10-04，subagent）

> 前作证据：`archive/topics/TF卡-2026-09-30.md`；任务：`TASKS.md` G1-6。
> 本轮**只做主机侧**：未刷机、未重启、未写设备、未编内核、未 commit、未改根目录 6 份维护文档。
> 结论层级：静态分析 + 资产；**最终定性仍取决于换卡 A/B（需用户操作）**。

## 0. 一句话

**根因倾向仍 = 卡本身（先验 ~70–80%）；本轮新增的硬结论是——`qcom,uses_level_shifter` 对本机是“无效移植”**：
厂商该属性唯一功能就是「SD_HS 时钟封顶 37.5 MHz」，而主线已通过 `sm8750.dtsi` 的
`max-sd-hs-hz = <37500000>` 达到完全相同的效果（实机 `/sys/.../ios` 也确认 37.5 MHz）。
所以**不要指望移植它修好写损坏**。已备好 5 个可区分根因的候选补丁 + 一个幂等压测脚本，供换卡 A/B 使用。

---

## 1. 驱动 / DT 差异：逐项核对（主线 7.2 vs 厂商 downstream）

### 1.1 `qcom,uses_level_shifter` 厂商实现要点

厂商 `stock-src/android_kernel_lenovo_sm8750/drivers/mmc/host/sdhci-msm.c` 中，该属性只出现在 3 处：

| 位置 | 行为 |
|---|---|
| 定义 L183 | `#define LEVEL_SHIFTER_HIGH_SPEED_FREQ 37500000` |
| 结构体 L538 | `bool uses_level_shifter;` |
| **L638-640**（`msm_set_clock_rate_for_bus_mode`） | `if (curr_ios.timing == MMC_TIMING_SD_HS && uses_level_shifter && !enable_ext_fb_clk) desired_rate = LEVEL_SHIFTER_HIGH_SPEED_FREQ;` |
| L2024-2028（`sdhci_msm_get_of_property`） | 读该 bool；若为真再读 `qcom,external-fb-clk` → `enable_ext_fb_clk` |
| L5005-5009（`sdhci_msm_probe` 尾部） | 仅当 `enable_ext_fb_clk` 时，置 `VENDOR_SPEC_FUNC4` 的 `EXTERN_FB_CLK` 位（外部反馈时钟） |

**即：该属性改的是「时钟频率（PM OPP rate）」，不碰 DLL/DDR 寄存器字段**。没有任何 DLL/DDR config 的差异与其绑定。

### 1.2 主线对应位置

- `linux/drivers/mmc/host/sdhci-msm.c::msm_set_clock_rate_for_bus_mode()`（L378 起）**没有任何 SD_HS 封顶逻辑**。
- 主线**没有** `LEVEL_SHIFTER_HIGH_SPEED_FREQ`、没有 `uses_level_shifter` 字段，也未定义该 DT 属性。
- 主线的等效手段在 **mmc core**：`drivers/mmc/core/host.c:299` 读 `max-sd-hs-hz` → `sd.c:362`
  `card->sw_caps.hs_max_dtr = host->max_sd_hs_hz ?: HIGH_SPEED_MAX_DTR`。
- 本机 `sm8750.dtsi`（`sdhc_2` 节点）**已有** `max-sd-hs-hz = <37500000>;` → 与厂商封顶**数值完全相同**。
  实机证据也吻合：`/sys/kernel/debug/mmc0/ios` 协商在 37.5 MHz（`PITFALLS` #55）。

### 1.3 移植可行性 / 风险 / 代价

| 项 | 评估 |
|---|---|
| 纯时钟封顶（本补丁） | **可移植，代价极低**，但属**无效移植**（max-sd-hs-hz 已等效）。 |
| `qcom,external-fb-clk` / `VENDOR_SPEC_FUNC4.EXTERN_FB_CLK` | 主线缺，属真相差；但本机 DT **未使用**（无该属性），厂商资料来源亦未见本机设置 → **不适用**。 |
| DLL/DDR config | 两边 DT 值一致（主线 `qcom,dll-config=0x0007442c` / `qcom,ddr-config=0x80040868`）；厂商驱动结构更旧，无额外可用差异。 |
| 兼容表 | 主线 `sdhci_msm_dt_match` 无 `qcom,sm8750-sdhci` 专用项，但 DTS 第二 compatible `qcom,sdhci-msm-v5` 命中通用 v5 → 正常。 |

**结论**：`qcom,uses_level_shifter` **不是缺失的 workaround**，不能作为根因候选；仅作 DT 对齐留档（补丁 a）。

### 1.4 `dma-coherent` 核实

`smsdhc_2`：`iommus = <&apps_smmu 0x540 0x0>; dma-coherent;`。核对同代主线各 SoC（hamoa / kaanapali / eliza / milos）**全部同款**
（sid 0x540 + dma-coherent）→ **不是 sm8750 独有的可疑项**。但若真实一致性被错误声明，现象恰是「总线成功、数据损坏、控制器零报错」，
故保留为廉价可证伪实验（补丁 b）。

---

## 2. 根因判定的静态倾向

支持「卡不良」的论据：

1. **尺寸相关性**：64 MB 大块×多轮全一致；8 MB 量级的 4 KB 小写间歇丢。**相干性/DMA 错误会按字节随机发生，不会只挑小写**。
2. `err_stats` 全 0（命令/数据 CRC、超时、ADMA 均无）→ 控制器/总线自认成功。
3. `e2fsck -fn` 前后一致 → **损坏确实停在卡上**（非读缓存陈旧）。
4. CID：白牌 `NCard`、`date 01/2010`、`OEM 0x0303`（非主流厂商标识）→ 典型贴牌/黑片特征。
5. `no-1-8-v` 已强制 3.3V/SD_HS（最保守的可用档），仍间歇坏 → 不是“高频 UHS 信号余量”那一类。

不能排除的驱动候选（静态无法区分）：
- 小写路径（单/多块 ADMA + 卡内部写缓冲/忙信号）的控制器-卡握手；
- 过度声明的 `dma-coherent`；
- 卡内部 FTL/写缓存固件在“多次小写”下丢写（仍是卡侧，但属“卡固件”而非“坏块”）。

**因此第 1 步必须是换卡 A/B，而不是继续猜驱动。**

---

## 3. 候选补丁清单（均已 `git apply --check` 通过，未提交）

> 全部位于 `patches/candidate-tf-*.patch`；**按代价从低到高**。应用方式（示例）：
> `cd linux && git apply ../patches/candidate-tf-lower-hs-hz.patch`（用完 `git checkout -- .` 回退）。
> 只改 DT 的补丁需重编 DTB（`make dtbs`，无需重编内核；仍建议 `flock /tmp/y700-kbuild.lock`）。

| # | 补丁 | 改动面 | 代价 | 预期能区分哪种根因 |
|---|---|---|---|---|
| a | `candidate-tf-levelshifter.patch` | 驱动 + DT | 低（但**无效**） | 仅证明“37.5 MHz 封顶通路”一致；若坏不变 → 排除时钟源问题。**预期无变化**。 |
| b | `candidate-tf-drop-dma-coherent.patch` | DT（`/delete-property/ dma-coherent;`） | 低 | **过度声明的 DMA 一致性**。若改后 PASS → 相干性根因；若不变 → 排除。 |
| d | `candidate-tf-lower-hs-hz.patch` | DT（`max-sd-hs-hz=12.5M`） | 低 | **时序/信号余量**。若降速后 PASS → 余量问题（卡或板级）；若不变 → 非时钟。 |
| c | `candidate-tf-uhs-1p8.patch` | DT（去 `no-1-8-v` + 四个 `sd-uhs-*`） | 中（需重编 DTB，1.8V 通路） | **3.3V-HS vs 1.8V-UHS 信令**。原注释称 SDR104 会坏，**预期更差**，仅作对照。 |
| e | `candidate-tf-bus-width-1.patch` | DT（`bus-width=<1>`） | 低 | **DAT1..DAT3 信号完整性**。若 1-bit 变好 → 数据线/负载问题。 |

> 注：`candidate-tf-levelshifter.patch` 的属性写为 `qcom,uses-level-shifter`（连字符，符合 DT 惯例）；
> 厂商驱动源码里用的是下划线 `qcom,uses_level_shifter`，移植时若要与厂商 DT 完全同名可自行改回。

---

## 4. A/B 实验设计（需用户操作；全部零写设备/只动 TF 卡与读卡器）

前置：设备当前停在 **fastboot**，Linux 未运行。先 `fastboot boot out/boot-elden-vk48.img`（持久变体）或正常启动 b 槽，
使 SSH `root@192.168.7.1` 可用、`/dev/mmcblk0`（TF）在。

**步骤 1 — 现状基线（本卡）**
```bash
scp scripts/tf-stress.sh root@192.168.7.1:/tmp/
# 设备上：把 TF 挂到 /mnt/tf（p2 若 fs 坏，先 mkfs.ext4 -O ^has_journal 或整卡格式化）
ssh root@192.168.7.1 'mkdir -p /mnt/tf; umount /mnt/tf 2>/dev/null; \
  mkfs.ext4 -F -O ^has_journal /dev/mmcblk0p2 && mount /dev/mmcblk0p2 /mnt/tf; \
  sh /tmp/tf-stress.sh -r 3 /mnt/tf; echo EXIT=$?'
```
记录输出的卡身份（`cid.*`）、`ios`（协商时钟/位宽/timing）、`err_stats`、`总不一致计数`。

**步骤 2 — 换已知良好卡（决定性）**：换一张品牌卡（Class10/A1，≥32 GB），同样的格式化 + 同一脚本跑一遍。

**步骤 3 — 本卡插安卓 / 电脑读卡器**：
- 安卓（a 槽 ZUXOS）或 PC 上跑等价的「写后读回」小写测试（PC 用 `f3write`/`f3read` 或 `h2testw`），
  或把本卡插读卡器后把同样脚本逻辑对读卡器挂载点跑。
- 目的：把「卡」从「设备 SDHCI 路径」里剥离出来。

**步骤 4（可选，强烈建议）— 容量真伪**：用 `f3` 或 `h2testw` 做**全卡写满再读回**（不是同偏移即写即读），
排除扩容黑片（同偏移即写即读对假容量卡是盲的）。

**判定见 §5。**

---

## 5. 判据（什么结果归因为什么）

| 观测 | 归因 | 行动 |
|---|---|---|
| 新卡 PASS 且旧卡 FAIL（同一 Linux 路径） | **卡不良** | **任务闭环：换卡**。旧卡降级为只读/丢弃。 |
| 新卡也 FAIL | **驱动/DT（或板级 SDHCI 路径）** | 依次试补丁 **d → b → e → c**（见 §3），每次单变量复跑 §5 脚本。 |
| 旧卡在安卓/读卡器也 FAIL | **卡不良** | 同上闭环（即使 Linux 侧还有问题，卡已先排除）。 |
| 旧卡在安卓/读卡器 PASS，但 Linux FAIL 且新卡也 FAIL | **Linux 驱动/DT** | 进入补丁排查。 |
| 降速（d）后 PASS | 时序/信号余量 | 决定：永久降速、或启 UHS+调 DLL、或查板级走线/驱动强度。 |
| 去 `dma-coherent`（b）后 PASS | 相干性声明错误 | 需上游式修法（正确描述一致性），而非长期删属性。 |
| 所有补丁都 FAIL 且新卡也 FAIL | SM8750 SDCC2 主线路径问题 | 转专项（对照同 SoC 其他产品/厂商 DLL 全套）。 |

**闭环定义（G1-6）**：换已知良好卡后，同一脚本连续 ≥3 轮 `总不一致计数 = 0`，且 `e2fsck -fn` 干净。

---

## 6. 压测脚本 `scripts/tf-stress.sh`

- **幂等 / 可复现 / 低干扰**：只在挂载点下建 `.tf-stress.<pid>/` 写临时文件，退出（含 INT/TERM）自动清理；
  源数据放 `/tmp`（非 TF）；不改分区表、不格盘、不动根分区。
- **自限**：内部用 `timeout -k 10 <总时长>` 重入一次包裹全脚本（默认 300 s），单个 `dd` 另有 120/180 s 超时。
- **防假阳性**：每轮写后 `sync` → `echo 3 > drop_caches` → 回读哈希比对（不 drop_caches 会被 page cache 骗）。
- **快照**：卡身份（`name/oemid/manfid/date/serial/fwrev/hwrev/cid`）、`/sys/kernel/debug/mmcN/ios`（协商速率/位宽/timing）、`err_stats`。
- **可选 fsck**：`--fsck` 在前后各卸载并 `e2fsck -fn`（摘要落 `/tmp/.tf-fsck.<pid>`）。
- 退出码：`0`=全一致；`1`=有不一致/前置失败；`2`=用法错。

用法：
```sh
tf-stress.sh [-n 小写块数=2000] [-m 大块MiB=64] [-r 轮数=3] [-t 秒=300] [-d] [--fsck] [挂载点=/mnt/tf]
# -d  4KB 小写用 O_DIRECT（oflag=direct；对照 buffered，区分 page cache/writeback 路径）
# --fsck  前后各一次 e2fsck -fn（会临时卸载再重挂）
```
建议首跑：`sh /tmp/tf-stress.sh -r 3 --fsck /mnt/tf`；怀疑 page cache 时加跑 `-d`。

---

## 7. 剩余未知

1. **换卡结果**（决定性；需用户物理换卡 / 读卡器）。
2. 卡真实容量（是否黑片扩容）——需全卡写满读回。
3. 是否与小写**并发度/多进程**相关（当前测试为单进程顺序小写；可加多线程 fio 对照）。
4. 板级 SD 走线/驱动强度（`sdc2_*` pinctrl：clk=16 mA、cmd/data=10 mA）是否对本卡余量不足——只有降速/1-bit 实验能间接判断。
5. 持久根离线装入等与 TF 有关联的改动未参与本轮。

---

## 8. 本轮实际改动 / 新增文件（**均未 commit**）

| 文件 | 说明 |
|---|---|
| `scripts/tf-stress.sh` | 新增，可执行；`sh -n` 通过 |
| `patches/candidate-tf-levelshifter.patch` | 新增（a） |
| `patches/candidate-tf-drop-dma-coherent.patch` | 新增（b） |
| `patches/candidate-tf-uhs-1p8.patch` | 新增（c） |
| `patches/candidate-tf-lower-hs-hz.patch` | 新增（d） |
| `patches/candidate-tf-bus-width-1.patch` | 新增（e） |
| `archive/topics/TF卡-2026-10-04-subagent.md` | 本文件 |

未改 `linux/` 源码、未编内核、未写设备、未动根目录 6 份维护文档。
