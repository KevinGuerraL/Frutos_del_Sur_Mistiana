"""MODELO: notas de pedido (Tarea 3: Asignacion y reparto a clientes)."""
import psycopg2.errors as pgerr

from app.db import baja_logica, get_cursor
from app.errors import AppError


def stock_de(cod_producto, nombre_calidad):
    """Fila de v_stock (stock en la unidad del producto) o None."""
    with get_cursor() as cur:
        cur.execute("SELECT * FROM v_stock WHERE cod_producto=%s AND nombre_calidad=%s",
                    (cod_producto, nombre_calidad))
        return cur.fetchone()


def hojas_disponibles():
    with get_cursor() as cur:
        cur.execute("SELECT id_compra, fecha FROM hoja_control_compra WHERE activo ORDER BY fecha DESC, id_compra DESC")
        return cur.fetchall()


def crear(fecha, modalidad, id_compra, id_cliente, lineas, firma=None):
    """lineas = [{'cod_producto','nombre_calidad','cajas'|'kilos','precio_unitario'}].
    Valida el stock linea por linea dentro de la misma transaccion."""
    with get_cursor() as cur:
        cur.execute("SELECT nextval('seq_numero_nota') AS n")
        numero = cur.fetchone()["n"]
        cur.execute("INSERT INTO nota_pedido VALUES (%s,%s,%s,%s,%s,%s)",
                    (numero, fecha, modalidad, firma, id_compra, id_cliente))
        for l in lineas:
            cur.execute("SELECT unidad_medida, kg_por_caja FROM producto_agricola WHERE cod_producto=%s",
                        (l["cod_producto"],))
            prod = cur.fetchone()
            pedido = l["cajas"] if l.get("cajas") is not None else l["kilos"]
            es_caja = l.get("cajas") is not None
            if prod["unidad_medida"] == "Kilogramo":
                req = pedido * prod["kg_por_caja"] if es_caja else pedido
            else:
                req = pedido if es_caja else pedido / prod["kg_por_caja"]
            cur.execute("SELECT stock FROM v_stock WHERE cod_producto=%s AND nombre_calidad=%s",
                        (l["cod_producto"], l["nombre_calidad"]))
            disp = cur.fetchone()["stock"]
            if req > disp:
                raise AppError(f"Stock insuficiente de {l['cod_producto']} {l['nombre_calidad']}: "
                               f"disponible {disp} {prod['unidad_medida'].lower()}(s), solicitado {req:.2f}.")
            cur.execute("INSERT INTO detalle_pedido VALUES (%s,%s,%s,%s,%s,%s)",
                        (numero, l["cod_producto"], l["nombre_calidad"],
                         l.get("cajas"), l.get("kilos"), l["precio_unitario"]))
        return numero


def listar():
    with get_cursor() as cur:
        cur.execute("""
            SELECT np.numero_compra, np.fecha, c.nombre AS cliente, np.modalidad_pago, np.id_compra,
                   SUM(COALESCE(dp.cajas::NUMERIC, dp.kilos) * dp.precio_unitario) AS total
            FROM nota_pedido np
            JOIN cliente c ON c.id_cliente = np.id_cliente
            LEFT JOIN detalle_pedido dp ON dp.numero_compra = np.numero_compra
            WHERE np.activo
            GROUP BY np.numero_compra, np.fecha, c.nombre, np.modalidad_pago, np.id_compra
            ORDER BY np.fecha DESC, np.numero_compra DESC""")
        return cur.fetchall()


def detalle(numero):
    with get_cursor() as cur:
        cur.execute("""
            SELECT a.nombre_producto, dp.nombre_calidad, dp.cajas, dp.kilos, dp.precio_unitario,
                   COALESCE(dp.cajas::NUMERIC, dp.kilos) * dp.precio_unitario AS subtotal
            FROM detalle_pedido dp JOIN producto_agricola a ON a.cod_producto = dp.cod_producto
            WHERE dp.numero_compra = %s ORDER BY a.nombre_producto, dp.nombre_calidad""", (numero,))
        return cur.fetchall()


def eliminar(numero):
    baja_logica("nota_pedido", numero)
