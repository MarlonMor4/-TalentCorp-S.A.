/* ╔══════════════════════════════════════════════════════════════════════════╗
   ║                                                                          ║
   ║   SCRIPT 04 — PROCESO ETL (EXTRACCIÓN, TRANSFORMACIÓN Y CARGA)           ║
   ║                                                                          ║
   ║   QUÉ HACE: Extrae datos de RRHH_OLTP, los transforma y carga en         ║
   ║             RRHH_DW. Genera DimFecha programáticamente (2023-2025).      ║
   ║   PREREQUISITO: Scripts 01, 02 y 03 ejecutados en la MISMA instancia.    ║
   ║                                                                          ║
   ╚══════════════════════════════════════════════════════════════════════════╝ */
 
USE RRHH_DW;
GO
 
-- ============================================================================
-- 4.1  LIMPIEZA DEL DWH (TRUNCATE en orden inverso a las FK)
-- ============================================================================
-- TRUNCATE es más rápido que DELETE porque opera a nivel de extensión de página,
-- no fila por fila. No genera log de transacciones individual por fila.
-- ORDEN CRÍTICO: primero las tablas de hechos (tienen FK → dimensiones),
-- luego las dimensiones (se puede truncar en cualquier orden entre ellas).
-- ============================================================================

-- Desactivar restricciones
ALTER TABLE dbo.FactCapacitaciones NOCHECK CONSTRAINT ALL;

-- Truncar
TRUNCATE TABLE dbo.DimCapacitacion;

-- Activar otra vez
PRINT '[INFO] Vaciando tablas del DWH (Orden de Integridad Referencial)...';

-- 1. Primero vaciamos las tablas de HECHOS (las que tienen las FK)
DELETE FROM dbo.FactCapacitaciones;
DELETE FROM dbo.FactEvaluaciones;
DELETE FROM dbo.FactAusencias;

-- 2. Ahora sí podemos vaciar las DIMENSIONES (las tablas PADRE)
DELETE FROM dbo.DimCapacitacion;
DELETE FROM dbo.DimTipoAusencia;
DELETE FROM dbo.DimEmpleado;
DELETE FROM dbo.DimPuesto;
DELETE FROM dbo.DimDepartamento;
DELETE FROM dbo.DimOficina;
DELETE FROM dbo.DimFecha;

-- 3. Opcional: Si quieres que los IDs empiecen de nuevo en 1
DBCC CHECKIDENT ('dbo.DimEmpleado', RESEED, 0);
-- Repetir para las demás dimensiones si es necesario...

PRINT '[OK] Todas las tablas del DWH vaciadas sin errores de FK.';
GO

 
-- ============================================================================
-- 4.2  CARGAR DimFecha  (generación programática — no viene del OLTP)
-- ============================================================================
-- La dimensión tiempo no se extrae de ninguna tabla del OLTP; se genera
-- por código cubriendo el rango de fechas de los datos transaccionales.
--
-- Técnica: CTE recursiva que genera una fila por día partiendo de la fecha
-- base y sumando 1 día hasta alcanzar la fecha fin.
-- MAXRECURSION 0: desactiva el límite de 100 niveles de recursión que SQL
-- Server aplica por defecto. Necesario para 1096 días (3 años completos).
--
-- Formato YYYYMMDD para FechaKey:
--   CONVERT(VARCHAR(8), fecha, 112) → '20230115'
--   CAST(... AS INT)                → 20230115 (entero que se ordena igual que la fecha)
-- ============================================================================
PRINT '[INFO] Generando DimFecha 2023-2025 (1096 días)...';
DECLARE @FIni DATE = '2023-01-01';
DECLARE @FFin DATE = '2025-12-31';
 
;WITH Cal AS (
    SELECT @FIni AS f
    UNION ALL
    SELECT DATEADD(DAY,1,f) FROM Cal WHERE f < @FFin  -- Condición de parada
)
INSERT INTO dbo.DimFecha
    (FechaKey,FechaCompleta,Anio,Semestre,Trimestre,Mes,NombreMes,Dia,NombreDiaSemana)
SELECT
    CAST(CONVERT(VARCHAR(8),f,112) AS INT),  -- YYYYMMDD como entero
    f,
    YEAR(f),
    CASE WHEN MONTH(f)<=6 THEN 1 ELSE 2 END,-- Semestre
    DATEPART(QUARTER,f),
    MONTH(f),
    DATENAME(MONTH,f),
    DAY(f),
    DATENAME(WEEKDAY,f)
FROM Cal
OPTION (MAXRECURSION 0);     -- Sin límite de recursión
PRINT '[OK] DimFecha cargada: '+CAST(@@ROWCOUNT AS VARCHAR)+' días.';
GO
 
