#!/usr/bin/env python3
"""Hand-edit ios/ so the Runner project has dev / staging / prod flavors (Bible §5.1).

Written because the authoring sandbox has no macOS/Xcode. NEVER RUN ON A MAC-EDITED PROJECT WITHOUT
`git diff`: it rewrites ios/Runner.xcodeproj/project.pbxproj. It is idempotent (exits if the flavor
configurations already exist). What it does:

* Adds 9 build configurations per target level (Debug|Release|Profile x dev|staging|prod), named the way
  Flutter expects (`Debug-dev` ... ), by cloning the existing Debug/Release/Profile ones.
* Adds ios/Flutter/<Config>-<flavor>.xcconfig + ios/Flutter/<flavor>.xcconfig (bundle id, display name,
  app-icon set) and drops the hard-coded PRODUCT_BUNDLE_IDENTIFIER / app-icon name from the cloned Runner
  target configurations so the xcconfig wins (target settings outrank xcconfig values).
* Writes shared schemes dev / staging / prod.
* Info.plist: display name comes from $(APP_DISPLAY_NAME); Info-dev.plist (dev only) additionally allows
  cleartext HTTP to local-network hosts (dev API on the Mac / LAN).

Mirrors apps/mobile/android/app/build.gradle.kts (applicationIdSuffix .dev/.staging, names MC Dev /
MC Staging / Marriage Connect).
"""

import re
import sys
from pathlib import Path

IOS = Path(__file__).resolve().parent.parent / "ios"
PBX = IOS / "Runner.xcodeproj" / "project.pbxproj"
SCHEMES = IOS / "Runner.xcodeproj" / "xcshareddata" / "xcschemes"
BASE_BUNDLE = "ug.marriageconnect.app"
FLAVORS = {
    "dev": (".dev", "MC Dev"),
    "staging": (".staging", "MC Staging"),
    "prod": ("", "Marriage Connect"),
}
MODES = ["Debug", "Release", "Profile"]
# Original configuration ids (stock Flutter template).
PROJECT = {"Debug": "97C147031CF9000F007C117D", "Release": "97C147041CF9000F007C117D", "Profile": "249021D3217E4FDB00AE95B9"}
RUNNER = {"Debug": "97C147061CF9000F007C117D", "Release": "97C147071CF9000F007C117D", "Profile": "249021D4217E4FDB00AE95B9"}
TESTS = {"Debug": "331C8088294A63A400263BE5", "Release": "331C8089294A63A400263BE5", "Profile": "331C808A294A63A400263BE5"}
LISTS = {  # XCConfigurationList id -> level
    "97C146E91CF9000F007C117D": ("project", PROJECT),
    "97C147051CF9000F007C117D": ("runner", RUNNER),
    "331C8087294A63A400263BE5": ("tests", TESTS),
}
DEBUG_REF = "9740EEB21CF90195004384FC"  # Flutter/Debug.xcconfig
RELEASE_REF = "7AFA3C8E1D35360C0083082E"  # Flutter/Release.xcconfig
FLUTTER_GROUP_ANCHOR = "9740EEB31CF90195004384FC /* Generated.xcconfig */,"


def new_id(tag: str) -> str:
    """Stable, collision-free 24-hex id: 'FA' + 22 hex digits from the tag."""
    import hashlib

    return "FA" + hashlib.sha1(tag.encode()).hexdigest()[:22].upper()


def block(text: str, ident: str) -> str:
    m = re.search(rf"\t\t{ident} /\* \w+ \*/ = \{{\n.*?\n\t\t\}};\n", text, re.S)
    if not m:
        raise SystemExit(f"configuration {ident} not found")
    return m.group(0)


