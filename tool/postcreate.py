#!/usr/bin/env python3
"""Ajustes idempotentes después de `flutter create` (se ejecuta en CI).

Las carpetas android/ e ios/ no se versionan: se generan en CI con la
plantilla de la versión de Flutter fijada y luego se parchean aquí.
Válido para Gradle Groovy (build.gradle) o Kotlin DSL (build.gradle.kts).

1. Nombre visible «Monte Carlo» en Android e iOS.
2. Permiso INTERNET en el manifiesto principal (la IA opcional del analista
   lo necesita en release; sin él la app sigue funcionando offline).
3. Firma de producción si existen las variables ANDROID_KEYSTORE_BASE64,
   ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS y ANDROID_KEY_PASSWORD
   (secretos del repositorio). Si no, queda la firma de depuración.
"""
import base64
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LABEL = "Monte Carlo"


def patch_manifest():
    p = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if not p.exists():
        print("· sin AndroidManifest.xml (¿se ejecutó flutter create?)")
        return
    s = p.read_text(encoding="utf-8")
    s = re.sub(r'android:label="[^"]*"', f'android:label="{LABEL}"', s, count=1)
    if "android.permission.INTERNET" not in s:
        s = s.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
    p.write_text(s, encoding="utf-8")
    print("✓ manifiesto: etiqueta e INTERNET")


def patch_ios():
    p = ROOT / "ios" / "Runner" / "Info.plist"
    if not p.exists():
        return
    s = p.read_text(encoding="utf-8")
    s = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)", rf"\g<1>{LABEL}\g<2>", s)
    p.write_text(s, encoding="utf-8")
    print("✓ iOS: nombre visible")


def configure_signing():
    need = ["ANDROID_KEYSTORE_BASE64", "ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD"]
    if not all(os.environ.get(k) for k in need):
        print("· sin secretos de firma: el APK usa la firma de depuración")
        return
    app = ROOT / "android" / "app"
    (app / "upload-keystore.jks").write_bytes(base64.b64decode(os.environ["ANDROID_KEYSTORE_BASE64"]))
    (ROOT / "android" / "key.properties").write_text(
        "storePassword={}\nkeyPassword={}\nkeyAlias={}\nstoreFile=upload-keystore.jks\n".format(
            os.environ["ANDROID_KEYSTORE_PASSWORD"], os.environ["ANDROID_KEY_PASSWORD"], os.environ["ANDROID_KEY_ALIAS"]
        ),
        encoding="utf-8",
    )
    kts = app / "build.gradle.kts"
    groovy = app / "build.gradle"
    if kts.exists():
        s = kts.read_text(encoding="utf-8")
        if "keystoreProperties" not in s:
            # Los imports van arriba; las declaraciones, después del bloque
            # plugins {} (Gradle exige que plugins sea lo primero).
            s = "import java.util.Properties\nimport java.io.FileInputStream\n\n" + s
            props = (
                'val keystoreProperties = Properties()\nval keystorePropertiesFile = rootProject.file("key.properties")\n'
                "if (keystorePropertiesFile.exists()) { keystoreProperties.load(FileInputStream(keystorePropertiesFile)) }\n\n"
            )
            s = s.replace("\nandroid {", "\n" + props + "android {", 1)
            s = s.replace(
                "    buildTypes {",
                "    signingConfigs {\n        create(\"release\") {\n"
                "            keyAlias = keystoreProperties[\"keyAlias\"] as String\n"
                "            keyPassword = keystoreProperties[\"keyPassword\"] as String\n"
                "            storeFile = file(keystoreProperties[\"storeFile\"] as String)\n"
                "            storePassword = keystoreProperties[\"storePassword\"] as String\n"
                "        }\n    }\n\n    buildTypes {",
                1,
            )
            s = s.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')
            kts.write_text(s, encoding="utf-8")
    elif groovy.exists():
        s = groovy.read_text(encoding="utf-8")
        if "keystoreProperties" not in s:
            props = (
                "def keystoreProperties = new Properties()\n"
                "def keystorePropertiesFile = rootProject.file('key.properties')\n"
                "if (keystorePropertiesFile.exists()) { keystoreProperties.load(new FileInputStream(keystorePropertiesFile)) }\n\n"
            )
            s = s.replace("\nandroid {", "\n" + props + "android {", 1)
            s = s.replace(
                "    buildTypes {",
                "    signingConfigs {\n        release {\n"
                "            keyAlias keystoreProperties['keyAlias']\n            keyPassword keystoreProperties['keyPassword']\n"
                "            storeFile file(keystoreProperties['storeFile'])\n            storePassword keystoreProperties['storePassword']\n"
                "        }\n    }\n\n    buildTypes {",
                1,
            )
            s = s.replace("signingConfig signingConfigs.debug", "signingConfig signingConfigs.release")
            groovy.write_text(s, encoding="utf-8")
    print("✓ firma de producción configurada")


if __name__ == "__main__":
    patch_manifest()
    patch_ios()
    configure_signing()
