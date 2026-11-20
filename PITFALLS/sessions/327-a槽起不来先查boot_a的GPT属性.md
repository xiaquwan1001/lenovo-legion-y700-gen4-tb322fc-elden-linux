# #695 Android a 槽「起不来」的第一件事是查 `boot_a` 的 GPT 属性，不是查镜像

<!-- created=2026-11-20 -->

## 判据（一句话）

`qbootctl` 只报 `Bootable 0/1`，**看不出 retry 与 unbootable 位**；要读准必须用
`scripts/slot-attr.py --allow-wrong-lun --device /dev/sde show`（设备侧跑，需把 `slot-attr.py` + `partlun.py` scp 到 `/tmp`）。
`boot_a` 的 `attribute byte6` 正常是 `0x7b`（retry=7, succ=1）或 `0x7a`（retry=7, succ=1, 无 OEM 的 bit0）；
**`0x82` = retry=0 / succ=0 / unbootable=1 ⇒ ABL 会直接跳过 a 槽**，此时任何「刷了还是不启动」的结论都不成立。

## 处置（每次上机前的固定三步）

```sh
scp scripts/slot-attr.py scripts/partlun.py root@192.168.7.1:/tmp/
ssh root@192.168.7.1 'python3 /tmp/slot-attr.py --allow-wrong-lun --device /dev/sde set a \
    --retry 7 --no-unbootable --successful'      # 主备两表同改 + CRC 重算 + 读回校验
ssh root@192.168.7.1 'qbootctl -s a'             # 设 active（`-a` 只是只读查询）
ssh root@192.168.7.1 'dd if=/dev/zero of=/dev/disk/by-partlabel/misc bs=4096 count=1 conv=fsync'  # 清 BCB，读回必须全 0
```

## 实测（2026-11-20 11:35–11:50，U2 HA2EXB0E，v1 super 在机）

| 阶段 | 观测 |
|---|---|
| 起始 | `boot_a byte6=0x82`（unbootable=1/retry=0）、`active=_b`、BCB 全 0、super=v1（system_a 5296 MiB） |
| 复位后 | `0x82→0x7a`、`active=_a`、BCB 全 0，reset |
| 结果 | 主机侧 60 s 内**无任何 USB 枚举**；~2 min 后以 Linux 起（up 1 min），`active` 回到 `_b`、**BCB=`boot-recovery`**、`boot_a` 又变 `0x82` |
| 失败层 | `logfs` 末条 `Shutting Down UEFI Boot Services: 13311 ms`（与 11-19 三发 13302/13307/13263 同族）⇒ 失败在 EBS **之后**；`pstoredump` 前 64 MiB **无可打印字符**（无 panic 文本） |

## 与旧口径的关系

- 11-19「3 发未进桌面里有 2 发被 BCB 污染」**仍成立**（那两次确实带着污染启动）；
  但「污染是唯一原因」**作废**——BCB 清零 + 属性修好后 a 槽依旧失败。
- 反过来，`boot_a=0x82` 这件事说明「起不来」至少有一段时间连「ABL 是否尝试过 a 槽」都无法确认。

## 失败链（现态理解）

ABL 启 a → Android 内核走到 EBS → 内核/init 阶段失败 → 复位 → ABL 判 a 失败：写 `retry=0/unbootable=1` +
`misc=boot-recovery` → 回落 b 槽（我们的 Linux）。所以**回落 b 槽是自动行为，不是「设备坏了」**。

## 指针

- 全账：`reports/android-a-slot-attempt-20261120.md`（含 logs/device-s1-113527/ 的 GPT 双表 dump、logfs 8 MiB）
- 相关：`PITFALLS #672`（boot_a 被标 UNBOOTABLE 导致「最小包 3 发全败」）、`#290`（无 fastboot fetch）、
  `#690`（主线核无 vendor RESTART2 ⇒ 软进 fastboot/EDL 不存在，只能人手按键）
- 上机包：`scripts/android-v3-bringup-walkthrough.sh`（S1 已包含清 BCB，但**未**包含复位 `boot_a` 属性 —— 本坑的机械化补丁待做）
