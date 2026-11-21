"""Punto de entrada de Frutos del Sur Mistiana."""
import tkinter as tk
import logging
from pathlib import Path
from tkinter import messagebox
import psycopg2
from config import DB, BASE_DIR, REINICIAR

def main():
    logging.basicConfig(filename=str(BASE_DIR / "frutos_sur.log"),
                        level=logging.ERROR, format="%(asctime)s %(levelname)s %(message)s")
    try:
        psycopg2.connect(**DB).close()
    except Exception as exc:
        logging.exception("Fallo al conectar a PostgreSQL")
        root = tk.Tk(); root.withdraw()
        if isinstance(exc, UnicodeDecodeError):
            causa = ("PostgreSQL rechazó la conexión. Casi siempre es por:\n"
                     "- contraseña o usuario incorrectos,\n"
                     "- o el nombre de la base de datos no existe.\n\n"
                     "Corrígelo con ConfigurarConexion.exe.")
        else:
            causa = str(exc).strip()[:400]
        messagebox.showerror("No se pudo conectar",
            "No fue posible conectar con la base de datos.\n\n" + causa + "\n\n"
            "Comprueba también que PostgreSQL esté iniciado y que servidor y puerto sean correctos.\n"
            "Si continúa, comparte el archivo frutos_sur.log con soporte.")
        root.destroy(); return
    if REINICIAR:
        try:
            from app import restaurar
            restaurar.restablecer()
        except Exception as exc:
            logging.exception("Fallo al restablecer la base desde el respaldo")
            root = tk.Tk(); root.withdraw()
            detalle = "" if isinstance(exc, UnicodeDecodeError) else "\n\n" + str(exc).strip()[:400]
            messagebox.showerror("No se pudo restablecer la base",
                "No fue posible restaurar la base de datos desde frutos_sur_backup.sql. "
                "La base quedo como estaba (la operacion es atomica)." + detalle + "\n\n"
                "Si continua, comparta el archivo frutos_sur.log con soporte.")
            root.destroy(); return
    from app.views.main_window import MainWindow
    MainWindow().mainloop()

if __name__ == "__main__":
    main()
