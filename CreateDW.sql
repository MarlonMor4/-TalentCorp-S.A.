/* ╔══════════════════════════════════════════════════════════════════════════╗
   ║                                                                          ║
   ║   SCRIPT 03 — CREACIÓN DEL DATA WAREHOUSE (RRHH_DW)                      ║
   ║                                                                          ║
   ║   QUÉ HACE: Crea la BD analítica con el modelo estrella:                 ║
   ║             7 dimensiones + 3 tablas de hechos + índices DWH.            ║
   ║                                                                          ║
   ╚══════════════════════════════════════════════════════════════════════════╝ */
 
-- ============================================================================
-- 3.1  CREAR / RECREAR EL DATA WAREHOUSE RRHH_DW
-- ============================================================================
IF DB_ID('RRHH_DW') IS NOT NULL
BEGIN
    ALTER DATABASE RRHH_DW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE RRHH_DW;
    PRINT '[INFO] RRHH_DW existía y fue eliminada para recreación limpia.';
END;
GO
CREATE DATABASE RRHH_DW;
GO
PRINT '[OK] Base de datos RRHH_DW creada.';
GO

USE RRHH_DW;



-- ============================================================================
-- 3.2  DIMENSIÓN: DimFecha
-- ============================================================================
-- La dimensión temporal es la más consultada en todo DWH.
-- FechaKey en formato YYYYMMDD (ej: 20230115) tiene una propiedad valiosa:
-- ordenar numéricamente = ordenar cronológicamente.
-- No tiene FK hacia el OLTP porque se genera por código (no se extrae de tablas).
-- ============================================================================
CREATE TABLE DimFecha (
    FechaKey        INT          NOT NULL  PRIMARY KEY,  -- YYYYMMDD: p.ej. 20230115
    FechaCompleta   DATE         NOT NULL,               -- Para cálculos de DATEDIFF
    Anio            INT          NOT NULL,               -- 2023, 2024, 2025
    Semestre        INT          NOT NULL,               -- 1=Ene-Jun | 2=Jul-Dic
    Trimestre       INT          NOT NULL,               -- 1 a 4
    Mes             INT          NOT NULL,               -- 1 a 12
    NombreMes       VARCHAR(20)  NOT NULL,               -- 'Enero', 'Febrero', ...
    Dia             INT          NOT NULL,               -- 1 a 31
    NombreDiaSemana VARCHAR(20)  NOT NULL                -- 'Lunes', 'Martes', ...
);
PRINT '[OK] DimFecha creada.';
GO
 
-- ============================================================================
-- 3.3  DIMENSIÓN: DimOficina
-- ============================================================================
-- Permite segmentar todos los análisis por sede geográfica.
-- OficinaID_OLTP: guarda la clave natural del sistema fuente para que el
-- proceso ETL pueda hacer JOIN y resolver la clave subrogatada (OficinaKey).
-- ============================================================================
CREATE TABLE DimOficina (
    OficinaKey      INT IDENTITY(1,1)  NOT NULL  PRIMARY KEY,  -- SK del DWH (subrogatada)
    OficinaID_OLTP  INT                NOT NULL,                -- NK del OLTP (natural key)
    CodigoOficina   VARCHAR(20)        NOT NULL,
    Ciudad          VARCHAR(100)       NOT NULL,
    Pais            VARCHAR(100)       NOT NULL,
    Region          VARCHAR(100)       NOT NULL,
    CodigoPostal    VARCHAR(20)        NULL
);
PRINT '[OK] DimOficina creada.';
GO
 
-- ============================================================================
-- 3.4  DIMENSIÓN: DimDepartamento
-- ============================================================================
CREATE TABLE DimDepartamento (
    DepartamentoKey     INT IDENTITY(1,1)  NOT NULL  PRIMARY KEY,
    DepartamentoID_OLTP INT                NOT NULL,  -- NK del OLTP
    NombreDepartamento  VARCHAR(100)       NOT NULL,
    Descripcion         VARCHAR(250)       NULL
);
PRINT '[OK] DimDepartamento creada.';
GO
 
