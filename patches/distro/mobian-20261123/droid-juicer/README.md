# droid-juicer `configs/lenovo,elden.toml` 成品 + recipes 片段（Mobian 第一件 MR 备料）

> 本轮（2026-11-23）：把 `patches/distro/mobian-20261121/droid-juicer/lenovo,elden.toml`
> 按 `reports/mobian-mr-plan-20261122.md` §2.2 的三处修改**成品化**，并做本地预检。
> **禁发信 / 禁 fork / 禁 push / 禁 MR / 禁 git commit / 未碰设备** —— 本目录全部为静态交付。
> 上游基线 = `gitlab.com/mobian1/droid-juicer` master @ 0.4.3（本地副本 `/tmp/droid-juicer/`，
> `src/firmware.rs` 行号判据与 11-21/11-22 报告一致）。

## 0. 产物

| 文件 | 是什么 | 状态 |
|---|---|---|
| `droid-juicer/lenovo,elden.toml` | **MR-1 成品**（英文注释、上游风格，可直接进 `configs/`） | ✅ tomllib OK / 风格对照 OK |
| `mobian-recipes/wip-device-snippet.toml` | MR-2 的 `wip.toml` 追加片段（**本 MR 不含**，将来同批） | ✅ tomllib OK |
| `mr-description.md` | GitLab MR 描述草稿（MD） | ✅ |
| 本 README | 预检记录 + 逐条对照表 | ✅ |

## 1. 相对 11-21 草稿的三处修改（全部来自 11-22 报告 §2.2）

1. **删 ADSP/CDSP 条目**（关键，非风格）：droid-juicer 对 `.mdt` 一律 squash 成单文件 `.mbn`
   （`src/firmware.rs:305-308`），而本机**单文件 `cdsp_dtb.mbn` 实测被 TZ 拒**
   （`DEVICE/README.md` §1.2 固件表：「split；`cdsp_dtb.mbn` 单文件被 TZ 拒」；
   `PITFALLS/sessions/06-脚本工具.md:211`）。写进 config 会产出设备不 request、也不敢用的 `.mbn`。
   ⇒ 成品只在头注释里说明「split 固件由板级固件包提供」，条目本身删除。
   ADSP/CDSP 的 split 件由我方 `elden-firmware` 包分发，**不得**进 droid-juicer 配置。
2. **注释全英文**：上游仓 19 个既有 config 风格为「少注释或无注释、无中文」；保留必要注释但换英文，
   把「未上机验证」「待 dmesg 确认」这类话移到 MR 描述（不放 TODO 进 config 本体）。
3. **尾部明写「故意不覆盖」清单**（haptic / board-2 / tplg / adsp+cdsp mbn），防止 reviewer
   误以为是遗漏（11-22 报告自检清单第 6 条）。

`sns_reg_config` 的来源（vendor vs odm）维持 11-21 的 TODO 判定：**本地采集件里没有
`backup/fw/vendor/etc/sensors/`**（EDL/挂载采集未覆盖 vendor 动态分区），上机 `ls` 是唯一判法，
本轮禁碰设备 ⇒ 保留 `partition = "vendor"`，在 MR 描述里作为问题问维护者（见 `mr-description.md` §Q2）。

## 2. 本地预检结果（复跑命令在 §4）

| 检查 | 结果 |
|---|---|
| `tomllib` 解析 | rc=0；顶层仅 `[juicer]`；键 = `dynpart / firmware / folders`（⊂ schema 四键） |
| firmware 条目数 | 8 条（11-21 的 9 条 − ADSP/CDSP 1 条） |
| 源文件本地命中 | **18/19 present，1 missing**（= `vendor/etc/sensors/sns_reg_config`，本地未采集） |
| `.mdt` 固件条目 | **0**（`grep -c 'name = "[^]]*\.mdt"'` = 0；`.mdt` 只出现在解释性注释里，11-22 自检清单第 8 条的本意 = 条目里无 `.mdt`，否则会产出被 TZ 拒的单文件 `.mbn`） |
| `rename` 含 `/` | 0 处（`firmware.rs` 用 `set_file_name`，带 `/` 会炸） |
| 风格 | 无 tab / 无行尾空格 / LF / 末行换行 / 纯 ASCII；缩进与 `configs/shift,axolotl.toml` 逐字符同形 |
| 分区基名 | GPT 复跑：LUN0 有 `super`、`persist`；LUN4 有 `modem_a/b`、`bluetooth_a/b`（vendor/odm 在 super 内，动态）✓ |

## 3. 逐条对照表（源件 → destination；「本地有据」= 本机文件/DTB/GPT 可复核）

