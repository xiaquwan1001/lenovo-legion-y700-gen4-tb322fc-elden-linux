# `#692` 上机两发（2026-11-27）+ **串口第一次抓到崩溃现场**：Linux 看到了 ADSP fatal error 并进入 SSR recovery，随后 ms 级整机复位

> 无人值守轮，用户已放行上机。**两发都做了整机复位**（零写盘，自动回 `boot_b`，设备现态健康：`--failed`=0、两 rproc `running`）。
> 产物：`patches/userland/hexagonrpc-write-20261127/`（补丁）、`reports/artifacts/sensors-692-attach-crash-20261127/`（串口摘录）。

## 0. 结论（四条，按分量排序）

1. **`#737` 的一条核心断言需要修正**：旧结论说「崩时串口 relay **零行** ⇒ 复位发生在 Linux 之外、内核什么都不知道」。
   本轮**串口抓到了完整现场**（`console=ttyGS0` 与主机 relay 都在跑），崩溃序列是：
   ```
   PDM: service 'qsh_process' crash: 'EF:qsh_process:0x4:sns_registry_4:0x74:sns_registry_senso…'
   qcom_q6v5_pas 6800000.remoteproc: fatal error received: err_qdi.c:1215:EF:qsh_process:0x4:sns_registry_4:0x74:sns_registry_sensor.c:309:…
   remoteproc remoteproc0: crash detected in adsp: type fatal error
   remoteproc remoteproc0: handling crash #1 in adsp
   remoteproc remoteproc0: recovering adsp
   ucsi_glink…: failed to send UCSI write request: -5
   【串口中断 ⇒ 整机复位，之后再无一行内核输出】
   ```
   ⇒ **Linux 的确看到了 ADSP 断言并开始 SSR 恢复**；整机死在 **恢复动作里（PAS shutdown/restart 那一小段）**，而不是「内核对崩溃一无所知」。
   旧观测「零行」更可能是当时 relay/日志窗口没覆盖到（或那几次是 `stop` 路径、崩点更早），**不能再当「Linux 之外」的证据**。
2. **上游 issue #29 就是我们这台机器**（同族文案逐字吻合）：`PDM: service … crash: … sns_registry_…` + `err_qdi.c` + `sns_registry_sensor.c`。
   所以 `#692` 的形态 = **DSP 在 attach 阶段重写 registry 时断言**，不是内核 fastrpc 的问题（与我们此前否证假说 A 的结论一致）。
3. **本轮的「假成功 fwrite」补丁不足以让它过**：两发（普通版 / verbose 版）都在 ~0.1 s 内触发同一条断言。
   最可能原因：DSP 先调了我们**没实现**的 apps_std 方法（`fremove`=24 / `frename`=33 / `ftrunc` / `mkdir` / `rmdir` / `fileExists`），
   0.5.0 对这些一律回 `AEE_EUNSUPPORTED` ⇒ DSP 直接断言，根本走不到 `fwrite`。
4. **一个浪费了的采样教训**（已入判据）：`nohup … >/dev/ttyGS0` 时 **nohup 认为 stdout 是终端，会把输出改写到 `nohup.out`**
   （本轮 `/root/nohup.out` 为 0 字节，用户态日志全丢）。要串口采样就用 `setsid <cmd> </dev/null >/dev/ttyGS0 2>&1 &`，**不要**套 `nohup`。

## 1. 两发实测记录

| 发 | 二进制 | 结果 | boot_id |
|---|---|---|---|
| #1 | `/usr/local/bin/hexagonrpcd-patched`（v0.5.0 + 87 行补丁，aarch64 静态 libhexagonrpc、strip 68 KB） | 进程**没起来**：`error while loading shared libraries: libhexagonrpc.so.0.5`（`-Ddefault_library=static` 对 `shared_library()` 无效；改 `library()` 后重编才解） ⇒ **无风险、无复位** | 95f5a0fc… |
| #2 | 同源重编（libhexagonrpc 静态链入）+ `-Dhexagonrpcd_verbose=true`，输出送 `/dev/ttyGS0` | **~0.1 s 内 ADSP fatal error ⇒ Linux 起 SSR recovery ⇒ 整机复位**（见 §0-1 串口原文） | 34588178… → e01179aa… |

复现命令（**危险**：必然复位一次；零写盘，自动回 `boot_b`）：
```sh
scp /tmp/hexagonrpcd-v elden-root:/usr/local/bin/hexagonrpcd-v
ssh elden-root 'setsid /usr/local/bin/hexagonrpcd-v -f /dev/fastrpc-adsp -d adsp -s -R /var/lib/droid-juicer/sensors/ </dev/null >/dev/ttyGS0 2>&1 &'
```

## 2. 为什么「补丁无效」是可解释的（下一轮的攻击面）

0.5.0 的 `apps_std` 方法表里，除 `fflush/fclose/fread/fseek/fopen_with_env/opendir/readdir/stat` 外**全是 `NULL`**；
任何未实现的调用都返回 `AEE_EUNSUPPORTED`，而 DSP 侧对 registry 的操作序列里几乎必然先碰到 `fremove`(24)/`frename`(33)。
⇒ **下一版补丁的正确做法不是「实现真写在先」，而是「先把所有已知方法都回一个合理的假成功」，再看 DSP 卡在哪一步**（逐步收窄）。

需要的签名来源（公开）：AOSP `apps_std.idl` / 下游 `adsprpc` 的 `apps_std.h`；上游 issue #29 已给出 24=remove、33=rename 的实测编号。

## 3. 判据与台账影响

- `PITFALLS #737` 追加修订（见该条正文新增「2026-11-27 修订」小节）：**不许再把「串口零行」当作「内核没参与」的证据**；
  复位点在 `remoteproc … recovering adsp` 之后的 PAS 关停/重启段。
- `TASKS/NEXT.md` **T13**：三态判据从「✅无复位」改为 **⚠️ 已知**（补丁 1 版不足），下一步 = **apps_std 全方法假成功**版。
- `report/hexagonrpc-upstream-registry-write-20261127.md` §5 的试验协议已按本轮实况校正（`nohup` 坑、静态链 libhexagonrpc）。

## 4. 设备现态（采集时点）

`boot_id e01179aa…`、`systemctl --failed` **0** 条、`remoteproc0/1 = running`、slot `_b`、`hexagonrpcd` 服务仍 **masked**（不会自启）：
`/usr/local/bin/hexagonrpcd-{patched,v}` 只是两个手工二进制，**没装成服务**。
