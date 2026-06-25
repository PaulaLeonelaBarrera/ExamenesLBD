-- =========================================================================
-- EXAMEN FINAL - LABORATORIO DE BASES DE DATOS 2022
-- Base de datos: DNI39079001
-- Alumna: Paula Leonela Barrera
-- =========================================================================

DROP DATABASE IF EXISTS DNI567;
CREATE DATABASE DNI567;
USE DNI567;

-- =========================================================================
-- PUNTO 1: CREACIÓN DE TABLAS, RESTRICCIONES E ÍNDICES
-- =========================================================================

-- Tabla Autores
CREATE TABLE Autores (
    idAutor VARCHAR(11) NOT NULL,
    apellido VARCHAR(40) NOT NULL,
    nombre VARCHAR(20) NOT NULL,
    telefono CHAR(12) NOT NULL DEFAULT 'UNKNOWN', -- Valor por defecto solicitado
    domicilio VARCHAR(40) NULL,
    ciudad VARCHAR(20) NULL,
    estado CHAR(2) NULL,
    codigoPostal CHAR(5) NULL,
    PRIMARY KEY (idAutor)
);

-- Índices explícitos para Autores
CREATE INDEX idx_pk_Autores ON Autores(idAutor);


-- Tabla Editoriales
CREATE TABLE Editoriales (
    idEditorial CHAR(4) NOT NULL,
    nombre VARCHAR(40) NOT NULL,
    ciudad VARCHAR(20) NULL,
    estado CHAR(2) NULL,
    pais VARCHAR(30) NOT NULL DEFAULT 'USA', -- Valor por defecto solicitado
    PRIMARY KEY (idEditorial),
    CONSTRAINT ak1_editoriales UNIQUE (nombre) -- Restricción: Nombre único
);

-- Índices explícitos para Editoriales
CREATE INDEX idx_pk_Editoriales ON Editoriales(idEditorial);


-- Tabla Titulos
CREATE TABLE Titulos (
    idTitulo VARCHAR(6) NOT NULL,
    titulo VARCHAR(80) NOT NULL,
    genero CHAR(12) NOT NULL DEFAULT 'UNDECIDED', -- Valor por defecto solicitado
    idEditorial CHAR(4) NOT NULL,
    precio DECIMAL(8,2) NULL,
    sinopsis VARCHAR(200) NULL,
    fechaPublicacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, -- Fecha actual por defecto
    PRIMARY KEY (idTitulo),
    FOREIGN KEY (idEditorial) REFERENCES Editoriales(idEditorial),
    CONSTRAINT chk_precio_positivo CHECK (precio IS NULL OR precio > 0) -- Validación: Número positivo
);

-- Índices explícitos para Titulos (PK y FK propagada)
CREATE INDEX idx_pk_Titulos ON Titulos(idTitulo);
CREATE INDEX idx_fk_Titulos_idEditorial ON Titulos(idEditorial);


-- Tabla TitulosDelAutor (Tabla intermedia)
CREATE TABLE TitulosDelAutor (
    idAutor VARCHAR(11) NOT NULL,
    idTitulo VARCHAR(6) NOT NULL,
    PRIMARY KEY (idAutor, idTitulo),
    FOREIGN KEY (idAutor) REFERENCES Autores(idAutor),
    FOREIGN KEY (idTitulo) REFERENCES Titulos(idTitulo)
);

-- Índices explícitos para TitulosDelAutor (PK compuesta y FKs)
CREATE INDEX idx_pk_TitulosDelAutor ON TitulosDelAutor(idAutor, idTitulo);
CREATE INDEX idx_fk_TitulosDelAutor_idAutor ON TitulosDelAutor(idAutor);
CREATE INDEX idx_fk_TitulosDelAutor_idTitulo ON TitulosDelAutor(idTitulo);


-- Tabla Tiendas
CREATE TABLE Tiendas (
    idTienda CHAR(4) NOT NULL,
    nombre VARCHAR(40) NOT NULL,
    domicilio VARCHAR(40) NULL,
    ciudad VARCHAR(20) NULL,
    estado CHAR(2) NULL,
    codigoPostal CHAR(5) NULL,
    PRIMARY KEY (idTienda),
    CONSTRAINT ak1_tiendas UNIQUE (nombre) -- Restricción: Nombre único
);

-- Índices explícitos para Tiendas
CREATE INDEX idx_pk_Tiendas ON Tiendas(idTienda);


-- Tabla Ventas
CREATE TABLE Ventas (
    codigoVenta VARCHAR(20) NOT NULL,
    idTienda CHAR(4) NOT NULL,
    fecha DATETIME NOT NULL,
    tipo VARCHAR(12) NOT NULL,
    PRIMARY KEY (codigoVenta),
    FOREIGN KEY (idTienda) REFERENCES Tiendas(idTienda)
);

