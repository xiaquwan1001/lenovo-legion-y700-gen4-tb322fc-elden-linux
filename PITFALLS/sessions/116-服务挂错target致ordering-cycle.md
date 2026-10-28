## #453 服务挂错 target ⇒ systemd **ordering cycle**，冷起根本不启动（且只有一行警告）

> 2026-10-27。G1-34 传感器「修好」后冷起又灭，根因不是驱动/udev，是 systemd 单元挂载点。

### 一、现象

- 手工 `systemctl restart iio-sensor-proxy` → `HasAccelerometer=true`，一切正常；
- **冷起**（RAM 载具 `fastboot boot` 或普通重启）后 → `inactive (dead)`，
  `busctl get-property … HasAccelerometer` 报 `The name net.hadess.SensorProxy was not provided by any .service files`；
- `systemctl --failed` **为空**（不是 failed，是 never started）；
- `journalctl` 只有一行：

```
systemd[1]: iio-sensor-proxy.service: Found ordering cycle: hexagonrpcd.service/start
            after multi-user.target/start after iio-sensor-proxy.service/start
            - after hexagonrpcd.service
systemd[1]: iio-sensor-proxy.service: Unable to break cycle starting with iio-sensor-proxy.service/start
```

### 二、机制

```
hexagonrpcd.service（包提供）: After=multi-user.target   WantedBy=default.target
iio-sensor-proxy.service（我们）: After=hexagonrpcd-adsp-sensorspd.service  WantedBy=multi-user.target
```

`multi-user.target` ←（wants）`iio-sensor-proxy` → `hexagonrpcd` → `After=multi-user.target` = **环**。
systemd 无法破环就直接**放弃启动**该单元，且只打一行 `Unable to break cycle`，**不计入 failed**。

⇒ 判据必须看 `systemctl is-active`，**不能**看 `--failed`；`systemd-analyze verify` 也**不报**这个环。

### 三、修法

把我们的单元挂到环**下游**的 target：

```
services.tsv: iio-sensor-proxy  wantedby = graphical.target   （原 multi-user.target）
```

`graphical.target` 本身 `After=multi-user.target`，于是：graphical → iio-sensor-proxy →（after）hexagonrpcd →（after）multi-user
= 线性，无环。渲染 + 生效三步：

```bash
python3 packaging/elden-userland/tools/render.py           # 重新渲染 unit + enable.tsv
install -D -m644 out/units/systemd/iio-sensor-proxy.service /usr/lib/systemd/system/
rm -f /etc/systemd/system/multi-user.target.wants/iio-sensor-proxy.service
ln -sfn /usr/lib/systemd/system/iio-sensor-proxy.service \
        /etc/systemd/system/graphical.target.wants/iio-sensor-proxy.service
systemctl daemon-reload
```

**冷起实测（RAM 载具 + Debian 根）**：`is-system-running=running`、`failed=0`、
`iio-sensor-proxy=active`、`HasAccelerometer/HasAmbientLight/HasProximity` 三真，**无需任何手工 restart**。

### 四、为什么长期没被发现

- 「手工 restart 一下就正常」⇒ 每次排障都在手工修好后收工，冷起态从没被单独验收；
- `--failed` 干净 + `systemd-analyze verify` 干净 ⇒ 两道常用门禁都放行；
- 我们的 `stage.sh` §G 门禁当时**写死了 `multi-user.target`**，因此即使服务挂错 target 也判"已 enable"（真·同义反复）。
  已改为读 `services.tsv` 的 `wantedby` 列（并处理多 target / `init=package` 两种情形）。

### 五、通用判据（写进习惯）

① 新增/修改 unit 后，**冷起**验证一次 `systemctl is-active <u>`；`--failed` 不作数。
② 任何 `After=` 指向**包提供的**单元时，先 `systemctl cat` 看它的 `After/Before`，
   尤其 Debian 的 `hexagonrpcd` 带 `After=multi-user.target` 这种反直觉依赖。
③ 门禁不要写死 target 名；target 属于数据（`services.tsv`），判据要从数据里取。
