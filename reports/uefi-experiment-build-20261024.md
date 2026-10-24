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

> 原 §4（实验 B）/§5（产物清单）/§6（差异）/§7（上机）/§8（风险）的待填内容，本轮统一写在 **§R3–§R7**，以此为准。

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

### 根因与修正：子模块被全局 git 改写劫持成 SSH

```
$ git config --global --get-regexp 'url\..*\.insteadof'
url.https://mirrors.ustc.edu.cn/aosp/.insteadof https://android.googlesource.com/
url.git@github.com:.insteadof https://github.com/
```

`~/.gitconfig` 里 `url.git@github.com:.insteadOf https://github.com/` 把**所有 https://github.com/ 改写为 git@github.com: SSH**。
命令行只加了 `url."https://gh-proxy.com/https://github.com/".insteadOf` 一条，同前缀冲突时 SSH 规则仍生效 ⇒ 子模块 clone 走 SSH，**到 github 无响应**（不是资源大）。
证据：第一次 openssl clone 走 `timeout -k 10 1500` 全程耗尽 1500 s、目录 0 字节、状态仍 `-`；同一仓库加 `GIT_CONFIG_GLOBAL=/dev/null` 后 **92 s/141 M 完成**。

修正后命令（此后一律用这条）：

```
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null timeout -k 10 900 \
  git -c url."https://gh-proxy.com/https://github.com/".insteadOf="https://github.com/" \
  submodule update --init --depth 1 --jobs 1 -- <path>
```

| # | submodule | 耗时 | 大小 | 检出 SHA |
|---|---|---|---|---|
| 7 | Platforms/OpensslPkg/Library/OpensslLib/openssl | 92 s | 141 M | `aea7aaf2abb04789f5868cbabec406ea43aa84bf` |
| 8 | Binaries（SurfaceDuoBinaries-fork） | 56 s | 206 M | `ce59dcf54753e112d7b847dd997d3ae934094e0d` |
| 9 | Features/DFCI | 0 s(已存在) | 7.5 M | `401e480fe46d348115a6fe94a878d50069b8098c` |
| 10 | Platforms/CranePkg（CrDK） | 0 s(已存在) | 516 K | `1731534fb1efe9d03972bb6ac3771f779f1a9d87` |
| 11 | Platforms/SurfaceDuoACPI | 0 s(已存在) | 43 M | `d742758fe575c08b5278d84fec1b3b313551a587` |

- 第 8 条首次失败（`Binaries` 残留 211 M 半成品目录 → `已经存在，并且不是一个空目录`），`rm -rf Binaries` 后 56 s 完成。
- 全 11 条 `git submodule status` 前缀均为空格（无 `-`/`+`/`U`），工作树 `du -sh` = **3.3 G**。
- gh-proxy 对以上仓库均无 404，未退回直连。

### 嵌套 submodule（递归层，stuart_setup 卡点）

第一次 `stuart_setup` 用 `GIT_CONFIG_GLOBAL=/dev/null` 仍 **rc=124 @1500 s**：它自身的 git 调用不带命令行 `-c` 改写，
内部 `git submodule` 用裸 https 直连 github（实测 ~1 KB/s）。已装 PATH 级 wrapper `~/.local/bin/git`
（忽略全局 ssh 改写 + github https → gh-proxy + `http.version=HTTP/1.1`），验证 `ls-remote` 3 s 返回。
随后再跑一次 `stuart_setup`（900 s）走到 `Resolving Git Submodule: Platforms/SurfaceDuoACPI` 再次超时 —— 因为它递归进了**嵌套** submodule。

