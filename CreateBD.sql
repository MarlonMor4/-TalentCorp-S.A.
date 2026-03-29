/* ╔══════════════════════════════════════════════════════════════════════════╗
   ║                                                                          ║
   ║   SCRIPT 01 — CREACIÓN DE LA BASE DE DATOS OLTP (RRHH_OLTP)              ║
   ║                                                                          ║
   ║   QUÉ HACE: Crea la base de datos transaccional con 8 tablas,            ║
   ║             restricciones de integridad referencial e índices.           ║
   ║                                                                          ║
   ╚══════════════════════════════════════════════════════════════════════════╝ */
 
-- ============================================================================
-- 1.1  CREAR / RECREAR LA BASE DE DATOS RRHH_OLTP
-- ============================================================================
-- Si la BD ya existe la eliminamos para garantizar un arranque limpio.
-- ALTER DATABASE ... SINGLE_USER cierra todas las conexiones activas antes
-- de eliminar, evitando el error "Cannot drop because it is in use".
IF DB_ID('RRHH_OLTP') IS NOT NULL
BEGIN
    ALTER DATABASE RRHH_OLTP SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE RRHH_OLTP;
    PRINT '[INFO] RRHH_OLTP existía y fue eliminada para recreación limpia.';
END;
GO
 
CREATE DATABASE RRHH_OLTP;
GO
PRINT '[OK] Base de datos RRHH_OLTP creada exitosamente.';
GO
 
USE RRHH_OLTP;
GO
 
-- ============================================================================
-- 1.2  TABLA: Oficinas
-- ============================================================================
-- Propósito : Almacena las sedes físicas de TalentCorp alrededor del mundo.
--             Es la tabla raíz del modelo: sin oficinas no puede haber
--             departamentos ni empleados asignados.
-- Relaciones: Referenciada por Departamentos y Empleados (1:N ambas).
-- Restricción UNIQUE en CodigoOficina: el código mnemónico identifica
--             unívocamente cada sede (ej: 'BOG-NORTE') sin usar el ID numérico.
-- ============================================================================
CREATE TABLE Oficinas (
    OficinaID       INT IDENTITY(1,1)  NOT NULL  PRIMARY KEY,  -- PK autoincremental, inmutable
    CodigoOficina   VARCHAR(20)        NOT NULL  UNIQUE,        -- Código legible: 'MAD-CENTRO', 'BOG-NORTE'
    Ciudad          VARCHAR(100)       NOT NULL,                -- Ciudad de la sede
    Pais            VARCHAR(100)       NOT NULL,                -- País (para agrupación geográfica)
    Region          VARCHAR(100)       NOT NULL,                -- Región: Europa / LatAm / Cono Sur
    CodigoPostal    VARCHAR(20)        NULL,                    -- Opcional: varía por país
    Telefono        VARCHAR(30)        NULL,                    -- Teléfono principal de la sede
    Direccion       VARCHAR(200)       NOT NULL,                -- Dirección física completa
    FechaCreacion   DATETIME2          NOT NULL  DEFAULT SYSDATETIME()  -- Auditoría
);
PRINT '[OK] Tabla Oficinas creada.';
GO
 
-- ============================================================================
-- 1.3  TABLA: Departamentos
-- ============================================================================
-- Propósito : Unidades organizacionales de TalentCorp (RR.HH., Tecnología,
--             Ventas, Finanzas, Marketing). Cada departamento opera en UNA sede.
-- Relación  : N departamentos → 1 oficina (FK OficinaID).
--             1 departamento → N empleados (inversa en tabla Empleados).
-- UNIQUE en NombreDepartamento: no puede haber dos áreas con el mismo nombre.
-- ============================================================================
CREATE TABLE Departamentos (
    DepartamentoID      INT IDENTITY(1,1)  NOT NULL  PRIMARY KEY,
    NombreDepartamento  VARCHAR(100)       NOT NULL  UNIQUE,    -- Nombre único del área funcional
    Descripcion         VARCHAR(250)       NULL,                -- Descripción de responsabilidades
    OficinaID           INT                NOT NULL,            -- FK → Oficinas (sede principal del depto.)
    FechaCreacion       DATETIME2          NOT NULL  DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Departamentos_Oficinas
        FOREIGN KEY (OficinaID) REFERENCES dbo.Oficinas(OficinaID)
);
PRINT '[OK] Tabla Departamentos creada.';
GO
 
