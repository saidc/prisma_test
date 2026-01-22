import subprocess  # Importa el módulo para ejecutar comandos del sistema
import sys         # Importa el módulo para interactuar con el intérprete (manejo de errores)

def ejecutar_docker_compose():
    # Define el comando como una lista para mayor seguridad y evitar problemas de escape de caracteres
    comando = [
        "docker",           # El ejecutable principal
        "compose",          # Subcomando de Docker para orquestación
        "--env-file",       # Flag para especificar un archivo de variables de entorno
        "./env/.active.env", # Ruta relativa al archivo de entorno
        "up",               # Levanta los servicios definidos en el docker-compose.yml
        "-d",               # Modo 'detached': corre los contenedores en segundo plano
        "--build"           # Fuerza la reconstrucción de las imágenes antes de iniciar
    ]
    
    try:
        # Muestra en la terminal el comando que se va a ejecutar (uniendo la lista por espacios)
        print(f"Ejecutando: {' '.join(comando)}...")
        
        # Ejecuta el comando de forma síncrona
        # check=True: Si el comando falla (codigo de salida distinto de 0), lanza una excepción
        # text=True: Captura las salidas del sistema como texto en lugar de bytes
        subprocess.run(comando, check=True, text=True)
        
        # Si llega aquí, es porque el comando se completó con éxito
        print("Docker Compose se ejecutó correctamente.")
        
    except subprocess.CalledProcessError as e:
        # Captura errores específicos de la ejecución del comando (ej. error en el archivo YAML)
        print(f"Error al ejecutar Docker Compose: {e}", file=sys.stderr)
    except FileNotFoundError:
        # Captura el error en caso de que Docker no esté instalado en la máquina
        print("Error: El comando 'docker' no se encontró. Asegúrate de que esté instalado.", file=sys.stderr)

# Punto de entrada estándar de Python para ejecutar la función
if __name__ == "__main__":
    ejecutar_docker_compose()
