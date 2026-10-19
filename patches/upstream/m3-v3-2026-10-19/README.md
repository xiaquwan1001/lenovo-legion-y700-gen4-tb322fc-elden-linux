# M3-1 v3（2026-10-19，形状 RFC）

> **本系列只含「形状」两枚**：binding + 通用 role-switch 查找 helper。DWC3 驱动实现**不在本系列**，
> 待形状被 ack 后作为 v4 发出（含 v2 sashiko 12 条修复）。
> 前序：v2 = `patches/upstream/m3-v2-2026-10-17/`（2 枚，已发、人类 0 回复、sashiko 12 条）。
> 形状判断依据：`reports/m3-v3-binding-decision-20261019.md`（C0，选 A=维持自定义 gpio mux）。

## 1. 系列构成

| 补丁 | 主题 | 内容 |
|---|---|---|
| `0001` | `dt-bindings: usb: snps,dwc3: describe two connectors sharing one HS bus` | `port@0` 改为 `hs-port`，下挂 `endpoint@0/endpoint@1`（**删 `port@2`**）；endpoint 带 `mux-state`（0/1，互补约束）与 `usb-role-switch`；`port-select-gpios` 存在时 required `ports`，不存在时禁止 endpoint 属性；具体驱动策略文字从 description 删除 |
| `0002` | `usb: roles: look up role switches attached to a graph endpoint` | 新增 `usb_role_switch_at_endpoint()`：沿调用方 OF graph endpoint 找**注册在远端 endpoint 上**的 role switch；`usb_role_switch_get()` / `fwnode_usb_role_switch_get()` 在既有 parent 查找之后尝试它（无行为变化，找不到就回落到原路径） |

## 2. 相对 v2 的变更（回答 sashiko）

1. `port@2` 删除 → `port@0` 下 `endpoint@0/1`（sashiko #2）。
2. `usb-role-switch` 的查找语义修正：v2 依赖**下游独有**的 `usb_role_switch_at_endpoint()`
   （`patches/replay-2026-10-17/0001` 里有，pristine `24a19b953` 无）⇒ v2 在纯净上游上
   consumer 永远 `-EPROBE_DEFER`。v3 把该 helper **作为正式补丁**（#3）。
3. `ports` 列入 required，并补 else 分支禁止无 gpio 时的 endpoint 属性（sashiko #4）。
4. 两 endpoint 的 `mux-state` 约束为互补（sashiko #5）。
5. 拒绝改用标准 mux 子系统（sashiko #1）：`drivers/usb/` 零 `mux_control` 先例；mux 只选通道、
   不表达「最早者胜」角色仲裁；`gpio-mux` probe 会强驱 idle 电平，覆盖 bootloader 留下的选择。
   理由写进 cover letter，binding 不再承载驱动策略。

## 3. 验收门（2026-10-19 本机实跑）

| 门 | 结果 |
|---|---|
| checkpatch `--strict --no-tree` | 0001 **0E/0W/0C**（129 行）；0002 **0E/0W/0C**（58 行） |
| `dt-doc-validate` | `snps,dwc3-common.yaml` **rc=0** |
| `make dt_binding_check DT_SCHEMA_FILES=…` | **rc=0**（STYLE 步骤因本机缺 `ruamel.yaml` 跳过，不影响 schema 校验） |
| 编译 | `drivers/usb/roles/class.o` `W=1` **rc=0，0 warning** |
| 干净应用 | pristine `24a19b953` 上 `git am` 两枚 **rc=0**（tip `6a48e34c7`） |

## 4. 投递与归档（2026-10-19）

- **线程**：作为 v3 回复 v2 cover（`In-Reply-To: <20261017081320.220525-1-xiaqinghuan@mail.ustc.edu.cn>`）。
- **Message-ID**：
  - cover `<20261019131848.344689-1-xiaqinghuan@mail.ustc.edu.cn>`
  - 0001 `<20261019131848.344689-2-xiaqinghuan@mail.ustc.edu.cn>`
  - 0002 `<20261019131848.344689-3-xiaqinghuan@mail.ustc.edu.cn>`
- **Result**：3 封均 `250`。
- **归档复核**：`/linux-usb/` 与 `/linux-devicetree/` **各 3/3**（2026-10-19T13:18:54Z）。
- 收件人：To = Greg KH / Thinh Nguyen / Rob Herring / Krzysztof Kozlowski / Conor Dooley；
  Cc = linux-usb / devicetree / linux-arm-msm / linux-kernel。

## 5. 下一步

1. 等形状 ack（重点两条：**标准 mux 是否坚持**、**endpoint 上的 `usb-role-switch` 命名是否接受**）。
2. ack 后发 v4 driver（`drivers/usb/dwc3/{core.h,core.c,drd.c,debugfs.c}`），逐条修 v2 sashiko：
   - Critical：`dwc3_role_mux_init()` 错误路径 `cancel_delayed_work(&drd_work)`；
   - High：`port->stamp` 只在 `NONE→非NONE` 更新；锁外 `dwc3_set_mode()` 的 `desired_port`/`desired_dr_role`
     竞争（合并临界区）；role switch 注册位置（已由本 RFC 的形状解决）；
   - Medium：fwnode 泄漏、`error`/`desired_role` 未读、补 `dwc3_pre_set_role()`；
   - 并把 `dwc3_set_mode()` 移到两个 switch 注册成功之后（Critical 的另一种解法）。

## 6. 复现

```bash
# 工作树（pristine v7.3-rc7 + 2 提交）
cd /tmp/m3v3        # 或在 build/m3v2-7.3rc7 里 git worktree add
git log --oneline -3

# 门
./scripts/checkpatch.pl --strict --no-tree 0001-*.patch 0002-*.patch
~/.local/bin/dt-doc-validate Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml
make -j16 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 drivers/usb/roles/class.o
```