-- ============================================================================
-- 1.4  TABLA: Puestos
-- ============================================================================
-- Propósito : Catálogo de cargos laborales con su banda salarial.
--             Define la estructura de compensación de TalentCorp por nivel:
--             Junior (entrada), Mid-Level (intermedio), Senior (experto).
-- CHECK NivelSalarial: solo acepta los 3 valores definidos por política de RR.HH.
-- CHECK RangoSalario : SalarioMinimo debe ser > 0 y <= SalarioMaximo.
--                      Evita datos absurdos como un mínimo mayor al máximo.
-- ============================================================================
CREATE TABLE Puestos (
    PuestoID        INT IDENTITY(1,1)   NOT NULL  PRIMARY KEY,
    NombrePuesto    VARCHAR(120)        NOT NULL,                -- Nombre del cargo, ej: 'Desarrollador Senior'
    NivelSalarial   VARCHAR(20)         NOT NULL,               -- Banda salarial del cargo
    SalarioMinimo   DECIMAL(12,2)       NOT NULL,               -- Piso del rango salarial en USD
    SalarioMaximo   DECIMAL(12,2)       NOT NULL,               -- Techo del rango salarial en USD
    FechaCreacion   DATETIME2           NOT NULL  DEFAULT SYSDATETIME(),
    -- Los tres niveles definen la jerarquía de madurez profesional en TalentCorp
    CONSTRAINT CK_Puestos_NivelSalarial
        CHECK (NivelSalarial IN ('Junior', 'Mid-Level', 'Senior')),
    -- Integridad del rango: evita configuraciones imposibles
    CONSTRAINT CK_Puestos_RangoSalario
        CHECK (SalarioMinimo > 0 AND SalarioMaximo >= SalarioMinimo)
);
PRINT '[OK] Tabla Puestos creada.';
GO
 
-- ============================================================================
-- 1.5  TABLA: Empleados  (entidad central del modelo OLTP)
-- ============================================================================
-- Propósito : Registro maestro de todo el personal de TalentCorp.
--             Es la entidad más relacionada del modelo: tiene 4 FK salientes
--             y recibe FK de 3 tablas transaccionales.
--
-- Auto-referencia JefeID:
--   Permite modelar la jerarquía organizacional directamente en la tabla.
--   JefeID = NULL significa que el empleado es el máximo responsable de su área
--   (director/gerente sin jefe asignado en el sistema).
--   JefeID ≠ NULL apunta al EmpleadoID del jefe directo.
--
-- Campo Activo (BIT):
--   Permite "desactivar" a un empleado desvinculado en lugar de eliminarlo,
--   preservando el histórico de transacciones (ausencias, evaluaciones, cap.)
--   que dependen de su EmpleadoID.
-- ============================================================================
CREATE TABLE Empleados (
    EmpleadoID          INT IDENTITY(1,1)   NOT NULL  PRIMARY KEY,
    Identificacion      VARCHAR(30)         NOT NULL  UNIQUE,   -- DNI/CC/Pasaporte: identificador legal único
    Nombre              VARCHAR(80)         NOT NULL,
    Apellidos           VARCHAR(120)        NOT NULL,
    FechaNacimiento     DATE                NOT NULL,
    Genero              VARCHAR(20)         NOT NULL,            -- Controlado por CHECK abajo
    EstadoCivil         VARCHAR(30)         NOT NULL,
    Email               VARCHAR(150)        NOT NULL  UNIQUE,   -- Email corporativo: clave digital única
    Telefono            VARCHAR(30)         NULL,
    FechaContratacion   DATE                NOT NULL,            -- Inicio del vínculo laboral
    DepartamentoID      INT                 NOT NULL,            -- FK → Departamentos
    PuestoID            INT                 NOT NULL,            -- FK → Puestos (cargo actual)
    SalarioActual       DECIMAL(12,2)       NOT NULL,            -- Salario vigente en USD
    JefeID              INT                 NULL,                -- FK auto-referencial (NULL = sin jefe superior)
    OficinaID           INT                 NOT NULL,            -- FK → Oficinas (sede asignada)
    Activo              BIT                 NOT NULL  DEFAULT 1, -- 1=activo, 0=desvinculado
    FechaCreacion       DATETIME2           NOT NULL  DEFAULT SYSDATETIME(),
    -- ── Integridad referencial: todos los FK deben apuntar a registros válidos ──
    CONSTRAINT FK_Empleados_Departamentos
        FOREIGN KEY (DepartamentoID)  REFERENCES dbo.Departamentos(DepartamentoID),
    CONSTRAINT FK_Empleados_Puestos
        FOREIGN KEY (PuestoID)        REFERENCES dbo.Puestos(PuestoID),
    CONSTRAINT FK_Empleados_Oficinas
        FOREIGN KEY (OficinaID)       REFERENCES dbo.Oficinas(OficinaID),
    -- La auto-referencia: un empleado puede ser jefe de otro empleado
    CONSTRAINT FK_Empleados_Jefe
        FOREIGN KEY (JefeID)          REFERENCES dbo.Empleados(EmpleadoID),
    -- ── Validaciones de dominio ──
    CONSTRAINT CK_Empleados_Genero
        CHECK (Genero IN ('Masculino', 'Femenino', 'No Binario', 'Otro')),
    CONSTRAINT CK_Empleados_Salario
        CHECK (SalarioActual > 0)
);
PRINT '[OK] Tabla Empleados creada.';
GO
 
