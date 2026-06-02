@echo off
echo ==========================================
echo  Incus Lab - Inicio
echo ==========================================
echo.
echo [1/5] Iniciando WSL2 + Incus...
wsl -d Debian2 -e bash -l -c "systemctl start incus"
echo.
echo [2/5] Iniciando contenedores...
wsl -d Debian2 -e bash -l -c "cd /root/Incus_Reservation_Management_Platform && bash scripts/startup.sh"
echo.
echo [3/5] Configurando proxy devices...
wsl -d Debian2 -e bash -l -c "sudo incus config device add core frontend-port proxy listen=tcp:0.0.0.0:5173 connect=tcp:127.0.0.1:5173 2>/dev/null; echo 'frontend: OK'" > NUL
wsl -d Debian2 -e bash -l -c "sudo incus config device add api api-port proxy listen=tcp:0.0.0.0:8080 connect=tcp:127.0.0.1:8080 2>/dev/null; echo 'api: OK'" > NUL
wsl -d Debian2 -e bash -l -c "sudo incus config device add mon prometheus-port proxy listen=tcp:0.0.0.0:9090 connect=tcp:127.0.0.1:9090 2>/dev/null; echo 'prometheus: OK'" > NUL
echo.
echo [4/5] Esperando puertos...
echo  - Frontend (5173)...
:retry5173
wsl -d Debian2 -e bash -l -c "ss -tlnp | grep -q 5173" > NUL 2>&1
if errorlevel 1 (
    timeout /t 2 /nobreak > NUL
    goto retry5173
)
echo  - API (8080)...
:retry8080
wsl -d Debian2 -e bash -l -c "ss -tlnp | grep -q 8080" > NUL 2>&1
if errorlevel 1 (
    timeout /t 2 /nobreak > NUL
    goto retry8080
)
echo  - Prometheus (9090)...
:retry9090
wsl -d Debian2 -e bash -l -c "ss -tlnp | grep -q 9090" > NUL 2>&1
if errorlevel 1 (
    timeout /t 2 /nobreak > NUL
    goto retry9090
)
echo.
echo [5/5] Abriendo servicios...
start http://localhost:5173
start http://localhost:9090
echo.
echo ==========================================
echo  Servicios disponibles:
echo    Frontend: http://localhost:5173
echo    API:      http://localhost:8080/api/v1/health
echo    Prometheus: http://localhost:9090
echo ==========================================
echo.
echo Para apagar: shutdown.bat
echo.
pause
