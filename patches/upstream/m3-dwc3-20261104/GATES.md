# 门禁记录 — M3-1 dwc3 v6（2026-11-04）

> 全部在本机实跑，命令与输出摘自 `artifacts/`。判据按项目惯例：**不看 rc 的地方写明**
> （`dt-validate` rc 恒 0、`make dt_binding_check` rc 恒 0 —— PITFALLS #470/#471）。
> 树 = `build/m3v6-dwc3`（分支 `m3v6`，tip `fce197bb2e8c…`），base = `24a19b953e2a3d0ea5a8c4951a0ab8f32720c907`。

## 0. 一页结论

| # | 门禁 | 结果 | 证据 |
|---|---|---|---|
| G1 | `checkpatch.pl --strict`（**stdin 喂 mbox**，PITFALLS #474） | **PASS** 3/3：0 errors / 0 warnings / 0 checks | `artifacts/checkpatch-*.log` |
| G2 | `scripts/check-series-selfcontained.sh` | **PASS**：3/3 按序重放，`WARN=0` | `artifacts/selfcontained.log` |
| G3 | `make W=1`（dwc3 + roles，19 个 glue 全 `=m`） | **PASS**：rc=0，**0 warning / 0 error**，26 个 `.o` | `artifacts/build-w1-dwc3-roles.log` |
| G4 | `dt-doc-validate`（binding 那枚） | **PASS**：rc=0，无输出 | `artifacts/dt-validate-probes.log` 首行 |
| G5 | `dt-validate` 形状探针（v6 树内 binding） | **PASS**：`boardshape` 0 行诊断；`n_dup0`/`n_extra`/`n_port1`/`nomuxprop` 全 REJECT | `artifacts/dt-validate-probes.log` |
| G6 | pristine `git am` **逐枚** | **PASS**：3/3 rc=0，终态树与系列 tip **相同**（`git diff` 空） | 本文 §6 |
| G7 | `git send-email --dry-run`（只 dry-run） | **PASS**：rc=0，`Dry-OK`，1 cover + 3 补丁，MID 连续、IRT 只挂 cover | `artifacts/send-email-dry-run.log` |
| G8 | `make dt_binding_check DT_SCHEMA_FILES=…` | **PASS**（0 行输出 + 负对照有输出；rc 不作判据） | 本文 §8 |
| G9 | 涉及 **phy** 文件的 `W=1` 编译 | **N/A**：本系列 `git diff --name-only` 6 个文件**无一在** `drivers/phy/` | 本文 §9 |
| G10 | `b4 send --dry-run` | **未证（环境缺件）**：本机无 `b4` | 本文 §10 |

## 1. G1 checkpatch（stdin 形态）

```sh
cd build/m3v6-dwc3
for p in patches/upstream/m3-dwc3-20261104/000[123]-*.patch; do
  cat "$p" | perl scripts/checkpatch.pl --strict --patch -
done
```

```
0001-dt-bindings-… : total: 0 errors, 0 warnings, 0 checks, 138 lines checked
0002-usb-roles-…    : total: 0 errors, 0 warnings, 0 checks, 63 lines checked
0003-usb-dwc3-…     : total: 0 errors, 0 warnings, 0 checks, 441 lines checked
```

（`lines checked` 是 checkpatch 统计的补丁体行数，不是文件行数；文件行数 187/99/515。喂法为 `--patch -` + stdin，
不用文件参数，避免 PITFALLS #474 的伪 ERROR。）

## 2. G2 系列自足性

```sh
scripts/check-series-selfcontained.sh patches/upstream/m3-dwc3-20261104 \
    24a19b953e2a3d0ea5a8c4951a0ab8f32720c907 --repo build/m3v6-dwc3
```

```
  ok    0001-dt-bindings-usb-snps-dwc3-describe-two-connectors-sh.patch
  ok    0002-usb-roles-look-up-role-switches-attached-to-a-graph-.patch
  ok    0003-usb-dwc3-support-two-connectors-sharing-one-HS-data-.patch
PASS  m3-dwc3-20261104: 全部 4 个文件按序重放成功于 24a19b953e…
== 汇总: PASS=3 FAIL=0 WARN=0 退出码=0 ==
```

