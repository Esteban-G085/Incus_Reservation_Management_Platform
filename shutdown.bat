@echo off
echo ==========================================
echo  Incus Lab - Apagado
echo ==========================================
echo.
echo Apagando servicios...
wsl -d Debian2 -e bash -l -c "cd /root/Incus_Reservation_Management_Platform && bash scripts/shutdown.sh"
echo.
echo Listo. Los contenedores estan detenidos.
echo Para reiniciar los servicios (si los contenedores ya existen): startup.bat
echo Para reiniciar el laboratorio desde cero: start-lab.bat
echo.
