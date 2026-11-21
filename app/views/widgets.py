"""VISTA: componentes reutilizables (tabla, combo con claves, manejo de errores)."""
import tkinter as tk
import logging
from decimal import Decimal
from tkinter import messagebox, ttk

from app.errors import AppError


def fmt(v):
    if v is None:
        return ""
    if isinstance(v, bool):
        return "Sí" if v else "No"
    if isinstance(v, Decimal):
        return f"{v:,.2f}"
    return str(v)


def guard(fn, *args, **kwargs):
    """Ejecuta una accion del controlador y muestra los errores al usuario.
    Devuelve (exito, resultado)."""
    try:
        return True, fn(*args, **kwargs)
    except AppError as e:
        messagebox.showwarning("Atención", str(e))
    except Exception as e:  # errores de BD u otros
        # Mensaje orientado al usuario; el detalle técnico queda en la consola.
        logging.exception("Error al ejecutar una operación de la aplicación")
        messagebox.showerror("No se pudo completar",
            "No se pudo completar esta operación. Comprueba los datos e inténtalo nuevamente. "
            "Si el problema continúa, contacta al administrador.")
    return False, None


class DataTable(ttk.Frame):
    """Tabla (Treeview) que se llena con una lista de diccionarios."""

    def __init__(self, parent, height=6):
        super().__init__(parent)
        self.tree = ttk.Treeview(self, show="headings", height=height, selectmode="browse")
        sb = ttk.Scrollbar(self, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=sb.set)
        self.tree.pack(side="left", fill="both", expand=True)
        sb.pack(side="right", fill="y")
        self._rows = {}

    def load(self, rows):
        self.tree.delete(*self.tree.get_children())
        self._rows = {}
        if rows:
            cols = list(rows[0].keys())
            self.tree["columns"] = cols
            for c in cols:
                self.tree.heading(c, text=c.replace("_", " ").capitalize())
                self.tree.column(c, width=110, anchor="w", stretch=True)
            for r in rows:
                iid = self.tree.insert("", "end", values=[fmt(r[c]) for c in cols])
                self._rows[iid] = r

    def selected(self):
        sel = self.tree.selection()
        return self._rows.get(sel[0]) if sel else None

    def on_select(self, callback):
        self.tree.bind("<<TreeviewSelect>>", lambda _e: callback())


class ComboMap(ttk.Combobox):
    """Combobox que muestra una etiqueta pero devuelve una clave (p. ej. el id)."""

    def __init__(self, parent, **kw):
        super().__init__(parent, state="readonly", **kw)
        self._keys = []

    def set_items(self, pairs):
        keys = [k for k, _ in pairs]
        labels = [lbl for _, lbl in pairs]
        if keys == self._keys and list(self["values"]) == labels:
            return  # sin cambios: conserva la seleccion actual
        self._keys = keys
        self["values"] = labels
        self.set("")

    def key(self):
        i = self.current()
        return self._keys[i] if i >= 0 else None


def labeled(parent, text, widget, row, col):
    ttk.Label(parent, text=text).grid(row=row, column=col, sticky="e", padx=(8, 2), pady=2)
    widget.grid(row=row, column=col + 1, sticky="w", padx=(0, 6), pady=2)
    return widget