（cover 存在 ⇒ 无「缺 cover」WARN；脚本判定 cover = 文件名含 `0000`/`cover`。）

## 3. G3 `make W=1` 编译（dwc3 + roles）

```sh
O=/tmp/m3v6-obj
make -s O=$O ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
for c in USB_DWC3 USB_DWC3_{OMAP,EXYNOS,PCI,HAPS,KEYSTONE,MESON_G12A,OF_SIMPLE,ST,QCOM,IMX8MP,IMX,XILINX,AM62,OCTEON,RTK,GENERIC_PLAT,APPLE,GOOGLE} USB_ROLE_SWITCH; do
  scripts/config --file $O/.config -m $c; done
scripts/config --file $O/.config -e COMPILE_TEST
make -s O=$O ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
make -j26 O=$O ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 drivers/usb/dwc3/ drivers/usb/roles/
```

```
make rc=0
warning: 0        error: 0
CONFIG_USB_DWC3…=m 条目数: 19    (grep -cE '^CONFIG_USB_DWC3[A-Z_0-9_]*=m' .config)
产出 .o: core.o drd.o debugfs.o dwc3.o host.o gadget.o ep0.o + 19 个 glue .o + roles/class.o（26 个）
```

`-j26`：主机 28 线程，按项目规则留 2 个 P 核给交互。

## 4. G4 `dt-doc-validate`

```sh
export PATH=$HOME/.local/opt/dtschema-venv/bin:$PATH     # dtschema 2026.9
dt-doc-validate Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml
# rc=0，无任何输出
```

## 5. G5 `dt-validate` 形状探针（关键：必须带 `DT_SCHEMA_PATH`）

```sh
export PATH=$HOME/.local/opt/dtschema-venv/bin:$PATH
export DT_SCHEMA_PATH=$PWD/Documentation/devicetree/bindings
for f in boardshape n_dup0 n_extra n_port1 nomuxprop; do
  dtc -I dts -O dtb -o /tmp/m3v6/$f.dtb reports/artifacts/m3v5fix-20261030-probe/$f.dts
  dt-validate -c -s "$DT_SCHEMA_PATH" /tmp/m3v6/$f.dtb        # 判据 = 诊断行数
done
```

| 探针 | diag_lines | 首条诊断 | 判定 |
|---|---|---|---|
| `boardshape` | **0** | — | **PASS**（板级真实形状 `port@0`(mux 0)+`port@2`(mux 1)） |
| `n_dup0` | 5 | `ports: 'oneOf' conditional failed, one must be fixed` | **REJECT**（两口同 mux-state） |
| `n_extra` | 9 | `ports:port@2:endpoint: Unevaluated properties are not allowed ('bogus-property')` | **REJECT**（非法属性） |
| `n_port1` | 10 | `ports: 'port@2' is a required property` | **REJECT**（第二口占 port@1） |
| `nomuxprop` | 9 | `'usb-role-switch' is a required property` | **REJECT**（缺控制器级 `usb-role-switch`） |

含义：折叠后的 binding 与 10-30 改定的形状（`reports/m3v5-binding-reshape-20261030.md` §2）**结论完全一致**，
即本轮唯一的内容订正是 description 文本，schema 行为未变。

## 6. G6 pristine `git am` 逐枚

```sh
W=$(mktemp -d /tmp/m3v6-am-XXXX)
git -C build/m3v2-7.3rc7 worktree add -q --detach $W 24a19b953e2a3d0ea5a8c4951a0ab8f32720c907
for p in patches/upstream/m3-dwc3-20261104/000[123]-*.patch; do (cd $W && git am -q "$p"); done
git -C $W diff --stat fce197bb2e HEAD        # 空 ⇒ 终态树相同
```

```
am 0001-… rc=0
am 0002-… rc=0
am 0003-… rc=0
diff vs v6 tip: (空)
git -C $R worktree remove --force $W; git -C $R worktree prune
```

## 7. G7 `git send-email --dry-run`（**未发信**）