-- ============================================================================
-- 4.3  CARGAR DIMENSIONES MAESTRAS (extracción directa del OLTP)
-- ============================================================================
-- Para cada dimensión: SELECT del OLTP + renombrar la PK como *ID_OLTP.
-- El IDENTITY de la dimensión en el DWH genera la clave subrogatada (SK)
-- automáticamente. No es necesario calcularla manualmente.
-- ============================================================================
PRINT '[INFO] Cargando DimOficina...';
INSERT INTO dbo.DimOficina (OficinaID_OLTP,CodigoOficina,Ciudad,Pais,Region,CodigoPostal)
SELECT OficinaID,CodigoOficina,Ciudad,Pais,Region,CodigoPostal
FROM RRHH_OLTP.dbo.Oficinas;
PRINT '[OK] DimOficina: '+CAST(@@ROWCOUNT AS VARCHAR)+' registros.';
GO
 
PRINT '[INFO] Cargando DimDepartamento...';
INSERT INTO dbo.DimDepartamento (DepartamentoID_OLTP,NombreDepartamento,Descripcion)
SELECT DepartamentoID,NombreDepartamento,Descripcion
FROM RRHH_OLTP.dbo.Departamentos;
PRINT '[OK] DimDepartamento: '+CAST(@@ROWCOUNT AS VARCHAR)+' registros.';
GO
 
PRINT '[INFO] Cargando DimPuesto...';
INSERT INTO dbo.DimPuesto (PuestoID_OLTP,NombrePuesto,NivelSalarial,SalarioMinimo,SalarioMaximo)
SELECT PuestoID,NombrePuesto,NivelSalarial,SalarioMinimo,SalarioMaximo
FROM RRHH_OLTP.dbo.Puestos;
PRINT '[OK] DimPuesto: '+CAST(@@ROWCOUNT AS VARCHAR)+' registros.';
GO
 
-- ============================================================================
-- 4.4  CARGAR DimEmpleado  (con transformaciones)
-- ============================================================================
-- Transformaciones aplicadas durante el ETL:
--   1. NombreCompleto: Nombre + ' ' + Apellidos concatenados en un campo
--   2. Edad: DATEDIFF(YEAR) simple sobreestima la edad si aún no cumpleaños.
--      Corrección: restar 1 si la fecha de cumpleaños de este año aún no pasó.
--   3. AntiguedadAnios: años completos desde FechaContratacion hasta hoy.
-- ============================================================================
PRINT '[INFO] Cargando DimEmpleado con transformaciones...';
INSERT INTO dbo.DimEmpleado
    (EmpleadoID_OLTP,Identificacion,NombreCompleto,Genero,EstadoCivil,
     Edad,FechaContratacion,AntiguedadAnios,Activo,
     DepartamentoID_OLTP,PuestoID_OLTP,OficinaID_OLTP,JefeID_OLTP)
SELECT
    e.EmpleadoID,
    e.Identificacion,
    CONCAT(e.Nombre,' ',e.Apellidos) AS NombreCompleto,  -- Transformación: concatenar
    e.Genero, e.EstadoCivil,
    -- Cálculo robusto de edad: evita el error del DATEDIFF simple
    DATEDIFF(YEAR,e.FechaNacimiento,GETDATE())
        - CASE WHEN DATEADD(YEAR,DATEDIFF(YEAR,e.FechaNacimiento,GETDATE()),e.FechaNacimiento)
                    > GETDATE() THEN 1 ELSE 0 END AS Edad,
    e.FechaContratacion,
    DATEDIFF(YEAR,e.FechaContratacion,GETDATE()) AS AntiguedadAnios,
    e.Activo,
    e.DepartamentoID, e.PuestoID, e.OficinaID, e.JefeID
FROM RRHH_OLTP.dbo.Empleados e;
PRINT '[OK] DimEmpleado: '+CAST(@@ROWCOUNT AS VARCHAR)+' registros.';
GO
 
PRINT '[INFO] Cargando DimTipoAusencia...';
-- Se extrae de los valores DISTINCT reales en la tabla fuente
INSERT INTO dbo.DimTipoAusencia (TipoAusencia)
SELECT DISTINCT TipoAusencia FROM RRHH_OLTP.dbo.Ausencias ORDER BY TipoAusencia;
PRINT '[OK] DimTipoAusencia: '+CAST(@@ROWCOUNT AS VARCHAR)+' registros.';
GO
 
PRINT '[INFO] Cargando DimCapacitacion...';
INSERT INTO dbo.DimCapacitacion (CapacitacionID_OLTP,NombreCapacitacion,Proveedor,Costo,DuracionDias)
SELECT CapacitacionID,NombreCapacitacion,Proveedor,Costo,DuracionDias
FROM RRHH_OLTP.dbo.Capacitaciones;
PRINT '[OK] DimCapacitacion: '+CAST(@@ROWCOUNT AS VARCHAR)+' registros.';
GO
 
