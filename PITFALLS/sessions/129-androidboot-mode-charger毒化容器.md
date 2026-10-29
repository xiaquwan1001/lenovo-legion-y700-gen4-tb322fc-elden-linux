# #465 宿主 `androidboot.mode=charger` 会让整个 Waydroid 容器停在 15 进程

## 结论（2026-10-29 设备实测）

宿主**插着 USB 供电重启**时，`/proc/cmdline` 里会带 `androidboot.mode=charger`。
容器里的 `init` 直接读 `/proc/cmdline` ⇒ `ro.bootmode=charger` ⇒ **只跑 `on charger` 分支，
不跑 `late-init`** ⇒ 没有 `vold` / `zygote` / `system_server`。

现象（全部像「镜像坏了」，实际与镜像无关）：

| 判据 | 中毒值 | 正常值 |
|---|---|---|
| `lxc-attach … getprop ro.bootmode` | **`charger`** | `unknown` |
| `lxc-attach … ps -A \| wc -l` | **15** | 112–113 |
| `getprop sys.boot_completed` | 空 | `1` |
| `dumpsys media.camera` | `Can't find service: media.camera` | `Number of camera devices: 1` |
| `lxc-attach` 长命令 | 看起来「挂死」（实为容器无事可做） | 正常 |

**误判风险**：换 `vendor.img` 后起不来，最容易被判成「我的镜像/补丁坏了」——
本轮先回退镜像复测（仍 15 进程）才排除，代价 ≈20 min。

## 定式

① **换镜像后容器起不来，先查两行**：`getprop ro.bootmode`、`ps -A | wc -l`。
② 确认中毒后**零改镜像**的修法：造一份去掉该参数的 cmdline，bind 覆盖容器内 `/proc/cmdline`：

```sh
tr ' ' '\n' < /proc/cmdline | grep -v '^androidboot.mode=' | tr '\n' ' ' > /run/fake-cmdline; echo >> /run/fake-cmdline
# 追加到 /var/lib/waydroid/lxc/waydroid/config（先备份 config）
# lxc.mount.entry = /run/fake-cmdline proc/cmdline none bind,create=file,optional 0 0
```

   修后 `ro.bootmode=unknown`、113 进程、`sys.boot_completed=1`。
③ `/run` 是 tmpfs ⇒ **重启后 `/run/fake-cmdline` 需要重建**（本机尚未脚本化，属欠账）。
④ 与 PITFALLS #459（`/dev/video100` bind 到不存在的节点会造 0 字节普通文件）是**两个独立层的坑**：
   #459 是 LXC 挂载，#465 是 Android init 的 bootmode 分叉；两者都会表现成「相机 0 台」。
