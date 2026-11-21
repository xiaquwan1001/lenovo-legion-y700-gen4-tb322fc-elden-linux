# Mobian 上游化第一件可交付 + 6.18 LTS 可落性静态评估 — 2026-11-21

> 性质：**纯静态 / 离线**。没整编内核、没碰设备、没发信、没写 Mobian 仓。
> 前置 = `reports/distro-upstream-feasibility-20261121.md`（三家候选与政策判定，Mobian 唯一可行）。
> 本文只回答两件事：① 6.18 LTS 能不能承载本机功能面（逐类给证据）；② 不碰内核的那两件可交付物长什么样（已落盘）。

---

## 0. 一页结论

| 问题 | 结论 | 决定性的数字/证据 |
|---|---|---|
| **6.18 LTS 能直接承载 elden 吗** | **不能**。不是「打几条补丁」，是「把一个 SoC 三年的 bringup 搬回去」 | v6.18 的 `sm8750.dtsi` = **4083 行**，我们在机线（7.4-rc3）= **7484 行**；USB 节点 **v7.0** 才进上游、显示（mdss）**v7.1**、GPU **v7.4** ⇒ 纯 6.18 内核**没有 USB、没有显示、没有 GPU、没有摄像头** |
| 板 DTS 能落 6.18 吗 | 不能（结构冲突） | 在机功能板 DTS（1329 行）引用 **18 个 label 在 v6.18 的 `sm8750.dtsi` 里不存在**，其中 **13 个是 SoC 节点**（`gpu`、`mdss`+6 个 dsi/phy、`usb`+4 个 phy/dwc3），另 5 个是 PMIC label（在 PMIC dtsi 里有，不算真缺）；逐条见 §1.1 |
| LTS 缺口是不是「Mobian 第一件 MR」的硬阻塞 | **不是（本轮新证据，推翻先前默认读法）** | Mobian 自己的 `qcom-linux` 仓里**在维护非 LTS 分支**：`mobian-sdm670-7.3`（2026-11-17）、`mobian-sc7280-7.3`（2026-11-19）、`mobian-sm6350-7.2`、`mobian-sdm845-7.2`、以及 `wip/tiol/7.4-sdm845` ⇒ 「只收 LTS」是对 **stable/testing 发布**的口径，**staging/分支层面 7.x 照跑** |
| 那第一件 MR 应该是什么 | **`mobian-sm8750-7.4` 分支 + droid-juicer 配置**（先不追 6.18） | 见 §4 |
| 本轮落盘 | `patches/distro/mobian-20261121/droid-juicer/{lenovo,elden.toml,README.md}`、`.../mobian-recipes/{wip.toml.snippet,README.md}` | 4 个文件，TOML 两个都过 `tomllib` |

---

## 1. §1 — 6.18 LTS 可落性：逐类评估

### 1.0 取证方法与口径（先说清哪些是「逐行核对」哪些是「文件级推断」）

- `build/elden-tree` 头 = `aebb727447` = **v7.4-rc3**（纯上游，payload 不在 git 里）。载荷面 = `patches/{upstream,local,dt}/` + `patches/local/20261113-daily-worktree/0001-*.patch`（38 文件 / +8976 −15 的在机工作区快照）。
- **v6.18 树取法**：`git fetch origin refs/tags/v6.18` 实测**失败**（`rc=124`，git.kernel.org 不支持 `--filter`，全量 tag 抓取不可行）⇒ 改用 **cgit plain 端点逐文件取真内容**：
  ```bash
  B=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain
  curl -sS -o /tmp/x "$B/<path>?h=v6.18"; echo $?   # 404 = 文件不存在，200 = 取到逐行内容
  ```
  （`curl` 直连 git.kernel.org 可用；**salsa 需 `--noproxy '*'`**，见 §4。）
