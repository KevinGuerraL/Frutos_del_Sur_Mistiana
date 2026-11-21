-- DATOS DE PRUEBA (los mismos del informe, ya validados contra el esquema)
INSERT INTO productor (id_productor,nombre,region_procedencia) VALUES
('PR001','Productor Los Andes','Ica'),
('PR002','Asociación Agrícola Santa Rosa','Chincha'),
('PR003','Productor El Pedregal','Pedregal');

INSERT INTO producto_agricola (cod_producto,nombre_producto,unidad_medida) VALUES
('PA01','Fresa','Kilogramo'),('PA02','Uva','Kilogramo'),('PA03','Arándano','Caja');

INSERT INTO calidad (cod_producto,nombre_calidad,precio_referencia) VALUES
('PA01','Primera',8.00),('PA01','Segunda',7.00),('PA01','Tercera',6.00),
('PA01','Cuarta',5.00),('PA01','Descarte',2.50),
('PA02','Primera',6.50),('PA02','Segunda',5.50),
('PA03','Primera',18.00),('PA03','Segunda',15.00);

INSERT INTO calidad_alias (cod_producto,nombre_calidad,alias_por_documento) VALUES
('PA01','Primera','I'),('PA01','Primera','1era'),
('PA01','Segunda','II'),('PA01','Segunda','2da'),
('PA01','Tercera','III'),('PA01','Tercera','3era'),
('PA01','Cuarta','IV'),('PA01','Descarte','Descarte');

INSERT INTO cliente (id_cliente,nombre,domicilio,telefono) VALUES
('CL001','Yaneth Quispe','Puesto Elena, plataforma comercial','987654321'),
('CL002','Mercado Santa Rosa','Chincha Alta','956123789'),
('CL003','Frutería La Preferida','Ica centro','945678123');

INSERT INTO calendario_retiro (fecha,dia_semana) VALUES
('2026-10-19','Lunes'),('2026-10-22','Jueves'),('2026-10-24','Sábado');

INSERT INTO retiro_campo (id_retiro,fecha,id_productor) VALUES
('RET001','2026-10-19','PR001'),('RET002','2026-10-22','PR002'),('RET003','2026-10-24','PR003');

INSERT INTO detalle_retiro (id_retiro,cod_producto,nombre_calidad,cantidad) VALUES
('RET001','PA01','Primera',100),('RET001','PA01','Segunda',120),('RET001','PA01','Tercera',80),
('RET002','PA01','Primera',90),('RET002','PA01','Segunda',110),('RET002','PA02','Primera',60),
('RET003','PA01','Primera',130),('RET003','PA01','Descarte',25),('RET003','PA03','Primera',20);

INSERT INTO hoja_control_compra (id_compra,fecha,id_retiro) VALUES
('HC001','2026-10-19','RET001'),('HC002','2026-10-22','RET002'),('HC003','2026-10-24','RET003');

INSERT INTO detalle_compra (id_compra,cod_producto,nombre_calidad,cantidad,precio_unitario) VALUES
('HC001','PA01','Primera',100,8.00),('HC001','PA01','Segunda',120,7.00),('HC001','PA01','Tercera',80,6.00),
('HC002','PA01','Primera',90,8.00),('HC002','PA01','Segunda',110,7.00),('HC002','PA02','Primera',60,6.50),
('HC003','PA01','Primera',130,8.00),('HC003','PA01','Descarte',25,2.50),('HC003','PA03','Primera',20,18.00);

INSERT INTO nota_pedido (numero_compra,fecha,modalidad_pago,firma_cliente,id_compra,id_cliente) VALUES
(1453,'2026-10-19','Contado',NULL,'HC001','CL001'),
(1454,'2026-10-22','Crédito',NULL,'HC002','CL002'),
(1455,'2026-10-24','Contado',NULL,'HC003','CL003');

INSERT INTO detalle_pedido (numero_compra,cod_producto,nombre_calidad,cajas,kilos,precio_unitario) VALUES
(1453,'PA01','Primera',NULL,20,12.00),(1453,'PA01','Segunda',NULL,15,10.50),
(1454,'PA01','Primera',NULL,25,12.00),(1454,'PA02','Primera',NULL,10,9.00),
(1455,'PA01','Primera',NULL,30,12.00),(1455,'PA03','Primera',5,NULL,25.00);
