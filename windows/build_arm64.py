import platform
import subprocess
import os
import shutil
import httpx

file = open('pubspec.yaml', 'r')
content = file.read()
file.close()

subprocess.run(["flutter", "build", "windows"], shell=True)

if os.path.exists("build/app-windows.zip"):
    os.remove("build/app-windows.zip")

version = str.split(str.split(content, 'version: ')[1], '+')[0]

release_dir = "build/windows/x64/runner/Release"
package_name = f"VeneraNext-{version}-windows-arm64"
package_dir = f"build/windows/{package_name}"
zip_path = f"build/windows/{package_name}.zip"

if os.path.exists(zip_path):
    os.remove(zip_path)
if os.path.exists(package_dir):
    shutil.rmtree(package_dir)

shutil.copytree(release_dir, package_dir)
subprocess.run(["tar", "-a", "-c", "-f", zip_path, "-C", "build/windows", package_name], shell=True)
shutil.rmtree(package_dir)

issPath = "windows/build_arm64.iss"

issContent = ""
file = open(issPath, 'r')
issContent = file.read()
newContent = issContent
newContent = newContent.replace("{{version}}", version)
newContent = newContent.replace("{{root_path}}", os.getcwd())
file.close()
file = open(issPath, 'w')
file.write(newContent)
file.close()

if not os.path.exists("windows/ChineseSimplified.isl"):
    # download ChineseSimplified.isl
    url = "https://cdn.jsdelivr.net/gh/kira-96/Inno-Setup-Chinese-Simplified-Translation@latest/ChineseSimplified.isl"
    response = httpx.get(url)
    with open('windows/ChineseSimplified.isl', 'wb') as file:
        file.write(response.content)

subprocess.run(["iscc", issPath], shell=True)

with open(issPath, 'w') as file:
    file.write(issContent)
