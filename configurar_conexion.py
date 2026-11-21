"""Asistente sencillo para editar la conexión; no accede ni modifica la base de datos."""
import configparser
import tkinter as tk
from tkinter import ttk, messagebox
from pathlib import Path
from config import BASE_DIR

path=BASE_DIR / "config.ini"
config=configparser.ConfigParser()
config.read(path, encoding="utf-8")
if not config.has_section("postgresql"): config.add_section("postgresql")
root=tk.Tk(); root.title("Configurar Frutos del Sur"); root.geometry("420x330"); root.resizable(False,False)
frame=ttk.Frame(root,padding=18); frame.pack(fill="both",expand=True)
fields=[("Servidor","host","localhost"),("Puerto","port","5432"),("Base de datos","dbname","frutos_sur_mistiana"),("Usuario","user","postgres"),("Contraseña","password","")]
entries={}
for i,(label,key,default) in enumerate(fields):
    ttk.Label(frame,text=label).grid(row=i,column=0,sticky="w",pady=5)
    e=ttk.Entry(frame,width=32,show="*" if key=="password" else "")
    e.grid(row=i,column=1,sticky="ew",pady=5); e.insert(0,config.get("postgresql",key,fallback=default)); entries[key]=e
frame.columnconfigure(1,weight=1)
def save():
    try:
        port=int(entries["port"].get())
        if not 1<=port<=65535: raise ValueError
    except ValueError:
        messagebox.showwarning("Puerto inválido","Escribe un puerto válido entre 1 y 65535."); return
    for key,e in entries.items(): config.set("postgresql",key,e.get().strip())
    with path.open("w",encoding="utf-8") as f: config.write(f)
    messagebox.showinfo("Guardado","Configuración guardada. No se modificó la base de datos."); root.destroy()
ttk.Button(frame,text="Guardar configuración",command=save).grid(row=6,column=0,columnspan=2,pady=16)
ttk.Label(frame,text="Este asistente solo guarda los datos de conexión.").grid(row=7,column=0,columnspan=2)
root.mainloop()