```sh
git send-email --dry-run --confirm=never --thread --no-chain-reply-to \
  --from='Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>' \
  --to='Greg Kroah-Hartman <gregkh@linuxfoundation.org>' \
  --to='Thinh Nguyen <Thinh.Nguyen@synopsys.com>' \
  --to='Rob Herring <robh@kernel.org>' \
  --to='Krzysztof Kozlowski <krzk+dt@kernel.org>' \
  --to='Conor Dooley <conor+dt@kernel.org>' \
  --cc='linux-usb@vger.kernel.org' --cc='devicetree@vger.kernel.org' \
  --cc='linux-arm-msm@vger.kernel.org' --cc='linux-kernel@vger.kernel.org' \
  patches/upstream/m3-dwc3-20261104/000[0-3]-*.patch
# rc=0, "Dry-OK"
```

线程形态（dry-run 日志实抽）：

```
0/3 Subject: [PATCH 0/3] usb: dwc3: two Type-C connectors sharing one HS data bus
    Message-ID: <20261104030244.177106-1-xiaqinghuan@mail.ustc.edu.cn>
1/3 Message-ID: <…-2-…>  In-Reply-To: <…-1-…>  References: <…-1-…>
2/3 Message-ID: <…-3-…>  In-Reply-To: <…-1-…>  References: <…-1-…>
3/3 Message-ID: <…-4-…>  In-Reply-To: <…-1-…>  References: <…-1-…>
RCPT: gregkh / Thinh / robh / krzk+dt / conor+dt / linux-usb / devicetree / linux-arm-msm / linux-kernel
```

⇒ MID 连续 `-1..-4`；`In-Reply-To`/`References` **只挂本次 cover**（`--no-chain-reply-to`），不跨旧线程。

## 8. G8 `dt_binding_check`

```sh
export PATH=$HOME/.local/opt/dtschema-venv/bin:$PATH   # yamllint 1.38.0 + ruamel 可用
make -s O=/tmp/m3v6-obj ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
     dt_binding_check DT_SCHEMA_FILES=Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml
# rc=0，输出 0 行
```

负对照（证明该 target 真在跑命令，不是空转）：把 `DT_SCHEMA_FILES` 指向不存在的 yaml ⇒ 输出 yamllint 报错文本（rc 仍 0）。
⇒ **判据 = 「0 行输出」+「负对照有输出」两条一起看**，与 PITFALLS #470/#471 的 rc 不可信一致。

踩坑记录（本轮）：上一次调用把 `PATH` 指到了不存在的 `~/venv-dtschema/bin`，导致 target 用系统 python3，
报 `ModuleNotFoundError: No module named 'ruamel'` 且 **rc 仍为 0** —— 正是 #470/#471 的形态，已用正确 venv 复跑。

## 9. G9 phy 文件

```sh
git -C build/m3v6-dwc3 diff --name-only 24a19b953e2a3d0ea5a8c4951a0ab8f32720c907 HEAD
# Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml
# drivers/usb/dwc3/core.c  drivers/usb/dwc3/core.h  drivers/usb/dwc3/debugfs.c
# drivers/usb/dwc3/drd.c   drivers/usb/roles/class.c
# grep -c 'drivers/phy' ⇒ 0
```

⇒ 本系列不碰 `drivers/phy/`、不碰 `drivers/usb/phy/`，「phy 文件 `W=1`」一项 **N/A**（不是漏做）。

## 10. G10 `b4`

```
command -v b4            ⇒ (空)
ls ~/.local/bin/b4       ⇒ No such file or directory
python3 -c 'import b4'   ⇒ ModuleNotFoundError
```

⇒ **未证**：本机没有 b4，无法跑 `b4 send --dry-run`。已用 G7 的 `git send-email --dry-run` 给出等价形态证据
（单线程、MID 连续、IRT 仅挂 cover、`base-commit:` 尾行）。发信前若要走 b4，需要先装（如
`python3 -m pip install --user b4`）并用 `b4 send --dry-run` 复核，这属编排者动作。

## 11. 门禁未覆盖（如实列出）

1. **未上机**：零设备操作；驱动行为证据见 cover letter 与 `README.md` §7。
2. **未在最新 `usb-next`/`master` 上重放**：base 固定 `24a19b953e`（本地可重现的 `v7.3-rc7`），未联网取新树。
3. **`dtbs_check` 全树**（M3 片级验收）不在本轮范围：本系列不含板 DTS（板 DTS 属 M3-2 片），
   板级形状用 §5 的探针 DTS 代替。
