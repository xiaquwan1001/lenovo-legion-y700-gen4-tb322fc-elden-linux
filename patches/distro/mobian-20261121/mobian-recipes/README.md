# `wip.toml.snippet` — mobian-recipes 设备条目草稿（elen / TB322FC / SM8750）

> 产物：`wip.toml.snippet`（可直接追加到上游 `devices/qcom/configs/wip.toml`，或拆成 `sm8750.toml`）。
> **未写 Mobian 仓、未发 MR、未跑 `./build.sh`**；本文件只做「字段取值 + 判据来源」的静态整理。

## 1. 字段 → 取值 → 判据

| 字段 | 取值 | 判据来源（可复跑） | 状态 |
|---|---|---|---|
| `chipset` | `sm8750` | DT 文件名 `qcom/<chipset>-<vendor>-<model>.dtb` + 我方板 DTS 名 `sm8750-lenovo-elden.dts`（`patches/upstream/board-dts-single-20261113-sent-20261117/`，patchwork `14991580`） | 确定 |
| `[[device]].vendor` | `lenovo` | 在机 DTB `compatible = "lenovo,elden", "qcom,sm8750"`（`out/boot-elden-vk192.img` 内嵌 DTB 解出） | 确定 |
| `[[device]].model` | `elden` | 同上（vendor 名段 + 机型段）；`AGENTS.md`「机型唯一：TB322FC = elden」 | 确定 |
| `[[device]].variant` | 不写 | 我们只有一个面板/一个机型；variant 只用于同名多 DT 文件 | 确定（不需要） |
| `[[device]].chipset` | 不写 | wip.toml 模板注释：只有「与顶层 chipset 不同的 SoC」才写 | 确定（不需要） |
| `[bootimg].base` | `0x0` | 在机 boot.img 头解析（ANDROID! v0 字段区无 base 字段 = 0）+ 上游 `sm7150.toml` 样例同为 `0x0` | 确定 |
| `[bootimg].kernel` | `0x8000` | 同上（header 偏移 `0x0C`） | 确定 |
| `[bootimg].ramdisk` | `0x1000000` | 同上（偏移 `0x14`） | 确定 |
| `[bootimg].tags` | `0x100` | 同上（偏移 `0x20`） | 确定 |
| `[bootimg].pagesize` | `4096` | 同上（偏移 `0x24`） | 确定 |
| `[bootimg].second` | `0` | 同上（偏移 `0x18` = 0） | 确定 |
| `[bootimg].version` / `.dtb` | **未写** | 我方镜像是 `header_version=2` 但 `dtb_size=0`/`dtb_addr=0`（DTB 附在 kernel 后）；Mobian 的 build 流程是否接受 `version=2` + `dtb=0x0` 未验证 | **TODO(需上游确认)** |
| `append` | **未写** | 在机 cmdline 里的 `elden_root=LABEL=linux17`、`androidboot.slot_suffix=_b` 是本机分区/槽位产物，Mobian 侧根设备与槽位由镜像流程决定；其余（`console=ttyGS0`/`clk_ignore_unused`/`pd_ignore_unused`/`arm-smmu.disable_bypass=0`/`panic=15`）是调试期选择 | **TODO(需上游确认)** |

复跑解析命令（离线）：

```bash
python3 - <<'EOF'
import struct
d=open('out/boot-elden-vk192.img','rb').read()
assert d[:8]==b'ANDROID!'
ks,ka,rs,ra,ss,sa,ta,ps = struct.unpack('<8I', d[8:40])
print('kernel',hex(ka),'ramdisk',hex(ra),'second',hex(sa),'tags',hex(ta),'pagesize',ps,
      'header_version',struct.unpack('<I',d[0x28:0x2C])[0])
print('cmdline:', d[0x40:0x240].split(b'\0')[0].decode())
EOF
# 实测输出：
#   kernel 0x8000 ramdisk 0x1000000 second 0x0 tags 0x100 pagesize 4096 header_version 2
#   cmdline: console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel printk.devkmsg=on
#            panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0
#            elden_root=LABEL=linux17 androidboot.slot_suffix=_b
```

## 2. 为什么用 `wip.toml`，以及更该做的替代

- 官方 Porting 页给 wip 设备的入口就是「`devices/qcom/configs/wip.toml` 里加一节 + 把内核 .deb 放进
  `devices/qcom/packages/`」，然后 `./build.sh -t qcom-wip -s`。
- 更干净的长期形态 = 新建 `devices/qcom/configs/sm8750.toml`（文件名即 chipset，字段与 `sm7150.toml` 同形）。
  我们这次按任务要求先给 `wip.toml` 片段，两种落法字段一致（本文件顶部注释写了搬迁步骤）。

## 3. 还缺什么（不在本片段里，属「上游要先收的件」）

1. **内核 .deb**：Mobian 收 LTS（6.1/6.6/6.12/6.18），我们在 7.3/7.4 线；且需要 Debian packaging
   （`debian/` 从 `Mobian-team/devices/kernels/qcom-linux` cherry-pick「Add Debian packaging」）。
   6.18 能不能承载本机功能面，见 `reports/mobian-upstream-firstpr-20261121.md` §1（结论：**不能直接用**，
   SM8750 的 USB 节点 v7.0 才进上游、显示 v7.1、GPU v7.4）。
2. **droid-juicer 配置**：同仓上级目录 `../droid-juicer/`（已交，含启动阻塞规避）。
3. **dtb 进镜像**：Mobian 侧要求 dtb 来自内核包（`qcom/sm8750-lenovo-elden.dtb`），
   而板 DTS 目前还只在 patchwork（`14991580`, state=new）；未进树前只能靠我们的内核分支带它。

■ 静态交付，未运行 `build.sh`、未改上游仓。
