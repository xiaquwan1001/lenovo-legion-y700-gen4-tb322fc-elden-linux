# M3-1 v2（2026-10-17，回应上游评审）

> **取代** `patches/upstream/m3-2026-10-13/`（v1，2026-10-13 18:29 +0800 已发送并归档）。
> 基线：pristine **`v7.3-rc7` = `24a19b953`**（本地工作树 `build/m3v2-7.3rc7`，分支 `m3v2`）。
> 审阅原件：`reports/mail-triage-20261017.md` §2（5 条线程里与本系列相关的 3 条）。

## 1. 三份评审意见 → 处置

| 来源 | 意见 | v2 处置 |
|---|---|---|
| **Krzysztof Kozlowski**（10-14） | ①「`usb-psy-name` 全树无使用者」②「power supply 用 phandle 不用名字」③ patch 2 里出现「No, you just added it!」 | **整枚补丁删除**（不再文档化该属性）；binding 补丁**完全不碰** `usb-psy-name`（v1 的两枚补丁在属性顺序上互相踩，导致后一枚读起来像在删前一枚刚加的东西 ⇒ 这是③的根因） |
| **Konrad Dybcio**（10-14） | 「incredibly strange setup，确定是这么接的？中间有 hub 吗？」 | 在 cover letter 里给出**板级拓扑**：两个 USB-C 各自独立 SS 对，只有 HS D+/D- 经 TLMM GPIO 29 的 2:1 mux；两个 connector 都是 `data-role = "dual"` 走 pmic-glink；附 DTS 片段 |
| **kernel test robot**（10-15） | `core.c:171 variable 'mux_role' set but not used`（arm-defconfig, clang, W=1） | 变量与其赋值**删除**；本机 `aarch64` gcc + `W=1` 重编 `drivers/usb/dwc3/` **0 warning** |
| **sashiko-ai**（10-13，4 条） | ① `pm_runtime_put_autosuspend` 不平衡 ② GPIO 失败路径 double-free/UAF ③ `flush_work()` 在 freezable wq 上死锁 ④ 「oldest wins」实际是静态优先级 | ① 不再在取引用前跳错误标签（该门直接删掉，错误由 role_set 侧报告）② **绝不中途退出** `__dwc3_set_mode`（GPIO 失败只记错 + `dev_err_ratelimited`，继续按原选中端口走完，避免 torn-down 角色 + 陈旧 `current_dr_role`）③ 去掉 `flush_work`，保持与上游单连接器 role switch **同一套异步语义** ④ 每个 connector 在 `NONE→role` 跳变时打 `jiffies` 时间戳，选择真正按「最早请求者胜」 |

## 2. 系列构成（2 枚，0 errors / 0 warnings / 0 checks）

| 补丁 | 主题 | 内容 |
|---|---|---|
| `0001-dt-bindings-usb-snps-dwc3-describe-the-two-connector.patch` | `dt-bindings: usb: snps,dwc3: describe the two-connector HS data path` | `$defs/hs-port`（`port-base`/`endpoint-base` 约束 + `usb-role-switch`/`mux-state` 成对依赖）、`port@0` 改用 `hs-port`、新增 `port@2`、`port-select-gpios`、条件校验（有 gpio ⇒ `dr_mode=otg` + 两个端点都必须带 `usb-role-switch`/`mux-state`） |
| `0002-usb-dwc3-support-two-connectors-sharing-one-HS-data-.patch` | `usb: dwc3: support two connectors sharing one HS data bus` | `core.h`（`dwc3_role_port`/`dwc3_role_mux`）、`core.c`（`__dwc3_set_mode` 在旧角色拆除后切数据通道）、`drd.c`（每连接器一个 role switch + 串行化 + 最早者胜 + 只在自己占有数据通道时报告角色）、`debugfs.c`（mux 存在时拒写 `mode`） |

## 3. 验收证据（全部本机实跑，2026-10-17）

| 门 | 命令 | 结果 |
|---|---|---|
| checkpatch | `./scripts/checkpatch.pl --strict --no-tree <patch>` | 0001 **0E/0W/0C**；0002 **0E/0W/0C** |
| binding 自检 | `dt-doc-validate Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml` | **rc=0**（dtschema 2026.9） |
| 编译 | `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 drivers/usb/dwc3/` | **rc=0，0 warning**（`/tmp/b2.log`，全量 22 个 dwc3 对象） |
| 干净应用 | 在 pristine `24a19b953` 上 `git apply` 两枚 | rc=0（两枚皆可独立应用，顺序 0001→0002） |

> 环境说明：换机后本机原缺 `clang`/`dtc`/`dt-doc-validate`，2026-10-17 已装 `clang 21.1.8` + `dtc 1.7.2`；
> 校验器装到 `~/.local/opt/dtschema-venv`（uv 托管 CPython 3.12 + 源码编 `pylibfdt`），
> `dt-doc-validate`/`dt-validate` 已软链到 `~/.local/bin`。

