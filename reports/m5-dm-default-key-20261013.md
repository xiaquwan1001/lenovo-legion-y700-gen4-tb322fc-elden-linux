# M5 立项 — dm-default-key / fscrypt wrappedkey 的 out-of-tree 承载方案（2026-10-13）

> 任务：静态立项 + 承载方案设计（**不写驱动实现**）。
> 上位规则：`reports/upstream-policy-20261013.md` §6 第 1 行（C2 = out-of-tree patchset，永不进上游包）、§1 三问门、§3 Q3 违例清单；
> 状态指针：`TASKS.md` §7 M5 行（⬜ 未开工）。
> pristine 参照 = `geekidos-linux` @ `24a19b953e`（Linux 7.3-rc7，**孤儿快照提交**）。
> 本报告所有数字均附可复跑命令 + 原始输出片段；结论允许「当前未定/不需要」，但不得无据断言。

## §0 结论速览

**任务前提需要一处更正**：任务书写「本机内核树里 grep 不到 dm-default-key」——**不成立**。实测：

- **vendor 血统的树里早就有**：`clean/base`（= 现役构建树 `~/y700-elden/linux`，7.2.0 血统）与 `m1/clean-tree`（M1 资产树）**都含** `drivers/md/dm-default-key.c`（457 行）+ `Documentation/admin-guide/device-mapper/dm-default-key.rst` + Kconfig/Makefile 条目 + Android vendor key ABI 兼容层。
- **pristine 7.3-rc7 与 M3 血统的工作树里没有**：`24a19b953e` 与 `m3/usb-psy-name`（= `build/m2-worktree`）**零命中**。
- **pristine 7.3-rc7 已经自带替代品**：`drivers/md/dm-inlinecrypt.c`（620 行，**支持 `hw-wrapped` key_type**）+ fscrypt `FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED`（UAPI 公开）+ `block/blk-crypto` hw-wrapped key 基础设施 + `drivers/soc/qcom/ice.c` HWKM（wrapped key）支持。
- **这些代码在任何在用 config 里都没被启用**：三份 .config 对 `DM_DEFAULT_KEY` **零命中**；`CONFIG_DM_INLINECRYPT` **全部 is not set**。⇒ 现状是「树内死代码」，剥离**不会改动任何在跑镜像的行为**。
- **需求面**：宿主侧挂载 stock 加密 userdata = **当前不可达，且 M5 单件不能解锁**（树内文档自述需要 userspace + TEE 取密钥，且「Enabling this parameter does not recover Android keys」）；容器内 G2 = **未证实需要**（现役容器镜像的内核没编这个 target，C1/C3/C4/C6/C10 照样全绿）。
- **建议落点**：M5 的**第一动作就应该是「验证 + 剥离」而不是「新建 patchset」**——因为代码已经在 M1 树里，且 M1 树的 `dm-default-key.c` 就是 §6 隔离清单要隔离的那个东西（§4 给候选与首步命令）。

## §1 现状盘点：树里有什么、没有什么

### 1.1 项目里同时存在两条**不相交**的内核血统（关键结构事实）

```sh
$ git -C geekidos-linux log --oneline -5 24a19b953e
24a19b953e Linux 7.3-rc7                       # 只有 1 条 → 孤儿快照提交

$ git -C geekidos-linux rev-list --max-parents=0 clean/base
ba28ec16f01f59ba8f5099e8af9e95b061fc5c78        # vendor 血统的根
$ git -C geekidos-linux show -s --format='%H %an <%ae> %ad %s' ba28ec16f0
ba28ec16f01f59ba8f5099e8af9e95b061fc5c78  GEEKiDoS <geek_ds@foxmail.com> Mon Sep 14 12:37:40 2026 +0800 power: supply: qcom_battmgr: omit SM8750 maximum-load power reading
$ git -C geekidos-linux log --oneline clean/base | wc -l
23

$ git -C geekidos-linux merge-base --is-ancestor 24a19b953e clean/base;      echo rc=$?
rc=1
$ git -C geekidos-linux merge-base --is-ancestor 24a19b953e m1/clean-tree;   echo rc=$?
rc=1
$ git -C geekidos-linux merge-base --is-ancestor ba28ec16f0 m3/usb-psy-name; echo rc=$?
rc=1
$ git -C geekidos-linux merge-base --is-ancestor 24a19b953e m3/usb-psy-name; echo rc=$?
rc=0
```

| 树 / ref | 血统根 | 内核版本（`Makefile`） | fs/crypto 命名 | dm-default-key | Android vendor ABI |
|---|---|---|---|---|---|
| `24a19b953e`（pristine 参照） | 自身孤儿快照 | 7.3.0-**rc7** | `block.c` | ❌ | ❌ |
| `clean/base`（`5b169d5418`，= `~/y700-elden/linux`） | `ba28ec16f0`（GEEKiDoS） | 7.2.0 | `inline_crypt.c` | ✅ | ✅ |
| `m1/clean-tree`（`c73ff25222`，M1 资产树） | `ba28ec16f0` | 7.2.0 | `inline_crypt.c` | ✅ | ✅ |
| `m3/usb-psy-name`（`6d73764570`，= `build/m2-worktree`） | `24a19b953e` | 7.3.0-rc7 | `block.c` | ❌ | ❌ |

