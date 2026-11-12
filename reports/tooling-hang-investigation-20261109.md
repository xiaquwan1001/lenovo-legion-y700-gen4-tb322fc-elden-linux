# 工具挂死调查：ssh+fastboot 复合命令整条挂住、timeout 失效（2026-11-09）


<!-- pitfalls-entries -->
> **本报告承载的 PITFALLS 条目正文锚点**（索引行在 `PITFALLS/README.md`；此处给 #NNN 定义，避免索引悬空）：
> `#585`

## 现象

本会话两次实例（命令形态相同）：

```bash
ssh $TAB 'sync; eldroid-bootctl reboot bootloader' >/dev/null 2>&1; \
sleep 14; timeout 15 fastboot devices > /tmp/fbd.txt 2>&1; cat /tmp/fbd.txt
```

5 分钟无输出、不退出，`timeout 15/12` 形同虚设，只能人工中断。当时设备确实已在 fastboot 模式（用户旁证：正常 fastboot 操作 <1 s，无输出即异常）。

## 证据

1. **timeout 对 fastboot 本身有效**（对不存在设备 `DUMMY` 复现）：
   `timeout 3 fastboot -s DUMMY getvar product` → 3.003 s 准时被杀，rc=124。
   ⇒ 挂死**不在 fastboot**。
2. `net.ipv4.tcp_retries2 = 15` ⇒ 已建立的 TCP 连接对端消失后，内核重传 **~15.4 分钟**才放弃。
3. 本机 timeout 为 uutils coreutils 0.10.0：不带 `-k` 只发 SIGTERM；fastboot 会响应 SIGTERM，所以「timeout 不生效」不能用「fastboot 忽略 TERM/D 状态」解释。
4. 两条实例的唯一共同前缀是**裸 ssh**（无 ConnectTimeout/ServerAlive*）。

## 根因

**挂点在命令链开头的 ssh，不是 fastboot；timeout 包的是后面的 fastboot，根本没执行到。**

链条（谁在等谁）：

```
bash ──等──> ssh（已建立连接）
                └─ 远端执行 reboot bootloader 后，板子 USB 网络（RNDIS/NCM）随内核重启消失
                └─ ssh 阻塞在 read()，内核按 tcp_retries2=15 重传 ~15.4 分钟
                └─ 无 ServerAliveInterval ⇒ 应用层永不判死
bash ──(永远到不了)──> sleep → timeout 15 fastboot devices
```

`>/dev/null 2>&1` 还把 ssh 的失败噪声藏掉，所以表现就是「整条命令静默挂死」。用户在 ~5 min 中断，远早于 ~15.4 min 的内核放弃点。两次实例形态一致 ⇒ 同一根因。

### 为什么 timeout 失效

`timeout 15 fastboot …` 只作用于 fastboot 子进程；它前面的 `ssh …` 没有 timeout、也没有应用层 keepalive，bash 顺序执行，卡在第一段就永远走不到 timeout 那一段。

### 排除/降级的旁证

- `fastboot | grep -q` SIGPIPE 打断 bulk 通道（PITFALLS #584）：真实存在，但两次实例 fastboot 输出重定向到文件、无管道，非本因；作为独立纪律保留。
- `lib-device-lock.sh` fd 9 继承：两次实例是裸命令行、未 source 锁库，锁未参与；fd 继承风险（#371）另行存在，不是本因。
- `uefi-boot-trial.sh` 的 `exec > >(tee)`：会使 bash 退出时等 tee 刷完，但仅影响该脚本退出时机（秒级），与本挂死无关。

## 加固件

新增 `scripts/lib-fastboot.sh`（已冒烟验证：DUMMY 上 `fbx` rc=124 准时超时；`fbdevices` SN 匹配正确，不误命中其它设备）：

- `fbx()`：`timeout -k 2 $FBTO fastboot -s "$SER" "$@"`，输出落 `$_FB_OUT`，永不进管道；SER 为空拒绝执行（#569）。
- `fbdevices()`：`timeout -k 2 10 fastboot devices` 落文件再判断，返回是否存在目标 SN。
- `sshc()`：`BatchMode + ConnectTimeout=8 + ServerAliveInterval=5 + CountMax=2` + 外层 `timeout -k 2`，对端消失 ~10 s 判死。

## 三条硬规则（以后这类命令怎么写）

1. **一条 shell 命令里不同时出现 ssh 与 fastboot**：先 `sshc` 拿到结果，再单发 `fbx`/`fbdevices`。
2. **所有 fastboot 包 `timeout -k 2 N`，输出先落文件/变量再判断**，永不接管道。
3. **所有 ssh 走 `sshc`**（或至少带 `ConnectTimeout` + `ServerAliveInterval`），裸 ssh 对会重启的板子 = 挂 15 分钟。

## 验收方法

```bash
# fbx 超时可控（不存在的序列号，~3 s 返回 124）
. scripts/lib-fastboot.sh; SER=DUMMY FBTO=3 fbx getvar product; echo $?
# fbdevices 误命中检查（真设备在总线时，DUMMY 必须 NOMATCH）
. scripts/lib-fastboot.sh; SER=DUMMY fbdevices || echo NOMATCH
# sshc 对断网目标 ~8-10 s 判死（可拔线演练）
```
