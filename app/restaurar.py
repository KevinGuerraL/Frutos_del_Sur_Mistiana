"""Restablece la base de datos al estado de frutos_sur_backup.sql (volcado de pg_dump en texto).

ADVERTENCIA: borra TODO el esquema public de la base configurada y lo recrea desde el respaldo.
Todo se hace en una sola transaccion: si algo falla, la base queda como estaba.
"""
import io
import re

import psycopg2

from config import BASE_DIR, DB, RESOURCE_DIR

NOMBRE_RESPALDO = "frutos_sur_backup.sql"
BASES_PROTEGIDAS = {"postgres", "template0", "template1"}

_COPY = re.compile(r"^COPY .+ FROM stdin;\s*$")
# Lineas del volcado que no se pueden/deben ejecutar con psycopg2:
#  - metacomandos de psql (\restrict, \unrestrict, \connect ...)
#  - SET transaction_timeout (no existe antes de PostgreSQL 17)
#  - ALTER ... OWNER TO (los objetos quedan a nombre del usuario que se conecta)
_IGNORAR = re.compile(r"^(\\(?!\.)|SET transaction_timeout|ALTER .+ OWNER TO )")


def _hay_sentencia(texto):
    """True si el texto tiene algo mas que lineas en blanco y comentarios (-- ...)."""
    return any(l.strip() and not l.strip().startswith("--") for l in texto.splitlines())


def ruta_respaldo():
    """Primero un respaldo junto al .exe (permite reemplazarlo); si no, el incluido en el programa."""
    for p in (BASE_DIR / NOMBRE_RESPALDO, RESOURCE_DIR / "database" / NOMBRE_RESPALDO):
        if p.exists():
            return p
    raise FileNotFoundError(f"No se encontro {NOMBRE_RESPALDO}")


def trocear(texto):
    """Divide el volcado en pasos: ('sql', texto) o ('copy', sentencia_copy, datos)."""
    pasos, buf, datos, copy_sql = [], [], None, None
    for linea in texto.splitlines(keepends=True):
        if datos is not None:                       # dentro de un bloque COPY
            if linea.rstrip("\r\n") == "\\.":
                pasos.append(("copy", copy_sql, "".join(datos)))
                datos = None
            else:
                datos.append(linea)
            continue
        if _COPY.match(linea):
            if _hay_sentencia("".join(buf)):
                pasos.append(("sql", "".join(buf)))
            buf = []
            copy_sql = linea.strip().rstrip(";")
            datos = []
            continue
        if _IGNORAR.match(linea):
            continue
        buf.append(linea)
    if datos is not None:
        raise ValueError("El respaldo termina dentro de un bloque COPY (archivo incompleto).")
    if _hay_sentencia("".join(buf)):
        pasos.append(("sql", "".join(buf)))
    return pasos


def restablecer():
    """Borra el esquema public de la base configurada y la restaura desde el respaldo."""
    if DB["dbname"].lower() in BASES_PROTEGIDAS:
        raise RuntimeError(f"Por seguridad no se restablece la base '{DB['dbname']}'.")
    pasos = trocear(ruta_respaldo().read_text(encoding="utf-8"))
    conn = psycopg2.connect(**DB)
    try:
        with conn.cursor() as cur:
            cur.execute("DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;")
            for paso in pasos:
                if paso[0] == "sql":
                    cur.execute(paso[1])
                else:
                    cur.copy_expert(paso[1], io.StringIO(paso[2]))
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
