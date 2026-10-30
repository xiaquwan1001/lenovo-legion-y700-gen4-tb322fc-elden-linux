# L2-A 离线包清单与三档体积（tablet-offload-20261030）

作者：L2-A（叶级）· 只读盘点 + 白名单两文件 · 无设备写入、无 git 写。
原始证据：`reports/artifacts/tablet-offload-20261030/l2a-dep-grep-{1,2,3,4}.log`、`l2a-pypi-dtschema.log`、`l2a-dir-sizes.log`。

## 1. 项目真实依赖盘点（grep 实据，file:line）

| 依赖 | 实据 file:line | 判定 | 说明 |
|---|---|---|---|
| `edl`（bkerler，venv+pip） | `.pi/skills/qualcomm-edl-flashing/SKILL.md:30`、`.pi/skills/qualcomm-android-flashing/SKILL.md:65` | ② 预传 | `pip install edl` 是错误包（PyPI 同名视频工具），必须 GitHub 源码 tarball（gh-proxy.com）+ requirements.txt 离线装；体积 ~数 MB |
| `cryptography` / `pycryptodome` | `scripts/hk-save-decrypt.py:49,55,60`、`.pi/skills/qualcomm-android-flashing/SKILL.md:72` | ① 在线可取 | USTC pypi 镜像 200 实测（见 §4）；`.x` 解密也要它 |
| `gdown` | `.pi/skills/qualcomm-android-flashing/SKILL.md:98`、`references/gdrive-zip64-range-extract.md:5` | ③ 不需要 | 教训已沉淀：pip 装失败（PEP 668+403），且项目已改用 Range 请求方案，无 gdown 依赖 |
| `tirith` | `.pi/skills/qualcomm-android-flashing/SKILL.md:172` | ③ 不需要 | 明确判定：PyPI 无此 bootloader 项目，装到的是无关监控包 |
| `dtc`（device-tree-compiler） | `.pi/skills/qualcomm-android-flashing/references/lenovo-abl-incompatibility.md:93`、`grub-direct-boot-android.md:87` | ① 在线可取 | apt sid 有；L1 已实测 apt 通道 200 |
| `dtschema`（dt-validate / dt-doc-validate） | host 用 pip：`TASKS/sessions/2026-10-27-M4-1绑定补丁投递-lore复核.md:15`（`~/.local/bin/dt-doc-validate`）；门禁大量使用（TASKS/README.md:568,576 等） | **① pip 经 USTC pypi（结论见 §2）** | 平板 `import dtschema` 失败 |
| `checkpatch.pl` | `patches/upstream/*/{GATES,SENT}.md` 多处 0E/0W/0C 门禁 | ① 在线可取 | 内核树自带 `scripts/checkpatch.pl`，无需安装；只需 perl（平板自带） |
| `debootstrap` + `qemu-user-static` | `scripts/win-x86-rootfs.sh:52`、`scripts/host-arm64-chroot.sh:30-42` | ① 在线可取 | apt 侧安装点写在脚本内（平板 arm64 上跑不需要 qemu-user-static，那是 x86 host 的事） |
| `aarch64-linux-gnu-gcc`（含 gcc-14/15） | `scripts/rebuild-vk64-image.sh:72-73`、`scripts/sd-variant-build.sh:20`、`scripts/env-build.sh:28`、`scripts/build-{ffrumble,sensord,hapticd,athm-probe}.sh:7/20`、`packaging/elden-userland/sources.tsv:16`、`probes/README.md:28` | ③ 平板上不需要 | 平板本身就是 arm64，直接用原生 `gcc`；交叉编译只在 x86 host 需要（平板离线任务不涉及） |
| `openssl`（avbtool 签名/验签） | `tools/avbtool.py:379-643` | ① 在线可取 | Debian sid 基础包已有 |
| `ccache` / `pahole` | `scripts/check-doctor.sh:198-205`、`scripts/sd-variant-build.sh:20` | ②/③ | pahole 仅 host 调试 ABI 用，平板可不下；ccache 平板编译内核才需要（见 §5 C 档） |
| `zstd` / `mkfs.f2fs`（f2fs-tools） / e2fsprogs | `scripts/f2fs-migrate.sh:56,103`、`scripts/q32-boot-evidence.sh:36` | ① 在线可取 | apt 侧 |
| `mkbootimg.py` | `scripts/build-boot.sh:17`、`scripts/mkbootimg.py:2`（vendored） | ③ 不需要 | 已 vendor 进仓库，纯 python3 标准库 |
| `qrtr-tools`（运行时提示） | `packaging/elden-userland/hooks/iio-sensor-proxy.pre:14` | ① 在线可取 | 平板 rootfs 运行时需要 |
| `nodejs` + `npm` + `ble.sh` + `tmux` + core-dev + kbuild + py-static | L1 实测 `--print-uris`：共 513 pkgs / 84.6 MiB | ① 在线可取（apt download 离线化） | nodejs+npm 67.1 MiB 为大头 |
| Pi agent（pi-fabric 等 npm 包） | 本机 `~/.pi/agent/npm/` | ② 预传 | npm registry 200 可达，但离线更稳：直接 scp Pi release 目录（方案见脚本 §C） |