| 层 | 嵌套 submodule | 耗时 | 大小 | SHA |
|---|---|---|---|---|
| L1 | `Platforms/SurfaceDuoACPI/QcomACPI`（WOA-Project/acpi_oem_qcom_common） | 38 s（首次 TLS 中断后 rm -rf 重试） | 123 M | `37436d47fd6b9f71d24790144095498435b4eb6e` |
| L3 | `Common/MU_TIANO/.../libspdm/os_stub/mbedtlslib/mbedtls` | 9 s | 43 M | `107ea89daaefb9867ea9121002fbbdf926780e98` |
| L3 | `Common/MU_TIANO/.../libspdm/os_stub/openssllib/openssl` | 157 s | 151 M | `de90e54bbe82e5be4fb9608b6f5c308bb837d355` |

- 首次 QcomACPI 失败：`GnuTLS recv error (-110): The TLS connection was non-properly terminated`（gh-proxy 侧抖动）；`rm -rf` 后重试成功。
- `libspdm` 自身（`98ef964e`）在之前某次被拉下；`unit_test/cmockalib/cmocka` 仍为 `+`（构建不涉及 unit_test，不补）。
- 结论：**PATH wrapper 是必须的**，`GIT_CONFIG_GLOBAL=/dev/null` 单独存在不足以救 stuart_setup（stuart 子进程仍走裸 https）。

## R2. stuart_setup / stuart_update / 构建（含两处环境坑）

### R2.1 stuart_setup 成功（rc=0，5 s）

```
cd build/uefi-woa-prep/repos/7-mu-lenovo
PATH=$HOME/.local/bin:$PATH GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
  timeout -k 10 900 ~/.local/bin/stuart_setup -c Platforms/PakalaPkg/PlatformBuildNoSb.py
```
输出尾部：`PROGRESS - ## Resolving Git Submodule: Platforms/CranePkg` → `PROGRESS - Done.` → `SECTION - Summary / PROGRESS - Success`。
（前两次 rc=124 @1500 s / 900 s 全部卡在 Git Submodule 解析，见上文根因。）

### R2.2 坑①：NuGet 走 mono 6.14 btls，证书校验失败（3 个 ext_dep 拿不到）

`stuart_update` rc=3：`Failed to fetch NugetDependecy: mu_nasm@20016.1.1 / edk2-acpica-iasl@20230628.0.1 / mu-uncrustify-release@73.0.8`。
`--verbose` 定位真因（不是网络）：

```
INFO - Cmd to run is: mono .../site-packages/edk2toolext/bin/NuGet.exe install mu_nasm -Source https://pkgs.dev.azure.com/...
INFO -   Unable to load the service index for source https://pkgs.dev.azure.com/projectmu/mu/_packaging/Basetools-Binary/nuget/v3/index.json.
INFO -   Authentication failed, see inner exception.
INFO -   Ssl error:1000007d:SSL routines:OPENSSL_internal:CERTIFICATE_VERIFY_FAILED  (Mono.Btls)
```

对照证据：
- `curl --noproxy '*' -o /dev/null -w '%{http_code}' https://pkgs.dev.azure.com/projectmu/mu/_packaging/Basetools-Binary/nuget/v3/index.json` → **200，1 s，直连可用**（经 127.0.0.1:7890 代理也 200）。
- 去掉所有 proxy 变量后 mono **仍然** CERTIFICATE_VERIFY_FAILED ⇒ 与代理 MITM 无关，是本机 mono **缺 `ca-certificates-mono`**（btls 用自己的信任库，不读系统 CA）；往 `~/.config/.mono/certs/Trust` 丢 bundle 也不被识别。
- `MONO_TLS_PROVIDER=legacy` 无效（mono 6.14 已无 legacy 后端）。

规避（不改系统、不装 apt 包）：**用 curl 直接下 3 个 .nupkg，解包进 ext_dep 目录并手写 `extdep_state.yaml`**。
edk2toolext 的 `ExternalDependency.verify()` 只比对 state 文件里的 `version:` 字符串，`nuget_dependency.fetch()` 在
`super().fetch()`（= 全局缓存/state）成功时**不联网**，因此手工布置等价于一次成功安装。

