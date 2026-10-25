#!/usr/bin/env python3
"""render.py — services.tsv → OpenRC initd + systemd unit（唯一真源的两份投影）

用法：python3 tools/render.py [--check]
  --check  只校验不写盘（等价 verify.sh 的渲染部分）

设计约束（改的时候别破坏）：
  * OpenRC 侧只用 openrc-run 的原生关键字（command/command_args/pidfile/supervisor/
    respawn_delay/start_pre/depend 的 need-after-before）——不用 supervise-daemon 之外的机制。
  * systemd 侧只用 standard unit 关键字；依赖走 Requires=/After=/Before=；
    安装走 WantedBy=；shutdown 类走 Before=shutdown.target + DefaultDependencies=no。
  * 参数（env）默认值来自 services.tsv；两种 init 都读 /etc/conf.d/<name> 做覆盖。
  * 服务定义里**不允许**出现 `rc-service` / `systemctl` / `apk` / `apt`（跨 init 污染）；
    verify.sh 会扫渲染产物。
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent          # packaging/elden-userland
TEMPLATES = ROOT / "templates"
HOOKS = ROOT / "hooks"
OUT = ROOT / "out" / "units"

COLUMNS = [
    "name", "init", "class", "desc", "exec", "args", "env", "log", "respawn",
    "need", "after", "before", "wantedby", "enabled",
]
REQUIRED = {"name", "init", "class", "desc", "exec"}
CLASSES = {"longrun", "oneshot", "shutdown"}
# OpenRC 服务名 → systemd 单元名（**两个世界不同名**，混用即静默失效）
# 依据：systemd-analyze verify 实测 "Failed to add dependency on localmount"。
UNIT_MAP = {
    # OpenRC 伪服务 / runlevel 关键字
    "localmount": "local-fs.target",
    "root": "local-fs.target",
    "modules": "systemd-modules-load.service",
    "udev": "systemd-udevd.service",
    "udev-settle": "systemd-udev-settle.service",
    "udev-trigger": "systemd-udev-trigger.service",
    "hwclock": "systemd-hwclock.service",
    "hostname": "systemd-hostnamed.service",
    "sysctl": "systemd-sysctl.service",
    "local": "elden-local.service",
    # initscripts 之外的守护
    "dbus": "dbus.service",
    "seatd": "seatd.service",
    "elogind": "elogind.service",
    "polkit": "polkit.service",
    "rtkit": "rtkit-daemon.service",
    "udisks2": "udisks2.service",
    "bluetooth": "bluetooth.service",
    "networkmanager": "NetworkManager.service",
    "chronyd": "chronyd.service",
    "lxc": "lxc.service",
    # 本项目 / 发行版包
    "waydroid-container": "waydroid-container.service",
    "hexagonrpcd-adsp-sensorspd": "hexagonrpcd-adsp-sensorspd.service",
    "sshd": "sshd.service",
}


def unit_name(name: str, known: set) -> str:
    """把 services.tsv 里的依赖名翻成 systemd 单元名。映射表优先，其次本包服务名。"""
    if name in UNIT_MAP:
        return UNIT_MAP[name]
    if name in known:
        return f"{name}.service"
    raise RenderError(
        f"依赖名 {name!r} 既不在 UNIT_MAP 也不是本包服务 ⇒ systemd 侧会静默忽略"
        f"（加映射或改依赖）")

INITS = {"ours", "override", "package"}


class RenderError(Exception):
    pass


def load_provides(path: Path):
    out = {}
    if not path.exists():
        return out
    for line in path.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#") or line.startswith("name\t"):
            continue
        name, alias = (line.split("\t") + [""])[:2]
        out.setdefault(name.strip(), []).append(alias.strip())
    return out


def load_services(path: Path):
    rows, header = [], None
    for lineno, line in enumerate(path.read_text().splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith("name\t"):
            header = line.split("\t")
            continue
        if header is None:
            raise RenderError(f"{path}:{lineno}: 数据行出现在表头之前")
        vals = line.split("\t")
        if len(vals) != len(header):
            raise RenderError(
                f"{path}:{lineno}: 列数 {len(vals)} != 表头 {len(header)}"
                f"（字段里可能有 TAB 而非空格）: {line[:80]}")
        rows.append(dict(zip(header, vals)))
    if header is None:
        raise RenderError(f"{path}: 找不到表头")
    missing = REQUIRED - set(header)
    if missing:
        raise RenderError(f"{path}: 表头缺列 {sorted(missing)}")
    return rows


def env_pairs(env: str):
    out = []
    for item in (env or "").split(";"):
        item = item.strip()
        if not item:
            continue
        if "=" not in item:
            raise RenderError(f"env 项不是 K=V：{item!r}")
        k, v = item.split("=", 1)
        out.append((k.strip(), v.strip()))
    return out


def split_names(s: str):
    return [x for x in (s or "").split() if x]


def subst(tpl: str, mapping) -> str:
    out = tpl
    for k, v in mapping.items():
        out = out.replace(f"@{k}@", v)
    left = [ln for ln in out.splitlines() if "@" in ln and ln.count("@") >= 2]
    if left:
        raise RenderError("未替换的占位符: " + "; ".join(left[:3]))
    return out


def render_openrc_initd(svc, hook_body):
    cls = svc["class"]
    extra = []
    if cls == "longrun":
        extra.append('command_background="yes"')
        extra.append(f'pidfile="/run/{svc["name"]}.pid"')
        if svc.get("log"):
            extra.append(f'output_log="{svc["log"]}"')
            extra.append(f'error_log="{svc["log"]}"')
        respawn = int(svc.get("respawn") or 0)
        if respawn > 0:
            extra.append('supervisor="supervise-daemon"')
            extra.append(f"respawn_delay_seconds={respawn}")
            extra.append("respawn_max=10")

    need = split_names(svc.get("need"))
    after = [x for x in split_names(svc.get("after")) if x not in need]
    dep = []
    if need:
        dep.append("need " + " ".join(need))
    if after:
        dep.append("after " + " ".join(after))
    if split_names(svc.get("before")):
        dep.append("before " + " ".join(split_names(svc["before"])))
    if not dep:
        # ⚠️ bash 会把「函数体里只有一行注释」判为语法错误（`f() { # c\n }` → unexpected token）
        dep.append(": # 无依赖")

    confd = (f'[ -f "/etc/conf.d/{svc["name"]}" ] && . "/etc/conf.d/{svc["name"]}"')
    pairs = env_pairs(svc.get("env"))
    defaults = "\n".join(f': "${{{k}:={v}}}"' for k, v in pairs) or "# 无默认参数"
    if pairs:
        defaults += "\nexport " + " ".join(k for k, _ in pairs)

    pre = ""
    if hook_body:
        body = "\n".join("\t" + ln if ln.strip() else "" for ln in hook_body.rstrip().splitlines())
        pre = f"\nstart_pre() {{\n{body}\n}}"

    provides = PROVIDES.get(svc["name"], [])
    if provides:
        dep.append("provide " + " ".join(provides))
    oneshot_start = ""
    if cls != "longrun":
        oneshot_start = (
            "\n# oneshot/shutdown：显式 start()，让状态如实报 started/failed 而不是 crashed\n"
            "start() {\n"
            '\tebegin "' + svc["desc"].replace('"', "'") + '"\n'
            '\t"$command" $command_args\n'
            "\teend $?\n"
            "}\n")

    mapping = {
        "NAME": svc["name"], "INIT": svc["init"], "CLASS": cls, "DESC": svc["desc"],
        "EXEC": svc["exec"], "ARGS": svc.get("args", ""),
        "ONESHOT_START": oneshot_start,
        "CONFD": confd, "ENV_DEFAULTS": defaults,
        "OPENRC_EXTRA": "\n".join(extra) or "# oneshot：前台执行",
        "DEPEND": "\n".join("\t" + d for d in dep),
        "PRE_HOOK": pre,
    }
    return subst((TEMPLATES / "openrc-initd.in").read_text(), mapping)


def render_systemd_unit(svc, hook_body):
    cls = svc["class"]
    deps = []
    if cls == "shutdown":
        deps.append("DefaultDependencies=no")
        deps.append("After=local-fs.target")
        deps.append("Before=shutdown.target")
    need = split_names(svc.get("need"))
    if need:
        deps.append("Requires=" + " ".join(unit_name(x, KNOWN) for x in need))
    after = [x for x in split_names(svc.get("after")) if x not in need]
    if after:
        deps.append("After=" + " ".join(unit_name(x, KNOWN) for x in after))
    before = split_names(svc.get("before"))
    if before:
        deps.append("Before=" + " ".join(unit_name(x, KNOWN) for x in before))

    body = []
    if cls == "shutdown":
        body.append("RemainAfterExit=yes")

    if hook_body:
        hook_path = f"/usr/local/libexec/elden/{svc['name']}.pre"
        body.append(f"ExecStartPre={hook_path}")

    exec_line = svc["exec"] + (" " + svc["args"] if svc.get("args") else "")
    body.append(f"ExecStart={exec_line}")

    pairs = env_pairs(svc.get("env"))
    if pairs:
        body.append("Environment=" + " ".join(f'"{k}={v}"' for k, v in pairs))
    body.append(f"EnvironmentFile=-/etc/conf.d/{svc['name']}")

    if cls == "longrun":
        respawn = int(svc.get("respawn") or 0)
        if respawn > 0:
            body.append("Restart=always")
            body.append(f"RestartSec={respawn}")
        else:
            body.append("Restart=no")
    if cls == "longrun" and svc.get("log") and svc["log"].startswith("/"):
        body.append(f"StandardOutput=append:{svc['log']}")
        body.append(f"StandardError=append:{svc['log']}")

    wantedby = split_names(svc.get("wantedby")) or ["multi-user.target"]
    install = "WantedBy=" + " ".join(wantedby)
    provides = PROVIDES.get(svc["name"], [])
    if provides:
        install += "\nAlias=" + " ".join(f"{a}.service" for a in provides)

    mapping = {
        "NAME": svc["name"], "INIT": svc["init"], "CLASS": cls, "DESC": svc["desc"],
        "UNIT_DEPS": "\n".join(deps) or "# 无额外依赖",
        "TYPE": "simple" if cls == "longrun" else "oneshot",
        "SERVICE_BODY": "\n".join(body),
        "INSTALL": install,
    }
    return subst((TEMPLATES / "systemd.service.in").read_text(), mapping)


def main() -> int:
    check_only = "--check" in sys.argv
    services = load_services(ROOT / "services.tsv")
    global KNOWN, PROVIDES
    KNOWN = {s["name"] for s in services}
    PROVIDES = load_provides(ROOT / "provides.tsv")

    seen = set()
    errors = []
    rendered = []
    for svc in services:
        name = svc["name"]
        if name in seen:
            errors.append(f"重复服务名：{name}")
        seen.add(name)
        if svc["init"] not in INITS:
            errors.append(f"{name}: init={svc['init']!r} 不在 {sorted(INITS)}")
        if svc["class"] not in CLASSES:
            errors.append(f"{name}: class={svc['class']!r} 不在 {sorted(CLASSES)}")
        if not (svc.get("respawn") or "0").isdigit():
            errors.append(f"{name}: respawn={svc.get('respawn')!r} 不是整数（多半是列错位）")
        if not svc["exec"].startswith("/"):
            errors.append(f"{name}: exec 必须是绝对路径：{svc['exec']!r}")
        if svc["init"] == "package":
            # 包自带 unit：不渲染，避免覆盖发行版单元；只登记依赖与验收名
            rendered.append((svc, "", ""))
            continue
        hook = HOOKS / f"{name}.pre"
        hook_body = hook.read_text() if hook.exists() else ""
        try:
            o = render_openrc_initd(svc, hook_body)
            s = render_systemd_unit(svc, hook_body)
        except RenderError as exc:
            errors.append(f"{name}: {exc}")
            continue
        rendered.append((svc, o, s))

        # 跨 init 污染检查（语义红线，不依赖 verify.sh）
        for bad in ("rc-service", "rc-update", "systemctl", "apk ", "apt-get"):
            if bad in s and svc["init"] == "ours":
                errors.append(f"{name}: systemd unit 出现跨-init 调用 {bad!r}")
                break

    for name, aliases in PROVIDES.items():
        if name not in KNOWN:
            errors.append(f"provides.tsv: {name} 不是 services.tsv 里的服务")
        if not aliases:
            errors.append(f"provides.tsv: {name} 别名列表为空")

    if errors:
        print("render: FAIL", file=sys.stderr)
        for e in errors:
            print("  - " + e, file=sys.stderr)
        return 1

    print(f"render: {len(rendered)} 个服务，"
          f"{sum(1 for s, _, _ in rendered if s.get('enabled') == '1')} 个默认启用")
    if check_only:
        print("render: --check 通过（未写盘）")
        return 0

    for d in (OUT / "openrc", OUT / "systemd", OUT / "hooks"):
        if d.exists():
            for f in d.iterdir():
                f.unlink()
        d.mkdir(parents=True, exist_ok=True)

    pkg = []
    for svc, o, s in rendered:
        name = svc["name"]
        if svc["init"] == "package":
            pkg.append(f"{name}\t{svc['exec']}\t{svc['desc']}")
            continue
        (OUT / "openrc" / name).write_text(o)
        (OUT / "openrc" / name).chmod(0o755)
        (OUT / "systemd" / f"{name}.service").write_text(s)
        hook = HOOKS / f"{name}.pre"
        if hook.exists():
            (OUT / "hooks" / f"{name}.pre").write_text(hook.read_text())
            (OUT / "hooks" / f"{name}.pre").chmod(0o755)

    # 安装清单：迁移时照着这张表 enable（enabled=0 的跳过）
    lines = ["# GENERATED — 迁移后要启用的服务（enabled=1）；0 的保留定义不启用",
             "# name<TAB>openrc-runlevel<TAB>systemd-target"]
    for svc, _, _ in rendered:
        if svc.get("enabled") != "1":
            continue
        runlevel = "shutdown" if svc["class"] == "shutdown" else (
            "boot" if svc["class"] == "oneshot" and svc["name"] in {"pstore-catch"} else "default")
        lines.append(f"{svc['name']}\t{runlevel}\t{' '.join(split_names(svc.get('wantedby')))}")
    (OUT / "enable.tsv").write_text("\n".join(lines) + "\n")
    (OUT / "packages.tsv").write_text(
        "# 包自带 unit（我们**不**渲染，迁移后只需确认已安装 + enable）\n"
        "# name<TAB>exec<TAB>desc\n" + ("\n".join(pkg) + "\n" if pkg else ""))

    print(f"render: → {OUT.relative_to(ROOT)}/{{openrc,systemd,hooks}}, enable.tsv")
    return 0


if __name__ == "__main__":
    sys.exit(main())
