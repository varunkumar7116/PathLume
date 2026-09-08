@echo off
title PATHLUME - USB APK Installer
color 0A

echo ============================================================
echo           PATHLUME - USB RELEASE APK INSTALLER
echo ============================================================
echo.

set APK_PATH=build\app\outputs\flutter-apk\app-release.apk

if not exist "%APK_PATH%" (
    echo [ERROR] Release APK not found at %APK_PATH%
    echo Building release APK now...
    call E:\flutter\bin\flutter.bat build apk --release
    if errorlevel 1 (
        echo [ERROR] Build failed. Please fix build issues and try again.
        pause
        exit /b 1
    )
)

echo [INFO] Found Release APK: %APK_PATH%
echo [INFO] Checking for connected USB Android devices...
echo.

call E:\flutter\bin\flutter.bat devices

echo.
echo ============================================================
echo Installing PATHLUME onto connected USB device...
echo ============================================================
echo.

call E:\flutter\bin\flutter.bat install

if errorlevel 1 (
    echo.
    echo [ERROR] Installation failed!
    echo Please make sure:
    echo  1. USB Debugging is turned ON in Developer Options on your phone.
    echo  2. Your phone is unlocked and you allowed USB Debugging prompt on the screen.
    echo  3. The phone is connected properly via USB cable.
    echo.
) else (
    echo.
    echo ============================================================
    echo [SUCCESS] PATHLUME updated APK successfully installed!
    echo ============================================================
    echo.
)

pause