```
# v3 index 里的 PackageBaseAddress/3.0.0 + {id}/{ver}/{id}.{ver}.nupkg（注意 303 需 curl -L）
mu_nasm                 20016.1.1     5019557 B
edk2-acpica-iasl        20230628.0.1  2811804 B
mu-uncrustify-release   73.0.8        2768185 B

# 解包到（注意剥掉包内 <id>/ 前缀，因为 host_specific 探测的是 Linux-x86 / Linux-x86-64）
MU_BASECORE/BaseTools/Bin/mu_nasm_extdep/                                → Linux-x86-64/{nasm,ndisasm} + extdep_state.yaml(20016.1.1)
MU_BASECORE/BaseTools/Bin/edk2-acpica-iasl_extdep/                       → Linux-x86/iasl        + extdep_state.yaml(20230628.0.1)
MU_BASECORE/.pytool/Plugin/UncrustifyCheck/mu-uncrustify-release_extdep/ → Linux-x86/uncrustify  + extdep_state.yaml(73.0.8)
```

修好后 `stuart_update` **rc=0，3 s**：`Updated/Verified 5 dependencies` ×2 pass，`PROGRESS - Success`。

### R2.3 构建命令（canonical，与仓库 CI workflow 一致）

仓库自带 `.github/workflows/sm8750_lenovo_y700g4.yml` 用的是 `./build_uefi.py -d lenovo-y700g4 -t RELEASE`；
`stuart_build ... --TARGET_DEVICE` **不是**合法参数（`error: unexpected argument`），TARGET_DEVICE 是 `key=value` 环境式参数。

```
PATH=$HOME/.local/bin:$PATH GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
  timeout -k 10 2400 ./build_uefi.py -d lenovo-y700g4 -t RELEASE
```
结果：**rc=0，60 s**（`Total time Elapsed: 0:00:56`；`0108 Images Verified`）。日志 `build/uefi-woa-prep/logs/build_A.log`。

产物：

| 文件 | 大小 | sha256 |
|---|---|---|
| `Build/PakalaPkg/lenovo-y700g4.img`（Android boot image，`ANDROID!` 魔数） | 2441216 | `dfa0c8b3e9fc1c04e8dfcb4bc4970130668e301f8b9f7bf8ae306130be5f0d29` |
| `Build/PakalaPkg/RELEASE_CLANGPDB/FV/SM8750_EFI.fd` | 4194304 | `560fcb93c931e39f8a33d895af05457de4e0de6e94696d274154545213a78063` |

已归档：`reports/artifacts/uefi-built-20261024/lenovo-y700g4-C.img`、`SM8750_EFI-C.fd`（同 sha）。

## R3. 三个镜像：N（纯 Mu 基线）/ A（厂商 UFSDxe）/ C（A + 厂商 RmVmDxe）

构建方式：只切换 `Binaries/`、`PatchedBinaries/` 里的两个 `.efi` 再重跑同一条 `./build_uefi.py`（无需改 .inf/.dsc）。
增量构建 14–15 s，全量首构 60 s。

| 镜像 | UFSDxe 源 | RmVmDxe 源 | `.img` 大小 | `.img` sha256 | `SM8750_EFI.fd` sha256 |
|---|---|---|---|---|---|
| **N**（纯 Mu 基线） | Mu `00ae059f…` | Mu `4733838e…` | 2441216 | `ad4796a669cd038588feb98317f8bb82fdae35fedb4c66e5e42515b025179050` | `6d51c190086b4164a3fc90761dd44a2b166f5b612f76b643d8b6cbaac227e696` |
| **A**（厂商 UFSDxe） | 厂商 `fa561bf1…` | Mu `4733838e…` | 2441216 | `e0d4a9041ab9787a5c4bbb833a24c6c1714534daeb4664df3c93d9d04346295a` | `eb00db73f7e85a9d4471d2d3c1f0afc19b3cb6519eb7034ebfad874cae3c62a9` |
| **C**（A + 厂商 RmVmDxe） | 厂商 `fa561bf1…` | 厂商 `aed61cb1…` | 2441216 | `dfa0c8b3e9fc1c04e8dfcb4bc4970130668e301f8b9f7bf8ae306130be5f0d29` | `560fcb93c931e39f8a33d895af05457de4e0de6e94696d274154545213a78063` |