-- ============================================================================
-- 1.6  TABLA: Ausencias
-- ============================================================================
-- Propósito : Registra cada evento de ausentismo laboral de cualquier empleado.
--             Un empleado puede tener múltiples ausencias a lo largo del tiempo.
--
-- DiasTotales (columna calculada PERSISTED):
--   Se calcula automáticamente como (FechaFin - FechaInicio + 1).
--   El "+1" hace que el cálculo sea INCLUSIVO en ambos extremos:
--   si inicio=lunes y fin=miércoles → DiasTotales = 3 (no 2).
--   PERSISTED significa que se almacena físicamente en disco y se actualiza
--   automáticamente cuando cambian FechaInicio o FechaFin. Esto la hace
--   indexable y evita recalcularla en cada SELECT.
--
-- Tipos de ausencia permitidos (CHECK):
--   Solo los 4 tipos definidos por la política laboral de TalentCorp.
--   Cualquier otro valor es rechazado a nivel de base de datos.
-- ============================================================================
CREATE TABLE Ausencias (
    AusenciaID      INT IDENTITY(1,1)   NOT NULL  PRIMARY KEY,
    EmpleadoID      INT                 NOT NULL,               -- FK → Empleados (quién estuvo ausente)
    TipoAusencia    VARCHAR(30)         NOT NULL,               -- Categoría del evento
    FechaInicio     DATE                NOT NULL,
    FechaFin        DATE                NOT NULL,
    -- Columna calculada: se persiste para que sea indexable y eficiente en consultas
    DiasTotales     AS (DATEDIFF(DAY, FechaInicio, FechaFin) + 1)  PERSISTED,
    Justificada     BIT                 NOT NULL,               -- 1=con respaldo doc., 0=injustificada
    Comentarios     VARCHAR(300)        NULL,
    FechaRegistro   DATETIME2           NOT NULL  DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Ausencias_Empleados
        FOREIGN KEY (EmpleadoID) REFERENCES dbo.Empleados(EmpleadoID),
    -- Solo 4 tipos válidos según política interna de RR.HH.
    CONSTRAINT CK_Ausencias_Tipo
        CHECK (TipoAusencia IN ('Vacaciones', 'Enfermedad', 'Permiso Personal', 'Licencia Médica')),
    -- La fecha de fin nunca puede ser anterior a la de inicio
    CONSTRAINT CK_Ausencias_Fechas
        CHECK (FechaFin >= FechaInicio)
);
PRINT '[OK] Tabla Ausencias creada.';
GO
 
