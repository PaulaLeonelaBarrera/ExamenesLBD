-- =========================================================================
-- EXAMEN FINAL - LABORATORIO DE BASES DE DATOS 2024
-- Base de datos: DNI39079001
-- Alumna: Paula Leonela Barrera
-- =========================================================================

DROP DATABASE IF EXISTS DNI123;
CREATE DATABASE DNI123;
USE DNI123;

-- PUNTO 1: NOTA ACLARATORIA SOBRE ÍNDICES
-- Se crean índices explícitos sobre las claves primarias y foráneas para 
-- cumplir con la consigna, aunque en MySQL (InnoDB) estos son generados 
-- automáticamente al definir dichas restricciones. 
-- En un escenario real, no sería necesario duplicar índices sobre PK.

-- =====================================================
-- TABLAS INDEPENDIENTES (Se crean primero)
-- =====================================================

-- Tabla Categorias 
CREATE TABLE Categorias (
    IdCategoria INT PRIMARY KEY, 
    Categoria VARCHAR(25) NOT NULL, 
    CONSTRAINT ak1_categorias UNIQUE (Categoria) -- Restricción: Nombres de categorías únicos 
);

-- Índices explícitos para Categorias 
CREATE INDEX idx_pk_Categorias ON Categorias(IdCategoria);


-- Tabla Puestos 
CREATE TABLE Puestos (
    IdPuesto INT PRIMARY KEY, 
    Puesto VARCHAR(25) NOT NULL, 
    CONSTRAINT ak1_puestos UNIQUE (Puesto) -- Restricción: Nombres de puestos únicos 
);

-- Índices explícitos para Puestos 
CREATE INDEX idx_pk_Puestos ON Puestos(IdPuesto);


-- Tabla Niveles 
CREATE TABLE Niveles (
    IdNivel INT PRIMARY KEY, 
    Nivel VARCHAR(25) NOT NULL, 
    CONSTRAINT ak1_niveles UNIQUE (Nivel) -- Restricción: Nombres de niveles únicos 
);

-- Índices explícitos para Niveles 
CREATE INDEX idx_pk_Niveles ON Niveles(IdNivel);


-- =====================================================
-- TABLAS DEPENDIENTES (Se crean al final)
-- =====================================================

-- Tabla Conocimientos 
CREATE TABLE Conocimientos (
    IdConocimiento INT NOT NULL, 
    IdCategoria INT NOT NULL, 
    Conocimiento VARCHAR(25) NOT NULL, 
    PRIMARY KEY (IdConocimiento, IdCategoria), -- Clave primaria compuesta 
    FOREIGN KEY (IdCategoria) REFERENCES Categorias(IdCategoria), 
    CONSTRAINT ak1_conocimientos UNIQUE (IdCategoria, Conocimiento)-- Restricción: Nombres de conocimientos únicos, el conocimiento puede repetirse en otra categoría 
);

-- Índices explícitos para Conocimientos (PK Compuesta y FK) 
CREATE INDEX idx_pk_Conocimientos ON Conocimientos(IdConocimiento, IdCategoria);
CREATE INDEX idx_fk_Conocimientos_IdCategoria ON Conocimientos(IdCategoria);


-- Tabla Personas 
CREATE TABLE Personas (
    IdPersona INT PRIMARY KEY, 
    IdPuesto INT NOT NULL, 
    Nombres VARCHAR(25) NOT NULL, 
    Apellidos VARCHAR(25) NOT NULL, 
    FechaIngreso DATE NOT NULL, 
    FechaBaja DATE NULL, 
    FOREIGN KEY (IdPuesto) REFERENCES Puestos(IdPuesto),
    CONSTRAINT chk_fechas_personas CHECK (FechaBaja IS NULL OR FechaBaja > FechaIngreso) -- Regla de negocio 
);

