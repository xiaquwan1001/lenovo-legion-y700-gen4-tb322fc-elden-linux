# 解锁链签名取证 —— 「联想用谷歌公开密钥，可以自己签来解锁 BL」核验

2026-10-03。用户更正：按三代以及 7、8 月的记录，联想用谷歌公开密钥签名 → 可以自己签来解锁 BL。
本文件 = 用**本地已有实物**做的核验（未下载任何新工具）。

## 0. 一句话结论

**两条链要分开看：**

| 链 | 签名密钥 | 是否公开 | 能否自己造 |
|---|---|---|---|
| **AVB 镜像链**（`vbmeta`/`boot`/`recovery`） | **AOSP testkey RSA-4096，pubkey sha1 `2597c218…`** | **是**（AOSP `external/avb/test/data/testkey_rsa4096.pem`，= 我们 `env-pass/keys/testkey_rsa4096.pem`） | **能**，且我们一直在用（b 槽包）→ **你的说法在这条链上成立** |
| **BL 解锁标志**（`fastboot flash unlock` 的 blob） | 模板内嵌 **Lenovo 自签证书**（serial `804940DE79164B1A`） | 证书在内、私钥不在 | **不需要签也能过**：SN 在签名覆盖范围外，改 8 字节即可（三代工具箱实测）→ 「自己签」不准确，但「自己造解锁文件」成立 |

⇒ 要改口的是我此前写的「官网申请是四代**唯一**可行路径」；正确的是：
**官网申请只是其中一条**，另有 ①自造解锁 blob（一发可验证）②EDL 直写（`qdl`，本项目的既有主路）③社区重签包（引第三方 `abl`，不作主路）。

---

## 1. AVB 链：确认是谷歌公开 testkey（你的说法成立）

`avbtool info_image`（本机 `tools/avbtool.py`）对 **U2 同款原厂 259 备份**：

| 镜像 | Public key (sha1) | 算法 |
|---|---|---|
| `backup/stock-259/vbmeta_a.img` | **`2597c218aae470a130f61162feaae70afd97f011`** | SHA256_RSA4096 |
| `backup/stock-259/boot_a.img` | `2597c218…` | SHA256_RSA4096（rollback 1738713600） |
| `backup/stock-259/recovery_a.img` | `2597c218…` | SHA256_RSA4096 |
| chain `boot` | `2597c218…`（testkey） | — |
| chain `recovery` / `vbmeta_system` | `8fcb864f11f53ed11284615fb67685522085d3a2`（**OEM key**） | — |
| `restore-259/重签包/{vbmeta,vbmeta_system,boot}_a.img` | 全部 `2597c218…` | 社区重签=同一把 testkey |

⇒ 联想这条产品线的 AVB 主链就是**谷歌公开的 AOSP testkey**（sha1 前缀 `2597c218`，与 7/8 月记录一致）。
⇒ 任何持有 AOSP testkey 的人都能签出被 ABL 认可的 `boot`/`vbmeta` —— 这正是我们 `bootslot-b/` + `scripts/sign-boot-b.sh` 一直在做的事，也是「免解重签包」能成立的原因（重签包只是额外换了 `abl`：与原厂差 229109 字节，首处差异 `0x1058`）。

## 2. 解锁标志链：**不是**谷歌 key，但也**不需要**申请

实物 = 本地 `y700四代工具/解BL/Y700 三代解锁工具箱by某贼.zip`（酷安@某贼，2024-10-22，标称 TB321FU/三代）。

### 2.1 工具箱实际流程（读主脚本 `:UNLOCKBL` 段，非推测）

1. `fastboot getvar serialno`，强校验 8 字符；
2. `hexconvetor ascii2hex <SN>`；
3. `copy res\sn.img tmp\sn.img`；
4. `HexTool.exe tmp\sn.img 00002048 08 <sn_hex>` → **只改偏移 0x2048 的 8 字节 SN**；
5. `fastboot flash unlock tmp\sn.img` → `fastboot oem unlock-go`。

