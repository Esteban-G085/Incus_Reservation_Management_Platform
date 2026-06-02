# -*- coding: utf-8 -*-
import subprocess
import argparse
import os
import sys

def ejecutar_comando(comando):
    """Ejecuta un comando en la terminal y maneja posibles errores."""
    resultado = subprocess.run(comando, capture_output=True, text=True)
    if resultado.returncode != 0:
        print(f"[!] Error ejecutando: {' '.join(comando)}")
        print(f"[!] Detalle: {resultado.stderr.strip()}")
        sys.exit(1)
    return resultado.stdout

def clonar_wsl(nuevo_nombre, distro_base="Debian-base", ruta_destino=None):
    # Definir rutas por defecto
    carpeta_usuario = os.environ.get('USERPROFILE', 'C:\\')
    carpeta_temporal = os.environ.get('TEMP', carpeta_usuario)
    
    # Si no se da una ruta de destino, crearla en C:\Usuarios\TuUsuario\WSL\NuevoNombre
    if not ruta_destino:
        ruta_destino = os.path.join(carpeta_usuario, 'WSL', nuevo_nombre)

    ruta_tar = os.path.join(carpeta_temporal, f"{distro_base}_temp_clone.tar")

    print("-" * 50)
    print(f"[*] Clonando '{distro_base}' -> '{nuevo_nombre}'")
    print(f"[*] Destino del disco virtual: {ruta_destino}")
    print("-" * 50)

    # 1. Crear carpeta de destino si no existe
    os.makedirs(ruta_destino, exist_ok=True)

    # 2. Exportar la distro base
    print("[*] Paso 1/3: Exportando la distribuci�n base (Esto puede tardar varios minutos)...")
    ejecutar_comando(["wsl", "--export", distro_base, ruta_tar])

    # 3. Importar la nueva distro
    print(f"[*] Paso 2/3: Importando la nueva distribución '{nuevo_nombre}'...")
    try:
        ejecutar_comando(["wsl", "--import", nuevo_nombre, ruta_destino, ruta_tar])
    except SystemExit:
        # Si falla la importación, limpiar el archivo temporal antes de salir
        if os.path.exists(ruta_tar):
            os.remove(ruta_tar)
        sys.exit(1)

    # 4. Limpiar el archivo .tar temporal
    print("[*] Paso 3/3: Limpiando archivos temporales...")
    if os.path.exists(ruta_tar):
        os.remove(ruta_tar)

    print("-" * 50)
    print(f"[+] ¡Éxito! La distribución '{nuevo_nombre}' está lista para usarse.")
    print(f"[i] Comando para entrar: wsl -d {nuevo_nombre}")
    print("[i] Nota: Iniciarás como 'root'. Recuerda configurar /etc/wsl.conf para tu usuario habitual.")
    print("-" * 50)

if __name__ == "__main__":
    # Configurar los argumentos de consola
    parser = argparse.ArgumentParser(description="Clona una distribución de WSL exportándola e importándola automáticamente.")
    parser.add_argument("nuevo_nombre", help="El nombre que le darás a la nueva distribución (ej. Debian2)")
    parser.add_argument("--base", default="Debian-base", help="El nombre de la distro instalada que servirá de plantilla (Por defecto: Debian)")
    parser.add_argument("--destino", default="", help="Ruta personalizada donde guardar el disco virtual (VHDX)")

    args = parser.parse_args()

    clonar_wsl(args.nuevo_nombre, args.base, args.destino)
