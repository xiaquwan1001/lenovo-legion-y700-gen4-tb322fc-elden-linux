# probes/ — 运行期诊断探针（**仅取证，不入镜像、不入上游包**）

这些程序用来在不重启设备的前提下读取/改变内核状态。前提：设备正处在要调查的失败态，
而重启会毁掉现场（Q28 坏发只能靠整机复位恢复，见 `PITFALLS #224`）。

## q28latch/ — 清 Q28 的软件闩锁

| 文件 | 作用 |
|---|---|
| `q28latch.c` | 内核模块，`insmod q28latch.ko addr=0x<kallsyms> value=0` 把 `dsi_bonded_cmd_failed` 写回 0 |
| `dsidump.c` | 用户态，`/dev/mem` 映射 DSI 控制器，按偏移 dump 寄存器 |
| `dsistat.c` | 用户态，只解码 `STATUS0` 的 busy 位 |

## q28peek/ — 读 `msm_dsi_host` 关键字段

`insmod q28peek.ko glb=0x<msm_dsim_glb>` 打印两个 host 的 `power_on` / `link_configured` /
三组 rate 与 link rate 是否相等 / src clk parent。字段偏移来自 `pahole -C msm_dsi_host build/m1-73/vmlinux`，
**内核结构变了必须重新取偏移**。

## 构建

```sh
# 模块（vermagic 必须与在机内核逐字相同）
cd build/m1-73 && make -j8 ARCH=arm64 CROSS_COMPILE="ccache aarch64-linux-gnu-" \
    M=../../probes/q28latch modules

# 用户态（静态链接，设备无同版本 libc 依赖）
aarch64-linux-gnu-gcc -static -O1 -o probes/q28latch/dsidump probes/q28latch/dsidump.c
```

地址来源（`CONFIG_RANDOMIZE_BASE=y`，每次开机变，必须现查）：

```sh
grep -w dsi_bonded_cmd_failed /proc/kallsyms   # 模块参数 addr=
grep -w msm_dsim_glb        /proc/kallsyms     # 模块参数 glb=
```

## 纪律

- 会 `taint` 内核（`O`）并**改变可达代码路径** ⇒ 只用于取证。
- 结论与用法见 `reports/q28-DOSSIER.md` §s、`TASKS/sessions/2026-10-22-Q28软件闩锁与link_configured误清.md`。
