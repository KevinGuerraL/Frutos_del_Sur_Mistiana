"""VISTA: Tarea 3 - Asignacion y reparto a clientes (nota de pedido)."""
import tkinter as tk
from decimal import Decimal
from tkinter import filedialog, messagebox, ttk

from app.controllers import catalogos_controller as cat
from app.controllers import pedido_controller as ctl
from app.controllers.utils import hoy
from app.views.widgets import ComboMap, DataTable, guard, labeled


class PedidosView(ttk.Frame):
    def __init__(self, parent):
        super().__init__(parent, padding=8)
        self.lineas, self.firma_ruta = [], None
        self.fecha, self.cantidad, self.precio = tk.StringVar(value=hoy()), tk.StringVar(), tk.StringVar()
        self.unidad, self.lbl_stock, self.lbl_firma = tk.StringVar(value="Kilos"), tk.StringVar(), tk.StringVar(value="sin firma")

        f = ttk.LabelFrame(self, text="Nueva nota de pedido", padding=6)
        f.pack(fill="x")
        labeled(f, "Fecha", ttk.Entry(f, textvariable=self.fecha, width=12), 0, 0)
        self.cb_cliente = labeled(f, "Cliente", ComboMap(f, width=30), 0, 2)
        self.cb_hoja = labeled(f, "Se abastece de", ComboMap(f, width=22), 0, 4)
        self.cb_modalidad = labeled(f, "Pago", ComboMap(f, width=10), 1, 0)
        self.cb_modalidad.set_items([(m, m) for m in ctl.MODALIDADES])
        ttk.Button(f, text="Adjuntar firma (imagen)", command=self.elegir_firma).grid(row=1, column=2, sticky="e")
        ttk.Label(f, textvariable=self.lbl_firma).grid(row=1, column=3, sticky="w")

        l = ttk.LabelFrame(self, text="Líneas de la nota", padding=6)
        l.pack(fill="x", pady=6)
        self.cb_producto = labeled(l, "Producto", ComboMap(l, width=16), 0, 0)
        self.cb_producto.bind("<<ComboboxSelected>>", lambda _e: self._producto())
        self.cb_calidad = labeled(l, "Calidad", ComboMap(l, width=14), 0, 2)
        self.cb_calidad.bind("<<ComboboxSelected>>", lambda _e: self._stock())
        ttk.Label(l, textvariable=self.lbl_stock, foreground="#a00").grid(row=0, column=4, columnspan=3, sticky="w")
        labeled(l, "Unidad", ttk.Combobox(l, textvariable=self.unidad, values=["Cajas", "Kilos"],
                                          state="readonly", width=7), 1, 0)
        labeled(l, "Cantidad", ttk.Entry(l, textvariable=self.cantidad, width=9), 1, 2)
        labeled(l, "Precio unit. S/", ttk.Entry(l, textvariable=self.precio, width=9), 1, 4)
        ttk.Button(l, text="Agregar línea", command=self.agregar).grid(row=1, column=6, padx=6)

        self.tabla_lineas = DataTable(self, height=4)
        self.tabla_lineas.pack(fill="x")
        b = ttk.Frame(self)
        b.pack(fill="x", pady=4)
        ttk.Button(b, text="Quitar línea seleccionada", command=self.quitar).pack(side="left")
        self.lbl_total = ttk.Label(b, text="Total: S/ 0.00", font=("", 11, "bold"))
        self.lbl_total.pack(side="left", padx=20)
        ttk.Button(b, text="REGISTRAR NOTA DE PEDIDO", command=self.registrar).pack(side="right")

        g = ttk.LabelFrame(self, text="Notas de pedido emitidas", padding=6)
        g.pack(fill="both", expand=True)
        self.tabla = DataTable(g, height=6)
        self.tabla.pack(fill="both", expand=True)
        self.tabla.on_select(self._detalle)
        self.detalle = DataTable(g, height=4)
        self.detalle.pack(fill="both", expand=True, pady=4)
        ttk.Button(g, text="Eliminar nota seleccionada", command=self.eliminar).pack(anchor="e")

    def refresh(self):
        self.cb_cliente.set_items([(c["id_cliente"], f"{c['id_cliente']} - {c['nombre']}") for c in cat.clientes()])
        self.cb_hoja.set_items([(h["id_compra"], f"{h['id_compra']} ({h['fecha']})") for h in ctl.hojas()])
        self.cb_producto.set_items([(p["cod_producto"], p["nombre_producto"]) for p in cat.productos()])
        self._unidades = {p["cod_producto"]: p["unidad_medida"] for p in cat.productos()}
        self.tabla.load(ctl.listar())

    def _producto(self):
        cod = self.cb_producto.key()
        self.cb_calidad.set_items([(c["nombre_calidad"], c["nombre_calidad"]) for c in cat.calidades(cod)])
        self.unidad.set("Cajas" if self._unidades.get(cod) == "Caja" else "Kilos")
        self.lbl_stock.set("")

    def _stock(self):
        self.lbl_stock.set(ctl.stock_texto(self.cb_producto.key(), self.cb_calidad.key()))

    def elegir_firma(self):
        ruta = filedialog.askopenfilename(title="Imagen de la firma",
                                          filetypes=[("Imágenes", "*.png *.jpg *.jpeg"), ("Todos", "*.*")])
        if ruta:
            self.firma_ruta = ruta
            self.lbl_firma.set(ruta.split("/")[-1].split("\\")[-1])

    def agregar(self):
        ok, linea = guard(ctl.armar_linea, self.cb_producto.key(), self.cb_calidad.key(), self.unidad.get(),
                          self.cantidad.get(), self.precio.get(), self.lineas)
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
        filas, total = [], Decimal(0)
        for l in self.lineas:
            cant = l["cajas"] if l["cajas"] is not None else l["kilos"]
            sub = Decimal(cant) * l["precio_unitario"]
            total += sub
            filas.append({"producto": l["producto"], "calidad": l["nombre_calidad"], "cajas": l["cajas"],
                          "kilos": l["kilos"], "precio_unitario": l["precio_unitario"], "subtotal": sub})
        self.tabla_lineas.load(filas)
        self.lbl_total.config(text=f"Total: S/ {total:,.2f}")

    def registrar(self):
        ok, firma = guard(ctl.leer_firma, self.firma_ruta)
        if not ok:
            return
        ok, numero = guard(ctl.registrar, self.fecha.get(), self.cb_modalidad.key(), self.cb_hoja.key(),
                           self.cb_cliente.key(), self.lineas, firma)
        if ok:
            messagebox.showinfo("Nota registrada", f"Nota de pedido N° {numero:06d} registrada.")
            self.lineas, self.firma_ruta = [], None
            self.lbl_firma.set("sin firma")
            self._pintar()
            self.refresh()
            self._stock()

    def _detalle(self):
        sel = self.tabla.selected()
        if sel:
            self.detalle.load(ctl.detalle(sel["numero_compra"]))

    def eliminar(self):
        sel = self.tabla.selected()
        if sel and messagebox.askyesno("Confirmar", f"¿Eliminar la nota {sel['numero_compra']}?"):
            ok, _ = guard(ctl.eliminar, sel["numero_compra"])
            if ok:
                self.detalle.load([])
                self.refresh()