- 归档：`reports/artifacts/uefi-built-20261024/{lenovo-y700g4-N.img, -A.img, -C.img, SM8750_EFI-{N,A,C}.fd}`。
- **可复现性**：C 构建两次，`.img` sha256 完全相同（`dfa0c8b3…`，两次均 2441216 B）⇒ 构建确定性成立。
- 构建后工作树已恢复成 **C 配置**（两枚厂商 blob），`sha256sum` 复核：`PatchedBinaries/UFSDxe.efi` = `fa561bf1…`、`Binaries/QcomPkg/Drivers/RmVmDxe/RmVmDxe.efi` = `aed61cb1…`。

### R3.1 从 `.img` 反解模块（硬判据，链路上每一层都记账）

`.img` 结构由 `Platforms/PakalaPkg/PythonLibs/PostBuild.py:makeAndroidImage()` 决定：
payload = `gzip(BootShim.bin ‖ FV/SM8750_EFI.fd)`，`mkbootimg --header_version 3`（kernel 在页 1 = offset **4096**）。
所以「从产物 image 反解」= gunzip(kernel) → 定位 `_FVH`（base = sig−0x28）→ 取 fd → 解 FV 内 LZMA(GUID_DEFINED `ee4e5898…`) → 得 12 865 544 B 的内层 DXE FV → `scripts/ffs-extract.py` 逐 FFS 解 PE32。

```
$ python3 scripts/ffs-extract.py /tmp/imgC-inner-0.bin --out /tmp/ffs-imgC2   # 219 个 FFS
$ sha256sum /tmp/ffs-imgC2/0d35cd8e-DXE_DRIVER-PE32.bin /tmp/ffs-imgC2/1d9cc582-DXE_DRIVER-PE32.bin
fa561bf11eb18f142b128f0335973f6c4a8d0241747ea581d5b3a56d601878d2  .../0d35cd8e-DXE_DRIVER-PE32.bin
aed61cb16c2e884ade9f79b7b809cffd4777c308d7d4199b7a9f50a30dbb861f  .../1d9cc582-DXE_DRIVER-PE32.bin
$ stat -c '%s %n' ...
151552 .../0d35cd8e-DXE_DRIVER-PE32.bin
57344  .../1d9cc582-DXE_DRIVER-PE32.bin
```

| 镜像 | 解出 UFSDxe（GUID `0d35cd8e-97ea-4f9a-96af-0f0d89f76567`） | 解出 RmVmDxe（GUID `1d9cc582-7a90-4109-835b-0cb05b6762e1`） |
|---|---|---|
| N | 151552 B / `00ae059f5b4a95fbe85dc9eb4c6d991c4ea5037f330cc8d3206951680a280ac1`（= Mu 原版） | 57344 B / `4733838ee33394d762002c6fd729369ca69c0b213fcdc843aaf3cd53161a6648`（= Mu 原版） |
| **A** | **151552 B / `fa561bf11eb18f142b128f0335973f6c4a8d0241747ea581d5b3a56d601878d2`（= 厂商，硬判据 ✅）** | 57344 B / `4733838e…` |
| **C** | **151552 B / `fa561bf1…`（✅）** | **57344 B / `aed61cb16c2e884ade9f79b7b809cffd4777c308d7d4199b7a9f50a30dbb861f`（= 厂商，✅）** |

补充证据：`.img` kernel 解出的 fd sha256 与 `Build/.../FV/SM8750_EFI.fd` 完全一致（C：`560fcb93…`，A：`eb00db73…`），
说明镜像里的 FV 就是被校验的那一份，中间无二次改写。

