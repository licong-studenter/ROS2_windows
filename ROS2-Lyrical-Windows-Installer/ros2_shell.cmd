@echo off
call "%~dp0ros2_env.cmd"
if errorlevel 1 exit /b %errorlevel%
title ROS 2 Lyrical Shell
cmd.exe /k