@echo off
setlocal
echo ========================================================
echo   DECIBEL - Building Flutter Production Release APK
echo ========================================================

set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "PATH=%JAVA_HOME%\bin;C:\Flutter\Source\flutter\bin;C:\flutter\Source\flutter\bin;%PATH%"

cd /d "%~dp0"
call flutter pub get

cd /d "%~dp0android"
call gradlew.bat assembleRelease

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo   BUILD SUCCESSFUL!
    echo ========================================================
    if exist "%~dp0build\app\outputs\apk\release\app-release.apk" (
        copy /y "%~dp0build\app\outputs\apk\release\app-release.apk" "%~dp0decibel-flutter-release.apk"
        echo   Release APK: %~dp0decibel-flutter-release.apk
    ) else if exist "app\build\outputs\apk\release\app-release.apk" (
        copy /y "app\build\outputs\apk\release\app-release.apk" "%~dp0decibel-flutter-release.apk"
        echo   Release APK: %~dp0decibel-flutter-release.apk
    )
) else (
    echo.
    echo [ERROR] Build failed with exit code %ERRORLEVEL%
)

