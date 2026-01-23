#!/usr/bin/env python3
import argparse
import os
import shutil
import subprocess
from pathlib import Path
from typing import List, Optional

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
COMPOSE_FILE = os.path.join(PROJECT_DIR, "docker-compose.yml")
ENV_FILE = os.path.join(PROJECT_DIR, ".env")
ENV_EXAMPLE_FILE = os.path.join(PROJECT_DIR, ".env.example")

def _run(cmd: List[str], title: str, check: bool = True) -> None:
    print(f"\n=== {title} ===")
    print("$ " + " ".join(cmd))
    subprocess.run(cmd, cwd=PROJECT_DIR, check=check)

def copiar_en(origen, destino):
    # Verificar si el archivo origen existe
    if os.path.exists(origen):
        try:
            shutil.copyfile(origen, destino)
            print(f"✅ Archivo '{destino}' creado exitosamente.")
        except Exception as e:
            print(f"❌ Error al copiar el archivo: {e}")
    else:
        print(f"⚠️ El archivo '{origen}' no existe en el directorio actual.")

def compose_cmd(extra: list[str]) -> list[str]:
  # Use --env-file to ensure env is loaded even when run via sudo
  return ["docker", "compose", "--env-file", str(ENV_FILE), "-f", str(COMPOSE_FILE)] + extra

def exec_cmd(service: str, command: List[str]) -> None:
    _ensure_tools()
    _ensure_env()

    cmd = ["docker", "compose", "--env-file", ENV_FILE, "-f", COMPOSE_FILE, "exec", service] + command
    _run(cmd, f"Exec en {service}", check=False)

def _ensure_env() -> None:
  if not os.path.exists(ENV_FILE):
    raise SystemExit("Falta .env. Crea uno desde .env.example (cp .env.example .env).")