-- Índices explícitos para Personas (PK y FK) 
CREATE INDEX idx_pk_Personas ON Personas(IdPersona);
CREATE INDEX idx_fk_Personas_IdPuesto ON Personas(IdPuesto);


-- Tabla Habilidades 
CREATE TABLE Habilidades (
    IdHabilidad INT PRIMARY KEY, 
    IdPersona INT NOT NULL, 
    IdConocimiento INT NOT NULL, 
    IdCategoria INT NOT NULL, 
    IdNivel INT NOT NULL DEFAULT 1, -- Valor predeterminado 1 
    FechaUltimaModificacion DATE NOT NULL DEFAULT (CURRENT_DATE), -- Fecha actual por defecto 
    Observaciones VARCHAR(144) NULL, 
    FOREIGN KEY (IdPersona) REFERENCES Personas(IdPersona),
    FOREIGN KEY (IdConocimiento, IdCategoria) REFERENCES Conocimientos(IdConocimiento, IdCategoria),
    FOREIGN KEY (IdNivel) REFERENCES Niveles(IdNivel)
);

-- Índices explícitos para Habilidades (PK y todas las FKs) 
CREATE INDEX idx_pk_Habilidades ON Habilidades(IdHabilidad);
CREATE INDEX idx_fk_Habilidades_IdPersona ON Habilidades(IdPersona);
CREATE INDEX idx_fk_Habilidades_Conocimientos ON Habilidades(IdConocimiento, IdCategoria);
CREATE INDEX idx_fk_Habilidades_IdNivel ON Habilidades(IdNivel);

-- -------------------------------------------------------------------------
-- NOTA: En esta línea se debe ejecutar el contenido de tu archivo "Datos2024.sql". 
-- -------------------------------------------------------------------------

-- =========================================================================
-- PUNTO 2: CREACIÓN DE LA VISTA 'vista_conocimientos_por_empleado' 
-- =========================================================================
-- Muestra categorías, conocimientos, empleados y sus niveles, controlando 
-- si el empleado no se encuentra activo para forzar la etiqueta 'Dado de baja'. 

CREATE OR REPLACE VIEW vista_conocimientos_por_empleado AS
SELECT 
    c.Categoria AS `Categoría`, 
    cn.Conocimiento AS `Conocimiento`, 
    CONCAT(p.Apellidos, ', ', p.Nombres) AS `Empleado`, 
    
    -- Control lógico: Si tiene cargada una fecha de baja, se rotula como se indica
    CASE 
        WHEN p.FechaBaja IS NOT NULL THEN 'Dado de baja'
        ELSE n.Nivel
    END AS `Nivel`

FROM Habilidades h
INNER JOIN Personas p ON h.IdPersona = p.IdPersona
INNER JOIN Conocimientos cn ON h.IdConocimiento = cn.IdConocimiento AND h.IdCategoria = cn.IdCategoria
INNER JOIN Categorias c ON cn.IdCategoria = c.IdCategoria
INNER JOIN Niveles n ON h.IdNivel = n.IdNivel

ORDER BY c.Categoria ASC, cn.Conocimiento ASC; 

-- Consulta de verificación para el examen
SELECT * FROM vista_conocimientos_por_empleado;


-- =========================================================================
-- PUNTO 3: PROCEDIMIENTO ALMACENADO 'rsp_borrar_habilidad' 
-- =========================================================================
-- Borrado físico seguro de registros de la tabla Habilidades controlando 
-- la existencia del ID mediante parámetros de salida (OUT). 

DROP PROCEDURE IF EXISTS rsp_borrar_habilidad;
DELIMITER //

