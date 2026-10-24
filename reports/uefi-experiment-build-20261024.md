# G1-29 UEFI 线：实验镜像构建（只构建，不上机）

日期：2026-10-24
目标：构建 Lenovo Y700 四代（TB322FC / SM8750P / PakalaPkg）NOSB 镜像，把 UFSDxe 替换为厂商 151552 B 版本，供用户手动 fastboot boot 实验。

## 0. 结论（摘要）

- 已克隆 xiaquwan1001/mu_wide_platforms（gh-proxy 成功），commit `6b6ac42a7edcdef984497efe2280db5309eb0001`（2026-10-05 11:51 +0800，ci: allow DEBUG build type…），仓库 1.0G。
- UFSDxe 替换已完成：`PatchedBinaries/UFSDxe.efi` 由 Mu 版 `00ae059f…`（151552 B）换成厂商版 `fa561bf1…`（151552 B），替换点即上游 PatchedBinaries 机制（UFSDxe.inf `PE32|UFSDxe.efi|*` 指向它），无需改 .inf。
- **关键取证**：lenovo-y700g4 的 Mu UFSDxe 本身就是 151552 B，与厂商版同尺寸不同 sha —— 与「Mu 用的 UFSDxe 是 159744 B」的旧结论冲突；159744 B 的 UFSDxe 只出现在 KaanapaliPkg/oneplus-plk110 与 KailuaPkg/oneplus-salami。即 y700g4 设备包的 UFSDxe 来自 nubia-nx789j 同代 Pakala 提取，并非 159744 B 那枚。
- 构建环境就绪，见 §2/§9；UFSDxe 与 RmVmDxe 均已替换（§3/§RmVmDxe）。

## 1. 仓库获取（7-mu-lenovo）

```
cd build/uefi-woa-prep/repos
git clone --depth 1 https://gh-proxy.com/https://github.com/xiaquwan1001/mu_wide_platforms 7-mu-lenovo
```
- commit：`6b6ac42a7edcdef984497efe2280db5309eb0001  2026-10-05 11:51:56 +0800  ci: allow DEBUG build type via workflow_dispatch input`
- remote：`https://gh-proxy.com/https://github.com/xiaquwan1001/mu_wide_platforms`，工作树 `du -sh` = **1024M**
- 未使用 sunflower2333 备胎（xiaquwan1001 克隆成功；本地另有 5-mu_wide_platforms = sunflower2333@3e1d0520，2026-10-01，其子模块未初始化）。
- 为子模块走镜像，设了 `git config url."https://gh-proxy.com/https://github.com/".insteadOf "https://github.com/"`（仓库本地）。

## 2. 构建环境

- stuart：`python3 -m pip install --user --break-system-packages -r pip-requirements.txt`（python3.14，PEP668 需 --break-system-packages；venv 方案失败：缺 python3.14-venv 包）。验证：`python3 -c "import edk2toolext"` OK；`~/.local/bin/stuart_{setup,update,build}` 就位。
- mono 已在 `/usr/bin/mono`；clang 21.1.8、aarch64 cross gcc 15.2 已在（背景给定）。
- **可复现构建命令（NoSb 流程）**（待产物落地后最终确认）：
  ```
  cd build/uefi-woa-prep/repos/7-mu-lenovo
  ~/.local/bin/stuart_setup -c Platforms/PakalaPkg/PlatformBuildNoSb.py
  ~/.local/bin/stuart_update -c Platforms/PakalaPkg/PlatformBuildNoSb.py
  ~/.local/bin/stuart_build -c Platforms/PakalaPkg/PlatformBuildNoSb.py --target RELEASE
  ```

## 3. 实验 A：UFSDxe 替换版 NOSB 构建

替换点：`Platforms/PakalaPkg/Device/lenovo-y700g4/PatchedBinaries/UFSDxe.efi`
（`PatchedBinaries/UFSDxe.inf`：`PE32|UFSDxe.efi|*`，FILE_GUID `0D35CD8E-97EA-4F9A-96AF-0F0D89F76567`，DEPEX `557c754d…` 与所有 Pakala 设备共用）。

| 项 | sha256 | 大小 |
|---|---|---|
| Mu 原版（备份为 `UFSDxe.efi.orig-mu`） | `00ae059f5b4a95fbe85dc9eb4c6d991c4ea5037f330cc8d3206951680a280ac1` | 151552 |
| 替换后（=厂商版） | `fa561bf11eb18f142b128f0335973f6c4a8d0241747ea581d5b3a56d601878d2` | 151552 |

构建：进行中，见 §9。

## 4. 实验 B：最小替换包（备选）

（待填）

## 5. 产物清单与校验

（待填）

## 6. 与 2026-10-05 构建的差异

（待填）

## 7. 上机测试步骤（用户手动执行）与判据

（待填）

## 8. 风险与回退

（待填）

## 9. 失败 / 未证实事项

- `pip install -r pip-requirements.txt --user` 首次失败（PEP 668 externally-managed-environment），用 `--break-system-packages` 解决。
- `stuart_setup` 走 gh-proxy 30 min 超时（卡在大子模块 Binaries = SurfaceDuoBinaries-fork），改为 `git submodule update --init --depth 1 --jobs 4`（timeout 3600，日志 `build/uefi-woa-prep/logs/submodules.log`），进行中。
- `modules.tsv` 未含 GUID 列，无法从表中直接比对厂商 FV 内 UFSDxe GUID；以尺寸 151552 B + sha `fa561bf1…` 锁定同一枚，最终以产物 image 解出模块的 sha 为准。
- **未证实**：部分子模块 `git submodule status` 显示 `+`（检出 SHA ≠ 超项目记录），若构建报缺文件需回补精确 SHA。

（待填）

---

# 续做（同一会话第二轮，2026-10-24 晚）

起点状态：仓库 `7-mu-lenovo` @ `6b6ac42a`，工作树 1.7 G，`git submodule status` 11 条全部为 `-`（未初始化）。
本轮纪律：逐个 submodule 拉取（不用 stuart_setup 的默认全量）、单个 >4 GB 或 >25 min 跳过、不碰设备。

## R1. submodule 逐个拉取（时间/大小记账）

（逐条追加）

### 已拉取（gh-proxy 镜像，`--depth 1 --jobs 4`，单条命令）

| # | submodule | 耗时 | 目录大小 | 检出 SHA |
|---|---|---|---|---|
| 1 | MU_BASECORE | 84 s | 1.7 G | `3609e51f683e4d9eed13df8dccbb05b0a64ebab2` |
| 2 | Common/MU | 15 s | 20 M | `039747f3b2c13df10b4fe4844e864c3095f98212` |
| 3 | Common/MU_TIANO | 73 s | 8.4 M | `2dd1beb9cd7631030dfc8e74cb4840a89b5d008d` |
| 4 | Common/MU_OEM_SAMPLE | 12 s | 1.5 M | `e798945fbe64baad73e9c4ec7cfb26efaa95d4e3` |
| 5 | Silicon/Arm/MU_TIANO | 56 s | 6.0 M | `d65d47a5f20ddc5b9c2190413773aa76e6966818` |
| 6 | Features/CONFIG | 10 s | 2.0 M | `d08c5af327768d2820bbd030ca5af443be33bce8` |

全部 `git submodule status -- <path>` 前缀由 `-` 变空格，无 `+`/`U`。每步包 `timeout -k 10 1500`（≤25 min），gh-proxy 无 404，未退回直连。
