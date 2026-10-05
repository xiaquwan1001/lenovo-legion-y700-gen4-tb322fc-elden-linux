# UEFI-RESOURCES-2026-10-05：TB322FC 间接引导层（G1-29）**可用资源清单** + 中文社区检索记录

> 承接 `BOOTCHAIN-2026-10-05.md`（机制判定）与 `TASKS.md` §1 **G1-29**。
> **本文件只记「资源与检索经验」**；本会话**未 clone、未构建、未上机、未写设备**。
> 结论一律以领域层为准（`TASKS.md` §1 G1-29、`RESOURCES.md` §1.6）；本文＝过程证据，只增不改。

---

## 0. 一句话结论

`BOOTCHAIN-2026-10-05.md` 判定的**缺环 =「一个 SM8750 可自举 UEFI 卷 + TB322FC 设备包」已不再是缺环**：
两样东西都在公开仓库里**完整存在**，构建脚本原生产出可直接 `fastboot boot` 的 **`lenovo-y700g4.img`**（Android boot 镜像 = BootShim + UEFI FD）。
⇒ Route A 的动作从「**自造**」变为「**取用 + 主机构建 + 设备侧零写盘验证**」。

---

## 1. 判定演进（相对 BOOTCHAIN-2026-10-05.md）

| 项 | BOOTCHAIN 原判定 | 本轮修正 | 证据 |
|---|---|---|---|
| SM8750 可自举 UEFI | 缺，需移植 | **已有**：Mu-Silicium `Silicon/Qualcomm/PakalaPkg` + `OnePlus/dodgePkg`（OnePlus 13，Status: Linux Boot ✅） | Mu-Silicium tree / `Status.md` |
| TB322FC 设备包 | 需移植 | **已有**：第三方已完成（`lenovo-y700g4`，518 文件，含真实内存映射/DT/patched DXE） | §2-A |
| 打包机制 | 需自写 arm64 壳 | **Mu 原生就产出 boot.img**（BootShim + FD 塞 boot kernel 槽） | §3 |

---

## 2. 资源清单（GitHub，均已用 API 核实存在；2026-10-05）

### A. 设备包 + 平台（主资源）

`sunflower2333/mu_wide_platforms` —— **fork of `Project-Aloha/mu_aloha_platforms`**（"fork of aloha with more platforms"）。
仓体 307 MB；创建 2026-07-19，最后 push 2026-10-01。作者相关 git 身份：**KancyJoe**（设备包）、**sunflower2333**（原厂备份）。

| 路径（仓库内） | 内容 | 备注 |
|---|---|---|
| `Platforms/PakalaPkg/` | SM8750 平台包（`Pakala.dsc` / `PakalaNoSb.dsc` / `PlatformBuild{,NoSb}.py`） | `TARGET_DEVICE` 选设备；`PcdSystemMemorySize=0x300000000`(12 GiB) |
| **`Platforms/PakalaPkg/Device/lenovo-y700g4/`** | **TB322FC 设备包，518 文件** | 见下明细 |
| `Platforms/PakalaPkg/Device/{oneplus-dodge,oneplus-erhai,xiaomi-piano,nubia-nx789j}/` | 同族 SM8750 设备包 | xiaomi-piano 有独立 CI 工作流 + 现存产物 |
| `Silicon/QC/Sm8750/QcomPkg/` | SM8750 平台 PEI/DXE（含 `PlatformPei/PlatformPeiLib.inf`） | |
| `Build/PakalaPkg/<device>.img` | **构建产物（Android boot 镜像）** | 由 `build_uefi.py` 生成 |

`lenovo-y700g4/` 明细（关键文件）：
- `Library/PlatformMemoryMapLib/PlatformMemoryMapLib.c` —— **真实 Y700g4/SM8750 内存映射**（DDR banks、UEFI FD @ `0xFF300000`、Gunyah/PIL 预留、MMU IO 区）
- `Library/PlatformConfigurationMapLib/` —— 设备配置映射
- `ACPI/DSDT.aml`、`DeviceTreeBlob/Linux/linux-y700g4.dtb`
- `Binaries/` —— Qualcomm DXE 全集（`ArmPkg` `EmbeddedPkg` `FatPkg` `MdeModulePkg` `QcomPkg` `RawFiles`）
- `PatchedBinaries/` —— 设备专属 patch：`ClockDxe` `FeatureEnablerDxe` `PmicDxeLA` `QcomWDogDxe` `SPMIDxe` `UFSDxe` `UsbConfigDxe`
- `APRIORI.inc`(空) `DXE.inc` `DXE.dsc.inc` `Defines.dsc.inc`(空) `PcdsFixedAtBuild.dsc.inc`
- `PcdsFixedAtBuild.dsc.inc`：framebuffer **1904×3040**；SMBIOS `Lenovo / Y700 / 4`（＝本机型）

