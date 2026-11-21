"""Configuracion de la conexion. Lee config.ini; las variables de entorno
PGHOST, PGPORT, PGDATABASE, PGUSER y PGPASSWORD tienen prioridad."""
import configparser
import os
import sys
from pathlib import Path

# BASE_DIR: carpeta donde viven config.ini, audit_logs y el log (junto al .exe si esta empaquetado).
# RESOURCE_DIR: recursos incluidos dentro del ejecutable (database/queries.sql).
if getattr(sys, "frozen", False):
    BASE_DIR = Path(sys.executable).resolve().parent
    RESOURCE_DIR = Path(getattr(sys, "_MEIPASS", BASE_DIR))
else:
    BASE_DIR = Path(__file__).resolve().parent
    RESOURCE_DIR = BASE_DIR
_cfg = configparser.ConfigParser()
_cfg.read(BASE_DIR / "config.ini", encoding="utf-8")
_s = _cfg["postgresql"] if _cfg.has_section("postgresql") else {}


def _get(key, env, default):
    return os.environ.get(env, _s.get(key, default))


DB = {
    "host": _get("host", "PGHOST", "localhost"),
    "port": int(_get("port", "PGPORT", "5432")),
    "dbname": _get("dbname", "PGDATABASE", "frutos_sur_mistiana"),
    "user": _get("user", "PGUSER", "postgres"),
    "password": _get("password", "PGPASSWORD", ""),
}


# Si es True, al abrir la aplicacion se BORRA el esquema public de la base configurada y se
# restaura desde frutos_sur_backup.sql. Se desactiva con restablecer_al_iniciar = no
# en la seccion [opciones] de config.ini (o con la variable FRUTOS_REINICIAR=no).
_o = _cfg["opciones"] if _cfg.has_section("opciones") else {}
REINICIAR = str(os.environ.get("FRUTOS_REINICIAR", _o.get("restablecer_al_iniciar", "si"))
                ).strip().lower() in ("si", "sí", "s", "1", "true", "yes")
