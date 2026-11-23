# Mobian 第一件 MR 备料完成 —— droid-juicer `configs/lenovo,elden.toml` 成品化（2026-11-23）

> 性质：主机侧静态备料。**零设备动作、零发信、零 fork/push/MR、零 `git commit`。**
> 唯一写域 = `patches/distro/mobian-20261123/` + 本报告。
> 输入 = `reports/mobian-mr-plan-20261122.md`（事实基线）、`reports/mobian-upstream-firstpr-20261121.md`、
> `patches/distro/mobian-20261121/{droid-juicer,mobian-recipes}/`、`DEVICE/README.md` §1.2（固件表）。
> 注：本任务由「上游化推进（y700-elden）」角色承接，lane D 范围 = D2（Mobian 第一件 MR 备料）。

---

## §0 结论数字表

| # | 项 | 数字/结果 |
|---|---|---|
| 1 | 成品 config | `patches/distro/mobian-20261123/droid-juicer/lenovo,elden.toml`，**8 条 firmware + 2 条 folders**（11-21 草稿 9+2，删 ADSP/CDSP 1 条） |
| 2 | `.mdt` 固件条目数 | **0**（条目里无 `name = "…mdt"`；`.mdt` 仅存在于解释性注释，TZ 拒单文件 `.mbn` 的硬约束已落进注释与排除清单） |
| 3 | tomllib 解析 | **rc=0**（顶层仅 `[juicer]`；键 ⊆ `dynpart/firmware/folders/partdump` schema） |
| 4 | 源文件本地命中 | **18/19 present**；1 missing = `vendor/etc/sensors/sns_reg_config`（本地采集未覆盖 vendor/etc，TODO） |
| 5 | recipes 片段 | `mobian-recipes/wip-device-snippet.toml`（`chipset = "sm8750"` 在 `[[device]]` 内），tomllib rc=0，**标注「本 MR 不含」** |
| 6 | MR 描述草稿 | `mr-description.md`：动机/板信息/分区表/逐条说明/**AI 辅助披露（开头如实）**/风险/**2 个维护者问题** |
| 7 | 风格自查 | 无 tab、无行尾空格、LF、末行换行、纯 ASCII；缩进与上游 `configs/shift,axolotl.toml` 同形（diff 见 README §4） |
| 8 | GPT 基名复核 | LUN0 = `persist`+`super` ✓，LUN4 = `modem_a/b`+`bluetooth_a/b` ✓（EDL 采集件 4096 B 扇区解析） |
| 9 | 改名字节数 | 13 个源件 stat 与 11-21 README §2.1 表、`elden-firmware_1.0~20261028_all.deb` 逐条一致 ✓ |
| 10 | DT 判据复核 | `/tmp/vk192.dts`（在机 DTB 解出）：zap `qcom/sm8750/gen80000_zap.mbn`(:3039)、触屏 `novatek_ts_csot_3k_fw.bin`(:1467)、功放 `awinic/y700-gen4-speakers.bin`(:777)、**split** `adsp.mdt/adsp_dtb.mdt`(:1777)、`cdsp.mdt/cdsp_dtb.mdt`(:6724) ✓ |

## §1 产物清单（唯一写域内）

| 文件 | 内容 |
|---|---|
| `patches/distro/mobian-20261123/droid-juicer/lenovo,elden.toml` | **MR-1 成品**（英文注释；ADSP/CDSP 只在注释说明、不进条目；尾部「故意不覆盖」4 项清单） |
| `patches/distro/mobian-20261123/droid-juicer/README.md` | 预检记录 + 11 行逐条对照表（本地有据/TODO 两栏）+ 复跑命令 |
| `patches/distro/mobian-20261123/mobian-recipes/wip-device-snippet.toml` | MR-2 `wip.toml` 追加片段（将来同批，**本 MR 不含**） |
| `patches/distro/mobian-20261123/mr-description.md` | GitLab MR 描述草稿（含 commit message + 9 条自检表） |

## §2 逐条对照（详见 droid-juicer/README.md §3，此处只列两栏汇总）

**本地有据（18 条 firmware + GPT/DTB 全套）**：GPU 4 件、触屏 1 件、功放 ACF 1 件（rename）、
WiFi 7 件（peach/ 6 件 rename + tmel）、BT 5 件（brh 4 + tmel，qca/ 前缀）。
每条给：源件路径（`backup/fw/...`）→ destination 名 → DT `firmware-name` 或驱动硬编码判据。

**TODO（3 条，全部同一根因：本地采集未覆盖 vendor 动态分区 / persist 内容）**：
1. `vendor:etc/sensors/sns_reg_config` → `sns_reg.conf`（vendor vs odm 未判）；
2. `vendor:etc/sensors/config` 目录；
3. `persist:sensors/registry/registry`（在机曾为空，`PITFALLS` #94，非致命）。
判法（下次设备窗口）：`ls /dev/disk/by-partlabel | grep -E 'vendor|odm|persist'` +
`sudo make-dynpart-mappings /dev/disk/by-partlabel/super` + `ls /dev/mapper/vendor_a/etc/sensors/`。
已作为 MR 描述的问题 2 问维护者，并在描述里声明「未在硬件上验证」。

## §3 投递前置清单（还差什么才能提交 MR-1）

| # | 前置 | 谁做 | 阻塞级别 |
|---|---|---|---|
| 1 | **用户放行**（建 fork + push + 开 MR；本轮禁令不解不开就是第 1 前置） | 用户 | 硬 |
| 2 | 设备窗口：`ls /dev/mapper/{vendor,odm}_a/etc/sensors/` 判 sns_reg_config 来源（vendor vs odm） | 我方 | 建议先做（决定 config 第 9/10 条的 partition 值；也可先提交、按维护者答复改） |
| 3 | 设备窗口：dmesg 确认 `ath12k/PEACH/hw2.0` 目录名（上主线内核后看 `Direct firmware load`） | 我方 | 不阻塞提交（描述已声明待确认） |
| 4 | `cargo fmt`/`clippy` 对 config 无影响（CI 只查 Rust 侧），无需本地 Rust 环境 | — | 无 |
| 5 | 决定是否同时投 recipes 侧：**不**。wip 条目单独提交是死条目（qcom-wip 无内核 deb，CI 提交即红，11-22 报告结论 #9/§3.3） | — | 已定 |
| 6 | （MR-2 远期前置，非 MR-1）内核分支 `mobian-sm8750-7.4` + `packages/*.deb` + droid-juicer 配置副本 | 我方 | MR-2 范围 |

## §4 与 11-22 报告的差异（事实更正）

本轮**没有**推翻 11-22 报告的任何一条结论；以下为执行中的细粒度补充/澄清：

1. **「19 个既有 config」实为 19 个（本地 `/tmp/droid-juicer/configs/` 实数：19 个 `.toml`，含同名 `lenovo,elden.toml` 旧草稿一份放在该工作副本里，不计入上游数）** —— 无更正，仅记录本地副本可用作风格 diff 基准。
2. **sns_reg_config 的「先跑取证再定 partition」在本轮不可达**：11-22 §2.3 的取证命令里 `ls /dev/mapper/...` 与 dmesg 两条是设备侧命令，本轮禁碰设备 ⇒ 该 TODO 维持，处置改为「MR 描述里问维护者 + 声明未验证」（11-22 §2.2 第 3 条给的正是这两个选项，无冲突）。
3. **GPT 解析细节更正（只影响复跑命令，不影响结论）**：11-21 README 说「GPT 现读 LUN0 第 10 项 = super」，本轮复跑确认 LUN0 表扇区为 **4096 B**（`EFI PART` 在偏移 0x1000，不是 0x200）；条目序：LUN0 第 10 项 = `super` ✓、第 6 项 = `persist` ✓；LUN4 = 78 项含 `modem_a/b`、`bluetooth_a/b` ✓。判据文件 `backup/fw/tb322fc-edl/gpt_main{0,4}.bin`。
4. **`/tmp/droid-juicer/` 存在一份此前 lane 放置的中文注释工作副本**（结构 = 11-22 §2.2 diff 草案的中文版，含 ADSP/CDSP 删除）。本轮成品与其内容一致，差异仅注释语言（英文）与尾部排除清单（中文版 3 项 + adsp/cdsp 说明 → 成品 4 项合并）。**无事实分歧**；上游交付以本成品（英文）为准。

## §5 复跑命令汇总

```bash
cd /home/xuqianhui/y700-elden
# 1) TOML/结构/命中
python3 - <<'EOF'
import tomllib, os
c = tomllib.load(open('patches/distro/mobian-20261123/droid-juicer/lenovo,elden.toml','rb'))
j = c['juicer']; src = {'modem':'backup/fw/modem','bluetooth':'backup/fw/bluetooth','vendor':'backup/fw/vendor'}
miss = []; n = 0
for e in j['firmware']:
    for f in e['files']:
        n += 1
        if not os.path.exists(os.path.join(src[e['partition']], e['origin'], f['name'])): miss.append(f['name'])
print('entries', len(j['firmware']), 'files', n, 'missing', miss)
EOF
# 期望：entries 8 files 19 missing ['sns_reg_config']
grep -c 'name = "[^"]*\.mdt"' patches/distro/mobian-20261123/droid-juicer/lenovo,elden.toml   # 期望 0（.mdt 只在注释里）
# 3) GPT（4096B 扇区）
python3 - <<'EOF'
import struct
for lun in (0,4):
    d = open(f'backup/fw/tb322fc-edl/gpt_main{lun}.bin','rb').read()
    hdr = 4096
    el = struct.unpack('<Q', d[hdr+0x48:hdr+0x50])[0]
    n = struct.unpack('<I', d[hdr+0x50:hdr+0x54])[0]
    sz = struct.unpack('<I', d[hdr+0x54:hdr+0x58])[0]
    names = [d[el*4096+i*sz+56:el*4096+i*sz+128].decode('utf-16-le').rstrip('\0')
             for i in range(n) if d[el*4096+i*sz:el*4096+i*sz+16] != b'\0'*16]
    print(lun, [x for x in names if x.rstrip('_ab') in ('modem','bluetooth','persist','super') or x in ('persist','super')])
EOF
# 4) 风格
diff <(sed 's/#.*//' /tmp/droid-juicer/configs/shift,axolotl.toml | grep -v '^\s*$') \
     <(sed 's/#.*//' patches/distro/mobian-20261123/droid-juicer/lenovo,elden.toml | grep -v '^\s*$') | head
```

## §6 残余风险

- **未上机**：config 的 3 条传感器条目来源分区未实判（vendor vs odm）；ath12k 目录名待 dmesg。均已在 MR 描述显式声明。
- **主线内核未验证**：Debian `packaging/forky` 是临时 fork（11-22 结论 #10），已写成维护者问题 1。
- **投递被拒的备选路径**已在 11-22 §2.5 排好（recipes-only 退路等），本轮不重复。