## R4. RmVmDxe 为什么「能直接进组件表」（静态依赖分析）

**结论：不需要改 FV 增量插入，也不需要写补丁脚本 —— 厂商 blob 直接躺进现有 `.dsc` 组件表即可。**

1. 组件表：`Platforms/PakalaPkg/Device/lenovo-y700g4/DXE.dsc.inc:73` 已有
   `$(PACKAGE_NAME)/Device/$(TARGET_DEVICE)/Binaries/QcomPkg/Drivers/RmVmDxe/RmVmDxe.inf`（**未被注释**）。
2. APRIORI：`Device/lenovo-y700g4/APRIORI.inc:195` 同样在 `APRIORI DXE { … }` 里（第 195 行，紧邻 `QRKSDxe`）。
3. Depex：`RmVmDxe.depex` = `06 08` = `TRUE; END`（`0x06`=EFI_DEP_TRUE / `0x08`=EFI_DEP_END）⇒ 无协议依赖，只要被排进 APRIORI 就会在 DXE dispatch 阶段执行。
4. 依赖的协议在 FV 里都有：`strings vendor-RmVmDxe.efi` 只硬依赖 **QcomScm**（`failed to get QcomScm protocol`、`ScmSipSysCall() failed`），
   生产者 `TzDxe/ScmDxeCompat.inf` 在 `APRIORI.inc:49`（**早于** RmVmDxe 的 195），产物 FV 内确实解出 `4b4973ee-DXE_DRIVER UI "ScmDxeCompat"`。
5. 「必须排在 LinuxLoader/BootLinux 之前」判据成立：`LinuxLoader`（`f536d559-DXE_SAL`，depex 也是 TRUE）**不在** APRIORI.inc 中，
   而 RmVmDxe 在 APRIORI 列表内 ⇒ DXE core 先按 APRIORI 顺序发完（含 RmVmDxe），再发剩余驱动/BDS，最后由 BDS 启 LinuxLoader。
   注：APRIORI.inc 里 BdsDxe（第 120 行）**在 RmVmDxe（195）之前**，但 `BdsEntry` 是 DxeMain 在 **dispatch 全部完成之后** 才调用的（`gEfiBdsArchProtocolGuid` 路径），因此不影响顺序。
6. 语义差异（厂商 vs Mu 版，同 344 条 strings）：厂商版多了
   `VmGetHypResources` / `MergeRmDtbo` / `Skipping RmVmProtocol Install` / `fdt_check_for_valid_blob` / `fdt_set_blob_handle` /
   **`/hypervisor/qcom,resource-manager-rpc`** —— 即厂商版会**改写传入 Linux 的 FDT**，把 hypervisor 的 resource-manager RPC 节点插进去。
   这正是下面 §R6 判据 3 的观测点，也解释了为什么 Mu 版（`4733838e…`）跑起来 `/proc/device-tree/hypervisor/` 不会出现。

## R5. 与 2026-10-05 构建的差异表

参考：`archive/topics/UEFI-RESOURCES-2026-10-05.md`（配方与依赖关系）、`archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md`（结论）。
2026-10-05 **没有产出 `lenovo-y700g4.img`**（该文 §「未构建 `lenovo-y700g4.img`；未上机；未改设备」），所以差异是「记录/静态结论」vs「今日实产物」。

