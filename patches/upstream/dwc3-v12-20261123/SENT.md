# dwc3 v12 投递记录（2026-11-23）

- **时间**：2026-11-23 ~09:53Z（主机时钟 17:53 +0800）
- **结果**：4 封全 `Result: 250`
- **cover MID**：`<20261123095310.154352-1-xiaqinghuan@mail.ustc.edu.cn>`（1/3..3/3 = `-2/3/4`）
- **线程形态**：**新线程**（cover 无 `In-Reply-To`）—— krzk 点名投法（TASKS §4.0 11-23 条）；G6 dry-run 日志里的 `--in-reply-to v11` 形态**未采用**（日志作沿革，其 MID 为 dry-run 自造，非实发）。
- **门禁**：G1–G6 全部有完成日志（`logs/`；G4 `dt_binding_check` RC=0、G5 基线对照 RC=0、G6 dry-run OK）。G1 已由主会话**独立复验**（fresh clone aebb727447 + `git am` 3/3 + 6 枚 blob sha 逐字一致，2026-11-23 整理轮）。
- **lore 复核**：待 5–15 min 摄取后按 MID 查 `https://lore.kernel.org/linux-usb/<MID>/`（devicetree 副本走 `/linux-devicetree/`）； patchwork 滞后不作第一判据。
- **发送命令**：`git send-email --confirm=never --no-annotate --to=Thinh.Nguyen@synopsys.com --cc=robh@kernel.org,krzk+dt@kernel.org,conor+dt@kernel.org,gregkh@linuxfoundation.org,devicetree@vger.kernel.org,linux-arm-msm@vger.kernel.org,linux-kernel@vger.kernel.org v12-000*.patch`
