-- =========================================================================
-- EXAMEN FINAL - LABORATORIO DE BASES DE DATOS 2026
-- Base de datos: DNI39079001
-- =========================================================================
DROP DATABASE IF EXISTS DNI12345678;
CREATE DATABASE DNI12345678;
USE DNI12345678;

-- PUNTO 1: NOTA ACLARATORIA SOBRE ÍNDICES
-- Se crean índices explícitos sobre las claves primarias y foráneas para 
-- cumplir con la consigna, aunque en MySQL (InnoDB) estos son generados 
-- automáticamente al definir dichas restricciones. 
-- En un escenario real, no sería necesario duplicar índices sobre PK.

-- =====================================================
-- TABLAS INDEPENDIENTES (Se crean primero)
-- =====================================================

-- Tabla Clientes
CREATE TABLE Clientes (
    idCliente INT PRIMARY KEY, 
    apellidos VARCHAR(50) NOT NULL, 
    nombres VARCHAR(50) NOT NULL, 
    dni VARCHAR(10) NOT NULL UNIQUE, -- Restricción AK1:1 
    domicilio VARCHAR(100) NOT NULL 
);

-- Índices explícitos para Clientes 
CREATE INDEX idx_pk_Clientes ON Clientes(idCliente);


-- Tabla Productos 
CREATE TABLE Productos (
    idProducto INT PRIMARY KEY, 
    nombre VARCHAR(150) NOT NULL UNIQUE, -- Restricción AK1:1 
    precio FLOAT NOT NULL, 
    CONSTRAINT chk_precio_productos CHECK (precio > 0) -- Validación precio > 0 
);

-- Índices explícitos para Productos 
CREATE INDEX idx_pk_Productos ON Productos(idProducto);


-- Tabla Sucursales 
CREATE TABLE Sucursales (
    idSucursal INT PRIMARY KEY, 
    nombre VARCHAR(100) NOT NULL UNIQUE,   -- Restricción AK1:1 
    domicilio VARCHAR(100) NOT NULL UNIQUE -- Restricción AK2:1 
);

-- Índices explícitos para Sucursales 
CREATE INDEX idx_pk_Sucursales ON Sucursales(idSucursal);


-- Tabla BandasHorarias 
CREATE TABLE BandasHorarias (
    idBandaHoraria INT PRIMARY KEY, 
    nombre CHAR(13) NOT NULL UNIQUE -- Restricción AK1:1
);

-- Índices explícitos para BandasHorarias 
CREATE INDEX idx_pk_BandasHorarias ON BandasHorarias(idBandaHoraria);


-- =====================================================
-- TABLAS DEPENDIENTES (Se crean al final)
-- =====================================================

-- Tabla Pedidos 
CREATE TABLE Pedidos (
    idPedido INT PRIMARY KEY, 
    idCliente INT NOT NULL, 
    fecha DATETIME NOT NULL, 
    FOREIGN KEY (idCliente) REFERENCES Clientes(idCliente) 
);

-- Índices explícitos para Pedidos (PK y Clave Propagada/FK) 
CREATE INDEX idx_pk_Pedidos ON Pedidos(idPedido);
CREATE INDEX idx_fk_Pedidos_idCliente ON Pedidos(idCliente);


-- Tabla ProductoDelPedido 
CREATE TABLE ProductoDelPedido (
    idPedido INT NOT NULL, 
    idProducto INT NOT NULL, 
    cantidad FLOAT NOT NULL, 
    precio FLOAT NOT NULL, 
    PRIMARY KEY (idPedido, idProducto), -- Clave primaria compuesta 
    FOREIGN KEY (idPedido) REFERENCES Pedidos(idPedido), 
    FOREIGN KEY (idProducto) REFERENCES Productos(idProducto), 
    CONSTRAINT chk_precio_pedido CHECK (precio > 0) -- Validación precio > 0 
);

-- Índices explícitos para ProductoDelPedido (PK Compuesta y Claves Propagadas/FK) 
CREATE INDEX idx_pk_ProductoDelPedido ON ProductoDelPedido(idPedido, idProducto);
CREATE INDEX idx_fk_ProdPed_idPedido ON ProductoDelPedido(idPedido);
CREATE INDEX idx_fk_ProdPed_idProducto ON ProductoDelPedido(idProducto);