```sh
$ git -C geekidos-linux show clean/base:Makefile | head -4   → VERSION=7 PATCHLEVEL=2 SUBLEVEL=0
$ git -C geekidos-linux show 24a19b953e:Makefile | head -4   → VERSION=7 PATCHLEVEL=3 SUBLEVEL=0 EXTRAVERSION=-rc7
$ git -C geekidos-linux ls-tree 24a19b953e fs/crypto/ | grep -E 'block|inline' → block.c
$ git -C geekidos-linux ls-tree clean/base  fs/crypto/ | grep -E 'block|inline' → inline_crypt.c
$ git -C geekidos-linux worktree list   # 现役工作树
/home/xuqianhui1001/y700-elden/geekidos-linux               5b169d5418 [clean/base]
/home/xuqianhui1001/y700-elden/build/m1-upstream/clean-tree c73ff25222 [m1/clean-tree]
/home/xuqianhui1001/y700-elden/build/m2-worktree            6d73764570 [m3/usb-psy-name]
```

**推论 1**：M1「上游资产树」实际是 **vendor 血统**（M3 系列工作树才是 pristine 血统）⇒ `TASKS.md` §7 M5 的判据「上游包内无 Android vendor ABI」**目前不满足**，M5 的剥离对象 = `m1/clean-tree`（唯一带 vendor ABI 的树）。
**推论 2**：两条血统无祖先关系 ⇒ 不能用 `git diff 24a19b953e clean/base` 做「payload 差分」（会得到 106 个文件、fs/crypto 整文件改名等噪声），剥离线只能按**文件清单 + 符号清单**逐项做（§1.3）。

### 1.2 检索矩阵（4 ref × 6 模式）

```sh
# 全矩阵生成命令（逐格）
for r in 24a19b953e clean/base m1/clean-tree m3/usb-psy-name; do
  for p in dm_default_key dm-default-key wrappedkey inlinecrypt __FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED; do
    echo "$r $p $(git -C geekidos-linux grep -l -- "$p" $r 2>/dev/null | wc -l)"
    git -C geekidos-linux grep -ln -- "$p" $r 2>/dev/null | head -4
  done
done
```

| 模式 | `24a19b953e` | `clean/base` | `m1/clean-tree` | `m3/usb-psy-name` |
|---|---|---|---|---|
| `dm_default_key` | **0** | **8** 文件 | **8** 文件 | **0** |
| `dm-default-key` | **0** | **5** 文件 | **5** 文件 | **0** |
| `dm_default_key_ciphers` | 0 | 1（`dm-default-key.c`） | 1 | 0 |
| `wrappedkey` | **1**（`drivers/md/dm-table.c`） | **5** | **5** | **1**（`dm-table.c`） |
| `inlinecrypt` | **13** | 15 | 15 | **13** |
| `__FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED` | **0** | **5** | **5** | **0** |

命中文件（`clean/base` 血统，命令 `git grep -ln -- '<pat>' <ref>`）：
- `dm_default_key`：`block/bio.c`、`block/blk-crypto-fallback.c`、`drivers/md/dm-default-key.c`、`fs/crypto/inline_crypt.c`（+ Kconfig/Makefile/doc/…）
- `dm-default-key`：`Documentation/admin-guide/device-mapper/dm-default-key.rst`、`…/index.rst`、`drivers/md/Kconfig`、`drivers/md/Makefile`、`drivers/md/dm-default-key.c`
- `__FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED`：`…/dm-default-key.rst`、`fs/crypto/fscrypt_private.h`、`fs/crypto/keyring.c`、`include/uapi/linux/fscrypt.h`（+1）

**关键区分**：`wrappedkey` 在 **pristine 也有 1 处**（`drivers/md/dm-table.c`）——那是**上游自带的 DM 侧 hw-wrapped key 回调 API**（`enum dm_wrappedkey_op` / `dm_exec_wrappedkey_op`，pristine `dm-table.c:1183–1344`），属于上游框架，**不是 vendor ABI**。真正 vendor 的只有三块：`dm-default-key.c` 目标本体、UAPI 里的 `__FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED`、fs/crypto 的 Android 兼容分支。

### 1.3 vendor ABI 与上游 ABI 的精确差异

**(a) UAPI（`include/uapi/linux/fscrypt.h`）**

