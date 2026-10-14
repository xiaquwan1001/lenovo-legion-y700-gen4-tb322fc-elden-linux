## 一、引导 / fastboot / 重启交接

1. **A/B 槽会漂移**：进过 Android/TWRP/多次 `fastboot boot` 后，`current-slot` 可能 a↔b。
   假 dtbo 必须**两个槽都写**（`dtbo_a` 和 `dtbo_b`），否则卡 logo。
   排查：`fastboot getvar current-slot`。
   ★★ **Android 卡启动动画（动画还在动、机身发热、数据没坏）→ 十有八九只是漂到了「引导链不配套」的槽。**
   2026-09-29 实测：`current-slot=b` 卡动画，仅 `fastboot --set-active=a` + `fastboot reboot` 就完好进系统、数据无损。
   **所以「进不去 Android」第一步 = 切另一个槽试试，别急着重刷/清数据。** a/b 都试一遍。
   ⚠️ **主语**：`--set-active` 属设备写操作，按 `.pi/AGENT-OPS.md` §1「先备份 GPT + 记当前 slot 再执行」；不再限定谁执行。

2. **内核 `reboot` 后总落 fastboot，是 ABL 的正常回退**，不是故障：
   - ABL 对**当前 Android 槽**做 AVB 校验，`boot_b` 公钥不匹配 / `dtbo_b` hash 不匹配 → 无法启动 → 回退 **fastboot**。
   - 主线 reboot 走 **PSCI SYSTEM_RESET**，且**没有 `reboot-mode` DT 节点** → 不向 ABL 传启动原因。
   - **清空 `misc`(sda7) 里的 `bootonce-bootloader` 无效**（已验证）。
   - 可用交接 = `fastboot boot <img>`（RAM，跳过 AVB）。
   - ABL 日志在 `logfs`（`/dev/sde68` 的 `UefiLog1.txt`），能看到它识别假 dtbo：`Dtbo hdr magic mismatch ... D7B7AB1E`。
   - **AVB 公钥资源**：该产品线有公开现成资源（酷安提到），日后做 verified-boot / 双槽直启的候选。

3. **fastboot 不能跑批量脚本/连续命令**：这台机响应差、易卡。
   一律**拆成单条简单命令**（`fastboot flash dtbo_a ...` / `fastboot boot ...` 各自单独）。
   报 **`Write to device failed (No such file or directory)`** 时：先单条 `fastboot reboot bootloader`，等待，再单条 `fastboot boot`。
   （`cycle.sh` 已按此简化：`--soft`/`--dtbo`/`--recover`/`<img>`。）
   ★ **经验事实（非授权规则）**：`to-fastboot.sh`/`cycle.sh` 类**封装脚本代跑 fastboot** 在本机故障率高，属禁忌；
   「谁执行 fastboot」见 `.pi/AGENT-OPS.md` §1（自主优先；写前先备份，异常才上报）。

4. **`fastboot boot` 失败后 bootloader 会进"脏"状态**（连续报 `Load Error`）；`fastboot reboot bootloader` 可清。
   `fastboot boot` 报 `Failed to load/authenticate boot image: Load Error` 时同理。

5. **`kexec` 换内核：不可用（已定论；⛔superseded 中间态）**——`kexec -l`/`-s -l` 均装载成功，但 **`kexec -e` 失败**：早期「黑屏挂死」，补 trans_pgd（vk54/vk58）后转为**直接掉电**；**分支点已于 2026-10-08 定位（→#154）= `device_shutdown()`**（本条当年写「未定位」系受限于无存活 console + APSS 看门狗永久禁用）。⇒ **不作迭代通道**，改用 `fastboot boot`/`--flash`。
   - 仍有效告诫：kexec 时 `console=ttyGS0` 必断，勿据「无输出」判挂死；kexec/重启实验前先 `slot-attr.py mark-successful b`（否则扣 boot_b retry，~7 次后 unbootable）。取证遗留事实：H2（CPU offline BUG_ON）已排除；运行期 VA=48 位而 `VA_BITS=52`；APSS 看门狗永久禁用是当年「未定位」的原因。
   - 全量证据：`archive/topics/KEXEC-ONDEVICE-2026-10-05.md`、`KEXEC-ONDEVICE-R2-2026-10-05.md`、`KEXEC-2026-10-05.md`、`RUNBOOK §8`；触发点取证见 #154。
6. **boot.img 必须 ≤96 MiB**（`boot_a`=0x6000000）；超了 `fastboot boot` 会 `Bad Buffer Size`。

7. **USB gadget 重枚举有延迟**：设备已进 Linux 但主机可能十几秒内看不到 `enx`/`ttyACM0`，等一下即恢复；别急着判定死机。

8. **SSH 失效时的救急通道**：串口 `/dev/ttyACM0`（CDC-ACM，getty on `ttyGS0`，直接 root shell）：
   ```bash
   stty -F /dev/ttyACM0 115200 raw -echo
   { printf '\r'; sleep 0.5; printf '<cmd>\r'; } > /dev/ttyACM0 & timeout 5 cat /dev/ttyACM0
   ```

---

