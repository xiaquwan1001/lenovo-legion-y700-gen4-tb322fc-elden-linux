# aw86927 series v2 — 无固件路径版（2026-10-27）

> **这版取代** `../aw86927-20261027/`（5 提交、含「固件波形装载」）。
> 决策依据：投递前对 linux-next 核对时判定「固件波形」是最容易被否的一块
> （上游自带驱动内正弦表 `aw86927_waveform[]`，来自 `df53055c540f`「Input: aw86927 - add support for
> Awinic AW86938」），于是按「先交最容易被收的部分」重切。
> 对应报告：`reports/aw86927-series-v2-20261027.md`。

- **基线**：`linux-next` **master** 的 `drivers/input/misc/aw86927.c` 与
  `Documentation/devicetree/bindings/input/awinic,aw86927.yaml`（2026-10-27 抓取）。
  该文件相对 7.3-rc7 只多一行 `#include <linux/interrupt.h>`（linux-next 侧漂移），本系列按
  linux-next 内容生成，**5 枚顺序 `git apply` 到 linux-next 全绿**。
- **构建树**：`build/aw-series` 分支 `aw-v2-fix`，tip `1bcb43ad8`；base commit
  `5197725fc`（= `24a19b953` + 上面那行 include，**不属于提交系列**）。
- **状态**：draft only —— **未投递、未上行**；投递需用户逐系列批准。

## 与 v1 的差别（为什么少了「固件波形装载」）

| v1 | v2 | 理由 |
|---|---|---|
| 0003 `load the RAM waveform from firmware`（+128 行、`select FW_LOADER`、`firmware-name` + `awinic,ram-waveform-index` 两个 DT 属性） | **删除** | 上游已有驱动内正弦表；要说服维护者「换成固件」需要额外论证（板级厂商波形 5881 B 在机可用，但不是上游的默认口径）。留作后续 RFC，先把无争议部分收进去 |
| 0002 per-chip 数据表（chipid / model / **SRAM 窗口**） | **删除**（AW86937 只保留 chipid + 初始化分支） | SRAM 几何唯一消费者是固件装载（界内校验）；去掉固件后它是死数据 |
| 0004 同时含 AW8693X 寄存器布局 + `BST 0x11→0x09` | 拆成 **0001（`Fixes:` 单枚）** + 0004 | 内核惯例：修既有 bug 走独立 `Fixes:`，不埋进新特性提交 |

## 提交

| # | 主题 | 变更 | checkpatch --strict |
|---|---|---|---|
| 0001 | `Input: aw86927 - fix the 7 V boost reference for AW86938` | `AW86938_PLAYCFG1_BST_7000MV 0x11→0x09`（`Fixes: df53055c540f`） | 0E（**1 W** = 本地仓 shallow，checkpatch 认不到 `Fixes:` 的 commit id；上游全树无此告警） |
| 0002 | `dt-bindings: input: awinic,aw86927: document the AW86937 variant` | `awinic,aw86937` 进 `awinic,aw86927` 回落组（与 AW86938 同型） | 0E/0W/0C；`dt-doc-validate` rc=0 |
| 0003 | `Input: aw86927 - add support for Awinic AW86937` | `AW86937_CHIPID 0x9370` + enum + `detect()` 分支 + `haptic_init` 并入 AW86938 分支 | 0E/0W/0C |
| 0004 | `Input: aw86927 - handle the AW8693X play and boost register layout` | auto-boost bit4→bit2、BST mode bit7→bit5(2 位域)、VBAT 模式取实测电压、停止改「PLAY_MODE_STOP + GO」两步并把 standby 超时当真失败 | 0E/0W/0C |
| 0005 | `Input: aw86927 - stop playback over suspend and on shutdown` | suspend/resume/shutdown + `suspended` 门 + `READ_ONCE/WRITE_ONCE` 幅度快照 | 0E/0W/0C |

## 门禁（编排者独立复跑，2026-10-27 晚）

```sh
# 1) 逐提交可编译（删 .o 强制重建；每个 commit checkout 后单独编）
for c in $(git rev-list --reverse 5197725fc..HEAD); do git checkout -q $c
  rm -f drivers/input/misc/aw86927.o
  make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 drivers/input/misc/aw86927.o
done                                  # → 5/5 rc=0，0 warning
# 2) 风格
perl scripts/checkpatch.pl --strict --no-tree /tmp/awv2/*.patch    # 4 枚 0E/0W/0C，0001 见上
# 3) binding
dt-doc-validate Documentation/devicetree/bindings/input/awinic,aw86927.yaml   # rc=0
# 4) 能否落到 linux-next（最小仓只放该文件 + binding）
git apply 0001..0005                  # → 5/5 OK，终态 +126 −23
```

## 投递前仍需拍板

1. **AW86937 无硬件**：本机两颗都是 AW86927/AW86938 系；AW86937 只有寄存器手册与厂商驱动依据，
   提交信息里已避免声称「本机实测」。若维护者要求实测证据，这块要先解释来源。
2. **0001 的 `Fixes:` 是否合适**：它修的是自 `df53055c540f` 起就错的既有值（7 V 名字对、值错），
   若维护者认为「vendor 值未必适用于所有板」，可退化成注释修正。
3. 固件波形能力后续是否单独立 RFC（本机确实在用厂商波形）。

## 投递记录（2026-10-27 21:29 +0800，用户批准）

- 通道：USTC SMTP（`git send-email`，`--thread`，cover letter + 5 枚）
- **To**：`linux-input@vger.kernel.org`、`Dmitry Torokhov <dmitry.torokhov@gmail.com>`
  **Cc**：`devicetree@vger.kernel.org`、Rob Herring、Krzysztof Kozlowski、Conor Dooley、`linux-kernel@vger.kernel.org`
- Message-ID（线程根 `-1`，各枚 `-2..-6`）：
  `20261027132929.242158-1..6-xiaqinghuan@mail.ustc.edu.cn`，6 封 `Result: 250`
- **归档复核（lore 独立检索，按发件人）**：
  `/linux-input/` **6/6**、`/linux-devicetree/` **6/6**（含 cover）、`/all/` 见 8 条本批记录
- 本地回读：Sent Items `[161]`–`[166]` 六封
- 待办：盯 review（Dmitry Torokhov）；有意见即出 v2，不自行加料
