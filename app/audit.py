"""Registro de auditoría de acciones del aplicativo (sin alterar PostgreSQL).
Se almacena en audit_logs/auditoria.jsonl, un registro por evento.
"""
import json, os, getpass
from datetime import datetime
from pathlib import Path
from decimal import Decimal
from config import BASE_DIR

AUDIT_DIR = BASE_DIR / "audit_logs"
AUDIT_FILE = AUDIT_DIR / "auditoria.jsonl"

def _safe(value):
    if isinstance(value, (Decimal,)): return str(value)
    if hasattr(value, "isoformat"): return value.isoformat()
    if isinstance(value, dict): return {str(k): _safe(v) for k,v in value.items()}
    if isinstance(value, (list, tuple)): return [_safe(v) for v in value]
    if value is None or isinstance(value, (str,int,float,bool)): return value
    return str(value)

def registrar_evento(accion, entidad, identificador=None, detalles=None):
    """Append-only audit entry. Logging errors do not interrupt business operations."""
    try:
        AUDIT_DIR.mkdir(parents=True, exist_ok=True)
        evento = {"fecha_hora":datetime.now().astimezone().isoformat(timespec="seconds"),
                  "usuario":getpass.getuser(), "accion":accion, "entidad":entidad,
                  "identificador":_safe(identificador), "detalles":_safe(detalles or {})}
        with AUDIT_FILE.open("a", encoding="utf-8") as f:
            f.write(json.dumps(evento, ensure_ascii=False) + "\n")
    except Exception:
        # Do not turn a completed database operation into an application failure.
        pass

def leer_eventos():
    if not AUDIT_FILE.exists(): return []
    rows=[]
    with AUDIT_FILE.open("r", encoding="utf-8") as f:
        for line in f:
            try: rows.append(json.loads(line))
            except json.JSONDecodeError: continue
    return list(reversed(rows))
