# #733 ramoops/pstore 在本机**读过即毁**：DDR 内容不跨复位存活（ECC 780/780 不可恢复）

## 现场（2026-11-26，U2 HA2EXB0E，全部零写盘实验）

要修「崩溃取证」，先验 pstore：ramoops 已注册（8 MiB @0xc2000000，record/console 2 MiB、pmsg 4 MiB），
但每次受控 panic（`echo c > /proc/sysrq-trigger`）后读回的 dump **按字节错乱**（如 `Li*tx ver3i/n 7.!dabug`）。

三步把「错在哪一层」分开：

- **参数层**：cmdline `ramoops.ecc=1` 被静默忽略；本内核 ECC 的属性是 DT **`ecc-size`**（`fs/pstore/ram.c`: `parse_u32("ecc-size", …)`）。
   把 **boot.img 里的 DTB** 改成 `ecc-size = <0x10>; max-reason = <0x5>;` 后生效：`ramoops: using … ecc: 16`。
- **写入层**：`console=ttyGS0` 在 panic 上下文里会卡住（只打印到 `sysrq: Trigger a crash`，既无 panic banner 也无栈，
   约 50 s 后被复位）⇒ 要拿到 panic dump 必须 **boot 时去掉 `console=ttyGS0`**（只留 `console=tty0`）。
- **存储层**：开 ECC 后 dump 自带报告 —— **`ECC: 0 Corrected bytes, 780 unrecoverable blocks`**；
   把 ramoops 挪到 **0x88000000**（8 GiB 内存区起点）重跑，**逐字相同的 780/780**，且写入的 marker 读回 0 命中。

⇒ 结论：不是 ring 指针错位、不是地址撞坏，而是**复位期间 DDR 内容整体失效**（与 SM8750/Gunyah 保留区、
以及该平台可能的 DDR 加密/重初始化吻合）。**pstore 在本机不能当证据通道。**

## 历史对照（为什么以前一直「pstore 是空的」）

`PITFALLS #414/#500/#620` 反复记「pstore 恒空 / 内容是 oops 但判读可疑」——当时归因「没触发 dump」。
本次实测更正：**dump 其实写了，读回被毁**。⇒ 以后任何「pstore 空」都不能当「没有 panic」的证据（#620 已有一半这条，现在是硬证据）。

## 处置 / 可复用的判据

- 任何「靠 ramoops 跨复位取证」的方案，在本机**先验 ECC 报告**：`grep -a 'ECC:' /var/lib/systemd/pstore/console-ramoops-0`
  出现 `unrecoverable blocks` 就说明这条通道不可用（判据比「读起来像乱码」硬）。
- panic 想被看见：`console=tty0`（去 ttyGS0）+ `softlockup_panic=1`（已落盘 `/etc/sysctl.d/99-evidence.conf`）⇒ 面板上出栈，人拍照。
- 无人值守要存盘只能走 **kdump/crashkernel**（panic 写盘，跨复位存活）；**硬掉电（#692 类）任何内核内通道都抓不到**，只能物理 UART。