### B. 原厂 UEFI DXE 备份（Binaries 的来源）

`Project-Aloha/UEFIFirmwareBackup` → `lenovo-y700g4/BOOT.MXF.2.5.1-00240.1-PAKALA-1/`（**480 文件**）。
README §SM8750 Pakala 表列：`Lenovo y700 gen4 = lenovo-y700g4`、`Oneplus 13 = oneplus-pjz110`、`Xiaomi Piano = xiaomi-piano`、`Redmagic 10 = redmagic-nx789j`。
提交 `3a48f03cf`（2026-04-21，sunflower2333）"sm8750: add y700 gen4 uefi files."。

### C. 备选基线

- `Project-Silicium/Mu-Silicium`：`Silicon/Qualcomm/PakalaPkg` + `Platforms/OnePlus/dodgePkg`（SM8750 参考端口，Status `Linux Boot ✅`）。boot 工具链见 §3。
- 该仓 `BootShim/BootShim.S`：`_Head: b _Start` + `REQUIRES_KERNEL_HEADER` 补 `ARM\x64` 头 ⇒ 即 BOOTCHAIN §2.1 所述「arm64 壳」机制。

### D. 同族可用性旁证

- Mu-Silicium `OnePlus 13 (dodge)`：UEFI Status `Display ✅ / Internal Storage ✅ / Touchscreen ✅ / Mass Storage ✅ / Linux Boot ✅`（WLAN/GPU/Camera 等仍 ❌，属 OS 侧，不影响引导层）。
- `mu_wide_platforms` CI：`sm8750_xiaomi_pad8p.yml` 工作流存在，产物 `uefi-images-plk110`（2026-07-19，9.7 MB，live）—— 证明 Pakala 家族工具链可跑通。
- ⚠️ 未见 `lenovo-y700g4` 专属 CI 工作流或产物；其可用性**无公开报告**。

---

## 3. 机制确认：Mu 原生产物＝Route A 要的 boot.img

`sunflower2333/mu_wide_platforms/build_uefi.py`（与 Mu-Silicium 同构）：
- `build_bootshim()` → `build_boot_shim.sh -b <base> -s <size>`；参数来自 `build_cfg/sm8750.json`（**`UEFI_BASE=0xFF300000`, `UEFI_SIZE=0x00400000`**）。
- `PostBuild.makeAndroidImage(...)`（`PlatformBuildNoSb.py` L284）→ 生成 `<device>_NOSB.img`；成功时产物在 **`Build/PakalaPkg/lenovo-y700g4.img`**。
- 机制 = **BootShim + `SILICIUM_UEFI.fd`**（可选 gzip）作为 **Android boot image 的 kernel 槽** → 被 ABL 当"长得像 Linux 内核的东西"加载 → UEFI BDS 起来。
- 设备发现：`build_uefi.py` 扫 `Platforms/<pkg>/Device` + `build_cfg/*.json` 自动匹配 ⇒ **`./build_uefi.py -d lenovo-y700g4`** 即可，无需手填平台。
- 构建环境：`Dockerfile`（ubuntu:24.04，**已预置 `mirrors.ustc.edu.cn`**）+ `build_setup.sh`（clang/llvm/gcc-aarch64-linux-gnu/lld/iasl/nasm/mono-devel…）。README：产物 `<target-device>.img`。

---

## 4. 中文社区检索记录（2026-10-05）

| 渠道 | 手段 | 结果 |
|---|---|---|
| **B 站** | 官方搜索 API（先取 cookie，见 §5） | 检索 `TB322FC / UEFI / uboot / 双系统 / Windows / 四代` 等 **命中均为无关主题或 Android 侧** |
| cn.bing.com | curl 直连 | 长尾/技术查询返回**「热门兜底」**（多组不同查询结果完全相同）⇒ 不可用 |
| 百度 / 搜狗 | curl 直连 | 被 SEO 污染（结果页为无关热点）⇒ 不可用 |
| 贴吧 / 酷安 / XDA / 4pda | curl 直连 | 403 / 404（反爬），未进入 |