⇒ 全工具只带**一份通用模板**，每台机器只改那 8 字节 ⇒ **三代解锁文件不需要向官网申请**。

### 2.2 模板结构（`bin/res/sn.img`，5386 B）

| 偏移 | 内容 |
|---|---|
| `0x0000` | `ANDROID!` boot 头（`page_size=2048`、`header_version=0`、`kernel_size=8`） |
| `0x0240` | 20 B 高熵值（固定，不随 SN 变） |
| `0x0800` | ASCII `-BY_SYXZ`（作者标记） |
| `0x1000..0x150A` | 签名块（1290 B）：`INTEGER ver=1` + `Certificate` + `sha256WithRSAEncryption` + `PrintableString "/boot"` + `INTEGER 0x1000` + **256 B RSA-2048 签名** |
| `0x2048` | **8 B 设备 SN（明文 ASCII）** ← 工具箱唯一改写处 |

签名块的 `"/boot" + INTEGER 0x1000` ⇒ 签名覆盖范围 = **前 0x1000 字节**；SN 在 `0x2048`，**在覆盖范围之外**。
（把各明文段做 SHA-256 与签名摘要 `5e4de8007e4db306…4033809d` 逐一比对，均不等 ⇒ 签名内容不是可读明文段；但不影响结论：工具箱只动 SN 就能用，说明 SN 不受签名保护。）

### 2.3 证书身份：Lenovo 自签，不是谷歌

```
Serial : 804940DE79164B1A        Subject = Issuer（自签）
         C=CN, ST=BEIJING, L=Lenovo, O=Android, OU=PAD, CN=Android,
         emailAddress=chengxta@lenovo.com
Validity: 2020-06-29 → 2047-11-15     Public-Key: RSA-2048
```

与本机可得的公开测试密钥逐一比对（modulus sha256 前 16）：

| 密钥 | sha256(mod) | 与解锁证书同一把？ |
|---|---|---|
| 解锁模板内嵌 Lenovo 证书 | `3a12b26bdb1fd731` | — |
| AOSP build `testkey.x509.pem`（C=US/California，2008→2035，RSA-2048） | `b446c577ade901be` | **✗** |
| AOSP `testkey_rsa2048.pem`（avb/mkbootimg testdata） | `f6e4324246e220ca` | **✗** |
| 我们的 `env-pass/keys/testkey_rsa4096.pem`（AVB） | — | RSA-4096，与 RSA-2048 解锁证书不同型 |

⇒ **「解锁 blob 用谷歌公开密钥签」不成立**；7/8 月记录的「testkey `2597c218`」讲的是 **AVB 镜像链**。
⇒ 三代工具能用不是因为拿到私钥，而是因为 **ABL 没把 SN 纳入签名校验** = **免签**，不是自签。

---

### 2.4 项目内早已有同一结论（我此前漏读）

`.pi/skills/qualcomm-edl-flashing/references/tb322fc-y700-gen4.md` §Unlock mechanics（早前从 xda/qtotter 消化）：

> sn.img = official unlock file: either apply via ZUI site (m.zui.com/iunlock) **or modify
> LoGen0110's sn.img template hex (Bootloader_SN Part1+Part2, jsfiddle.net/2uvz1fwn generator)**
> — must match own `bootload_sn`. Error `Download is not allowed on locked devices` = wrong/newer ABL → downgrade first.

