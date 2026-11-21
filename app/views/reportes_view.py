"""VISTA: stock, cierre del dia (Tarea 4) y consultas SQL."""
import tkinter as tk
from tkinter import ttk

from app.controllers import reporte_controller as ctl
from app.controllers.utils import hoy
from app.views.widgets import ComboMap, DataTable, fmt, guard


class StockView(ttk.Frame):
    def __init__(self, parent):
        super().__init__(parent, padding=8)
        ttk.Label(self, text="Stock disponible por producto y calidad (comprado - vendido)",
                  font=("", 11, "bold")).pack(anchor="w")
        self.tabla = DataTable(self, height=18)
        self.tabla.pack(fill="both", expand=True, pady=6)
        ttk.Button(self, text="Actualizar", command=self.refresh).pack(anchor="e")

    def refresh(self):
        self.tabla.load(ctl.stock())


class CierreView(ttk.Frame):
    def __init__(self, parent):
        super().__init__(parent, padding=8)
        self.fecha = tk.StringVar(value=hoy())
        top = ttk.Frame(self)
        top.pack(fill="x")
        ttk.Label(top, text="Fecha del cierre").pack(side="left")
        ttk.Entry(top, textvariable=self.fecha, width=12).pack(side="left", padx=6)
        ttk.Button(top, text="Calcular cierre", command=self.refresh).pack(side="left")
        self.resumen = ttk.Label(self, justify="left", font=("", 11))
        self.resumen.pack(anchor="w", pady=10)
        self.tabla = DataTable(self, height=14)
        self.tabla.pack(fill="both", expand=True)

    def refresh(self):
        ok, res = guard(ctl.cierre, self.fecha.get())
        if ok:
            r, notas = res
            self.resumen.config(text=(
                f"Notas emitidas: {r['notas']}\n"
                f"Importe total vendido: S/ {fmt(r['ventas_totales'])}\n"
                f"   • Al contado (monto a transferir): S/ {fmt(r['a_transferir_contado'])}\n"
                f"   • A crédito (pendiente de cobro): S/ {fmt(r['pendiente_credito'])}\n"
                f"Pagado/por pagar a productores ese día: S/ {fmt(r['compras_del_dia'])}"))
            self.tabla.load(notas)


class ConsultasView(ttk.Frame):
    def __init__(self, parent):
        super().__init__(parent, padding=8)
        top = ttk.Frame(self)
        top.pack(fill="x")
        self.cb = ComboMap(top, width=80)
        self.cb.pack(side="left")
        ttk.Button(top, text="Ejecutar", command=self.ejecutar).pack(side="left", padx=6)
        self.lbl = ttk.Label(self, text="")
        self.lbl.pack(anchor="w")
        self.sql = tk.Text(self, height=8, font=("Courier", 9))
        self.sql.pack(fill="x", pady=4)
        self.tabla = DataTable(self, height=14)
        self.tabla.pack(fill="both", expand=True)
        self.consultas = []

    def refresh(self):
        if not self.consultas:
            ok, c = guard(ctl.consultas)
            if ok:
                self.consultas = c
                self.cb.set_items([(i, t) for i, (t, _) in enumerate(c)])

    def ejecutar(self):
        i = self.cb.key()
        if i is None:
            return
        sql = self.consultas[i][1]
        self.sql.delete("1.0", "end")
        self.sql.insert("1.0", sql)
        ok, filas = guard(ctl.ejecutar, sql)
        if ok:
            self.tabla.load(filas)
            self.lbl.config(text=f"{len(filas)} fila(s)")