-- ============================================================================
-- 1.7  TABLA: EvaluacionesDesempeno
-- ============================================================================
-- Propósito : Registro de cada evaluación formal de desempeño realizada.
--             TalentCorp hace evaluaciones semestrales o anuales.
--             El evaluador es SIEMPRE otro empleado (no un sistema externo),
--             normalmente el jefe directo del evaluado.
--
-- Doble FK a Empleados:
--   EmpleadoEvaluadoID → el empleado que recibe la calificación
--   EvaluadorID        → el empleado (jefe) que realiza la evaluación
--   Ambas referencian la misma tabla Empleados con nombres de constraint distintos.
--
-- Escala de calificación (1.0 a 5.0):
--   1.0 = Muy deficiente  |  2.0 = Deficiente  |  3.0 = Regular
--   4.0 = Bueno           |  5.0 = Excelente
--   El CHECK garantiza que ninguna calificación salga de este rango.
-- ============================================================================
CREATE TABLE EvaluacionesDesempeno (
    EvaluacionID        INT IDENTITY(1,1)   NOT NULL  PRIMARY KEY,
    EmpleadoEvaluadoID  INT                 NOT NULL,  -- FK → empleado que recibe la evaluación
    FechaEvaluacion     DATE                NOT NULL,
    Calificacion        DECIMAL(3,1)        NOT NULL,  -- Un solo decimal: 3.5, 4.0, 4.5, etc.
    EvaluadorID         INT                 NOT NULL,  -- FK → empleado que realiza la evaluación
    Comentarios         VARCHAR(500)        NULL,      -- Retroalimentación narrativa del evaluador
    FechaRegistro       DATETIME2           NOT NULL   DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Evaluaciones_EmpleadoEvaluado
        FOREIGN KEY (EmpleadoEvaluadoID) REFERENCES dbo.Empleados(EmpleadoID),
    CONSTRAINT FK_Evaluaciones_Evaluador
        FOREIGN KEY (EvaluadorID)        REFERENCES dbo.Empleados(EmpleadoID),
    CONSTRAINT CK_Evaluaciones_Calificacion
        CHECK (Calificacion BETWEEN 1.0 AND 5.0)
);
PRINT '[OK] Tabla EvaluacionesDesempeno creada.';
GO
 
-- ============================================================================
-- 1.8  TABLA: Capacitaciones
-- ============================================================================
-- Propósito : Catálogo maestro de programas de formación disponibles en TalentCorp.
--             Define el programa en sí (nombre, proveedor, costo, fechas),
--             NO la participación individual de cada empleado.
--             La participación individual se registra en EmpleadosCapacitaciones.
--
-- DuracionDias (columna calculada PERSISTED):
--   Misma lógica que DiasTotales en Ausencias: inclusivo en ambos extremos.
--   Un programa de un solo día tiene DuracionDias = 1.
-- ============================================================================
CREATE TABLE Capacitaciones (
    CapacitacionID      INT IDENTITY(1,1)   NOT NULL  PRIMARY KEY,
    NombreCapacitacion  VARCHAR(150)        NOT NULL,  -- Nombre descriptivo del programa
    Descripcion         VARCHAR(300)        NULL,
    Proveedor           VARCHAR(150)        NOT NULL,  -- Empresa externa o departamento interno que imparte
    Costo               DECIMAL(12,2)       NOT NULL,  -- Costo unitario por participante en USD
    FechaInicio         DATE                NOT NULL,
    FechaFin            DATE                NOT NULL,
    DuracionDias        AS (DATEDIFF(DAY, FechaInicio, FechaFin) + 1)  PERSISTED,
    FechaCreacion       DATETIME2           NOT NULL   DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Capacitaciones_Costo
        CHECK (Costo >= 0),          -- Puede ser 0 para formaciones internas gratuitas
    CONSTRAINT CK_Capacitaciones_Fechas
        CHECK (FechaFin >= FechaInicio)
);
PRINT '[OK] Tabla Capacitaciones creada.';
GO
 