**唯一像 UEFI 的线索已排除**：`BV1FNKtzLEmM《简简单单安排一下让拯救者y700四代用上Windows系统》`（UP 夏折腾1118，2025-06-25）。
其**评论区自证**是串流/远程 + Winlator 类（评论原话大意："Windows on ARM 为啥只支持到 K20 之类的老处理器、不支持 8E"、"小米9连y700二代，无线可以，有线却做不到"）⇒ **非本地 UEFI WoA**。

**中文社区实际在做（与本项目相邻，非 UEFI）**：
- 澎湃 OS 3/4 移植（免解锁 root）——"悲伤的压缩包"等，多条 2026 视频。
- 主线 Linux：`BV1stYX66EKG` GEEKiDoS《Y700 四代主线 Linux 7.2 KDE Plasma》（＝本仓 `geekidos-linux/` 同源）；`BV1q2N46WEXs` 三代 Linux（作者 **酷安@GUF296**）。
- 一加 Pad2Pro / 橘子系统移植；Winlator / 盖世游戏 跑 PC 游戏（Android 侧转译）。

⇒ **结论：中文社区没有 TB322FC 的独立 UEFI / U-Boot / Windows-on-ARM 产出**（可用资源仍是 §2 的 GitHub 仓库；其作者看起来也是中文开发者，但在中文字区未公开/未发教程）。

---

## 5. 检索经验（可复用，已同步全局记忆）

1. **B 站官方 API 可用**（web_search 全灭时的主力）：
   ```sh
   curl -s -c /tmp/ck.txt https://www.bilibili.com/            # 拿 buvid cookie
   curl -s -b /tmp/ck.txt -H 'Referer: https://search.bilibili.com/' \
     'https://api.bilibili.com/x/web-interface/search/type?search_type=video&keyword=<urlencoded>'
   # 详情 api.bilibili.com/x/web-interface/view?bvid=…；评论 /x/v2/reply?type=1&oid=<aid>
   ```
   不先取 cookie 直接调 search API → `code 412`（风控）。
2. **cn.bing.com 对长尾查询不可用**：会返回与查询无关的"热门兜底"（识别法：几组不同关键词结果页标题完全相同）。百度/搜狗被 SEO 污染。贴吧/酷安/XDA/4pda 反爬 403/404。
3. **中国站点 direct 与 proxy 均可 200**，但 **GitHub `api.github.com` 直连间歇失败（000/TLS timeout）→ 加重试**；`gh` CLI 走代理会 TLS timeout，用 `gh auth token` 取 token 后 `curl --noproxy '*' -H "Authorization: Bearer $TOKEN"` 更稳。
4. **GitHub 搜索 API**：未认证 `search/*` 限 10 req/min；带 token 可绕。**`search/code` 默认不索引 fork** ⇒ 核实 fork 内容要用 **`/repos/<o>/<r>/contents/<path>`**（本轮 `lenovo-y700g4` 就因此未被 code search 命中，但 contents API 可见）。
5. `web_search` 工具本轮后端全灭（Firecrawl/Brave/Exa/Tavily/BrightData/AnySearch 均 `curl 35 TLS unexpected eof`，Firefox 渲染超时）——本机代理 127.0.0.1:7897 故障时，**改用 bash + curl 直连**。

---

## 6. 缺口 / 风险（资源到手 ≠ 已解决）

1. **本设备无验证记录**：`lenovo-y700g4` 无 CI 工作流、无产物、无公开报告；同族 xiaomi-piano/dodge 可用只是旁证。
2. **容量档**：`PakalaNoSb.dsc` 默认 `PcdSystemMemorySize=0x300000000`（12 GiB）为本单元（16 GB）之外；按项目"不跨容量档"原则，**内存映射须按实际单元核对**（设备等价：唯一差异=容量）。
3. **四代 ABL 是否接受 BootShim 壳**：未验（BOOTCHAIN E4）。但机制同三代、且本机已证 ABL 接受自签 `boot.img` ⇒ 倾向可行。
4. **授权/合规**：仓库为 BSD-2-Clause（drivers 部分 GPLv2+）；`Binaries/` 为原厂 DXE 二进制，来源＝设备自身固件。
5. 构建需 **x86_64 主机**（明确不支持在 ARM 上构建）；本机满足。

---

## 7. 本会话边界（勿越界）

- 本会话**只做资源收集 + 经验记录**：**未 clone 仓库、未构建、未上机、未改任何分区/设备**。
- 下一步（另会话）：主机构建 `lenovo-y700g4.img` → 设备侧 **E4（零写盘 `fastboot boot`）** 判 ABL 接受性 → 再谈持久/刷入。