-- Índices explícitos para Ventas (PK y FK propagada)
CREATE INDEX idx_pk_Ventas ON Ventas(codigoVenta);
CREATE INDEX idx_fk_Ventas_idTienda ON Ventas(idTienda);


-- Tabla Detalles
CREATE TABLE Detalles (
    idDetalle INT AUTO_INCREMENT NOT NULL, -- Implementación del IDENTITY del modelo lógico
    codigoVenta VARCHAR(20) NOT NULL,
    idTitulo VARCHAR(6) NOT NULL,
    cantidad SMALLINT NOT NULL,
    PRIMARY KEY (idDetalle),
    FOREIGN KEY (codigoVenta) REFERENCES Ventas(codigoVenta),
    FOREIGN KEY (idTitulo) REFERENCES Titulos(idTitulo),
    CONSTRAINT chk_cantidad_positiva CHECK (cantidad > 0) -- Validación: Número positivo
);

-- Índices explícitos para Detalles (PK y FKs propagadas)
CREATE INDEX idx_pk_Detalles ON Detalles(idDetalle);
CREATE INDEX idx_fk_Detalles_codigoVenta ON Detalles(codigoVenta);
CREATE INDEX idx_fk_Detalles_idTitulo ON Detalles(idTitulo);


-- -------------------------------------------------------------------------
-- CARGA DE DATOS (Script Datos2022.sql provisto por el examen)
-- -------------------------------------------------------------------------

-- =========================================================================
-- PUNTO 2: CREACIÓN DE LA VISTA 'VCantidadVentas'
-- =========================================================================
-- Muestra el código de tienda, cantidad de líneas/ítems vendidos e importe total.
-- Se usa LEFT JOIN para asegurar que se listen todas las tiendas del sistema.

CREATE OR REPLACE VIEW VCantidadVentas AS
SELECT 
    t.idTienda,
    (COUNT(v.codigoVenta)) AS `Cantidad de ventas`, -- antes COUNT(d.idDetalle)
    COALESCE(SUM(d.cantidad * ti.precio), 0) AS `Importe total de ventas`
FROM Tiendas t
LEFT JOIN Ventas v ON t.idTienda = v.idTienda
LEFT JOIN Detalles d ON v.codigoVenta = d.codigoVenta
LEFT JOIN Titulos ti ON d.idTitulo = ti.idTitulo
GROUP BY t.idTienda
ORDER BY `Cantidad de ventas` DESC, `Importe total de ventas` DESC;

-- Consulta de verificación obligatoria solicitada por el examen
SELECT * FROM VCantidadVentas;


-- =========================================================================
-- PUNTO 3: PROCEDIMIENTO ALMACENADO 'Nueva Editorial'
-- =========================================================================
-- Manejo estructurado de errores lógicos mediante parámetros de salida (OUT).

DROP PROCEDURE IF EXISTS `Nueva Editorial`;
DELIMITER //

CREATE PROCEDURE `Nueva Editorial`(
    IN p_idEditorial CHAR(4),
    IN p_nombre VARCHAR(40),
    IN p_ciudad VARCHAR(20),
    IN p_estado CHAR(2),
    IN p_pais VARCHAR(30),
    OUT p_codigo_error INT,
    OUT p_mensaje_error VARCHAR(255)
)
BEGIN
    -- Inicialización por defecto (Éxito)
    SET p_codigo_error = 0;
    SET p_mensaje_error = 'Editorial registrada correctamente.';

    -- 1. Validación de campos obligatorios nulos
    IF p_idEditorial IS NULL OR p_nombre IS NULL THEN
        SET p_codigo_error = 1;
        SET p_mensaje_error = 'Error Lógico: El ID y el Nombre de la editorial no pueden ser nulos.';

    -- 2. Validación de Clave Primaria Duplicada
    ELSEIF EXISTS (SELECT 1 FROM Editoriales WHERE idEditorial = p_idEditorial) THEN
        SET p_codigo_error = 2;
        SET p_mensaje_error = CONCAT('Error Lógico: Ya existe una editorial registrada con el ID ', p_idEditorial, '.');

    -- 3. Validación de Clave Alternativa Duplicada (Nombre Único)
    ELSEIF EXISTS (SELECT 1 FROM Editoriales WHERE nombre = p_nombre) THEN
        SET p_codigo_error = 3;
        SET p_mensaje_error = CONCAT('Error Lógico: Ya existe una editorial con el nombre \'', p_nombre, '\'.');

    -- Operación si pasa los controles de negocio
    ELSE
        INSERT INTO Editoriales (idEditorial, nombre, ciudad, estado, pais)
        VALUES (p_idEditorial, p_nombre, p_ciudad, p_estado, COALESCE(p_pais, 'USA'));
    END IF;

