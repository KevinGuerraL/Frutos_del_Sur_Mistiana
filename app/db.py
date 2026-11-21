"""Acceso a PostgreSQL. Todos los modelos usan get_cursor()."""
from contextlib import contextmanager

import psycopg2
import psycopg2.errors as pgerr
import psycopg2.extras

from app.errors import AppError

from config import DB


@contextmanager
def get_cursor():
    """Abre una transaccion: COMMIT si todo sale bien, ROLLBACK si hay error."""
    conn = psycopg2.connect(**DB)
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        yield cur
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def next_code(cur, table, column, prefix, width=3):
    """Siguiente codigo correlativo, p. ej. RET004 a partir de RET001..RET003."""
    cur.execute(
        f"SELECT COALESCE(MAX(SUBSTRING({column} FROM '[0-9]+$')::int), 0) + 1 AS n FROM {table}"
    )
    return f"{prefix}{cur.fetchone()['n']:0{width}d}"


def baja_logica(tabla, clave, motivo="Eliminado desde la aplicación"):
    """La base no permite DELETE fisico: usa el procedimiento sp_baja_logica."""
    try:
        with get_cursor() as cur:
            cur.execute("CALL sp_baja_logica(%s,%s,%s)", (tabla, str(clave), motivo))
    except pgerr.RaiseException as e:
        raise AppError(e.diag.message_primary or "No se pudo dar de baja el registro.")
