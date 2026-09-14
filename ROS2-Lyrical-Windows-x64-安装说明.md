# ROS 2 Lyrical Windows x64 安装说明

本文档说明如何安装随本项目提供的 ROS 2 Lyrical 离线安装程序。安装程序文件为：

```text
C:\ros2\ROS2-Lyrical-Windows-x64-Installer.exe
```

安装包内置 ROS 2 Lyrical 运行环境和完整 Python/Pixi 运行时，目标机器不需要预装 Python、Pixi、Visual Studio 或连接互联网。

## 1. 安装前检查

目标机器应满足以下条件：

| 项目 | 要求 |
|---|---|
| 操作系统 | Windows 10 build 17763 或更高版本，推荐 Windows 11 |
| 架构 | 64 位 x64 |
| PowerShell | Windows PowerShell 5.1 或更高版本 |
| 文件系统 | NTFS |
| 可用磁盘空间 | 至少 10 GB |
| 权限 | 默认安装不需要管理员权限；启用系统级长路径时需要管理员权限 |
| 网络 | 安装时不需要网络 |

默认安装目录固定为：

```text
%LOCALAPPDATA%\ROS2\Lyrical
```

## 2. 校验安装程序

安装包大小约为 927 MiB。建议先校验 SHA-256：

```powershell
Get-FileHash `
  C:\ros2\ROS2-Lyrical-Windows-x64-Installer.exe `
  -Algorithm SHA256
```

当前安装包的 SHA-256 为：

```text
5a5a543ca3cb9431287d124c88e25563973db9ccc3b5f66ff6cbbc79d94fb84d
```

也可以直接读取校验文件：

```powershell
Get-Content `
  C:\ros2\ROS2-Lyrical-Windows-x64-Installer.exe.sha256
```

如果哈希不一致，请不要运行该安装程序，并重新复制完整的 EXE 文件。

## 3. 安装步骤

1. 打开文件资源管理器，进入 `C:\ros2`。
2. 双击 `ROS2-Lyrical-Windows-x64-Installer.exe`。
3. 如果 Windows SmartScreen 显示“未知发布者”，选择“更多信息”，再选择“仍要运行”。当前安装程序未进行商业代码签名。
4. 等待自解压和依赖检测完成。安装器会检测：
   - Windows 版本和 x64 架构。
   - PowerShell 版本。
   - 目标磁盘剩余空间。
   - Windows 长路径设置。
   - 内置 Python、VC 运行库和 ROS 2 关键文件。
5. 安装器将文件复制到 `%LOCALAPPDATA%\ROS2\Lyrical`。
6. 安装器自动执行以下验证：
   - `ros2 --help`
   - `ros2 pkg list`
7. 看到 `ROS 2 Lyrical installation completed successfully.` 后表示安装成功。

安装过程会创建：

- ROS 2 运行目录：`%LOCALAPPDATA%\ROS2\Lyrical\ros`
- Python/Qt/DDS 运行时：`%LOCALAPPDATA%\ROS2\Lyrical\runtime`
- ROS 2 命令入口：`%LOCALAPPDATA%\ROS2\Lyrical\ros2.cmd`
- 环境加载脚本：`%LOCALAPPDATA%\ROS2\Lyrical\ros2_env.cmd`
- 已配置终端：`%LOCALAPPDATA%\ROS2\Lyrical\ros2_shell.cmd`
- 开始菜单快捷方式：`ROS 2 Lyrical Shell`

## 4. 验证安装

重新打开一个命令行终端，执行：

```cmd
"%LOCALAPPDATA%\ROS2\Lyrical\ros2.cmd" --help
```

查看包列表：

```cmd
"%LOCALAPPDATA%\ROS2\Lyrical\ros2.cmd" pkg list
```

正常情况下应发现约 353 个 ROS 2 包。查看话题：

```cmd
"%LOCALAPPDATA%\ROS2\Lyrical\ros2.cmd" topic list
```

## 5. 使用 ROS 2

### 使用已配置终端

双击开始菜单中的 `ROS 2 Lyrical Shell`，或执行：

```cmd
"%LOCALAPPDATA%\ROS2\Lyrical\ros2_shell.cmd"
```

进入终端后可以直接运行：

```cmd
ros2 --help
ros2 pkg list
ros2 topic list
ros2 node list
```

### 测试 C++ 与 Python 通信

终端 1：

```cmd
ros2 run demo_nodes_cpp talker
```

终端 2：

```cmd
ros2 run demo_nodes_py listener
```

预期输出：

```text
[talker] Publishing: 'Hello World: ...'
[listener] I heard: [Hello World: ...]
```

### 直接调用 ros2.cmd

不打开配置终端也可以直接运行：

```cmd
"%LOCALAPPDATA%\ROS2\Lyrical\ros2.cmd" run demo_nodes_cpp talker
"%LOCALAPPDATA%\ROS2\Lyrical\ros2.cmd" run demo_nodes_py listener
```

## 6. 常见问题

### 安装后提示找不到 ros2

重新打开终端，使安装器写入的用户 PATH 生效；或者直接使用：

```cmd
"%LOCALAPPDATA%\ROS2\Lyrical\ros2_shell.cmd"
```

### SmartScreen 阻止运行

安装程序未进行数字签名。确认 SHA-256 与本文档一致后，选择“更多信息”并点击“仍要运行”。

### 安装失败

安装日志位于：

```text
%TEMP%\ROS2-Lyrical-install.log
```

请检查日志中的 `Installation failed` 以及前面的依赖检测信息。

### 长路径警告

如果 Windows 长路径未启用，安装器会尝试在具备管理员权限时启用。无法启用时仍可能完成安装，但后续源码开发可能受到 260 字符路径限制影响。

### 安装目录能否修改

当前安装器版本固定安装到 `%LOCALAPPDATA%\ROS2\Lyrical`，以避免不同机器上的路径长度和权限差异。

## 7. 卸载

可以通过 Windows“应用和功能”选择 `ROS 2 Lyrical`，或者运行：

```powershell
& "$env:LOCALAPPDATA\ROS2\Lyrical\uninstall.ps1"
```

卸载会删除：

- `%LOCALAPPDATA%\ROS2\Lyrical`
- 当前用户 PATH 中的 ROS 2 安装目录
- `ROS2_LYRICAL_HOME`
- 开始菜单快捷方式
- 当前用户卸载注册表项

## 8. 适用范围

该安装包提供的是可运行的 ROS 2 Lyrical 环境，包含 ROS 2 CLI、C++/Python 运行库、DDS、RViz 和 Python 工具。

该安装包不包含 Visual Studio 编译器或源码构建工具。如果需要在目标机器重新编译 ROS 2 源码，需要另行安装 Visual Studio Build Tools 和 Pixi，并按照 ROS 2 Lyrical 源码开发流程执行。