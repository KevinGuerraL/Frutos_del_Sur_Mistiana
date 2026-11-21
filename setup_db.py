"""Crea la base de datos, las tablas, la vista y (opcional) los datos de prueba.

ADVERTENCIA: este script puede crear o destruir estructuras. No ejecutarlo contra una base
existente que se deba conservar. --reset elimina el esquema public completo.

Uso:
    python setup_db.py              # crea todo (si la BD ya existe, no la toca)
    python setup_db.py --reset      # BORRA y recrea las tablas de la BD
    python setup_db.py --sin-datos  # crea solo la estructura, sin datos de prueba
"""
import sys
from pathlib import Path

import psycopg2
from psycopg2 import sql

from config import DB

SQL_DIR = Path(__file__).resolve().parent / "database"


def run_file(cur, name):
    cur.execute((SQL_DIR / name).read_text(encoding="utf-8"))
    print(f"  ejecutado: {name}")


def main():
    reset = "--reset" in sys.argv
    sin_datos = "--sin-datos" in sys.argv
    dbname = DB["dbname"]

    # 1) Crear la base de datos si no existe (se conecta a la BD 'postgres')
    admin = psycopg2.connect(**{**DB, "dbname": "postgres"})
    admin.autocommit = True
    with admin.cursor() as cur:
        cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (dbname,))
        if cur.fetchone() is None:
            cur.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(dbname)))
            print(f"Base de datos '{dbname}' creada.")
        else:
            print(f"La base de datos '{dbname}' ya existe.")
    admin.close()

    # 2) Crear tablas, vista y datos
    conn = psycopg2.connect(**DB)
    with conn, conn.cursor() as cur:
        if reset:
            cur.execute("DROP SCHEMA public CASCADE; CREATE SCHEMA public;")
            print("  esquema anterior eliminado (--reset)")
        else:
            cur.execute("SELECT to_regclass('public.productor')")
            if cur.fetchone()[0] is not None:
                print("Las tablas ya existen. Usa --reset si quieres recrearlas.")
                return
        run_file(cur, "schema.sql")
        if not sin_datos:
            run_file(cur, "seed.sql")
    conn.close()
    print("Listo. Ahora ejecuta:  python main.py")


if __name__ == "__main__":
    main()