END //
DELIMITER ;

-- Variables de sesión de control para capturar las salidas OUT
SET @cod_err = 0;
SET @msg_err = '';

-- --- PRUEBAS DE CASOS INCORRECTOS ---
-- Caso Incorrecto 1: Valores mandatorios nulos
CALL `Nueva Editorial`(NULL, 'Editorial Fantasma', 'Tucumán', 'TA', 'Argentina', @cod_err, @msg_err);
SELECT @cod_err AS `Código`, @msg_err AS `Mensaje`;

-- Caso Incorrecto 2: ID Duplicado (El ID '0736' ya existe de Datos.sql)
CALL `Nueva Editorial`('0736', 'Editorial Clonada', 'Boston', 'MA', 'USA', @cod_err, @msg_err);
SELECT @cod_err AS `Código`, @msg_err AS `Mensaje`;

-- Caso Incorrecto 3: Nombre Duplicado (El nombre 'Binnet & Hardley' ya existe)
CALL `Nueva Editorial`('8888', 'Binnet & Hardley', 'Washington', 'DC', 'USA', @cod_err, @msg_err);
SELECT @cod_err AS `Código`, @msg_err AS `Mensaje`;

-- --- PRUEBA DE CASO CORRECTO ---
CALL `Nueva Editorial`('4545', 'Nuevos Horizontes Libros', 'San Miguel', 'TM', 'Argentina', @cod_err, @msg_err);
SELECT @cod_err AS `Código`, @msg_err AS `Mensaje`;

-- Verificación en tabla
SELECT * FROM Editoriales WHERE idEditorial = '4545';


-- =========================================================================
-- PUNTO 4: PROCEDIMIENTO ALMACENADO 'Buscar Titulos PorAutor'
-- =========================================================================
-- Retorna el catálogo completo asociado a un código de autor ordenado por título.

DROP PROCEDURE IF EXISTS `Buscar Titulos PorAutor`;
DELIMITER //

CREATE PROCEDURE `Buscar Titulos PorAutor`(
    IN p_idAutor VARCHAR(11)
)
BEGIN
    SELECT 
        t.idTitulo AS `Código`,
        t.titulo AS `Título`,
        t.genero AS `Género`,
        e.nombre AS `Editorial`,
        t.precio AS `Precio`,
        t.sinopsis AS `Sinopsis`,
        DATE(t.fechaPublicacion) AS `Fecha`
    FROM TitulosDelAutor ta
    INNER JOIN Titulos t ON ta.idTitulo = t.idTitulo
    INNER JOIN Editoriales e ON t.idEditorial = e.idEditorial
    WHERE ta.idAutor = p_idAutor
    ORDER BY t.titulo ASC;
END //
DELIMITER ;

-- Ejecución de control con un Autor válido (ej. Marjorie Green '213-46-8915')
CALL `Buscar Titulos PorAutor`('213-46-8915');


-- =========================================================================
-- PUNTO 5: CONTROL DE INTEGRIDAD REFENCIAL MEDIANTE TRIGGERS
-- =========================================================================
-- Evita el borrado lógico/físico de una Editorial si posee títulos activos vinculados.

DROP TRIGGER IF EXISTS EvitarBorrarEditorialConTitulos;
DELIMITER //

CREATE TRIGGER EvitarBorrarEditorialConTitulos
BEFORE DELETE ON Editoriales
FOR EACH ROW
BEGIN
    -- Validación: Si la editorial vieja que se intenta borrar está en Títulos
    IF EXISTS (SELECT 1 FROM Titulos WHERE idEditorial = OLD.idEditorial) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: No se puede eliminar la editorial debido a que posee títulos referenciados en el catálogo.';
    END IF;
END //
DELIMITER ;

-- -------------------------------------------------------------------------
-- CASO A: BORRADO DE EDITORIAL SIN TÍTULOS ASOCIADOS (Debe funcionar)
-- -------------------------------------------------------------------------
-- La editorial '9952' (Scootney Books) no se vinculó a ningún título en Datos.sql
DELETE FROM Editoriales WHERE idEditorial = '9952';

-- Verificación: Debe retornar vacío, confirmando la remoción exitosa
SELECT * FROM Editoriales WHERE idEditorial = '9952';

-- -------------------------------------------------------------------------
-- CASO B: BORRADO DE EDITORIAL CON TÍTULOS ASOCIADOS (Debe fallar)
-- -------------------------------------------------------------------------
-- La editorial '1389' (Algodata Infosystems) tiene asignado el título 'PC8888', abortará por Trigger.
DELETE FROM Editoriales WHERE idEditorial = '1389';

-- RESULTADO ESPERADO EN CONSOLA:
-- Error Code: 1644. Error: No se puede eliminar la editorial debido a que posee títulos referenciados en el catálogo.