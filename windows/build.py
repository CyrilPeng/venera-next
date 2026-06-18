import os
from pathlib import Path
import re
import shutil
import subprocess

import httpx


ROOT = Path.cwd()
WINDOWS_BUILD_DIR = ROOT / "build" / "windows"
WINDOWS_RELEASE_DIR = WINDOWS_BUILD_DIR / "x64" / "runner" / "Release"
ISS_PATH = ROOT / "windows" / "build.iss"
CHINESE_TRANSLATION_PATH = ROOT / "windows" / "ChineseSimplified.isl"
CHINESE_TRANSLATION_URL = (
    "https://cdn.jsdelivr.net/gh/kira-96/"
    "Inno-Setup-Chinese-Simplified-Translation@latest/ChineseSimplified.isl"
)


def run(command):
    executable = shutil.which(command[0])
    if executable is None:
        raise FileNotFoundError(command[0])
    subprocess.run([executable, *command[1:]], check=True)


def read_version():
    content = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([^\s]+)", content, re.MULTILINE)
    if match is None:
        raise RuntimeError("pubspec.yaml does not contain a version field")
    return match.group(1).split("+", 1)[0]


def require_non_empty_file(path):
    if not path.is_file():
        raise FileNotFoundError(path)
    if path.stat().st_size <= 0:
        raise RuntimeError(f"{path} is empty")


def create_portable_zip(version):
    if not WINDOWS_RELEASE_DIR.is_dir():
        raise FileNotFoundError(WINDOWS_RELEASE_DIR)

    zip_path = WINDOWS_BUILD_DIR / f"Venera-{version}-windows.zip"
    if zip_path.exists():
        zip_path.unlink()

    shutil.make_archive(str(zip_path.with_suffix("")), "zip", WINDOWS_RELEASE_DIR)
    require_non_empty_file(zip_path)
    return zip_path


def ensure_chinese_translation():
    if CHINESE_TRANSLATION_PATH.exists():
        return

    response = httpx.get(CHINESE_TRANSLATION_URL)
    response.raise_for_status()
    CHINESE_TRANSLATION_PATH.write_bytes(response.content)


def build_installer(version):
    iss_content = ISS_PATH.read_text(encoding="utf-8")
    rendered = iss_content.replace("{{version}}", version)
    rendered = rendered.replace("{{root_path}}", os.getcwd())
    installer_path = WINDOWS_BUILD_DIR / f"Venera-{version}-windows-installer.exe"

    try:
        ISS_PATH.write_text(rendered, encoding="utf-8")
        ensure_chinese_translation()
        run(["iscc", str(ISS_PATH)])
    finally:
        ISS_PATH.write_text(iss_content, encoding="utf-8")

    require_non_empty_file(installer_path)
    return installer_path


version = read_version()
run(["flutter", "build", "windows"])
create_portable_zip(version)
build_installer(version)