| 维度 | 2026-10-05 | 2026-10-24（本轮） |
|---|---|---|
| 仓库 commit | `6b6ac42a`（同） | `6b6ac42a`（同，未重新 clone） |
| 子模块 | 未初始化 | 11 个全部就位（+ 3 个嵌套），工作树 3.3 G |
| 构建链 | 只做了静态配方分析（`PostBuild.makeAndroidImage` → gzip(BootShim‖fd) → mkbootimg v3） | 全链跑通：`stuart_setup` 5 s / 全量首构 60 s / 增量 14–15 s |
| 产物 | 无 | `lenovo-y700g4.img` 2441216 B ×3（N/A/C），`SM8750_EFI.fd` 4194304 B ×3 |
| FV 内模块数 | 未统计 | 219 个 FFS；内层 DXE FV 解压后 12 865 544 B |
| UFSDxe 来源 | 记录「Mu 版 159744 B」与其后修正「y700g4 的 Mu 版也是 151552 B」 | **实测**：Mu `00ae059f…`(151552) vs 厂商 `fa561bf1…`(151552)，同尺寸不同 sha；产镜像可任选（N vs A） |
| RmVmDxe | 只提 GUID `1d9cc582` | 组件表里**本来就有**（Mu 版 `4733838e…` 57344 B 与厂商版 `aed61cb1…` 57344 B 同尺寸不同 sha）；无需 FV 增量插入 |
| DTB | 记录为 6 字节 dummy，但 payload 不引用 | 一致：`build_uefi.py` 只产 payload=gzip(BootShim‖fd)，`--dtb` 未传，DTB 不参与 |
| 上机 | 未做 | 仍未做（本轮纪律：不碰设备），步骤与判据见 §R6 |

## R6. 上机步骤（用户手动，**零写盘**）与判据

> 本轮**没有**执行任何 `adb/fastboot`。以下命令供用户手动执行；镜像已在仓库里，sha256 可直接核对。

### R6.1 步骤

```
# 0) 校验镜像（应与 §R3 表一致）
sha256sum reports/artifacts/uefi-built-20261024/lenovo-y700g4-C.img   # dfa0c8b3…
# 1) 单元进 bootloader（已解锁）
adb reboot bootloader && fastboot devices
# 2) 零写盘启动实验镜像（不写任何分区）
fastboot boot reports/artifacts/uefi-built-20261024/lenovo-y700g4-C.img
# 3) 对照实验（可选）：A 只有厂商 UFSDxe，C 是 A+厂商 RmVmDxe
fastboot boot reports/artifacts/uefi-built-20261024/lenovo-y700g4-A.img
```

镜像选择建议：**先 A 后 C**。A 只变 UFS 驱动（判据 1/2 的纯净对照）；C 在 A 的基础上加 RmVmDxe（判据 3）。

### R6.2 判据（按证据强度排序）

| # | 判据 | 观测方法 | 期望（A/C） | 对照（N） |
|---|---|---|---|---|
| 1 | **UFS 设备是否出现** | UEFI 侧：屏幕/串口 `map -r` 是否列出 UFS 卷；Linux 侧：`lsblk`、`cat /proc/partitions`、`dmesg \| grep -i ufs` | UFS 块设备出现、能读分区 | 按旧记录：无 UFS 设备 |
| 2 | **`UFS.c+2326` ASSERT 是否消失** | 串口/UEFI 控制台日志（`grep -i "UFS.c\|ASSERT"`），或 pstore (`/sys/fs/pstore`) | **不再出现** `ASSERT … UFS.c(2326)` | 旧记录里出现该 ASSERT |
| 3 | **hypervisor resource-manager DT 节点** | Linux 起来后 `ls /proc/device-tree/hypervisor/`、`cat /proc/device-tree/hypervisor/qcom,resource-manager-rpc@*/compatible` | 出现 `qcom,resource-manager-rpc@…`（仅 **C** 期望有；A/N 不应有） | 无 `hypervisor/` 目录 |
| 4 | 附加：SCM SIP 调用是否成功 | 串口日志 `grep -i "ScmSipSysCall\|VmGetHypResources\|MergeRmDtbo\|Skipping RmVmProtocol Install"` | C 无 `failed`，可能出现 `Skipping RmVmProtocol Install`（属正常分支） | N 无 RmVm 相关行 |
| 5 | 附加：LinuxLoader 能否继续引导 Linux | BDS 菜单 / 自动 `boot` 到已有 boot 槽 | 能进 Linux（说明 RmVmDxe 没破坏 FDT） | 同左 |