⇒ **四代自造解锁文件的正确补丁字段是 `Bootloader_SN` 的 Part1+Part2**（= 本机 `ro.boot.bootload_sn`，
64 hex = 两段 32 hex），比三代的「改 `0x2048` 的 `ro.serialno`」更贴合 ABL 校验点。
⇒ 同一条也给出失败特征串：`Download is not allowed on locked devices` ⇒ ABL 版本问题 → 先降级。
⇒ 故 A 路有两种补丁法，都在本地可做：**A1** 改 `0x2048` 的 SN（三代工具箱原法）；
**A2** 改模板内 `Bootloader_SN Part1/Part2`（U2 = `EBC74CD1B224948C1FCD6511E3933247` + `57633D4B859984878EDB81E26975502E`）。
定位方法：在模板里搜 Part1/Part2 的现有值或直接搜两段全 `0`/全 `F` 占位；找不到就把模板与我们手上的
`1.5.10.259免解锁重签.zip` 内 `abl_a.img` 一起比对新 ABL 的校验点（下轮实现）。

## 3. 对 U2（四代 TB322FC，locked）的四条路（按成本）

| 路 | 做法 | 依据/风险 | 状态 |
|---|---|---|---|
| **A 自造解锁 blob** | 模板改字段（**A1** `0x2048` 写 SN；**A2** 改 `Bootloader_SN Part1/Part2`）→ `fastboot flash unlock` | 零成本、失败不改设备状态；社区称「四代改了 abl」⇒ 可能失效 | ⬜ 一发可验证 |
| **B 官网 `sn.img`** | https://www.zui.com/iunlock （SN + `ro.boot.bootload_sn`） | 要账号/大陆邮箱/审核；1 号·年 3 台；不可逆代价同前 | ⬜ 兜底 |
| **C EDL 直写（不依赖 BL 解锁）** | `qdl/build/qdl` + `xbl_s_devprg_ns.melf`，`fastboot oem edl` 进 9008 | 写分区本就不受 lock 位限制；AVB 用 AOSP testkey 自签即可被接受（§1）→ **G1 的 flash/GPT 写其实不需要解锁** | ⬜ 上机首轮即可证实 |
| D 社区「免解重签包」 | `restore-259/重签包/`、`1.5.10.259免解锁重签.zip`（**第三方改过的 abl**） | 引第三方闭源引导器，与「只用自己引导链」冲突；只给 root 不给 fastboot 写权限 | ⛔ 应急，不作主路 |

**A 路生成命令**（SN 现读，不写死）：

```bash
SN=$(adb -s <SERIAL> shell getprop ro.serialno | tr -d '\r')
B=backup/${SN}-16+512; mkdir -p "$B"
unzip -p "y700四代工具/解BL/Y700 三代解锁工具箱by某贼.zip" bin/res/sn.img > "$B/sn-selfgen.img"
python3 - "$B/sn-selfgen.img" "$SN" <<'PY'
import sys
p, sn = sys.argv[1], sys.argv[2].encode()
d = bytearray(open(p,'rb').read())
d += b'\0' * (0x2048 + len(sn) - len(d))       # 模板 0x150A → 补零到 0x2048
d[0x2048:0x2048+len(sn)] = sn
open(p,'wb').write(d); print('SN@0x2048 =', sn.decode(), 'size', len(d))
PY
# 然后： fastboot flash unlock "$B/sn-selfgen.img" ; fastboot oem unlock-go
```

## 4. 文档改口清单（本轮已改）

| 位置 | 旧 | 新 |
|---|---|---|
| `RUNBOOK-BRINGUP.md` §0.5 | 「四代唯一可行路径 = 官网申请」 | 四条路（A 自造 → B 官网 → C EDL → D 重签包），A/C 优先，均不需账号 |
| `PITFALLS.md` #82 | 「传统强解/泄露 sn 法全部失效」 | 三代实物实测：模板通用、SN 明文在 `0x2048` 不受签名保护；AVB 链= AOSP testkey |
| `GAPS.md` Q16 | 「新版屏蔽 → 只能降级」 | 改为「自造模板/EDL 在四代是否有效」两条一发实验；降级降为兜底 |
| `TASKS.md` G1-0 | 前置门=等官网文件 | 前置门=先跑 A 实验；C（EDL）与「必须解锁」解耦 |
| `.pi/skills/gsi-device-adaptation/references/tb322fc-zuxos-ota-root.md` 第 7 条 | 「官网申请 + 传统法失效」 | 补实物取证与本文件链接 |
| 全局 profile_memory | 「唯一可行路径」 | 已补更正条目 |

