#!/usr/bin/env python3
"""从已上机的精简 system_a.img 提取安卓原厂资产 → assets/android-20261119/ + MANIFEST.tsv

纯主机侧、无 root：只用 debugfs 读 ext4 镜像（不 loop mount），zipfile 读 apk。
主源  = out/android-min-20261118/new/system_a.img（5.0 GiB ext4，已上机件）
次源  = 同一镜像里的 apk（ZuiWallpaperSetting / ZuiStandbyMode / framework-res）

用法:
  python3 scripts/android-assets-extract-20261119.py            # 重建 assets 树（复用 staging）
  python3 scripts/android-assets-extract-20261119.py --clean    # 先删 staging/assets 再重建

产物:
  assets/android-20261119/{wallpapers,lockscreen,sounds,bootanimation,fonts,meta}/
  assets/android-20261119/meta/MANIFEST.tsv
  assets/android-20261119/meta/{fonts-inventory.tsv,apk-inventory.tsv,extract.log}

判据: 每行 sha256 实测；图片分辨率用 Pillow 读；音频时长用 ffprobe；mime 用 `file --mime-type`。
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(ROOT, "out/android-min-20261118/new/system_a.img")
OUT = os.path.join(ROOT, "assets/android-20261119")
STG = os.path.join(ROOT, "out/android-assets-20261119/staging")
DEBUGFS = "/usr/sbin/debugfs"
SRC_IMG = "out/android-min-20261118/new/system_a.img"

log_lines = []


def log(msg):
    print(msg, flush=True)
    log_lines.append(msg)


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def dcmd(*args):
    """debugfs -R 一条命令；去掉 chown 噪音（非 root 无法改属主，无害）。"""
    r = run([DEBUGFS, "-R", " ".join(args), IMG])
    return r.stdout.replace("debugfs 1.47.2 (1-Jan-2025)\n", "")


def rdump(path, dest):
    """rdump 一个目录到 dest/<name>；返回真实落点。"""
    os.makedirs(dest, exist_ok=True)
    r = run([DEBUGFS, "-R", f"rdump {path} {dest}", IMG])
    errs = [l for l in (r.stdout + r.stderr).splitlines()
            if "changing ownership" not in l and l.strip() and "debugfs 1.4" not in l]
    real = os.path.join(dest, os.path.basename(path))
    log(f"  rdump {path} -> {os.path.relpath(real, ROOT)} "
        f"({sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fs in os.walk(real) for f in fs)/1e6:.1f} MB)"
        + (f" note={errs[:1]}" if errs else ""))
    return real


def dump_file(img_path, dest):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    run([DEBUGFS, "-R", f"dump {img_path} {dest}", IMG])
    if not os.path.isfile(dest):
        raise SystemExit(f"dump failed: {img_path}")
    return dest


def ensure_staging():
    m = os.path.join(STG, "media/media")
    if not os.path.isdir(m):
        rdump("/system/media", os.path.join(STG, "media"))
    th = os.path.join(STG, "etc/themes")
    if not os.path.isdir(th):
        rdump("/system/etc/themes", os.path.join(STG, "etc"))
    apk = os.path.join(STG, "apk")
    os.makedirs(apk, exist_ok=True)
    for name, p in (
        ("ZuiWallpaperSetting.apk", "/system/priv-app/ZuiWallpaperSetting/ZuiWallpaperSetting.apk"),
        ("ZuiStandbyMode.apk", "/system/priv-app/ZuiStandbyMode/ZuiStandbyMode.apk"),
        ("framework-res.apk", "/system/framework/framework-res.apk"),
    ):
        d = os.path.join(apk, name)
        if not os.path.isfile(d) or os.path.getsize(d) == 0:
            log(f"  dump {p}")
            dump_file(p, d)
    return apk


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def mime_of(path):
    r = run(["file", "-b", "--mime-type", path])
    return r.stdout.strip() or "application/octet-stream"


def img_dims(path):
    try:
        from PIL import Image
        with Image.open(path) as im:
            return im.size, im.format
    except Exception:
        return (0, 0), "?"


def audio_dur(path):
    r = run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=nw=1:nk=1", path])
    try:
        return float(r.stdout.strip())
    except ValueError:
        return 0.0


MANIFEST = []  # (file, size, sha256, mime, source_image, source_path, use_hint)


def add(path, source_path, use_hint, source_image=None, extra=None):
    size = os.path.getsize(path)
    rel = os.path.relpath(path, OUT)
    mime = mime_of(path)
    hint = use_hint
    if mime.startswith("image/"):
        (w, h), fmt = img_dims(path)
        hint = f"{hint}; {w}x{h} {fmt}"
    elif mime.startswith("audio/") or mime.endswith("ogg"):
        hint = f"{hint}; {audio_dur(path):.1f}s"
    if extra:
        hint = f"{hint}; {extra}"
    MANIFEST.append((rel, size, sha256_of(path), mime,
                     source_image or SRC_IMG, source_path, hint))


def copytree_sub(src_dir, dst_dir, use_hint, source_prefix):
    os.makedirs(dst_dir, exist_ok=True)
    n = 0
    for name in sorted(os.listdir(src_dir)):
        s = os.path.join(src_dir, name)
        if os.path.isdir(s):
            n += copytree_sub(s, os.path.join(dst_dir, name), use_hint,
                              f"{source_prefix}/{name}")
        elif os.path.isfile(s):
            d = os.path.join(dst_dir, name)
            shutil.copy2(s, d)
            add(d, f"{source_prefix}/{name}", use_hint)
            n += 1
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--clean", action="store_true")
    args = ap.parse_args()

    if not os.path.isfile(IMG):
        raise SystemExit(f"missing {IMG}")
    if args.clean:
        for d in (STG, OUT):
            shutil.rmtree(d, ignore_errors=True)
    log(f"[1] staging from {SRC_IMG}")
    apk_dir = ensure_staging()

    log("[2] 壁纸 /system/media/wallpapers")
    sysw = os.path.join(STG, "media/media/wallpapers")
    os.makedirs(os.path.join(OUT, "wallpapers"), exist_ok=True)
    for name in sorted(os.listdir(sysw)):
        s = os.path.join(sysw, name)
        if os.path.isdir(s):
            if name == "lockscreen":
                continue
            copytree_sub(s, os.path.join(OUT, "wallpapers", name),
                         "壁纸(ZUI 主题目录)", f"/system/media/wallpapers/{name}")
        elif name.endswith(".xml"):
            continue  # 配置进 meta
        else:
            d = os.path.join(OUT, "wallpapers", name)
            shutil.copy2(s, d)
            add(d, f"/system/media/wallpapers/{name}", "壁纸/默认壁纸(ZUI 原厂)")
    # 锁屏壁纸单列
    os.makedirs(os.path.join(OUT, "wallpapers/lockscreen"), exist_ok=True)
    d = os.path.join(OUT, "wallpapers/lockscreen/wallpaper")
    shutil.copy2(os.path.join(sysw, "lockscreen/wallpaper"), d)
    add(d, "/system/media/wallpapers/lockscreen/wallpaper", "锁屏壁纸(ZUI 默认)")
    for name in ("default_config.xml", "zui_launcher_config.xml"):
        src = os.path.join(sysw, name) if name.startswith("default") else os.path.join(STG, "media/media", name)
        if os.path.isfile(src):
            dst = os.path.join(OUT, "meta", name)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)
            add(dst, f"/system/media/{'wallpapers/' if name.startswith('default') else ''}{name}",
                "ZUI 壁纸/桌面配置(参考)")

    log("[3] 锁屏/AOD 资产: framework-res + ZuiStandbyMode")
    lock = os.path.join(OUT, "lockscreen")
    os.makedirs(lock, exist_ok=True)
    fw = zipfile.ZipFile(os.path.join(apk_dir, "framework-res.apk"))
    fw_map = {
        "res/drawable-nodpi-v4/default_wallpaper.png": "default_wallpaper_phone.png",
        "res/drawable-sw600dp-nodpi-v13/default_wallpaper.png": "default_wallpaper_sw600dp.png",
        "res/drawable-sw720dp-nodpi-v13/default_wallpaper.png": "default_wallpaper_sw720dp.png",
        "assets/images/clock_font.png": "framework_clock_font.png",
    }
    for src, dstname in fw_map.items():
        with fw.open(src) as f, open(os.path.join(lock, dstname), "wb") as o:
            shutil.copyfileobj(f, o)
        add(os.path.join(lock, dstname), f"framework-res.apk!/{src}",
            "框架默认壁纸/锁屏时钟字体图(AOSP 基线)", source_image="framework-res.apk(内嵌于 system_a.img)")
    sd = os.path.join(STG, "standby")
    os.makedirs(sd, exist_ok=True)
    zsm = zipfile.ZipFile(os.path.join(apk_dir, "ZuiStandbyMode.apk"))
    for i in zsm.infolist():
        if i.filename.lower().endswith((".jpg", ".jpeg")):
            with zsm.open(i) as f, open(os.path.join(sd, os.path.basename(i.filename)), "wb") as o:
                shutil.copyfileobj(f, o)
    sbdir = os.path.join(lock, "standby-mode")
    os.makedirs(sbdir, exist_ok=True)
    n = 0
    for name in sorted(os.listdir(sd)):
        s = os.path.join(sd, name)
        (w, h), _ = img_dims(s)
        if min(w, h) < 1000:  # 64x44 等 UI 碎图
            continue
        shutil.copy2(s, os.path.join(sbdir, name))
        add(os.path.join(sbdir, name), f"ZuiStandbyMode.apk!/res/{name}",
            "ZUI 息屏/AOD 与锁屏时钟背景(原厂摄影壁纸)", source_image="ZuiStandbyMode.apk(内嵌于 system_a.img)")
        n += 1
    log(f"  standby-mode kept {n}")

    log("[4] ZuiWallpaperSetting.apk → 大图壁纸池")
    zw = os.path.join(STG, "apk/zwalls")
    zws = zipfile.ZipFile(os.path.join(apk_dir, "ZuiWallpaperSetting.apk"))
    os.makedirs(zw, exist_ok=True)
    for i in zws.infolist():
        if i.is_dir() or not i.filename.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
            continue
        d = os.path.join(zw, os.path.basename(i.filename))
        if not os.path.isfile(d):
            with zws.open(i) as f, open(d, "wb") as o:
                shutil.copyfileobj(f, o)
    zout = os.path.join(OUT, "wallpapers/zui-wallpaper-setting")
    os.makedirs(zout, exist_ok=True)
    n = 0
    for name in sorted(os.listdir(zw)):
        s = os.path.join(zw, name)
        (w, h), _ = img_dims(s)
        if min(w, h) >= 1904 and os.path.getsize(s) >= 500000:
            shutil.copy2(s, os.path.join(zout, name))
            add(os.path.join(zout, name), f"ZuiWallpaperSetting.apk!/res/{name}",
                "ZUI 壁纸商店大图(桌面/锁屏可用)", source_image="ZuiWallpaperSetting.apk(内嵌于 system_a.img)")
            n += 1
    log(f"  zui-wallpaper-setting kept {n}")

    log("[5] 音效 /system/media/audio")
    audio = os.path.join(STG, "media/media/audio")
    for sub, hint in (("alarms", "闹钟铃声"), ("notifications", "通知音"),
                      ("ringtones", "来电铃声"), ("ui", "系统 UI 音效")):
        copytree_sub(os.path.join(audio, sub), os.path.join(OUT, "sounds", sub),
                     hint, f"/system/media/audio/{sub}")

    log("[6] 开机/关机动画")
    ba = os.path.join(OUT, "bootanimation")
    os.makedirs(ba, exist_ok=True)
    for name in sorted(os.listdir(os.path.join(STG, "media/media"))):
        if name.endswith(".zip") and name.startswith(("bootanimation", "shutdownanimation")):
            shutil.copy2(os.path.join(STG, "media/media", name), os.path.join(ba, name))
            add(os.path.join(ba, name), f"/system/media/{name}",
                "开机/关机动画(Plymouth 参考,不直接安装)")
    # 记录动画帧规格（zip 内 desc.txt）
    for name in os.listdir(ba):
        try:
            z = zipfile.ZipFile(os.path.join(ba, name))
            desc = z.read("desc.txt").decode("utf-8", "replace").strip() if "desc.txt" in z.namelist() else "?"
        except Exception as e:
            desc = f"ERR {e}"
        log(f"  desc.txt {name}: {' | '.join(desc.splitlines()[:2])}")

    log("[7] 字体")
    fdir = os.path.join(OUT, "fonts")
    os.makedirs(fdir, exist_ok=True)
    ls = run([DEBUGFS, "-R", "ls -l /system/fonts", IMG]).stdout
    fonts = []
    for line in ls.splitlines():
        parts = line.split()
        if len(parts) >= 9 and parts[1].isdigit():
            fonts.append((parts[8], int(parts[5])))
    kept = [f for f, _ in fonts if f == "ZUKChinese.ttf" or f.startswith("SourceSansPro-")]
    for f in kept:
        d = os.path.join(fdir, f)
        dump_file(f"/system/fonts/{f}", d)
        add(d, f"/system/fonts/{f}", "字体(ZUI 特色/可用于桌面)")
    with open(os.path.join(OUT, "meta/fonts-inventory.tsv"), "w") as o:
        o.write("font\tsize\tcopied\n")
        for f, s in sorted(fonts, key=lambda x: -x[1]):
            o.write(f"{f}\t{s}\t{'yes' if f in kept else 'no'}\n")
    log(f"  fonts total {len(fonts)}, copied {len(kept)} ({sum(os.path.getsize(os.path.join(fdir,f)) for f in kept)/1e6:.1f} MB)")

    # ZuiStandbyMode.apk 内嵌字体 = ZUI 息屏/锁屏时钟字型（资源名混淆，族名用 fc-scan 实测）
    log("[7b] ZUI 锁屏/AOD 时钟字体 (ZuiStandbyMode.apk)")
    have = {sha256_of(os.path.join(fdir, f)) for f in kept}
    zsb = os.path.join(OUT, "fonts/zui-standby")
    os.makedirs(zsb, exist_ok=True)
    for i in zsm.infolist():
        if not i.filename.lower().endswith((".ttf", ".otf")):
            continue
        data = zsm.read(i)
        h = hashlib.sha256(data).hexdigest()
        if h in have:  # 与 /system/fonts 重复（ne.ttf == ZUKChinese.ttf）
            continue
        dst = os.path.join(zsb, os.path.basename(i.filename))
        with open(dst, "wb") as o:
            o.write(data)
        fam = run(["fc-scan", "--format", "%{family}|%{style}", dst]).stdout.strip()
        add(dst, f"ZuiStandbyMode.apk!/{i.filename}",
            f"ZUI 锁屏/AOD 时钟字体(fc-scan: {fam})",
            source_image="ZuiStandbyMode.apk(内嵌于 system_a.img)")
    log(f"  zui-standby fonts {len(os.listdir(zsb))}")

    log("[8] apk 内资产盘点")
    with open(os.path.join(OUT, "meta/apk-inventory.tsv"), "w") as o:
        o.write("apk\tentries\tmedia_bytes\tnote\n")
        for name in ("ZuiWallpaperSetting.apk", "ZuiStandbyMode.apk", "framework-res.apk"):
            z = zipfile.ZipFile(os.path.join(apk_dir, name))
            ents = [i for i in z.infolist() if not i.is_dir()]
            media = sum(i.file_size for i in ents if i.filename.lower().endswith(
                (".png", ".jpg", ".jpeg", ".webp", ".mp4")))
            o.write(f"{name}\t{len(ents)}\t{media}\t\n")
    # 未复制清单（说明为何不复制，便于以后按需再取）
    with open(os.path.join(OUT, "meta/skipped-assets.tsv"), "w") as o:
        o.write("source\tentry\tsize\treason\n")
        for i in zws.infolist():
            if i.is_dir():
                continue
            low = i.filename.lower()
            if low.endswith(".mp4"):
                o.write(f"ZuiWallpaperSetting.apk\t{i.filename}\t{i.file_size}\t动态壁纸视频(本包只收静态图)\n")
            elif low.endswith((".png", ".jpg", ".jpeg", ".webp")) and i.file_size >= 500000:
                n = os.path.basename(i.filename)
                if not os.path.isfile(os.path.join(zout, n)):
                    o.write(f"ZuiWallpaperSetting.apk\t{i.filename}\t{i.file_size}\t分辨率<1904 的 UI 图/预览图\n")
        for f, sz in fonts:
            if f not in kept and sz > 1000000:
                o.write(f"system_a.img\t/system/fonts/{f}\t{sz}\tAOSP/Noto 通用字体(发行版已有)\n")
    # 主题图标包（非壁纸，只登记）
    th = os.path.join(OUT, "meta/themes-info.txt")
    os.makedirs(os.path.dirname(th), exist_ok=True)
    with open(th, "w") as o:
        o.write("# /system/etc/themes（图标 mask 主题包，非壁纸；staging 保留供查）\n")
        for dp, _, fs in os.walk(os.path.join(STG, "etc/themes")):
            for f in sorted(fs):
                p = os.path.join(dp, f)
                o.write(f"{os.path.relpath(p, STG)} {os.path.getsize(p)}\n")

    log("[9] MANIFEST.tsv")
    # 重复内容标注
    by_sha = {}
    for row in MANIFEST:
        by_sha.setdefault(row[2], []).append(row[0])
    dup = {k: v for k, v in by_sha.items() if len(v) > 1}
    mpath = os.path.join(OUT, "meta/MANIFEST.tsv")
    with open(mpath, "w") as o:
        o.write("file\tsize\tsha256\tmime\tsource_image\tsource_path\tuse_hint\n")
        for rel, size, sha, mime, simg, spath, hint in sorted(MANIFEST):
            if sha in dup and rel != sorted(dup[sha])[0]:
                hint += f"; dup of {sorted(dup[sha])[0]}"
            o.write(f"{rel}\t{size}\t{sha}\t{mime}\t{simg}\t{spath}\t{hint}\n")
    with open(os.path.join(OUT, "meta/extract.log"), "w") as o:
        o.write("\n".join(log_lines) + "\n")
    total = sum(r[1] for r in MANIFEST)
    log(f"DONE rows={len(MANIFEST)} bytes={total/1e6:.1f}MB dup_groups={len(dup)}")
    print(json.dumps({"manifest": os.path.relpath(mpath, ROOT), "rows": len(MANIFEST),
                      "bytes": total, "dup_groups": len(dup)}, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main())