CREATE PROCEDURE rsp_borrar_habilidad(
    IN p_IdHabilidad INT,
    OUT p_codigo_error INT,
    OUT p_mensaje_error VARCHAR(255)
)
BEGIN
    -- Se inicializan los parámetros de salida asumiendo éxito por defecto.
    SET p_codigo_error = 0;
    SET p_mensaje_error = 'Habilidad eliminada con éxito.';

    -- -----------------------------------------------------------------
    -- VALIDACIÓN DE ERRORES LÓGICOS
    -- -----------------------------------------------------------------

    -- 1. Control de nulidad del parámetro de entrada
    IF p_IdHabilidad IS NULL THEN
        SET p_codigo_error = 1;
        SET p_mensaje_error = 'Error Lógico: El ID de la habilidad provisto no puede ser nulo.';

    -- 2. Control de existencia de la clave primaria (PK)
    ELSEIF NOT EXISTS (SELECT 1 FROM Habilidades WHERE IdHabilidad = p_IdHabilidad) THEN
        SET p_codigo_error = 2;
        SET p_mensaje_error = CONCAT('Error Lógico: No existe ninguna habilidad registrada con el ID ', p_IdHabilidad, '.');

    -- -----------------------------------------------------------------
    -- OPERACIÓN DE ELIMINACIÓN (Si se superan las validaciones)
    -- -----------------------------------------------------------------
    ELSE
        DELETE FROM Habilidades WHERE IdHabilidad = p_IdHabilidad;
    END IF;

END //

DELIMITER ;

-- Variables de sesión para capturar los resultados de las salidas OUT
SET @cod_err = 0;
SET @msg_err = '';

-- =========================================================================
-- PRUEBAS DE CASOS INCORRECTOS (Códigos de error 1 y 2) 
-- =========================================================================

-- CASO INCORRECTO 1: Id nulo 
CALL rsp_borrar_habilidad(NULL, @cod_err, @msg_err);
SELECT @cod_err AS `Código de Error`, @msg_err AS `Mensaje de Error`;

-- CASO INCORRECTO 2: Id de habilidad que no existe en el sistema 
CALL rsp_borrar_habilidad(9999, @cod_err, @msg_err);
SELECT @cod_err AS `Código de Error`, @msg_err AS `Mensaje de Error`;

-- =========================================================================
-- PRUEBA DE CASO CORRECTO (Debe devolver código 0 e impactar en las tablas) 
-- =========================================================================
-- Asumiendo que el ID 1 existe posterior a la ejecución de Datos.sql
CALL rsp_borrar_habilidad(1, @cod_err, @msg_err);
SELECT @cod_err AS `Código de Error`, @msg_err AS `Mensaje de Error`;

-- Comprobación física de la eliminación exitosa
SELECT * FROM Habilidades WHERE IdHabilidad = 1;


-- =========================================================================
-- PUNTO 4: PROCEDIMIENTO ALMACENADO 'rsp_cantidades' 
-- =========================================================================
-- Generación de reporte de métricas combinando el detalle descriptivo con 
-- una fila consolidada de sumatorios globales usando UNION ALL y CAST dinámicos. 

DROP PROCEDURE IF EXISTS rsp_cantidades;
DELIMITER //