-- Tabla Entregas 
CREATE TABLE Entregas (
    idEntrega INT PRIMARY KEY, 
    idSucursal INT NOT NULL, 
    idPedido INT NOT NULL, 
    fecha DATETIME NOT NULL, 
    idBandaHoraria INT NOT NULL, 
    FOREIGN KEY (idSucursal) REFERENCES Sucursales(idSucursal), 
    FOREIGN KEY (idPedido) REFERENCES Pedidos(idPedido), 
    FOREIGN KEY (idBandaHoraria) REFERENCES BandasHorarias(idBandaHoraria) 
);

-- Índices explícitos para Entregas (PK y todas las Claves Propagadas/FK) 
CREATE INDEX idx_pk_Entregas ON Entregas(idEntrega);
CREATE INDEX idx_fk_Entregas_idSucursal ON Entregas(idSucursal);
CREATE INDEX idx_fk_Entregas_idPedido ON Entregas(idPedido);
CREATE INDEX idx_fk_Entregas_idBandaHoraria ON Entregas(idBandaHoraria);

-- Ejecuto Datos2023

-- =========================================================================
-- PUNTO 2: CREACIÓN DE LA VISTA 'VEntregas' (CON CONTROL DE VALORES NULL)
-- =========================================================================

CREATE OR REPLACE VIEW VEntregas AS
SELECT 
    s.nombre AS Sucursal,
    
-- Se utiliza COALESCE para reemplazar valores NULL producidos por LEFT JOIN,
-- mejorando la presentación de los datos.
    
    COALESCE(e.idPedido, 0) AS Pedido, -- Reemplazo numérico directo para el ID del pedido
    
    COALESCE(DATE(p.fecha), 'Sin datos') AS `F. pedido`,
    COALESCE(DATE(e.fecha), 'Sin datos') AS `F. entrega`,
    
    COALESCE(bh.nombre, 'Sin datos') AS Banda,
    
    COALESCE(CONCAT(c.apellidos, ', ', c.nombres, ' (', c.dni, ')'),'Sin datos') AS Cliente

FROM Sucursales s
LEFT JOIN Entregas e ON s.idSucursal = e.idSucursal
LEFT JOIN Pedidos p ON e.idPedido = p.idPedido
LEFT JOIN Clientes c ON p.idCliente = c.idCliente
LEFT JOIN BandasHorarias bh ON e.idBandaHoraria = bh.idBandaHoraria

ORDER BY s.nombre ASC, p.fecha ASC, e.fecha ASC;

-- Consulta de verificación para el examen
-- Agrego una sucursal "fantasma" (que obviamente no va a tener ninguna entrega asociada en la tabla Entregas)
INSERT INTO Sucursales VALUES (99, 'Sucursal Test Sin Ventas', 'Av. Siempre Viva 742');
SELECT * FROM VEntregas;

-- =========================================================================
-- PUNTO 3: PROCEDIMIENTO ALMACENADO 'NuevoProducto'
-- =========================================================================
-- Alta de registros en la tabla Productos controlando errores de
-- negocio e integridad mediante parámetros de salida (OUT).

DELIMITER //

CREATE PROCEDURE NuevoProducto(
    IN p_idProducto INT,
    IN p_nombre VARCHAR(150),
    IN p_precio FLOAT,
    OUT p_codigo_error INT,
    OUT p_mensaje_error VARCHAR(255)
)
BEGIN
    -- Se inicializan los parámetros de salida asumiendo éxito por defecto.
    SET p_codigo_error = 0;
    SET p_mensaje_error = 'Producto registrado con éxito.';

    -- -----------------------------------------------------------------
    -- VALIDACIÓN DE ERRORES LÓGICOS (Reglas de negocio e Integridad)
    -- -----------------------------------------------------------------

    -- 1. Control de regla de negocio: Precio mayor a cero
    IF p_precio IS NULL OR p_precio <= 0 THEN
        SET p_codigo_error = 1;
        SET p_mensaje_error = 'Error Lógico: El precio debe ser estrictamente mayor que cero.';

    -- 2. Control de integridad obligatoria: Nombre no vacío
    ELSEIF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        SET p_codigo_error = 2;
        SET p_mensaje_error = 'Error Lógico: El nombre del producto es obligatorio y no puede estar vacío.';

    -- 3. Control de Clave Primaria (PK): idProducto ya existente
    ELSEIF EXISTS (SELECT 1 FROM Productos WHERE idProducto = p_idProducto) THEN
        SET p_codigo_error = 3;
        SET p_mensaje_error = CONCAT('Error de Integridad: Ya existe un producto con el ID ', p_idProducto, '.');

    -- 4. Control de Clave Alternativa (AK1:1): Nombre ya existente
    ELSEIF EXISTS (SELECT 1 FROM Productos WHERE nombre = p_nombre) THEN
        SET p_codigo_error = 4;
        SET p_mensaje_error = CONCAT('Error de Integridad: Ya existe un producto con el nombre "', p_nombre, '".');

    -- -----------------------------------------------------------------
    -- OPERACIÓN DE INSERCIÓN (Si se superan todas las validaciones)
    -- -----------------------------------------------------------------
    ELSE
        INSERT INTO Productos (idProducto, nombre, precio)
        VALUES (p_idProducto, p_nombre, p_precio);
    END IF;

