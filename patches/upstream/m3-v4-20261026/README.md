
## 6. 投递（2026-10-26 20:32 +0800 = 12:32 UTC，用户批准「做1」）

- 方式：`git send-email`（USTC 通道），**新线程**（不挂 v2/v3，正文点名 supersede 两个 Message-ID）。
- 收件人：To = Greg Kroah-Hartman / Thinh Nguyen / Rob Herring / Krzysztof Kozlowski / Conor Dooley；
  Cc = linux-usb / devicetree / linux-arm-msm / linux-kernel。
- Message-ID（4 封 `Result: 250`）：
  - cover `<20261026123211.243224-1-xiaqinghuan@mail.ustc.edu.cn>`
  - 1/3 `<20261026123211.243224-2-xiaqinghuan@mail.ustc.edu.cn>`
  - 2/3 `<20261026123211.243224-3-xiaqinghuan@mail.ustc.edu.cn>`
  - 3/3 `<20261026123211.243224-4-xiaqinghuan@mail.ustc.edu.cn>`
- **归档复核**（lore，`provider=browser`；直连 URL 被 Firecrawl 缓存成 404，属工具假阴性）：
  `/linux-usb/` 命中 0/3、1/3、2/3、3/3 **4/4**；`/linux-devicetree/` 命中 0/3、1/3、3/3（2/3 属 `drivers/usb/roles`，该列表未收录，正常）。
  列表回环：本机 INBOX 收到 4 封（含两份 cover 副本）。
- Sent Items 回读：[152]–[155]。

## 7. cover 口径（诚实性说明）

Testing 段写明：机械门在 v4 上**重跑过**；板级插拔行为来自 **v1/v2 的同一天线逻辑**（本板日常内核就跑这套，`/sys/class/usb_role/a600000.usb-port{0,1}-role-switch` 两个开关都在），
而 **v4 的 5 项修复未逐插拔复测**（作者的上机通道正是被切换的那条 USB 链路），并主动提出「维护者要的话可以补测」。不作未做过的声明。