CREATE PROCEDURE rsp_cantidades()
BEGIN
    
    -- Subconsulta externa para aislar la ordenación y evitar que la fila de resumen se mezcle 
    SELECT 
        `Categoría`,
        `Conocimiento`,
        `Cantidad`
    FROM (
        
        -- PARTE A: Detalle analítico por conocimiento y cantidad de empleados únicos 
        -- Se utiliza CAST para unificar los tipos de datos en los SELECT del UNION ALL,
        -- evitando conversiones implícitas y asegurando consistencia en el resultado.
        SELECT 
            CAST(c.Categoria AS CHAR(50)) AS `Categoría`,
            CAST(cn.Conocimiento AS CHAR(50)) AS `Conocimiento`,
            CAST(COUNT(DISTINCT h.IdPersona) AS CHAR(50)) AS `Cantidad`,
            1 AS tipo_fila,                        -- Bandera para dejar el bloque analítico al inicio
            c.Categoria AS cat_ordenar,
            cn.Conocimiento AS con_ordenar
        FROM Habilidades h
        INNER JOIN Conocimientos cn ON h.IdConocimiento = cn.IdConocimiento AND h.IdCategoria = cn.IdCategoria
        INNER JOIN Categorias c ON cn.IdCategoria = c.IdCategoria
        GROUP BY c.IdCategoria, c.Categoria, cn.IdConocimiento, cn.Conocimiento
        
        UNION ALL
        
        -- PARTE B: Fila consolidada de totales estructurales (solo elementos mapeados en habilidades) 
        SELECT 
            CAST(COUNT(DISTINCT h.IdCategoria) AS CHAR(50)) AS `Categoría`, -- Total categorías únicas 
            CAST(COUNT(DISTINCT h.IdCategoria, h.IdConocimiento) AS CHAR(50)) AS `Conocimiento`, -- Total conocimientos únicos 
            CAST(COUNT(DISTINCT h.IdPersona) AS CHAR(50)) AS `Cantidad`,   -- Total empleados asignados únicos 
            2 AS tipo_fila,                        -- Bandera que fuerza la fila al fondo del reporte
            '' AS cat_ordenar,
            '' AS con_ordenar
        FROM Habilidades h
        
    ) AS ReporteEstructural
    
    -- Criterio de ordenación: Detalle arriba ordenado DESC, totales estrictamente abajo 
    ORDER BY tipo_fila ASC, cat_ordenar DESC, con_ordenar DESC;

END //

DELIMITER ;

-- Ejecución de control del Reporte Consolidado
CALL rsp_cantidades();


-- =========================================================================
-- PUNTO 5: CONTROL DE INTEGRIDAD MEDIANTE TRIGGERS 
-- =========================================================================
-- Bloqueo preventivo en operaciones de eliminación (BEFORE DELETE) para preservar 
-- la integridad referencial del negocio antes de comprometer registros. 

DROP TRIGGER IF EXISTS EvitarBorrarPuestoConPersonas;
DELIMITER //

CREATE TRIGGER EvitarBorrarPuestoConPersonas
BEFORE DELETE ON Puestos
FOR EACH ROW
BEGIN
    -- VALIDACIÓN: Evalúa si el puesto objetivo (OLD.IdPuesto) está asignado en Personas 
    IF EXISTS (SELECT 1 FROM Personas WHERE IdPuesto = OLD.IdPuesto) THEN
        -- Interrupción de la transacción levantando un código de excepción personalizado 
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: No se puede eliminar el puesto debido a que se encuentra asignado a una o más personas activas.';
    END IF;
END //

DELIMITER ;

-- -------------------------------------------------------------------------
-- CASO A: BORRADO DE UN PUESTO QUE NO TIENE NINGUNA PERSONA (Debe funcionar) 
-- -------------------------------------------------------------------------
-- 1. Insertamos un puesto limpio de control
INSERT INTO Puestos (IdPuesto, Puesto) 
VALUES (99, 'Puesto de Prueba Vacío');

-- 2. El trigger evalúa la ausencia de dependencias y permite el borrado sin inconvenientes 
DELETE FROM Puestos 
WHERE IdPuesto = 99;

-- Verificación: Debe retornar vacío, confirmando la remoción exitosa
SELECT * FROM Puestos WHERE IdPuesto = 99;

-- -------------------------------------------------------------------------
-- CASO B: BORRADO DE UN PUESTO CON PERSONAS ASOCIADAS (Debe fallar) 
-- -------------------------------------------------------------------------
-- Intentamos eliminar el Puesto ID 1 (ej. 'Programador' de los datos base), el cual 
-- cuenta con empleados dependientes activos. El trigger abortará la ejecución. 
DELETE FROM Puestos 
WHERE IdPuesto = 1;

-- RESULTADO ESPERADO EN CONSOLA DE MYSQL:
-- Error Code: 1644. Error: No se puede eliminar el puesto debido a que se encuentra asignado a una o más personas activas.