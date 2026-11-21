"""VISTA: Tarea 2 - Monitoreo de stock (hoja de control de compras)."""
from tkinter import messagebox, simpledialog, ttk

from app.controllers import compra_controller as ctl
from app.views.widgets import ComboMap, DataTable, guard


class ComprasView(ttk.Frame):
    def __init__(self, parent):
        super().__init__(parent, padding=8)
        f = ttk.LabelFrame(self, text="Digitalizar un retiro en la hoja de control de compras", padding=6)
        f.pack(fill="x")
        ttk.Label(f, text="Retiro pendiente").pack(side="left")
        self.cb = ComboMap(f, width=50)
        self.cb.pack(side="left", padx=6)
        ttk.Button(f, text="Generar hoja de control", command=self.generar).pack(side="left")
        ttk.Label(f, text="(usa el precio de referencia de cada calidad; puedes corregirlo abajo)").pack(side="left", padx=8)

        g = ttk.LabelFrame(self, text="Hojas de control de compra", padding=6)
        g.pack(fill="both", expand=True, pady=8)
        self.tabla = DataTable(g, height=8)
        self.tabla.pack(fill="both", expand=True)
        self.tabla.on_select(self._detalle)
        self.detalle = DataTable(g, height=7)
        self.detalle.pack(fill="both", expand=True, pady=4)
        ttk.Button(g, text="Cambiar precio de la línea seleccionada", command=self.cambiar_precio).pack(anchor="e")

    def refresh(self):
        self.cb.set_items([(r["id_retiro"], f"{r['id_retiro']} - {r['fecha']} - {r['productor']}")
                           for r in ctl.retiros_pendientes()])
        self.tabla.load(ctl.hojas())

    def generar(self):
        ok, codigo = guard(ctl.generar_hoja, self.cb.key())
        if ok:
            messagebox.showinfo("Hoja generada", f"Se creó la hoja de control {codigo}.")
            self.cb.set_items([])
            self.refresh()

    def _detalle(self):
        sel = self.tabla.selected()
        if sel:
            self.detalle.load(ctl.detalle(sel["id_compra"]))

    def cambiar_precio(self):
        hoja, linea = self.tabla.selected(), self.detalle.selected()
        if not hoja or not linea:
            messagebox.showinfo("Atención", "Selecciona una hoja y una línea de su detalle.")
            return
        nuevo = simpledialog.askstring("Cambiar precio", f"Nuevo precio para {linea['nombre_producto']} "
                                       f"{linea['nombre_calidad']} (S/):", parent=self)
        if nuevo:
            ok, _ = guard(ctl.cambiar_precio, hoja["id_compra"], linea["cod_producto"],
                          linea["nombre_calidad"], nuevo)
            if ok:
                self.refresh()
                self.detalle.load(ctl.detalle(hoja["id_compra"]))
