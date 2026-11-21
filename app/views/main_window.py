"""Ventana principal rediseñada para usuarios no técnicos.
Se mantienen las vistas y controladores existentes; no altera el esquema de BD.
"""
import tkinter as tk
from tkinter import ttk

from app.views.catalogos_view import CatalogosView
from app.views.compras_view import ComprasView
from app.views.pedidos_view import PedidosView
from app.views.reportes_view import CierreView, ConsultasView, StockView
from app.views.retiros_view import RetirosView
from app.views.widgets import guard
from app.views.auditoria_view import AuditoriaView


class MainWindow(tk.Tk):
    GREEN = "#174D3A"
    GREEN2 = "#23664D"
    LIGHT = "#F3F6F4"
    TEXT = "#20352C"
    MUTED = "#61766A"
    WHITE = "#FFFFFF"

    def __init__(self):
        super().__init__()
        self.title("Frutos del Sur Mistiana | Sistema de gestión")
        self.geometry("1360x850")
        self.minsize(1050, 700)
        self.configure(bg=self.LIGHT)
        self._style()
        self.pages = {}
        self.current = None
        self._layout()
        self.show_page("inicio")

    def _style(self):
        s = ttk.Style(self)
        try:
            s.theme_use("clam")
        except tk.TclError:
            pass
        s.configure("TFrame", background=self.LIGHT)
        s.configure("Card.TFrame", background=self.WHITE)
        s.configure("TLabel", background=self.LIGHT, foreground=self.TEXT, font=("Segoe UI", 10))
        s.configure("Title.TLabel", font=("Segoe UI", 22, "bold"), foreground=self.GREEN, background=self.LIGHT)
        s.configure("Subtitle.TLabel", font=("Segoe UI", 10), foreground=self.MUTED, background=self.LIGHT)
        s.configure("Nav.TButton", font=("Segoe UI", 10), padding=(14, 11), anchor="w")
        s.configure("Accent.TButton", font=("Segoe UI", 10, "bold"), padding=(12, 9))
        s.configure("Treeview", font=("Segoe UI", 10), rowheight=30, background=self.WHITE, fieldbackground=self.WHITE)
        s.configure("Treeview.Heading", font=("Segoe UI", 10, "bold"), padding=8)
        s.configure("TLabelframe", background=self.LIGHT)
        s.configure("TLabelframe.Label", font=("Segoe UI", 10, "bold"), foreground=self.GREEN, background=self.LIGHT)

    def _layout(self):
        # Barra lateral
        side = tk.Frame(self, bg=self.GREEN, width=250)
        side.pack(side="left", fill="y")
        side.pack_propagate(False)
        tk.Label(side, text="FRUTOS\nDEL SUR", bg=self.GREEN, fg="white", font=("Segoe UI", 21, "bold"), justify="left").pack(anchor="w", padx=24, pady=(28, 4))
        tk.Label(side, text="MISTIANA  ·  GESTIÓN", bg=self.GREEN, fg="#CBE1D4", font=("Segoe UI", 9, "bold")).pack(anchor="w", padx=24, pady=(0, 25))
        navs = [
            ("⌂", "Inicio", "inicio"),
            ("＋", "Registrar retiro", "retiros"),
            ("▤", "Hojas de compra", "compras"),
            ("▣", "Pedidos / ventas", "pedidos"),
            ("◫", "Stock disponible", "stock"),
            ("▥", "Cierre del día", "cierre"),
            ("⚙", "Datos y catálogos", "catalogos"),
            ("⋯", "Consultas avanzadas", "consultas"),
            ("◷", "Historial / auditoría", "auditoria"),
        ]
        for glyph, label, key in navs:
            btn = tk.Button(side, text=f"{glyph}   {label}", command=lambda k=key: self.show_page(k),
                            bg=self.GREEN, fg="white", activebackground=self.GREEN2, activeforeground="white",
                            relief="flat", bd=0, font=("Segoe UI", 11), anchor="w", padx=22, pady=12, cursor="hand2")
            btn.pack(fill="x", padx=8, pady=2)
        tk.Label(side, text="Sistema de gestión agrícola", bg=self.GREEN, fg="#CBE1D4", font=("Segoe UI", 9)).pack(side="bottom", anchor="w", padx=22, pady=20)

        # Área principal con encabezado y vistas
        main = tk.Frame(self, bg=self.LIGHT)
        main.pack(side="left", fill="both", expand=True)
        head = tk.Frame(main, bg=self.WHITE, height=72)
        head.pack(fill="x")
        head.pack_propagate(False)
        self.head_title = tk.Label(head, text="Inicio", bg=self.WHITE, fg=self.GREEN, font=("Segoe UI", 17, "bold"))
        self.head_title.pack(side="left", padx=28, pady=20)
        tk.Label(head, text="Gestione registros y operaciones de forma sencilla", bg=self.WHITE, fg=self.MUTED, font=("Segoe UI", 10)).pack(side="right", padx=24)
        self.content = tk.Frame(main, bg=self.LIGHT)
        self.content.pack(fill="both", expand=True, padx=22, pady=18)

    def show_page(self, key):
        titles = {"inicio":"Inicio", "retiros":"Registrar retiro", "compras":"Hojas de compra", "pedidos":"Pedidos / ventas", "stock":"Stock disponible", "cierre":"Cierre del día", "catalogos":"Datos y catálogos", "consultas":"Consultas avanzadas", "auditoria":"Historial / auditoría"}
        self.head_title.config(text=titles.get(key, "Sistema"))
        for child in self.content.winfo_children():
            child.destroy()
        if key == "inicio":
            self._home()
            return
        classes = {"auditoria":AuditoriaView, "retiros":RetirosView, "compras":ComprasView, "pedidos":PedidosView, "stock":StockView, "cierre":CierreView, "catalogos":CatalogosView, "consultas":ConsultasView}
        view = classes[key](self.content)
        view.pack(fill="both", expand=True)
        guard(view.refresh)

    def _home(self):
        tk.Label(self.content, text="Bienvenido a Frutos del Sur", bg=self.LIGHT, fg=self.GREEN, font=("Segoe UI", 24, "bold")).pack(anchor="w", pady=(8, 4))
        tk.Label(self.content, text="Seleccione una tarea. Los botones están organizados según el trabajo diario.", bg=self.LIGHT, fg=self.MUTED, font=("Segoe UI", 11)).pack(anchor="w", pady=(0, 18))
        cards = tk.Frame(self.content, bg=self.LIGHT)
        cards.pack(fill="x")
        options = [
            ("01", "Registrar retiro", "Registrar la fruta recibida del productor.", "retiros", "#23664D"),
            ("02", "Hojas de compra", "Preparar y revisar hojas de control.", "compras", "#367B60"),
            ("03", "Pedidos / ventas", "Registrar pedidos, clientes y entregas.", "pedidos", "#477F69"),
            ("04", "Stock disponible", "Consultar productos y cantidades disponibles.", "stock", "#568A73"),
            ("05", "Cierre del día", "Revisar las operaciones y totales del día.", "cierre", "#23664D"),
            ("06", "Datos y catálogos", "Administrar productos, calidades, productores y clientes.", "catalogos", "#367B60"),
            ("07", "Historial / auditoría", "Ver quién registró, modificó o eliminó información.", "auditoria", "#477F69"),
        ]
        for i, (num, title, desc, key, color) in enumerate(options):
            r, c = divmod(i, 2)
            card = tk.Frame(cards, bg=self.WHITE, highlightbackground="#DCE6DF", highlightthickness=1)
            card.grid(row=r, column=c, sticky="nsew", padx=(0, 12) if c == 0 else (12, 0), pady=10)
            cards.columnconfigure(c, weight=1)
            tk.Label(card, text=num, bg=self.WHITE, fg=color, font=("Segoe UI", 12, "bold")).pack(anchor="w", padx=18, pady=(15, 3))
            tk.Label(card, text=title, bg=self.WHITE, fg=self.TEXT, font=("Segoe UI", 15, "bold")).pack(anchor="w", padx=18, pady=3)
            tk.Label(card, text=desc, bg=self.WHITE, fg=self.MUTED, font=("Segoe UI", 10), wraplength=430, justify="left").pack(anchor="w", padx=18, pady=(3, 14))
            tk.Button(card, text="Abrir  →", command=lambda k=key: self.show_page(k), bg=color, fg="white", activebackground=self.GREEN,
                      activeforeground="white", relief="flat", font=("Segoe UI", 10, "bold"), cursor="hand2", padx=15, pady=8).pack(anchor="w", padx=18, pady=(0, 16))
        note = tk.Frame(self.content, bg="#E5EFE9")
        note.pack(fill="x", pady=(18, 0))
        tk.Label(note, text="Consejo", bg="#E5EFE9", fg=self.GREEN, font=("Segoe UI", 11, "bold")).pack(anchor="w", padx=16, pady=(12, 2))
        tk.Label(note, text="Use el menú izquierdo para cambiar de tarea. Las consultas avanzadas están separadas para evitar confusiones.", bg="#E5EFE9", fg=self.TEXT, font=("Segoe UI", 10), wraplength=800, justify="left").pack(anchor="w", padx=16, pady=(0, 12))