-- ============================================================================
-- 1.9  TABLA: EmpleadosCapacitaciones  (tabla de relación N:M)
-- ============================================================================
-- Propósito : Registra qué empleados participan en qué capacitaciones.
--             Resuelve la relación muchos-a-muchos entre Empleados y Capacitaciones
--             agregando atributos propios de la participación:
--             resultado (CalificacionObtenida), estado y comentarios.
--
-- UNIQUE (EmpleadoID, CapacitacionID):
--   Impide que el mismo empleado sea inscrito dos veces en la misma capacitación.
--   Es la restricción de negocio más importante de esta tabla.
--
-- Estados posibles:
--   'Completada' → CalificacionObtenida y FechaCompletado deben tener valor
--   'En Curso'   → CalificacionObtenida y FechaCompletado son NULL (aún en progreso)
-- ============================================================================
CREATE TABLE EmpleadosCapacitaciones (
    EmpleadoCapacitacionID  INT IDENTITY(1,1)  NOT NULL  PRIMARY KEY,
    EmpleadoID              INT                NOT NULL,  -- FK → Empleados
    CapacitacionID          INT                NOT NULL,  -- FK → Capacitaciones
    CalificacionObtenida    DECIMAL(5,2)       NULL,      -- Escala 0-100; NULL si 'En Curso'
    FechaCompletado         DATE               NULL,      -- NULL si 'En Curso'
    Estado                  VARCHAR(20)        NOT NULL,  -- 'Completada' o 'En Curso'
    Comentarios             VARCHAR(300)       NULL,
    FechaRegistro           DATETIME2          NOT NULL   DEFAULT SYSDATETIME(),
    CONSTRAINT FK_EmpleadoCap_Empleados
        FOREIGN KEY (EmpleadoID)     REFERENCES dbo.Empleados(EmpleadoID),
    CONSTRAINT FK_EmpleadoCap_Capacitaciones
        FOREIGN KEY (CapacitacionID) REFERENCES dbo.Capacitaciones(CapacitacionID),
    CONSTRAINT CK_EmpleadoCap_Estado
        CHECK (Estado IN ('Completada', 'En Curso')),
    CONSTRAINT CK_EmpleadoCap_Calificacion
        CHECK (CalificacionObtenida IS NULL OR CalificacionObtenida BETWEEN 0 AND 100),
    -- RESTRICCIÓN CRÍTICA: un empleado no puede inscribirse dos veces al mismo programa
    CONSTRAINT UQ_EmpleadoCap
        UNIQUE (EmpleadoID, CapacitacionID)
);
PRINT '[OK] Tabla EmpleadosCapacitaciones creada.';
GO
 
-- ============================================================================
-- 1.10  ÍNDICES DE RENDIMIENTO
-- ============================================================================
-- Los índices aceleran las consultas de JOINs y filtros más frecuentes.
-- Se crean DESPUÉS de las tablas para no bloquear la creación con locks.
-- Convención de nombres: IX_<Tabla>_<Columnas>
-- ============================================================================
 
-- Índices en Empleados: los JOIN más habituales en reportes de RR.HH.
CREATE INDEX IX_Empleados_DepartamentoID  ON dbo.Empleados(DepartamentoID);
CREATE INDEX IX_Empleados_PuestoID        ON dbo.Empleados(PuestoID);
CREATE INDEX IX_Empleados_OficinaID       ON dbo.Empleados(OficinaID);
CREATE INDEX IX_Empleados_JefeID          ON dbo.Empleados(JefeID);  -- Consultas de jerarquía
 
-- Índice compuesto en Ausencias: la búsqueda típica es "ausencias de X empleado en X período"
CREATE INDEX IX_Ausencias_EmpFecha
    ON dbo.Ausencias(EmpleadoID, FechaInicio);
 
-- Índice en Evaluaciones: análisis histórico por empleado y fecha
CREATE INDEX IX_Evaluaciones_EmpFecha
    ON dbo.EvaluacionesDesempeno(EmpleadoEvaluadoID, FechaEvaluacion);
 
-- Índice en la tabla N:M: recuperar todas las capacitaciones de un empleado
CREATE INDEX IX_EmpleadoCap_EmpleadoID
    ON dbo.EmpleadosCapacitaciones(EmpleadoID);
GO
PRINT '[OK] Índices de rendimiento creados.';

SELECT
    t.name          AS Tabla,
    COUNT(c.column_id) AS NumColumnas,
    -- Muestra si la tabla tiene restricciones FK (integridad referencial activa)
    (SELECT COUNT(*) FROM sys.foreign_keys fk WHERE fk.parent_object_id = t.object_id)
                    AS NumFK
FROM sys.tables t
JOIN sys.columns c ON t.object_id = c.object_id
GROUP BY t.name, t.object_id
ORDER BY t.name;
GO
PRINT '=== SCRIPT 01 COMPLETADO: RRHH_OLTP creada con 8 tablas. ===';
