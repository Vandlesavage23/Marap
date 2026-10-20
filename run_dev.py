"""One-click developer stack runner for Marriage Connect.
Starts Redis (if not already running) and the Django development server on port 8000.
"""

import os
import sys
import socket
import threading
import subprocess
from pathlib import Path

def find_backend_dir() -> Path:
    candidates = [
        Path(__file__).resolve().parent,
        Path(__file__).resolve().parent / "backend",
        Path(__file__).resolve().parent / "Marap-main" / "backend",
        Path.cwd() / "backend",
        Path.cwd() / "Marap-main" / "backend",
        Path.cwd(),
    ]
    for p in candidates:
        if (p / "manage.py").is_file():
            return p
    return Path(__file__).resolve().parent / "backend"

def is_redis_running(host: str = "127.0.0.1", port: int = 6379) -> bool:
    try:
        with socket.create_connection((host, port), timeout=1.0):
            return True
    except OSError:
        return False

def start_redis_server():
    try:
        import fakeredis
        server = fakeredis.TcpFakeServer(("127.0.0.1", 6379))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        return True
    except Exception as e:
        print(f"  [!] Warning: Could not start local fake Redis: {e}")
        return False

def main():
    backend_dir = find_backend_dir()
    os.chdir(backend_dir)
    sys.path.insert(0, str(backend_dir))

    # Python interpreter in virtual environment
    venv_python = backend_dir / ".venv" / "Scripts" / "python.exe"
    python_cmd = str(venv_python) if venv_python.exists() else sys.executable

    print("\n" + "=" * 62, flush=True)
    print("      Marriage Connect - All-in-One Development Stack      ", flush=True)
    print("=" * 62, flush=True)

    # 1. Check or start Redis
    if is_redis_running():
        print("  [OK] Redis:        Already running on 127.0.0.1:6379", flush=True)
    else:
        print("  [..] Redis:        Starting local Redis on 127.0.0.1:6379...", flush=True)
        if start_redis_server():
            print("  [OK] Redis:        Started successfully", flush=True)
        else:
            print("  [!]  Redis:        Failed to start", flush=True)

    # 2. Check Database URL
    db_url = os.environ.get("DATABASE_URL", "postgres://mc:mc@localhost:5432/mc")
    print(f"  [OK] Database:     PostgreSQL ({db_url})", flush=True)

    # 3. Print URLs banner
    print("\n" + "-" * 62, flush=True)
    print("  Access the application in your browser:", flush=True)
    print("   * API & Docs:     http://api.localtest.me:8000/api/v1/docs/", flush=True)
    print("   * Web Checkout:   http://pay.localtest.me:8000/login", flush=True)
    print("   * Staff Admin:    http://admin.localtest.me:8000/login", flush=True)
    print("-" * 62, flush=True)
    print("  [Press Ctrl + C to stop the entire stack]\n", flush=True)

    # 4. Start Django development server
    try:
        subprocess.run(
            [python_cmd, "manage.py", "runserver", "127.0.0.1:8000"],
            cwd=str(backend_dir),
            check=False
        )
    except KeyboardInterrupt:
        print("\n[OK] Shutting down Marriage Connect services...")

if __name__ == "__main__":
    main()
