# 堆/全局越界定位并修好（ASan）：`apps_std` 方法表**按索引 dispatch**，新增方法必须占对下标

> 2026-11-27 续轮。上一轮遗留：attach 末尾 `free(): invalid next size (fast)`（SIGABRT，服务被 systemd 重拉一次）。
> 本轮用 aarch64 ASan 构建一次抓到根因并修好，设备现态 **`NRestarts=0`**。

## 0. 结论

**根因 = 我们自己加的补丁里方法表下标错位**，不是上游代码问题：

```
==2221==ERROR: AddressSanitizer: global-buffer-overflow … READ of size 8
    #0 invoke_requested_procedure ../hrpcd-patch/hexagonrpcd/listener.c:546   ← impl = &ifaces[handle]->procs[method];
0x…1fa00 is located 32 bytes before global 'localctl_procs'
0x…1fa00 is located 16 bytes after global 'apps_std_procs' … of size 560
```

`apps_std_procs[]` 是**按方法号当索引**的表（`procs[method]`），我们之前把 `fopen_fd/fclose_fd/fopen_with_env_fd`（方法号 34/35/36）
直接接在 `stat`（31）后面 ⇒ 落在下标 **32/33/34**，而 `n_procs` 又被设成 57 ⇒ DSP 调 36 时**读到数组外 32 字节**
（越界读全局符号区），进而踩坏堆。

**修法**（已进补丁）：31=`stat` → 32/33 显式留两个 `{NULL,NULL}`（`ftrunc`/`frename` 未实现）→ 34=`fopen_fd`、
35=`fclose_fd`、36=`fopen_with_env_fd`，并把 `n_procs` 设 **37**（= 表长）。
ASan 复跑：`ERROR: AddressSanitizer` **0 条**；设备上服务 `NRestarts=0`。

## 1. 验收（修后，真重启）

```
elden-sensorspd  active   NRestarts=0
iio-sensor-proxy active
HasAccelerometer=true   HasAmbientLight=true   HasProximity=true
ssccli --sensor accelerometer → X=-1.17 Y=-0.62 Z=9.51 m/s²（连续）
systemctl --failed → 0
```

## 2. 这次调试的可复制手法（值得留）

```sh
# 1) 交叉 ASan 构建（本机 gcc-cross 15 自带 libasan，设备 /lib/aarch64-linux-gnu/libasan.so.8 已存在）
meson setup /tmp/hrpcd-asan . --cross-file aarch64.txt -Dwerror=false -Ddefault_library=static \
     -Db_sanitize=address -Dhexagonrpcd_verbose=true && ninja -C /tmp/hrpcd-asan
# 2) 让设备处于「listener 槽位空闲」的 boot（关键：**先 disable 服务**，mask 会因 unit 文件已存在而失败）
ssh elden 'systemctl disable --now elden-sensorspd && systemctl reboot'
# 3) 后台跑并把 ASan 报告落文件（设备不复位时文件不会丢；**别用 nohup**，见 #740 姊妹条）
ssh elden "(ASAN_OPTIONS=detect_leaks=0 setsid /usr/local/bin/hexagonrpcd-asan -f /dev/fastrpc-adsp -d adsp -s \
     -R /var/lib/hrpcd-root/ </dev/null >/tmp/asan.out 2>&1 &); sleep 60; grep -c 'ERROR: AddressSanitizer' /tmp/asan.out"
```

## 3. 顺带确认的两个"不是 bug"

- `Could not open /vendor/etc/sensors/config/sns_presence_detect.json` 等 7 条、以及 `cam_registry_dump.txt`、
  `sns_odp_config_params.bin`：ROM 里本来就没有这些文件（选配），DSP 收到 ENOENT 后**继续**，不致命。
- `Unknown search directory $`：DSP 传了空环境变量名，我们回 `AEE_EBADPARM`，DSP 也无碍。

## 4. 下一步

1. **真写后端**（唯一功能缺口）：`hexagonfs_mapped` 只读 ⇒ copy-on-write 到 `/var/lib/hexagonrpc/`，
   `fwrite/ftrunc/fremove/frename/mkdir/rmdir/fsync` 真实现 ⇒ registry/标定可持久化（现在每次 PD 重启都要重新解析）。
2. 上游：#29 仍 open；我们有「0 字节占位 + 扁平布局 + 方法表索引」三条一手经验，**回帖需用户放行**。
