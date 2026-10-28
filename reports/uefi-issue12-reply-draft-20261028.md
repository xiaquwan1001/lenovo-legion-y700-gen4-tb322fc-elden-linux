# UEFI issue #12 回帖 — 2026-10-28（L4 lane）

对象：`sunflower2333/mu_wide_platforms#12`
（`SM8750 (Pakala) Lenovo Y700 Gen4: vendor UFSDxe fails UEFI_DEVICE_ERROR — which platform config is it missing?`）

状态：**草稿就绪 → 已发布**（2026-10-28T11:04:46Z，评论 URL 见 §4）。

## 0. 起草依据（本次独立复核的取证）

| 事实 | 数值/结论 | 证据等级 |
|---|---|---|
| 原厂 `uefi.elf` | 5 242 880 B，sha256 `fc68d2f9…`（`~/下载/tb322fc/`） | 已证（本轮重算） |
| 内嵌 FV 位置 | FFS `9e21fd93-9c72-4c15-8c4b-e77f1db2d792` @ file offset `0x4e238`，GUID_DEFINED LZMA 段，DataOffset=24 | 已证（本轮重算） |
| 解出 FV | 4 247 560 B，sha256 `657940ca74a667aaa518038f2d4bfe7de04205ca883574e0c46172df002962d9`，**与 `reports/artifacts/uefi-dxe-20261024/vendor-dxe-fv.bin` 逐字节相同** | 已证（本轮重算，闭合了 10-24 的产物来源链） |
| 厂商 UFSDxe | GUID `0d35cd8e-97ea-4f9a-96af-0f0d89f76567`，PE32，**151 552 B**，sha256 `fa561bf11eb18f142b128f0335973f6c4a8d0241747ea581d5b3a56d601878d2` | 已证（从 FV 重新解出后 `sha256sum` 与 artifact 一致） |
| Mu y700g4 未打补丁件 | `Platforms/PakalaPkg/Device/lenovo-y700g4/Binaries/QcomPkg/Drivers/UFSDxe/UFSDxe.efi`，151 552 B，sha256 `dac620ac…`，**与厂商件只差 6 字节**，全部落在内嵌 build 路径串（`mp250526` vs `mp251201`，偏移 `0x23d21`/`0x23d30..33`/`0x23d3b`） | 已证（`cmp -l`） |
| Mu y700g4 补丁件 | `PatchedBinaries/UFSDxe.efi`，151 552 B，sha256 `00ae059f…`，相对厂商件差 **32 字节 = 3 段（`0xa998` 8 B / `0x114c4` 16 B / `0x1b080` 8 B）** | 已证（`cmp -l` 分组） |
| 「159 744 B / KaanapaliLAA 26310」代次差 | 该尺寸在 Mu 树里**只存在于** `Platforms/KaanapaliPkg/Device/oneplus-plk110/{Binaries,PatchedBinaries}`（`2249bfbc…` / `d08a85c9…`）与 `KailuaPkg/Device/oneplus-salami`（`c19ec196…`）；**y700g4 设备包不用它** ⇒ 本机不适用 | 已证（`find`+`sha256sum`+`strings`） |
| BootShim cache 维护 | 已补 `dc civac`（覆盖 `UEFI_BASE..+UEFI_SIZE`）→ `dsb sy` → `ic iallu` → `dsb sy` → `isb`（`patches/uefi/0001-…`，源码 `BootShim/BootShim.S` L51–67 当前工作树即为该版本） | 已证 |
| 补后上机结果 | 交棒后 USB 静默 60 s、屏幕全程联想 logo、~82 s 回落 stock Android `_a` 槽 ⇒ **仍是同一早死点** | 已证（`reports/uefi-n2-v0-attempt-20261026.md`） |
| `UEFI_BASE=0xFF300000` | ABL `Final RAM Partitions` 列 `0xFF300000 / 0x500000`；在机内核 `ff300000-ff7fffff : System RAM` | 已证（`reports/uefi-control-experiment-20261027.md`） |
| ABL logfs 取证限制 | `/dev/sde68`（FAT12 `LOGFS`，`UEFILOG1.TXT` 64 KiB）**每次启动重写** ⇒ 失败那次的日志被回落启动覆盖 | 已证 |
| UFSDxe depex / 顺序 | `UFSDxe.depex` = `06 08`（TRUE，无自带顺序约束）；`APRIORI.inc` 第 **76** 行 | 已证（`xxd` + `grep -n`） |
| 早死点可见性 | `USE_UART_{GENI,DM}_FOR_SERIAL_OUTPUT=0`、无 `UsbSerial*Dxe`（ABL 侧除外）、NoSb 仅 `USE_SCREEN_FOR_SERIAL_OUTPUT=1`（依赖 GOP/DXE） | 已证（`reports/uefi-control-experiment-20261027.md`） |

## 1. 起草取舍（避免未证结论）

