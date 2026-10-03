# 自主迭代：内核改动管理

上游 `geekidos-linux`（fork of GEEKiDoS/linux，分支 `v7.2-elden`）只作**起点**；
后续驱动/DT 改动由我们自己在本地维护，不依赖作者更新。

## 当前本地改动（未提交，`git status`）

- `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`：
  - `splash_region` 节点名（连字符→下划线）
  - `&mdss_dp0 { status="disabled"; }`
  - 其它（见 `git diff`）

建议：每个逻辑改动单独 commit，用 `git format-patch` 导出到本目录存档，便于回滚与重放。

```bash
cd linux
git diff > ../patches/0001-local-wip.patch      # 存档当前
# 或提交后：
git format-patch origin/v7.2-elden -o ../patches/
```

## 迭代方式（按代价从低到高）

1. **模块热加载（最优，不重启）**：把要调的驱动编成 `=m`，只编该模块，
   `scp` 到设备 `/tmp`，`insmod/rmmod` 验证。kernel 已 `CONFIG_MODULES=y`。
   - 需要 rootfs 有 `kmod`（busybox insmod 也行）。当前 Alpine 有 busybox insmod。
2. **软重启迭代（一条命令）**：`./iterate.sh` = 增量编译→打包→软回 fastboot→boot→等 SSH。
   - 约 1-3 分钟（增量编译），全程不按电源键。
3. 早期 hang 才需物理按键。

## 注意

- **改 `.config` 后绝不跑 `make olddefconfig`**（会删 `CONFIG_ARCH_QCOM`）。用 `scripts/config -e/-d` 后直接 `make`；
  `build.sh` 每次都会校验该行。
- boot.img 必须 ≤96 MiB（`boot_a` = 0x6000000）。
- 对作者自定义资产（如 `awinic/y700-gen4-speakers.bin`）不要等待上游：
  直接改我们自己的 DTS/驱动，或自造 profile。
