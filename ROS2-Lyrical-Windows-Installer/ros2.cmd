@echo off
call "%~dp0ros2_env.cmd"
if errorlevel 1 exit /b %errorlevel%
"%ROS2_LYRICAL_PYTHON%" "%ROS2_LYRICAL_ROS%\Scripts\ros2-script.py" %*
exit /b %errorlevel%