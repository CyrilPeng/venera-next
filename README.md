<div align="center">

# Venera Next

**一个更偏个人口味的跨平台漫画阅读器 Fork。**

本项目分叉自 [venera-app/venera](https://github.com/venera-app/venera)。原项目作者已将仓库归档并停止维护；感谢原作者长期投入与开源贡献。

![Flutter](https://img.shields.io/badge/Flutter-3.41.4-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.8+-0175C2?logo=dart&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20Linux%20%7C%20macOS-7C3AED)
![License](https://img.shields.io/badge/License-GPL--3.0-10B981)

</div>

---

## 写在前面

`Venera Next` 是我基于原版 Venera 开启的个人维护分支。

这个 fork 后续会继续更新，但更新方向主要服务于**我自己的阅读习惯、审美偏好和使用场景**。因此：

- 不保证所有功能都会与原版保持一致；
- 不保证每个需求都会被接受或实现；
- 不保证发布节奏稳定；
- 不保证适合所有用户；
- 欢迎参考、fork、提 issue 或 PR，但维护取舍会比较主观。

如果你喜欢原版的设计理念，请优先感谢和尊重原项目：

> 原项目：[https://github.com/venera-app/venera](https://github.com/venera-app/venera)
> 当前状态：原作者已归档仓库，不再维护。

---

## 项目定位

Venera Next 是一个使用 Flutter 构建的跨平台漫画阅读器，支持本地漫画和网络漫画源。

它的核心目标是：

- **本地阅读舒服**：导入、管理、阅读本地漫画；
- **网络源灵活**：通过 JavaScript 编写和扩展漫画源；
- **跨端体验统一**：移动端和桌面端共用一套阅读体验；
- **阅读流更顺滑**：持续优化阅读器、预加载、缓存和交互体验；
- **个人化演进**：加入我认为更自然、更高效的阅读方式。

---

## 亮点功能

### 阅读体验

- 画廊模式：适合传统分页阅读；
- 连续模式：适合当前章节内纵向连续阅读；
- 瀑布流模式：跨章节连续阅读，接近章节末尾时自动加载后续章节；
- 图片预加载：减少翻页或跨章等待；
- 阅读历史：自动记录阅读章节与页码；
- 多图阅读：支持横屏/竖屏下不同图片布局策略。

### 漫画来源

- 本地漫画阅读；
- 网络漫画源阅读；
- JavaScript 漫画源扩展；
- 搜索、分类、排行、探索页；
- 支持源能力扩展：登录、收藏、评论、评分、标签等。

### 管理能力

- 收藏管理；
- 阅读历史；
- 下载漫画；
- 图片收藏；
- 本地漫画库；
- WebDAV 数据同步。

### 跨平台

支持 Flutter 覆盖的主流平台：

- Android
- iOS
- Windows
- Linux
- macOS

---

## Venera Next 的新增方向

当前 fork 已开始进行个人化改造：

### v1.1.0

- 新增 **瀑布流阅读模式**；
- 复用现有“预加载图片数量”设计；
- 支持跨章节预加载；
- 支持跨章节连续阅读；
- 阅读进度会跟随当前可见图片同步到对应章节。

完整版本记录见 [CHANGELOG.md](CHANGELOG.md)。

---

## 构建项目

### 环境要求

- Flutter `3.41.4`，尽量不要使用更高小版本混用构建发行包；
- Dart `>=3.8.0 <4.0.0`；
- JDK `17`，Android release 构建建议不要使用 JDK 21；
- Rust 工具链，并安装 Android 目标：`aarch64-linux-android`、`armv7-linux-androideabi`、`x86_64-linux-android`；
- 对应平台构建环境，例如 Android SDK / NDK、Xcode、Visual Studio、Linux GTK/WebKit 依赖等。

### 重要：不要随意升级依赖

构建发行包时应尽量复用仓库中的 `pubspec.lock`。

本项目的网络层依赖 `rhttp 0.15.1`，其生成代码依赖 `flutter_rust_bridge 2.11.1`。如果 `flutter pub get` 重新解算并把 `flutter_rust_bridge` 升级到 `2.12.0`，可能出现运行时错误：

```text
flutter_rust_bridge has not been initialized
```

该错误会导致 App 内所有基于 `rhttp` 的网络请求失败，包括漫画源和 WebDAV。

构建前请确认：

```powershell
Select-String pubspec.lock -Pattern "flutter_rust_bridge" -Context 0,6
```

应看到：

```text
version: "2.11.1"
```

如果不是，请先恢复锁文件：

```powershell
git checkout -- pubspec.lock
```

### 获取依赖

推荐使用锁文件模式，确保依赖不漂移：

```powershell
flutter pub get --enforce-lockfile
```

如果使用镜像源导致 `--enforce-lockfile` 失败，建议改用 `pub.dev` 加代理，而不是让 `pub get` 自动重解依赖：

```powershell
$env:PUB_HOSTED_URL="https://pub.dev"
$env:http_proxy="http://127.0.0.1:7897"
$env:https_proxy="http://127.0.0.1:7897"
$env:no_proxy="localhost,127.0.0.1"
flutter pub get --enforce-lockfile
```

如确实需要重新解算依赖，请在构建后再次确认 `flutter_rust_bridge` 仍为 `2.11.1`。

### Android 构建

#### 1. 配置 JDK 17

Windows PowerShell 示例：

```powershell
$env:JAVA_HOME="C:\soft\Java\jdk-17"
$env:Path="$env:JAVA_HOME\bin;$env:Path"
java -version
```

#### 2. 配置签名

创建 `android/key.properties`：

```properties
storePassword=你的 store 密码
keyPassword=你的 key 密码
keyAlias=你的 key alias
storeFile=../keystore.jks
```

并将 keystore 文件放到：

```text
android/keystore.jks
```

请不要提交 `android/key.properties` 和 `android/keystore.jks`。

#### 3. 检查 Rust Android targets

```powershell
rustup target list --installed
```

如果缺少 Android targets：

```powershell
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
```

#### 4. 构建 APK

```powershell
flutter clean
flutter pub get --enforce-lockfile
flutter build apk
```

构建产物通常位于：

```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/apk/release/
```

如果 Gradle 官方源下载慢，可临时修改 `android/gradle/wrapper/gradle-wrapper.properties`：

```properties
distributionUrl=https://mirrors.cloud.tencent.com/gradle/gradle-8.13-all.zip
```

该改动仅用于本地构建，不建议提交。

### 其他平台构建

构建 Windows：

```bash
flutter build windows
```

构建 Linux：

```bash
flutter build linux
```

构建 macOS：

```bash
flutter build macos
```

### 常见问题

- `flutter_rust_bridge has not been initialized`：通常是 `flutter_rust_bridge` 被升级到与 `rhttp 0.15.1` 不匹配的版本，请恢复 `pubspec.lock`。
- `Unable to satisfy pubspec.yaml using pubspec.lock`：当前 Flutter/Dart 或包源无法复用锁文件，请优先切换到项目要求的 Flutter 版本并使用 `pub.dev` 加代理。
- Gradle 卡在下载 `gradle-8.13-all.zip`：临时切换 Gradle wrapper 镜像，或配置系统代理。
- Kotlin incremental cache 报 `this and base files have different roots`：通常是缓存警告；如构建成功可忽略，或执行 `flutter clean` 后重试。

---

## 漫画源开发

Venera 的网络源由 JavaScript 编写，通过内置 JS API 与 Flutter/Dart 侧能力交互。

如果你想创建或维护漫画源，请阅读：

- [Comic Source 文档](doc/comic_source.md)
- [JS API 文档](doc/js_api.md)

---

## Headless 模式

项目支持无界面命令行模式，可用于自动化同步、更新源脚本、检查订阅更新等。

文档见：

- [Headless Doc](doc/headless_doc.md)

---

## 免责声明

本项目仅作为漫画阅读器客户端与个人维护 fork。

- 项目本身不提供漫画内容；
- 网络漫画源由用户自行添加、维护或选择；
- 请遵守所在地法律法规和内容来源站点规则；
- 请尊重版权与创作者权益；
- 本 fork 的更新方向以个人需求为主，不承诺满足所有使用场景。

---

## 致谢

### 原项目

感谢 [venera-app/venera](https://github.com/venera-app/venera) 的原作者和贡献者。Venera Next 的基础架构、核心能力和大量实现都来自原项目。

### 标签翻译

漫画标签中文翻译来自：

- [EhTagTranslation/Database](https://github.com/EhTagTranslation/Database)

---

## License

本项目继承原项目许可证，使用 GPL-3.0 License。详见 [LICENSE](LICENSE)。

