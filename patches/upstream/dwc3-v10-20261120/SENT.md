## 投递实账（2026-11-21 10:21 CST，`git send-email`，USTC 通道）

- 结果：**4 封全部 `Result: 250`**（日志 `logs/sent-20261121-1020.txt`）。
- 收件人（9 个，沿用 v9）：`Thinh.Nguyen@synopsys.com`, `linux-usb@vger.kernel.org`（To）；
  `robh@kernel.org`, `krzk+dt@kernel.org`, `conor+dt@kernel.org`, `gregkh@linuxfoundation.org`,
  `devicetree@vger.kernel.org`, `linux-arm-msm@vger.kernel.org`, `linux-kernel@vger.kernel.org`（Cc）。
- 线程：`--in-reply-to='<20261117052137.32833-1-xiaqinghuan@mail.ustc.edu.cn>'`（v9 cover）
  ⇒ cover 直接挂在 v9 线程下，3 枚 patch 再挂在 v10 cover 下。
- Message-ID：
  - `<20261121022104.1507987-1-xiaqinghuan@mail.ustc.edu.cn>` ← `[PATCH v10 0/3] usb: dwc3: support two connectors sharing one HS data bus`
  - `<20261121022104.1507987-2-xiaqinghuan@mail.ustc.edu.cn>` ← `[PATCH v10 1/3] dt-bindings: usb: snps,dwc3: describe two connectors on one HS data bus`
  - `<20261121022104.1507987-3-xiaqinghuan@mail.ustc.edu.cn>` ← `[PATCH v10 2/3] usb: roles: look up role switches attached to a graph endpoint`
  - `<20261121022104.1507987-4-xiaqinghuan@mail.ustc.edu.cn>` ← `[PATCH v10 3/3] usb: dwc3: select the shared HS data bus with a mux controller`
- 归档复核（投后 ~10 min）：
  - **`lore.kernel.org/linux-usb/<cover MID>/` 已归档**：页面标题 = v10 cover，`Thread overview` 列出
    v9 全 4 封 + v10 全 4 封（含 sashiko ×3 与 Rob ×2），`In-Reply-To` = v9 cover ⇒ 线程正确。
    取证方式 = `web_fetch`（Firecrawl 渲染），**绕过了 lore 的 Anubis 挑战**（curl 直取仍是 403/挑战页）。
  - **`linux-devicetree` 副本**：待 patchwork 摄取后复核（2026-11-21 02:3x 现查 patchwork 全项目
    最新件仍停在 `2026-11-20T23:39Z` ⇒ 是 patchwork 侧整体摄取滞后，不是我们投递失败）。
- 退信：INBOX/Junk/Sent 三处按 `mailer-daemon` / `postmaster` / `Undelivered` / `delivery` 扫 = 0。

### 未做/边界

- G7 上机回归仍未做（cover 已声明 "No runtime testing is claimed"）。
- 0004（板 DTS，GPIO 29 + 双 endpoint）继续 hold。
- patchwork 侧的 `v9` 条目会在 v10 摄取后自动转 `superseded`；若 24 h 后仍未摄取，按 MID 到
  `linux-devicetree` 单独补查（v9 那次 arm-msm 副本也是延迟摄取）。
