--
-- PostgreSQL database dump
--

\restrict nvCxgSiMLDsKU81D3AAvzXD77xdpGDoNgMphUXqPN8tAcsHC3sNyEaJurF0z3eO

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS '';


--
-- Name: fn_a_unidad_producto(character varying, integer, numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_a_unidad_producto(p_cod character varying, p_cajas integer, p_kilos numeric) RETURNS numeric
    LANGUAGE sql STABLE
    AS $$
    SELECT CASE a.unidad_medida
               WHEN 'Kilogramo' THEN COALESCE(p_kilos, p_cajas * a.kg_por_caja)
               ELSE COALESCE(p_cajas, p_kilos / a.kg_por_caja)
           END
    FROM producto_agricola a WHERE a.cod_producto = p_cod
$$;


ALTER FUNCTION public.fn_a_unidad_producto(p_cod character varying, p_cajas integer, p_kilos numeric) OWNER TO postgres;

--
-- Name: fn_asegurar_fecha_retiro(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_asegurar_fecha_retiro(p_fecha date) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE v_dia INT := EXTRACT(ISODOW FROM p_fecha)::INT;
BEGIN
    IF v_dia NOT IN (1, 4, 6) THEN
        RAISE EXCEPTION 'Los retiros solo se realizan lunes, jueves y sábado (la fecha % no lo es)', p_fecha;
    END IF;
    INSERT INTO calendario_retiro (fecha, dia_semana)
    VALUES (p_fecha, CASE v_dia WHEN 1 THEN 'Lunes' WHEN 4 THEN 'Jueves' ELSE 'Sábado' END)
    ON CONFLICT (fecha) DO NOTHING;
END $$;


ALTER FUNCTION public.fn_asegurar_fecha_retiro(p_fecha date) OWNER TO postgres;

--
-- Name: fn_listar_auditoria(integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_listar_auditoria(p_limite integer DEFAULT 200, p_tabla text DEFAULT NULL::text) RETURNS TABLE(id_auditoria bigint, fecha timestamp with time zone, usuario text, tabla text, operacion text, clave text, datos_antes text, datos_despues text)
    LANGUAGE sql STABLE
    AS $$
    SELECT a.id_auditoria, a.fecha, a.usuario::TEXT, a.tabla::TEXT, a.operacion::TEXT, a.clave::TEXT,
           a.datos_antes::TEXT, a.datos_despues::TEXT
    FROM auditoria a WHERE p_tabla IS NULL OR a.tabla = p_tabla
    ORDER BY a.id_auditoria DESC LIMIT p_limite
$$;


ALTER FUNCTION public.fn_listar_auditoria(p_limite integer, p_tabla text) OWNER TO postgres;

--
-- Name: fn_listar_calidades(text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_listar_calidades(p_cod text DEFAULT NULL::text, p_bajas boolean DEFAULT false) RETURNS TABLE(cod_producto text, nombre_calidad text, precio_referencia numeric, estado text, motivo_baja text)
    LANGUAGE sql STABLE
    AS $$
    SELECT cod_producto::TEXT, nombre_calidad::TEXT, precio_referencia,
           CASE WHEN activo THEN 'Activo' ELSE 'Baja' END, motivo_baja::TEXT
    FROM calidad
    WHERE (p_cod IS NULL OR cod_producto = p_cod) AND (activo OR p_bajas)
    ORDER BY cod_producto, precio_referencia DESC
$$;


ALTER FUNCTION public.fn_listar_calidades(p_cod text, p_bajas boolean) OWNER TO postgres;

--
-- Name: fn_listar_clientes(boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_listar_clientes(p_bajas boolean DEFAULT false) RETURNS TABLE(id_cliente text, nombre text, domicilio text, telefono text, estado text, motivo_baja text)
    LANGUAGE sql STABLE
    AS $$
    SELECT id_cliente::TEXT, nombre::TEXT, domicilio::TEXT, telefono::TEXT,
           CASE WHEN activo THEN 'Activo' ELSE 'Baja' END, motivo_baja::TEXT
    FROM cliente WHERE activo OR p_bajas ORDER BY 1
$$;


ALTER FUNCTION public.fn_listar_clientes(p_bajas boolean) OWNER TO postgres;

--
-- Name: fn_listar_hoja_detalle(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_listar_hoja_detalle(p_id text) RETURNS TABLE(cod_producto text, nombre_producto text, nombre_calidad text, cantidad numeric, unidad_medida text, precio_unitario numeric, total numeric)
    LANGUAGE sql STABLE
    AS $$
    SELECT dc.cod_producto::TEXT, a.nombre_producto::TEXT, dc.nombre_calidad::TEXT, dc.cantidad,
           a.unidad_medida::TEXT, dc.precio_unitario, dc.cantidad * dc.precio_unitario
    FROM detalle_compra dc JOIN producto_agricola a ON a.cod_producto = dc.cod_producto
    WHERE dc.id_compra = p_id ORDER BY a.nombre_producto, dc.nombre_calidad
$$;


ALTER FUNCTION public.fn_listar_hoja_detalle(p_id text) OWNER TO postgres;

--
-- Name: fn_listar_hojas(boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_listar_hojas(p_bajas boolean DEFAULT false) RETURNS TABLE(id_compra text, fecha date, id_retiro text, productor text, total_a_pagar numeric, estado text, motivo_baja text)
    LANGUAGE sql STABLE
    AS $$
    SELECT h.id_compra::TEXT, h.fecha, h.id_retiro::TEXT, p.nombre::TEXT,
           COALESCE(SUM(dc.cantidad * dc.precio_unitario), 0),
           CASE WHEN h.activo THEN 'Activo' ELSE 'Baja' END, h.motivo_baja::TEXT
    FROM hoja_control_compra h
    JOIN retiro_campo r ON r.id_retiro = h.id_retiro
    JOIN productor p ON p.id_productor = r.id_productor
    LEFT JOIN detalle_compra dc ON dc.id_compra = h.id_compra
    WHERE h.activo OR p_bajas
    GROUP BY h.id_compra, h.fecha, h.id_retiro, p.nombre, h.activo, h.motivo_baja
    ORDER BY h.fecha DESC, h.id_compra DESC
$$;


ALTER FUNCTION public.fn_listar_hojas(p_bajas boolean) OWNER TO postgres;

--
-- Name: fn_listar_nota_detalle(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_listar_nota_detalle(p_numero integer) RETURNS TABLE(cod_producto text, nombre_producto text, nombre_calidad text, cajas integer, kilos numeric, precio_unitario numeric, subtotal numeric)
    LANGUAGE sql STABLE
    AS $$
    SELECT dp.cod_producto::TEXT, a.nombre_producto::TEXT, dp.nombre_calidad::TEXT, dp.cajas, dp.kilos,
           dp.precio_unitario, COALESCE(dp.cajas::NUMERIC, dp.kilos) * dp.precio_unitario
    FROM detalle_pedido dp JOIN producto_agricola a ON a.cod_producto = dp.cod_producto
    WHERE dp.numero_compra = p_numero ORDER BY a.nombre_producto, dp.nombre_calidad
$$;


ALTER FUNCTION public.fn_listar_nota_detalle(p_numero integer) OWNER TO postgres;

--
-- Name: fn_listar_notas(boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_listar_notas(p_bajas boolean DEFAULT false) RETURNS TABLE(numero_compra integer, fecha date, cliente text, modalidad_pago text, id_compra text, total numeric, estado text, motivo_baja text)
    LANGUAGE sql STABLE
    AS $$
    SELECT np.numero_compra, np.fecha, c.nombre::TEXT, np.modalidad_pago::TEXT, np.id_compra::TEXT,
           COALESCE(SUM(COALESCE(dp.cajas::NUMERIC, dp.kilos) * dp.precio_unitario), 0),
           CASE WHEN np.activo THEN 'Activo' ELSE 'Baja' END, np.motivo_baja::TEXT
    FROM nota_pedido np
    JOIN cliente c ON c.id_cliente = np.id_cliente
    LEFT JOIN detalle_pedido dp ON dp.numero_compra = np.numero_compra
    WHERE np.activo OR p_bajas
    GROUP BY np.numero_compra, np.fecha, c.nombre, np.modalidad_pago, np.id_compra, np.activo, np.motivo_baja
    ORDER BY np.fecha DESC, np.numero_compra DESC
$$;


ALTER FUNCTION public.fn_listar_notas(p_bajas boolean) OWNER TO postgres;

--
-- Name: fn_listar_productores(boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_listar_productores(p_bajas boolean DEFAULT false) RETURNS TABLE(id_productor text, nombre text, region_procedencia text, estado text, motivo_baja text)
    LANGUAGE sql STABLE
    AS $$
    SELECT id_productor::TEXT, nombre::TEXT, region_procedencia::TEXT,
           CASE WHEN activo THEN 'Activo' ELSE 'Baja' END, motivo_baja::TEXT
    FROM productor WHERE activo OR p_bajas ORDER BY 1
$$;


ALTER FUNCTION public.fn_listar_productores(p_bajas boolean) OWNER TO postgres;

--
-- Name: fn_listar_productos(boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_listar_productos(p_bajas boolean DEFAULT false) RETURNS TABLE(cod_producto text, nombre_producto text, unidad_medida text, kg_por_caja numeric, estado text, motivo_baja text)
    LANGUAGE sql STABLE
    AS $$
    SELECT cod_producto::TEXT, nombre_producto::TEXT, unidad_medida::TEXT, kg_por_caja,
           CASE WHEN activo THEN 'Activo' ELSE 'Baja' END, motivo_baja::TEXT
    FROM producto_agricola WHERE activo OR p_bajas ORDER BY 1
$$;


ALTER FUNCTION public.fn_listar_productos(p_bajas boolean) OWNER TO postgres;

--
-- Name: fn_listar_retiro_detalle(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_listar_retiro_detalle(p_id text) RETURNS TABLE(cod_producto text, nombre_producto text, nombre_calidad text, cantidad numeric, unidad_medida text)
    LANGUAGE sql STABLE
    AS $$
    SELECT d.cod_producto::TEXT, a.nombre_producto::TEXT, d.nombre_calidad::TEXT, d.cantidad, a.unidad_medida::TEXT
    FROM detalle_retiro d JOIN producto_agricola a ON a.cod_producto = d.cod_producto
    WHERE d.id_retiro = p_id ORDER BY a.nombre_producto, d.nombre_calidad
$$;


ALTER FUNCTION public.fn_listar_retiro_detalle(p_id text) OWNER TO postgres;

--
-- Name: fn_listar_retiros(boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_listar_retiros(p_bajas boolean DEFAULT false) RETURNS TABLE(id_retiro text, fecha date, dia_semana text, id_productor text, productor text, estado text, motivo_baja text)
    LANGUAGE sql STABLE
    AS $$
    SELECT r.id_retiro::TEXT, r.fecha, c.dia_semana::TEXT, r.id_productor::TEXT, p.nombre::TEXT,
           CASE WHEN r.activo THEN 'Activo' ELSE 'Baja' END, r.motivo_baja::TEXT
    FROM retiro_campo r
    JOIN calendario_retiro c ON c.fecha = r.fecha
    JOIN productor p ON p.id_productor = r.id_productor
    WHERE r.activo OR p_bajas
    ORDER BY r.fecha DESC, r.id_retiro DESC
$$;


ALTER FUNCTION public.fn_listar_retiros(p_bajas boolean) OWNER TO postgres;

--
-- Name: fn_prueba_conexion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_prueba_conexion() RETURNS TABLE(base_datos text, usuario text, version_postgres text, hora_servidor timestamp with time zone, tablas_publicas bigint)
    LANGUAGE sql STABLE
    AS $$
    SELECT current_database()::TEXT, current_user::TEXT, version(), now(),
           (SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = 'public' AND table_type = 'BASE TABLE')
$$;


ALTER FUNCTION public.fn_prueba_conexion() OWNER TO postgres;

--
-- Name: fn_rep_historial_retiros(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_rep_historial_retiros() RETURNS TABLE(id_retiro character varying, fecha date, productor character varying, region_procedencia character varying)
    LANGUAGE sql STABLE
    AS $$
    SELECT r.id_retiro, r.fecha, p.nombre, p.region_procedencia
    FROM retiro_campo r
    JOIN productor p ON p.id_productor = r.id_productor
    ORDER BY r.fecha DESC, r.id_retiro DESC
$$;


ALTER FUNCTION public.fn_rep_historial_retiros() OWNER TO postgres;

--
-- Name: fn_rep_notas_con_cliente(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_rep_notas_con_cliente() RETURNS TABLE(numero_compra integer, fecha date, cliente character varying, domicilio character varying, modalidad_pago character varying)
    LANGUAGE sql STABLE
    AS $$
    SELECT np.numero_compra, np.fecha, c.nombre, c.domicilio, np.modalidad_pago
    FROM nota_pedido np
    JOIN cliente c ON c.id_cliente = np.id_cliente
    ORDER BY np.fecha DESC, np.numero_compra DESC
$$;


ALTER FUNCTION public.fn_rep_notas_con_cliente() OWNER TO postgres;

--
-- Name: fn_rep_total_retirado_por_fecha(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_rep_total_retirado_por_fecha() RETURNS TABLE(fecha date, unidad_medida character varying, total_cantidad numeric)
    LANGUAGE sql STABLE
    AS $$
    SELECT r.fecha, a.unidad_medida, SUM(dr.cantidad)
    FROM retiro_campo r
    JOIN detalle_retiro dr ON dr.id_retiro = r.id_retiro
    JOIN producto_agricola a ON a.cod_producto = dr.cod_producto
    GROUP BY r.fecha, a.unidad_medida
    ORDER BY r.fecha, a.unidad_medida
$$;


ALTER FUNCTION public.fn_rep_total_retirado_por_fecha() OWNER TO postgres;

--
-- Name: fn_retiros_sin_hoja(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_retiros_sin_hoja() RETURNS TABLE(id_retiro text, fecha date, productor text)
    LANGUAGE sql STABLE
    AS $$
    SELECT r.id_retiro::TEXT, r.fecha, p.nombre::TEXT
    FROM retiro_campo r JOIN productor p ON p.id_productor = r.id_productor
    WHERE r.activo AND NOT EXISTS (SELECT 1 FROM hoja_control_compra h WHERE h.id_retiro = r.id_retiro)
    ORDER BY r.fecha, r.id_retiro
$$;


ALTER FUNCTION public.fn_retiros_sin_hoja() OWNER TO postgres;

--
-- Name: fn_siguiente_codigo(text, text, text, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_siguiente_codigo(p_tabla text, p_columna text, p_prefijo text, p_ancho integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE v_n INT;
BEGIN
    EXECUTE format('SELECT COALESCE(MAX(SUBSTRING(%I FROM ''[0-9]+$'')::INT), 0) + 1 FROM %I',
                   p_columna, p_tabla) INTO v_n;
    RETURN p_prefijo || LPAD(v_n::TEXT, p_ancho, '0');
END $_$;


ALTER FUNCTION public.fn_siguiente_codigo(p_tabla text, p_columna text, p_prefijo text, p_ancho integer) OWNER TO postgres;

--
-- Name: fn_trg_auditoria(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_trg_auditoria() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_antes JSONB; v_despues JSONB; v_fila JSONB; v_clave TEXT;
BEGIN
    IF TG_OP <> 'INSERT' THEN v_antes := to_jsonb(OLD); END IF;
    IF TG_OP <> 'DELETE' THEN v_despues := to_jsonb(NEW); END IF;
    v_fila := COALESCE(v_despues, v_antes);
    SELECT string_agg(v_fila ->> u.k, '|' ORDER BY u.o) INTO v_clave
    FROM unnest(string_to_array(TG_ARGV[0], ',')) WITH ORDINALITY AS u(k, o);
    INSERT INTO auditoria (tabla, operacion, clave, datos_antes, datos_despues)
    VALUES (TG_TABLE_NAME, TG_OP, v_clave, v_antes, v_despues);
    RETURN NULL;
END $$;


ALTER FUNCTION public.fn_trg_auditoria() OWNER TO postgres;

--
-- Name: fn_trg_bloquear_delete(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_trg_bloquear_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'No se permite borrar físicamente registros de %: use la baja lógica (sp_baja_logica) para conservar la auditoría', TG_TABLE_NAME;
END $$;


ALTER FUNCTION public.fn_trg_bloquear_delete() OWNER TO postgres;

--
-- Name: fn_trg_marcar_baja(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_trg_marcar_baja() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.activo AND NOT NEW.activo THEN
        NEW.fecha_baja := now();
    ELSIF NOT OLD.activo AND NEW.activo THEN
        NEW.fecha_baja := NULL;
        NEW.motivo_baja := NULL;
    END IF;
    RETURN NEW;
END $$;


ALTER FUNCTION public.fn_trg_marcar_baja() OWNER TO postgres;

--
-- Name: fn_trg_validar_activos(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_trg_validar_activos() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.activo THEN
        IF TG_TABLE_NAME = 'retiro_campo' THEN
            IF NOT EXISTS (SELECT 1 FROM productor WHERE id_productor = NEW.id_productor AND activo) THEN
                RAISE EXCEPTION 'El productor % está dado de baja o no existe', NEW.id_productor;
            END IF;
        ELSIF TG_TABLE_NAME = 'hoja_control_compra' THEN
            IF NOT EXISTS (SELECT 1 FROM retiro_campo WHERE id_retiro = NEW.id_retiro AND activo) THEN
                RAISE EXCEPTION 'El retiro % está dado de baja o no existe', NEW.id_retiro;
            END IF;
        ELSIF TG_TABLE_NAME = 'nota_pedido' THEN
            IF NOT EXISTS (SELECT 1 FROM cliente WHERE id_cliente = NEW.id_cliente AND activo) THEN
                RAISE EXCEPTION 'El cliente % está dado de baja o no existe', NEW.id_cliente;
            END IF;
            IF NOT EXISTS (SELECT 1 FROM hoja_control_compra WHERE id_compra = NEW.id_compra AND activo) THEN
                RAISE EXCEPTION 'La hoja de control % está dada de baja o no existe', NEW.id_compra;
            END IF;
        ELSIF TG_TABLE_NAME = 'calidad' THEN
            IF NOT EXISTS (SELECT 1 FROM producto_agricola WHERE cod_producto = NEW.cod_producto AND activo) THEN
                RAISE EXCEPTION 'El producto % está dado de baja o no existe', NEW.cod_producto;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END $$;


ALTER FUNCTION public.fn_trg_validar_activos() OWNER TO postgres;

--
-- Name: fn_trg_validar_stock(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_trg_validar_stock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_pedido NUMERIC; v_stock NUMERIC; v_activa BOOLEAN;
BEGIN
    SELECT activo INTO v_activa FROM nota_pedido WHERE numero_compra = NEW.numero_compra;
    IF v_activa IS NOT TRUE THEN RETURN NEW; END IF;   -- una nota dada de baja no consume stock
    v_pedido := fn_a_unidad_producto(NEW.cod_producto, NEW.cajas, NEW.kilos);
    SELECT stock INTO v_stock FROM v_stock
     WHERE cod_producto = NEW.cod_producto AND nombre_calidad = NEW.nombre_calidad;
    IF TG_OP = 'UPDATE' THEN   -- la línea anterior ya estaba descontada: se devuelve antes de comparar
        v_stock := COALESCE(v_stock, 0) + fn_a_unidad_producto(OLD.cod_producto, OLD.cajas, OLD.kilos);
    END IF;
    IF v_pedido > COALESCE(v_stock, 0) THEN
        RAISE EXCEPTION 'Stock insuficiente de % %: disponible %, solicitado %',
            NEW.cod_producto, NEW.nombre_calidad, COALESCE(v_stock, 0), ROUND(v_pedido, 2);
    END IF;
    RETURN NEW;
END $$;


ALTER FUNCTION public.fn_trg_validar_stock() OWNER TO postgres;

--
-- Name: sp_baja_logica(text, text, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_baja_logica(IN p_tabla text, IN p_clave text, IN p_motivo text DEFAULT NULL::text)
    LANGUAGE plpgsql
    AS $$
DECLARE v_cod TEXT; v_cal TEXT;
BEGIN
    IF COALESCE(TRIM(p_motivo), '') = '' THEN
        RAISE EXCEPTION 'Debe indicar el motivo de la baja (queda registrado para la auditoría)';
    END IF;
    CASE p_tabla
    WHEN 'productor' THEN
        IF EXISTS (SELECT 1 FROM retiro_campo WHERE id_productor = p_clave AND activo) THEN
            RAISE EXCEPTION 'El productor % tiene retiros activos: da de baja primero esos retiros', p_clave;
        END IF;
        UPDATE productor SET activo = FALSE, motivo_baja = p_motivo WHERE id_productor = p_clave AND activo;
    WHEN 'cliente' THEN
        IF EXISTS (SELECT 1 FROM nota_pedido WHERE id_cliente = p_clave AND activo) THEN
            RAISE EXCEPTION 'El cliente % tiene notas de pedido activas: da de baja primero esas notas', p_clave;
        END IF;
        UPDATE cliente SET activo = FALSE, motivo_baja = p_motivo WHERE id_cliente = p_clave AND activo;
    WHEN 'producto_agricola' THEN
        IF EXISTS (SELECT 1 FROM calidad WHERE cod_producto = p_clave AND activo) THEN
            RAISE EXCEPTION 'El producto % tiene calidades activas: da de baja primero sus calidades', p_clave;
        END IF;
        UPDATE producto_agricola SET activo = FALSE, motivo_baja = p_motivo WHERE cod_producto = p_clave AND activo;
    WHEN 'calidad' THEN
        v_cod := split_part(p_clave, '|', 1);
        v_cal := split_part(p_clave, '|', 2);
        IF EXISTS (SELECT 1 FROM detalle_pedido d JOIN nota_pedido n ON n.numero_compra = d.numero_compra AND n.activo
                    WHERE d.cod_producto = v_cod AND d.nombre_calidad = v_cal)
        OR EXISTS (SELECT 1 FROM detalle_compra d JOIN hoja_control_compra h ON h.id_compra = d.id_compra AND h.activo
                    WHERE d.cod_producto = v_cod AND d.nombre_calidad = v_cal)
        OR EXISTS (SELECT 1 FROM detalle_retiro d JOIN retiro_campo r ON r.id_retiro = d.id_retiro AND r.activo
                    WHERE d.cod_producto = v_cod AND d.nombre_calidad = v_cal) THEN
            RAISE EXCEPTION 'La calidad % está en uso en retiros, hojas o notas activas', p_clave;
        END IF;
        UPDATE calidad SET activo = FALSE, motivo_baja = p_motivo
        WHERE cod_producto = v_cod AND nombre_calidad = v_cal AND activo;
    WHEN 'retiro_campo' THEN
        IF EXISTS (SELECT 1 FROM hoja_control_compra WHERE id_retiro = p_clave AND activo) THEN
            RAISE EXCEPTION 'El retiro % tiene una hoja de control activa: da de baja primero la hoja', p_clave;
        END IF;
        UPDATE retiro_campo SET activo = FALSE, motivo_baja = p_motivo WHERE id_retiro = p_clave AND activo;
    WHEN 'hoja_control_compra' THEN
        IF EXISTS (SELECT 1 FROM nota_pedido WHERE id_compra = p_clave AND activo) THEN
            RAISE EXCEPTION 'La hoja % tiene notas de pedido activas: da de baja primero esas notas', p_clave;
        END IF;
        UPDATE hoja_control_compra SET activo = FALSE, motivo_baja = p_motivo WHERE id_compra = p_clave AND activo;
    WHEN 'nota_pedido' THEN
        UPDATE nota_pedido SET activo = FALSE, motivo_baja = p_motivo WHERE numero_compra = p_clave::INT AND activo;
    ELSE
        RAISE EXCEPTION 'Tabla no permitida para baja lógica: %', p_tabla;
    END CASE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el registro % de % o ya estaba dado de baja', p_clave, p_tabla;
    END IF;
END $$;


ALTER PROCEDURE public.sp_baja_logica(IN p_tabla text, IN p_clave text, IN p_motivo text) OWNER TO postgres;

--
-- Name: sp_calidad_guardar(character varying, character varying, numeric); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_calidad_guardar(IN p_cod character varying, IN p_nombre character varying, IN p_precio numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE calidad SET precio_referencia = p_precio
    WHERE cod_producto = p_cod AND nombre_calidad = p_nombre AND activo;
    IF NOT FOUND THEN
        IF EXISTS (SELECT 1 FROM calidad WHERE cod_producto = p_cod AND nombre_calidad = p_nombre) THEN
            RAISE EXCEPTION 'La calidad % de % está dada de baja: reactívala', p_nombre, p_cod;
        END IF;
        INSERT INTO calidad (cod_producto, nombre_calidad, precio_referencia) VALUES (p_cod, p_nombre, p_precio);
    END IF;
END $$;


ALTER PROCEDURE public.sp_calidad_guardar(IN p_cod character varying, IN p_nombre character varying, IN p_precio numeric) OWNER TO postgres;

--
-- Name: sp_cliente_insertar(character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_cliente_insertar(IN p_nombre character varying, IN p_domicilio character varying, IN p_telefono character varying, INOUT p_id character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    p_id := fn_siguiente_codigo('cliente', 'id_cliente', 'CL', 3);
    INSERT INTO cliente (id_cliente, nombre, domicilio, telefono) VALUES (p_id, p_nombre, p_domicilio, p_telefono);
END $$;


ALTER PROCEDURE public.sp_cliente_insertar(IN p_nombre character varying, IN p_domicilio character varying, IN p_telefono character varying, INOUT p_id character varying) OWNER TO postgres;

--
-- Name: sp_cliente_modificar(character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_cliente_modificar(IN p_id character varying, IN p_nombre character varying, IN p_domicilio character varying, IN p_telefono character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE cliente SET nombre = p_nombre, domicilio = p_domicilio, telefono = p_telefono
    WHERE id_cliente = p_id AND activo;
    IF NOT FOUND THEN RAISE EXCEPTION 'El cliente % no existe o está dado de baja', p_id; END IF;
END $$;


ALTER PROCEDURE public.sp_cliente_modificar(IN p_id character varying, IN p_nombre character varying, IN p_domicilio character varying, IN p_telefono character varying) OWNER TO postgres;

--
-- Name: sp_hoja_generar(character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_hoja_generar(IN p_id_retiro character varying, INOUT p_id character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM retiro_campo WHERE id_retiro = p_id_retiro AND activo) THEN
        RAISE EXCEPTION 'El retiro % no existe o está dado de baja', p_id_retiro;
    END IF;
    IF EXISTS (SELECT 1 FROM hoja_control_compra WHERE id_retiro = p_id_retiro) THEN
        RAISE EXCEPTION 'El retiro % ya tiene hoja de control (activa o dada de baja: reactívala)', p_id_retiro;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM detalle_retiro WHERE id_retiro = p_id_retiro) THEN
        RAISE EXCEPTION 'El retiro % no tiene líneas registradas', p_id_retiro;
    END IF;
    p_id := fn_siguiente_codigo('hoja_control_compra', 'id_compra', 'HC', 3);
    INSERT INTO hoja_control_compra (id_compra, fecha, id_retiro)
    SELECT p_id, fecha, id_retiro FROM retiro_campo WHERE id_retiro = p_id_retiro;
    INSERT INTO detalle_compra (id_compra, cod_producto, nombre_calidad, cantidad, precio_unitario)
    SELECT p_id, d.cod_producto, d.nombre_calidad, d.cantidad, c.precio_referencia
    FROM detalle_retiro d
    JOIN calidad c ON c.cod_producto = d.cod_producto AND c.nombre_calidad = d.nombre_calidad
    WHERE d.id_retiro = p_id_retiro;
END $$;


ALTER PROCEDURE public.sp_hoja_generar(IN p_id_retiro character varying, INOUT p_id character varying) OWNER TO postgres;

--
-- Name: sp_hoja_precio_modificar(character varying, character varying, character varying, numeric); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_hoja_precio_modificar(IN p_id character varying, IN p_cod character varying, IN p_cal character varying, IN p_precio numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM hoja_control_compra WHERE id_compra = p_id AND activo) THEN
        RAISE EXCEPTION 'La hoja de control % no existe o está dada de baja', p_id;
    END IF;
    UPDATE detalle_compra SET precio_unitario = p_precio
    WHERE id_compra = p_id AND cod_producto = p_cod AND nombre_calidad = p_cal;
    IF NOT FOUND THEN RAISE EXCEPTION 'La línea % % no existe en la hoja %', p_cod, p_cal, p_id; END IF;
END $$;


ALTER PROCEDURE public.sp_hoja_precio_modificar(IN p_id character varying, IN p_cod character varying, IN p_cal character varying, IN p_precio numeric) OWNER TO postgres;

--
-- Name: sp_nota_insertar(date, character varying, character varying, character varying, bytea, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_nota_insertar(IN p_fecha date, IN p_modalidad character varying, IN p_id_compra character varying, IN p_id_cliente character varying, IN p_firma bytea DEFAULT NULL::bytea, INOUT p_numero integer DEFAULT NULL::integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    p_numero := nextval('seq_numero_nota');
    INSERT INTO nota_pedido (numero_compra, fecha, modalidad_pago, firma_cliente, id_compra, id_cliente)
    VALUES (p_numero, p_fecha, p_modalidad, p_firma, p_id_compra, p_id_cliente);
END $$;


ALTER PROCEDURE public.sp_nota_insertar(IN p_fecha date, IN p_modalidad character varying, IN p_id_compra character varying, IN p_id_cliente character varying, IN p_firma bytea, INOUT p_numero integer) OWNER TO postgres;

--
-- Name: sp_nota_linea_guardar(integer, character varying, character varying, integer, numeric, numeric); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_nota_linea_guardar(IN p_numero integer, IN p_cod character varying, IN p_cal character varying, IN p_cajas integer, IN p_kilos numeric, IN p_precio numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM nota_pedido WHERE numero_compra = p_numero AND activo) THEN
        RAISE EXCEPTION 'La nota de pedido % no existe o está dada de baja', p_numero;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM calidad WHERE cod_producto = p_cod AND nombre_calidad = p_cal AND activo) THEN
        RAISE EXCEPTION 'La calidad % de % no existe o está dada de baja', p_cal, p_cod;
    END IF;
    IF (p_cajas IS NULL) = (p_kilos IS NULL) THEN
        RAISE EXCEPTION 'Indica cajas o kilos (solo uno de los dos)';
    END IF;
    UPDATE detalle_pedido SET cajas = p_cajas, kilos = p_kilos, precio_unitario = p_precio
    WHERE numero_compra = p_numero AND cod_producto = p_cod AND nombre_calidad = p_cal;
    IF NOT FOUND THEN
        INSERT INTO detalle_pedido (numero_compra, cod_producto, nombre_calidad, cajas, kilos, precio_unitario)
        VALUES (p_numero, p_cod, p_cal, p_cajas, p_kilos, p_precio);
    END IF;
END $$;


ALTER PROCEDURE public.sp_nota_linea_guardar(IN p_numero integer, IN p_cod character varying, IN p_cal character varying, IN p_cajas integer, IN p_kilos numeric, IN p_precio numeric) OWNER TO postgres;

--
-- Name: sp_nota_linea_quitar(integer, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_nota_linea_quitar(IN p_numero integer, IN p_cod character varying, IN p_cal character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM detalle_pedido WHERE numero_compra = p_numero AND cod_producto = p_cod AND nombre_calidad = p_cal;
    IF NOT FOUND THEN RAISE EXCEPTION 'La línea % % no existe en la nota %', p_cod, p_cal, p_numero; END IF;
END $$;


ALTER PROCEDURE public.sp_nota_linea_quitar(IN p_numero integer, IN p_cod character varying, IN p_cal character varying) OWNER TO postgres;

--
-- Name: sp_nota_modificar(integer, date, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_nota_modificar(IN p_numero integer, IN p_fecha date, IN p_modalidad character varying, IN p_id_compra character varying, IN p_id_cliente character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE nota_pedido SET fecha = p_fecha, modalidad_pago = p_modalidad,
                           id_compra = p_id_compra, id_cliente = p_id_cliente
    WHERE numero_compra = p_numero AND activo;
    IF NOT FOUND THEN RAISE EXCEPTION 'La nota de pedido % no existe o está dada de baja', p_numero; END IF;
END $$;


ALTER PROCEDURE public.sp_nota_modificar(IN p_numero integer, IN p_fecha date, IN p_modalidad character varying, IN p_id_compra character varying, IN p_id_cliente character varying) OWNER TO postgres;

--
-- Name: sp_producto_insertar(character varying, character varying, numeric, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_producto_insertar(IN p_nombre character varying, IN p_unidad character varying, IN p_kg_por_caja numeric, INOUT p_cod character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    p_cod := fn_siguiente_codigo('producto_agricola', 'cod_producto', 'PA', 2);
    INSERT INTO producto_agricola (cod_producto, nombre_producto, unidad_medida, kg_por_caja)
    VALUES (p_cod, p_nombre, p_unidad, p_kg_por_caja);
END $$;


ALTER PROCEDURE public.sp_producto_insertar(IN p_nombre character varying, IN p_unidad character varying, IN p_kg_por_caja numeric, INOUT p_cod character varying) OWNER TO postgres;

--
-- Name: sp_producto_modificar(character varying, character varying, character varying, numeric); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_producto_modificar(IN p_cod character varying, IN p_nombre character varying, IN p_unidad character varying, IN p_kg_por_caja numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE producto_agricola SET nombre_producto = p_nombre, unidad_medida = p_unidad, kg_por_caja = p_kg_por_caja
    WHERE cod_producto = p_cod AND activo;
    IF NOT FOUND THEN RAISE EXCEPTION 'El producto % no existe o está dado de baja', p_cod; END IF;
END $$;


ALTER PROCEDURE public.sp_producto_modificar(IN p_cod character varying, IN p_nombre character varying, IN p_unidad character varying, IN p_kg_por_caja numeric) OWNER TO postgres;

--
-- Name: sp_productor_insertar(character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_productor_insertar(IN p_nombre character varying, IN p_region character varying, INOUT p_id character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    p_id := fn_siguiente_codigo('productor', 'id_productor', 'PR', 3);
    INSERT INTO productor (id_productor, nombre, region_procedencia) VALUES (p_id, p_nombre, p_region);
END $$;


ALTER PROCEDURE public.sp_productor_insertar(IN p_nombre character varying, IN p_region character varying, INOUT p_id character varying) OWNER TO postgres;

--
-- Name: sp_productor_modificar(character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_productor_modificar(IN p_id character varying, IN p_nombre character varying, IN p_region character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE productor SET nombre = p_nombre, region_procedencia = p_region
    WHERE id_productor = p_id AND activo;
    IF NOT FOUND THEN RAISE EXCEPTION 'El productor % no existe o está dado de baja', p_id; END IF;
END $$;


ALTER PROCEDURE public.sp_productor_modificar(IN p_id character varying, IN p_nombre character varying, IN p_region character varying) OWNER TO postgres;

--
-- Name: sp_reactivar(text, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_reactivar(IN p_tabla text, IN p_clave text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    CASE p_tabla
    WHEN 'productor' THEN UPDATE productor SET activo = TRUE WHERE id_productor = p_clave AND NOT activo;
    WHEN 'cliente' THEN UPDATE cliente SET activo = TRUE WHERE id_cliente = p_clave AND NOT activo;
    WHEN 'producto_agricola' THEN UPDATE producto_agricola SET activo = TRUE WHERE cod_producto = p_clave AND NOT activo;
    WHEN 'calidad' THEN
        UPDATE calidad SET activo = TRUE
        WHERE cod_producto = split_part(p_clave, '|', 1) AND nombre_calidad = split_part(p_clave, '|', 2) AND NOT activo;
    WHEN 'retiro_campo' THEN UPDATE retiro_campo SET activo = TRUE WHERE id_retiro = p_clave AND NOT activo;
    WHEN 'hoja_control_compra' THEN UPDATE hoja_control_compra SET activo = TRUE WHERE id_compra = p_clave AND NOT activo;
    WHEN 'nota_pedido' THEN
        IF EXISTS (SELECT 1 FROM detalle_pedido d
                   JOIN v_stock s ON s.cod_producto = d.cod_producto AND s.nombre_calidad = d.nombre_calidad
                   WHERE d.numero_compra = p_clave::INT
                     AND fn_a_unidad_producto(d.cod_producto, d.cajas, d.kilos) > s.stock) THEN
            RAISE EXCEPTION 'No hay stock suficiente para reactivar la nota %', p_clave;
        END IF;
        UPDATE nota_pedido SET activo = TRUE WHERE numero_compra = p_clave::INT AND NOT activo;
    ELSE
        RAISE EXCEPTION 'Tabla no permitida para reactivar: %', p_tabla;
    END CASE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el registro % de % o ya está activo', p_clave, p_tabla;
    END IF;
END $$;


ALTER PROCEDURE public.sp_reactivar(IN p_tabla text, IN p_clave text) OWNER TO postgres;

--
-- Name: sp_retiro_insertar(date, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_retiro_insertar(IN p_fecha date, IN p_id_productor character varying, INOUT p_id character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM fn_asegurar_fecha_retiro(p_fecha);
    p_id := fn_siguiente_codigo('retiro_campo', 'id_retiro', 'RET', 3);
    INSERT INTO retiro_campo (id_retiro, fecha, id_productor) VALUES (p_id, p_fecha, p_id_productor);
END $$;


ALTER PROCEDURE public.sp_retiro_insertar(IN p_fecha date, IN p_id_productor character varying, INOUT p_id character varying) OWNER TO postgres;

--
-- Name: sp_retiro_linea_guardar(character varying, character varying, character varying, numeric); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_retiro_linea_guardar(IN p_id character varying, IN p_cod character varying, IN p_cal character varying, IN p_cantidad numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM retiro_campo WHERE id_retiro = p_id AND activo) THEN
        RAISE EXCEPTION 'El retiro % no existe o está dado de baja', p_id;
    END IF;
    IF EXISTS (SELECT 1 FROM hoja_control_compra WHERE id_retiro = p_id AND activo) THEN
        RAISE EXCEPTION 'El retiro % ya tiene hoja de control activa: no se pueden cambiar sus líneas', p_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM calidad WHERE cod_producto = p_cod AND nombre_calidad = p_cal AND activo) THEN
        RAISE EXCEPTION 'La calidad % de % no existe o está dada de baja', p_cal, p_cod;
    END IF;
    UPDATE detalle_retiro SET cantidad = p_cantidad
    WHERE id_retiro = p_id AND cod_producto = p_cod AND nombre_calidad = p_cal;
    IF NOT FOUND THEN
        INSERT INTO detalle_retiro (id_retiro, cod_producto, nombre_calidad, cantidad)
        VALUES (p_id, p_cod, p_cal, p_cantidad);
    END IF;
END $$;


ALTER PROCEDURE public.sp_retiro_linea_guardar(IN p_id character varying, IN p_cod character varying, IN p_cal character varying, IN p_cantidad numeric) OWNER TO postgres;

--
-- Name: sp_retiro_linea_quitar(character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_retiro_linea_quitar(IN p_id character varying, IN p_cod character varying, IN p_cal character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM hoja_control_compra WHERE id_retiro = p_id AND activo) THEN
        RAISE EXCEPTION 'El retiro % ya tiene hoja de control activa: no se pueden cambiar sus líneas', p_id;
    END IF;
    DELETE FROM detalle_retiro WHERE id_retiro = p_id AND cod_producto = p_cod AND nombre_calidad = p_cal;
    IF NOT FOUND THEN RAISE EXCEPTION 'La línea % % no existe en el retiro %', p_cod, p_cal, p_id; END IF;
END $$;


ALTER PROCEDURE public.sp_retiro_linea_quitar(IN p_id character varying, IN p_cod character varying, IN p_cal character varying) OWNER TO postgres;

--
-- Name: sp_retiro_modificar(character varying, date, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_retiro_modificar(IN p_id character varying, IN p_fecha date, IN p_id_productor character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM hoja_control_compra WHERE id_retiro = p_id AND activo) THEN
        RAISE EXCEPTION 'El retiro % ya tiene hoja de control activa: dala de baja antes de modificarlo', p_id;
    END IF;
    PERFORM fn_asegurar_fecha_retiro(p_fecha);
    UPDATE retiro_campo SET fecha = p_fecha, id_productor = p_id_productor WHERE id_retiro = p_id AND activo;
    IF NOT FOUND THEN RAISE EXCEPTION 'El retiro % no existe o está dado de baja', p_id; END IF;
END $$;


ALTER PROCEDURE public.sp_retiro_modificar(IN p_id character varying, IN p_fecha date, IN p_id_productor character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: auditoria; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auditoria (
    id_auditoria bigint NOT NULL,
    tabla character varying(40) NOT NULL,
    operacion character varying(10) NOT NULL,
    clave character varying(80),
    datos_antes jsonb,
    datos_despues jsonb,
    usuario character varying(60) DEFAULT CURRENT_USER NOT NULL,
    fecha timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.auditoria OWNER TO postgres;

--
-- Name: auditoria_id_auditoria_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.auditoria_id_auditoria_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.auditoria_id_auditoria_seq OWNER TO postgres;

--
-- Name: auditoria_id_auditoria_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.auditoria_id_auditoria_seq OWNED BY public.auditoria.id_auditoria;


--
-- Name: calendario_retiro; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.calendario_retiro (
    fecha date NOT NULL,
    dia_semana character varying(10) NOT NULL,
    CONSTRAINT calendario_retiro_dia_semana_check CHECK (((dia_semana)::text = ANY ((ARRAY['Lunes'::character varying, 'Jueves'::character varying, 'Sábado'::character varying])::text[]))),
    CONSTRAINT ck_dia_coincide_fecha CHECK (((((dia_semana)::text = 'Lunes'::text) AND (EXTRACT(isodow FROM fecha) = (1)::numeric)) OR (((dia_semana)::text = 'Jueves'::text) AND (EXTRACT(isodow FROM fecha) = (4)::numeric)) OR (((dia_semana)::text = 'Sábado'::text) AND (EXTRACT(isodow FROM fecha) = (6)::numeric))))
);


ALTER TABLE public.calendario_retiro OWNER TO postgres;

--
-- Name: calidad; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.calidad (
    cod_producto character varying(10) NOT NULL,
    nombre_calidad character varying(20) NOT NULL,
    precio_referencia numeric(8,2) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_baja timestamp with time zone,
    motivo_baja character varying(200),
    CONSTRAINT calidad_precio_referencia_check CHECK ((precio_referencia > (0)::numeric))
);


ALTER TABLE public.calidad OWNER TO postgres;

--
-- Name: calidad_alias; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.calidad_alias (
    cod_producto character varying(10) NOT NULL,
    nombre_calidad character varying(20) NOT NULL,
    alias_por_documento character varying(30) NOT NULL
);


ALTER TABLE public.calidad_alias OWNER TO postgres;

--
-- Name: cliente; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cliente (
    id_cliente character varying(10) NOT NULL,
    nombre character varying(100) NOT NULL,
    domicilio character varying(150),
    telefono character varying(15),
    activo boolean DEFAULT true NOT NULL,
    fecha_baja timestamp with time zone,
    motivo_baja character varying(200)
);


ALTER TABLE public.cliente OWNER TO postgres;

--
-- Name: detalle_compra; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalle_compra (
    id_compra character varying(10) NOT NULL,
    cod_producto character varying(10) NOT NULL,
    nombre_calidad character varying(20) NOT NULL,
    cantidad numeric(8,2) NOT NULL,
    precio_unitario numeric(8,2) NOT NULL,
    CONSTRAINT detalle_compra_cantidad_check CHECK ((cantidad > (0)::numeric)),
    CONSTRAINT detalle_compra_precio_unitario_check CHECK ((precio_unitario > (0)::numeric))
);


ALTER TABLE public.detalle_compra OWNER TO postgres;

--
-- Name: detalle_pedido; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalle_pedido (
    numero_compra integer NOT NULL,
    cod_producto character varying(10) NOT NULL,
    nombre_calidad character varying(20) NOT NULL,
    cajas integer,
    kilos numeric(8,2),
    precio_unitario numeric(8,2) NOT NULL,
    CONSTRAINT detalle_pedido_cajas_check CHECK (((cajas IS NULL) OR (cajas >= 0))),
    CONSTRAINT detalle_pedido_check CHECK ((((cajas IS NOT NULL) AND (kilos IS NULL)) OR ((cajas IS NULL) AND (kilos IS NOT NULL)))),
    CONSTRAINT detalle_pedido_kilos_check CHECK (((kilos IS NULL) OR (kilos >= (0)::numeric))),
    CONSTRAINT detalle_pedido_precio_unitario_check CHECK ((precio_unitario > (0)::numeric))
);


ALTER TABLE public.detalle_pedido OWNER TO postgres;

--
-- Name: detalle_retiro; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalle_retiro (
    id_retiro character varying(10) NOT NULL,
    cod_producto character varying(10) NOT NULL,
    nombre_calidad character varying(20) NOT NULL,
    cantidad numeric(8,2) NOT NULL,
    CONSTRAINT detalle_retiro_cantidad_check CHECK ((cantidad > (0)::numeric))
);


ALTER TABLE public.detalle_retiro OWNER TO postgres;

--
-- Name: hoja_control_compra; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hoja_control_compra (
    id_compra character varying(10) NOT NULL,
    fecha date NOT NULL,
    id_retiro character varying(10) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_baja timestamp with time zone,
    motivo_baja character varying(200)
);


ALTER TABLE public.hoja_control_compra OWNER TO postgres;

--
-- Name: nota_pedido; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nota_pedido (
    numero_compra integer NOT NULL,
    fecha date NOT NULL,
    modalidad_pago character varying(10) NOT NULL,
    firma_cliente bytea,
    id_compra character varying(10) NOT NULL,
    id_cliente character varying(10) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_baja timestamp with time zone,
    motivo_baja character varying(200),
    CONSTRAINT nota_pedido_modalidad_pago_check CHECK (((modalidad_pago)::text = ANY ((ARRAY['Crédito'::character varying, 'Contado'::character varying])::text[])))
);


ALTER TABLE public.nota_pedido OWNER TO postgres;

--
-- Name: producto_agricola; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.producto_agricola (
    cod_producto character varying(10) NOT NULL,
    nombre_producto character varying(50) NOT NULL,
    unidad_medida character varying(10) NOT NULL,
    kg_por_caja numeric(6,2) DEFAULT 10 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_baja timestamp with time zone,
    motivo_baja character varying(200),
    CONSTRAINT producto_agricola_kg_por_caja_check CHECK ((kg_por_caja > (0)::numeric)),
    CONSTRAINT producto_agricola_unidad_medida_check CHECK (((unidad_medida)::text = ANY ((ARRAY['Kilogramo'::character varying, 'Caja'::character varying])::text[])))
);


ALTER TABLE public.producto_agricola OWNER TO postgres;

--
-- Name: productor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.productor (
    id_productor character varying(10) NOT NULL,
    nombre character varying(100) NOT NULL,
    region_procedencia character varying(20) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_baja timestamp with time zone,
    motivo_baja character varying(200),
    CONSTRAINT productor_region_procedencia_check CHECK (((region_procedencia)::text = ANY ((ARRAY['Ica'::character varying, 'Chincha'::character varying, 'Pisco'::character varying, 'Pedregal'::character varying, 'Tacna'::character varying])::text[])))
);


ALTER TABLE public.productor OWNER TO postgres;

--
-- Name: retiro_campo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.retiro_campo (
    id_retiro character varying(10) NOT NULL,
    fecha date NOT NULL,
    id_productor character varying(10) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_baja timestamp with time zone,
    motivo_baja character varying(200)
);


ALTER TABLE public.retiro_campo OWNER TO postgres;

--
-- Name: seq_numero_nota; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.seq_numero_nota
    START WITH 1456
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.seq_numero_nota OWNER TO postgres;

--
-- Name: v_stock; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_stock AS
 WITH compras AS (
         SELECT dc.cod_producto,
            dc.nombre_calidad,
            sum(dc.cantidad) AS comprado
           FROM (public.detalle_compra dc
             JOIN public.hoja_control_compra h ON ((((h.id_compra)::text = (dc.id_compra)::text) AND h.activo)))
          GROUP BY dc.cod_producto, dc.nombre_calidad
        ), ventas AS (
         SELECT dp.cod_producto,
            dp.nombre_calidad,
            sum(
                CASE a_1.unidad_medida
                    WHEN 'Kilogramo'::text THEN COALESCE(dp.kilos, ((dp.cajas)::numeric * a_1.kg_por_caja))
                    ELSE COALESCE((dp.cajas)::numeric, (dp.kilos / a_1.kg_por_caja))
                END) AS vendido
           FROM ((public.detalle_pedido dp
             JOIN public.nota_pedido np ON (((np.numero_compra = dp.numero_compra) AND np.activo)))
             JOIN public.producto_agricola a_1 ON (((a_1.cod_producto)::text = (dp.cod_producto)::text)))
          GROUP BY dp.cod_producto, dp.nombre_calidad
        )
 SELECT a.cod_producto,
    a.nombre_producto,
    a.unidad_medida,
    c.nombre_calidad,
    (COALESCE(co.comprado, (0)::numeric))::numeric(10,2) AS comprado,
    (COALESCE(v.vendido, (0)::numeric))::numeric(10,2) AS vendido,
    ((COALESCE(co.comprado, (0)::numeric) - COALESCE(v.vendido, (0)::numeric)))::numeric(10,2) AS stock
   FROM (((public.calidad c
     JOIN public.producto_agricola a ON (((a.cod_producto)::text = (c.cod_producto)::text)))
     LEFT JOIN compras co ON ((((co.cod_producto)::text = (c.cod_producto)::text) AND ((co.nombre_calidad)::text = (c.nombre_calidad)::text))))
     LEFT JOIN ventas v ON ((((v.cod_producto)::text = (c.cod_producto)::text) AND ((v.nombre_calidad)::text = (c.nombre_calidad)::text))))
  WHERE c.activo;


ALTER VIEW public.v_stock OWNER TO postgres;

--
-- Name: auditoria id_auditoria; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auditoria ALTER COLUMN id_auditoria SET DEFAULT nextval('public.auditoria_id_auditoria_seq'::regclass);


--
-- Data for Name: auditoria; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auditoria (id_auditoria, tabla, operacion, clave, datos_antes, datos_despues, usuario, fecha) FROM stdin;
1	productor	INSERT	PR001	\N	{"activo": true, "nombre": "Productor Los Andes", "fecha_baja": null, "motivo_baja": null, "id_productor": "PR001", "region_procedencia": "Ica"}	postgres	2026-11-14 08:08:19.82669-05
2	productor	INSERT	PR002	\N	{"activo": true, "nombre": "Asociación Agrícola Santa Rosa", "fecha_baja": null, "motivo_baja": null, "id_productor": "PR002", "region_procedencia": "Chincha"}	postgres	2026-11-14 08:08:19.82669-05
3	productor	INSERT	PR003	\N	{"activo": true, "nombre": "Productor El Pedregal", "fecha_baja": null, "motivo_baja": null, "id_productor": "PR003", "region_procedencia": "Pedregal"}	postgres	2026-11-14 08:08:19.82669-05
4	producto_agricola	INSERT	PA01	\N	{"activo": true, "fecha_baja": null, "kg_por_caja": 10.00, "motivo_baja": null, "cod_producto": "PA01", "unidad_medida": "Kilogramo", "nombre_producto": "Fresa"}	postgres	2026-11-14 08:08:19.82669-05
5	producto_agricola	INSERT	PA02	\N	{"activo": true, "fecha_baja": null, "kg_por_caja": 10.00, "motivo_baja": null, "cod_producto": "PA02", "unidad_medida": "Kilogramo", "nombre_producto": "Uva"}	postgres	2026-11-14 08:08:19.82669-05
6	producto_agricola	INSERT	PA03	\N	{"activo": true, "fecha_baja": null, "kg_por_caja": 10.00, "motivo_baja": null, "cod_producto": "PA03", "unidad_medida": "Caja", "nombre_producto": "Arándano"}	postgres	2026-11-14 08:08:19.82669-05
7	calidad	INSERT	PA01|Primera	\N	{"activo": true, "fecha_baja": null, "motivo_baja": null, "cod_producto": "PA01", "nombre_calidad": "Primera", "precio_referencia": 8.00}	postgres	2026-11-14 08:08:19.82669-05
8	calidad	INSERT	PA01|Segunda	\N	{"activo": true, "fecha_baja": null, "motivo_baja": null, "cod_producto": "PA01", "nombre_calidad": "Segunda", "precio_referencia": 7.00}	postgres	2026-11-14 08:08:19.82669-05
9	calidad	INSERT	PA01|Tercera	\N	{"activo": true, "fecha_baja": null, "motivo_baja": null, "cod_producto": "PA01", "nombre_calidad": "Tercera", "precio_referencia": 6.00}	postgres	2026-11-14 08:08:19.82669-05
10	calidad	INSERT	PA01|Cuarta	\N	{"activo": true, "fecha_baja": null, "motivo_baja": null, "cod_producto": "PA01", "nombre_calidad": "Cuarta", "precio_referencia": 5.00}	postgres	2026-11-14 08:08:19.82669-05
11	calidad	INSERT	PA01|Descarte	\N	{"activo": true, "fecha_baja": null, "motivo_baja": null, "cod_producto": "PA01", "nombre_calidad": "Descarte", "precio_referencia": 2.50}	postgres	2026-11-14 08:08:19.82669-05
12	calidad	INSERT	PA02|Primera	\N	{"activo": true, "fecha_baja": null, "motivo_baja": null, "cod_producto": "PA02", "nombre_calidad": "Primera", "precio_referencia": 6.50}	postgres	2026-11-14 08:08:19.82669-05
13	calidad	INSERT	PA02|Segunda	\N	{"activo": true, "fecha_baja": null, "motivo_baja": null, "cod_producto": "PA02", "nombre_calidad": "Segunda", "precio_referencia": 5.50}	postgres	2026-11-14 08:08:19.82669-05
14	calidad	INSERT	PA03|Primera	\N	{"activo": true, "fecha_baja": null, "motivo_baja": null, "cod_producto": "PA03", "nombre_calidad": "Primera", "precio_referencia": 18.00}	postgres	2026-11-14 08:08:19.82669-05
15	calidad	INSERT	PA03|Segunda	\N	{"activo": true, "fecha_baja": null, "motivo_baja": null, "cod_producto": "PA03", "nombre_calidad": "Segunda", "precio_referencia": 15.00}	postgres	2026-11-14 08:08:19.82669-05
16	cliente	INSERT	CL001	\N	{"activo": true, "nombre": "Yaneth Quispe", "telefono": "987654321", "domicilio": "Puesto Elena, plataforma comercial", "fecha_baja": null, "id_cliente": "CL001", "motivo_baja": null}	postgres	2026-11-14 08:08:19.82669-05
17	cliente	INSERT	CL002	\N	{"activo": true, "nombre": "Mercado Santa Rosa", "telefono": "956123789", "domicilio": "Chincha Alta", "fecha_baja": null, "id_cliente": "CL002", "motivo_baja": null}	postgres	2026-11-14 08:08:19.82669-05
18	cliente	INSERT	CL003	\N	{"activo": true, "nombre": "Frutería La Preferida", "telefono": "945678123", "domicilio": "Ica centro", "fecha_baja": null, "id_cliente": "CL003", "motivo_baja": null}	postgres	2026-11-14 08:08:19.82669-05
19	retiro_campo	INSERT	RET001	\N	{"fecha": "2026-10-19", "activo": true, "id_retiro": "RET001", "fecha_baja": null, "motivo_baja": null, "id_productor": "PR001"}	postgres	2026-11-14 08:08:19.82669-05
20	retiro_campo	INSERT	RET002	\N	{"fecha": "2026-10-22", "activo": true, "id_retiro": "RET002", "fecha_baja": null, "motivo_baja": null, "id_productor": "PR002"}	postgres	2026-11-14 08:08:19.82669-05
21	retiro_campo	INSERT	RET003	\N	{"fecha": "2026-10-24", "activo": true, "id_retiro": "RET003", "fecha_baja": null, "motivo_baja": null, "id_productor": "PR003"}	postgres	2026-11-14 08:08:19.82669-05
22	detalle_retiro	INSERT	RET001|PA01|Primera	\N	{"cantidad": 100.00, "id_retiro": "RET001", "cod_producto": "PA01", "nombre_calidad": "Primera"}	postgres	2026-11-14 08:08:19.82669-05
23	detalle_retiro	INSERT	RET001|PA01|Segunda	\N	{"cantidad": 120.00, "id_retiro": "RET001", "cod_producto": "PA01", "nombre_calidad": "Segunda"}	postgres	2026-11-14 08:08:19.82669-05
24	detalle_retiro	INSERT	RET001|PA01|Tercera	\N	{"cantidad": 80.00, "id_retiro": "RET001", "cod_producto": "PA01", "nombre_calidad": "Tercera"}	postgres	2026-11-14 08:08:19.82669-05
25	detalle_retiro	INSERT	RET002|PA01|Primera	\N	{"cantidad": 90.00, "id_retiro": "RET002", "cod_producto": "PA01", "nombre_calidad": "Primera"}	postgres	2026-11-14 08:08:19.82669-05
26	detalle_retiro	INSERT	RET002|PA01|Segunda	\N	{"cantidad": 110.00, "id_retiro": "RET002", "cod_producto": "PA01", "nombre_calidad": "Segunda"}	postgres	2026-11-14 08:08:19.82669-05
27	detalle_retiro	INSERT	RET002|PA02|Primera	\N	{"cantidad": 60.00, "id_retiro": "RET002", "cod_producto": "PA02", "nombre_calidad": "Primera"}	postgres	2026-11-14 08:08:19.82669-05
28	detalle_retiro	INSERT	RET003|PA01|Primera	\N	{"cantidad": 130.00, "id_retiro": "RET003", "cod_producto": "PA01", "nombre_calidad": "Primera"}	postgres	2026-11-14 08:08:19.82669-05
29	detalle_retiro	INSERT	RET003|PA01|Descarte	\N	{"cantidad": 25.00, "id_retiro": "RET003", "cod_producto": "PA01", "nombre_calidad": "Descarte"}	postgres	2026-11-14 08:08:19.82669-05
30	detalle_retiro	INSERT	RET003|PA03|Primera	\N	{"cantidad": 20.00, "id_retiro": "RET003", "cod_producto": "PA03", "nombre_calidad": "Primera"}	postgres	2026-11-14 08:08:19.82669-05
31	hoja_control_compra	INSERT	HC001	\N	{"fecha": "2026-10-19", "activo": true, "id_compra": "HC001", "id_retiro": "RET001", "fecha_baja": null, "motivo_baja": null}	postgres	2026-11-14 08:08:19.82669-05
32	hoja_control_compra	INSERT	HC002	\N	{"fecha": "2026-10-22", "activo": true, "id_compra": "HC002", "id_retiro": "RET002", "fecha_baja": null, "motivo_baja": null}	postgres	2026-11-14 08:08:19.82669-05
33	hoja_control_compra	INSERT	HC003	\N	{"fecha": "2026-10-24", "activo": true, "id_compra": "HC003", "id_retiro": "RET003", "fecha_baja": null, "motivo_baja": null}	postgres	2026-11-14 08:08:19.82669-05
34	detalle_compra	INSERT	HC001|PA01|Primera	\N	{"cantidad": 100.00, "id_compra": "HC001", "cod_producto": "PA01", "nombre_calidad": "Primera", "precio_unitario": 8.00}	postgres	2026-11-14 08:08:19.82669-05
35	detalle_compra	INSERT	HC001|PA01|Segunda	\N	{"cantidad": 120.00, "id_compra": "HC001", "cod_producto": "PA01", "nombre_calidad": "Segunda", "precio_unitario": 7.00}	postgres	2026-11-14 08:08:19.82669-05
36	detalle_compra	INSERT	HC001|PA01|Tercera	\N	{"cantidad": 80.00, "id_compra": "HC001", "cod_producto": "PA01", "nombre_calidad": "Tercera", "precio_unitario": 6.00}	postgres	2026-11-14 08:08:19.82669-05
37	detalle_compra	INSERT	HC002|PA01|Primera	\N	{"cantidad": 90.00, "id_compra": "HC002", "cod_producto": "PA01", "nombre_calidad": "Primera", "precio_unitario": 8.00}	postgres	2026-11-14 08:08:19.82669-05
38	detalle_compra	INSERT	HC002|PA01|Segunda	\N	{"cantidad": 110.00, "id_compra": "HC002", "cod_producto": "PA01", "nombre_calidad": "Segunda", "precio_unitario": 7.00}	postgres	2026-11-14 08:08:19.82669-05
39	detalle_compra	INSERT	HC002|PA02|Primera	\N	{"cantidad": 60.00, "id_compra": "HC002", "cod_producto": "PA02", "nombre_calidad": "Primera", "precio_unitario": 6.50}	postgres	2026-11-14 08:08:19.82669-05
40	detalle_compra	INSERT	HC003|PA01|Primera	\N	{"cantidad": 130.00, "id_compra": "HC003", "cod_producto": "PA01", "nombre_calidad": "Primera", "precio_unitario": 8.00}	postgres	2026-11-14 08:08:19.82669-05
41	detalle_compra	INSERT	HC003|PA01|Descarte	\N	{"cantidad": 25.00, "id_compra": "HC003", "cod_producto": "PA01", "nombre_calidad": "Descarte", "precio_unitario": 2.50}	postgres	2026-11-14 08:08:19.82669-05
42	detalle_compra	INSERT	HC003|PA03|Primera	\N	{"cantidad": 20.00, "id_compra": "HC003", "cod_producto": "PA03", "nombre_calidad": "Primera", "precio_unitario": 18.00}	postgres	2026-11-14 08:08:19.82669-05
43	nota_pedido	INSERT	1453	\N	{"fecha": "2026-10-19", "activo": true, "id_compra": "HC001", "fecha_baja": null, "id_cliente": "CL001", "motivo_baja": null, "firma_cliente": null, "numero_compra": 1453, "modalidad_pago": "Contado"}	postgres	2026-11-14 08:08:19.82669-05
44	nota_pedido	INSERT	1454	\N	{"fecha": "2026-10-22", "activo": true, "id_compra": "HC002", "fecha_baja": null, "id_cliente": "CL002", "motivo_baja": null, "firma_cliente": null, "numero_compra": 1454, "modalidad_pago": "Crédito"}	postgres	2026-11-14 08:08:19.82669-05
45	nota_pedido	INSERT	1455	\N	{"fecha": "2026-10-24", "activo": true, "id_compra": "HC003", "fecha_baja": null, "id_cliente": "CL003", "motivo_baja": null, "firma_cliente": null, "numero_compra": 1455, "modalidad_pago": "Contado"}	postgres	2026-11-14 08:08:19.82669-05
46	detalle_pedido	INSERT	1453|PA01|Primera	\N	{"cajas": null, "kilos": 20.00, "cod_producto": "PA01", "numero_compra": 1453, "nombre_calidad": "Primera", "precio_unitario": 12.00}	postgres	2026-11-14 08:08:19.82669-05
47	detalle_pedido	INSERT	1453|PA01|Segunda	\N	{"cajas": null, "kilos": 15.00, "cod_producto": "PA01", "numero_compra": 1453, "nombre_calidad": "Segunda", "precio_unitario": 10.50}	postgres	2026-11-14 08:08:19.82669-05
48	detalle_pedido	INSERT	1454|PA01|Primera	\N	{"cajas": null, "kilos": 25.00, "cod_producto": "PA01", "numero_compra": 1454, "nombre_calidad": "Primera", "precio_unitario": 12.00}	postgres	2026-11-14 08:08:19.82669-05
49	detalle_pedido	INSERT	1454|PA02|Primera	\N	{"cajas": null, "kilos": 10.00, "cod_producto": "PA02", "numero_compra": 1454, "nombre_calidad": "Primera", "precio_unitario": 9.00}	postgres	2026-11-14 08:08:19.82669-05
50	detalle_pedido	INSERT	1455|PA01|Primera	\N	{"cajas": null, "kilos": 30.00, "cod_producto": "PA01", "numero_compra": 1455, "nombre_calidad": "Primera", "precio_unitario": 12.00}	postgres	2026-11-14 08:08:19.82669-05
51	detalle_pedido	INSERT	1455|PA03|Primera	\N	{"cajas": 5, "kilos": null, "cod_producto": "PA03", "numero_compra": 1455, "nombre_calidad": "Primera", "precio_unitario": 25.00}	postgres	2026-11-14 08:08:19.82669-05
77	retiro_campo	INSERT	RET004	\N	{"fecha": "2026-11-21", "activo": true, "id_retiro": "RET004", "fecha_baja": null, "motivo_baja": null, "id_productor": "PR001"}	postgres	2026-11-20 12:46:11.501937-05
78	detalle_retiro	INSERT	RET004|PA01|Primera	\N	{"cantidad": 2.00, "id_retiro": "RET004", "cod_producto": "PA01", "nombre_calidad": "Primera"}	postgres	2026-11-20 12:46:11.501937-05
79	hoja_control_compra	INSERT	HC004	\N	{"fecha": "2026-11-21", "activo": true, "id_compra": "HC004", "id_retiro": "RET004", "fecha_baja": null, "motivo_baja": null}	postgres	2026-11-20 12:46:42.634679-05
80	detalle_compra	INSERT	HC004|PA01|Primera	\N	{"cantidad": 2.00, "id_compra": "HC004", "cod_producto": "PA01", "nombre_calidad": "Primera", "precio_unitario": 8.00}	postgres	2026-11-20 12:46:42.634679-05
81	retiro_campo	INSERT	RET005	\N	{"fecha": "2026-11-21", "activo": true, "id_retiro": "RET005", "fecha_baja": null, "motivo_baja": null, "id_productor": "PR001"}	postgres	2026-11-20 16:30:55.691506-05
82	detalle_retiro	INSERT	RET005|PA01|Primera	\N	{"cantidad": 2.00, "id_retiro": "RET005", "cod_producto": "PA01", "nombre_calidad": "Primera"}	postgres	2026-11-20 16:30:55.691506-05
\.


--
-- Data for Name: calendario_retiro; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.calendario_retiro (fecha, dia_semana) FROM stdin;
2026-10-19	Lunes
2026-10-22	Jueves
2026-10-24	Sábado
2026-11-21	Sábado
\.


--
-- Data for Name: calidad; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.calidad (cod_producto, nombre_calidad, precio_referencia, activo, fecha_baja, motivo_baja) FROM stdin;
PA01	Primera	8.00	t	\N	\N
PA01	Segunda	7.00	t	\N	\N
PA01	Tercera	6.00	t	\N	\N
PA01	Cuarta	5.00	t	\N	\N
PA01	Descarte	2.50	t	\N	\N
PA02	Primera	6.50	t	\N	\N
PA02	Segunda	5.50	t	\N	\N
PA03	Primera	18.00	t	\N	\N
PA03	Segunda	15.00	t	\N	\N
\.


--
-- Data for Name: calidad_alias; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.calidad_alias (cod_producto, nombre_calidad, alias_por_documento) FROM stdin;
PA01	Primera	I
PA01	Primera	1era
PA01	Segunda	II
PA01	Segunda	2da
PA01	Tercera	III
PA01	Tercera	3era
PA01	Cuarta	IV
PA01	Descarte	Descarte
\.


--
-- Data for Name: cliente; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cliente (id_cliente, nombre, domicilio, telefono, activo, fecha_baja, motivo_baja) FROM stdin;
CL001	Yaneth Quispe	Puesto Elena, plataforma comercial	987654321	t	\N	\N
CL002	Mercado Santa Rosa	Chincha Alta	956123789	t	\N	\N
CL003	Frutería La Preferida	Ica centro	945678123	t	\N	\N
\.


--
-- Data for Name: detalle_compra; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalle_compra (id_compra, cod_producto, nombre_calidad, cantidad, precio_unitario) FROM stdin;
HC001	PA01	Primera	100.00	8.00
HC001	PA01	Segunda	120.00	7.00
HC001	PA01	Tercera	80.00	6.00
HC002	PA01	Primera	90.00	8.00
HC002	PA01	Segunda	110.00	7.00
HC002	PA02	Primera	60.00	6.50
HC003	PA01	Primera	130.00	8.00
HC003	PA01	Descarte	25.00	2.50
HC003	PA03	Primera	20.00	18.00
HC004	PA01	Primera	2.00	8.00
\.


--
-- Data for Name: detalle_pedido; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalle_pedido (numero_compra, cod_producto, nombre_calidad, cajas, kilos, precio_unitario) FROM stdin;
1453	PA01	Primera	\N	20.00	12.00
1453	PA01	Segunda	\N	15.00	10.50
1454	PA01	Primera	\N	25.00	12.00
1454	PA02	Primera	\N	10.00	9.00
1455	PA01	Primera	\N	30.00	12.00
1455	PA03	Primera	5	\N	25.00
\.


--
-- Data for Name: detalle_retiro; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalle_retiro (id_retiro, cod_producto, nombre_calidad, cantidad) FROM stdin;
RET001	PA01	Primera	100.00
RET001	PA01	Segunda	120.00
RET001	PA01	Tercera	80.00
RET002	PA01	Primera	90.00
RET002	PA01	Segunda	110.00
RET002	PA02	Primera	60.00
RET003	PA01	Primera	130.00
RET003	PA01	Descarte	25.00
RET003	PA03	Primera	20.00
RET004	PA01	Primera	2.00
RET005	PA01	Primera	2.00
\.


--
-- Data for Name: hoja_control_compra; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hoja_control_compra (id_compra, fecha, id_retiro, activo, fecha_baja, motivo_baja) FROM stdin;
HC001	2026-10-19	RET001	t	\N	\N
HC002	2026-10-22	RET002	t	\N	\N
HC003	2026-10-24	RET003	t	\N	\N
HC004	2026-11-21	RET004	t	\N	\N
\.


--
-- Data for Name: nota_pedido; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nota_pedido (numero_compra, fecha, modalidad_pago, firma_cliente, id_compra, id_cliente, activo, fecha_baja, motivo_baja) FROM stdin;
1453	2026-10-19	Contado	\N	HC001	CL001	t	\N	\N
1454	2026-10-22	Crédito	\N	HC002	CL002	t	\N	\N
1455	2026-10-24	Contado	\N	HC003	CL003	t	\N	\N
\.


--
-- Data for Name: producto_agricola; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.producto_agricola (cod_producto, nombre_producto, unidad_medida, kg_por_caja, activo, fecha_baja, motivo_baja) FROM stdin;
PA01	Fresa	Kilogramo	10.00	t	\N	\N
PA02	Uva	Kilogramo	10.00	t	\N	\N
PA03	Arándano	Caja	10.00	t	\N	\N
\.


--
-- Data for Name: productor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.productor (id_productor, nombre, region_procedencia, activo, fecha_baja, motivo_baja) FROM stdin;
PR001	Productor Los Andes	Ica	t	\N	\N
PR002	Asociación Agrícola Santa Rosa	Chincha	t	\N	\N
PR003	Productor El Pedregal	Pedregal	t	\N	\N
\.


--
-- Data for Name: retiro_campo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.retiro_campo (id_retiro, fecha, id_productor, activo, fecha_baja, motivo_baja) FROM stdin;
RET001	2026-10-19	PR001	t	\N	\N
RET002	2026-10-22	PR002	t	\N	\N
RET003	2026-10-24	PR003	t	\N	\N
RET004	2026-11-21	PR001	t	\N	\N
RET005	2026-11-21	PR001	t	\N	\N
\.


--
-- Name: auditoria_id_auditoria_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auditoria_id_auditoria_seq', 82, true);


--
-- Name: seq_numero_nota; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.seq_numero_nota', 1456, true);


--
-- Name: auditoria auditoria_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auditoria
    ADD CONSTRAINT auditoria_pkey PRIMARY KEY (id_auditoria);


--
-- Name: calendario_retiro calendario_retiro_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calendario_retiro
    ADD CONSTRAINT calendario_retiro_pkey PRIMARY KEY (fecha);


--
-- Name: calidad_alias calidad_alias_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calidad_alias
    ADD CONSTRAINT calidad_alias_pkey PRIMARY KEY (cod_producto, nombre_calidad, alias_por_documento);


--
-- Name: calidad calidad_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calidad
    ADD CONSTRAINT calidad_pkey PRIMARY KEY (cod_producto, nombre_calidad);


--
-- Name: cliente cliente_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT cliente_pkey PRIMARY KEY (id_cliente);


--
-- Name: detalle_compra detalle_compra_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_compra
    ADD CONSTRAINT detalle_compra_pkey PRIMARY KEY (id_compra, cod_producto, nombre_calidad);


--
-- Name: detalle_pedido detalle_pedido_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_pedido
    ADD CONSTRAINT detalle_pedido_pkey PRIMARY KEY (numero_compra, cod_producto, nombre_calidad);


--
-- Name: detalle_retiro detalle_retiro_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_retiro
    ADD CONSTRAINT detalle_retiro_pkey PRIMARY KEY (id_retiro, cod_producto, nombre_calidad);


--
-- Name: hoja_control_compra hoja_control_compra_id_retiro_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoja_control_compra
    ADD CONSTRAINT hoja_control_compra_id_retiro_key UNIQUE (id_retiro);


--
-- Name: hoja_control_compra hoja_control_compra_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoja_control_compra
    ADD CONSTRAINT hoja_control_compra_pkey PRIMARY KEY (id_compra);


--
-- Name: nota_pedido nota_pedido_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nota_pedido
    ADD CONSTRAINT nota_pedido_pkey PRIMARY KEY (numero_compra);


--
-- Name: producto_agricola producto_agricola_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.producto_agricola
    ADD CONSTRAINT producto_agricola_pkey PRIMARY KEY (cod_producto);


--
-- Name: productor productor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.productor
    ADD CONSTRAINT productor_pkey PRIMARY KEY (id_productor);


--
-- Name: retiro_campo retiro_campo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.retiro_campo
    ADD CONSTRAINT retiro_campo_pkey PRIMARY KEY (id_retiro);


--
-- Name: idx_cliente_nombre; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cliente_nombre ON public.cliente USING btree (nombre);


--
-- Name: idx_detalle_compra_producto; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detalle_compra_producto ON public.detalle_compra USING btree (cod_producto, nombre_calidad);


--
-- Name: idx_detalle_pedido_producto; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detalle_pedido_producto ON public.detalle_pedido USING btree (cod_producto, nombre_calidad);


--
-- Name: idx_nota_cliente; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_nota_cliente ON public.nota_pedido USING btree (id_cliente);


--
-- Name: idx_nota_compra; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_nota_compra ON public.nota_pedido USING btree (id_compra);


--
-- Name: idx_nota_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_nota_fecha ON public.nota_pedido USING btree (fecha);


--
-- Name: idx_productor_nombre; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_productor_nombre ON public.productor USING btree (nombre);


--
-- Name: idx_retiro_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_retiro_fecha ON public.retiro_campo USING btree (fecha);


--
-- Name: idx_retiro_productor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_retiro_productor ON public.retiro_campo USING btree (id_productor);


--
-- Name: calidad trg_auditoria; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.calidad FOR EACH ROW EXECUTE FUNCTION public.fn_trg_auditoria('cod_producto,nombre_calidad');


--
-- Name: cliente trg_auditoria; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.cliente FOR EACH ROW EXECUTE FUNCTION public.fn_trg_auditoria('id_cliente');


--
-- Name: detalle_compra trg_auditoria; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.detalle_compra FOR EACH ROW EXECUTE FUNCTION public.fn_trg_auditoria('id_compra,cod_producto,nombre_calidad');


--
-- Name: detalle_pedido trg_auditoria; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.detalle_pedido FOR EACH ROW EXECUTE FUNCTION public.fn_trg_auditoria('numero_compra,cod_producto,nombre_calidad');


--
-- Name: detalle_retiro trg_auditoria; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.detalle_retiro FOR EACH ROW EXECUTE FUNCTION public.fn_trg_auditoria('id_retiro,cod_producto,nombre_calidad');


--
-- Name: hoja_control_compra trg_auditoria; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.hoja_control_compra FOR EACH ROW EXECUTE FUNCTION public.fn_trg_auditoria('id_compra');


--
-- Name: nota_pedido trg_auditoria; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.nota_pedido FOR EACH ROW EXECUTE FUNCTION public.fn_trg_auditoria('numero_compra');


--
-- Name: producto_agricola trg_auditoria; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.producto_agricola FOR EACH ROW EXECUTE FUNCTION public.fn_trg_auditoria('cod_producto');


--
-- Name: productor trg_auditoria; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.productor FOR EACH ROW EXECUTE FUNCTION public.fn_trg_auditoria('id_productor');


--
-- Name: retiro_campo trg_auditoria; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria AFTER INSERT OR DELETE OR UPDATE ON public.retiro_campo FOR EACH ROW EXECUTE FUNCTION public.fn_trg_auditoria('id_retiro');


--
-- Name: calidad trg_bloquear_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_bloquear_delete BEFORE DELETE ON public.calidad FOR EACH ROW EXECUTE FUNCTION public.fn_trg_bloquear_delete();


--
-- Name: cliente trg_bloquear_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_bloquear_delete BEFORE DELETE ON public.cliente FOR EACH ROW EXECUTE FUNCTION public.fn_trg_bloquear_delete();


--
-- Name: hoja_control_compra trg_bloquear_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_bloquear_delete BEFORE DELETE ON public.hoja_control_compra FOR EACH ROW EXECUTE FUNCTION public.fn_trg_bloquear_delete();


--
-- Name: nota_pedido trg_bloquear_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_bloquear_delete BEFORE DELETE ON public.nota_pedido FOR EACH ROW EXECUTE FUNCTION public.fn_trg_bloquear_delete();


--
-- Name: producto_agricola trg_bloquear_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_bloquear_delete BEFORE DELETE ON public.producto_agricola FOR EACH ROW EXECUTE FUNCTION public.fn_trg_bloquear_delete();


--
-- Name: productor trg_bloquear_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_bloquear_delete BEFORE DELETE ON public.productor FOR EACH ROW EXECUTE FUNCTION public.fn_trg_bloquear_delete();


--
-- Name: retiro_campo trg_bloquear_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_bloquear_delete BEFORE DELETE ON public.retiro_campo FOR EACH ROW EXECUTE FUNCTION public.fn_trg_bloquear_delete();


--
-- Name: calidad trg_marcar_baja; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_marcar_baja BEFORE UPDATE ON public.calidad FOR EACH ROW EXECUTE FUNCTION public.fn_trg_marcar_baja();


--
-- Name: cliente trg_marcar_baja; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_marcar_baja BEFORE UPDATE ON public.cliente FOR EACH ROW EXECUTE FUNCTION public.fn_trg_marcar_baja();


--
-- Name: hoja_control_compra trg_marcar_baja; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_marcar_baja BEFORE UPDATE ON public.hoja_control_compra FOR EACH ROW EXECUTE FUNCTION public.fn_trg_marcar_baja();


--
-- Name: nota_pedido trg_marcar_baja; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_marcar_baja BEFORE UPDATE ON public.nota_pedido FOR EACH ROW EXECUTE FUNCTION public.fn_trg_marcar_baja();


--
-- Name: producto_agricola trg_marcar_baja; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_marcar_baja BEFORE UPDATE ON public.producto_agricola FOR EACH ROW EXECUTE FUNCTION public.fn_trg_marcar_baja();


--
-- Name: productor trg_marcar_baja; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_marcar_baja BEFORE UPDATE ON public.productor FOR EACH ROW EXECUTE FUNCTION public.fn_trg_marcar_baja();


--
-- Name: retiro_campo trg_marcar_baja; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_marcar_baja BEFORE UPDATE ON public.retiro_campo FOR EACH ROW EXECUTE FUNCTION public.fn_trg_marcar_baja();


--
-- Name: calidad trg_validar_activos; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validar_activos BEFORE INSERT OR UPDATE ON public.calidad FOR EACH ROW EXECUTE FUNCTION public.fn_trg_validar_activos();


--
-- Name: hoja_control_compra trg_validar_activos; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validar_activos BEFORE INSERT OR UPDATE ON public.hoja_control_compra FOR EACH ROW EXECUTE FUNCTION public.fn_trg_validar_activos();


--
-- Name: nota_pedido trg_validar_activos; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validar_activos BEFORE INSERT OR UPDATE ON public.nota_pedido FOR EACH ROW EXECUTE FUNCTION public.fn_trg_validar_activos();


--
-- Name: retiro_campo trg_validar_activos; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validar_activos BEFORE INSERT OR UPDATE ON public.retiro_campo FOR EACH ROW EXECUTE FUNCTION public.fn_trg_validar_activos();


--
-- Name: detalle_pedido trg_validar_stock; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validar_stock BEFORE INSERT OR UPDATE ON public.detalle_pedido FOR EACH ROW EXECUTE FUNCTION public.fn_trg_validar_stock();


--
-- Name: calidad_alias calidad_alias_cod_producto_nombre_calidad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calidad_alias
    ADD CONSTRAINT calidad_alias_cod_producto_nombre_calidad_fkey FOREIGN KEY (cod_producto, nombre_calidad) REFERENCES public.calidad(cod_producto, nombre_calidad) ON DELETE CASCADE;


--
-- Name: calidad calidad_cod_producto_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calidad
    ADD CONSTRAINT calidad_cod_producto_fkey FOREIGN KEY (cod_producto) REFERENCES public.producto_agricola(cod_producto);


--
-- Name: detalle_compra detalle_compra_cod_producto_nombre_calidad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_compra
    ADD CONSTRAINT detalle_compra_cod_producto_nombre_calidad_fkey FOREIGN KEY (cod_producto, nombre_calidad) REFERENCES public.calidad(cod_producto, nombre_calidad);


--
-- Name: detalle_compra detalle_compra_id_compra_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_compra
    ADD CONSTRAINT detalle_compra_id_compra_fkey FOREIGN KEY (id_compra) REFERENCES public.hoja_control_compra(id_compra) ON DELETE CASCADE;


--
-- Name: detalle_pedido detalle_pedido_cod_producto_nombre_calidad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_pedido
    ADD CONSTRAINT detalle_pedido_cod_producto_nombre_calidad_fkey FOREIGN KEY (cod_producto, nombre_calidad) REFERENCES public.calidad(cod_producto, nombre_calidad);


--
-- Name: detalle_pedido detalle_pedido_numero_compra_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_pedido
    ADD CONSTRAINT detalle_pedido_numero_compra_fkey FOREIGN KEY (numero_compra) REFERENCES public.nota_pedido(numero_compra) ON DELETE CASCADE;


--
-- Name: detalle_retiro detalle_retiro_cod_producto_nombre_calidad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_retiro
    ADD CONSTRAINT detalle_retiro_cod_producto_nombre_calidad_fkey FOREIGN KEY (cod_producto, nombre_calidad) REFERENCES public.calidad(cod_producto, nombre_calidad);


--
-- Name: detalle_retiro detalle_retiro_id_retiro_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_retiro
    ADD CONSTRAINT detalle_retiro_id_retiro_fkey FOREIGN KEY (id_retiro) REFERENCES public.retiro_campo(id_retiro) ON DELETE CASCADE;


--
-- Name: hoja_control_compra hoja_control_compra_id_retiro_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoja_control_compra
    ADD CONSTRAINT hoja_control_compra_id_retiro_fkey FOREIGN KEY (id_retiro) REFERENCES public.retiro_campo(id_retiro);


--
-- Name: nota_pedido nota_pedido_id_cliente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nota_pedido
    ADD CONSTRAINT nota_pedido_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cliente(id_cliente);


--
-- Name: nota_pedido nota_pedido_id_compra_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nota_pedido
    ADD CONSTRAINT nota_pedido_id_compra_fkey FOREIGN KEY (id_compra) REFERENCES public.hoja_control_compra(id_compra);


--
-- Name: retiro_campo retiro_campo_fecha_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.retiro_campo
    ADD CONSTRAINT retiro_campo_fecha_fkey FOREIGN KEY (fecha) REFERENCES public.calendario_retiro(fecha);


--
-- Name: retiro_campo retiro_campo_id_productor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.retiro_campo
    ADD CONSTRAINT retiro_campo_id_productor_fkey FOREIGN KEY (id_productor) REFERENCES public.productor(id_productor);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


--
-- PostgreSQL database dump complete
--

\unrestrict nvCxgSiMLDsKU81D3AAvzXD77xdpGDoNgMphUXqPN8tAcsHC3sNyEaJurF0z3eO

