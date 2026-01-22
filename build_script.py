import subprocess  # Importa el módulo para ejecutar procesos del sistema
import sys         # Importa el módulo para manejo de errores y salida del sistema
import argparse    # Importa el módulo para gestionar argumentos de línea de comandos

def docker_compose_up(env_file):
    # Definimos el comando de docker compose que solicitaste originalmente
    comando_docker = [
        "docker", "compose", # Usamos 'docker compose' en lugar de 'docker-compose'
        "--env-file", env_file, # Especificamos el archivo de entorno
        "up", "-d", "--build" # Comando para levantar los servicios en modo detached y construir imágenes
    ]
    
    try:
        print("--- Iniciando pasos del ambiente DEV ---")
        print(f"Ejecutando comando: {' '.join(comando_docker)}")
        
        # Ejecutamos el comando y esperamos a que termine
        subprocess.run(comando_docker, check=True, text=True)
        
        print("--- Ambiente DEV desplegado correctamente ---")
        
    except subprocess.CalledProcessError as e:
        # Si Docker devuelve un error, lo capturamos aquí
        print(f"Error al ejecutar Docker en ambiente dev: {e}", file=sys.stderr)
    except FileNotFoundError:
        # Si Docker no está instalado en el sistema
        print("Error: El comando 'docker' no fue encontrado.", file=sys.stderr)

def init_dev():
    """
    Esta función se encarga de ejecutar los pasos específicos 
    para el ambiente de desarrollo (dev).
    """
    docker_compose_up(".active.env")

def main():
    # 1. Configuramos argparse para recibir el argumento --init
    parser = argparse.ArgumentParser(description="Script de gestión de ambientes.")
    
    # Añadimos la variable 'init' como argumento de entrada
    parser.add_argument(
        "--init", 
        type=str, 
        help="Define el ambiente a inicializar (ej: dev)"
    )

    # 2. Leemos los argumentos pasados al ejecutar el script
    args = parser.parse_args()

    # 3. Guardamos el valor en una variable local para mayor claridad
    init = args.init

    # 4. Lógica de validación: si init es 'dev', ejecutamos la función
    if init == "dev":
        init_dev()
    else:
        # Si no es 'dev', el script no hace nada y avisa al usuario
        print(f"Valor de --init: '{init}'. No se realizará ninguna acción.")

# Punto de entrada del programa
if __name__ == "__main__":
    main()