```sh
$ git -C geekidos-linux diff <(git show 24a19b953e:include/uapi/linux/fscrypt.h) \
                             <(git show clean/base:include/uapi/linux/fscrypt.h)
@@ -129,7 +130,10 @@ struct fscrypt_add_key_arg {
   __u32 key_id;
 #define FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED	0x00000001
   __u32 flags;
-  __u32 __reserved[7];
+  __u32 __reserved[6];
+  /* Original Android wrappedkey_v0 ABI, distinct from upstream flags. */
+#define __FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED		0x00000001
+  __u32 __flags;
   __u8 raw[];
 };
```
⇒ vendor 的「hfscrypt 风格 ABI」= **从 `__reserved` 里挖出 4 字节当 `__flags`**（AOSP 原样）；上游 7.3-rc7 的同名能力走 `flags` + `FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED`。

**(b) 内核侧兼容分支（`fs/crypto/keyring.c`，`clean/base`）**
```sh
$ git -C geekidos-linux show clean/base:fs/crypto/keyring.c | grep -n 'arg.__flags\|android_compat\|is_hw_wrapped'
758:	if (arg.__flags) {
760:		if (arg.__flags & ~__FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED)
765:		secret.android_compat = true;
773:		secret.is_hw_wrapped = true;
$ git -C geekidos-linux show clean/base:fs/crypto/keyring.c | sed -n '757,766p'
	if (arg.__flags) {
		/* Support for the original Android flag */
		if (arg.__flags & ~__FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED)
			return -EINVAL; /* unknown flags */
		if (arg.flags & FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED)
			return -EINVAL; /* conflicting flags */
		arg.flags |= FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED;
		secret.android_compat = true;
	}
$ git -C geekidos-linux show clean/base:fs/crypto/keyring.c | grep -n 'android_compat'
563:			keyid_kdf_ctx = secret.android_compat ?
$ git -C geekidos-linux show clean/base:fs/crypto/keysetup.c | grep -n 'use_hw_wrapped_key'
229:	bool use_hw_wrapped_key = false;   246: use_hw_wrapped_key = true;   271: if (use_hw_wrapped_key)
```
⇒ 兼容层 = ① 接受 `__flags` 位并折算到上游 `flags`；② 用不同的 HKDF context（`android_compat`）保持 Android 的 key identifier 派生；③ `fs/crypto/fscrypt_private.h:407` `HKDF_CONTEXT_KEY_IDENTIFIER_FOR_HW_WRAPPED_KEY`。

**(c) DM 目标本体与选项**
```sh
$ git -C geekidos-linux show clean/base:drivers/md/dm-default-key.c | wc -l          → 457
$ git -C geekidos-linux show 24a19b953e:drivers/md/dm-inlinecrypt.c | wc -l         → 620
$ git -C geekidos-linux show clean/base:drivers/md/dm-default-key.c | grep -n 'wrappedkey\|.name' 
118:		} else if (!strcmp(opt_string, "wrappedkey_v0")) {
119:			dkc->key_type = BLK_CRYPTO_KEY_TYPE_HW_WRAPPED;
365:				DMEMIT(" wrappedkey_v0");
426:	.name			= "default-key",
$ git -C geekidos-linux show clean/base:drivers/md/Makefile | grep -n 'default-key\|inlinecrypt'
57:obj-$(CONFIG_DM_DEFAULT_KEY)	+= dm-default-key.o
59:obj-$(CONFIG_DM_INLINECRYPT)	+= dm-inlinecrypt.o
$ git -C geekidos-linux show clean/base:drivers/md/Kconfig | grep -n 'DM_DEFAULT_KEY\|DM_INLINECRYPT'
318:config DM_DEFAULT_KEY
338:config DM_INLINECRYPT
$ git -C geekidos-linux show 24a19b953e:drivers/md/Kconfig | grep -n 'DM_DEFAULT_KEY\|DM_INLINECRYPT'
294:config DM_CRYPT
318:config DM_INLINECRYPT          # ← pristine 只有 INLINECRYPT，没有 DEFAULT_KEY
```

**(d) 上游侧现成能力（pristine 7.3-rc7 自带）**
```sh
$ git -C geekidos-linux show 24a19b953e:include/linux/blk-crypto.h | grep -n -A3 'enum blk_crypto_key_type'
26: enum blk_crypto_key_type {
31:   BLK_CRYPTO_KEY_TYPE_RAW = 0x1,
39:   BLK_CRYPTO_KEY_TYPE_HW_WRAPPED = 0x2,
$ git -C geekidos-linux show 24a19b953e:include/uapi/linux/fscrypt.h | grep -n 'FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED'
130:#define FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED	0x00000001
$ git -C geekidos-linux show 24a19b953e:drivers/md/dm-inlinecrypt.c | grep -n 'key_type\|hw-wrapped'
269:  ctx->key_type = BLK_CRYPTO_KEY_TYPE_RAW;
270:  } else if (!strcmp(val, "hw-wrapped")) {
271:  ctx->key_type = BLK_CRYPTO_KEY_TYPE_HW_WRAPPED;
$ git -C geekidos-linux show 24a19b953e:drivers/soc/qcom/ice.c | grep -n 'wrapped'
102:static bool qcom_ice_use_wrapped_keys;
179:	if (ice->hwkm_version && qcom_scm_has_wrapped_key_support()) {
```

