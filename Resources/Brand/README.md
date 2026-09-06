# LocalStack 品牌资源

标识由三层连接的平面组成，表达集中管理多个本地服务。深墨绿色底板搭配薄荷绿线条；菜单栏使用同一轮廓的单色 template 图像，跟随系统自动反色。

- `StackMark.svg`：可编辑矢量标识。
- `AppIcon-1024.png` / `../AppIcon.icns`：完整 macOS 图标尺寸。
- `TrayTemplate.png`：20 pt、2× 菜单栏模板。
- `DMGBackground.png`：720 × 480 pt、2× Finder 背景；文件包含正确的逻辑尺寸元数据。

运行 `make assets` 通过 AppKit 矢量绘制重新生成全部位图和 ICNS。DMG 中的图标位置由 `Scripts/dmg_settings.py` 定义，与背景预留区域对应。SwiftUI 面板中的标识由 `Design/Theme.swift` 的 `StackMark` 绘制。
