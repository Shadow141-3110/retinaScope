@echo off
setlocal EnableExtensions
set "PROJECT_ROOT=%~dp0"
if "%PROJECT_ROOT:~-1%"=="\" set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"

if /I "%~1"=="backend" goto BACKEND
if /I "%~1"=="frontend" goto FRONTEND

title RetinaScope - Launcher
echo.
echo =====================================================
echo                 RETINASCOPE AI
echo          Backend + Next.js Frontend Launcher
echo =====================================================
echo.
echo Project folder: %PROJECT_ROOT%
echo.

if not exist "%PROJECT_ROOT%\backend\main.py" (
    echo [ERROR] backend\main.py was not found.
    echo Put this BAT file in the project root beside backend, frontend, models and venv.
    goto MAIN_ERROR
)
if not exist "%PROJECT_ROOT%\frontend\package.json" (
    echo [ERROR] frontend\package.json was not found.
    echo Put this BAT file in the project root beside backend, frontend, models and venv.
    goto MAIN_ERROR
)
if not exist "%PROJECT_ROOT%\models\efficientnet_b0_best.pth" (
    echo [ERROR] Required model missing:
    echo models\efficientnet_b0_best.pth
    goto MAIN_ERROR
)
if not exist "%PROJECT_ROOT%\venv\Scripts\python.exe" (
    echo [ERROR] Project virtual environment was not found:
    echo venv\Scripts\python.exe
    echo Create/restore the project venv first.
    goto MAIN_ERROR
)

rem Check whether the expected backend is already healthy.
curl.exe -fsS http://127.0.0.1:8000/api/health >nul 2>&1
if errorlevel 1 (
    rem Port check: do not silently bind to a different port because CORS and frontend URLs expect 8000.
    powershell -NoProfile -Command "if (Get-NetTCPConnection -State Listen -LocalPort 8000 -ErrorAction SilentlyContinue) { exit 1 } else { exit 0 }" >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Port 8000 is already in use, but it is not responding as the RetinaScope API.
        echo Close the old backend terminal/process, then run this BAT again.
        goto MAIN_ERROR
    )
    echo [1/2] Starting FastAPI backend in a separate window...
    start "RetinaScope - Backend" "%ComSpec%" /k ""%~f0" backend"
) else (
    echo [1/2] RetinaScope backend is already responding on port 8000. Reusing it.
)

rem Reuse a frontend if one is already responding; otherwise start the local Next.js app.
curl.exe -fsS http://127.0.0.1:3000 >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "if (Get-NetTCPConnection -State Listen -LocalPort 3000 -ErrorAction SilentlyContinue) { exit 1 } else { exit 0 }" >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Port 3000 is already in use, but no web page responded correctly.
        echo Close the old frontend terminal/process, then run this BAT again.
        goto MAIN_ERROR
    )
    echo [2/2] Starting Next.js frontend in a separate window...
    start "RetinaScope - Frontend" "%ComSpec%" /k ""%~f0" frontend"
) else (
    echo [2/2] A web server is already responding on port 3000. Reusing it.
)

echo.
echo Waiting briefly for the frontend to boot...
timeout /t 6 /nobreak >nul
echo.
echo =====================================================
echo RetinaScope startup commands have been launched.
echo Frontend : http://127.0.0.1:3000
echo Backend  : http://127.0.0.1:8000/docs
echo Health   : http://127.0.0.1:8000/api/health
echo.
echo Keep the Backend and Frontend windows open.
echo Close those windows to stop their servers.
echo =====================================================
start "" http://127.0.0.1:3000
echo.
pause
exit /b 0

:BACKEND
title RetinaScope - FastAPI Backend
cd /d "%PROJECT_ROOT%"
set "PYTHON=%PROJECT_ROOT%\venv\Scripts\python.exe"
echo.
echo ==========================================
echo       RETINASCOPE FASTAPI BACKEND
echo ==========================================
echo Project: %PROJECT_ROOT%
echo.

"%PYTHON%" -c "import fastapi, uvicorn, multipart, torch, timm, cv2, reportlab, pytorch_grad_cam" >nul 2>&1
if errorlevel 1 (
    echo [INFO] Required backend packages are missing. Installing dependencies...
    echo This may take a while on the first run.
    "%PYTHON%" -m pip install -r "%PROJECT_ROOT%\requirements.txt" fastapi uvicorn python-multipart grad-cam
    if errorlevel 1 (
        echo.
        echo [ERROR] Dependency installation failed. Read the pip error above.
        pause
        exit /b 1
    )
)

echo.
echo Starting model and API on http://127.0.0.1:8000 ...
echo API docs: http://127.0.0.1:8000/docs
echo.
"%PYTHON%" -m uvicorn backend.main:app --host 127.0.0.1 --port 8000
if errorlevel 1 (
    echo.
    echo [ERROR] Backend stopped with an error. Read the traceback above.
)
echo.
echo Backend process ended. This window will remain open.
pause
exit /b

:FRONTEND
title RetinaScope - Next.js Frontend
cd /d "%PROJECT_ROOT%\frontend"
echo.
echo ==========================================
echo        RETINASCOPE NEXT.JS FRONTEND
echo ==========================================
echo Project: %PROJECT_ROOT%\frontend
echo.

where node.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js was not found in PATH. Install Node.js LTS and reopen this BAT.
    pause
    exit /b 1
)
where npm.cmd >nul 2>&1
if errorlevel 1 (
    echo [ERROR] npm was not found in PATH. Repair your Node.js installation.
    pause
    exit /b 1
)

if not exist "%PROJECT_ROOT%\frontend\node_modules" (
    echo [INFO] frontend\node_modules is missing. Running npm install...
    call npm.cmd install
    if errorlevel 1 (
        echo.
        echo [ERROR] npm install failed. Read the npm error above.
        pause
        exit /b 1
    )
)

rem Frontend configuration for the existing FastAPI routes.
set "NEXT_PUBLIC_RETINASCOPE_PREDICT_URL=http://127.0.0.1:8000/api/predict"
set "NEXT_PUBLIC_RETINASCOPE_FILE_FIELD=file"
set "NEXT_PUBLIC_RETINASCOPE_API_BASE_URL=http://127.0.0.1:8000"

echo.
echo API URL : %NEXT_PUBLIC_RETINASCOPE_PREDICT_URL%
echo API base: %NEXT_PUBLIC_RETINASCOPE_API_BASE_URL%
echo Starting Next.js on http://127.0.0.1:3000 ...
echo.
call npm.cmd run dev -- --hostname 127.0.0.1 --port 3000
if errorlevel 1 (
    echo.
    echo [ERROR] Frontend stopped with an error. Read the npm output above.
)
echo.
echo Frontend process ended. This window will remain open.
pause
exit /b

:MAIN_ERROR
echo.
echo Startup cancelled. Fix the error above and run this BAT again.
echo.
pause
exit /b 1