### 1.4 已知线索核对（HINDSIGHT / PITFALLS 行号）

```sh
$ sed -n '1516,1519p' flashing-bundle/profile/memory/HINDSIGHT.md
userdata /data f2fs ... fileencryption=aes-256-xts... keydirectory=/metadata/vold/metadata_encryption,
         metadata_encryption=aes-256-xts:wrappedkey_v0, inlinecrypt
$ sed -n '1582,1583p' flashing-bundle/profile/memory/HINDSIGHT.md
1. **Gen4 userdata 是 metadata 加密 f2fs**（`metadata_encryption=aes-256-xts:wrappedkey_v0`，key 硬件包裹）→ **mainline 和 Android root 都拿不到裸密钥**，不能软件解密。
2. **TWRP 能解 metadata 加密**（dm-default-key），`/data` 可挂载；
$ sed -n '291,293p' flashing-bundle/workspace/PITFALLS.md   # = 项目根 PITFALLS.md:598–600（第 57 条）
57. **Gen4 的 userdata 是 metadata 加密 f2fs**（`metadata_encryption=aes-256-xts:wrappedkey_v0`，
    key 在 `/metadata`、硬件包裹）→ **mainline/root 都拿不到裸密钥**，不能软件解密。
    但 **TWRP 能解 metadata 加密**（它有 keymaster + dm-default-key），`/data` 可挂载；
```
**核对结论**：三条线索**全部成立**（设备 fstab 确实是 `wrappedkey_v0` + `inlinecrypt`；解 metadata 加密确需 keymaster + dm-default-key），但它们都是**设备侧/TWRP 侧事实**，**不能推出「本机主线内核树里有这个驱动」**——任务书据它们做的推断与 §1.2 实测相反。

### 1.5 树内代码的**编译/运行状态**（决定剥离成本）

```sh
$ for f in build/m1-upstream/clean-tree/.config linux/.config build/m2-worktree/.config; do
    echo "== $f"; grep -n 'DM_DEFAULT_KEY' $f; echo "  rc=$?";
    grep -n 'DM_INLINECRYPT\|BLK_INLINE_ENCRYPTION=y' $f; done
== .../m1-upstream/clean-tree/.config     (322076 B, Oct 11 16:27)
  rc=1                                    # ← 零命中
886:CONFIG_BLK_INLINE_ENCRYPTION=y
2613:# CONFIG_DM_INLINECRYPT is not set
== .../linux/.config                       (322099 B, Oct 12 08:05)
  rc=1
886:CONFIG_BLK_INLINE_ENCRYPTION=y
2614:# CONFIG_DM_INLINECRYPT is not set
== .../build/m2-worktree/.config           (324819 B, Oct 13 16:57)
  rc=1
891:CONFIG_BLK_INLINE_ENCRYPTION=y
2621:# CONFIG_DM_INLINECRYPT is not set
$ grep -rn 'DM_DEFAULT_KEY' patches/*.config patches/*.bak | wc -l
0
```
**结论**：`DM_DEFAULT_KEY`（tristate）在三份在用 .config 里**完全没有出现** ⇒ 从未编进任何在跑内核/模块；`DM_INLINECRYPT` 显式关。⇒ **M5 是纯静态剥离，零运行时回归面**（⚠ 与 §1.1 的「树内死代码」同义）。

### 1.6 这些 vendor 代码的**来源**

```sh
$ git -C geekidos-linux log --oneline -S'__FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED' clean/base
ba28ec16f0 power: supply: qcom_battmgr: omit SM8750 maximum-load power reading
$ git -C geekidos-linux log --oneline -S'android_compat' clean/base
ba28ec16f0 …
$ git -C geekidos-linux log --oneline --diff-filter=A clean/base -- drivers/md/dm-default-key.c
ba28ec16f0 …
# stock Lenovo GKI 模块清单里也登记了这个文件：
$ grep -n 'dm-default-key' stock-src/android_kernel_lenovo_sm8750/files_gki_aarch64.txt
1241:drivers/md/dm-default-key.c
```
⇒ 该代码**随 GEEKiDoS `v7.2-elden` 基座（root commit `ba28ec16f0`，作者 GEEKiDoS，2026-09-14）整体导入**，与 AOSP/联想 GKI 同源；**不是本项目 payload**（但 `clean/base` 历史被 graft 成 23 提交的单根，`git log -S` 只能归到 root commit，**无法进一步区分「上游作者自带」与「更早一次导入时被合并」**——见 §5 未决问题 U1）。

## §2 需求面：到底需不需要（取证式判定）

### 2.1 两个东西各解决什么（据树内/上游文档原文）

