@echo off
echo ==========================================
echo  Validacion de servicios
echo ==========================================
echo.
echo [WSL] Ejecutando validacion interna...
wsl -d Debian2 -e bash -l -c "cd /root/Incus_Reservation_Management_Platform && bash scripts/validate-services.sh"
echo.
echo ==========================================
echo  [Windows] Acceso desde el host
echo ==========================================
set PASS=0
set FAIL=0

curl.exe -s -o NUL -w "%%{http_code}" --connect-timeout 3 http://localhost:5173 > NUL 2>&1
if errorlevel 1 (
    echo   [X] Frontend http://localhost:5173 - NO RESPONDE
    set /a FAIL+=1
) else (
    set /a PASS+=1
    curl.exe -s -o NUL -w "  [V] Frontend http://localhost:5173 (HTTP %%{http_code})\n" --connect-timeout 3 http://localhost:5173
)

curl.exe -s -o NUL -w "%%{http_code}" --connect-timeout 3 http://localhost:8080/api/v1/health > NUL 2>&1
if errorlevel 1 (
    echo   [X] API http://localhost:8080 - NO RESPONDE
    set /a FAIL+=1
) else (
    set /a PASS+=1
    curl.exe -s -w "  [V] API http://localhost:8080 (HTTP %%{http_code})\n" --connect-timeout 3 http://localhost:8080/api/v1/health
)

curl.exe -s -o NUL -w "%%{http_code}" --connect-timeout 3 http://localhost:9090 > NUL 2>&1
if errorlevel 1 (
    echo   [X] Prometheus http://localhost:9090 - NO RESPONDE
    set /a FAIL+=1
) else (
    set /a PASS+=1
    curl.exe -s -o NUL -w "  [V] Prometheus http://localhost:9090 (HTTP %%{http_code})\n" --connect-timeout 3 http://localhost:9090
)

echo.
set /a TOTAL=%PASS%+%FAIL%
echo Resultados: %PASS%/%TOTAL% accesibles desde Windows
if %FAIL% equ 0 (
    echo   Todo OK
) else (
    echo   Ejecute start-lab.bat primero
)
echo.
pause
