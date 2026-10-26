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
#
# ⚠️ 2026-10-26（T14 去 Alpine 化）：本表**不再是唯一真源**，权威已迁到 `deps.tsv`
#   （抽象名 → openrc / systemd 双列）。这里保留为**派生缓存**，并且必须与 deps.tsv
#   第 2 列逐条一致（`--check` 里的自检会断言，漂了直接 FAIL）。
#   历史教训不变：两个世界不同名，混用即静默失效（PITFALLS #397a）。
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


# ---------------------------------------------------------------- 抽象依赖层
# deps.tsv 的形状：abstract <TAB> openrc <TAB> systemd <TAB> note
# 两类索引，**方向相反**，这是向后兼容的关键：
#   ABSTRACT[抽象名]  → (openrc 名, systemd 名)   新写法（推荐）
#   BY_OPENRC[openrc] → (抽象名, systemd 名)      旧写法（2026-10-25 的 services.tsv 原样可跑）
# ⇒ 「改名换 init」只需改 deps.tsv；「继续用 OpenRC 名」也仍然合法且解析到同一行。
PROVIDER_POINTS = {"container-backend", "sensor-source", "haptics-bridge"}
ABSTRACT = {}
BY_OPENRC = {}
PROVIDERS = {}                # abstract → [provider 候选，现役在前]
DEPS_CONFLICTS = []          # 歧义：同一个 openrc 名出现在两个抽象名里


