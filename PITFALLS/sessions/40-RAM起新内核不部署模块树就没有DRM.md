# 四十、RAM 启动新内核却不先部署模块树 ⇒ 没有 DRM（会被误判成 Q28 坏发）

> 2026-10-17 晚实测。收录 **#293**。场景：换机后重放的 M1-7.3 镜像 `vk127` 首次上机。

## #293 `lsmod` 为空 ⇒ DP 控制器永久 `-EPROBE_DEFER` ⇒ DPU 组件集不齐 ⇒ 无 `card0`

- **现象**：`fastboot boot out/boot-elden-vk127.img` 起得来（SSH/WiFi 都通、`uname -r` 正确），
  但 `/dev/dri` **不存在**；`dmesg` 里**完全没有** `msm_dpu … bound ae94000.dsi` 那几行。
  Q28 看门狗 84.9 s 后按「`card=no`」判坏并重启（日志 `Q28 bad boot detected … card=no sig=no`）。
- **误判方向**：很容易记成「Q28 又坏了一发」。实际**不是 Q28**——Q28 坏发一定有 `card0`，
  签名是首条 DCS `ff 20` 的命令 DMA 超时（`l1>0`）。
- **根因链**（`/sys/kernel/debug/devices_deferred` 直接给出）：
  ```
  lsmod | wc -l         -> 1        # 除表头外 0 个模块
  devices_deferred      -> af54000.displayport-controller
                           aux_bridge.aux_bridge.0  failed to acquire drm_bridge
  ```
  `/lib/modules/<新 UTS>` 不存在 ⇒ 所有 `modprobe` 在用户态静默失败（**内核 dmesg 里一条错误都没有**）
  ⇒ DP 所需的 PHY/altmode 等模块缺失 ⇒ DP 控制器一直 defer ⇒ `msm` 的 **component master 拿不齐组件**
  ⇒ DPU 不 probe ⇒ 整块 DRM 不出现。
- **判据**：先看 `lsmod | wc -l`（正常日常镜像约 17 行）。**为空/极少 ⇒ 先怀疑模块树缺失，别怀疑显示栈。**
- **修法**：宿主编好模块后部署，再启动：
  ```bash
  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
       INSTALL_MOD_PATH=/tmp/modinst INSTALL_MOD_STRIP=1 modules_install
  tar -C /tmp/modinst -czf /tmp/modules.tgz lib
  scp /tmp/modules.tgz root@192.168.7.1:/tmp/ && ssh root@192.168.7.1 'cd / && tar xzf /tmp/modules.tgz'
  ```
  `vermagic` 必须与镜像 `uname -r` **逐字相同**（另见 `#282–#284` 的 `ARCH`/vermagic 坑）。
  部署后同一镜像立刻恢复正常：DPU 绑定成功、`card0` 出现、`dsi_isr=41`。
- **纪律**：**任何 RAM 启动（`fastboot boot`）或写盘的新内核，先部署对应 `/lib/modules/<UTS>` 再判显示**；
  否则得到的「坏发」是缺件伪影（本次 s1/s2 两发已按此作废，不计入 Q28 样本）。
- **附带确认**（同批 3 发真 POR：s4/s5/s6）：模块树补齐后 `vk127` **3/3 GOOD**（`l1=0`、`dsi_isr=41`、
  用户目视有桌面），功能抽查全绿（WiFi 关联 / 声卡 2 张 / `/dev/fastrpc-adsp` / `SensorProxy` up）。
  **这不改变 Q28 口径**（坏发仍 ~50%、按时间成簇、恢复只能整机复位）——3/3 好只说明没撞上坏发簇。
