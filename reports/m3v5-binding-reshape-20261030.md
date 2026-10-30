# M3-1 v5 binding 形状改定：按「两个连接器 = 两个 port」落地（2026-10-30）

> 父会话执行，接 `reports/m3v5-fix-20261030.md` §6-1 的未解缺口。
> 用户 2026-10-30 批准「DTS 结构正确、改 binding」。**未投递、未上机**。

## §0 数字结论

| 项 | 结果 |
|---|---|
| 形状裁定 | 两个 HS 连接器 = **两个 port**（`port@0` + `port@2`），各挂**一个** `endpoint`，`mux-state` 落在 endpoint 上 |
| 为什么不是同 port 双 endpoint | `port@1` 已被 SoC dtsi 的 SuperSpeed 通路占用（`usb_dwc3_ss` → `usb_dp_qmpphy_usb_ss_in`），上游 `snps,dwc3.yaml` 也把 `port@1` 定为 SS 口 ⇒ 第二个 HS 口只能落 `port@2` |
| `dt-doc-validate` | **0 行输出**（通过） |
| 探针复验 | `boardshape` **PASS**；`n_dup0`（两口同 mux-state）**REJECT**；`n_extra`（endpoint 非法属性）**REJECT**；`n_port1`（第二口试图用 port@1）**REJECT** |
| 补丁 | `patches/upstream/m3v5-fix-20261030/` 两枚重出：0001 **仅 binding**（92+/40−）↔ 0002 **仅驱动**（5 文件 263+/222−） |
| `checkpatch --strict` | 0001 **0E/0W/0C**（167 行）、0002 **0E/0W/0C**（776 行） |
| 驱动门禁 | `make -j6 W=1 O=/tmp/m3v5fix-obj2 drivers/usb/dwc3/ drivers/usb/roles/` **rc=0，0 warning / 0 error** |
| pristine 重放 | 两枚在 `24223e44ad` 上 `git apply` **rc=0**，终态 6 文件与 fix 树**逐字节一致** |

## §1 binding 改了什么（对比 A–J 之前的版本）

**改前**（`then.properties.ports`）：要求 `port@0`，其下 `endpoint@0` + `endpoint@1`，两条互斥 `oneOf` 分支。

**改后**：

```yaml
        ports:
          required: [port@0, port@2]
          properties:
            port@0: { $ref: '#/$defs/hs-port' }
            port@2: { $ref: '#/$defs/hs-port' }
          oneOf:
            - required: [port@0, port@2]   # port@0 = 0, port@2 = 1
            - required: [port@0, port@2]   # port@0 = 1, port@2 = 0
```

四条理由（都写进了 yaml 注释）：

1. `mux-state` 描述的是「**该连接器**接在 port-select GPIO 的哪一电平」，属于**连接器**，而一个 port 就是一个连接器 ⇒ 两个连接器必须是两个 port。
2. `port@1` 已被上游 `snps,dwc3.yaml` 定义为 SuperSpeed 口，在其下挂 `usb-role-switch`/`mux-state` 会被 schema 拒（探针 `n_port1` 实测）。
3. 每个分支都 `required: [port@0, port@2]` 才能让 `oneOf` 真正互斥——只写 `properties` 时，对不存在的节点约束恒真，两个分支会同时匹配而误拒（第一版实现踩过，见 §3）。
4. 给 `port@0`/`port@2` 挂 `$ref: '#/$defs/hs-port'`，否则 `unevaluatedProperties: false` 不生效、非法属性漏过（第一版实现踩过，见 §3）。

## §2 探针矩阵（按诊断文本判定，不看 rc —— 见 `PITFALLS #471`）

| 探针 | 形状 | 期望 | 实测 |
|---|---|---|---|
| `boardshape.dts` | **板级真实形状**：`port@0`(0) + `port@2`(1) | PASS | **PASS（0 行诊断）** |
| `n_dup0.dts` | 两口都 `mux-state = <0>` | REJECT | **REJECT**（`ports: 'oneOf' conditional failed`） |
| `n_extra.dts` | `port@2` 的 endpoint 加 `bogus-property` | REJECT | **REJECT**（`Unevaluated properties are not allowed`） |
| `n_port1.dts` | 第二口写成 `port@1` | REJECT | **REJECT**（`'port@2' is a required property`） |
| `nomuxprop.dts` | 删控制器级 `usb-role-switch` | REJECT | **REJECT**（`'usb-role-switch' is a required property`） |
| `ok/dup1/dup0/extraep.dts` | **旧形状**（同 port 双 endpoint） | — | 全部 REJECT —— **它们对应的形状已被废弃**，保留在 `reports/artifacts/m3v5fix-20261030-probe/` 仅作历史 |

复跑命令（**必须带 `DT_SCHEMA_PATH`**，否则本地 binding 根本不参与校验——这是本轮踩到的坑）：

```bash
cd build/m3v5-fix
export PATH=$HOME/.local/opt/dtschema-venv/bin:$PATH
export DT_SCHEMA_PATH=$PWD/Documentation/devicetree/bindings
dtc -I dts -O dtb -o /tmp/x.dtb reports/artifacts/m3v5fix-20261030-probe/boardshape.dts
dt-validate -c -s "$DT_SCHEMA_PATH" /tmp/x.dtb    # 判据 = 诊断文本行数，不看 rc
```

## §3 本轮踩到的三个坑（已并入 PITFALLS 与本文）

1. **`dt-validate` 的 rc 恒为 0**（`#471`），必须数诊断行数。
2. **缺 `DT_SCHEMA_PATH` 时本地 binding 完全不生效**：会得到「所有探针输出相同」的假象（本轮第一版即如此，三例输出逐字相同才发现）。
3. **`dt-validate -s <单个 yaml> <dtb>` 走不通**：dtb 里的字符串被读成 `bytes`（诊断形如 `dr_mode: b'otg\x00' is not of type ...`），节点匹配失败。只能用 `-c -s <schema 目录>`。
4. `git commit --amend -- <path>` 会把该路径改动并进 **HEAD**（= 0002 driver），不是 0001 —— 本轮踩了两次，最终用 `reset --mixed 24223e44ad` + 两次 `commit -C <old>` 重做才把 binding/driver 分开。

## §4 仍未做

1. **未上机**：本轮只改 binding，驱动行为未变（A–J 已在 `m3v5-daily` 上机验证过 mux 注册）。
2. **补丁基线是 daily 的 `24223e44ad`，不是 pristine `24a19b953`** ⇒ 0002 含「v2→v4 形状」重写内容，**投递前必须在 pristine 上重放 v4 三枚 + 本轮增量后重出**。
3. **绑定根因的 F1–F3 中，F1 已含在 0002**（`class.c` 改回 `if (sw)`）；F2（`ucsi.c` 失败上抛）、F3（`ucsi_glink.c` 有界重试）**未落地**，属下一轮。
