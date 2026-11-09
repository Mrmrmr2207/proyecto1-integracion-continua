"""API REST de tareas — Integración Continua, Proyecto 1 (Politécnico Grancolombiano)."""

import os
import time
from datetime import datetime, timezone

from flask import Flask, jsonify, request
import psycopg2
from psycopg2.extras import RealDictCursor

app = Flask(__name__)

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://tareas_user:tareas_pass@db:5432/tareas_db",
)


def get_connection(retries: int = 10, delay: float = 2.0):
    """Obtiene una conexión a PostgreSQL con reintentos (espera a que el contenedor db esté listo)."""
    last_error = None
    for attempt in range(1, retries + 1):
        try:
            conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
            return conn
        except psycopg2.OperationalError as exc:
            last_error = exc
            app.logger.warning(
                "Intento %s/%s: base de datos no disponible (%s). Reintentando...",
                attempt,
                retries,
                exc,
            )
            time.sleep(delay)
    raise RuntimeError(f"No se pudo conectar a PostgreSQL: {last_error}") from last_error


@app.get("/health")
def health():
    """Verifica que la API y la base de datos respondan."""
    db_ok = False
    db_error = None
    try:
        with get_connection(retries=3, delay=1.0) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1 AS ok;")
                row = cur.fetchone()
                db_ok = bool(row and row["ok"] == 1)
    except Exception as exc:  # noqa: BLE001 — devolvemos el error en el healthcheck
        db_error = str(exc)

    status = "ok" if db_ok else "degraded"
    code = 200 if db_ok else 503
    payload = {
        "status": status,
        "service": "api-tareas",
        "database": "up" if db_ok else "down",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    if db_error:
        payload["database_error"] = db_error
    return jsonify(payload), code


@app.get("/tareas")
def listar_tareas():
    """Lista todas las tareas almacenadas en PostgreSQL."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, titulo, completada, creado_en
                FROM tareas
                ORDER BY id ASC;
                """
            )
            rows = cur.fetchall()
    return jsonify({"tareas": [dict(r) for r in rows], "total": len(rows)}), 200


@app.post("/tareas")
def crear_tarea():
    """Crea una nueva tarea. Body JSON: {"titulo": "..." }."""
    data = request.get_json(silent=True) or {}
    titulo = (data.get("titulo") or "").strip()
    if not titulo:
        return jsonify({"error": "El campo 'titulo' es obligatorio"}), 400

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO tareas (titulo, completada)
                VALUES (%s, FALSE)
                RETURNING id, titulo, completada, creado_en;
                """,
                (titulo,),
            )
            row = cur.fetchone()
        conn.commit()

    return jsonify(dict(row)), 201


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=False)