-- ============================================================================
-- 4.5  CARGAR FactAusencias  (resolución de claves subrogatadas)
-- ============================================================================
-- Para cada ausencia del OLTP debemos RESOLVER las SK de las 5 dimensiones:
--
--   FechaKey      → convertir FechaInicio a YYYYMMDD (mismo formato de DimFecha)
--   EmpleadoKey   → JOIN DimEmpleado WHERE EmpleadoID_OLTP = e.EmpleadoID
--   OficinaKey    → JOIN DimOficina   WHERE OficinaID_OLTP = e.OficinaID
--   DepartKey     → JOIN DimDepto     WHERE DepartID_OLTP  = e.DepartamentoID
--   TipoKey       → JOIN DimTipo      WHERE TipoAusencia   = a.TipoAusencia
--
-- Este proceso de resolución de SK es el CORAZÓN del ETL dimensional.
-- Si cualquier JOIN falla (fila sin coincidencia), el registro se pierde.
-- Las validaciones del Script 05 confirman que no se perdió ninguno.
-- ============================================================================
PRINT '[INFO] Cargando FactAusencias...';
INSERT INTO dbo.FactAusencias
    (FechaKey,EmpleadoKey,OficinaKey,DepartamentoKey,TipoAusenciaKey,
     CantidadAusencias,DiasAusencia,JustificadaFlag)
SELECT
    CAST(CONVERT(VARCHAR(8),a.FechaInicio,112) AS INT),  -- Resolución FechaKey
    de.EmpleadoKey,                                       -- Resolución SK empleado
    dof.OficinaKey,                                       -- Resolución SK oficina
    dd.DepartamentoKey,                                   -- Resolución SK departamento
    dta.TipoAusenciaKey,                                  -- Resolución SK tipo
    1,                 -- CantidadAusencias siempre 1 (granularidad = evento individual)
    a.DiasTotales,
    a.Justificada
FROM RRHH_OLTP.dbo.Ausencias        a
JOIN RRHH_OLTP.dbo.Empleados        e   ON a.EmpleadoID      = e.EmpleadoID
JOIN dbo.DimEmpleado               de   ON de.EmpleadoID_OLTP = e.EmpleadoID
JOIN dbo.DimOficina               dof   ON dof.OficinaID_OLTP = e.OficinaID
JOIN dbo.DimDepartamento           dd   ON dd.DepartamentoID_OLTP = e.DepartamentoID
JOIN dbo.DimTipoAusencia          dta   ON dta.TipoAusencia   = a.TipoAusencia;
PRINT '[OK] FactAusencias: '+CAST(@@ROWCOUNT AS VARCHAR)+' registros.';
GO
 
-- ============================================================================
-- 4.6  CARGAR FactEvaluaciones  (doble JOIN a DimEmpleado)
-- ============================================================================
-- Punto técnico especial: necesitamos DOS JOINs a DimEmpleado con alias distintos:
--   de  → resuelve el SK del empleado EVALUADO (EmpleadoKey)
--   dev → resuelve el SK del empleado EVALUADOR (EvaluadorEmpleadoKey)
-- Ambos referencian la misma dimensión, pero con diferentes NK del OLTP.
-- ============================================================================
PRINT '[INFO] Cargando FactEvaluaciones...';
INSERT INTO dbo.FactEvaluaciones
    (FechaKey,EmpleadoKey,EvaluadorEmpleadoKey,OficinaKey,DepartamentoKey,PuestoKey,
     Calificacion,CantidadEvaluaciones)
SELECT
    CAST(CONVERT(VARCHAR(8),ev.FechaEvaluacion,112) AS INT),
    de.EmpleadoKey,               -- SK del empleado evaluado
    dev.EmpleadoKey,              -- SK del evaluador (segundo alias de DimEmpleado)
    dof.OficinaKey,
    dd.DepartamentoKey,
    dp.PuestoKey,
    ev.Calificacion,
    1
FROM RRHH_OLTP.dbo.EvaluacionesDesempeno  ev
JOIN RRHH_OLTP.dbo.Empleados              e   ON ev.EmpleadoEvaluadoID = e.EmpleadoID
JOIN dbo.DimEmpleado                     de   ON de.EmpleadoID_OLTP   = e.EmpleadoID
JOIN dbo.DimEmpleado                    dev   ON dev.EmpleadoID_OLTP  = ev.EvaluadorID
JOIN dbo.DimOficina                     dof   ON dof.OficinaID_OLTP   = e.OficinaID
JOIN dbo.DimDepartamento                 dd   ON dd.DepartamentoID_OLTP = e.DepartamentoID
JOIN dbo.DimPuesto                       dp   ON dp.PuestoID_OLTP      = e.PuestoID;
PRINT '[OK] FactEvaluaciones: '+CAST(@@ROWCOUNT AS VARCHAR)+' registros.';
GO
 
