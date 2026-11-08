#!/usr/bin/env python3
"""Configure the generated Flutter Android project for permanent release signing."""
from __future__ import annotations

import base64
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"
APP = ANDROID / "app"

required = [
    "ANDROID_KEYSTORE_BASE64",
    "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "ANDROID_KEY_PASSWORD",
]
missing = [name for name in required if not os.environ.get(name)]
if missing:
    raise SystemExit("Missing permanent Android signing secrets: " + ", ".join(missing))

raw_base64 = os.environ["ANDROID_KEYSTORE_BASE64"]
compact_base64 = "".join(raw_base64.split())
try:
    keystore_bytes = base64.b64decode(compact_base64, validate=True)
except Exception as exc:
    raise SystemExit(
        "ANDROID_KEYSTORE_BASE64 is invalid. Replace that GitHub secret with the single-line value from paper-plane-ANDROID_KEYSTORE_BASE64.txt."
    ) from exc
if not keystore_bytes:
    raise SystemExit("Decoded Android keystore is empty.")

APP.mkdir(parents=True, exist_ok=True)
keystore_path = APP / "upload-keystore.jks"
keystore_path.write_bytes(keystore_bytes)

key_alias = os.environ["ANDROID_KEY_ALIAS"]
store_password = os.environ["ANDROID_KEYSTORE_PASSWORD"]
key_password = os.environ["ANDROID_KEY_PASSWORD"]
verification = subprocess.run(
    [
        "keytool", "-list", "-v", "-keystore", str(keystore_path),
        "-storepass", store_password,
    ],
    check=False,
    capture_output=True,
    text=True,
)
if verification.returncode != 0:
    raise SystemExit("The keystore cannot be opened. Check ANDROID_KEYSTORE_PASSWORD.")
key_password_check = subprocess.run(
    [
        "keytool", "-certreq", "-alias", key_alias, "-keystore", str(keystore_path),
        "-storepass", store_password, "-keypass", key_password,
        "-file", str(APP / ".paper-plane-key-check.csr"),
    ],
    check=False,
    capture_output=True,
    text=True,
)
(APP / ".paper-plane-key-check.csr").unlink(missing_ok=True)
if key_password_check.returncode != 0:
    raise SystemExit("ANDROID_KEY_PASSWORD does not unlock the private key for the selected alias.")

certificate = verification.stdout
if f"Alias name: {key_alias}" not in certificate:
    raise SystemExit("ANDROID_KEY_ALIAS does not match the uploaded keystore.")

def normalized_fingerprint(label: str) -> str:
    match = re.search(rf"(?m)^\s*{label}:\s*([0-9A-Fa-f:]+)\s*$", certificate)
    return match.group(1).replace(":", "").lower() if match else ""

sha1 = normalized_fingerprint("SHA1")
sha256 = normalized_fingerprint("SHA256")
expected_sha1 = "f45f3c66211a38235934dfc80716a2e12d4b3a7f"
expected_sha256 = "6e9b240e193b53e192fb3c11d406ece477ece8ca501593072105a6397479106b"
if sha1 != expected_sha1 or sha256 != expected_sha256:
    raise SystemExit("The selected keystore does not match the permanent Paper Plane SHA-1/SHA-256 certificate.")

properties = {
    "storePassword": store_password,
    "keyPassword": key_password,
    "keyAlias": key_alias,
    "storeFile": "upload-keystore.jks",
}
(ANDROID / "key.properties").write_text(
    "".join(f"{key}={value}\n" for key, value in properties.items()),
    encoding="utf-8",
)

candidates = [APP / "build.gradle.kts", APP / "build.gradle"]
gradle = next((path for path in candidates if path.exists()), None)
if gradle is None:
    raise SystemExit("Flutter generated neither build.gradle.kts nor build.gradle in android/app.")
text = gradle.read_text(encoding="utf-8")
kotlin = gradle.suffix == ".kts"


