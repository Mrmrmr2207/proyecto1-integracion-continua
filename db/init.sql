-- Esquema inicial de la base de datos de tareas
-- Se ejecuta automáticamente al crear el volumen de PostgreSQL

CREATE TABLE IF NOT EXISTS tareas (
    id          SERIAL PRIMARY KEY,
    titulo      VARCHAR(255) NOT NULL,
    completada  BOOLEAN NOT NULL DEFAULT FALSE,
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO tareas (titulo, completada) VALUES
    ('Configurar repositorio en GitHub', TRUE),
    ('Escribir docker-compose.yml', FALSE),
    ('Documentar arquitectura en el README', FALSE);