- **判定分级**：`逐行` = 我把 v6.18 的文件内容取下来数过/看过；`文件级` = 只按「文件存在与否 / 命中计数」推断，没逐行读。
- 追加事实源：`out/boot-elden-vk192.img` 内嵌 DTB（= **在机** DT 的逐字状态，解出 `/tmp/vk192.dts`）。

### 1.1 逐类表

| 类 | v6.18 现状（证据 + 级别） | 我方件（hunk 数） | 判定 |
|---|---|---|---|
| **DTS 板件** | `sm8750-lenovo-elden.dts` = **404**（文件级）；`sm8750.dtsi` 4083 行（逐行）。**在机功能板 DTS 引用但 v6.18 dtsi 没有的 label = 18 个**：`gpu`、`mdss`、`mdss_dsi0/0_out/0_phy`、`mdss_dsi1/1_out/1_phy`、`usb`、`usb_dp_qmpphy`、`usb_dp_qmpphy_out`、`usb_dwc3_hs`、`usb_hsphy`（其余 5 个 `pm8550*`/`pmih0108`/`pon_*` 在 PMIC dtsi 里有，不算缺）（逐行） | 上游在档件 = **129 行骨架**（`patches/upstream/board-dts-single-20261113-sent-20261117/0001`，2 hunk/+132；patchwork `14991580` state=new）；**在机功能板 = 1329 行**（`Y700-elden-linux/linux/…/sm8750-lenovo-elden.dts`） | **结构冲突**：板文件本身能贴，但它依赖的 12 个 SoC 节点在 6.18 里不存在 |
| **regulator wl2868c** | `drivers/regulator/wl2868c.c` = **404**、binding `willsemi,wl2868c.yaml` = **404**（逐行核对=文件不存在） | `patches/upstream/wl2868c-v12-20261117/`：binding **2 hunk/+107**、driver **4 hunk/+318** | **需补丁，量级小、无结构冲突**（regulator core API 稳定）。注意：它已合入 `regulator.git for-7.5`（`84e67d2ee13f`+`602f57223457`），但**6.18/7.4 都没有** |
| **dwc3** | `drivers/usb/dwc3/core.c`：**`mux` 命中 0**（逐行）⇒ v10 3/3 的 mux-controls 机制要从零补；`drivers/usb/roles/class.c` 存在（200，文件级）；**6.18 的 sm8750.dtsi 没有 `usb@` 节点**（v7.0 才有，逐行按 tag 比） | `patches/upstream/dwc3-v10-20261120/`：1/3 binding 2 hunk、2/3 roles **3 hunk**、3/3 dwc3 **18 hunk / 4 文件 / +487** | **需补丁 + 依赖 v7.0 的 DT**：驱动侧可补，节点侧要搬 v7.0 的 `usb` + QMP combo PHY + HS PHY（6.18 已有 `phy-qcom-qmp-combo.c`，18 处 sm8750 命中 ✓） |
| **camss** | `drivers/media/platform/qcom/camss/camss.c`：**`sm8750` 命中 0**（逐行，v6.18→v7.4 全为 0）；`phy-qcom-mipi-csi2-3ph-dphy.c` 只在 **v7.4-rc3** 出现（文件级，逐 tag 探活）；6.18 dtsi 无 camss 节点（逐行） | 在机 camss 节点来自**本地 patchset**（`patches/local/20261115-dl-cam-hw-interfaces`，在机 DTB 里 16 处 `camss/csiphy` 命中）；上游件 = 我们的 csiphy 2.4 delta（**4 hunk / +142**，`patches/upstream/camss-csiphy-24-v2-20261117`）+ Qualcomm 的 camss v6（7 枚，仍在评审） | **结构冲突（最深）**：整栈（camss 平台驱动对 SM8750 + 3ph DSI/CSI PHY 驱动）7.4 才齐；6.18 无从补起 |
| **fastrpc** | v6.18 的 `sm8750.dtsi` **只有 1 个 `fastrpc {`**（= cdsp，且已带 `qcom,non-secure-domain`）（逐行）；**ADSP 的 fastrpc 节点 v7.0 才出现**；我们补丁的上下文 `memory-region = <&adsp_rpc_remote_heap_mem>` 的 label 在 6.18 也不存在（逐行） | `patches/upstream/sm8750-adsp-nonsecure-20261107/0001` = **1 hunk / +1 行**（但上下文对不上 6.18） | **需重做**：M10 那 1 行在 6.18 是空转（没有节点可打），真正要搬的是 v7.0 的 ADSP fastrpc 节点 + 它依赖的 `adsp_rpc_remote_heap_mem` 内存区 |
| **mdss / dpu** | `dpu_12_0_sm8750.h` 在 v6.18 **存在**（58 处 sm8750 命中，逐行）；`msm_mdss.c:578` 已有 `{ .compatible = "qcom,sm8750-mdss", .data = &data_57k }`（逐行）；`dispcc-sm8750.c` 存在（24 命中，逐行）；**但 dtsi 里没有 `mdss`/`display-subsystem`**（v7.1 才有，逐行按 tag 比） | 我方 M8（`m8-mdss-v5-20261114`：binding 2 hunk / mdss 2 hunk / dts 1 hunk，净 +13/−16）+ M6 DSI PLL（1 hunk / +3） | **需补丁（小）+ 依赖 v7.1 的 DT 块**：v7.1 的 mdss 块在 7.4 里是 **405 行**（`mdss` 到 `mdss_dsi...` 整段）⇒ 补丁不大，搬 DT 是大头 |
| **audio tplg** | tplg 是**固件**（`/lib/firmware/qcom/sm8750/*-tplg.bin`），与内核版本无耦合；6.18 有 `sound/soc/qcom/qdsp6/{q6apm.c,q6apm-dai.c}`（200，逐行取到 851 行）+ dtsi 里 lpass 宏/soundwire（33 处 lpass 命中，逐行） | 自编件：`scripts/audio-tplg/` + `scripts/audio-ucm/`；本地 hack 3 枚（`patches/0005,0009,0011`，非上游件） | **无版本冲突**；但 3 枚 q6apm 改动是本地策略件（按 `reports/upstream-policy-20261013.md` 不进上游包），6.18 上需重做 |
| **firmware 清单** | 纯用户态（`droid-juicer` + 我们的 `elden-firmware` 包） | 见 §2 | **与内核版本无关**，可独立推进 |
| （附带）触觉 aw86927 | 6.18 有 `drivers/input/misc/aw86927.c`（846 行，逐行），**无 aw86937/aw86938 字串**（逐行 grep=0） | `patches/upstream/haptics-v3-20261118/` 6 枚：1+1+1+4+6+12 = **25 hunk** | 需补丁，量级中；无结构冲突 |

