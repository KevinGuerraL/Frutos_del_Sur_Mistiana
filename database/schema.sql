-- =====================================================================
-- Frutos del Sur La Mistiana - Registro de compras de productos agricolas
-- ESQUEMA CORREGIDO (PostgreSQL). Se ejecuta con setup_db.py
-- =====================================================================

-- 1. TABLAS ------------------------------------------------------------
CREATE TABLE productor (
    id_productor VARCHAR(10) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    region_procedencia VARCHAR(20) NOT NULL
        CHECK (region_procedencia IN ('Ica','Chincha','Pisco','Pedregal','Tacna'))
);

CREATE TABLE producto_agricola (
    cod_producto VARCHAR(10) PRIMARY KEY,
    nombre_producto VARCHAR(50) NOT NULL,
    unidad_medida VARCHAR(10) NOT NULL
        CHECK (unidad_medida IN ('Kilogramo','Caja')),
    -- CORRECCION 1: factor de conversion caja <-> kilo (el documento indica 10 cajas = 100 kg)
    kg_por_caja NUMERIC(6,2) NOT NULL DEFAULT 10 CHECK (kg_por_caja > 0)
);

CREATE TABLE calidad (
    cod_producto VARCHAR(10) NOT NULL,
    nombre_calidad VARCHAR(20) NOT NULL,
    precio_referencia NUMERIC(8,2) NOT NULL CHECK (precio_referencia > 0),
    PRIMARY KEY (cod_producto, nombre_calidad),
    FOREIGN KEY (cod_producto) REFERENCES producto_agricola(cod_producto)
);

CREATE TABLE calidad_alias (
    cod_producto VARCHAR(10) NOT NULL,
    nombre_calidad VARCHAR(20) NOT NULL,
    alias_por_documento VARCHAR(30) NOT NULL,
    PRIMARY KEY (cod_producto, nombre_calidad, alias_por_documento),
    FOREIGN KEY (cod_producto, nombre_calidad)
        REFERENCES calidad(cod_producto, nombre_calidad) ON DELETE CASCADE
);

CREATE TABLE cliente (
    id_cliente VARCHAR(10) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    domicilio VARCHAR(150),
    telefono VARCHAR(15)
);

CREATE TABLE calendario_retiro (
    fecha DATE PRIMARY KEY,
    dia_semana VARCHAR(10) NOT NULL
        CHECK (dia_semana IN ('Lunes','Jueves','Sábado')),
    -- CORRECCION 2: el dia escrito debe coincidir con el dia real de la fecha
    CONSTRAINT ck_dia_coincide_fecha CHECK (
        (dia_semana = 'Lunes'  AND EXTRACT(ISODOW FROM fecha) = 1) OR
        (dia_semana = 'Jueves' AND EXTRACT(ISODOW FROM fecha) = 4) OR
        (dia_semana = 'Sábado' AND EXTRACT(ISODOW FROM fecha) = 6))
);

CREATE TABLE retiro_campo (
    id_retiro VARCHAR(10) PRIMARY KEY,
    fecha DATE NOT NULL REFERENCES calendario_retiro(fecha),
    id_productor VARCHAR(10) NOT NULL REFERENCES productor(id_productor)
);

CREATE TABLE detalle_retiro (
    id_retiro VARCHAR(10) NOT NULL,
    cod_producto VARCHAR(10) NOT NULL,
    nombre_calidad VARCHAR(20) NOT NULL,
    cantidad NUMERIC(8,2) NOT NULL CHECK (cantidad > 0),
    PRIMARY KEY (id_retiro, cod_producto, nombre_calidad),
    FOREIGN KEY (id_retiro) REFERENCES retiro_campo(id_retiro) ON DELETE CASCADE,
    FOREIGN KEY (cod_producto, nombre_calidad)
        REFERENCES calidad(cod_producto, nombre_calidad)
);

CREATE TABLE hoja_control_compra (
    id_compra VARCHAR(10) PRIMARY KEY,
    fecha DATE NOT NULL,
    id_retiro VARCHAR(10) NOT NULL UNIQUE REFERENCES retiro_campo(id_retiro)
);

CREATE TABLE detalle_compra (
    id_compra VARCHAR(10) NOT NULL,
    cod_producto VARCHAR(10) NOT NULL,
    nombre_calidad VARCHAR(20) NOT NULL,
    cantidad NUMERIC(8,2) NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(8,2) NOT NULL CHECK (precio_unitario > 0),
    PRIMARY KEY (id_compra, cod_producto, nombre_calidad),
    FOREIGN KEY (id_compra) REFERENCES hoja_control_compra(id_compra) ON DELETE CASCADE,
    FOREIGN KEY (cod_producto, nombre_calidad)
        REFERENCES calidad(cod_producto, nombre_calidad)
);

