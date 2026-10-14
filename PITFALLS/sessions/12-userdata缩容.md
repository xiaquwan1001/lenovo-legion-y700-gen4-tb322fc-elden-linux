## 十二、userdata 缩容（TWRP 路线实测结论，2026-09-29）

57. **Gen4 的 userdata 是 metadata 加密 f2fs**（`metadata_encryption=aes-256-xts:wrappedkey_v0`，
    key 在 `/metadata`、硬件包裹）→ **mainline/root 都拿不到裸密钥**，不能软件解密。
    但 **TWRP 能解 metadata 加密**（它有 keymaster + dm-default-key），`/data` 可挂载；
    FBE(fscrypt) 的 `/data/user/0`、`/sdcard` 仍需锁屏凭据，无凭据时显示加密名。

58. **★ TWRP 的 `resize.f2fs` 能缩容，但 ZUXOS 不认**：实测流程可行且数据在块层保留——
    卸载 `/data` → 手动 `mount -t f2fs`（**不带 `checkpoint=disable`**）再 `umount` 让 CP 变 clean →
    `/system_root/system/bin/resize.f2fs -s -t <4096B块数> /dev/block/dm-14`。
    `-t` 单位是 **4096B 块**（不是 512B）；**缩容必须 `-s`**。缩完 Android 能正常挂载、用量不变。
    ⚠️ **但 ZUXOS 会检测到 userdata 容量不对 → 反复重启卡 logo**（用户实测）。
    → 结论：**改 GPT 给 Linux 分区，只能用"GPT 手术 + 擦掉 userdata 让 Android 重建"**
    （与 2026-09-04 那次成功的做法一致），不要指望在线 resize 保数据。

59. **TWRP 启动条件**：`polygraphene TWRP-3.7.1-16-TB322FC-2026-04-04-2` **只有 current-slot=a 才能起**；
    之前多次启动失败其实是设备停在**损坏的 b 槽**（b 槽任何内核都 PMIC/SPMI 早死）。
    另外 **`fastboot boot` 100MiB 的 TWRP 会失败**（超缓冲），要 `fastboot flash recovery_a/b` 再
    `fastboot reboot recovery`（先 `--set-active=a`）。TWRP 的工具在 `/system_root/system/bin/`（需 TWRP 挂 system）。

---