END //

DELIMITER ;

-- Variables de sesión para capturar los resultados de las salidas OUT
SET @cod_err = 0;
SET @msg_err = '';

-- =========================================================================
-- PRUEBAS DE CASOS INCORRECTOS (Debe devolver códigos de error 1 al 4)
-- =========================================================================

-- CASO INCORRECTO 1: Violación de regla del precio (Precio menor o igual a cero)
CALL NuevoProducto(901, 'Teclado Mecánico Retroiluminado', -150.50, @cod_err, @msg_err);
SELECT @cod_err AS `Código de Error`, @msg_err AS `Mensaje de Error`;

-- CASO INCORRECTO 2: Violación de campo obligatorio (Nombre vacío)
CALL NuevoProducto(902, '', 4500.00, @cod_err, @msg_err);
SELECT @cod_err AS `Código de Error`, @msg_err AS `Mensaje de Error`;

-- CASO INCORRECTO 3: Violación de Clave Primaria (El ID 1 ya fue insertado por Datos.sql)
CALL NuevoProducto(1, 'Mouse Inalámbrico Nuevo', 2500.00, @cod_err, @msg_err);
SELECT @cod_err AS `Código de Error`, @msg_err AS `Mensaje de Error`;

-- CASO INCORRECTO 4: Violación de Clave Única AK (El nombre ya existe en los datos base)
CALL NuevoProducto(903, 'Microsoft Surface', 99999.00, @cod_err, @msg_err);
SELECT @cod_err AS `Código de Error`, @msg_err AS `Mensaje de Error`;

-- PRUEBA DE CASO CORRECTO (Debe devolver código 0 e insertar físicamente)
CALL NuevoProducto(500, 'Monitor Gamer Curvo 27 pulgadas', 75000.00, @cod_err, @msg_err);
SELECT @cod_err AS `Código de Error`, @msg_err AS `Mensaje de Error`;

-- Comprobación de la inserción exitosa en la tabla
SELECT * FROM Productos WHERE idProducto = 500;

-- =========================================================================
-- PUNTO 4: PROCEDIMIENTO ALMACENADO 'BuscarPedidos'
-- =========================================================================
DROP PROCEDURE IF EXISTS BuscarPedidos;
DELIMITER //

CREATE PROCEDURE BuscarPedidos(
    IN p_idPedido INT
)
BEGIN
    -- VALIDACIÓN: Verificación previa de existencia del pedido
    IF NOT EXISTS (SELECT 1 FROM Pedidos WHERE idPedido = p_idPedido) THEN
        SELECT CONCAT('Error: El código de pedido ', p_idPedido, ' no existe.') AS `Mensaje`;
    ELSE
        
        -- SUBCONSULTA EXTERNA: Para ordenar alfabéticamente los productos 
        -- sin que la fila de resumen se mezcle hacia arriba.
        SELECT 
            idProducto,
            nombre,
            precio_lista AS `precio lista`,
            cantidad,
            precio_venta AS `precio venta`,
            total
        FROM (
            
            -- PARTE A: Detalle de los productos del pedido
            SELECT 
                CAST(pp.idProducto AS CHAR(50)) AS idProducto,
                CAST(pr.nombre AS CHAR(150)) AS nombre,
                CAST(pr.precio AS CHAR(50)) AS precio_lista,
                CAST(pp.cantidad AS CHAR(50)) AS cantidad,
                CAST(pp.precio AS CHAR(50)) AS precio_venta,
                CAST((pp.cantidad * pp.precio) AS CHAR(50)) AS total,
                1 AS tipo_fila,                          -- Para dejar el detalle arriba
                pr.nombre AS nombre_ordenar              -- Criterio de ordenación A-Z
            FROM ProductoDelPedido pp
            INNER JOIN Productos pr ON pp.idProducto = pr.idProducto
            WHERE pp.idPedido = p_idPedido
            
            UNION ALL
            
            -- PARTE B: Fila de resumen formateada exactamente como el PDF
            -- Mapeamos las etiquetas de texto en las columnas del SELECT
            SELECT 
                'Fecha:' AS idProducto,                           -- Va en la col de ID
                CAST(DATE(p.fecha) AS CHAR(50)) AS nombre,        -- La fecha va en la col de Nombre
                'Cliente:' AS precio_lista,                       -- Va en la col de Precio Lista
                CAST(CONCAT(c.apellidos, ', ', c.nombres) AS CHAR(150)) AS cantidad, -- El cliente va en Cantidad
                'Total:' AS precio_venta,                         -- Va en la col de Precio Venta
                CAST(SUM(pp.cantidad * pp.precio) AS CHAR(50)) AS total, -- El monto final va en Total
                2 AS tipo_fila,                                   -- Fuerza a que vaya al fondo
                'ZZZZZZZZZZZZZZZ' AS nombre_ordenar               -- Evita que altere el orden A-Z
            FROM Pedidos p
            INNER JOIN Clientes c ON p.idCliente = c.idCliente
            INNER JOIN ProductoDelPedido pp ON p.idPedido = pp.idPedido
            WHERE p.idPedido = p_idPedido
            GROUP BY p.idPedido, p.fecha, c.apellidos, c.nombres
            
        ) AS Reporte
        
        -- ORDENAMIENTO DE EXAMEN: Detalle primero (ordenado por producto) y resumen al final.
        ORDER BY tipo_fila ASC, nombre_ordenar ASC;

    END IF;
