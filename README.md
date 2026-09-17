# 右见 RightSight

右见是一款 macOS Finder 右键菜单工具，基于 GPL-3.0 项目 [RClick](https://github.com/wflixu/RClick) 修改。

## 功能

- 用外部应用打开文件或目录
- 复制路径、直接删除、隐藏/显示、AirDrop
- 剪切并粘贴文件；复制/移动到指定文件夹，重名自动编号且不会覆盖
- 从模板新建文件
- 常用目录
- 批量图片转换：JPG、PNG、WebP；原图保留，重名时自动生成新文件名
- 设置支持导出、导入和一键恢复默认配置

## 开发与构建

需要 macOS 15.6+、Xcode 16.4+。打开 `RClick.xcodeproj`，选择 `RClick` scheme 构建。内部 target 名保持上游结构，产物名为 `RightSight.app`。

```bash
git clone https://github.com/dmarcin1/RightSight.git
cd RightSight
open RClick.xcodeproj
```

WebP 编码使用持续维护的 [SDWebImageWebPCoder](https://github.com/SDWebImage/SDWebImageWebPCoder)（MIT）及 Google libwebp；JPG/PNG 使用 macOS Image I/O。

## 测试

```bash
xcodebuild test -project RClick.xcodeproj -scheme RClick -destination 'platform=macOS'
```

## 授权

本项目继承 RClick 的 GNU GPL v3.0 授权，详见 [LICENSE](LICENSE) 和 [RIGHTSIGHT_NOTICE.md](RIGHTSIGHT_NOTICE.md)。