| # | config 条目 | 源（partition:origin/name） | destination 名 | 本地有据 | 判据 |
|---|---|---|---|---|---|
| 1 | GPU | vendor:firmware/`gen80000_zap.mbn` | `qcom/sm8750/gen80000_zap.mbn` | ✅ | DT `firmware-name`（/tmp/vk192.dts:3039）+ 文件在 `backup/fw/vendor/firmware/` |
| 2 | GPU | vendor:firmware/`gen80000_{gmu.bin,sqe.fw,aqe.fw}` | 同名 | ✅ | adreno 驱动定名；文件在；deb 内同位置 |
| 3 | 触屏 | vendor:firmware/`novatek_ts_csot_3k_fw.bin` | 根目录同名（253952 B） | ✅ | DT `firmware-name`（:1467，`nt36536`） |
| 4 | 功放 | vendor:firmware/`aw882xx_acf.bin` | `awinic/y700-gen4-speakers.bin`（1792 B） | ✅ | DT `firmware-name`（:777,:788）+ 11-21 README §2 表（与 deb 逐字节同长） |
| 5 | WiFi | modem:image/peach/`amss20.bin`→`amss.bin`（6959168 B）等 6 条 | `ath12k/PEACH/hw2.0/` | ✅ | ath12k 默认路径（DT 无 firmware-name）；非-20 变体 MHI `-110`（DEVICE §1.2）；字节数全对上 |
| 6 | WiFi tmel | modem:image/`tmel_peach_20.elf`→`tmel.bin`（56752 B） | `ath12k/PEACH/hw2.0/tmel.bin` | ✅ | 同上；源件在 `peach/` 上一层（本地 ls 证实） |
| 7 | BT brh×4 | bluetooth:image/ 同名 | `qca/`（btqca 硬编码前缀） | ✅ | dmesg `QCA Downloading qca/brhbtfw20.tlv`（11-21 README §2）；deb 内同位置 |
| 8 | BT tmel | modem:image/`tmel_peach_20.elf` | `qca/tmel_peach_20.elf` | ✅ | 缺则 BT 控制器不注册（`PITFALLS` #454） |
| 9 | 传感器 | vendor:etc/sensors/`sns_reg_config`→`sns_reg.conf` | `/usr/share/qcom/sm8750/LENOVO/TB322FC/sensors/` | ⚠ **TODO** | 本地无 `backup/fw/vendor/etc/`；来源分区（vendor vs odm）需上机 `ls /dev/mapper/vendor_a/etc/sensors/` 判 |
| 10 | 传感器目录 | vendor:etc/sensors/`config` | 同上绝对路径 | ⚠ **TODO** | 同上 |
| 11 | 传感器 registry | persist:sensors/registry/`registry` | 同上绝对路径 | ⚠ **TODO** | `persist` 分区在 GPT（LUN0）✓，但本地无采集内容；在机曾为空（`PITFALLS` #94，非致命） |

**绝对路径语义**：`firmware.rs:273/340` = `PathBuf::from(extract_path).join(destination)`，Rust `join`
遇绝对路径直接替换前缀 ⇒ `/usr/share/qcom/...` 不受 `extract_path`（默认 `/lib/firmware/updates`）影响。
与上游先例 `shift,axolotl.toml` 的 `/var/lib/droid-juicer/sensors` 同形。

## 4. 复跑命令

```bash
cd /home/xuqianhui/y700-elden
# TOML + 结构 + 源文件命中（§2 全部数字）
python3 - <<'EOF'
import tomllib, os
c = tomllib.load(open('patches/distro/mobian-20261123/droid-juicer/lenovo,elden.toml','rb'))
j = c['juicer']
src = {'modem':'backup/fw/modem','bluetooth':'backup/fw/bluetooth','vendor':'backup/fw/vendor'}
miss = []
n = 0
for e in j['firmware']:
    for f in e['files']:
        n += 1
        p = os.path.join(src[e['partition']], e['origin'], f['name'])
        if not os.path.exists(p): miss.append(p)
print('entries', len(j['firmware']), 'files', n, 'missing', miss)
EOF
# .mdt 计数（期望 0）
grep -c '\.mdt' patches/distro/mobian-20261123/droid-juicer/lenovo,elden.toml
# GPT 基名（4096 B 扇区，LUN0/LUN4）
# （见 reports/mobian-firstmr-20261123.md §2 附录脚本）
# 风格对照
diff <(sed 's/#.*//' /tmp/droid-juicer/configs/shift,axolotl.toml | grep -v '^\s*$') \
     <(sed 's/#.*//' patches/distro/mobian-20261123/droid-juicer/lenovo,elden.toml | grep -v '^\s*$')
```

## 5. 明确不做（本轮硬约束）

- 不 fork、不 push、不开 MR、不 `git send-email`、不 `git commit`。
- 不碰设备（`/dev/disk/by-partlabel`、`make-dynpart-mappings`、dmesg 全部留待下次设备窗口）。
- 不改 `PITFALLS #691/#693/#694` 相关结论：Mobian 落地时 droid-juicer.service 必须 masked +
  离线抽取，纪律在 `patches/distro/mobian-20261121/droid-juicer/README.md` §3，本成品不重复展开。
