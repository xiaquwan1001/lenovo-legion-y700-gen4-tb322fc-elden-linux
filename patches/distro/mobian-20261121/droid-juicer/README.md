# `lenovo,elden.toml` — droid-juicer 配置（Mobian 装机第一件可交付物）

> 产物：`lenovo,elden.toml`（本目录）。落点（上游要求）= `/usr/share/droid-juicer/configs/lenovo,elden.toml`。
> 生成方式 = **纯静态/离线**：字段逐条给判据来源；机器校验见 §5。**未上机、未发 MR、未写 Mobian 仓**。
> 上游源码判据基线 = `gitlab.com/mobian1/droid-juicer` **master @ `a160267c`（Release 0.4.3，2026-10）**，
> 取源命令：`curl -sS https://gitlab.com/mobian1/droid-juicer/-/raw/master/src/firmware.rs`（本文所有 `firmware.rs:NNN` 都指这份）。

---

## 0. 一句话结论 + 三条必须先知道的形态冲突

配置本身能用（`tomllib` 解析通过，23 个源文件全部在本地 EDL/挂载采集件里逐条命中），
但**它不可能单独把 elden 的固件面变成「零缺失」**，原因三条都在上游工具的语义里，不在我们的配置里：

| # | 冲突 | 上游语义（判据） | 我方处置 |
|---|---|---|---|
| C1 | **`.mdt` 会被 squash 成单文件 `.mbn`** | `src/firmware.rs:305-308`：`if file.name.ends_with(".mdt") { destination.set_extension("mbn"); squash_file(...) }` ⇒ 只出 `adsp.mbn`，**不拷 `.bNN` 分段** | 我们下游板 DTS 现在写 split（`firmware-name = "qcom/sm8750/adsp.mdt"`，在机 DTB 现读）⇒ **换 Mobian 前把 DT 改成单文件名字**（上游 `sm8750-mtp.dts` 即 `qcom/sm8750/adsp.mbn`），否则要么改 DT、要么另发自带分段的固件包 |
| C2 | **拼装类固件 droid-juicer 不做** | `board-2.bin` = `bdwlan.e01..e41` 拼装（2253964 B）；droid-juicer 只 copy/squash | `board-2.bin` 留在 `elden-firmware` 包；本配置只给 `board.bin`（ath12k 的合法回退） |
| C3 | **自定/自编资产不是「抽取」** | `awinic/y700-gen4-haptic.bin`（vendor 无同名牌，`backup/fw/README.md`）、`qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin`（自编，`scripts/audio-tplg/`） | 必须由我方固件包分发；droid-juicer 只解决「原厂件合法再分发」那半边 |

---

## 1. 机型号（每字段判据）

