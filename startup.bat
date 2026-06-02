@echo off
echo ==========================================
echo  Incus Lab - Inicio completo
echo ==========================================
echo.
echo [1/3] Iniciando Incus en WSL2...
wsl -d Debian2 -e bash -l -c "systemctl start incus"
echo.
echo [2/3] Iniciando contenedores...
wsl -d Debian2 -e bash -l -c "cd /root/Incus_Reservation_Management_Platform && bash scripts/startup.sh"
echo.
echo [3/3] Abriendo frontend http://localhost:5173 ...
start http://localhost:5173
echo.
echo Laboratorio iniciado.
echo Para verificar: validate.bat
echo Para apagar: shutdown.bat
echo.
