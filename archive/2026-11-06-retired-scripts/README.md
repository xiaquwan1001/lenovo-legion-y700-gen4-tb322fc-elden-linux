# 2026-11-06 退役脚本归档（2 件）

> 证据层 · 只增不改。权威登记条目在 `../../PITFALLS/sessions/15-过时废弃功能缺陷登记.md` §15.1。
> 判定依据：`python3 scripts/static-scan.py --inventory`（2026-11-06 新增的入口清单模式）在**全仓纳管文本**里
> 对这两个 basename 的引用数 = **0 live / 0 hist**（连历史会话都没提过），且脚本正文指向的目录/镜像线已不存在。

| 脚本 | 为什么退役 | 现在看 |
|---|---|---|
| `rootfs/add-pkgs.sh` | 「往已建好的 Alpine 树补包再重打」的 WSL 时代助手：硬编码 `R=/TB322FC/rootfs`（换机后不存在），依赖 WSL 的 qemu-user binfmt。现役补包 = 设备侧 `apk add` + `rootfs/build-rootfs.sh` 重建 | `rootfs/build-rootfs.sh`、`TASKS/README.md` §1 G1-31 |
| `rootfs/verify-image.sh` | Ubuntu 根的归档前校验（`/mnt/rootfs` + `lib/aarch64-linux-gnu`）；**Ubuntu 根线已不在主线**（Alpine → Debian/Mobian），同一职责现由 `packaging/elden-userland/tools/verify.sh` 承担 | `packaging/elden-userland/tools/verify.sh` |

## 未退役的同批候选（有活价值，必须留但需要登记点）

`static-scan.py --inventory` 里同样 `live=0`，但**不是废件**，故不退役：

- `rootfs/vk-probe.py` —— ctypes 直调 Vulkan loader 枚举物理设备（本机无 `vulkan-tools`），是 G1-8 图形基线的现役探针；
- `initramfs/probe-device.sh` —— initramfs 内 DT/`msm-id`/`board-id`/reserved-memory 一次性 dump，bring-up 现场用；
- `scripts/rambuild.sh` —— 内存盘构建区助手，只被 `.pi/plans/` 引用（本工具把 `.pi/plans/` 计为 hist）。

这三件的正确处置是**补一行受管指针**（`RESOURCES/README.md` §2 与 `RUNBOOK-BRINGUP/README.md`），不是归档。
