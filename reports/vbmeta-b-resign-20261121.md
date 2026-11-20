# b 槽自签 AVB「债」还清（主机侧）：vbmeta_b 重签 + 生成器 + 门

> 日期 2026-11-21（无人值守轮次，设备**离线**：`05c6/18d1` 无枚举、fastboot 空、`ssh 192.168.7.1` 超时）。
> 本报告只做**主机侧造件与离线判据**；刷写/验收动作未执行（需设备窗口）。

## 0. 数字结论

| 项 | 结果 |
|---|---|
| 债的性质 | 设备在机 `vbmeta_b` 的顶层 key 与 chain `boot:3` 都指向 **旧钥 `fc1e3b33…`**，而 `boot_b` 的 AVB footer 已是 **现役钥 `1e54e86e…`** ⇒ **自签链自身不自洽** |
| 新件 | `out/vbmeta-b/vbmeta_b-flags3.img`（65536 B、Flags 3、rollback 0/0、顶层 key `1e54e86e…`、chain `boot:3` = `1e54e86e…`），sha256 **`906e69221701805c3d84890f80b9df59d3d13767331d87f7fe8cccdbde09678c`**（O_DIRECT 复算，两跑逐字节一致 —— PKCS#1 v1.5 签名确定性） |
| 离线判据 | 7 项全过（大小 / 顶层 key / chain key / Flags / boot 件 footer key / **整链 `verify_image --follow_chain_partitions` rc=0** / 翻字节必拒） |
| 反证（修复前） | 同一校验器跑**设备现役** `vbmeta_b`：顶层 key 与 chain 两处 FAIL + 整链验签 `Embedded public key does not match given key` ⇒ 门确实咬得住这次漂移 |
| 新增可复现件 | `scripts/build-vbmeta-b.sh`（`--check` 离线复核；`--flags/--key/--boot/--out-dir` 可选）+ `scripts/doctor/26-vbmeta-b-chain.sh`（`check-doctor` §26，含翻字节反作弊） |
| 未做（需设备/需决策） | ① 刷写与新件的真机回归；② `flags=0`「干净链」变体（需 `dtbo_b` 现役内容 dump 才能造 dtbo hash 描述符，且 flags=0 会**真校验** boot/dtbo） |

## 1. 取证（全部离线可复算）

```
# 设备在机 vbmeta_b（2026-11-20 22:20 EDL dump）
$ python3 tools/avbtool.py info_image --image logs/forensics-20261120-2210/vbmeta_b.img
Public key (sha1):        fc1e3b33f76b269c5ad5e570a4f776eb8701f24d
Flags:                    3
  Chain Partition descriptor: boot  Public key (sha1): fc1e3b33f76b269c5ad5e570a4f776eb8701f24d

# 设备在机 boot_b（同批 dump，sha256 740d431b…）
$ python3 tools/avbtool.py info_image --image logs/forensics-20261120-2210/boot_b.img
Public key (sha1):        1e54e86ef19fad73791ecbab052656356be99bd8

# 现役私钥
$ python3 tools/avbtool.py extract_public_key --key bootslot-b/avb.key --output /tmp/k && sha1(/tmp/k)
1e54e86ef19fad73791ecbab052656356be99bd8
```

⇒ 2026-10-18 换钥（`bootslot-b/avb.key` mtime 2026-10-18 08:33）后，`boot_b`（`scripts/sign-boot-b.sh` 每次打包都重签）
拿到的是新钥，而 `vbmeta_b` 从未重签。

## 2. 机制与**不作过度归因**

- **可证的部分**：自签链（vbmeta 顶层 → chain `boot:3` → boot 的 hash footer）现在**内部一致**，
  且这条一致性由 §26 门持续盯着（换钥忘了重签 ⇒ FAIL）。
- **不宣称的部分**：`fastboot boot` 之所以报 `Failed to load/authenticate boot image`，
  是否就由这条漂移直接导致，**本轮无设备、无法判决**。反方向的既有证据：`PITFALLS #146`
  记录过同一条命令的三种回话（`usb_read failed` / `OKAY` 后不跳 / `Invalid Parameter`），
  且接受与否与「另一槽是否 bootable」相关 ⇒ **机制不是单一 key 不一致能解释的**。
  另外 Flags=3 的语义（`VERIFICATION_DISABLED`）= ABL 连描述符都不解析，按 AOSP 语义
  这条漂移在**当前 flags 下本不该影响槽位启动**；它影响的是「哪天要切 flags=0 干净链」与
  「任何走 AVB 校验的路径（`fastboot boot` 是否校验、ABL 是否分支）」。
- **可判决的验收动作（需设备窗口，一条命令）**：
  ```bash
  timeout 60 fastboot flash vbmeta_b out/vbmeta-b/vbmeta_b-flags3.img
  timeout 30 fastboot boot bootslot-b/boot_b.img     # 成功 = 债了结；仍失败 = 归因排除本项
  ```
  回退件：`logs/forensics-20261120-2210/vbmeta_b.img`（在机现役）或 `backup/vbmeta_b-20261110.img`。

## 3. 为什么只造 `flags=3`

`flags=0` 变体（干净链、真校验）需要：
① `dtbo` 的 hash 描述符 —— 其 digest 必须对应**设备上现役 `dtbo_b` 内容**，而 b 槽 `dtbo_b` 是
2026-10-03 起按 G1-29 配方写全 0 的 32 MiB 区、**仓内没有它的 dump**，凭记忆造描述符等于制造
「描述符指向不明内容」的假账；
② 一次上机「boot+dtbo 全过校验」的样本。
⇒ 本轮不造，登记为「需要 `dtbo_b` dump 后再做」。

## 4. 门（`check-doctor` §26）

```
$ bash scripts/check-doctor.sh --only 26-vbmeta-b-chain.sh
== 26. b 槽自签 AVB 链一致性（vbmeta_b ↔ avb.key ↔ boot_b） ==
  [ok]   现役件与 avb.key 自洽（顶层 key + chain boot:3 + Flags + 整链验签）
  [ok]   反作弊通过（翻字节 ⇒ --check rc=1，门在读签名）
```

三态：`out/vbmeta-b/` 不存在 ⇒ `warn SKIP`（不装成 PASS）；件不自洽 ⇒ FAIL；全过 ⇒ ok。
反作弊按位取反一个字节（写死写 0 在原本是 0 的字节上等于没改 ⇒ 会假绿，已避免）。

## 5. 复现

```bash
scripts/build-vbmeta-b.sh                 # 造件 + 自检 + MANIFEST + O_DIRECT SHA256SUMS
scripts/build-vbmeta-b.sh --check         # 只验（doctor §26 委托此模式）
scripts/check-doctor.sh --only 26-vbmeta-b-chain.sh
```