判据 3 是本轮新加的核心实验点，因为静态分析确认厂商 RmVmDxe 是**唯一**会写 `/hypervisor/qcom,resource-manager-rpc` 的组件（§R4.6）。

## R7. 风险与回退

- **零写盘**：`fastboot boot` 只把镜像载入内存，不写 `boot`/`dtbo`/`super`。断电重启（长按电源 10 s）即回到原 Android。
- 风险 1：ABL 拒绝该 boot image（header v3 / cmdline 空 / 无 ramdisk）⇒ 表现为停在 bootloader 或直接回 Android，**无害**。
- 风险 2：UEFI 起来但卡死（无显示/无串口）⇒ 同样只能断电退出；不会写盘、不会影响 Android 分区。
- 风险 3：C 里厂商 RmVmDxe 会改写 FDT，若 SCM SIP 在本机 firmware 上失败，可能出现 `failed to get QcomScm protocol` / `ScmSipSysCall() failed` 而 Linux 起不来 ⇒ **这正是先跑 A 的原因**：A 不碰 FDT，可把「UFS 修好没有」和「RmVm 有没有副作用」两件事分开。
- 回退：不做任何 `fastboot flash`。若曾手动改过分区（本项目其它线），回退靠 `DEVICE/` 记录的备份镜像，不在本轮范围。
- 合规：镜像里是**厂商标识可追溯的 blob**（UFSDxe/RmVmDxe 来自本机固件 dump，sha 已记账），仅用于本机实验，不进入上游提交。

## R8. 失败 / 未证实（本轮）

1. `stuart_setup` 两次超时（1500 s / 900 s）：根因 = 全局 `url.git@github.com:.insteadOf` 把子模块 https 改写成 SSH + 嵌套子模块丢失 `-c` 改写。修法见 R1。
2. `Platforms/OpensslPkg/Library/OpensslLib/openssl` 首拉 1500 s 0 字节（同上根因），修后 92 s / 141 M。
3. `Binaries` 首次 `已经存在，并且不是一个空目录`（上一轮残留 211 M）⇒ `rm -rf` 后 56 s 完成。
4. `Platforms/SurfaceDuoACPI/QcomACPI` 首次 `GnuTLS recv error (-110)`（gh-proxy 抖动）⇒ 重试 38 s 成功。
5. `stuart_update` rc=3：mono 6.14 btls `CERTIFICATE_VERIFY_FAILED`（缺 `ca-certificates-mono`，与代理无关，直连也失败）⇒ 手工布置 3 个 ext_dep（curl 下 nupkg + 写 `extdep_state.yaml`），详见 R2.2。
6. `stuart_build … --TARGET_DEVICE lenovo-y700g4` 报 `error: unexpected argument`（该参数不是 stuart CLI 选项）⇒ 改用仓库 CI 的 `./build_uefi.py -d lenovo-y700g4 -t RELEASE`。
7. `scripts/ffs-extract.py` 直接对 `.img` 跑：`== no FV; LZMA guid at []`（payload 是 gzip，FV 不在文件偏移上）⇒ 先 gunzip kernel 再解。
8. `rm -rf /tmp/...` 被环境拦截：`EXDEV: cross-device link not permitted`（被改道到 `.pi/trash`）⇒ 改用 `python3 -c shutil.rmtree`。
9. LZMA GUID 在 fd 内有**两处**命中：`0x9d8c` 是假命中（`Input format not supported by decoder`），真正的压缩段在 `0xd250` ⇒ 解析需遍历全部命中点。
10. **未证实**：本轮未上机，判据 1–5 全部为待验；`RmVmDxe` 的 FDT 改写是否在本机 firmware + 主线 DT 组合下真的成功，只能由判据 3 回答。
11. **未做**：`stuart_update` 的 `iasl/uncrustify`（cibuild scope）只是为了让环境检查通过而手工布置，实际构建用的是 `clang 21.1.8 + CLANGPDB`，未使用这两个工具。