### 1.2 「6.18 可落性」的量化

- **DT 面**：`sm8750.dtsi` 6.18→7.4 净增 **+3401 行**（7484−4083）；其中 USB 块 89 行、mdss 块 405 行、GPU 块 169 行（7.4 现查），这只是**块大小**，相随的驱动/时钟/PHY/DTS 依赖更多。
- **驱动面**：`gpucc-sm8750.c` v7.1 才有；`camcc/videocc/cambistmclkcc-sm8750.c` v7.0 才有；`adreno a8xx_catalog.c`（A830）**v7.4-rc3** 才有；mipi-csi2 3ph PHY **v7.4-rc3** 才有。
- **⇒ 结论**：6.18 上要跑本机，等于把 **v7.0 + v7.1 + v7.4 三个 release 的 SM8750 使能** 搬回去。这不是「LTS 重基 5–8 人日」（可行性报告给的量级），而是 **SoC bringup 级的一次倒灌**，工期与风险都远超一个发行版 MR 的合理前置。
- **⇒ 因此本次评估的实际价值不是「怎么上 6.18」，而是「证明不该在 6.18 上开工」**，并把决策推回到 §4 的分支路线。

---

## 2. §2 — droid-juicer 配置（已落盘，含启动阻塞规避）

产物：`patches/distro/mobian-20261121/droid-juicer/`
- `lenovo,elden.toml` —— 设备配置（文件名 = DT compatible，判据见下）
- `README.md` —— 逐字段判据来源 / 分区清单 / 改名依据 / **启动阻塞规避** / 可复跑判据

