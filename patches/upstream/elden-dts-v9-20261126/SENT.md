# v9 投递记录（2026-11-26 08:21:57 CST）

- 触发：Krzysztof Kozlowski 2026-11-25T12:03:08Z `<179560818867.84329.911396338614062552.b4-reply@b4>` 要求「cover/changelog 显式写 waiting on bindings」。
- 放行：用户 2026-11-26 「全部允许」（keyring 解锁后本轮直接投）。
- 投出命令：`bash SEND.sh --send`（本地六段断言 + `--dry-run` 3 封 `Result: OK` 先过）
- 日志：`logs/sent-20261126-082157.txt`
- 结果（3/3 `Result: 250`）：
  - cover `<20261126002157.1954799-1-xiaqinghuan@mail.ustc.edu.cn>`
  - 1/2 `<20261126002157.1954799-2-xiaqinghuan@mail.ustc.edu.cn>`
  - 2/2 `<20261126002157.1954799-3-xiaqinghuan@mail.ustc.edu.cn>`
- 收件人：`andersson@kernel.org,konradybcio@kernel.org`；Cc：`abelvesa@kernel.org,mitltlatltl@gmail.com,robh@kernel.org,krzk+dt@kernel.org,conor+dt@kernel.org,devicetree@vger.kernel.org,linux-arm-msm@vger.kernel.org,linux-kernel@vger.kernel.org`
- lore 复核（2026-11-26T02:5xZ，父代理独立复核，非 worker 自报）：
  - 取件方式 = 本地 Firefox 渲染（`browserfetch.mjs fetch`）；curl 直取/走代理均 403（Anubis），**不得**用 `/raw 200` 当证据（口径见 TASKS §7 头）。
  - `linux-arm-msm` 三封**全命中**（标题逐字）：
    - `<20261126002157.1954799-1-…>` → `[PATCH v9 0/2] arm64: dts: qcom: sm8750-lenovo-elden: add the Lenovo Legion Y700 Gen4`
    - `<20261126002157.1954799-2-…>` → `[PATCH v9 1/2] dt-bindings: arm: qcom: document the Lenovo Legion Y700 Gen4`
    - `<20261126002157.1954799-3-…>` → `[PATCH v9 2/2] arm64: dts: qcom: sm8750-lenovo-elden: add Lenovo Legion Y700 Gen4, a Qualcomm SM8750-based tablet`
  - 归档正文已含「Waiting on bindings」专节（第 12 行）+ dwc3 v16 链接 ⇒ Krzysztof 的两条要求（显式依赖 + 不要 wall of text）在档可查。
  - 工具事实：Anubis 下同一页重试 2–3 次才过（单次 90 s 超时内）；再试一次即成功，不能因一次 403/挑战页就判「未归档」。
- 待办：盯 review（Krzysztof/Conor/Rob）；1/2 可独立合，2/2 等 7.5-rc1。
