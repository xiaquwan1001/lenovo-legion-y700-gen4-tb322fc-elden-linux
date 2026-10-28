## #454 「bluetoothd 起了但 `No default controller available`」= 缺一个固件文件，不是服务崩

> 2026-10-28。Q34（`bluetoothd` 冷起偶发 crash / 蓝牙不可用）**现场复现并定案**。
> 结论与「crash」无关：**WCN7861 外设阶段的第 5 个固件文件没装**。

### 一、现场（设备本机实测）

```
# systemctl is-active bluetooth   → active
# bluetoothctl show               → No default controller available
# hciconfig -a
hci0:  BD Address: 00:00:00:00:00:00  ACL MTU: 0:0  SCO MTU: 0:0
       DOWN        ← 控制器从未起来（不是"起来了又掉"）

# dmesg | grep hci0
hci_uart_qca serial0-0: Direct firmware load for qca/tmel_peach_20.elf failed with error -2
Bluetooth: hci0: Peripheral setup failed: -2
```

`-2` = `-ENOENT`。顺着 `hci_qca.c` 读：

```c
if (soc_type == QCA_WCN7861) {
        ret = qca_peripheral_setup(hu);      /* WCN7861 专属：外设(TME)阶段 */
        if (ret) { bt_dev_err(hdev, "Peripheral setup failed: %d", ret); ... }
}
...
qca_peripheral_download(hu, "qca/brhperifw20.tlv", ...);
qca_peripheral_download(hu, "qca/brhperinv20.bin", ...);
MODULE_FIRMWARE("qca/tmel_peach_20.elf");   /* ← 这个在 3226 行 */
```

**设备侧 `/lib/firmware/qca/` 只有 4 个文件**（brhbtfw20 / brhbtnv20 / brhperifw20 / brhperinv20），
少了 `tmel_peach_20.elf` ⇒ 外设阶段直接失败、`qca_power_off()`、控制器不注册。

### 二、为什么像"服务崩了"

- `bluetoothd` 本身**完全正常**（active），它只是找不到控制器；
- 那句 `No default controller available` 是 BlueZ 的诊断文案，指向"没有 adapter"，**不指向固件**；
- `hciconfig` 能看到 `hci0` 且 `RX bytes:166` 非零（IBS 握手有过流量）⇒ 更像"链路有问题"而不是"文件没装"；
- 上一轮 Q34 的定性（"冷起偶发 crash，restart 就好"）**不成立**：这里 restart/重载模块**不解决**（固件仍然缺），
  只有补文件才行 —— 之前偶尔"restart 后好了"极可能是别的偶发，与本次不同源。

### 三、修法（30 秒，不用重启）

```bash
scp backup/fw/modem/image/tmel_peach_20.elf root@<dev>:/lib/firmware/qca/
ssh <dev> 'modprobe -r hci_uart btqca; modprobe hci_uart'       # 触发 serdev 重新 probe
```

判据（三条）：

```
hci0: BD Address: 22:22:62:9C:97:58   UP RUNNING
bluetoothctl show → Controller 22:22:62:9C:97:58 (public)   Name: elden
dmesg → QCA setup on UART is completed   /   HFP non-HCI data transport is supported
```

### 四、根治（防复发）——两层

① **`rootfs/debian/elden-firmware/paths.txt` 补 `qca/tmel_peach_20.elf`**，
   并新增 `local-extras.tsv`：**源树（设备 `/lib/firmware`）里没有、但驱动会 request 的文件**
   （仓库内副本 = `backup/fw/modem/image/tmel_peach_20.elf`，56752 B，sha256 `a175c8d9…`）。
   为什么需要这层：包构建的源树就是设备自身，设备缺什么包就永远缺什么 —— 循环依赖。
② **新门禁 A2：驱动 `MODULE_FIRMWARE()` 声明的厂商固件必须进包**。
   既有门禁 A 只查 **DT `firmware-name`**，而这次缺的名字只出现在**驱动代码**里 ⇒ 缝就在这里。
   A2 口径：`git grep -o 'MODULE_FIRMWARE("…")' -- drivers/`，只筛本机厂商前缀
   （`qca/ qcom/ ath12k/ awinic/ novatek`），逐条要求落在暂存树/包内。
   实测本树命中 **3 条**（brhperifw20 / brhperinv20 / tmel_peach_20），负向测试（把 tmel 从清单删掉）
   → `MISS … / FAIL 驱动声明的固件没进包`，恢复后 → `缺 0 条`。
   接进 `stage`（暂存后即校验）与 `deb`（解包后再校验，防"进了暂存树没进包"）。

### 五、连带修掉的门禁自身 bug

A2 第一版用 `[ -d "$tree/.git" ]` 判断内核树是否是 git 仓库 —— 而 `build/vk151` 是 **worktree**，
`.git` 是**文件**不是目录 ⇒ 判断恒假 ⇒ A2 **静默跳过并打印"通过"**（日志里那句
`（内核树无厂商 MODULE_FIRMWARE 条目，跳过 A2）` 就是它）。改为 `-e` 并在非 git 时打 WARN。

> 同一个坑一天内出现两次（`PITFALLS #452` 的 `IFS` 折叠、这里的 `-d .git`）：
> **门禁"静默跳过"比没有门禁更危险** —— 它会给出一份绿色的假证据。
> 写完门禁必须做一次**负向测试**（故意破坏输入 → 必须 FAIL）。

### 六、口径更新

- **Q34 定案**：不是 `bluetoothd` crash，是 **WCN7861 外设固件缺文件**；已修并加门禁。
- 若将来再次出现"`hci0` DOWN + `Peripheral setup failed: -2`"，先看**具体文件名**（`Direct firmware load` 那行），
  不要先怀疑服务或 DTS。
