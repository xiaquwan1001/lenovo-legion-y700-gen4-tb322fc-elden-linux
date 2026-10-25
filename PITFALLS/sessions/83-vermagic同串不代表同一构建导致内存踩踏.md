# PITFALLS #394 — vermagic 只比 UTS 串：同串不代表同一构建，加载即随机踩内存

- 日期：2026-10-25
- pi 会话 id：01a170ea-a315-732b-b345-f3d47f865773
- 主题：外置模块与在机内核「同 `uname -r`」却结构体错位，表现为 `list_del/list_add corruption`
- 结论（一句话）：**`vermagic` 比对的是 UTS release 字符串，`…-vk127-00002-g<sha>-dirty` 里的 `<sha>`
  不同就是不同的树**；同串只保证「名字一样」，不保证任何结构体布局一致，加载后踩内存的表现是
  slab 链表损坏（`list_del corruption` / `list_add corruption`）而不是干净的 `-EINVAL`。
- 证据指针：`reports/gunyah-612-driver-port-20261025.md` §6

## 症状

设备侧 `uname -r` = `7.3.0-rc7-debug-vk127-00002-g2d223a4d0-dirty`，
模块构建树 = `…-g24223e44ad80-dirty`。`modinfo` 的 `vermagic` 两边**看起来**相同（release 串一致），
`insmod` 也不报 `-ENOEXEC`，于是「加载成功」被当成通过。

随后：

```
list_del corruption, prev->next should be ffff00000d77c00, but was ffff000005bcb50
  __list_del_entry_valid_or_report → device_shutdown → kernel_restart
list_add corruption ...
  __list_add_valid_or_report → kobject_add_internal → typec_register_partner
```

连带现象：`reboot` 会卡在 `device_shutdown`（电源键长按也无响应），只能硬断电。

## 判据（动手前一条命令）

```sh
# 设备侧完整构建身份（含 git 描述），不是只看 uname -r 的数值部分
ssh root@<dev> 'cat /proc/version'
# 模块侧
modinfo <mod>.ko | sed -n 's/^vermagic: *//p'
# 必须逐字相等，包含末尾 "-dirty"
```

`g<sha>` 段不同 ⇒ **拒绝加载**。别依赖 `modprobe` 的依赖解析，它不看这一段。

## 为什么容易踩

- 本项目的日用内核 UTS 里带着 git 描述（`CONFIG_LOCALVERSION_AUTO`），但**同一台机器上存在多个构建树**
  （`build/gunyah-port`、`build/vk151`、`build/m1-73`…），彼此的 `g<sha>` 可以完全不同而其余字段相同。
- `scripts/build-manifest.sh` 曾因尾部 `+` 产生假阴性（`PITFALLS #384`），说明这套比对**历史上就脆**；
  这次是相反方向的坑：**假阳性**（看着一致其实不是同一构建）。
- 内存踩踏的报错点（`device_shutdown`、`typec_register_partner`）与 Gunyah **毫无关系**，
  很容易被误判成「typec 驱动 bug」或「内核本身不稳」，从而在错误方向上耗掉整轮。

## 正确做法

- 上机前把「构建身份」做成硬门禁：不一致就 `insmod` 都别做。
- 需要跨树验证时，先把目标树 `make … LOCALVERSION=` 的输出与在机 `/proc/version` 对齐，
  或者干脆用 `fastboot boot` 连带内核一起换（零写盘），保证内核与模块同源。
- 一旦看到 `list_del/list_add corruption`：**立即停止在该内核上做实验**，硬断电重启；
  损坏已经发生，后续任何观测都不可信。
