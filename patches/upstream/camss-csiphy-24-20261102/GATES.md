# 门禁（编排者独立复跑，2026-11-02）

基线 = 公开 `6628e7d4c6`（Linux v7.4-rc1）。临时树 = `git -C build/b5-v2 worktree add /tmp/wt-camss6628 6628e7d4c6`。

## 1. 干净应用

```
$ git am --keep-cr patches/upstream/camss-csiphy-24-20261102/0001-*.patch
应用：media: camss: csiphy: add CSIPHY 2.4.0 lane settings for SM8750
$ git diff --stat 6628e7d4c6..HEAD
 .../platform/qcom/camss/camss-csiphy-3ph-1-0.c     | 124 +++++++++++++++++++++
 drivers/media/platform/qcom/camss/camss.h          |   1 +
 2 files changed, 125 insertions(+)
```
⇒ **1/1 干净应用，+125 −0**（与 7.3-rc7 上的原 2/9 逐字节相同）。

## 2. checkpatch `--strict`

```
total: 0 errors, 0 warnings, 0 checks, 149 lines checked
… has no obvious style problems and is ready for submission.
```

## 3. 编译（`W=1`）

```
$ cp build/m4-base/.config . && make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 olddefconfig
$ make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 W=1 drivers/media/platform/qcom/camss/
  CC [M]  drivers/media/platform/qcom/camss/camss-csiphy-3ph-1-0.o
  LD [M]  drivers/media/platform/qcom/camss/qcom-camss.o
rc=0（0 warning / 0 error）
```

⚠ 两个环境坑（都踩到过）：
1. **`olddefconfig` 必须带 `ARCH=arm64`** —— 不带时按宿主机 x86 解析，`CONFIG_ARCH_QCOM` 与
   `CONFIG_VIDEO_QCOM_CAMSS` 被静默抹掉（与 `PITFALLS #162` 同族，这次是在一次性测试树上复现）。
2. 编译必须 `CROSS_COMPILE=aarch64-linux-gnu-`，否则 `-mlittle-endian` / `-msign-return-address` 不被宿主 gcc 识别。

## 4. 「树内有没有使用者」

```
$ git show 6628e7d4c6:drivers/media/platform/qcom/camss/camss.c | grep -c 8750
0
```
⇒ 公开树无 SM8750 `camss_resources` 表项 ⇒ `CAMSS_8750` 永不被赋值 ⇒ 本枚**不可单独投**（详见 `README.md`）。