## 4. 未做 / 待办

- **板 DTS 那一半**（`port-select-gpios` + `ports` 段）仍在 **M3-2 板基础片**，本系列不带板文件。
- 投递（`git send-email` 到手后需人工确认发件）：收件人 To = Greg KH / Thinh Nguyen / linux-usb；
  Cc = Rob Herring / Krzysztof Kozlowski / Conor Dooley / devicetree / linux-arm-msm / linux-kernel。
- 投递后按 Message-ID 到 `/linux-usb/` 与 `/linux-devicetree/` 各自复核归档（技能 `upstream-mail-ustc` §5）。

## 5. 复现

```bash
cd build/m3v2-7.3rc7          # pristine v7.3-rc7 (24a19b953) + 分支 m3v2
git log --oneline -2          # 0001 binding / 0002 driver
./scripts/checkpatch.pl --strict --no-tree <(git format-patch -2 --stdout)
dt-doc-validate Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 drivers/usb/dwc3/
```

## 6. 投递记录（2026-10-17 08:13Z，**已发送 + 已归档复核**）

发送命令（树根 `build/m3v2-7.3rc7`）：

```bash
git send-email --confirm=never --suppress-cc=self \
  --to="Greg Kroah-Hartman <gregkh@linuxfoundation.org>" \
  --to="Thinh Nguyen <Thinh.Nguyen@synopsys.com>" \
  --to="linux-usb@vger.kernel.org" \
  --cc="Felipe Balbi <balbi@kernel.org>" \
  --cc="Rob Herring <robh@kernel.org>" \
  --cc="Krzysztof Kozlowski <krzk+dt@kernel.org>" \
  --cc="Conor Dooley <conor+dt@kernel.org>" \
  --cc="devicetree@vger.kernel.org" \
  --cc="linux-arm-msm@vger.kernel.org" \
  --cc="linux-kernel@vger.kernel.org" \
  patches/upstream/m3-v2-2026-10-17/0000-cover-letter.patch \
  patches/upstream/m3-v2-2026-10-17/0001-*.patch \
  patches/upstream/m3-v2-2026-10-17/0002-*.patch
```

| 邮件 | Message-ID | 归档 |
|---|---|---|
| `[PATCH v2 0/2]` 封面 | `20261017081320.220525-1-xiaqinghuan@mail.ustc.edu.cn` | ✅ `/linux-usb/` + `/linux-devicetree/` |
| `[PATCH v2 1/2]` binding | `20261017081320.220525-2-xiaqinghuan@mail.ustc.edu.cn` | ✅ 同上 |
| `[PATCH v2 2/2]` driver | `20261017081320.220525-3-xiaqinghuan@mail.ustc.edu.cn` | ✅ 同上 |

- 每封 `git send-email` 返回 **`Result: 250`**（三封全成功）。
- **归档复核**：`lore-query.py "https://lore.kernel.org/<inbox>/?q=f:xiaqinghuan%40mail.ustc.edu.cn"`（自动过 Anubis PoW）⇒
  **两个 inbox 各自 3/3**（时间戳 2026-10-17T08:13:36Z / 08:13:37Z）。
- **逐字节复核**：取 `https://lore.kernel.org/linux-usb/<msgid>/raw`，与本地 patch 的 diff 段逐行比对 ——
  **0002：本地 93 行 diff，归档缺失 0**；**0002（driver）：本地 380 行 diff，归档缺失 0**（封面 71/71）。

### 本地正文字节 sha256（与归档 raw 对账用）

```
132831948d53093468b385fd28796bf252e590b5d06751f1c07cf111be465ba4  0000-cover-letter.patch
95339410fb68dfbd57351ee166c39a7d46ef1c2dbb3217c3b1469705ac9fed9a  0001-dt-bindings-usb-snps-dwc3-describe-the-two-connector.patch
0323431c0088495a73457dc33c1f3602fee09448a5a0af3883345f5571c52334  0002-usb-dwc3-support-two-connectors-sharing-one-HS-data.patch
```

### 发送期踩到的两个坑（下次直接照做）

1. **系列编号**：`git format-patch --no-numbered` 生成的补丁没有 `v2 x/2` 编号，`send-email` 只会发成 `[PATCH]`。
   必须 `git format-patch -2 -v2 --cover-letter`；cover 的 `*** SUBJECT HERE ***` / `*** BLURB HERE ***` 要手工替换。
2. **凭据 host 必须与 keyring 条目一致**：`sendemail.smtpserver=mail.ustc.edu.cn` 时会报
   `could not read Password for 'smtp://…@mail.ustc.edu.cn:465'`（keyring 里存的是 `smtp.ustc.edu.cn:465`）。
   已把 `sendemail.smtpserver` 统一为 **`smtp.ustc.edu.cn`**。

### 回信跟踪

```bash
python3 ~/.local/bin/read-mail-ustc.py --days 7 --replies-only
```