-- ============================================================================
-- 3.5  DIMENSIÓN: DimPuesto
-- ============================================================================
-- Permite analizar patrones de desempeño, ausentismo y formación por nivel
-- de cargo (Junior vs Mid-Level vs Senior) y rango salarial.
-- ============================================================================
CREATE TABLE DimPuesto (
    PuestoKey       INT IDENTITY(1,1)  NOT NULL  PRIMARY KEY,
    PuestoID_OLTP   INT                NOT NULL,
    NombrePuesto    VARCHAR(120)       NOT NULL,
    NivelSalarial   VARCHAR(20)        NOT NULL,  -- Junior / Mid-Level / Senior
    SalarioMinimo   DECIMAL(12,2)      NOT NULL,
    SalarioMaximo   DECIMAL(12,2)      NOT NULL
);
PRINT '[OK] DimPuesto creada.';
GO
 
-- ============================================================================
-- 3.6  DIMENSIÓN: DimEmpleado  (SCD Type 1)
-- ============================================================================
-- Snapshot del estado ACTUAL del empleado al momento del ETL.
-- SCD Type 1 = sobreescribe los atributos cuando cambian, sin guardar historial.
-- Para producción se recomendaría SCD Type 2 con fechas de vigencia, pero
-- para este proyecto Type 1 es suficiente según el alcance definido.
-- Atributos derivados calculados en el ETL: Edad y AntiguedadAnios.
-- ============================================================================
CREATE TABLE DimEmpleado (
    EmpleadoKey         INT IDENTITY(1,1)  NOT NULL  PRIMARY KEY,  -- SK del DWH
    EmpleadoID_OLTP     INT                NOT NULL,  -- NK del OLTP
    Identificacion      VARCHAR(30)        NOT NULL,
    NombreCompleto      VARCHAR(220)       NOT NULL,  -- Nombre+Apellidos concatenados en ETL
    Genero              VARCHAR(20)        NOT NULL,
    EstadoCivil         VARCHAR(30)        NOT NULL,
    Edad                INT                NOT NULL,  -- Calculado en el ETL
    FechaContratacion   DATE               NOT NULL,
    AntiguedadAnios     INT                NOT NULL,  -- Calculado en el ETL
    Activo              BIT                NOT NULL,
    DepartamentoID_OLTP INT                NOT NULL,  -- Contexto para JOINs cruzados
    PuestoID_OLTP       INT                NOT NULL,
    OficinaID_OLTP      INT                NOT NULL,
    JefeID_OLTP         INT                NULL       -- NULL para los 5 directivos
);
PRINT '[OK] DimEmpleado creada.';
GO
 
-- ============================================================================
-- 3.7  DIMENSIÓN: DimTipoAusencia
-- ============================================================================
-- Dimensión de cardinalidad muy baja (4 valores).
-- Ideal como filtro/slicer en dashboards de Power BI o Tableau.
-- ============================================================================
CREATE TABLE DimTipoAusencia (
    TipoAusenciaKey INT IDENTITY(1,1)  NOT NULL  PRIMARY KEY,
    TipoAusencia    VARCHAR(30)        NOT NULL  UNIQUE
);
PRINT '[OK] DimTipoAusencia creada.';
GO
 
-- ============================================================================
-- 3.8  DIMENSIÓN: DimCapacitacion
-- ============================================================================
CREATE TABLE DimCapacitacion (
    CapacitacionKey     INT IDENTITY(1,1)  NOT NULL  PRIMARY KEY,
    CapacitacionID_OLTP INT                NOT NULL,
    NombreCapacitacion  VARCHAR(150)       NOT NULL,
    Proveedor           VARCHAR(150)       NOT NULL,
    Costo               DECIMAL(12,2)      NOT NULL,
    DuracionDias        INT                NOT NULL
);
PRINT '[OK] DimCapacitacion creada.';
GO
 
