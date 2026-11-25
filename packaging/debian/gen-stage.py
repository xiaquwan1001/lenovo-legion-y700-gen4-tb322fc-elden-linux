#!/usr/bin/env python3
"""Generate the build-time files of the Droidloom Debian packages.

The Debian packaging packs a staged payload (the same tree
``packaging/arch/PKGBUILD.in`` packs) or, for the host architecture only, the
runtime tree compiled from this checkout.  Everything that is derived rather
than copied lives here so the Arch and Debian recipes share one definition:

  cell-template   portable cell recipe (no builder identity, package paths)
  package-json    the release identity the runtime publishes
  licenses        project, upstream and Cargo dependency notices
  control         one binary package's control paragraph, from control.in

Usage: gen-stage.py <subcommand> ... ; run with no arguments for help.
"""

import json
import os
import re
import shutil
import subprocess
import sys

DEFAULT_ARCHITECTURES = {"x86_64": "amd64", "aarch64": "arm64"}

# Same list as tools/droidloom-update/src/licenses.rs: the upstream notices the
# binary packages must carry beside the project's own license text.
UPSTREAM_NOTICES = [
    "android/native-bridge/NOTICE.txt",
    "android/manifest/native-bridge-lock.json",
    "protocol/denial-frame-timeline-v1.xml",
    "graphics/droidloom-wayland/protocol/denial-text-input-panel-v1.xml",
    "graphics/droidloom-wayland/protocol/denial-insets-v1.xml",
    "runtime/droidloom-devices/protocol/denial-fingerprint-verify-v1.xml",
    "android/device/droidloom_arm64/android.software.activities_on_secondary_displays.xml",
]

# Keys a portable recipe must not carry: builder identity and local storage.
PORTABLE_REMOVED_KEYS = [
    "host_uid",
    "render_node",
    "data_dir",
    "runtime_dir",
    "denial_socket",
]


def die(message):
    print(f"gen-stage: {message}", file=sys.stderr)
    raise SystemExit(2)


def copy(source, destination):
    os.makedirs(os.path.dirname(destination), exist_ok=True)
    shutil.copyfile(source, destination)
    shutil.copymode(source, destination)


def walk(root):
    for directory, _, files in os.walk(root):
        for name in sorted(files):
            yield os.path.join(directory, name)


def cell_template(recipe_path, output):
    with open(recipe_path, encoding="utf-8") as source:
        recipe = json.load(source)
    recipe["image_dir"] = "/usr/lib/droidloom/images"
    recipe["vendor_image"] = "/usr/lib/droidloom/images/images/vendor.raw.img"
    for key in PORTABLE_REMOVED_KEYS:
        recipe.pop(key, None)
    recipe["shared_storage_directories"] = []
    with open(output, "w", encoding="utf-8") as target:
        json.dump(recipe, target, indent=2, sort_keys=True)
        target.write("\n")


def package_json(version_path, architecture, output):
    with open(version_path, encoding="utf-8") as source:
        identity = json.load(source)
    identity["architecture"] = architecture
    with open(output, "w", encoding="utf-8") as target:
        json.dump(identity, target, indent=2, sort_keys=True)
        target.write("\n")


def is_notice_path(relative):
    prefixes = (
        "license",
        "licence",
        "copying",
        "notice",
        "copyright",
        "authors",
    )
    return any(
        part.lower().startswith(prefixes)
        for part in relative.replace(os.sep, "/").split("/")
    )


def project_licenses(repo, destination):
    for name in ("LICENSE", "THIRD_PARTY.md"):
        copy(os.path.join(repo, name), os.path.join(destination, name))
    for path in walk(os.path.join(repo, "LICENSES")):
        copy(path, os.path.join(destination, os.path.relpath(path, repo)))
    for name in UPSTREAM_NOTICES:
        copy(
            os.path.join(repo, name),
            os.path.join(destination, "upstream", name),
        )


def rust_licenses(repo, destination):
    metadata = json.loads(
        subprocess.run(
            ["cargo", "metadata", "--locked", "--format-version", "1"],
            cwd=repo,
            check=True,
            capture_output=True,
        ).stdout
    )
    workspace = set(metadata["workspace_members"])
    supplements = os.path.join(repo, "packaging", "licenses", "cargo")
    inventory = []
    for package in metadata["packages"]:
        if package["id"] in workspace:
            continue
        name, version = package["name"], package["version"]
        directory = f"{name}-{version}"
        root = os.path.dirname(package["manifest_path"])
        notices = {
            os.path.relpath(path, root)
            for path in walk(root)
            if is_notice_path(os.path.relpath(path, root))
        }
        if package.get("license_file"):
            notices.add(package["license_file"])
        supplement = os.path.join(supplements, directory)
        supplemental = walk(supplement) if os.path.isdir(supplement) else []
        if not notices and not supplemental:
            die(f"no upstream license text for Cargo dependency {directory}")
        for relative in sorted(notices):
            copy(
                os.path.join(root, relative),
                os.path.join(destination, directory, relative),
            )
        for path in supplemental:
            relative = os.path.join(
                "supplemental", os.path.relpath(path, supplement)
            )
            copy(path, os.path.join(destination, directory, relative))
            notices.add(relative)
        inventory.append(
            {
                "name": name,
                "version": version,
                "license": package.get("license"),
                "source": package.get("source"),
                "repository": package.get("repository"),
                "directory": directory,
                "notices": sorted(notices),
            }
        )
    inventory.sort(key=lambda entry: (entry["name"], entry["version"]))
    with open(os.path.join(destination, "index.json"), "w", encoding="utf-8") as index:
        json.dump(inventory, index, indent=2, sort_keys=True)
        index.write("\n")


