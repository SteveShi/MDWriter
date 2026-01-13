# Sparkle 更新配置指南

本文档详细说明如何为 MDWriter 配置 Sparkle 2 更新系统。

## 1. 准备工作

项目已经集成了 Sparkle 的 Swift Package 依赖。如果尚未集成，请在 Xcode 的 `Package Dependencies` 中添加 `https://github.com/sparkle-project/Sparkle`。

## 2. 代码实现

在 `MDWriterApp.swift` 或新建一个 `UpdaterController.swift` 文件中添加以下代码，用于管理更新检查：

```swift
import Sparkle

class UpdaterController: ObservableObject {
    private letcontroller: SPUStandardUpdaterController
    
    init() {
        // startingUpdater: true 表示应用启动时自动初始化更新器
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
```

在 `MDWriterApp` 中使用：

```swift
@main
struct MDWriterApp: App {
    // 初始化更新控制器
    @StateObject var updaterController = UpdaterController()
    
    var body: some Scene {
        WindowGroup { ... }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("检查更新...") {
                    updaterController.checkForUpdates()
                }
            }
        }
    }
}
```

## 3. 配置 Info.plist

在项目的 `Info.plist` 文件中添加以下键值对：

*   **`SUFeedURL`**: 您的 Appcast XML 文件地址。
    *   例如：`https://your-domain.com/appcast.xml`
*   **`SUPublicEDKey`**: 您的公钥（稍后生成）。

## 4.生成密钥和发布更新

Sparkle 提供了一组命令行工具来辅助部署。

1.  **生成密钥对**：
    运行 Sparkle 的 `generate_keys` 工具。它会生成公钥和私钥。
    *   **公钥**：填入 `Info.plist` 的 `SUPublicEDKey` 字段。
    *   **私钥**：妥善保存，用于签名发布包。

2.  **打包应用**：
    将编译好的 `.app` 文件压缩为 `.zip` 或创建 `.dmg`。

3.  **生成 Appcast**：
    使用 `generate_appcast` 工具扫描您的更新包目录，生成 `appcast.xml`。
    ```bash
    # 假设您的更新包在 archives 目录
    ./bin/generate_appcast archives/
    ```

4.  **上传**：
    将新的压缩包和 `appcast.xml` 上传到您在 `SUFeedURL` 中配置的服务器位置。

## 5. 沙盒注意事项

如果您开启了 App Sandbox：
1.  确保在 `Entitlements` 中允许网络访问 (`com.apple.security.network.client`)。
2.  Sparkle 2 支持沙盒，但需要在 `Entitlements` 中添加特定的 XPC 服务权限（如果使用 XPC 架构）。对于简单的 `SPUStandardUpdaterController` 集成，通常只需网络权限即可。

## 参考资料

*   [Sparkle Documentation](https://sparkle-project.org/documentation/)

## 6. GitHub Actions 自动化

我们已经为您配置了 GitHub Actions (`.github/workflows/release.yml`) 来自动完成更新包的构建、签名和 Appcast 生成。

**您只需要做一件事：**

1.  找到您之前生成的 **Sparkle 私钥**（Private Key）。
2.  在 GitHub 仓库页面，进入 `Settings` -> `Secrets and variables` -> `Actions`。
3.  点击 `New repository secret`。
4.  Name 填写：`SPARKLE_PRIVATE_KEY`。
5.  Value 填写：您的私钥内容（通常以 `IS` 开头的一长串字符）。

**自动化流程说明：**

当您推送以 `v` 开头的标签（如 `v1.6.1`）时，Action 会自动：
1.  构建并签名的 macOS 应用。
2.  下载 Sparkle 工具链。
3.  使用您提供的私钥对更新包进行 EdDSA 签名。
4.  基于 GitHub Release 的下载链接，自动生成 `appcast.xml` 文件。
5.  将 `appcast.xml` 附在 Release 附件中。

**注意**：由于 GitHub Release 在发布时 URL 是固定的，生成的 XML 中的 `enclosure url` 会指向该 Release 的 ZIP 下载地址。您只需将 Release 附件中的 `appcast.xml` 内容更新到您托管 Appcast 的服务器（如 GitHub Pages）即可。
