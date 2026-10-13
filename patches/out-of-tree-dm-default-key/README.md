# patches/out-of-tree-dm-default-key — vendor key ABI 的 out-of-tree 封存区

> 立项报告：`reports/m5-dm-default-key-20261013.md`（§3/§4 设计，§5 验证命令）。
> 上游化规则：`reports/upstream-policy-20261013.md` §6 第一行（C2 = out-of-tree patchset，**永不进上游包**）。

## 是什么

Android 的 `dm-default-key` 元数据加密目标 + Android 的 `wrappedkey_v0` vendor key ABI
（`__FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED`）在 vendor 血统内核树里**已经存在**（457 行目标 + ~40 行
fs/crypto 兼容层 + doc），但从**任何在用 `.config` 里都没被启用**（`DM_DEFAULT_KEY` 零命中）。

本目录的用途只有一个：**把它从"上游包"里剥离出去，改成默认不注入的补丁**，
以满足 `TASKS.md` §7 M5 的判据「上游包内无 Android vendor ABI」，同时不丢掉这份能力。

## 目录

- `patches/` — 补丁本体（**待生成**，见下）。默认**不**应用。
- `tests/` — 格式/兼容性验证记录（**待补**）：`dm-inlinecrypt` 与 `dm-default-key` 的卷布局兼容性实验（报告 §5 U3）。

## 生成（待执行；命令见报告 §4）

```sh
git -C geekidos-linux diff -R clean/base \
    -- drivers/md/dm-default-key.c drivers/md/Kconfig drivers/md/Makefile \
       include/uapi/linux/fscrypt.h fs/crypto \
       Documentation/admin-guide/device-mapper \
  > patches/out-of-tree-dm-default-key/patches/0001-vendor-key-abi.patch
```

## 红线与回退

- **永不**进入上游提交系列（`patches/upstream/**`）与 M 系列补丁；只在需要原厂 Android userspace 语义时才注入。
- 注入/回退都是源码级：`git apply` / `git checkout -- <files>`；`.config` 回退用 `patches/config-before-fragment-*.bak`。
- 更干净的上游等价能力（`dm-inlinecrypt` + `FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED`）**已在 pristine 7.3-rc7 树内**，优先用它（报告 §3.4）。