- **不写**「Mu 缺提供者」：`reports/uefi-runtime-table-provider-20261024.md` 已把 NpaDxe/ScmDxe/HWIODxe 三个协议提供者全部定位到同 FV 且在 Mu 构建里齐全，该假设基本排除。
- **不写**「已定位根因」：`UFS.c+2326` 是 SMMU 配置失败、`0x13224` 是运行期表解引用，两层独立，**均未修**。
- **不写**「代次差是原因」：本轮证明本机 Mu 与厂商件是同一构建（仅 build 路径串差 6 字节），故把「159 744 B 代次差」降级为**提问选项 (a)**，并明说本机不适用。
- 对作者新给的「Link State 处于 Sleep，写个 tiny DXE 拉起来」：**接受为可行方向**，但要求给出 ① 层级判据（DEBUG 构建下 `Start EBS` 之后第一行）、② tiny DXE 的排序机制（depex / APRIORI），因为 UFSDxe 的 depex 是 TRUE、位置在第 76 行。
- 只陈述**已证**事实；对 SMMU 与 link state 的关系用提问形式（「link-state 修复是否也覆盖该路径」），不下判断。

## 2. 与本地报告的对照（issue 现状）

| 项 | 结果 |
|---|---|
| issue 状态 | `OPEN`，标题同上，`createdAt 2026-10-05T09:25:23Z`，`updatedAt 2026-10-28T04:27:34Z` |
| 评论总数 | 4 |
| 我方上一条 | 2026-10-28T04:14:57Z（ABL RAM 表 + 无早期可见性 + 三条请求） |
| 作者新回复 | **2026-10-28T04:27:34Z**，1 条，60 字符：「UFS问题是Link State处于Sleep状态，你让AI写个tiny dxe用来把link state拉起来不就行了」 |
| 是否有新信息 | **有**：首次给出方向性假设（link state = Sleep）+ 建议形状（tiny DXE 拉起 link） |
| 查询时刻 | 2026-10-28 18:51 +0800（`gh issue view 12 --repo sunflower2333/mu_wide_platforms`） |

## 3. 英文回帖草稿（定稿全文）

见 `out/mail-20261028/uefi-issue12-reply.txt`（纯 ASCII，Markdown，GitHub issue 风格）。

结构：
1. 接受「link state = Sleep」为具体方向；先给一条改变前提的实测：**本机 Mu 用的 UFSDxe 就是厂商 UFSDxe**（6 字节差异全在 build 路径串）。
2. 据此请对方确认「firmware version dependent / special patch」指的是 (a) UFSDxe 代次 / (b) 运行期数据表 / (c) link state+PHY 三者中的哪一个；并说明 159 744 B/26310 那枚在本机设备包里根本不存在。
3. 指出我方两条失败签名里 **`UFS.c+2326` 是 SMMU 配置失败**，与 link state 是两层；问 link-state 修复是否也覆盖它。
4. 说明仍缺**层级判据**，并列出已排除项（BootShim cache 维护已补、上机仍同一早死点；`UEFI_BASE` 可用；无 UART/USB serial；屏幕输出依赖 GOP）。
5. 对 tiny DXE 追加两个工程问题：DEBUG 构建下 `Start EBS` 之后应出现的第一行；tiny DXE 的排序方式（depex 还是 `APRIORI.inc` 插队，UFSDxe 当前在 76 行、depex=`06 08`）。

## 4. 发送记录

| 项 | 值 |
|---|---|
| 发布方式 | `gh issue comment 12 --repo sunflower2333/mu_wide_platforms --body-file out/mail-20261028/uefi-issue12-reply.txt` |
| 评论 URL | https://github.com/sunflower2333/mu_wide_platforms/issues/12#issuecomment-6467336320 |
| 发布时间 | **2026-10-28T11:04:46Z**（= 19:04:46 +0800） |
| 回读校验 | `gh issue view 12 --json comments` 末条 = `xiaquwan1001` / `2026-10-28T11:04:46Z` / 正文 5 423 字符，与本地文件一致 |
| issue 状态 | 仍 `OPEN`（发布后 `updatedAt` 更新） |
| 凭据 | `gh auth status`：`xiaquwan1001`（keyring，scopes `gist, read:org, repo, workflow`）⇒ 权限充足，无失败 |

### 发布前自检（逐项过）

- 纯 ASCII：`LC_ALL=C grep -c '[^ -~]'` = **0**（105 行）。
- GUID / sha 逐字核对：`0d35cd8e-97ea-4f9a-96af-0f0d89f76567`、`fa561bf1…878d2`（= `vendor-UFSDxe.efi` 实测）、`657940ca…62d9`（= `vendor-dxe-fv.bin` 实测）、`fc68d2f9…`（= `~/下载/tb322fc/uefi.elf` 实测）、`dac620ac…` / `00ae059f…`（= 树内两件实测）。全部命中，无编造。
- 无未证结论：仅列 (a)/(b)/(c) 三选项提问，未声称根因；「代次差」明确降级为不适用于本机。
- 引用完整：`uefi.elf` 尺寸+sha、FFS GUID+偏移、DataOffset、解压尺寸、模块数与 UFSDxe 尺寸/sha、差异字节偏移、depex 值、`APRIORI.inc` 行号、ABL RAM 表数值、`System RAM` 区间——均可从本机文件/日志复现。
- 未写「已解决」：明确写“was not the (only) gap”“cannot tell … from …”。