| 字段 | 取值 | 判据来源（可复跑） |
|---|---|---|
| 文件名 = DT compatible | `lenovo,elden.toml` | droid-juicer README「config files named after the device's DT `compatible` property」；本机取值 = 在机 DTB 现读：`python3 -c "d=open('out/boot-elden-vk192.img','rb').read();i=d.rfind(bytes.fromhex('d00dfeed'));import struct;open('/tmp/k.dtb','wb').write(d[i:i+struct.unpack('>I',d[i+4:i+8])[0]])" && dtc -I dtb -O dts /tmp/k.dtb \| grep -m1 lenovo` ⇒ `compatible = "lenovo,elden", "qcom,sm8750";` |
| 机型 | Lenovo Legion Y700 Gen4 = **TB322FC** = 代号 **elden** | 项目 `AGENTS.md`「机型唯一」 |
| SoC | **SM8750**（上游内部名 Pakala；DT `qcom,sm8750`） | 同上 + DTB compatible 第二条 |
| `dynpart = "super"` | `super` | 本机 GPT 现读（`backup/fw/tb322fc-edl/gpt_main0.bin` 第 10 项 = `super`，22 GiB，a 槽动态分区 system/vendor/product/odm/system_ext/*_dlkm，`DEVICE/README.md` §3 表） |
| 挂载路径口径 | `partition` 写基名（`modem` / `bluetooth` / `vendor` / `persist`） | `src/firmware.rs:97-116`：先试 `/dev/mapper/<part>`，再 `<part>_a`、`<part>_b`，再 `/dev/disk/by-partlabel/<part>{,_a,_b}` ⇒ 写基名即命中本机 `modem_a`/`bluetooth_a` |

## 2. 需抽取分区清单（现名 = 本机 GPT 实读，不是猜测）

GPT 名字来源：`backup/fw/tb322fc-edl/gpt_main{0,4,5}.bin`（EDL 采集，主表逐项 utf-16 解析）。
本机相关物理/LUN 关系：**LUN0** 放 `super`/`persist`/`misc`/`metadata`/`userdata`…；**LUN4** 放 `modem_a|b`、`bluetooth_a|b`、`dsp_a|b`、`boot_a|b`…

| 分区（by-partlabel 实名） | 用到的 origin | 配置里的 `partition` | 落地 destination |
|---|---|---|---|
| `modem_a` | `image/`（adsp/cdsp/tmel） | `modem` | `qcom/sm8750`、`qca`、`ath12k/PEACH/hw2.0` |
| `modem_a` | `image/peach/`（WCN7861） | `modem` | `ath12k/PEACH/hw2.0` |
| `bluetooth_a` | `image/`（brh 家族 4 件） | `bluetooth` | `qca` |
| `super` → `vendor_a`（ext4，`make-dynpart-mappings`） | `firmware/` | `vendor` | `qcom/sm8750`、`.`、`awinic` |
| `super` → `vendor_a` | `etc/sensors/`（config 目录 + `sns_reg_config`） | `vendor` | `/usr/share/qcom/sm8750/LENOVO/TB322FC/sensors`（绝对路径） |
| `persist` | `sensors/registry/registry` | `persist` | 同上 `/…/sensors/registry` |

### 2.1 逐文件来源与「改名依据」（全部可本地复核）

改名依据 = 与**在机可用**的 `out/debian/elden-firmware_1.0~20261028_all.deb` 内文件**字节数逐一相等**，
且源件在采集树里存在（`backup/fw/…`）。复核命令见 §5。

| destination 名 | 源件（分区:origin/name） | 字节 | 说明 |
|---|---|---|---|
| `qcom/sm8750/adsp.mbn` | modem:image/`adsp.mdt`(+`adsp.b00..b56`) | squash | C1：squash 产物 |
| `qcom/sm8750/adsp_dtb.mbn` | modem:image/`adsp_dtb.mdt`(+`.b00..b02`) | squash | 同上 |
| `qcom/sm8750/cdsp.mbn` | modem:image/`cdsp.mdt`(+`cdsp.b00..b15`) | squash | 同上 |
| `qcom/sm8750/cdsp_dtb.mbn` | modem:image/`cdsp_dtb.mdt`(+`.b00..b02`) | squash | 同上 |
| `qcom/sm8750/gen80000_zap.mbn` | vendor:firmware/`gen80000_zap.mbn` | 同名 | DT `zap-shader` 现读此名 |
| `qcom/sm8750/gen80000_{gmu.bin,sqe.fw,aqe.fw}` | vendor:firmware/ 同名 | 同名 | 我方包里是 `.zst` 变体（镜像侧压缩选择） |
| `novatek_ts_csot_3k_fw.bin` | vendor:firmware/ 同名 | 253952 | DT `firmware-name` 现读此名 |
| `awinic/y700-gen4-speakers.bin` | vendor:firmware/`aw882xx_acf.bin` | 1792 | `backup/fw/README.md`「功放 ACF」：内容即 aw88461 ACF |
| `awinic/y700-gen4-haptic.bin` | **无源件**（C3） | 5881 | 自定资产，不进本配置 |
| `ath12k/PEACH/hw2.0/amss.bin` | modem:image/peach/`amss20.bin` | 6959168 | `-20` 变体才被这颗 die 接受（`amss.bin` 非-20 MHI `-110`） |
| `ath12k/PEACH/hw2.0/aux_ucode.bin` | modem:image/peach/`aux_ucode20.elf` | 61440 | |
| `ath12k/PEACH/hw2.0/m3.bin` | modem:image/peach/`phy_ucode20.elf` | 290816 | |
| `ath12k/PEACH/hw2.0/tmel.bin` | modem:image/`tmel_peach_20.elf` | 56752 | 与 BT 那件的第 5 文件同源 |
| `ath12k/PEACH/hw2.0/board.bin` | modem:image/peach/`bdwlan.elf` | 125420 | C2 |
| `ath12k/PEACH/hw2.0/qdss_trace_config.bin` | modem:image/peach/`qdss_trace_config_v2.cfg` | 6237 | |
| `ath12k/PEACH/hw2.0/regdb.bin` | modem:image/peach/`regdb.bin` | 24278 | |
| `ath12k/PEACH/hw2.0/board-2.bin` | **拼装**（C2） | 2253964 | 不进本配置 |
| `qca/brhbtfw20.tlv` | bluetooth:image/ 同名 | 219296 | btqca 代码写死 `qca/` 前缀（`name-map.tsv`，dmesg 实测） |
| `qca/brhbtnv20.bin` | bluetooth:image/ 同名 | 13319 | |
| `qca/brhperifw20.tlv` | bluetooth:image/ 同名 | 19884 | |
| `qca/brhperinv20.bin` | bluetooth:image/ 同名 | 741 | |
| `qca/tmel_peach_20.elf` | modem:image/ 同名 | 56752 | 缺则 BT 控制器不注册（`PITFALLS` #454） |
| `/usr/share/qcom/sm8750/LENOVO/TB322FC/sensors/config/` | vendor:`etc/sensors/config`（含 `json.lst`，整目录） | 目录 | sensorspd 的 registry 输入 |
| `/…/sensors/registry/` | persist:`sensors/registry/registry` | 目录 | 本机此目录**曾为空**（`PITFALLS` #94），非致命 |
| `/…/sensors/sns_reg.conf` | vendor:`etc/sensors/sns_reg_config` | 单文件 | **TODO(需上机确认)**：来源路径未实地 ls |

## 3. 启动阻塞规避（这一节是**必须**的，配置只管「抽什么」，管不了「会不会卡死」）

历史事实（都是本项目实测，不是上游文档）：

- **`PITFALLS` #691 / `sessions/323-`**：`droid-juicer.service` 在 **自建 GPT 表**上扫描后**恒处于 `running`**，
  `graphical.target` 永远 `waiting`、`greetd` 排后面永不执行 ⇒ 屏上停在开机服务日志（与「桌面壳坏了」不可区分）。
- **`PITFALLS` #693 / `sessions/325-`**：那不是「慢」，是死循环；`kill -9` 被 systemd 重拉；
  **在 live 系统上 `systemctl disable --now droid-juicer` 后 ~40 s 整机掉电**（无 Oops/无 pstore，日志只到启动后第 1 秒）
  ⇒ 结论：**禁止在 live 系统上停/杀它**。
- **`PITFALLS` #694 / `sessions/326-`**：救援舱 = cmdline 追加 `systemd.mask=droid-juicer.service …` 后 `fastboot boot`（零写盘）。

因此 elden 上的 **Mobian 落地纪律（写进镜像构建，而不是写进配置）**：

1. **首次启动不跑它**：镜像里 `droid-juicer.service` 必须 **masked**（`systemctl mask droid-juicer`，
   或 stage 阶段直接不 enable）。上游默认「首启自动跑 + 抽完自动 reboot」对本机 = 首启必卡。
2. **抽取改在镜像构建/安装器阶段做**（离线，主机侧 loop 挂载，不碰在机 GPT）：
   ```sh
   # 主机侧，只读挂载 + 让 droid-juicer 跑一次（不重启设备）
   sudo make-dynpart-mappings /dev/disk/by-partlabel/super   # 先映射 vendor/odm
   sudo droid-juicer --config /usr/share/droid-juicer/configs/lenovo,elden.toml
   sudo droid-juicer --cleanup                                # 需要重跑时先清
   ```
   产物落在 `general.extract_path`（见 §4），再打进镜像的 `/lib/firmware`。
3. **万一首启还是跑了**：先 **`systemctl stop` 单独做一次**、确认 `list-jobs` 里 `running` 消失**再** `mask`
   （#693 的「不要在同一轮里做组合写操作」）；若仍复发 ⇒ 走 zero-write 救援舱（cmdline `systemd.mask=`）。
4. **本机只读它不写它**：droid-juicer 以 `RDONLY` 挂载源分区（`firmware.rs:96` `MountFlags::RDONLY`），
   这点与「怀疑它在自建 GPT 上做破坏性操作」的观察不冲突也不互证 —— 该怀疑仍**未取证**（#693 原文口径）。

## 4. 全局 `/etc/droid-juicer/config.toml`（设备无关，Mobian 侧）

```toml
[general]
extract_path = "/lib/firmware/updates"
```
- `extract_path` 语义 = 所有 `destination` 的基准（`firmware.rs:273`），默认 `/lib/firmware/updates`；
  本配置里两条传感器的 `destination` 用**绝对路径**，`Path::join` 遇绝对路径直接替换基准（同处），
  所以它们不受 `extract_path` 影响。
- 不要照抄上游 Debian sample 里的 `postprocess.commands`（它含 `dracut`/`update-initramfs` 与 **reboot** 语义）；
  本机必须显式禁掉自动重启（见 §3 第 1 条）。

## 5. 判据（可复跑，全部离线）

```bash
# 1) TOML 语法 + 结构
python3 -c "import tomllib;d=tomllib.load(open('patches/distro/mobian-20261121/droid-juicer/lenovo,elden.toml','rb'));j=d['juicer'];print('OK',j['dynpart'],len(j['firmware']),'段',len(j['folders']),'段落')"
# 期望：OK super 9 段 2 段落

# 2) 每个源文件在本地采集件里逐条命中（23/23；sensors 两处不参与：本地未采集 vendor/etc 与 persist）
python3 - <<'EOF'
import tomllib,os
j=tomllib.load(open('patches/distro/mobian-20261121/droid-juicer/lenovo,elden.toml','rb'))['juicer']
src={k:'backup/fw/'+k for k in ('modem','bluetooth','vendor')}
bad=[];n=0
for e in j['firmware']:
    for f in e['files']:
        assert '/' not in (f.get('rename') or ''), f
        if e['partition'] in src:
            n+=1
            p=os.path.join(src[e['partition']],e['origin'],f['name'])
            if not os.path.exists(p): bad.append(p)
print('checked',n,'missing',len(bad),bad)
EOF
# 期望：checked 23 missing 1 ['backup/fw/vendor/etc/sensors/sns_reg_config']（= §2.1 的 TODO 行）

# 3) 改名字节数对照（与在机可用包逐个相等）
dpkg-deb -c out/debian/elden-firmware_1.0~20261028_all.deb | grep -E 'ath12k|qca/|novatek|awinic|gen80000'

# 4) 上机后（Mobian 首次启动前）验证固件面 = 零缺失
ssh mobian@<ip> 'dmesg | grep -i "Direct firmware load" | grep -c failed'   # 期望 0
ssh mobian@<ip> 'ls -l /lib/firmware/updates/qcom/sm8750 /lib/firmware/updates/qca'
```

■ 本文件为静态交付，未运行 droid-juicer、未改设备、未发信。