## 2. dtschema 路线裁决

**结论：走 pip（USTC pypi 镜像），不走 apt。** 理由：

1. 平板真正缺的是 `dt-validate` / `dt-doc-validate` 可执行工具，这两个**只随 `dtschema` pip 包分发**；apt 的 `python3-jsonschema` 只给 jsonschema 库，不提供 DT 校验工具。内核自带的是 `scripts/dtc`（dtb/dts 互转）与 `scripts/checkpatch.pl`（perl 脚本，零依赖），二者都补不上 dtbs_check/dt_binding_check 的 schema 校验缺口。
2. 平板是 sid，理论上 apt 拼装 jsonschema+rfc3339-validator+... 也能喂出环境，但 `dtschema` 对 `jsonschema`、`rfc3339-validator`、`yamllint` 有版本下限，手工拼版本漂移风险高、且没有包管理器追平级；pip 一次 `pip download dtschema --dest` 全链路取齐，代价小（dtschema wheel ~1 MB + 依赖 ~5–8 MB）。
3. 实测 `https://mirrors.ustc.edu.cn/pypi/simple/dtschema/` HTTP 200（`l2a-pypi-dtschema.log`），下载+安装均可离线化（`pip download` 在 host 或平板在线一次，`pip install --no-index --find-links` 离线装）。
4. 代价：需要在平板上开 venv（sid PEP 668 外部管理环境），venv 建立成本 ≈ 0；总计 < 10 MB 磁盘。

## 3. 离线包清单表（包 / 来源 / 体积 / 取法 / 失败回退）

| 包 | 来源 | 体积 | 取法 | 失败回退 |
|---|---|---|---|---|
| apt 513 pkgs（core-dev/ble.sh/nodejs+npm/py-static/kbuild） | mirrors.ustc.edu.cn/debian sid | 84.6 MiB（L1 实测） | 平板 `apt-get download` → `/var/cache/apt/archives.offline`（脚本 B 段） | 逐包回退 `apt-get --print-uris` + 手动 curl；单包坏只重下该包 |
| dtschema 及依赖 | USTC pypi | ~8 MB | `pip download dtschema -d wheelhouse`（在线）→ `pip install --no-index --find-links`（离线） | apt `python3-jsonschema`+内核 `scripts/dtc` 只做 dts↔dtb，dt-validate 功能降级放弃（无替代） |
| edl（GitHub tarball） | gh-proxy.com → github.com/bkerler/edl | ~3 MB（源码+req） | 在线一次下载 tarball，离线 venv + `pip install -r requirements.txt --find-links`（req 也先 download） | gh-proxy 403 时改 web archive / 手拷 |
| cryptography / pycryptodome | USTC pypi | ~6 MB | 并入 wheelhouse | apt `python3-cryptography`（sid 有） |
| 仓库工作树（git-tracked 3720 文件） | 本仓库 | 98 MB（97,949,584 B，L1 实测） | `git archive` 或 rsync 排除大目录 | tar 分卷 scp |
| `.git`（pack） | 本仓库 | 31.19 MiB pack（L1 实测） | `git bundle` 或直接打包 `.git/objects/pack` | 裸 clone 后 push 到平板 mirror remote（只读消费不违反禁令，禁止 push 方向是出仓） |
| `patches/` + `reports/` + `TASKS/` + `PITFALLS/` + `.pi/skills/` | 仓库 | 13M + 99M + 1.1M + 952K + 424K | rsync（git archive 不含未跟踪的 reports 时需单独走） | 按需子集 |
| Pi agent npm 目录 | 本机 `~/.pi/agent/npm/` | 待测（建议档才需要） | `rsync -a`（含 node_modules 即离线可用） | 平板在线 `npm install`（registry.npmjs.org 200） |
| nodejs+npm 本体 | 已含在 apt 513 包 | 67.1 MiB | 同 apt | — |

