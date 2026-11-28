# iio-sensor-proxy 3.9 + elden patches (claim race, ALS deadband)

Upstream: <https://gitlab.freedesktop.org/hadess/iio-sensor-proxy> tag `3.9` (commit `0085ddf`).
Target: Debian trixie arm64 (elden), in-tree package `iio-sensor-proxy 3.9-1`.

| file | what |
|---|---|
| `0001-claim-race-defer-Claim-until-discovery-finished.patch` | queue `Claim*()` that arrives before `find_sensors()` registered that sensor type; turn it into a real claim (polling started, invocation answered after the first reading) once discovery is done; fail with `G_DBUS_ERROR_NOT_SUPPORTED` if the type is really absent |
| `0002-light-deadband-rate-limit-light-level-reports.patch` | deadband `max(20 lux, 5%)` + 1 s hold for ≥10 lux steps + ≤1 report/10 s and ≤6 reports/min per sensor; ≥100 lux steps go out after 2 s; first reading always reported |
| `build-arm64-deb.sh` | reproducible cross build (no root, no chroot) → `artifacts/iio-sensor-proxy_3.9-2elden_arm64.deb` |
| `artifacts/` | deb + loose binary + ABI log + the real "before" lux trace taken from the device journal + the two simulators |
| `../../scripts/deploy-iio-sensor-proxy-patches.sh` | `--check` (read-only) / `--apply` / `--rollback`, runs **on the device** |

Build (host):

```sh
timeout -k 10 900 bash build-arm64-deb.sh        # work dir default /tmp/iio-patch-20261128
```

The build uses the in-repo sysroot `out/sysroot-trixie-arm64` as `sys_root`; because trixie ships
no `libssc` (and the in-repo sysroot has no polkit/`udev.pc`), a symlink farm is made in the work
dir and `libssc`/`polkit-gobject-1` are overlaid from the other trixie arm64 sysroot
(`/tmp/ssc-prep/sysroot-work/sysroot`). `-Wl,--allow-shlib-undefined` is needed because
`libssc.so → libqmi-glib.so.5 → libmbim-glib.so.4` cannot be resolved inside the sysroot; they are
resolved on the device at run time.

Deploy / rollback: see the header of `scripts/deploy-iio-sensor-proxy-patches.sh`.
`--apply` must not be run without a device lock and a decision from the parent session; this
round it was not run.