def licenses(repo, destination):
    project_licenses(repo, destination)
    rust_licenses(repo, os.path.join(destination, "rust"))


def paragraphs(path):
    with open(path, encoding="utf-8") as source:
        text = source.read()
    return [block for block in text.split("\n\n") if block.strip()]


def control(template, package, version, architecture, mode, base_version, output):
    """Emit one binary package's control paragraph.

    ``mode`` is ``payload`` when the matching image and base packages are built
    beside this one, and ``source`` when only the runtime tree exists: the
    Android image dependency then becomes a recommendation, because the images
    come from a separate payload build rather than from this checkout.
    """
    stanza = None
    source = None
    for block in paragraphs(template):
        first = block.splitlines()[0].strip()
        if first.startswith("Source:"):
            source = block
        elif first == f"Package: {package}":
            stanza = block
    if stanza is None or source is None:
        die(f"{template} has no Source or Package: {package} paragraph")
    maintainer = next(
        (line for line in source.splitlines() if line.startswith("Maintainer:")),
        "Maintainer: Droidloom packaging <packaging@droidloom.invalid>",
    )
    lines = []
    for line in stanza.splitlines():
        if line.startswith("Depends:"):
            if mode == "source":
                line = line.replace("droidloom-image (= @VERSION@), ", "")
                line = line.replace(", droidloom-image (= @VERSION@)", "")
                if line.strip() == "Depends:":
                    continue
        if line.startswith("Recommends: @IMAGE_RECOMMENDS@"):
            if mode == "payload":
                continue
            line = f"Recommends: droidloom-image (= {version})"
        lines.append(
            line.replace("@ARCH@", architecture)
            .replace("@BASE_VERSION@", base_version)
            .replace("@VERSION@", version)
        )
    if not any(line.startswith("Maintainer:") for line in lines):
        lines.append(maintainer)
    with open(output, "w", encoding="utf-8") as target:
        target.write("\n".join(lines).rstrip("\n") + "\n")


DEPENDENCY = re.compile(
    r"^(?P<name>[^\s:()]+)(?::[a-z0-9]+)?"
    r"(?:\s*\(\s*(?P<operator>[<>=]+)\s*(?P<version>[^)\s]+)\s*\))?$"
)


def installed_version(package):
    """The installed version of a package, or None when it is not installed."""
    query = subprocess.run(
        ["dpkg-query", "-W", "-f", "${Status}|${Version}", package],
        capture_output=True,
        text=True,
    )
    if query.returncode != 0:
        return None
    status, _, version = query.stdout.partition("|")
    return version if "installed" in status.split() else None


def version_satisfies(have, operator, want):
    if not operator:
        return True
    return (
        subprocess.run(
            ["dpkg", "--compare-versions", have, operator, want],
            capture_output=True,
        ).returncode
        == 0
    )


def depends(control):
    """Report the Depends groups no installed package satisfies.

    ``dpkg -i --dry-run`` stops at "unpack": it never evaluates dependencies,
    so the acceptance check needs this instead of trusting its exit status.
    """
    unmet = []
    with open(control, encoding="utf-8") as source:
        for line in source:
            if not line.lower().startswith("depends:"):
                continue
            for group in line.split(":", 1)[1].split(","):
                satisfied = False
                for alternative in (part.strip() for part in group.split("|")):
                    match = DEPENDENCY.match(alternative)
                    if match is None:
                        die(f"cannot read dependency: {alternative!r}")
                    have = installed_version(match["name"])
                    if have and version_satisfies(
                        have, match["operator"], match["version"]
                    ):
                        satisfied = True
                        break
                if not satisfied:
                    unmet.append(group.strip())
    if unmet:
        for group in unmet:
            print(f"unmet dependency: {group}", file=sys.stderr)
        raise SystemExit(1)
    print("dependencies satisfied")


def main(argv):
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        raise SystemExit(2)
    command, arguments = argv[1], argv[2:]
    if command == "cell-template" and len(arguments) == 2:
        cell_template(*arguments)
    elif command == "package-json" and len(arguments) == 3:
        package_json(*arguments)
    elif command == "licenses" and len(arguments) == 2:
        licenses(*arguments)
    elif command == "control" and len(arguments) == 7:
        control(*arguments)
    elif command == "depends" and len(arguments) == 1:
        depends(*arguments)
    else:
        print(__doc__, file=sys.stderr)
        raise SystemExit(2)


if __name__ == "__main__":
    main(sys.argv)