关键事实（全部有判据，README 里逐条给了复跑命令）：

1. **文件名与身份**：`lenovo,elden.toml`，取值来自**在机 DTB 现读** `compatible = "lenovo,elden", "qcom,sm8750"`（从 `out/boot-elden-vk192.img` 抽出 FDT 后 `dtc`）。
2. **分区清单用本机 GPT 实名**：`modem_a`（adsp/cdsp/tmel）、`bluetooth_a`（brh 4 件）、`super`→`vendor_a`（GPU/触屏/ACF）、`persist`（传感器 registry）；GPT 名字从 EDL 采集的 `backup/fw/tb322fc-edl/gpt_main{0,4,5}.bin` 逐项解析，**不是照抄别人的 device 名**。`partition` 写基名即可（droid-juicer 自动试 `_a`/`_b`）。
3. **三个形态冲突（这是这件的真正内容，配置本身解决不了）**：
   - **C1 `.mdt` 被 squash 成 `.mbn`**（`firmware.rs:305-308`）⇒ 上游形态是单文件；我们下游板 DTS 现在写 split（在机 DTB 现读 `qcom/sm8750/adsp.mdt` + `adsp_dtb.mdt`）⇒ **换 Mobian 前要么改 DT 成 `.mbn`（上游 `sm8750-mtp.dts` 就是），要么自带分段固件包**。
   - **C2 拼装件 droid-juicer 不做**：`ath12k/PEACH/hw2.0/board-2.bin`（2253964 B）= `bdwlan.e01..e41` 拼装 ⇒ 只能留在 `elden-firmware` 包；配置只给 `board.bin`（125420 B，= `bdwlan.elf`）。
   - **C3 自定/自编资产不是「抽取」**：`awinic/y700-gen4-haptic.bin`（vendor 无同名牌）、`qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin`（自编）⇒ 必须我方包分发。
4. **启动阻塞规避（`PITFALLS` #691/#693/#694 的直接后果）**：本机的 `droid-juicer.service` 在自建 GPT 上**恒 running**（`graphical.target` 永不 active），live 上 `disable --now` 后 ~40 s **整机掉电**。所以 elden 上必须：**首启 masked**、抽取改在**镜像构建/安装器阶段离线做**（`droid-juicer --config …`）、万一跑了先 `stop` 单独验证再 `mask`、复发走 cmdline `systemd.mask=` 零写盘救援舱。README §3 给了完整顺序与命令。
5. **机器校验**：`tomllib` 解析 OK；**23 个源文件条目逐个在本地采集件里命中**（唯一例外 = `vendor/etc/sensors/sns_reg_config`，本地未采集，已标 `TODO(需上机确认)` 并给了核对命令）。

---

## 3. §3 — mobian-recipes `wip.toml` 草稿（已落盘）

产物：`patches/distro/mobian-20261121/mobian-recipes/`
- `wip.toml.snippet` —— 可直接追加到上游 `devices/qcom/configs/wip.toml`（或拆成 `sm8750.toml`）
- `README.md` —— 字段 → 取值 → 判据表 + 复跑解析命令 + 两个 `TODO(需上游确认)`

取值全部来自**在机 boot.img 头现解析**（`out/boot-elden-vk192.img`：`kernel 0x8000 / ramdisk 0x1000000 / tags 0x100 / pagesize 4096 / second 0`，与上游已填样例 `sm7150.toml` 逐字段相同），**没有猜任何一个数**：