-- ============================================================================
-- 3.9  TABLA DE HECHOS: FactAusencias
-- ============================================================================
-- Proceso de negocio: registro de ausentismo laboral.
-- Granularidad: UN registro por evento de ausencia por empleado.
-- Medidas:
--   CantidadAusencias → ADITIVA: se puede sumar en cualquier dimensión
--   DiasAusencia      → ADITIVA: suma de días tiene sentido siempre
--   JustificadaFlag   → SEMI-ADITIVA: sumar el flag no tiene sentido (% sí)
-- ============================================================================
CREATE TABLE FactAusencias (
    FactAusenciaKey     BIGINT IDENTITY(1,1)  NOT NULL  PRIMARY KEY,
    FechaKey            INT   NOT NULL,  -- Fecha inicio de la ausencia → DimFecha
    EmpleadoKey         INT   NOT NULL,  -- → DimEmpleado
    OficinaKey          INT   NOT NULL,  -- → DimOficina (sede del empleado)
    DepartamentoKey     INT   NOT NULL,  -- → DimDepartamento
    TipoAusenciaKey     INT   NOT NULL,  -- → DimTipoAusencia
    CantidadAusencias   INT   NOT NULL,  -- Siempre 1; permite COUNT(*) y SUM()
    DiasAusencia        INT   NOT NULL,  -- Total días de esta ausencia
    JustificadaFlag     BIT   NOT NULL,  -- 1=con respaldo, 0=injustificada
    CONSTRAINT FK_FactAus_Fecha  FOREIGN KEY (FechaKey)        REFERENCES dbo.DimFecha(FechaKey),
    CONSTRAINT FK_FactAus_Emp    FOREIGN KEY (EmpleadoKey)     REFERENCES dbo.DimEmpleado(EmpleadoKey),
    CONSTRAINT FK_FactAus_Of     FOREIGN KEY (OficinaKey)      REFERENCES dbo.DimOficina(OficinaKey),
    CONSTRAINT FK_FactAus_Dep    FOREIGN KEY (DepartamentoKey) REFERENCES dbo.DimDepartamento(DepartamentoKey),
    CONSTRAINT FK_FactAus_Tipo   FOREIGN KEY (TipoAusenciaKey) REFERENCES dbo.DimTipoAusencia(TipoAusenciaKey)
);
PRINT '[OK] FactAusencias creada.';
GO
 
-- ============================================================================
-- 3.10  TABLA DE HECHOS: FactEvaluaciones
-- ============================================================================
-- Proceso de negocio: evaluación formal de desempeño.
-- Granularidad: UN registro por evaluación realizada.
-- Nota especial: DOS FK a DimEmpleado (evaluado y evaluador).
-- Medidas:
--   Calificacion        → SEMI-ADITIVA: usar AVG, nunca SUM
--   CantidadEvaluaciones→ ADITIVA: permite contar eventos
-- ============================================================================
CREATE TABLE FactEvaluaciones (
    FactEvaluacionKey       BIGINT IDENTITY(1,1)  NOT NULL  PRIMARY KEY,
    FechaKey                INT           NOT NULL,
    EmpleadoKey             INT           NOT NULL,  -- El empleado evaluado
    EvaluadorEmpleadoKey    INT           NOT NULL,  -- El empleado que evalúa
    OficinaKey              INT           NOT NULL,
    DepartamentoKey         INT           NOT NULL,
    PuestoKey               INT           NOT NULL,
    Calificacion            DECIMAL(3,1)  NOT NULL,  -- 1.0 a 5.0
    CantidadEvaluaciones    INT           NOT NULL,  -- Siempre 1
    CONSTRAINT FK_FactEval_Fecha  FOREIGN KEY (FechaKey)             REFERENCES dbo.DimFecha(FechaKey),
    CONSTRAINT FK_FactEval_Emp    FOREIGN KEY (EmpleadoKey)          REFERENCES dbo.DimEmpleado(EmpleadoKey),
    CONSTRAINT FK_FactEval_Eval   FOREIGN KEY (EvaluadorEmpleadoKey) REFERENCES dbo.DimEmpleado(EmpleadoKey),
    CONSTRAINT FK_FactEval_Of     FOREIGN KEY (OficinaKey)           REFERENCES dbo.DimOficina(OficinaKey),
    CONSTRAINT FK_FactEval_Dep    FOREIGN KEY (DepartamentoKey)      REFERENCES dbo.DimDepartamento(DepartamentoKey),
    CONSTRAINT FK_FactEval_Pues   FOREIGN KEY (PuestoKey)            REFERENCES dbo.DimPuesto(PuestoKey)
);
PRINT '[OK] FactEvaluaciones creada.';
GO
 
