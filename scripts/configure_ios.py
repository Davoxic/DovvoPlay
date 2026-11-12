#!/usr/bin/env python3
"""Configura Info.plist, Podfile e le icone dell'app iOS per DovvoPlay."""
import os
import plistlib
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

    plist["CFBundleDisplayName"] = "DovvoPlay"
    plist["CFBundleName"] = "DovvoPlay"

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
        "DovvoPlay usa la rete locale per ricevere musica dal tuo computer via Wi-Fi "
        "e per ascoltare insieme ad altri dispositivi sulla stessa rete."
    )

    # Il poster del Replay si condivide come immagine: senza questa voce,
    # scegliendo "Salva immagine" dal menu di condivisione iOS chiude l'app.
    plist["NSPhotoLibraryAddUsageDescription"] = (
        "DovvoPlay salva in Foto il poster del tuo Replay quando scegli di salvarlo."
    )

    # ATS per consentire stream audio HTTP locali / CDN
    ats = plist.get("NSAppTransportSecurity", {})
    ats["NSAllowsArbitraryLoads"] = True
    ats["NSAllowsLocalNetworking"] = True
    plist["NSAppTransportSecurity"] = ats

    with open(INFO_PLIST, "wb") as f:
        plistlib.dump(plist, f)
    print("Info.plist configurato con successo.")

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

    patch_snippet = """
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
    end"""

    if "flutter_additional_ios_build_settings(target)" in content and patch_snippet not in content:
        content = content.replace(
            "flutter_additional_ios_build_settings(target)",
            "flutter_additional_ios_build_settings(target)\n" + patch_snippet
        )

    PODFILE.write_text(content, encoding="utf-8")
    print("Podfile configurato con successo.")

def configure_icons():
    print("Configuro le icone dell'app...")
    icon_src = ROOT / "assets" / "AppIcon.png"
    appicon_dir = RUNNER_DIR / "Assets.xcassets" / "AppIcon.appiconset"
    if icon_src.exists():
        appicon_dir.mkdir(parents=True, exist_ok=True)
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
        print("Icona copiata e Contents.json aggiornato in:", dest)

if __name__ == "__main__":
    configure_info_plist()
    configure_podfile()
    configure_icons()
    print("Configurazione completata.")
