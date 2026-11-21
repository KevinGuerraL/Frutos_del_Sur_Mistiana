"""VISTA: Tarea 1 - Registro de retiro."""
import tkinter as tk
from tkinter import messagebox, ttk

from app.controllers import catalogos_controller as cat
from app.controllers import retiro_controller as ctl
from app.controllers.utils import hoy
from app.views.widgets import ComboMap, DataTable, guard, labeled


class RetirosView(ttk.Frame):
    def __init__(self, parent):
        super().__init__(parent, padding=8)
        self.lineas = []
        self.fecha = tk.StringVar(value=hoy())
        self.cantidad = tk.StringVar()

        f = ttk.LabelFrame(self, text="Nuevo retiro de campo (lunes, jueves o sábado)", padding=6)
        f.pack(fill="x")
        labeled(f, "Fecha", ttk.Entry(f, textvariable=self.fecha, width=12), 0, 0)
        self.cb_productor = labeled(f, "Productor", ComboMap(f, width=36), 0, 2)
        self.cb_producto = labeled(f, "Producto", ComboMap(f, width=16), 1, 0)
        self.cb_producto.bind("<<ComboboxSelected>>", lambda _e: self._cargar_calidades())
        self.cb_calidad = labeled(f, "Calidad", ComboMap(f, width=22), 1, 2)
        labeled(f, "Cantidad", ttk.Entry(f, textvariable=self.cantidad, width=10), 1, 4)
        ttk.Button(f, text="Agregar línea", command=self.agregar).grid(row=1, column=6, padx=6)

        self.tabla_lineas = DataTable(self, height=4)
        self.tabla_lineas.pack(fill="x", pady=4)
        b = ttk.Frame(self)
        b.pack(fill="x")
        ttk.Button(b, text="Quitar línea seleccionada", command=self.quitar).pack(side="left")
        ttk.Button(b, text="REGISTRAR RETIRO", command=self.registrar).pack(side="right")

        g = ttk.LabelFrame(self, text="Retiros registrados", padding=6)
        g.pack(fill="both", expand=True, pady=(8, 0))
        self.tabla = DataTable(g, height=7)
        self.tabla.pack(fill="both", expand=True)
        self.tabla.on_select(self._ver_detalle)
        self.tabla_detalle = DataTable(g, height=5)
        self.tabla_detalle.pack(fill="both", expand=True, pady=4)
        ttk.Button(g, text="Eliminar retiro seleccionado", command=self.eliminar).pack(anchor="e")

    def refresh(self):
        self.cb_productor.set_items([(p["id_productor"], f"{p['id_productor']} - {p['nombre']}")
                                     for p in cat.productores()])
        self.cb_producto.set_items([(p["cod_producto"], f"{p['nombre_producto']} ({p['unidad_medida']})")
                                    for p in cat.productos()])
        self.tabla.load(ctl.listar())

    def _cargar_calidades(self):
        self.cb_calidad.set_items([(c["nombre_calidad"], f"{c['nombre_calidad']} (ref. S/ {c['precio_referencia']})")
                                   for c in cat.calidades(self.cb_producto.key())])

    def agregar(self):
        ok, linea = guard(ctl.armar_linea, self.cb_producto.key(), self.cb_calidad.key(),
                          self.cantidad.get(), self.lineas)
        if ok:
            linea["producto"] = self.cb_producto.get()
            self.lineas.append(linea)
            self.cantidad.set("")
            self._pintar()

    def quitar(self):
        sel = self.tabla_lineas.selected()
        if sel:
            self.lineas = [l for l in self.lineas
                           if not (l["producto"] == sel["producto"] and l["nombre_calidad"] == sel["calidad"])]
            self._pintar()

    def _pintar(self):
        self.tabla_lineas.load([{"producto": l["producto"], "calidad": l["nombre_calidad"],
                                 "cantidad": l["cantidad"]} for l in self.lineas])

    def registrar(self):
        ok, codigo = guard(ctl.registrar, self.fecha.get(), self.cb_productor.key(), self.lineas)
        if ok:
            messagebox.showinfo("Retiro registrado", f"Se registró el retiro {codigo}.")
            self.lineas = []
            self._pintar()
            self.tabla.load(ctl.listar())

    def _ver_detalle(self):
        sel = self.tabla.selected()
        if sel:
            self.tabla_detalle.load(ctl.detalle(sel["id_retiro"]))

    def eliminar(self):
        sel = self.tabla.selected()
        if sel and messagebox.askyesno("Confirmar", f"¿Eliminar el retiro {sel['id_retiro']}?"):
            ok, _ = guard(ctl.eliminar, sel["id_retiro"])
            if ok:
                self.tabla_detalle.load([])
                self.tabla.load(ctl.listar())
