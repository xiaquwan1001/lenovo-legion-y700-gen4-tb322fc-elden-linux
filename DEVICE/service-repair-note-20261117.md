# 送修说明（联想拯救者 Y700 四代 TB322FC · SN HA2EXB0E）

> 给售后/维修工程师看的一页纸。本机现为**官方 259 固件 + 官方镜像**（我方已全量刷回），
> 故障与"改装系统"无关性已在下方逐条自测。详细日志与取证件见文末指针。

## 设备与固件

| 项 | 值 |
|---|---|
| 机型 | Lenovo Legion Y700 第四代（TB322FC / SM8750P / 代号 elden） |
| 序列号 | **HA2EXB0E**（fastboot 序列号同名） |
| 引导固件 | 官方 `TB322FC_15.10.259` 包内容（`xbl/xbl_config/abl/uefi/aop/tz/hyp/keymaster/devcfg/qupfw/uefisecapp/imagefv/shrm/cpucp/featenabler` × A/B 共 39 个分区），设备端 sha256 **39/39 == 官方件** |
| 系统镜像 | 官方 `boot/vbmeta/dtbo`，A/B 双槽均已刷官方件并读回校验 |
| 解锁状态 | `unlocked:yes`（`fastboot oem unlock`，2026-10-03 由本机完成；非本次故障原因，见自测 5） |
| 当前状态 | 停在 **fastboot**（`fastboot devices` 可见 `HA2EXB0E`）；`current-slot=a`、`slot-unbootable:a/b=no/no`、`slot-retry-count=a7/b6` |

## 现象（用户可复述）

1. 开机后**只进 fastboot 界面**（bootloader），不进 Android、无开机动画、无 logo 停留后的系统启动。
2. 卡死后**完全断电（长按 15–20 s 到黑屏）→ 等 10 s → 只按电源键开机**，仍然只进 fastboot（已连续 2 次，不随时间自愈）。
3. 在 fastboot 下执行：

```
fastboot continue            → FAILED (remote: 'Failed to load image from partition: Device Error')
fastboot boot <任意 boot.img>  → Sending 'boot.img' OKAY
                               FAILED (remote: 'Failed to load/authenticate boot image: Device Error')
```

4. USB 下载通路本身正常（83 MB / 65 MB / 1 MB 镜像都能 **`Sending … OKAY`**，失败发生在之后的 **load / authenticate 阶段**）。

## 自测项（已排除的 9 类原因，均为可复现命令 + 读回校验）

| # | 已排除 | 判据 |
|---|---|---|
| 1 | boot 镜像内容损坏 | 分区 dump 与主机件逐字节相同（设备端 `sha256`） |
| 2 | 写路径未落地 | 重刷后设备端 `sha256` 仍与源件相同 |
| 3 | 分区表(GPT)损坏 | 5 个 LUN 全解析，`boot/vbmeta/dtbo` 等分区齐全、尺寸正确（boot 96 MiB、dtbo 32 MiB） |
| 4 | A/B 槽属性异常 | 复位为 `unbootable=no / retry=7`；冷起后 retry 7→6 ⇒ ABL **确实尝试并失败** |
| 5 | 解锁/校验态 | `Device unlocked: true`、`critical unlocked: true`、`Verity mode: false` |
| 6 | AVB 签名链（我方自签件被拒） | 刷**官方** `boot_b.img`（OEM key `8fcb864f…`）+ 官方 `vbmeta_b` 后同样失败 |
| 7 | 引导固件被改坏 / 代次错配 | 全量刷官方 39 分区，设备端 sha256 **39/39 == 官方件**，仍失败 |
| 8 | 镜像大小 / 落点 | 96 MB、65 MB、**1 MB** 自制合法 boot.img 全部同一错误 |
| 9 | BCB 命令 / DDR 训练数据 | 清 `misc` 的 BCB 命令（原值 `ffbm-00`）+ 按官方配方把 `ddr` 分区清零，均无变化 |

补充证据（指向硬件）：在同一台机上，**EDL（9008）大块内存访问曾 5 分钟不返回**（`poke 32 MiB → 0x90000000`），
且同一命令的错误串在多次尝试间**自行变化**（`Device Error` ↔ `Load Error`）——两者都不符合"镜像/分区有问题的确定性失败"。

## 判定与期望维修动作

**判定**：所有可由软件/固件/镜像解释的原因已逐条排除，失败点固定在**引导阶段 ABL 加载 boot image 时的运行期内存访问**，
高度指向**主板侧（DRAM / 存储控制器或相关供电）硬件故障**。

**期望维修动作**（建议按序）：
1. 主板级诊断：DRAM 完整性与存储控制器读写测试（厂商诊断模式或产线工具）；
2. 若诊断不可用，**更换主板**后复测"能否正常开机进 Android"；
3. 复测判据：`fastboot devices` 不再出现（进入系统）、或 `adb devices` 可见该机；开机无 fastboot 停留。

## 附：可复现命令（维修方复测用）

```bash
# 1. 确认现象
fastboot devices                       # → HA2EXB0E  fastboot
fastboot -s HA2EXB0E getvar current-slot
fastboot -s HA2EXB0E continue          # → 'Failed to load image from partition: Device Error'
fastboot -s HA2EXB0E boot <任意官方boot.img>   # → 'Failed to load/authenticate boot image: Device Error'

# 2. 进入 9008（无需拆机/短接）
fastboot -s HA2EXB0E oem edl           # 4 s 内 lsusb 出现 05c6:9008
```

## 证据指针（我方内部，供核对，不随机器上交）

- 全账：`reports/bl-stuck-20261117-device-window.md`（§2 九类排除表、§7 原厂刷写与 39/39 校验、§8 结论）
- 历史同类案例 10 例与排查决策树：`reports/bl-history-and-playbook.md`
- 二进制取证：`reports/artifacts/bl-stuck-20261117/`（`misc`/`vbmeta_a,b`/`dtbo_b`/`logfs`/`xbl_sc_logs` + `SHA256SUMS.txt`）
- 39 分区刷写前现值 dump：`backup/HA2EXB0E-16+512/dev-dump-20261117/`（`SHA256SUMS.txt` 已入仓）
- 硬件稳定性上交：`~/hw-stability/evidence/inbox/20261117-y700-elden-bl-load-error/`