def locate_block(source: str, pattern: str, start: int = 0) -> tuple[int, int]:
    match = re.search(pattern, source[start:])
    if match is None:
        raise SystemExit(f"Cannot locate Gradle block matching {pattern!r} in {gradle}.")
    opening = start + match.end() - 1
    depth = 0
    quote: str | None = None
    escaped = False
    line_comment = False
    block_comment = False
    i = opening
    while i < len(source):
        ch = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""
        if line_comment:
            if ch == "\n":
                line_comment = False
        elif block_comment:
            if ch == "*" and nxt == "/":
                block_comment = False
                i += 1
        elif quote:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
        elif ch == "/" and nxt == "/":
            line_comment = True
            i += 1
        elif ch == "/" and nxt == "*":
            block_comment = True
            i += 1
        elif ch in ("'", '\"'):
            quote = ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return opening, i
        i += 1
    raise SystemExit(f"Unclosed Gradle block matching {pattern!r} in {gradle}.")


locate = r"(?m)^android\s*\{"
android_open, _ = locate_block(text, locate)
if "keystoreProperties" not in text:
    if kotlin and "import java.util.Properties" not in text:
        text = "import java.util.Properties\n\n" + text
    prefix = (
        'val keystoreProperties = Properties()\n'
        'val keystorePropertiesFile = rootProject.file("key.properties")\n'
        'if (keystorePropertiesFile.exists()) {\n'
        '    keystoreProperties.load(keystorePropertiesFile.inputStream())\n'
        '}\n\n'
        if kotlin else
        'def keystoreProperties = new Properties()\n'
        'def keystorePropertiesFile = rootProject.file("key.properties")\n'
        'if (keystorePropertiesFile.exists()) {\n'
        '    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n'
        '}\n\n'
    )
    if not kotlin and "import java.util.Properties" not in text:
        text = "import java.util.Properties\nimport java.io.FileInputStream\n\n" + text
    android_statement_start = re.search(locate, text).start()
    text = text[:android_statement_start] + prefix + text[android_statement_start:]

if kotlin and '@Suppress("DEPRECATION")\\nandroid {' not in text:
    text = re.sub(r"(?m)^android\\s*\\{", '@Suppress("DEPRECATION")\\nandroid {', text, count=1)

signing_config = (
    '\n    signingConfigs {\n'
    '        create("release") {\n'
    '            keyAlias = keystoreProperties["keyAlias"] as String\n'
    '            keyPassword = keystoreProperties["keyPassword"] as String\n'
    '            storeFile = file(keystoreProperties["storeFile"] as String)\n'
    '            storePassword = keystoreProperties["storePassword"] as String\n'
    '        }\n'
    '    }\n'
    if kotlin else
    '\n    signingConfigs {\n'
    '        release {\n'
    '            keyAlias keystoreProperties["keyAlias"]\n'
    '            keyPassword keystoreProperties["keyPassword"]\n'
    '            storeFile file(keystoreProperties["storeFile"])\n'
    '            storePassword keystoreProperties["storePassword"]\n'
    '        }\n'
    '    }\n'
)

android_open, android_close = locate_block(text, locate)
if not re.search(r"\bsigningConfigs\s*\{", text[android_open + 1:android_close]):
    text = text[:android_open + 1] + signing_config + text[android_open + 1:]

android_open, _ = locate_block(text, locate)
build_open, _ = locate_block(text, r"buildTypes\s*\{", android_open)
release_open, release_close = locate_block(text, r"release\s*\{", build_open)
release_body = text[release_open + 1:release_close]
indent_match = re.search(r"(?m)^(\s*)\S", release_body)
inner_indent = indent_match.group(1) if indent_match else "            "
if kotlin:
    desired = inner_indent + 'signingConfig = signingConfigs.getByName("release")'
    signing_line = re.compile(r"(?m)^\s*signingConfig\s*=.*$")
else:
    desired = inner_indent + "signingConfig signingConfigs.release"
    signing_line = re.compile(r"(?m)^\s*signingConfig\s+.*$")

if signing_line.search(release_body):
    release_body = signing_line.sub(desired, release_body, count=1)
else:
    release_body = "\n" + desired + release_body
text = text[:release_open + 1] + release_body + text[release_close:]
gradle.write_text(text, encoding="utf-8")
print(f"Configured permanent Android release signing in {gradle}.")
