## #449 「上游没有这东西」的结论半衰期很短 —— 投递前必须对 linux-next 重新核对

> 2026-10-27 晚，为回答 Konrad 的「基线换 `linux-next/master`」把**所有在途系列**对
> linux-next master 过了一遍。结论：**一条系列被上游半路占据**，一处提交信息写错对象，
> 其余全部仍然有效。完整表 = `reports/upstream-dedup-audit-20261027.md`。

### 一、最贵的一条：aw86927 的「固件波形装载」已被上游用「驱动内波形」实现

我们的判断链是：`reports/u4-aw86927-sramwindow-20261027.md` 说「上游无固件装载路径」⇒
立项一个 5 提交系列（binding / chip 数据表 / **固件 RAM 波形装载** / AW8693X play+boost / suspend+shutdown）。

但 linux-next 的 `drivers/input/misc/aw86927.c` 现在是：

- `static const u8 aw86927_waveform[]` —— 二补码正弦表，注释 `round(84 * sin(x / 16.25))`；
- `struct aw86927_sram_waveform_header sram_waveform_header` —— version 0x01 + start/end 地址；
- `aw86927_ram_init()` 里 **写 header → 写波形 → VBAT 检测** 的完整 SRAM 编程路径；
- 仍然**没有** `request_firmware()`、**没有** `AW86937`、`BST_7000MV 0x11` 仍然是 `0x11`。

⇒ 逐枚 `git apply` 到 linux-next 的结果：**0001/0002/0004 过；0003（固件波形）冲突；0005 依赖 0003 也冲突**。
「上游没有 X」这句话本来是 2026-10-13（7.3-rc7）核实的，**两周后就过时了**。

**教训**：凡是以「上游还没有」为前提立项的系列，**投递前必须重跑一次存在性核对**；
核对成本 ≈ 10 分钟（§二），代价对比 = 撤稿一次（M2 A1 已经付过）或系列重构（本轮）。

### 二、可复用的核对三步（10 min，纯主机）

```sh
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890
B='https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/plain'

# ① binding / 文档：404 = 上游没有
curl -sSL -o /dev/null -w '%{http_code}\n' "$B/Documentation/devicetree/bindings/…?h=master"

# ② 功能面：grep 目标符号（不是 grep 文件名）
curl -sSL "$B/drivers/input/misc/aw86927.c?h=master" | grep -c 'request_firmware\|AW86937'

# ③ 补丁能不能套：最小仓只放目标文件，逐枚 git apply --check（顺序套，别孤立判）
```

`git apply --check` 必须**顺序**做：孤立判 `0004` 会误报（它依赖 `0003` 的上下文），
本轮 M3-4 的 4 枚就出现过这种假失败。

### 三、第二类错误：提交信息里的「回落对象」

M2 A2 的 v1 写道「driver has no entry for `qcom,sm8750-pmic-glink`，so it falls back to
`QCOM_BATTMGR_SM8350`」。实际 DT 是

```
compatible = "qcom,sm8750-pmic-glink", "qcom,sm8550-pmic-glink", "qcom,pmic-glink";
```

`of_match` 沿 compatible 列表走，命中第二项 ⇒ 变体是 **SM8550**（属性表含 `POWER_NOW`）。
症状描述（UPower 报 89 W/100 W）没错，**归因对象错了**。v2 已改正。

**教训**：写「回落/默认是 X」之前，去读**板级 DTS 的 compatible 顺序**和 `of_match_table` 的实际表项，
不要只看 `/* Unmatched devices falls back to … */` 这类注释（那是最后一个 entry 的注释，不是本条路径）。

### 四、顺带确认（这些仍然有效，不必重做）

M2 P3、M3-1、M3-3、M3-4、M4-1、M6 L1、M8、M1-U6 在 linux-next master 上**全部没有**被重复实现；
其中 M1-U6（`qcom_q6v5_pas` DTB 固件泄漏）在 linux-next 上**同病**，补丁直接 `git apply --check` rc=0。
