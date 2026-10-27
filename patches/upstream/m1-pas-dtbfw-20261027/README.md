# M1-U6 补丁：`qcom_q6v5_pas` 成功路径释放 DTB 固件（2026-10-27）

面向上游 `linux-remoteproc` 的小修。**未投递**（等用户批准）。证据与分析 =
`reports/m1-u6-pas-dtbfw-leak-20261027.md`（本目录只放补丁与机械门）。

## 内容

| 文件 | 主题 |
|---|---|
| `0001-remoteproc-qcom_q6v5_pas-release-dtb-firmware.patch` | `qcom_pas_load()` 把 DTB 固件收成局部变量并**加载后立即 `release_firmware()`**；删掉 `struct qcom_pas::dtb_firmware` 成员 |

基线 = pristine `24a19b953`（Linux 7.3-rc7），1 文件 / **+5 −4**。

## 门禁（已跑）

```sh
cd build/m4-base            # worktree @ m1-pas-dtbfw（基于 24a19b953）
perl scripts/checkpatch.pl --strict --no-tree \
  /home/xuqianhui/y700-elden/patches/upstream/m1-pas-dtbfw-20261027/0001-*.patch
# → total: 0 errors, 0 warnings, 0 checks, 30 lines checked

make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- drivers/remoteproc/
# → rc=0，0 warning（qcom_q6v5_pas.o 干净）
```

补丁**直接基于 pristine 提交**，因此 `git am` 到 7.3-rc7 干净（无需 3way）。

## 建议收件人（投递时再核对 MAINTAINERS）

- To：Bjorn Andersson `<andersson@kernel.org>`（REMOTEPROC 维护者）
- Cc：Mathieu Poirier、`linux-remoteproc@vger.kernel.org`、`linux-arm-msm@vger.kernel.org`、`linux-kernel@vger.kernel.org`

## 投递前待定

1. **是否与 M1 树合流**：`build/m1-upstream/clean-tree-73`（若重建）应包含本补丁，否则 M1 树继续带泄漏版。
2. 是否加 `Fixes:` 标签 —— 本地仓是浅边界（`git rev-list --count HEAD` = 4），**定不到引入提交**，
   故补丁正文不写 `Fixes:`；若上游要求可请维护者补。