- **dm-default-key = Android metadata encryption**：给「不属于任何加密文件的块」（文件系统元数据、目录项、未加密文件内容）套一个默认 key，同时**让 fscrypt 文件内容直通不二次加密**。树内 doc 原文：
  ```sh
  $ git -C geekidos-linux show clean/base:Documentation/admin-guide/device-mapper/dm-default-key.rst | sed -n '7,14p'
  The ``default-key`` target implements Android metadata encryption. It encrypts
  filesystem metadata and unencrypted file contents, while passing through fscrypt
  file contents without applying a second layer of encryption.
  This target is adapted from Android common and the Lenovo Android kernel.
  ```
- **fscrypt wrappedkey = 密钥不以明文驻留内核内存**：android wrapped key 用于「硬件包裹密钥」（KeyMint 包裹 → 内核只持有 ephemeral wrapped 形态 → ICE/HWKM 解包）。上游对应物 = `Documentation/block/inline-encryption.rst` §Hardware-wrapped keys（`_hardware_wrapped_keys`）+ `FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED`。
- **两者是配对关系**：metadata 加密的 key 在 Android 上就是 `wrappedkey_v0`（= 硬件包裹），所以 dm-default-key 提供 `wrappedkey_v0` 选项（§1.3c:118–119），fscrypt 提供 Android 的 `__flags` ABI（§1.3a）。

### 2.2 宿主 Linux 侧访问 stock userdata：**当前不可达；且 M5 单件不能解锁**

树内 doc 自己就写了结论（不是我们的推断）：
```sh
$ git -C geekidos-linux show clean/base:Documentation/admin-guide/device-mapper/dm-default-key.rst | sed -n '52,74p'
Read-only access to an existing Android filesystem
  First obtain the correct metadata key through compatible userspace and the device's TEE. …
  Qualcomm ICE requires `qcom_ice.use_wrapped_keys=1` at boot to opt into HWKM.
  Enabling this parameter does not recover Android keys.
  … Neither interface obtains keys from Android KeyMint, authenticates the user's
  credential, or unlocks files by itself.
```
配合 `PITFALLS #57`（「key 在 `/metadata`、硬件包裹 → mainline/root 都拿不到裸密钥」；TWRP 靠自带 **keymaster + dm-default-key** 才能挂）⇒
**判定 = 不需要（本场景），且「加进内核」不是瓶颈**：瓶颈是**用户态取密钥通路（KeyMint/TEE）+ ICE HWKM 开关 + ephemeral wrapped key 的产生**。把 dm-default-key 编进内核，只会把失败点从「没有 target」前移到「没有 key」。

### 2.3 容器内 G2（Waydroid / redroid）：**未证实需要；现有证据方向相反**

- 现役容器镜像所用内核对 `DM_DEFAULT_KEY` **零启用**（§1.5）——即容器是在**内核没有该 target** 的情况下跑到达标的：C1（去 workaround 出网，`curl baidu=200`）、C3（GMS 登录 + Google 204）、C4（6 传感器 running）、C6（codec 53 + 闹钟出声）、C10（振动幅度/cancel）全部为 ✅（`TASKS.md` §2 C1/C3/C4/C6/C10 行）。
- 全仓报告检索：容器相关报告**没有任何一处**提到 fscrypt / fileencryption / metadata 加密需求：
  ```sh
  $ grep -rln 'fscrypt\|fileencryption' reports/ archive/ | head
  reports/upstream-policy-20261013.md
  archive/topics/UPSTREAM-REVIEW-2026-10-04.md
  ```
  （命中的两份都是**策略文档**，不是容器实测报告。）
- 反方向风险也记一笔：**Play Integrity 与本件无关**（PI 判的是 build 指纹/密钥/认证状态，不是磁盘加密），`reports/c3-identity-drm-20261013.md` 的 PI 前置失败原因是 `userdebug`+`test-keys`，不是「userdata 没加密」。⇒ 政策 §6 把 C2 标成「G2 必需」目前**缺证据**。

**判定 = 未定（倾向不需要）**。需容器侧取证（设备侧，本轮为纯主机任务，只给命令）：`adb shell getprop ro.crypto.state / ro.crypto.type`、`adb shell 'dumpsys mount | grep -i dm-'`、`adb shell 'cat /proc/mounts | grep data'`。

### 2.4 需求判定汇总

| 场景 | 判定 | 证据 |
|---|---|---|
| 宿主侧**读** stock 加密 userdata（如接管 Android 数据） | **不需要（本件）**：M5 不解锁；瓶颈=密钥通路 | §2.2 两段原文 + `PITFALLS #57` |
| 宿主侧**写/重建** userdata（GPT 缩容后的现状路线：擦除重建） | **不需要** | `PITFALLS #58`：缩容后 Android 自建；我们从不读其内容 |
| 容器内 G2（Waydroid/redroid） | **未定（倾向不需要）** | §2.3：现役内核未编该 target 而 C1/C3/C4/C6/C10 全绿 |
| 上游包整洁性（M5 判据本身） | **需要剥离** | `TASKS.md` §7 M5 判据 + 政策 §6 第一行 |
| 未来「把 Android 数据搬进容器 / 容器内跑 FBE」 | 未评估（新需求才需重新立项） | — |

