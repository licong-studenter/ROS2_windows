# ROS 2 Lyrical Windows x64 离线安装包

本项目用于构建 `ROS2-Lyrical-Windows-x64-Installer.exe`。安装包内置已经编译并验证的 ROS 2 Lyrical 运行环境和 Python/Pixi 运行时，目标机器无需 Visual Studio、Pixi、Python 或网络连接即可运行 ROS 2。

## 交付文件

- `ROS2-Lyrical-Windows-x64-Installer.exe`：离线自解压安装程序，约 927 MB。
- `ROS2-Lyrical-Windows-x64-Installer.exe.sha256`：安装包 SHA-256 校验文件。
- `ROS2-Lyrical-Windows-Installer\README.md`：本文档。
- `ROS2-Lyrical-Windows-Installer\build_installer.ps1`：可重复构建安装器的脚本。

## 安装包内容

- `ros\`：ROS 2 Lyrical 的 merged install tree。
- `runtime\`：Python 3.12、Qt、DDS、压缩库等完整运行时。
- `ros2.cmd`：加载环境并执行 `ros2` 命令。
- `ros2_env.cmd`：设置 ROS 2、AMENT、PYTHONPATH、PATH 和 DDS 相关环境。
- `ros2_shell.cmd`：打开已配置的 ROS 2 命令终端。
- `uninstall.ps1`：当前用户级卸载脚本。

安装包不包含源码构建目录 `build\`，也不包含 Visual Studio 编译器。它适用于运行 ROS 2 节点、`ros2` CLI、Python 包和 RViz。若要在目标机器上重新编译 ROS 2 源码，仍需安装 Visual Studio Build Tools 和 Pixi。

## 依赖检测

安装脚本在复制文件前检测以下项目：

- Windows 10 build 17763 或更高版本。
- Windows x64 架构。
- PowerShell 5.1 或更高版本。
- 目标磁盘至少 10 GB 可用空间。
- Windows 长路径设置。
- 内置 `runtime\python.exe` 和 VC 运行库 DLL。
- `ros\local_setup.bat`、`ros\Scripts\ros2-script.py` 等关键文件。
- 安装后的 `ros2 --help`。
- 安装后的 `ros2 pkg list`，并要求至少发现 300 个包。

检测失败时安装器会停止并显示原因。安装过程不需要管理员权限，默认安装目录固定为：

```text
%LOCALAPPDATA%\ROS2\Lyrical
```

## 安装

1. 双击 `ROS2-Lyrical-Windows-x64-Installer.exe`。
2. 等待自解压和依赖检测完成。
3. 安装器复制运行时并执行 `ros2` 自检。
4. 安装完成后使用开始菜单中的 `ROS 2 Lyrical Shell` 快捷方式。

安装器会：

- 将 ROS 2 和运行时复制到 `%LOCALAPPDATA%\ROS2\Lyrical`。
- 在当前用户 PATH 中加入安装目录。
- 设置 `ROS2_LYRICAL_HOME` 用户环境变量。
- 创建开始菜单快捷方式。
- 注册当前用户的卸载信息。

## 使用方法

直接调用 `ros2`：

```cmd
"%LOCALAPPDATA%\ROS2\Lyrical\ros2.cmd" --help
"%LOCALAPPDATA%\ROS2\Lyrical\ros2.cmd" pkg list
"%LOCALAPPDATA%\ROS2\Lyrical\ros2.cmd" topic list
```

打开已配置终端：

```cmd
"%LOCALAPPDATA%\ROS2\Lyrical\ros2_shell.cmd"
```

在已配置终端中运行节点：

```cmd
ros2 run demo_nodes_cpp talker
```

另一个终端中运行：

```cmd
ros2 run demo_nodes_py listener
```

预期看到：

```text
[talker] Publishing: 'Hello World: ...'
[listener] I heard: [Hello World: ...]
```

## 卸载

从 Windows“应用和功能”中选择 `ROS 2 Lyrical`，或运行：

```powershell
& "$env:LOCALAPPDATA\ROS2\Lyrical\uninstall.ps1"
```

卸载会删除安装目录、当前用户 PATH 中的安装目录、`ROS2_LYRICAL_HOME`、开始菜单快捷方式和卸载注册表项。

## 重新构建安装器

在已完成 ROS 2 Lyrical 源码构建的机器上运行：

```powershell
powershell -ExecutionPolicy Bypass -File `
  C:\ros2\ROS2-Lyrical-Windows-Installer\build_installer.ps1
```

构建脚本读取：

```text
C:\dev\lyrical\install
C:\dev\.pixi\envs\default
```

默认输出：

```text
C:\ros2\ROS2-Lyrical-Windows-x64-Installer.exe
```

源码目录 `C:\dev\lyrical\src` 和构建目录 `C:\dev\lyrical\build` 不会被打包。