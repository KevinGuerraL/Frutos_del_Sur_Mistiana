"""VISTA: mantenimiento de productores, clientes, productos y calidades."""
import tkinter as tk
from tkinter import messagebox, ttk

from app.controllers import catalogos_controller as ctl
from app.views.widgets import DataTable, guard, labeled


class CatalogosView(ttk.Frame):
    def __init__(self, parent):
        super().__init__(parent, padding=8)
        nb = ttk.Notebook(self)
        nb.pack(fill="both", expand=True)
        self.p = self._productores(nb)
        self.c = self._clientes(nb)
        self.pr = self._productos(nb)

    # --- Productores ---
    def _productores(self, nb):
        fr = ttk.Frame(nb, padding=8)
        nb.add(fr, text="Productores")
        self.v_pn = tk.StringVar()
        labeled(fr, "Nombre", ttk.Entry(fr, textvariable=self.v_pn, width=36), 0, 0)
        self.cb_region = labeled(fr, "Región", ttk.Combobox(fr, values=ctl.REGIONES, state="readonly", width=12), 0, 2)
        ttk.Button(fr, text="Agregar", command=self.add_productor).grid(row=0, column=4, padx=6)
        t = DataTable(fr, height=14)
        t.grid(row=1, column=0, columnspan=6, sticky="nsew", pady=6)
        ttk.Button(fr, text="Eliminar seleccionado", command=lambda: self._del(t, "id_productor", ctl.eliminar_productor)
                   ).grid(row=2, column=4, sticky="e")
        return t

    def add_productor(self):
        ok, cod = guard(ctl.nuevo_productor, self.v_pn.get(), self.cb_region.get())
        if ok:
            self.v_pn.set("")
            self.refresh()

    # --- Clientes ---
    def _clientes(self, nb):
        fr = ttk.Frame(nb, padding=8)
        nb.add(fr, text="Clientes")
        self.v_cn, self.v_cd, self.v_ct = tk.StringVar(), tk.StringVar(), tk.StringVar()
        labeled(fr, "Nombre", ttk.Entry(fr, textvariable=self.v_cn, width=30), 0, 0)
        labeled(fr, "Domicilio", ttk.Entry(fr, textvariable=self.v_cd, width=34), 0, 2)
        labeled(fr, "Teléfono", ttk.Entry(fr, textvariable=self.v_ct, width=14), 0, 4)
        ttk.Button(fr, text="Agregar", command=self.add_cliente).grid(row=0, column=6, padx=6)
        t = DataTable(fr, height=14)
        t.grid(row=1, column=0, columnspan=8, sticky="nsew", pady=6)
        ttk.Button(fr, text="Eliminar seleccionado", command=lambda: self._del(t, "id_cliente", ctl.eliminar_cliente)
                   ).grid(row=2, column=6, sticky="e")
        return t

    def add_cliente(self):
        ok, _ = guard(ctl.nuevo_cliente, self.v_cn.get(), self.v_cd.get(), self.v_ct.get())
        if ok:
            for v in (self.v_cn, self.v_cd, self.v_ct):
                v.set("")
            self.refresh()

    # --- Productos y calidades ---
    def _productos(self, nb):
        fr = ttk.Frame(nb, padding=8)
        nb.add(fr, text="Productos y calidades")
        self.v_prn, self.v_kg = tk.StringVar(), tk.StringVar(value="10")
        labeled(fr, "Producto", ttk.Entry(fr, textvariable=self.v_prn, width=20), 0, 0)
        self.cb_unidad = labeled(fr, "Unidad", ttk.Combobox(fr, values=ctl.UNIDADES, state="readonly", width=10), 0, 2)
        labeled(fr, "Kg por caja", ttk.Entry(fr, textvariable=self.v_kg, width=7), 0, 4)
        ttk.Button(fr, text="Agregar producto", command=self.add_producto).grid(row=0, column=6, padx=6)
        self.t_prod = DataTable(fr, height=6)
        self.t_prod.grid(row=1, column=0, columnspan=8, sticky="nsew", pady=6)
        self.t_prod.on_select(self._calidades)
        self.v_cal, self.v_precio = tk.StringVar(), tk.StringVar()
        labeled(fr, "Calidad", ttk.Entry(fr, textvariable=self.v_cal, width=16), 2, 0)
        labeled(fr, "Precio ref. S/", ttk.Entry(fr, textvariable=self.v_precio, width=8), 2, 2)
        ttk.Button(fr, text="Guardar calidad (crea o actualiza precio)", command=self.save_calidad
                   ).grid(row=2, column=4, columnspan=3)
        self.t_cal = DataTable(fr, height=7)
        self.t_cal.grid(row=3, column=0, columnspan=8, sticky="nsew", pady=6)
        return self.t_prod

    def add_producto(self):
        ok, _ = guard(ctl.nuevo_producto, self.v_prn.get(), self.cb_unidad.get(), self.v_kg.get())
        if ok:
            self.v_prn.set("")
            self.refresh()

    def _calidades(self):
        sel = self.t_prod.selected()
        self.t_cal.load(ctl.calidades(sel["cod_producto"]) if sel else [])

    def save_calidad(self):
        sel = self.t_prod.selected()
        ok, _ = guard(ctl.guardar_calidad, sel["cod_producto"] if sel else None, self.v_cal.get(), self.v_precio.get())
        if ok:
            self.v_cal.set("")
            self.v_precio.set("")
            self._calidades()

    def _del(self, tabla, campo, accion):
        sel = tabla.selected()
        if sel and messagebox.askyesno("Confirmar", f"¿Eliminar {sel[campo]}?"):
            ok, _ = guard(accion, sel[campo])
            if ok:
                self.refresh()

    def refresh(self):
        self.p.load(ctl.productores())
        self.c.load(ctl.clientes())
        self.pr.load(ctl.productos())