| 字段 | 值 | 判据 |
|---|---|---|
| `chipset` | `sm8750` | DT 文件名规则 + 板 DTS 名 |
| `[[device]]` | `vendor="lenovo"`, `model="elden"` | 在机 DTB compatible |
| `[bootimg]` | `base 0x0 / kernel 0x8000 / ramdisk 0x1000000 / second 0 / tags 0x100 / pagesize 4096` | boot.img 头现解析（命令在 README §1） |
| `[bootimg].version/.dtb` | **未写** | `TODO(需上游确认)`：我方镜像是 `header_version=2` 但 `dtb_size=0`（DTB 附在 kernel 后），Mobian 流程是否接受 `version=2`+`dtb=0x0` 未验证 |
| `append` | **未写** | `TODO(需上游确认)`：`elden_root=LABEL=linux17`、`androidboot.slot_suffix=_b` 是本机分区/槽位产物，Mobian 侧由镜像流程决定 |

`tomllib` 解析 OK（`chipset/bootimg/device` 三段，值见上）。

---

## 4. §4 — 我方欠什么 + 下一步

### 4.1 本轮新增的、改变路线判断的两条硬事实

1. **6.18 不可落**（§1）：差的不是一个补丁串，是 3 个 release 的 SoC 使能。
2. **Mobian 自己在跑 7.x 分支**（本轮现查 salsa API）：
   ```bash
   curl -sS --noproxy '*' "https://salsa.debian.org/api/v4/projects/Mobian-team%2Fdevices%2Fkernels%2Fqcom-linux/repository/branches?per_page=100"
   # 命中（含 "-7."）= 12 条：mobian-sc7280-7.1/7.2/7.3、mobian-sdm670-7.0/7.1/7.2/7.3、
   #       mobian-sdm845-7.1/7.2、mobian-sm6350-7.1/7.2、mobian-milos-7.2
   # 另有 wip/tiol/7.4-sdm845（全量分支列表里，命名不带 "-7."）
   # 活跃度：mobian-sdm670-7.3 @ 2026-11-17「Linux 7.3.5」、mobian-sc7280-7.3 @ 2026-11-19「d/config: sync with Debian's 7.3 configs」
   ```
   ⇒ 「Mobian 只收 LTS」只在**发布（stable/testing）**口径成立；**分支层面 7.x 是常规操作**，我们该提的是 `mobian-sm8750-7.4`（staging 形态），不追 6.18。
   *未验证*：`debian/` 打包目录在抽查的 4 个分支根上都取不到（404）⇒ 打包件的确切落点标 `TODO(需上游确认)`，别在 MR 里瞎写。

### 4.2 我方欠的件（按能不能今天做排序）

| # | 欠什么 | 现状/判据 | 阻断谁 |
|---|---|---|---|
| 1 | **板 DTS 的固件名从 split 改单文件**（`qcom/sm8750/adsp.mdt` → `adsp.mbn`；cdsp 同） | 在机 DT 现读 split；droid-juicer 只会产 `.mbn`（C1） | droid-juicer 落地的完整性；也影响上游化（上游 mtp/qrd 用 `.mbn`） |
| 2 | **`board-2.bin` 拼装脚本落仓**（`bdwlan.e01..e41` → 2253964 B） | 现在只存在于历史手工操作；`elden-firmware` 包里有成品但无生成器 | WiFi 在新镜像上的完整性 |
| 3 | **`awinic/y700-gen4-haptic.bin` 的来源/许可**：自定资产，vendor 无同名牌 | `backup/fw/README.md` 自认「待核」 | 触觉在新镜像上可用；也决定这件能不能进任何发行版包 |
| 4 | **板 DTS 进树**（patchwork `14991580` 仍 new，7 天无回复） | `reports/upstream-recheck-20261120.md` | Mobian 侧 dtb 只能来自我们的内核分支；也阻断 Nura 的 `deviceinfo_dtb` |
| 5 | **内核分支形态**：从「设备树 + 局部补丁」变成 `mobian-sm8750-7.4`（Debian packaging） | 上游 `qcom-linux` 有 7.3 分支样例可抄；`debian/` 位置未定（TODO） | 整件 Mobian 编译 |
| 6 | **`sm8750.dtsi` 的 3 件 DT quirk 尚未上游**（`adsp` fastrpc non-secure、`compute-cb` stream-ID mask、ramoops `record-size`） | M10 v3 在档 new；另两件只在 `patches/dt/` | 6.18 议题降级后它们才真正重要（跟板件一起走） |