**明确排除（脚本 hard-exclude）**：`build/`(171G)、`out/`(6.4G)、`geekidos-linux/`(2.9G)、`stock-src/`(2.0G)、`env-pass/`(3.3G)、`backup/*.img`(3.0G 主体)、`dl-cam/*.img`(2.7G 主体)、`.pi/sessions/`(616M)。

## 4. 在线通道实测（本轮 + 引用 L1）

- `https://mirrors.ustc.edu.cn/pypi/simple/dtschema/` → **HTTP 200**（本轮实测）。
- `https://mirrors.ustc.edu.cn/debian/dists/sid/Release` → **HTTP 200**（本轮实测）。
- L1：apt/npm 源均 200；平板 git 2.55.0 / nodejs 24.22.0 / npm 12.2.0 / ble.sh 0.4.0~git20250806 / tmux 3.8 候选在。

## 5. 总体积三档 vs 平板容量

| 档 | 内容 | 体积（估） | 平板 /sda17 剩 73G | 合并分区后 ~169G |
|---|---|---|---|---|
| **A 最小可跑** | git-tracked 工作树(98M)+`.git` pack(31M)+apt 513 包(85M)+dtschema wheelhouse(8M)+edl(3M) | **≈ 230 MiB** | ✅ 毫无压力 | ✅ |
| **B 建议** | A + reports(99M)+patches(13M)+TASKS/PITFALLS(2M)+.pi/skills(424K)+Pi agent npm 目录(估 300–500M) | **≈ 0.9–1.2 GiB** | ✅ | ✅ |
| **C 含内核工具链** | B + 原生 gcc/binutils/make/flex/bison/bc/libssl-dev(python3-dev)+ccache（平板 arm64 原生编内核，apt 侧估 400–700 MiB 下载+安装后 ~2–3G）+ kbuild 已在 | **≈ 3–4.5 GiB** | ✅（73G 足够，但原生编 SM8750 内核在 8 核平板上墙钟远慢于 host，仅作应急） | ✅ |
| **放不下的** | `build/` 171G（三档均放不下；73G 放不下任何形式的内核构建树全量，169G 理论可放单棵 clean-tree 但无意义——平板 C 档定位是应急小改动编译，不承载 M1 树） | 171G | ❌ | ❌（169G 也放不下） |

`geekidos-linux/`(2.9G 部分 clone)、`out/`(6.4G)、`stock-src/`(2.0G)：**不预传**——平板如需上游 pristine，可走 git blob:none 部分克隆按需取；预传完整目录浪费且失去按需性。

## 6. 产物与复现

- 脚本：`.pi/plans/tablet-offline-pkgs.sh`（DRY_RUN=1 默认；`--run` 才动作）。
- 语法自检：`bash -n .pi/plans/tablet-offline-pkgs.sh`
- 复现 grep：`grep -rnE 'apt(-get)? install|pip3? install|...' scripts/ tools/ probes/ packaging/ .pi/skills/ RUNBOOK-BRINGUP/`（模式见 `l2a-dep-grep-1.log` 头部）
- 复现 pypi 实测：`curl --noproxy '*' -sS -o /dev/null -w '%{http_code}\n' https://mirrors.ustc.edu.cn/pypi/simple/dtschema/`