def _ensure_tools() -> None:
  if shutil.which("docker") is None:
    raise SystemExit("Error: 'docker' no está instalado o no está en PATH.")
  try:
    subprocess.run(["docker", "compose", "version"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
  except Exception:
    raise SystemExit("Error: 'docker compose' no está disponible. Actualiza Docker/Compose.")

def up(build: bool) -> None:
  _ensure_tools()
  _ensure_env()

  cmd = ["docker", "compose", "--env-file", ENV_FILE, "-f", COMPOSE_FILE, "up", "-d"]
  if build:
      cmd.append("--build")
  _run(cmd, "Paso 1 - Levantar stack (API + PostgreSQL)")

  _run(["docker", "compose", "--env-file", ENV_FILE, "-f", COMPOSE_FILE, "ps", "-a"], "Paso 2 - Ver estado")

  print(" - Studio:      python3 manage.py studio")

  print("\n=== Paso 2 - Ver estado ===")
  _run(compose_cmd(["ps"]))
  print("\nEndpoints:")
  print(" - API health:  http://localhost:${APP_PORT}/health")
  print(" - Users:       http://localhost:${APP_PORT}/users")
  print(" - Studio:      http://localhost:${STUDIO_PORT} (si el servicio studio está up)")
  return

def down(remove_volumes: bool) -> None:
  _ensure_tools()
  _ensure_env()
  cmd = compose_cmd(["down"])
  if remove_volumes:
    cmd.append("-v")
  cmd += ["--remove-orphans"]
  _run(cmd, "Bajar stack")

def nuke() -> None:
  _ensure_tools()
  _ensure_env()

  cmd = compose_cmd(["down", "-v", "--rmi", "local", "--remove-orphans"])
  _run(cmd, "Reset total (volúmenes + imágenes locales)")
  
def logs(service: Optional[str], tail: int, follow: bool) -> None:
  _ensure_tools()
  _ensure_env()

  extra = ["logs"]
  cmd = compose_cmd(extra)
  if follow:
    cmd.append("-f")
  if service:
    cmd.append(service)
  _run(cmd, "Logs", check=False)
   
def main():
  parser = argparse.ArgumentParser(description="Gestor del proyecto Prisma + Docker.")
  sub = parser.add_subparsers(dest="cmd", required=True)

  up = sub.add_parser("up", help="Levanta el stack (api+db).")
  up.add_argument("--build", action="store_true", help="Build images")

  p_down = sub.add_parser("down", help="Baja el stack.")
  p_down.add_argument("--volumes", action="store_true", help="También elimina volúmenes (-v).")

  nuke = sub.add_parser("nuke", help="Elimina volúmenes e imágenes locales del compose.")

  p_logs = sub.add_parser("logs", help="Muestra logs.")
  p_logs.add_argument("--service", default=None, help="Servicio (api|db|studio).")
  p_logs.add_argument("--tail", type=int, default=200)
  p_logs.add_argument("-f", "--follow", action="store_true")
  
  p_exec = sub.add_parser("exec", help="Ejecuta un comando dentro de un servicio.")
  p_exec.add_argument("service", help="api|db|studio")
  p_exec.add_argument("command", nargs=argparse.REMAINDER, help="Comando a ejecutar (ej: sh -lc 'ls -la').")

  studio = sub.add_parser("studio", help="Levanta Prisma Studio.")

  ps = sub.add_parser("ps", help="Show status")

  args = parser.parse_args()

  copiar_en(ENV_EXAMPLE_FILE, ENV_FILE)

  if args.cmd == "up":
    up(build=args.build)
  elif args.cmd == "down":
    down(remove_volumes=args.volumes)
  elif args.cmd == "nuke":
    nuke() 
  elif args.cmd == "logs":
    logs(service=args.service, tail=args.tail, follow=args.follow)
  elif args.cmd == "exec":
    if not args.command:
      raise SystemExit("Debes indicar un comando. Ej: python3 manage.py exec api sh -lc 'node -v'")
    exec_cmd(args.service, args.command)
  elif args.cmd == "ps":
    _run(compose_cmd(["ps", "-a"]), "Estado de los servicios")
  elif args.cmd == "studio":
    # Start studio service if not running
    _run(compose_cmd(["up", "-d", "studio"]), "Iniciando Prisma Studio")
    print("Studio: http://localhost:${STUDIO_PORT}")

if __name__ == "__main__":
  main()

"""

## 2) Limpieza y levantamiento (para salir del estado actual con errores)

### Paso 0 — Baja el stack actual (y opcionalmente elimina “orphans”)

Como estás trabajando en un folder que ya tenía otros contenedores (`prisma_test-nginx-1`, `prisma_test-app-1`), te aparecen como “orphans”. Si no los necesitas, límpialos.

```bash
cd ~/prisma_test

sudo docker compose down --remove-orphans
# si quieres borrar volúmenes (reinicio total):
# sudo docker compose down --remove-orphans -v
```

### Paso 1 — Levanta reconstruyendo (con tu script)

```bash
sudo python3 manage.py up --build
```

### Paso 2 — Valida logs (ya no debe aparecer P1012)

```bash
sudo docker compose logs -f api
sudo docker compose logs -f studio
```

---

## 3) Validación del CRUD de User (rápida por cURL)

Asumiendo que tu API expone rutas típicas:

### Health

```bash
curl -s http://localhost:3000/health
```

### Crear usuario

```bash
curl -s -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","name":"Test User"}'
```

### Listar usuarios

```bash
curl -s http://localhost:3000/users
```

### Actualizar usuario (ejemplo id=1)

```bash
curl -s -X PUT http://localhost:3000/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Nuevo Nombre"}'
```

### Eliminar usuario (ejemplo id=1)

```bash
curl -s -X DELETE http://localhost:3000/users/1
```

---

## 4) Prisma Studio (y firewall)

Tu contenedor Studio expone `5555`. Si quieres verlo remotamente:

* Opción A: abrir puerto (no recomendado en internet sin restricción)

```bash
sudo ufw allow 5555/tcp
```

* Opción B (recomendada): túnel SSH desde tu PC

```bash
ssh -L 5555:localhost:5555 saidc@<IP_SERVIDOR>
```

Luego en tu navegador local: `http://localhost:5555`


_________________________________________________________________________________
"""

"""
    ## Cómo levantar y bajar (paso a paso)

    ### 1) Descomprimir y preparar `.env`

        ```bash
        unzip prisma-docker-basic.zip
        cd prisma-docker-basic
        cp .env.example .env
        ```

        Revisa en `.env` (por defecto ya está correcto para Docker Compose):

        * `DATABASE_URL=postgresql://app:app@db:5432/app?schema=public`

    ### 2) Levantar el stack (build + up)

        ```bash
        sudo python3 manage.py up --build
        ```

        Prueba:

        * `http://localhost:3000/health`

    ### 3) Probar el CRUD

        Crear:

        ```bash
        curl -X POST http://localhost:3000/users \
        -H "Content-Type: application/json" \
        -d '{"email":"test@example.com","name":"Test User"}'
        ```

        Listar:

        ```bash
        curl http://localhost:3000/users
        ```

        Actualizar:

        ```bash
        curl -X PUT http://localhost:3000/users/1 \
        -H "Content-Type: application/json" \
        -d '{"name":"Nuevo Nombre"}'
        ```

        Eliminar:

        ```bash
        curl -X DELETE http://localhost:3000/users/1
        ```

    ### 4) Prisma Studio (opcional)

        ```bash
        python3 manage.py studio
        ```

        Abrir: `http://localhost:5555`

    ### 5) Bajar el stack

        Sin borrar datos:

        ```bash
        python3 manage.py down
        ```

        Borrando datos (volúmenes):

        ```bash
        python3 manage.py down --volumes
        ```

        Reset “fuerte” (volúmenes + imágenes locales del compose):

        ```bash
        python3 manage.py nuke
        ```
"""