## §3 承载方案对比（≥2 个候选）

**设计约束（由 §1/§2 实测导出）**
1. **红线**：上游包（= 未来提交给上游的树 / M3 血统工作树）不得含 vendor key ABI（`dm-default-key` 目标 + `__FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED`）。
2. **需求侧**：当前**没有任何已证实的功能需求**（§2.4）⇒ 任何方案都必须「默认不启用 + 秒级回退」。
3. **双血统**：vendor 代码挂在 7.2.0 血统（`fs/crypto/inline_crypt.c`），上游是 7.3-rc7 血统（`fs/crypto/block.c`）⇒ 任何"加回去"的补丁都**只有对同血统基座**才近乎无冲突。
4. **UAPI 不可模块化**：`__flags` 是编译期结构体字段（§1.3a）⇒ 「Android ABI 兼容」这件事**无法**只靠一个 =m 模块完成，必须在树内改头文件（这条直接决定候选 (b) 的性价比）。

### 3.1 候选 (a) out-of-tree 内核 patchset（政策 §6 原定方案）

- **形态**：`patches/out-of-tree-dm-default-key/patches/000{1..3}-*.patch`（① dm-default-key 目标本体 + Kconfig/Makefile；② UAPI `__flags` + fs/crypto 兼容分支；③ doc），由构建前的一步 `git apply` 按需注入内核树；**默认不注入**。
- **实现代价**：**低**——代码 100% 已存在（457 行目标 + ~40 行 UAPI/兼容 + doc），只需「从现有树反向导出」；不需要新写任何驱动。
- **红线合规**：达标（上游包内可做到零命中；patchset 永不进包、永不上 ML）。
- **M1 树/重构建接入点**：与 `scripts/apply-kernel-fragment.sh`（`FRAG=` 合并 → `SNAP=` 快照）同层加 `scripts/apply-out-of-tree.sh`（或在 `scripts/build-kernel.sh` 之前手工 apply）；config 侧配 `patches/fragment-dm-default-key.config`（`CONFIG_DM_DEFAULT_KEY=m`、`CONFIG_FS_ENCRYPTION_INLINE_CRYPT=y`）；运行时 HWKM 开关走 cmdline `qcom_ice.use_wrapped_keys=1`（**不是** config，见树内 doc 原文 §2.2）。改动存档沿用 `patches/kernel-history/<branch>/` 约定（`patches/README.md`）。
- **回退方式**：`git checkout -- <files>`（源码级）；`.config` 回 `patches/config-before-fragment-*.bak`；镜像级回退 = 现役 `boot_b` 镜像（不动 GPT/槽位）。
- **风险**：与基座强耦合（约束 3）⇒ 每次换基座要重基 1 次；且 UAPI 补丁改的是**行数敏感**的 `__reserved[7]→[6]`（若上游将来收紧该结构体，补丁会冲突——按 §1.3a 现在是双方一致的 7→6 偏移，冲突面小）。

### 3.2 候选 (b) 上游包只留通用 hook、vendor 实现独立模块

- **形态**：上游包里保留上游 hook（**实际上已经存在**：`dm-table.c` 的 `dm_wrappedkey_op`/`dm_exec_wrappedkey_op` + `FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED`），Android 语义放独立模块。
- **致命点**：约束 4。`__FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED` 在 `include/uapi/linux/fscrypt.h` 的**结构体布局**里，模块改不了 UAPI ⇒ 想同时满足「上游包零 vendor ABI」+「Android userspace 二进制可 ABI 兼容」只能再写一个**独立 misc 驱动**（提供 Android 语义 ioctl → 转译到上游接口）。这等于把 40 行兼容代码换成几百行新代码。
- **实现代价**：中～高（新模块 + 转译层 + 自己的测试面）。
- **红线合规**：**高**（上游包内连 vendor 结构体都不留）——但这是它唯一相对 (a) 的优势。
- **接入点**：同 (a) 的 patchset 机制 + 一个 =m 模块（可走 `scripts/mod-loop.sh` 热换）。
- **回退方式**：`rmmod` + 不注入 patchset。
- **评价**：**不建议**。收益（上游包内少 40 行）远小于成本，且当前**没有**证明 Android userspace 必须与同一内核对话（§2.3 未定）。

### 3.3 候选 (c) 完全不进内核（用户态）

- **形态**：① 复用 **TWRP**（自带 keymaster + dm-default-key，`PITFALLS #57` 实测可挂 `/data`）；② 只要**块层解密**时用内核既有 `dm-crypt` + 从 TEE/KeyMint 取得的 key 手工建表（零新内核代码）；③ 纯用户态 FUSE 解密——**没有 key 一样不可能**。
- **实现代价**：**零内核代码**；代价全在「取 key」这一外部前提。
- **红线合规**：完美（内核零 vendor ABI）。
- **接入点**：无（需要时用 TWRP 引导，或 host `dmsetup`）。
- **回退方式**：天然。
- **评价**：**对"宿主读 stock userdata"这是当前唯一有实测先例的路线**（TWRP）；但它对"容器内 Android 自己要元数据加密"（若将来被证实）**无能为力** ⇒ 定位 = 兜底，不是主选。