END //

DELIMITER ;

-- PRUEBA CASO CORRECTO: Consulta un pedido existente (Muestra detalles + Fila Resumen abajo)
CALL BuscarPedidos(1);

-- PRUEBA CASO INCORRECTO: Consulta un código que no existe (Dispara el mensaje del IF)
CALL BuscarPedidos(9999);

-- =========================================================================
-- PUNTO 5: CONTROL DE INTEGRIDAD MEDIANTE TRIGGERS
-- =========================================================================
-- Evaluar la implementación de disparadores para
-- reglas de negocio complejas y el uso de SIGNAL SQLSTATE para abortar
-- operaciones enviando mensajes de error personalizados.

-- Limpieza previa: Borra el trigger si ya existía de ejecuciones anteriores
DROP TRIGGER IF EXISTS EvitarBorrarProductoConPedidos;

DELIMITER //

CREATE TRIGGER EvitarBorrarProductoConPedidos
BEFORE DELETE ON Productos
FOR EACH ROW
BEGIN
    -- VALIDACIÓN: Verificar si el idProducto que se intenta borrar (OLD.idProducto)
    -- ya se encuentra registrado en la tabla intermedia de detalles 'ProductoDelPedido'.
    IF EXISTS (SELECT 1 FROM ProductoDelPedido WHERE idProducto = OLD.idProducto) THEN
        -- Aborta el borrado de forma segura y lanza la excepción a la consola
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: No se puede eliminar el producto porque está incluido en uno o más pedidos activos.';
        
    END IF;
END //

DELIMITER ;

-- -------------------------------------------------------------------------
-- CASO A: BORRADO DE UN PRODUCTO NO INCLUIDO EN NINGÚN PEDIDO (Debe funcionar)
-- -------------------------------------------------------------------------
-- 1. Insertamos un producto nuevo de prueba (sabemos que nadie lo pidió todavía)
INSERT INTO Productos (idProducto, nombre, precio) 
VALUES (999, 'Producto Temporal De Prueba', 150.00);

-- 2. Ejecutamos el borrado. El trigger validará que no hay pedidos y dejará pasar la orden.
DELETE FROM Productos 
WHERE idProducto = 999;

-- Se verifica con un SELECT que el producto 999 se borró correctamente
SELECT * FROM Productos WHERE idProducto = 999;

-- -------------------------------------------------------------------------
-- CASO B: BORRADO DE UN PRODUCTO QUE SÍ TIENE PEDIDOS (Debe fallar)
-- -------------------------------------------------------------------------
-- Intentamos borrar el producto ID 5 (Bose QuietComfort 35 II) el cual ya está
-- asignado en los reportes de los puntos anteriores.
DELETE FROM Productos 
WHERE idProducto = 5;

-- RESULTADO ESPERADO EN CONSOLA:
-- Error Code: 1644. Error: No se puede eliminar el producto porque está incluido en uno o más pedidos activos.