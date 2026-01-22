import subprocess
import sys
import argparse

def docker_compose_up(env_file):
    """Levanta el ambiente con build y en modo detached."""
    comando_docker = [
        "docker", "compose",
        "--env-file", env_file,
        "up", "-d", "--build"
    ]
    
    try:
        print(f"--- Iniciando despliegue de ambiente: {env_file} ---")
        subprocess.run(comando_docker, check=True, text=True)
        print("--- Ambiente desplegado correctamente ---")
    except subprocess.CalledProcessError as e:
        print(f"Error al levantar Docker: {e}", file=sys.stderr)
    except FileNotFoundError:
        print("Error: El comando 'docker' no fue encontrado.", file=sys.stderr)

def docker_compose_down_all(env_file):
    """
    Baja los servicios y elimina TODO:
    -v: Volúmenes
    --rmi all: Todas las imágenes utilizadas
    --remove-orphans: Contenedores huérfanos
    """
    comando_docker = [
        "docker", "compose",
        "--env-file", env_file,
        "down",
        "-v",            # Elimina volúmenes
        "--rmi", "all",  # Elimina todas las imágenes del archivo compose
        "--remove-orphans" # Elimina contenedores no definidos en el archivo actual
    ]
    
    try:
        print(f"--- Limpiando ambiente (Down All): {env_file} ---")
        subprocess.run(comando_docker, check=True, text=True)
        print("--- El sistema ha quedado en cero (volúmenes, redes e imágenes eliminados) ---")
    except subprocess.CalledProcessError as e:
        print(f"Error al limpiar Docker: {e}", file=sys.stderr)

def main():
    parser = argparse.ArgumentParser(description="Script de gestión de ambientes.")
    
    # Argumento para inicializar
    parser.add_argument(
        "--init", 
        type=str, 
        help="Define el ambiente a inicializar (ej: dev)"
    )

    # Argumento para limpieza total
    parser.add_argument(
        "--down-all",
        type=str,
        help="Baja y elimina todo rastro del ambiente (ej: dev)"
    )

    args = parser.parse_args()
    env_path = "./env/.active.env"

    # Lógica para inicializar
    if args.init == "dev":
        docker_compose_up(env_path)
    
    # Lógica para resetear (down-all)
    elif args.down_all == "dev":
        docker_compose_down_all(env_path)
    
    else:
        print("No se ha especificado una acción válida o el ambiente es incorrecto.")
        print("Uso: python3 manage_script.py --init dev  O  python3 manage_script.py --down-all dev")

if __name__ == "__main__":
    main()


# Ejemplo de uso:
#  Para inicializar el ambiente de desarrollo, ejecuta:
#   sudo python3 build_script.py --init dev
#  Para limpiar todo el ambiente de desarrollo, ejecuta:
#   python3 manage_script.py --down-all dev