-- ============================================================================
-- 3.11  TABLA DE HECHOS: FactCapacitaciones
-- ============================================================================
-- Proceso de negocio: participación de empleados en programas de formación.
-- Granularidad: UN registro por asignación empleado-capacitación.
-- Medidas:
--   CostoCapacitacion  → ADITIVA: la inversión total tiene sentido sumar
--   CalificacionObtenida → SEMI-ADITIVA: puede ser NULL (cursos en curso)
--   CantidadAsignaciones → ADITIVA
-- ============================================================================
CREATE TABLE FactCapacitaciones (
    FactCapacitacionKey     BIGINT IDENTITY(1,1)  NOT NULL  PRIMARY KEY,
    FechaKey                INT           NOT NULL,
    EmpleadoKey             INT           NOT NULL,
    CapacitacionKey         INT           NOT NULL,
    OficinaKey              INT           NOT NULL,
    DepartamentoKey         INT           NOT NULL,
    PuestoKey               INT           NOT NULL,
    Estado                  VARCHAR(20)   NOT NULL,  -- 'Completada' o 'En Curso'
    CalificacionObtenida    DECIMAL(5,2)  NULL,      -- NULL si 'En Curso'
    CantidadAsignaciones    INT           NOT NULL,
    CostoCapacitacion       DECIMAL(12,2) NOT NULL,
    CONSTRAINT FK_FactCap_Fecha  FOREIGN KEY (FechaKey)        REFERENCES dbo.DimFecha(FechaKey),
    CONSTRAINT FK_FactCap_Emp    FOREIGN KEY (EmpleadoKey)     REFERENCES dbo.DimEmpleado(EmpleadoKey),
    CONSTRAINT FK_FactCap_Cap    FOREIGN KEY (CapacitacionKey) REFERENCES dbo.DimCapacitacion(CapacitacionKey),
    CONSTRAINT FK_FactCap_Of     FOREIGN KEY (OficinaKey)      REFERENCES dbo.DimOficina(OficinaKey),
    CONSTRAINT FK_FactCap_Dep    FOREIGN KEY (DepartamentoKey) REFERENCES dbo.DimDepartamento(DepartamentoKey),
    CONSTRAINT FK_FactCap_Pues   FOREIGN KEY (PuestoKey)       REFERENCES dbo.DimPuesto(PuestoKey)
);
PRINT '[OK] FactCapacitaciones creada.';
GO
 
-- ============================================================================
-- 3.12  ÍNDICES DEL DATA WAREHOUSE
-- ============================================================================
-- En un DWH los índices van sobre las FK de las tablas de hechos.
-- Los JOINs entre hechos y dimensiones son la operación dominante.
-- ============================================================================
CREATE INDEX IX_FactAus_FechaKey    ON dbo.FactAusencias(FechaKey);
CREATE INDEX IX_FactAus_EmpKey      ON dbo.FactAusencias(EmpleadoKey);
CREATE INDEX IX_FactAus_DepKey      ON dbo.FactAusencias(DepartamentoKey);
CREATE INDEX IX_FactEval_FechaKey   ON dbo.FactEvaluaciones(FechaKey);
CREATE INDEX IX_FactEval_EmpKey     ON dbo.FactEvaluaciones(EmpleadoKey);
CREATE INDEX IX_FactEval_DepKey     ON dbo.FactEvaluaciones(DepartamentoKey);
CREATE INDEX IX_FactCap_FechaKey    ON dbo.FactCapacitaciones(FechaKey);
CREATE INDEX IX_FactCap_EmpKey      ON dbo.FactCapacitaciones(EmpleadoKey);
CREATE INDEX IX_FactCap_CapKey      ON dbo.FactCapacitaciones(CapacitacionKey);
GO
PRINT '[OK] Índices del DWH creados.';
 
-- ============================================================================
--  VERIFICACIÓN SCRIPT 03
--    Muestra las 10 tablas del DWH (7 Dim* + 3 Fact*) en el Object Explorer.
-- ============================================================================
SELECT
    t.name AS Tabla,
    CASE WHEN t.name LIKE 'Dim%' THEN 'Dimensión' ELSE 'Hecho' END AS TipoTabla,
    COUNT(c.column_id) AS NumColumnas
FROM sys.tables t JOIN sys.columns c ON t.object_id = c.object_id
GROUP BY t.name ORDER BY TipoTabla, t.name;
GO
PRINT '=== SCRIPT 03 COMPLETADO: RRHH_DW creada con 7 dimensiones y 3 hechos. ===';

 