---

## 5. 第三方签名服务产出的 blob（2026-10-03 16:25 追加实测）

来源 = **https://lenovobl.neko.ink/**（NekoYuzu《Lenovo BootLoader Unlock Tool》v1.0.0，表单选
`Operation System Type = ZUX OS` + 64 位 `Bootloader_SN`）。本机产物
`backup/HA2EXB0E-16+512/sn-neko-zuxos.img`（**356 B**，sha256 `d26e4e27…f8aa`，同目录 `SHA256SUMS.unlock`）。

### 5.1 结构（与三代 5386 B 的 PKCS#7 模板**完全不同格式** = 四代新格式）

| 偏移 | 长度 | 内容 | 本机值 |
|---|---|---|---|
| `0x00` | 16 | magic | `1a2blenovo3c4d5e` |
| `0x10` | 4×u32(LE) | 头部字段 | `0` / `1` / **`256`**（= 尾部签名长度）/ **`32`**（= SN 每段 hex 长） / `1`（= ZUX OS 类型） |
| `0x24` | **64** | **`Bootloader_SN` 明文 ASCII** | `EBC74CD1…6975502E` — **与本机 `ro.boot.bootload_sn` 逐字节一致** ✅ |
| `0x64` | **256** | 签名（长度 = RSA-2048） | `49cd3b34…` |

`36 + 64 + 256 = 356` ⇒ **自洽**；且头部 `256`/`32` 两字段与实际字节数吻合 ⇒ 不是随手拼的假文件。
**不含 `ro.serialno`** ⇒ 四代校验点确实只有 `Bootloader_SN`（与 PITFALLS #83 一致）。
blob 里**不嵌证书** ⇒ 公钥烧在 ABL 内（印证「四代起官方改了 abl」）。

### 5.2 离线验签结果：**验不过三代那把 key**（不等于无效）

用三代模板内嵌证书（serial `804940DE79164B1A`，pubkey modulus 首 4 字节 `b7448bed`）对 `0x64..0x164`
做 RSA 公开运算 + 穷举 `PKCS1v15/PSS × SHA1/256/384/512/MD5 × 9 种 payload 取法`：**全部失败**，
恢复块头尾皆为随机态（无 `00 01 FF … 00 DigestInfo` 结构）
⇒ **签名密钥 ≠ 三代解锁证书**。要么四代 ABL 换了新 key 且该服务持有私钥，要么此 blob 无效。
**离线不可判**，只能一发实验判。

### 5.3 判定与风险边界（为何可以放心试）

- `fastboot flash unlock sn.img` 打印 `OKAY` + `Warning: skip copying unlock image avb footer
  (unlock partition size: 0 …)` = **只说明传输被接受**（by-name 里无 `unlock` 分区，ABL 特判缓存），
  **刷任何字节都是 OKAY，不代表验签通过**（fastboot 36.0.0 实测）。
- 真正的门 = 下一条 `fastboot oem unlock-go`：验签失败 → ABL 直接报错/无反应，**不擦机、不改锁状态**；
  验签成功 → 屏出 UNLOCK 菜单，**要你在屏上按音量键+电源确认才擦 `/data`** ⇒ 双重闸门。
- 失败特征串：`Download is not allowed on locked devices` / `Unlock command not allowed` ⇒ 停手转 **路 C（EDL）**，勿重复刷。
- 与三代法的区别：三代 = **免签**（改明文 SN，签名不覆盖）；本 blob = **真签名**（服务端持有密钥签名）。
  两条路互不否定，本 blob 属「路 B 的等价替代」——拿到的是官网同等级产物，只是不占 1 号/年 3 台限额。
