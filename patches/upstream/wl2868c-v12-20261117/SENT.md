
## 投递实账（2026-11-17 13:20 CST，`git send-email`，USTC 通道）

- 结果：**3 封全部 `Result: 250`**；lore 复核（`scripts/lore-fetch-raw.py` 按 MID 取 raw）：linux-arm-msm、linux-devicetree、lkml **全部命中**。
- 收件人（8 个）：`broonie@kernel.org`, `conor+dt@kernel.org`, `devicetree@vger.kernel.org`, `krzk+dt@kernel.org`, `lgirdwood@gmail.com`, `linux-arm-msm@vger.kernel.org`, `linux-kernel@vger.kernel.org`, `robh@kernel.org`
- Message-ID：
  - `<20261117052257.34849-1-xiaqinghuan@mail.ustc.edu.cn>` ← [PATCH v12 0/2] regulator: add the Will Semiconductor WL2868C camera PMIC
  - `<20261117052257.34849-2-xiaqinghuan@mail.ustc.edu.cn>` ← [PATCH v12 1/2] regulator: dt-bindings: willsemi,wl2868c: add the WL2868C camera PMIC
  - `<20261117052257.34849-3-xiaqinghuan@mail.ustc.edu.cn>` ← [PATCH v12 2/2] regulator: willsemi,wl2868c: add the WL2868C camera PMIC driver
- 发送日志：`logs/sent2-20261117-132257.txt`

### 注意：第一次误发（已重发纠正）

13:21 第一次实发时，三个补丁文件仍带着 **v11 的 `Message-ID`/`In-Reply-To`/`References`**（`format-patch --thread` 留在件里），
git send-email 照抄这些头 ⇒ 归档侧按 MID 去重，视作 v11 的重复（实测取 `9ab5e593…` 取回的是 v11 原文）。
纠正 = 删掉三个件里的这三个头 + cover 加一行「上一封是误发、请用这封」，13:22:57 重发（新 MID `20261117052257.34849-{1,2,3}`），
重发件在 `linux-arm-msm/`、`linux-devicetree/`、`lkml/` 三处均归档。日志 `logs/sent2-*.txt`；误发日志 `logs/sent-20261117-132127.txt`。
教训：**重发新版本前必须 strip `Message-ID`/`In-Reply-To`/`References`**（已写进 `PITFALLS`）。