-- ============================================================================
-- 4.7  CARGAR FactCapacitaciones  (manejo de fechas NULL)
-- ============================================================================
-- Transformación especial en FechaKey:
--   Si el curso está 'En Curso', FechaCompletado = NULL.
--   No podemos dejar FechaKey sin valor (el FK a DimFecha requiere valor).
--   Solución: ISNULL(ec.FechaCompletado, c.FechaInicio) — si no hay fecha
--   de completado, usamos la fecha de inicio de la capacitación como referencia.
-- ============================================================================
PRINT '[INFO] Cargando FactCapacitaciones...';
INSERT INTO dbo.FactCapacitaciones
    (FechaKey,EmpleadoKey,CapacitacionKey,OficinaKey,DepartamentoKey,PuestoKey,
     Estado,CalificacionObtenida,CantidadAsignaciones,CostoCapacitacion)
SELECT
    CAST(CONVERT(VARCHAR(8),ISNULL(ec.FechaCompletado,c.FechaInicio),112) AS INT),
    de.EmpleadoKey,
    dc.CapacitacionKey,
    dof.OficinaKey,
    dd.DepartamentoKey,
    dp.PuestoKey,
    ec.Estado,
    ec.CalificacionObtenida,
    1,
    c.Costo
FROM RRHH_OLTP.dbo.EmpleadosCapacitaciones  ec
JOIN RRHH_OLTP.dbo.Empleados                 e  ON ec.EmpleadoID    = e.EmpleadoID
JOIN RRHH_OLTP.dbo.Capacitaciones            c  ON ec.CapacitacionID= c.CapacitacionID
JOIN dbo.DimEmpleado                        de  ON de.EmpleadoID_OLTP    = e.EmpleadoID
JOIN dbo.DimCapacitacion                    dc  ON dc.CapacitacionID_OLTP= c.CapacitacionID
JOIN dbo.DimOficina                        dof  ON dof.OficinaID_OLTP    = e.OficinaID
JOIN dbo.DimDepartamento                    dd  ON dd.DepartamentoID_OLTP = e.DepartamentoID
JOIN dbo.DimPuesto                          dp  ON dp.PuestoID_OLTP      = e.PuestoID;
PRINT '[OK] FactCapacitaciones: '+CAST(@@ROWCOUNT AS VARCHAR)+' registros.';
GO
 
-- ============================================================================
-- ✅ VERIFICACIÓN SCRIPT 04
--La tabla de resumen debe mostrar todos los conteos correctos del DWH.
--    DimFecha=1096, DimOficina=5, DimDepartamento=5, DimPuesto=10,
--    DimEmpleado=50, DimTipoAusencia=4, DimCapacitacion=10,
--    FactAusencias=100, FactEvaluaciones=80, FactCapacitaciones=60
-- ============================================================================
SELECT 'DimFecha'          AS Tabla,'Dimensión' AS Tipo,COUNT(*) AS Registros FROM dbo.DimFecha          UNION ALL
SELECT 'DimOficina',               'Dimensión',          COUNT(*)              FROM dbo.DimOficina         UNION ALL
SELECT 'DimDepartamento',          'Dimensión',          COUNT(*)              FROM dbo.DimDepartamento    UNION ALL
SELECT 'DimPuesto',                'Dimensión',          COUNT(*)              FROM dbo.DimPuesto          UNION ALL
SELECT 'DimEmpleado',              'Dimensión',          COUNT(*)              FROM dbo.DimEmpleado        UNION ALL
SELECT 'DimTipoAusencia',          'Dimensión',          COUNT(*)              FROM dbo.DimTipoAusencia    UNION ALL
SELECT 'DimCapacitacion',          'Dimensión',          COUNT(*)              FROM dbo.DimCapacitacion    UNION ALL
SELECT 'FactAusencias',            'Hecho',              COUNT(*)              FROM dbo.FactAusencias      UNION ALL
SELECT 'FactEvaluaciones',         'Hecho',              COUNT(*)              FROM dbo.FactEvaluaciones   UNION ALL
SELECT 'FactCapacitaciones',       'Hecho',              COUNT(*)              FROM dbo.FactCapacitaciones;
GO
PRINT '=== SCRIPT 04 COMPLETADO: ETL ejecutado. DWH RRHH_DW cargado. ===';