# 持久根「内核 ↔ 模块」对齐 + G1-5/G1-4 持久复现（2026-10-05）

> 过程证据；结论以领域层为准（`TASKS.md` G1-5/G1-4、`PITFALLS` #99–#101、`RESOURCES.md` §3）。

## 1. 问题

U2 跑 **boot_b 持久直启**，`uname -r = 7.2.0-debug-g4c68eb5ed4e3-dirty`（= commit `4c68eb5ed`，vk46 + 未提交 vk47 DTS），
但持久根 `/lib/modules/` **只有旧内核** `7.2.0-debug-gba28ec16f01f-dirty`：

```
# modprobe qcom-camss
modprobe: FATAL: Module qcom-camss not found in directory /lib/modules/7.2.0-debug-g4c68eb5ed4e3-dirty
```

⇒ `lsmod` 仅表头、`/dev/media0`、`/dev/video0/3`、声卡控件全无 → **G1-5/G1-4 在持久系统上无法复现**（与功能回归无关）。
G1-5 之前是在 **vk50 RAM 启动 + 自带 overlay** 下验的，持久根的模块从未对齐。

运行 config（`/proc/config.gz`）关键项：`CONFIG_MODVERSIONS` 未开、`CONFIG_MODULE_SIG` 未开
⇒ **模块加载只要求 vermagic 精确匹配**，不需要符号 CRC/签名。
目标 vermagic：`7.2.0-debug-g4c68eb5ed4e3-dirty SMP preempt mod_unload aarch64`。

## 2. 方案（零写盘，不动 flash）

1. worktree 检出源码 commit `bd114ca33`（vk47 = 运行内核实际内容；与 vk46 仅差一段 DTS，C 代码同）。
2. `.config` ← 运行内核 `/proc/config.gz`；`scripts/config --set-str LOCALVERSION "-debug-g4c68eb5ed4e3-dirty"` + `--disable LOCALVERSION_AUTO`。
3. `make -j16 KBUILD_MODPOST_WARN=1 modules`；`make modules_install`（不行，见下）→ 改为按 `kernel/` 布局手动打包 `.ko`。
4. `scp` → 设备 `/lib/modules/<KV>/` → `depmod -a <KV>` → 加载。

### 构建细节 / 坑
- 新 worktree 无 `vmlinux` ⇒ 无 `Module.symvers` ⇒ modpost 报 56k+ 未解析符号。**借主树 `Module.symvers`（5a70ade46 构建）+ `KBUILD_MODPOST_WARN=1`** 通过（MODVERSIONS 关闭，CRC 无关）。
- `make modules_install` 因缺 `modules.builtin`（未编 vmlinux）失败 → **手动 `tar` 按 `kernel/...` 布局**打包。
- **vermagic 多了尾部 `+`**：`scripts/setlocalversion` 在**环境变量 `LOCALVERSION` 未设置**时补 `+`（`...-dirty+`）。
  必须 `export LOCALVERSION=`（空但已设）+ 删 `include/config/kernel.release`/`include/generated/utsrelease.h` 重生成，才得 `...-dirty`。
- 持久根实际只需 **25 个 `.ko`**（camera 链 + videobuf2/v4l2 依赖 + veth/bridge/br_netfilter/stp/llc + wl2868c），包 15 MB；全量 1484 个含调试符号 567 MB，无必要。

## 3. 结果（U2 实机，boot_b 持久根）

```
# 25 个 .ko 部署到 /lib/modules/7.2.0-debug-g4c68eb5ed4e3-dirty/ + depmod
# modprobe qcom-camss → rc=0（vermagic 匹配）
```

**G1-5 相机复现（持久系统）**：
```
[camera-up] front configured: gc08a8 12-0031 SRGGB10_1X10 -> msm_csiphy4 -> msm_csid0 -> msm_vfe0_rdi0 -> /dev/video0
<<<<<<<<<<   stream rc=0
[camera-up] rear  configured: s5kjns 11-0056 SGRBG10_1X10 -> msm_csiphy3 -> msm_csid1 -> msm_vfe1_rdi0 -> /dev/video3
<<<<<<<<<<   stream rc=0
```

**G1-4 音频通路（持久系统）**：`sh audio-alsa-init.sh all` → `mm1 on, L/R=400`；
`speaker-test -D hw:0,0 -c2 -t sine -f 440 -l 1` → **rc=0**（周期正常完成；实际听声需在场）。

### 两个加载陷阱（已入 PITFALLS #99/#100）
1. **热载时序**：模块在开机 38 min 后才 modprobe，`deferred_probe` 已超时 → `qcom-camss: Failed to configure power domains: -110`；
   `modprobe -r` + `modprobe`（或开机时加载）即正常。**必须开机加载**。
2. **PipeWire/WirePlumber 占用 `/dev/media0`**：`media-ctl -l` 报 `Resource busy`。停 wireplumber 即解（RAM 无桌面时不存在此问题）。

## 4. 固化

- **boot 加载**：设备 `/init` 比 `rootfs/init` 旧、**缺相机加载块**；已部署 `rootfs/init`（含 `camera-modules-load.sh` 调用，未加 `on_initramfs` 守卫 ⇒ switch_root 后在持久根也会跑一次）+ `/usr/local/sbin/camera-modules-load.sh`。旧 `/init` 备份为 `/init.bak-kmod-align`。
- **资产**：`out/camera-modules-7.2.0-debug-g4c68eb5ed4e3-dirty.tar.gz`（sha256 `4146dfd0cdfa1664…`）。
- **待办**：~~下次重启验证开机自动加载~~ **✅ 已验证（2026-10-05）**：多次自然重启后，boot 后 `lsmod | grep -c camss`=8、`/dev/media0`/`video0`/`video3` 均在。
  ⚠️ **未解释旁证**：同内核被报告「进桌面 ~5 min 硬重启 2 次」（未受控复现）——见 `archive/topics/REBOOT-5MIN-2026-10-05.md`、`TASKS.md` Q24。不排除与本轮相机自动加载有关（H2），待单变量排查。

## 5. 复现命令（备忘）

```sh
# 主机：worktree + 强制 vermagic
cd ~/y700-elden/geekidos-linux && git worktree add --detach /tmp/wt bd114ca33
cd /tmp/wt && cp <running.config .config> \
  && ./scripts/config --set-str LOCALVERSION "-debug-g4c68eb5ed4e3-dirty" \
  && ./scripts/config --disable LOCALVERSION_AUTO
export PATH="$HOME/bin:$PATH" ARCH=arm64 CROSS_COMPILE="ccache aarch64-linux-gnu-" \
       CCACHE_DIR="$HOME/.cache/ccache-elden" LOCALVERSION=          # ← 空但已设，防 '+'
cp ~/y700-elden/geekidos-linux/Module.symvers . && make -j16 olddefconfig
rm -f include/config/kernel.release include/generated/utsrelease.h
make -j16 KBUILD_MODPOST_WARN=1 modules
# 设备：
#  tar xzf <bundle> -C /lib/modules/<KV> && depmod -a <KV> && /usr/local/sbin/camera-modules-load.sh
```
