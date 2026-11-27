# GATES —— coresight MODULE_DEVICE_TABLE v1（2026-11-27）

发件树 = `/tmp/cs-wt`（`git worktree add --detach /tmp/cs-wt 4da9a8b69fc85`），
三枚提交：`ctcu` / `tpda`；封面手写（`v1-0000-cover-letter.patch`）。

| 门 | 命令 | 结果 |
|---|---|---|
| checkpatch --strict | `perl scripts/checkpatch.pl --strict --no-signoff v1-0001-*.patch` | `0 errors, 0 warnings, 0 checks`，7 行 |
| checkpatch --strict | 同上 `v1-0002-*.patch` | `0 errors, 0 warnings, 0 checks`，7 行 |
| 编成模块可加载 | `modinfo -F alias coresight-ctcu.ko` / `coresight-tpda.ko`（补丁后构建） | `of:N*T*Cqcom,sa8775p-ctcu` / `amba:d???F0F??` |
| udev 自动加载（真机） | 删 `/etc/modules-load.d/elden-coresight.conf` 后重启（vk196） | `lsmod` 有 `coresight_ctcu`+`coresight_tpda`；AMBA 未绑定 `0` |
| 模块解析 | 设备 `modprobe -S <UTS> -R 'of:N*T*Cqcom,sa8775p-ctcu'` / `'amba:d???F0F??'` | `coresight_ctcu` / `coresight_tpda` |
| dup-check | patchwork `linux-arm-kernel`(62) / `linux-arm-msm`(92) `q=ctcu`、`q=tpda` | 无同类 MODULE_DEVICE_TABLE 投递 |
| 上游 7.4-rc3 复检 | `grep MODULE_DEVICE_TABLE build/elden-tree/drivers/hwtracing/coresight/{coresight-ctcu-core.c,coresight-tpda.c}` | 仍然缺（不是 7.3 专有） |

复现命令（打补丁 → 构建 → 部署）：

```bash
# 树里已 apply（build/daily 工作区），重建受影响模块
KDIR=build/daily JOBS=12 bash scripts/build-kernel.sh Image.gz dtbs modules
DEPLOY_ANY_UTS=1 bash scripts/deploy-modules.sh --from build/daily
# 设备侧
modinfo -k <UTS> -F alias coresight-ctcu    # 期望 of:N*T*Cqcom,sa8775p-ctcu
modprobe -S <UTS> -R 'amba:d???F0F??'        # 期望 coresight_tpda
```