### 4.3 下一步：**一条命令**（可复跑，回答「第一件 MR 的落法是 7.x 分支还是 LTS」）

```bash
cd ~/y700-elden && curl -sS --noproxy '*' "https://salsa.debian.org/api/v4/projects/Mobian-team%2Fdevices%2Fkernels%2Fqcom-linux/repository/branches?per_page=100" \
 | python3 -c "import json,sys;b=[x['name'] for x in json.load(sys.stdin)];print('7.x 分支:',[x for x in b if '-7.' in x]);print('6.18 分支:',[x for x in b if '6.18' in x])"
# 现测（2026-11-21 12:5x）：7.x 分支 **12** 条（含 sdm670-7.3 / sc7280-7.3 本周仍在提交）；6.18 分支 **10** 条（5 个 mobian-*-6.18 + 5 个 wip/tiol/6.18-*）
```

判读：若目标是「先让 Mobian 能出 elden 镜像」⇒ 照 `mobian-sdm670-7.3` 的形状开 `mobian-sm8750-7.4`；6.18 只在「Mobian 明确要求进 stable/testing」时才重新评估（本文 §1 已给出届时的工作量上界：≈3 个 release 的 SoC DT+驱动倒灌）。

---

## 5. 复跑清单（本文所有数字的来源命令）

```bash
# a) v6.18 文件存在性（404=无）
B=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain
for f in drivers/regulator/wl2868c.c Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml \
         arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts drivers/phy/qualcomm/phy-qcom-mipi-csi2-3ph-dphy.c; do
  echo "$(curl -sS -o /dev/null -w '%{http_code}' "$B/$f?h=v6.18")  $f"; done     # 全 404

# b) SoC 节点进入上游的时间点（行数/mdss/usb/gpu 命中）
for t in v6.18 v7.0 v7.1 v7.2 v7.3 v7.4-rc3; do
  s=$(curl -sS "$B/arch/arm64/boot/dts/qcom/sm8750.dtsi?h=$t")
  echo "$t lines=$(wc -l <<<"$s") mdss=$(grep -c mdss <<<"$s") usb=$(grep -c 'usb@' <<<"$s") gpu=$(grep -c 'gpu@' <<<"$s") fastrpc=$(grep -c 'fastrpc {' <<<"$s")"
done

# c) 在机 DT 的 18 个缺失 label（需先抽 DTB，见 §4.1/README 的 python 片段）
grep -oE "^&[a-zA-Z0-9_]+" Y700-elden-linux/linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts | tr -d '&' | sort -u > /tmp/board.txt
curl -sS "$B/arch/arm64/boot/dts/qcom/sm8750.dtsi?h=v6.18" | grep -oE "^[[:space:]]+[a-zA-Z0-9_]+: " | tr -d ' \t:' | sort -u > /tmp/l618.txt
comm -23 /tmp/board.txt /tmp/l618.txt     # 18 行（含 5 个 PMIC label，见 §1.1 注）

# d) 我方每个补丁的 hunk 数
for p in patches/upstream/wl2868c-v12-20261117/v12-000*.patch; do
  echo "$(basename $p) files=$(grep -c '^diff --git' $p) hunks=$(grep -c '^@@' $p)"; done

# e) Mobian 自己的 7.x 分支（§4.1 第 2 条）
curl -sS --noproxy '*' "https://salsa.debian.org/api/v4/projects/Mobian-team%2Fdevices%2Fkernels%2Fqcom-linux/repository/branches?per_page=100"
```

■ 结束（静态/离线；未整编内核、未碰设备、未发信、未写 Mobian 仓、未改 `out/`、`patches/` 既有件）