CREATE TABLE nota_pedido (
    numero_compra INTEGER PRIMARY KEY,
    fecha DATE NOT NULL,
    modalidad_pago VARCHAR(10) NOT NULL
        CHECK (modalidad_pago IN ('Crédito','Contado')),
    firma_cliente BYTEA,
    id_compra VARCHAR(10) NOT NULL REFERENCES hoja_control_compra(id_compra),
    id_cliente VARCHAR(10) NOT NULL REFERENCES cliente(id_cliente)
);

CREATE TABLE detalle_pedido (
    numero_compra INTEGER NOT NULL,
    cod_producto VARCHAR(10) NOT NULL,
    nombre_calidad VARCHAR(20) NOT NULL,
    cajas INTEGER CHECK (cajas IS NULL OR cajas >= 0),
    kilos NUMERIC(8,2) CHECK (kilos IS NULL OR kilos >= 0),
    precio_unitario NUMERIC(8,2) NOT NULL CHECK (precio_unitario > 0),
    PRIMARY KEY (numero_compra, cod_producto, nombre_calidad),
    FOREIGN KEY (numero_compra) REFERENCES nota_pedido(numero_compra) ON DELETE CASCADE,
    FOREIGN KEY (cod_producto, nombre_calidad)
        REFERENCES calidad(cod_producto, nombre_calidad),
    CHECK ((cajas IS NOT NULL AND kilos IS NULL) OR (cajas IS NULL AND kilos IS NOT NULL))
);

-- 2. INDICES SECUNDARIOS ----------------------------------------------
CREATE INDEX idx_productor_nombre ON productor(nombre);
CREATE INDEX idx_cliente_nombre ON cliente(nombre);
CREATE INDEX idx_retiro_fecha ON retiro_campo(fecha);
CREATE INDEX idx_retiro_productor ON retiro_campo(id_productor);
CREATE INDEX idx_nota_fecha ON nota_pedido(fecha);
CREATE INDEX idx_nota_cliente ON nota_pedido(id_cliente);
-- CORRECCION 3: la Tabla 44 del informe lista este indice pero el script no lo creaba
CREATE INDEX idx_nota_compra ON nota_pedido(id_compra);
CREATE INDEX idx_detalle_compra_producto ON detalle_compra(cod_producto, nombre_calidad);
CREATE INDEX idx_detalle_pedido_producto ON detalle_pedido(cod_producto, nombre_calidad);

-- 3. SECUENCIA PARA EL N° DE NOTA DE PEDIDO ----------------------------
-- CORRECCION 4: numero correlativo generado por la BD (no a mano)
CREATE SEQUENCE seq_numero_nota START WITH 1456;

-- 4. VISTA DE STOCK ----------------------------------------------------
-- CORRECCION 5: monitoreo de stock real. Compra y venta se comparan en la
-- unidad del producto (Kilogramo o Caja), convirtiendo con kg_por_caja.
CREATE VIEW v_stock AS
WITH compras AS (
    SELECT cod_producto, nombre_calidad, SUM(cantidad) AS comprado
    FROM detalle_compra
    GROUP BY cod_producto, nombre_calidad
), ventas AS (
    SELECT dp.cod_producto, dp.nombre_calidad,
           SUM(CASE a.unidad_medida
                   WHEN 'Kilogramo' THEN COALESCE(dp.kilos, dp.cajas * a.kg_por_caja)
                   ELSE COALESCE(dp.cajas, dp.kilos / a.kg_por_caja)
               END) AS vendido
    FROM detalle_pedido dp
    JOIN producto_agricola a ON a.cod_producto = dp.cod_producto
    GROUP BY dp.cod_producto, dp.nombre_calidad
)
SELECT a.cod_producto, a.nombre_producto, a.unidad_medida, c.nombre_calidad,
       COALESCE(co.comprado, 0)::NUMERIC(10,2) AS comprado,
       COALESCE(v.vendido, 0)::NUMERIC(10,2)   AS vendido,
       (COALESCE(co.comprado, 0) - COALESCE(v.vendido, 0))::NUMERIC(10,2) AS stock
FROM calidad c
JOIN producto_agricola a ON a.cod_producto = c.cod_producto
LEFT JOIN compras co ON co.cod_producto = c.cod_producto AND co.nombre_calidad = c.nombre_calidad
LEFT JOIN ventas  v  ON v.cod_producto  = c.cod_producto AND v.nombre_calidad  = c.nombre_calidad;