### 3.4 候选 (d) 直接用上游 `dm-inlinecrypt` + 上游 `HW_WRAPPED` ABI（**本报告新增**，证据驱动）

- **形态**：内核侧**零 vendor 代码**。pristine 7.3-rc7 已具备全部零件（§1.3d）：`dm-inlinecrypt`（`hw-wrapped` key_type，key 从内核 keyring 以 `<type>:<desc>` 传入）、fscrypt `FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED`、blk-crypto `BLK_CRYPTO_KEY_TYPE_HW_WRAPPED`、`drivers/soc/qcom/ice.c` 的 HWKM 路径（`qcom_scm_ice_set_key`）。宿主建表 = `dmsetup create <name> --table '0 <n> inlinecrypt aes-xts-plain64 hw-wrapped logon:<keydesc> <iv_offset> <dev> <start>'`。
- **实现代价**：内核 **0 行**；代价 = 必须先验证**磁盘格式兼容性**（`dm-inlinecrypt` 的 IV/DUN 布局 vs `dm-default-key` 写出的卷）——**目前未验证**（§5 U3）。
- **红线合规**：**最高**（完全上游；连 patchset 都不需要）。
- **接入点**：只动 config——`CONFIG_DM_INLINECRYPT=m`（三份在用 .config 现为 `is not set`，§1.5）；无源码补丁，不需要 `patches/out-of-tree-*`。
- **回退方式**：config 关掉（`CONFIG_DM_INLINECRYPT` 是独立 tristate，关闭不影响其它任何功能）。
- **评价**：与项目「上游化」目标**同向**，且是唯一「内核包永远干净」的路线；**限制**：不能冒充 Android 的 `default-key` 目标名（fs_mgr 硬编码），因此**不服务原厂 userspace**——而 §2.3 未证实我们存在这种需求。

### 3.5 对比矩阵

| 维度 | (a) out-of-tree patchset | (b) hook + 独立模块 | (c) 用户态 | (d) 纯上游 dm-inlinecrypt |
|---|---|---|---|---|
| 内核代码量 | 0 新增（复用现有 457+40 行） | 0 现有 + 新写模块/转译层 | **0** | **0** |
| 实现代价 | 低（导出+剥离） | 中～高 | 无内核代价，受限于取 key | 低（开 config）+ 一次格式验证 |
| 红线（上游包无 vendor ABI） | ✅（默认不注入） | ✅✅ | ✅✅ | ✅✅（最干净） |
| 与 M1 树/重构建接入点 | `scripts/apply-out-of-tree.sh` + `fragment-dm-default-key.config` | 同上 + `mod-loop` 热换模块 | 不接入（TWRP/dm-crypt） | 仅 `CONFIG_DM_INLINECRYPT=m` |
| 回退方式 | `git checkout` / config 回退快照 | `rmmod` + 不注入 | 天然 | 关 config |
| 能服务 Android 原厂 userspace（若将来需要） | ✅（要重基） | ✅ | ❌ | ❌（目标名不同） |
| 当前需求（§2.4 全为"不需要/未定"）下的性价比 | **首选（封存）** | 最低 | **兜底** | **首选（能力）** |

## §4 建议与下一步

**推荐 = (d) 作为内核能力 + (a) 作为封存**（两者不冲突，且各自都满足红线）：

1. **能力侧选 (d)**：不写任何内核代码；当需要用加密映射时，打开上游 `dm-inlinecrypt`，用它替代"再加一个 vendor 目标"。前提是先做 §5 U3 的格式验证（**尚未做**）。
2. **封存侧选 (a)**：把已经躺在 `m1/clean-tree` 里的三块 vendor 代码**反向导出**成 patchset（默认不注入），从而同时达成 M5 判据「上游包内无 Android vendor ABI」。
3. **不做 (b)**（约束 4 使其性价比最低）；**(c) 保留为兜底**（TWRP 路线已在 `PITFALLS #57` 实测可用）。

**具体第一步（命令级；本任务只建目录与 README，以下为授权后待执行）**

```sh
# ① 反向导出（在 vendor 血统树上生成"加回 vendor ABI"的补丁）
git -C geekidos-linux diff -R clean/base \
    -- drivers/md/dm-default-key.c drivers/md/Kconfig drivers/md/Makefile \
       include/uapi/linux/fscrypt.h fs/crypto \
       Documentation/admin-guide/device-mapper \
  > patches/out-of-tree-dm-default-key/patches/0001-vendor-key-abi.patch
# ② 核对该补丁只碰这 6 类文件（应当无第 7 类）
grep '^+++ b/' patches/out-of-tree-dm-default-key/patches/0001-vendor-key-abi.patch | sort -u

# ③ 剥离（在 M1 树的新分支上做；不要动 m1/clean-tree 本体）
git -C geekidos-linux checkout -b m5/strip-vendor-abi m1/clean-tree
git -C geekidos-linux rm drivers/md/dm-default-key.c \
    Documentation/admin-guide/device-mapper/dm-default-key.rst
#    + 恢复 Kconfig/Makefile/index.rst/uapi/fscrypto 到上游形态（逐文件 hunk）
git -C geekidos-linux commit -m "m5: strip Android vendor key ABI from the upstream package"

# ④ 判据自检（期望两条都是 0）
git -C geekidos-linux grep -ln 'dm-default-key\|__FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED' m5/strip-vendor-abi | wc -l
```