def load_deps(path: Path):
    ABSTRACT.clear()
    BY_OPENRC.clear()
    PROVIDERS.clear()
    del DEPS_CONFLICTS[:]
    if not path.exists():
        raise RenderError(
            f"缺 {path.name}：抽象依赖词表是必需品（services.tsv 的 need/after/before 靠它渲染）")
    header = None
    for lineno, line in enumerate(path.read_text().splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        vals = line.split("\t")
        if header is None:
            header = vals
            if header[:3] != ["abstract", "openrc", "systemd"]:
                raise RenderError(
                    f"{path.name}:{lineno}: 表头前三列必须是 abstract/openrc/systemd，实际 {header[:3]}")
            continue
        if len(vals) < 3:
            raise RenderError(f"{path.name}:{lineno}: 列数 {len(vals)} < 3")
        abstract, openrc, systemd = (v.strip() for v in vals[:3])
        if not abstract or not openrc or not systemd:
            raise RenderError(f"{path.name}:{lineno}: 抽象名/两种名字都不能为空：{line[:80]}")
        # 可选第 5 列 provider：只有 3 个抽象点允许带（防到处长出可插拔点）
        if len(vals) >= 5 and vals[4].strip():
            if abstract not in PROVIDER_POINTS:
                raise RenderError(
                    f"{path.name}:{lineno}: 抽象名 {abstract!r} 不是三大抽象点，"
                    f"不得带 provider 列（防过度设计）")
            PROVIDERS[abstract] = vals[4].split()
        if abstract in ABSTRACT:
            raise RenderError(f"{path.name}:{lineno}: 抽象名重复：{abstract}")
        if not systemd.endswith((".service", ".target")):
            raise RenderError(
                f"{path.name}:{lineno}: systemd 列必须是 *.service 或 *.target（否则 systemd 静默忽略）：{systemd}")
        if openrc in BY_OPENRC and BY_OPENRC[openrc][0] != abstract:
            DEPS_CONFLICTS.append((openrc, BY_OPENRC[openrc][0], abstract))
        ABSTRACT[abstract] = (openrc, systemd)
        BY_OPENRC[openrc] = (abstract, systemd)


def _lookup(name: str):
    """依赖名 → (抽象名, openrc 名, systemd 名)；抽象名优先，其次旧 OpenRC 名。"""
    if name in ABSTRACT:
        openrc, systemd = ABSTRACT[name]
        return name, openrc, systemd
    if name in BY_OPENRC:
        abstract, systemd = BY_OPENRC[name]
        return abstract, name, systemd
    return None


def unit_name(name: str, known: set) -> str:
    """把 services.tsv / deps.tsv 里的依赖名翻成 **systemd** 单元名。

    解析顺序（每条都必须有出处，杜绝「看起来能跑」）：
      1. deps.tsv 的抽象名         —— 新写法，推荐
      2. deps.tsv 的 openrc 名     —— 旧写法，向后兼容（同一个 systemd 名）
      3. UNIT_MAP（历史缓存）      —— 只为兼容 deps.tsv 尚未覆盖的历史行
      4. 本包 services.tsv 的服务名 —— 同包互依
      其它 ⇒ 抛错（systemd 会静默忽略，绝不能放过）
    """
    hit = _lookup(name)
    if hit is not None:
        abstract, _, systemd = hit
        legacy = UNIT_MAP.get(name)
        if legacy is not None and legacy != systemd:
            raise RenderError(
                f"依赖名 {name!r} 在 deps.tsv 与 UNIT_MAP 里解析不一致"
                f"（deps.tsv={systemd} / UNIT_MAP={legacy}）⇒ 先统一再渲染")
        return systemd
    if name in UNIT_MAP:
        return UNIT_MAP[name]
    if name in known:
        return f"{name}.service"
    raise RenderError(
        f"依赖名 {name!r} 既不在 deps.tsv、也不在 UNIT_MAP、也不是本包服务 ⇒ systemd 侧会静默忽略"
        f"（在 deps.tsv 加抽象名，或改用已有抽象名）")


def openrc_name(name: str) -> str:
    """把依赖名翻成 **OpenRC** 侧的名字（`depend() { need … }`）。"""
    hit = _lookup(name)
    if hit is not None:
        return hit[1]
    # 本包服务名与历史 UNIT_MAP 项在 OpenRC 侧原样保留（它们本来就是 OpenRC 名）
    return name

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

    # 抽象名 → OpenRC 名字（deps.tsv 第 2 列）；未登记的（本包服务/历史项）原样透传
    # 去重按**抽象名**判定（need 写 fs-local、after 写 localmount 是同一个依赖，不能重复渲染）
    def _canon(x):
        hit = _lookup(x)
        return hit[0] if hit is not None else x

    need_raw = split_names(svc.get("need"))
    need_keys = {_canon(x) for x in need_raw}
    need = [openrc_name(x) for x in need_raw]
    after = [openrc_name(x) for x in split_names(svc.get("after")) if _canon(x) not in need_keys]
    dep = []
    if need:
        dep.append("need " + " ".join(need))
    if after:
        dep.append("after " + " ".join(after))
    if split_names(svc.get("before")):
        dep.append("before " + " ".join(openrc_name(x) for x in split_names(svc["before"])))
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
    # systemd 侧同理：Requires= 用抽象名归并，After= 去重按抽象名（否则 need fs-local + after localmount 会双写）
    def _canon(x):
        hit = _lookup(x)
        return hit[0] if hit is not None else x

    need = split_names(svc.get("need"))
    need_keys = {_canon(x) for x in need}
    if need:
        deps.append("Requires=" + " ".join(unit_name(x, KNOWN) for x in need))
    after = [x for x in split_names(svc.get("after")) if _canon(x) not in need_keys]
    if after:
        deps.append("After=" + " ".join(unit_name(x, KNOWN) for x in after))
    before = split_names(svc.get("before"))
    if before:
        deps.append("Before=" + " ".join(unit_name(x, KNOWN) for x in before))
    # 去重：同一个 systemd 单元名在 Requires=/After= 里重复出现会被 systemd 接受，
    # 但同名归一后就重复了（example: need fs-local + after localmount ⇒ 两行 local-fs.target）
    seen_units, dedup = set(), []
    for line in deps:
        key = line.split("=", 1)[0]
        units = line.split("=", 1)[1].split() if "=" in line else []
        if key in ("Requires", "After", "Before"):
            units = [u for u in units if (key, u) not in seen_units]
            for u in units:
                seen_units.add((key, u))
            if not units:
                continue
            line = key + "=" + " ".join(units)
        dedup.append(line)
    deps = dedup

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
    try:
        load_deps(ROOT / "deps.tsv")
    except RenderError as exc:
        print("render: FAIL", file=sys.stderr)
        print("  - " + str(exc), file=sys.stderr)
        return 1

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

    # ---- 抽象依赖层自检（2026-10-26 T14：deps.tsv 是唯一真源） ----------------
    # 1. deps.tsv 第 2 列必须与历史 UNIT_MAP 逐条一致（只查两边都有的键）——
    #    不一致就是「同一句话两种说法」，一定要現场修为一个。
    for openrc_name_, (abstract, systemd) in sorted(BY_OPENRC.items()):
        legacy = UNIT_MAP.get(openrc_name_)
        if legacy is not None and legacy != systemd:
            errors.append(
                f"deps.tsv 与 UNIT_MAP 冲突：openrc={openrc_name_} "
                f"deps.tsv→{systemd} / UNIT_MAP→{legacy}")
    # 2. 同一个 openrc 名不得映射到两个抽象名（歧义 = 两种 init 可能走叉）
    for openrc_name_, a1, a2 in DEPS_CONFLICTS:
        errors.append(f"deps.tsv: openrc 名 {openrc_name_!r} 同时属于 {a1!r} 与 {a2!r}")
    # 3. services.tsv 里出现的每个依赖词必须能解析（否则 systemd 静默忽略）
    for svc in services:
        for col in ("need", "after", "before"):
            for token in split_names(svc.get(col)):
                try:
                    unit_name(token, KNOWN)
                except RenderError as exc:
                    errors.append(f"{svc['name']}.{col}: {exc}")
    # 3b. 三大抽象点的 provider 必须可解析（本包服务名 / UNIT_MAP 键 / '-'）
    for abstract, provs in sorted(PROVIDERS.items()):
        if not provs:
            errors.append(f"deps.tsv: {abstract} 的 provider 列为空")
            continue
        for p in provs:
            if p in ("-", KNOWN) or p in KNOWN or p in UNIT_MAP:
                continue
            errors.append(f"deps.tsv: {abstract} 的 provider {p!r} 不是本包服务也不是 UNIT_MAP 键")
    # 4. ★向后兼容硬门：旧 OpenRC 写法与抽象写法必須渲染出**逐字相同**的产物。
    #    做法 = 把每行 need/after/before 的每个词换成「它自己的抽象名」，再渲染一遍比字符串。
    #    这条保证「改名字不改语义」，也是将来换第三种 init 时的回退保险。
    errors.extend(_compat_selfcheck(services))

    # 3c. 三大抽象点必须登记 provider（现役实现可追溯）
    for abstract in sorted(PROVIDER_POINTS):
        if abstract not in ABSTRACT:
            errors.append(f"deps.tsv: 缺抽象点 {abstract}（三抽象点是硬性清单，不许漂）")
        elif abstract not in PROVIDERS:
            errors.append(f"deps.tsv: 抽象点 {abstract} 缺 provider 列（现役实现必须可追溯）")
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


def _compat_selfcheck(services):
    """旧 OpenRC 词表 ⇄ 抽象词表：渲染结果必须逐字等价（向后兼容硬门）。

    返回错误列表（空 = 通过）。只对**实际能被 deps.tsv 解析**的词做归一，其它词原样保留。
    否则任何一次 deps.tsv 改动都可能让旧 services.tsv 静默变异。
    """
    errs = []
    for svc in services:
        if svc["init"] == "package":
            continue
        hook = HOOKS / f"{svc['name']}.pre"
        hook_body = hook.read_text() if hook.exists() else ""
        norm = dict(svc)
        for col in ("need", "after", "before"):
            toks = split_names(svc.get(col))
            out = []
            for t in toks:
                hit = _lookup(t)
                out.append(hit[0] if hit else t)
            norm[col] = " ".join(out)
        try:
            a = render_openrc_initd(svc, hook_body) + render_systemd_unit(svc, hook_body)
            b = render_openrc_initd(norm, hook_body) + render_systemd_unit(norm, hook_body)
        except RenderError:
            continue                      # 其它检查会报具体原因，这里不重复计
        if a != b:
            errs.append(
                f"{svc['name']}: 抽象名与旧 OpenRC 名渲染不等价（去 Alpine 化破坏兼容）")
    return errs


if __name__ == "__main__":
    sys.exit(main())
