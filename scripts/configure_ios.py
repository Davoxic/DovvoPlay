#!/usr/bin/env python3
"""Configura Info.plist, Podfile, project.pbxproj e le icone dell'app iOS per SborraPlay."""
import os
import plistlib
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IOS_DIR = ROOT / "ios"
RUNNER_DIR = IOS_DIR / "Runner"
INFO_PLIST = RUNNER_DIR / "Info.plist"
PODFILE = IOS_DIR / "Podfile"

def configure_info_plist():
    print("Configuro Info.plist...")
    if not INFO_PLIST.exists():
        print(f"Info.plist non trovato in {INFO_PLIST}")
        return

    with open(INFO_PLIST, "rb") as f:
        plist = plistlib.load(f)

    plist["CFBundleDisplayName"] = "SborraPlay"
    plist["CFBundleName"] = "SborraPlay"

    # Background audio mode
    bg_modes = plist.get("UIBackgroundModes", [])
    if "audio" not in bg_modes:
        bg_modes.append("audio")
    plist["UIBackgroundModes"] = bg_modes

    # File sharing per l'app File e iTunes
    plist["UIFileSharingEnabled"] = True
    plist["LSSupportsOpeningDocumentsInPlace"] = True

    # Permessi rete locale per server Wi-Fi
    plist["NSLocalNetworkUsageDescription"] = (
        "SborraPlay usa la rete locale per consentire il caricamento di file musicali via Wi-Fi dal tuo computer."
    )

    # ATS per consentire stream audio HTTP locali / CDN
    ats = plist.get("NSAppTransportSecurity", {})
    ats["NSAllowsArbitraryLoads"] = True
    plist["NSAppTransportSecurity"] = ats

    with open(INFO_PLIST, "wb") as f:
        plistlib.dump(plist, f)
    print("Info.plist configurato con successo.")

def configure_project_pbxproj():
    print("Configuro project.pbxproj per disattivare firma...")
    pbxproj = IOS_DIR / "Runner.xcodeproj" / "project.pbxproj"
    if not pbxproj.exists():
        print("project.pbxproj non trovato")
        return
    text = pbxproj.read_text(encoding="utf-8")
    text = re.sub(r'CODE_SIGN_IDENTITY\s*=\s*"[^"]*";', 'CODE_SIGN_IDENTITY = "";', text)
    text = re.sub(r'CODE_SIGN_STYLE\s*=\s*Automatic;', 'CODE_SIGN_STYLE = Manual;', text)
    text = re.sub(r'DEVELOPMENT_TEAM\s*=\s*[^;]+;', 'DEVELOPMENT_TEAM = "";', text)
    text = text.replace(
        'PRODUCT_BUNDLE_IDENTIFIER = com.dchietti.sborraplay;',
        'PRODUCT_BUNDLE_IDENTIFIER = com.dchietti.sborraplay;\n\t\t\t\tCODE_SIGNING_ALLOWED = NO;\n\t\t\t\tCODE_SIGNING_REQUIRED = NO;'
    )
    pbxproj.write_text(text, encoding="utf-8")
    print("project.pbxproj configurato con successo.")

def configure_xcconfigs():
    print("Configuro .xcconfig per disattivare firma...")
    for name in ["Release.xcconfig", "Debug.xcconfig", "Profile.xcconfig"]:
        xc = IOS_DIR / "Flutter" / name
        if xc.exists():
            content = xc.read_text(encoding="utf-8")
            patch = "\nCODE_SIGNING_ALLOWED=NO\nCODE_SIGNING_REQUIRED=NO\nCODE_SIGN_IDENTITY=\nDEVELOPMENT_TEAM=\n"
            if "CODE_SIGNING_ALLOWED=NO" not in content:
                content += patch
                xc.write_text(content, encoding="utf-8")
    print(".xcconfig configurati con successo.")

def configure_podfile():
    print("Configuro Podfile...")
    if not PODFILE.exists():
        print("Podfile non ancora generato.")
        return

    content = PODFILE.read_text(encoding="utf-8")

    # Assicura platform :ios, '14.0'
    lines = []
    for line in content.splitlines():
        if line.strip().startswith("# platform :ios") or line.strip().startswith("platform :ios"):
            lines.append("platform :ios, '14.0'")
        else:
            lines.append(line)
    content = "\n".join(lines)
    if "platform :ios" not in content:
        content = "platform :ios, '14.0'\n" + content

    target_block = """
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
        config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
        config.build_settings['CODE_SIGN_IDENTITY'] = ''
      end"""

    if "flutter_additional_ios_build_settings(target)" in content:
        content = content.replace(
            "flutter_additional_ios_build_settings(target)",
            "flutter_additional_ios_build_settings(target)\n" + target_block
        )
    elif "post_install do |installer|" in content:
        content = content.replace(
            "post_install do |installer|",
            "post_install do |installer|\n  installer.pods_project.targets.each do |target|\n" + target_block + "\n  end"
        )
    else:
        content += f"""
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
{target_block}
  end
end
"""

    PODFILE.write_text(content, encoding="utf-8")
    print("Podfile configurato con successo.")

def configure_icons():
    print("Configuro le icone dell'app...")
    icon_src = ROOT / "assets" / "AppIcon.png"
    appicon_dir = RUNNER_DIR / "Assets.xcassets" / "AppIcon.appiconset"
    if icon_src.exists() and appicon_dir.exists():
        dest = appicon_dir / "AppIcon.png"
        shutil.copy2(icon_src, dest)

        contents_json = """{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
        (appicon_dir / "Contents.json").write_text(contents_json, encoding="utf-8")
        print("Icona copiata e Contents.json aggiornato.")

if __name__ == "__main__":
    configure_info_plist()
    configure_project_pbxproj()
    configure_xcconfigs()
    configure_podfile()
    configure_icons()
    print("Configurazione completata.")
