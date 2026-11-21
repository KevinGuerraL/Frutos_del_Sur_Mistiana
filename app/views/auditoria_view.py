"""Visor sencillo del historial de cambios registrados por el aplicativo."""
import tkinter as tk
from tkinter import ttk, messagebox
from app.audit import leer_eventos

class AuditoriaView(ttk.Frame):
    def __init__(self, master):
        super().__init__(master)
        ttk.Label(self, text="Historial de acciones", font=("Segoe UI", 18, "bold")).pack(anchor="w", pady=(5,3))
        ttk.Label(self, text="Registro de inserciones, modificaciones, eliminaciones y otras acciones realizadas desde la aplicación.").pack(anchor="w", pady=(0,10))
        bar=ttk.Frame(self);bar.pack(fill="x", pady=5)
        ttk.Button(bar,text="Actualizar",command=self.refresh).pack(side="left")
        ttk.Button(bar,text="Ver detalle",command=self.detail).pack(side="left",padx=6)
        ttk.Label(self,text="Los registros se guardan en audit_logs/auditoria.jsonl; no requieren cambios en PostgreSQL.").pack(anchor="w",pady=4)
        cols=("fecha","usuario","accion","entidad","id")
        self.tree=ttk.Treeview(self,columns=cols,show="headings")
        labels={"fecha":"Fecha y hora","usuario":"Usuario Windows","accion":"Acción","entidad":"Tipo de registro","id":"Identificador"}
        widths={"fecha":190,"usuario":120,"accion":130,"entidad":180,"id":140}
        for c in cols:self.tree.heading(c,text=labels[c]);self.tree.column(c,width=widths[c],anchor="w")
        self.tree.pack(fill="both",expand=True)
        self._events=[];self.refresh()
    def refresh(self):
        self._events=leer_eventos()
        self.tree.delete(*self.tree.get_children())
        for i,e in enumerate(self._events):
            self.tree.insert("","end",iid=str(i),values=(e.get("fecha_hora"),e.get("usuario"),e.get("accion"),e.get("entidad"),e.get("identificador")))
    def detail(self):
        sel=self.tree.selection()
        if not sel: messagebox.showinfo("Historial","Selecciona un evento para ver sus detalles.",parent=self);return
        e=self._events[int(sel[0])]
        text=(f"Fecha: {e.get('fecha_hora')}\nUsuario: {e.get('usuario')}\nAcción: {e.get('accion')}\n"
              f"Entidad: {e.get('entidad')}\nIdentificador: {e.get('identificador')}\n\nDetalles:\n")
        import json
        text+=json.dumps(e.get("detalles",{}),ensure_ascii=False,indent=2)
        w=tk.Toplevel(self);w.title("Detalle del evento");w.geometry("700x500")
        t=tk.Text(w,wrap="word");t.pack(fill="both",expand=True);t.insert("1.0",text);t.configure(state="disabled")
