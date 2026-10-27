# 投递记录（2026-10-27 21:29 +0800）

- 补丁：`0001-remoteproc-qcom_q6v5_pas-release-dtb-firmware.patch`（`+5 −4`）
- **To**：`linux-remoteproc@vger.kernel.org`
  **Cc**：`Bjorn Andersson <andersson@kernel.org>`、`Mathieu Poirier <mathieu.poirier@linaro.org>`、
  `linux-arm-msm@vger.kernel.org`、`linux-kernel@vger.kernel.org`
- Message-ID：`20261027132944.242550-1-xiaqinghuan@mail.ustc.edu.cn`，`Result: 250`
- 投递前复核：`git apply --check` 到 **linux-next master** 的 `qcom_q6v5_pas.c` **rc=0**；
  上游**同病**（成功路径 0 处 `release_firmware`，linux-next 只在失败分支加 `qcom_pas_metadata_release()`）
- 归档复核：`/linux-remoteproc/` **1/1**、`/all/` 命中
- 待办：盯 review（Bjorn / Mathieu）