**依赖的外部信息**
- **不需要联网下载**：参考实现（Android 版 `dm-default-key.c`、上游 `dm-inlinecrypt.c`、上游 hw-wrapped key 文档）**都已经在本地树里**（§1.2/§1.3 命令可直接取出）。
- 若将来要 AOSP userspace 参考（`vold`/`fs_mgr` 如何建表、如何从 KeyMint 取 wrapped key）：来源 = AOSP（Apache-2.0）；**本任务不下载**。
- 唯一硬前提 = **设备侧取证**（能否取得 metadata key / 容器是否加密），见 §5 U2。

## §5 产物清单 + 验证命令 + 未决问题

### 5.1 产物清单（绝对路径）

| 产物 | 说明 |
|---|---|
| `/home/xuqianhui1001/y700-elden/reports/m5-dm-default-key-20261013.md` | 本报告（§0–§5） |
| `/home/xuqianhui1001/y700-elden/patches/out-of-tree-dm-default-key/README.md` | 封存目录说明（形态/生成命令/红线/回退） |
| `/home/xuqianhui1001/y700-elden/patches/out-of-tree-dm-default-key/patches/` | 占位（补丁本体 ① 步生成后落此） |
| `/home/xuqianhui1001/y700-elden/patches/out-of-tree-dm-default-key/tests/` | 占位（格式验证脚本/取证记录） |

### 5.2 每条结论的验证命令

| 结论 | 验证命令 |
|---|---|
| pristine 无 dm-default-key、有 dm-inlinecrypt | `git -C geekidos-linux grep -ln 'dm-default-key' 24a19b953e`（rc=1）；`git -C geekidos-linux ls-tree 24a19b953e drivers/md/ | grep inlinecrypt` |
| M1 树仍含 vendor ABI | `git -C geekidos-linux grep -ln 'dm-default-key\|__FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED' m1/clean-tree`（5+5 文件） |
| pristine 与 M1 无祖先关系（双血统） | `git -C geekidos-linux merge-base --is-ancestor 24a19b953e m1/clean-tree; echo rc=$?` → 1 |
| 所有在用 config 都没启用 | `for f in ${HOME}/y700-elden/{linux,build/m1-upstream/clean-tree,build/m2-worktree}/.config; do grep -c . "$f"; grep -n DM_DEFAULT_KEY "$f"; done` → 三份均 rc=1 |
| 需求未证实 | `grep -rln 'fscrypt\|fileencryption' reports/ archive/` → 只命中 2 份策略文档，无容器报告 |

### 5.3 未决问题

| # | 问题 | 需要什么 | 阻塞面 |
|---|---|---|---|
| **U1** | vendor 三块代码的确切来源（GEEKiDoS 基座自带 vs 更早一次导入）——`clean/base` 历史被 graft 成 23 提交单根，`git log -S` 只能归到 root commit | 基座上游 `GEEKiDoS/linux` 的 `v7.2-elden` 远端比对（**本任务按纪律未联网取**） | 影响"剥离"是否能写进 `patches/kernel-history` 的可复现谱系 |
| **U2** | 容器/宿主**是否真的需要** metadata 加密（§2.3 判定=未定） | 设备侧：`adb shell getprop ro.crypto.state`/`ro.crypto.type`、`dumpsys mount | 决定 (a) 是否值得封存、(c)/(d) 是否只是兜底 |
| **U3** | `dm-inlinecrypt` 能否读 `dm-default-key` 写出的卷（IV/DUN 布局是否一致） | 一次设备侧/宿主侧只读实验（**需要 key**，与 U2 同源） | 决定候选 (d) 是否真能替代 (a) |
| **U4** | vendor 补丁重基到上游血统（`inline_crypt.c`→`block.c`）的实际冲突面 | 一次 `git apply --3way` / `git am --3way` 试算 | 决定 (a) 的长期维护成本 |
| **U5** | M1「上游资产树」为何是 vendor 血统（而非 `24a19b953e`）——若不是笔误，则 M5 的"上游包"定义需父 agent 明确 | 父 agent 裁决 | 决定剥离对象是 `m1/clean-tree` 还是另立上游血统树 |

### 5.4 本任务的边界声明
- 未改任何内核树/源码（`git status` 在 `geekidos-linux` 与工作树均无本任务产生的改动）。
- 未联网、未碰设备、未跑 fastboot/EDL。