def main() -> None:
    text = PBX.read_text()
    if "Debug-dev" in text:
        print("flavors already present; nothing to do")
        return

    # 1. stock configs: unify the bundle id with Android and give them an explicit display name.
    text = text.replace(
        "PRODUCT_BUNDLE_IDENTIFIER = ug.marriageconnect.marriageConnect.RunnerTests;",
        f"PRODUCT_BUNDLE_IDENTIFIER = {BASE_BUNDLE}.RunnerTests;",
    )
    text = text.replace(
        "PRODUCT_BUNDLE_IDENTIFIER = ug.marriageconnect.marriageConnect;",
        f'APP_DISPLAY_NAME = "Marriage Connect";\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BASE_BUNDLE};',
    )

    new_blocks: list[str] = []
    list_additions: dict[str, list[str]] = {k: [] for k in LISTS}
    file_refs: list[str] = []
    group_children: list[str] = []

    for flavor, (suffix, _name) in FLAVORS.items():
        for mode in MODES:
            cfg = f"{mode}-{flavor}"
            # xcconfig file reference (Runner target only)
            ref = new_id(f"xcconfig:{cfg}")
            file_refs.append(
                f'\t\t{ref} /* {cfg}.xcconfig */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
                f'name = "{cfg}.xcconfig"; path = "Flutter/{cfg}.xcconfig"; sourceTree = "<group>"; }};\n'
            )
            group_children.append(f"{ref} /* {cfg}.xcconfig */,")
            for list_id, (level, originals) in LISTS.items():
                src = block(text, originals[mode])
                ident = new_id(f"{level}:{cfg}")
                b = src.replace(originals[mode], ident, 1)
                b = re.sub(r"/\* \w+ \*/ = \{", f"/* {cfg} */ = {{", b, count=1)
                b = re.sub(r"name = \w+;", f"name = {cfg};", b)
                if level == "runner":
                    b = re.sub(
                        r"baseConfigurationReference = \w+ /\* [\w.]+ \*/;",
                        f"baseConfigurationReference = {ref} /* {cfg}.xcconfig */;",
                        b,
                    )
                    b = re.sub(r"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = [^;]+;\n", "", b)
                    b = re.sub(r"\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = [^;]+;\n", "", b)
                    b = re.sub(r"\t\t\t\tAPP_DISPLAY_NAME = [^;]+;\n", "", b)
                    if flavor == "dev":
                        b = b.replace(
                            "INFOPLIST_FILE = Runner/Info.plist;", "INFOPLIST_FILE = Runner/Info-dev.plist;"
                        )
                if level == "tests":
                    b = re.sub(
                        r"PRODUCT_BUNDLE_IDENTIFIER = [^;]+;",
                        f"PRODUCT_BUNDLE_IDENTIFIER = {BASE_BUNDLE}{suffix}.RunnerTests;",
                        b,
                    )
                new_blocks.append(b)
                list_additions[list_id].append(f"\t\t\t\t{ident} /* {cfg} */,\n")

            include = "Release.xcconfig" if mode == "Profile" else f"{mode}.xcconfig"
            (IOS / "Flutter" / f"{cfg}.xcconfig").write_text(
                f'// {cfg}: stock Flutter {mode} settings + the {flavor} flavor. Generated by tool/ios_add_flavors.py.\n'
                f'#include "{include}"\n#include "{flavor}.xcconfig"\n'
            )
        suffix_id = f"{BASE_BUNDLE}{suffix}"
        (IOS / "Flutter" / f"{flavor}.xcconfig").write_text(
            f"// Flavor `{flavor}` (mirrors android/app/build.gradle.kts).\n"
            f"PRODUCT_BUNDLE_IDENTIFIER = {suffix_id}\n"
            f"APP_DISPLAY_NAME = {_name}\n"
            f"ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-{flavor}\n"
        )

    text = text.replace(
        "/* End XCBuildConfiguration section */", "".join(new_blocks) + "/* End XCBuildConfiguration section */"
    )
    text = text.replace(
        "/* End PBXFileReference section */", "".join(file_refs) + "/* End PBXFileReference section */"
    )
    text = text.replace(
        FLUTTER_GROUP_ANCHOR,
        FLUTTER_GROUP_ANCHOR + "".join("\n\t\t\t\t" + c for c in group_children),
    )
    for list_id, lines in list_additions.items():
        m = re.search(rf"\t\t{list_id} /\* [^*]+\*/ = \{{.*?buildConfigurations = \(\n(.*?)\t\t\t\);", text, re.S)
        if not m:
            raise SystemExit(f"config list {list_id} not found")
        text = text[: m.end(1)] + "".join(lines) + text[m.end(1) :]
    PBX.write_text(text)

    # 2. Info.plist display name + dev-only ATS exception.
    plist = (IOS / "Runner" / "Info.plist").read_text()
    plist = plist.replace(
        "<key>CFBundleDisplayName</key>\n\t<string>Marriage Connect</string>",
        "<key>CFBundleDisplayName</key>\n\t<string>$(APP_DISPLAY_NAME)</string>",
    )
    (IOS / "Runner" / "Info.plist").write_text(plist)
    ats = (
        "\t<key>NSAppTransportSecurity</key>\n\t<dict>\n"
        "\t\t<key>NSAllowsLocalNetworking</key>\n\t\t<true/>\n\t</dict>\n"
    )
    (IOS / "Runner" / "Info-dev.plist").write_text(plist.replace("</dict>\n</plist>", ats + "</dict>\n</plist>"))

    # 3. Shared schemes: clone Runner.xcscheme, pointing every action at <mode>-<flavor>.
    base = (SCHEMES / "Runner.xcscheme").read_text()
    for flavor in FLAVORS:
        s = base
        s = re.sub(r'buildConfiguration = "Debug"', f'buildConfiguration = "Debug-{flavor}"', s)
        s = re.sub(r'buildConfiguration = "Release"', f'buildConfiguration = "Release-{flavor}"', s)
        s = re.sub(r'buildConfiguration = "Profile"', f'buildConfiguration = "Profile-{flavor}"', s)
        (SCHEMES / f"{flavor}.xcscheme").write_text(s)
    print("done: review `git diff apps/mobile/ios` and verify on a Mac (see README)")


if __name__ == "__main__":
    sys.exit(main())
