# dwc3 v10 门禁账（2026-11-18，主机侧）

基线 = **mainline v7.4-rc3 final `aebb727447`**（`build/m3v2-7.3rc7` 的 `refs/remotes/gh/master` 现查同号）。
门禁全部跑在**从本目录 3 枚 patch 文件 `git am` 出来的 pristine 树**上（不是作者工作树）：

```sh
git -C build/m3v2-7.3rc7 worktree add --detach /tmp/dwc3-amtest aebb727447
cd /tmp/dwc3-amtest && git am patches/upstream/dwc3-v10-20261118/v10-000{1,2,3}-*.patch
```

| 门 | 命令 | 结果 |
|---|---|---|
| G1 `git am` | 3 枚按序 `git am` | **3/3 干净**（无 offset/fuzz；`ef4a47d6ea` 树） |
| G2 checkpatch | `perl scripts/checkpatch.pl --strict --no-signoff --no-tree <patch>` ×3 | **0001 = 0E/0W/0C（146 行）· 0002 = 0E/0W/0C（63 行）· 0003 = 0E/0W/0C（618 行）** |
| G3 编译 `W=1` | `make -j14 W=1 O=/tmp/kbuild-amtest drivers/usb/dwc3/ drivers/usb/roles/`（ARCH=arm64，`CONFIG_MULTIPLEXER=y` `CONFIG_USB_ROLE_SWITCH=y`） | **rc=0，0 warning / 0 error** |
| G4 dt_binding_check | `make -j14 O=/tmp/kbuild-amtest dt_binding_check DT_SCHEMA_FILES=.../snps,dwc3-common.yaml` | **rc=0**（SCHEMA/CHKDT/LINT/STYLE 无诊断） |
| G5 dtbs_check（非 mux 回归） | `make -j14 O=/tmp/kbuild-dwc3 CHECK_DTBS=y DT_SCHEMA_FILES=.../snps,dwc3-common.yaml qcom/sm8250-mtp.dtb qcom/sm8650-mtp.dtb qcom/sm8750-mtp.dtb` | **rc=0，无 dwc3 相关诊断**（旧版单 endpoint 板未被误伤） |
| G6 正/负样例（dt-validate） | 用 G4 产出的 `processed-schema.json` 校验 `patches/upstream/dwc3-v9-draft-20261111/gates/*.dtb` | **正样例 PASS**；负样例 4 类全被拒：同 state（`oneOf`）、缺 `endpoint@1`（required）、`endpoint@1` 缺 `usb-role-switch`/`mux-state`（required，本轮新增）、legacy v8 形状（unevaluated properties） |

复现要点：

- `CONFIG_MULTIPLEXER` / `CONFIG_USB_ROLE_SWITCH` 必须 `=y`，否则 `drd.c` 的 mux 代码被 `#if` 掉、编译门等于没跑。
- G5 的 `DT_SCHEMA_FILES` 只带本 binding，故只证明「本 schema 不误伤非 mux 板」；全量 `dtbs_check` 不在本轮范围。
- 负样例 `neg-no-props`（`endpoint@1` 两个属性都不写）为本轮新增，源文件 `/tmp/neg-no-props.dts`；同形状可由 `gates/pos.dts` 删两行复现。
- `dt-validate` 走 `/schemas/usb/...` 时对**条件分支内的 `const` 比较**有类型转换缺陷（会把 cell 当 bytes 比较）：本轮因此把「两 endpoint 必需」放进 `then` 的 `required`（只做存在性检查），互斥 `oneOf` 留在 `$defs/hs-port` 顶层，正样例才 PASS。这一条属工具行为，不写进补丁正文。

**未验（如实）**：mux 路径无上机实测（GPIO 29 实际电平切换、SDP/PD 两口枚举、拔插事件）；cover 已写明 "reviewed statically only"。
