# 历史 config 快照归档（2026-11-13）

> **内容**：`../config-history-20261113.tar.zst`（15 件，4.86 MB → 67 KB，`zstd -t` 通过，解包后逐件 `sha256sum -c` 全 OK）。
> **动机**：`patches/config-*` 平铺了 30 个完整 `.config`（每个 ≈320 KB）。它们高度同源，
> 同一份内容被重复保存（如 `vk50/vk76/vk89` 三件逐字节相同），使 `patches/` 噪声、目录浏览与
> `rg` 命中都被历史噪声淹没。**归档 ≠ 删除**：原件字节仍在包里，`SHA256SUMS` 可逐件核对。

## 1. 归档清单（`SHA256SUMS` 为唯一账）

| 文件 | sha256（前 12） | 对应版本 | 归档理由 / 现役替身 |
|---|---|---|---|
| `config-vk20-debug` | `19cec0037a42` | vk20 | 早期 debug 基线；被 `config-daily-*` 取代 |
| `config-vk26-android-container` | `2c65b79ac99c` | vk26 | 容器首版；netfilter 见下件 |
| `config-vk27-container-netfilter` | `b14aa576d9b8` | vk27 | 容器 netfilter；被 `fragment-droidloom-nftables.config` 取代 |
| `config-vk28-netd-ipv6-xfrm` | `6ee13732df20` | vk28 | 与 `config-vk32-camera-base.bak` **逐字节相同**（重复件） |
| `config-vk32-camera-base.bak` | `6ee13732df20` | vk32 | 同上，重复保存；相机基线现由 `fragment-camera-sensors.config` 表达 |
| `config-vk38-camera` | `a383cdb99dfe` | vk38 | 与 `config-vk40-bringup` **逐字节相同** |
| `config-vk50-modular` | `2a940612792e` | vk50 | 与 vk76/vk89 **逐字节相同**（模块化首版） |
| `config-vk76-modular` | `2a940612792e` | vk76 | 同上，重复件 |
| `config-vk89-modular` | `2a940612792e` | vk89 | 同上，重复件 |
| `config-vk95-c1routing` | `e81de18bffe7` | vk95 | C1 路由首版；后续 `vk102/vk103` 的 `.bak` 件当年即未入库 |
| `config-suspend-s2idle-20261018-173529` | `52ae455f6adb` | vk128/129 线 | suspend 首次尝试（失败线）；现役 = `config-daily-c2-suspend-20261113` |
| `config-vk163-modular-20261025` | `eedb75f5a77f` | vk163 | 模块化 v1；v2 才是日常线（`config-vk163-modular-v2-20261026` 保留在 `patches/`） |
| `config-vk186-nftables-20261110` | `8e053cc673d2` | vk187 | nftables 单一 diff 快照；现役 `fragment-droidloom-nftables.config` |
| `config-vk188-sysfbfb-20261112` | `10b73afd024e` | vk188 | 现役线由 `config-daily-c1/c2` 承载，本件为 vk188 时点留存 |
| `config-vk189-suspend-20261112` | `6de93564847f` | vk189 | **⚠ 已判失真**（`PITFALLS #640`）：内容是 vk188 时点、缺 GUNYAH 符号，与 vk189 manifest `config_sha256=feefc38b…` 不符；**不得作为复现依据** |

## 2. 必须留在 `patches/` 平铺的原件（不要归档）

下面这些被脚本**硬编码**或被门禁当作 SSOT，归档会直接破坏复现/门禁：

| 文件 | 谁在用 |
|---|---|
| `config-daily-c1` / `config-daily-c2-suspend-20261113` / `config-daily-c3-uinput-20261113` | `scripts/check-abi-config.sh` 默认参考（取最新 `config-daily-*`） |
| `config-vk127-working-20261018` | `check-abi-config.sh` 兜底（无 daily 件时）；ABI 历史对照 |
| `config-vk40-bringup` | `scripts/rebuild-vk64-image.sh` 硬编码（vk64 镜像复现） |
| `config-vk163-modular-v2-20261026` | `apply-kernel-fragment.sh` / `mod-loop.sh` 注释所指的日常线基线 |
| `config-m3v2-suspend-20261113` | `build/m3v2-7.3rc7` 树的 aligned SSOT（SUSPEND 开关） |

## 3. 取回与核对

```bash
# 列内容
tar --zstd -tf patches/config-history-20261113.tar.zst

# 解到临时目录并逐件核对（SHA256SUMS 与包内文件名一一对应）
mkdir -p /tmp/cfg-history && tar --zstd -xf patches/config-history-20261113.tar.zst -C /tmp/cfg-history
(cd /tmp/cfg-history && sha256sum -c /home/xuqianhui/y700-elden/patches/config-history-20261113/SHA256SUMS)

# 只取一件
tar --zstd -xf patches/config-history-20261113.tar.zst -C /tmp config-vk95-c1routing
```

## 4. 以后的纪律

- 新增 config 快照一律 `config-<line>-<feature>-<YYYYMMDD>` 命名；**同一内容不另存第二份**（先 `sha256sum` 比一下）。
- 只有「当前线 SSOT」与「脚本硬编码引用」的 config 留在 `patches/` 平铺；被取代的快照攒到下一次整理轮打进 `config-history-<date>.tar.zst`。
- `patches/*.bak` 是 fragment 应用前的一次性自动备份（`apply-kernel-fragment.sh` 产生），**不入库**（`.gitignore` 已挡），整理轮直接删盘即可。
