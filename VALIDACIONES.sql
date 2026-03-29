/* ╔══════════════════════════════════════════════════════════════════════════╗
   ║   SCRIPT 05 — VALIDACIONES DE CALIDAD DE DATOS (14 VALIDACIONES)         ║
   ║                                                                          ║
   ║   QUÉ HACE: Ejecuta 14 pruebas automatizadas sobre el DWH y genera       ║
   ║             un reporte PASS/FAIL con resumen de % de éxito.              ║
   ║                                                                          ║
   ╚══════════════════════════════════════════════════════════════════════════╝ */
 
USE RRHH_DW;
GO
 
-- Tabla temporal para acumular resultados de las 14 validaciones
IF OBJECT_ID('tempdb..#Val') IS NOT NULL DROP TABLE #Val;
CREATE TABLE #Val (
    Num       INT         NOT NULL,
    Categoria VARCHAR(40) NOT NULL,
    Nombre    VARCHAR(200)NOT NULL,
    Estado    VARCHAR(6)  NOT NULL,   -- 'PASS' o 'FAIL'
    Detalle   VARCHAR(400)NOT NULL,
    Problemas INT         NOT NULL DEFAULT 0
);
GO
 
-- ── V1: Integridad referencial FactAusencias ──────────────────────────────────
-- Verifica que las 5 FK (Fecha, Empleado, Oficina, Departamento, TipoAusencia)
DECLARE @v INT;
SELECT @v=COUNT(*) FROM dbo.FactAusencias
WHERE FechaKey NOT IN(SELECT FechaKey FROM dbo.DimFecha)
   OR EmpleadoKey NOT IN(SELECT EmpleadoKey FROM dbo.DimEmpleado)
   OR OficinaKey NOT IN(SELECT OficinaKey FROM dbo.DimOficina)
   OR DepartamentoKey NOT IN(SELECT DepartamentoKey FROM dbo.DimDepartamento)
   OR TipoAusenciaKey NOT IN(SELECT TipoAusenciaKey FROM dbo.DimTipoAusencia);
INSERT INTO #Val VALUES(1,'Integridad Ref.','FK válidas en FactAusencias (5 dimensiones)',
    IIF(@v=0,'PASS','FAIL'),
    IIF(@v=0,'Todas las FK de FactAusencias son válidas.',CONCAT(@v,' registros con FK inválida.')),@v);
GO
 
-- ── V2: Integridad referencial FactEvaluaciones ───────────────────────────────
-- Punto especial: incluye DOS FK a DimEmpleado (EmpleadoKey y EvaluadorEmpleadoKey).
DECLARE @v INT;
SELECT @v=COUNT(*) FROM dbo.FactEvaluaciones
WHERE FechaKey NOT IN(SELECT FechaKey FROM dbo.DimFecha)
   OR EmpleadoKey NOT IN(SELECT EmpleadoKey FROM dbo.DimEmpleado)
   OR EvaluadorEmpleadoKey NOT IN(SELECT EmpleadoKey FROM dbo.DimEmpleado)
   OR OficinaKey NOT IN(SELECT OficinaKey FROM dbo.DimOficina)
   OR DepartamentoKey NOT IN(SELECT DepartamentoKey FROM dbo.DimDepartamento)
   OR PuestoKey NOT IN(SELECT PuestoKey FROM dbo.DimPuesto);
INSERT INTO #Val VALUES(2,'Integridad Ref.','FK válidas en FactEvaluaciones (doble ref. a DimEmpleado)',
    IIF(@v=0,'PASS','FAIL'),
    IIF(@v=0,'Todas las FK de FactEvaluaciones son válidas.',CONCAT(@v,' registros con FK inválida.')),@v);
GO
 
-- ── V3: Integridad referencial FactCapacitaciones ────────────────────────────
DECLARE @v INT;
SELECT @v=COUNT(*) FROM dbo.FactCapacitaciones
WHERE FechaKey NOT IN(SELECT FechaKey FROM dbo.DimFecha)
   OR EmpleadoKey NOT IN(SELECT EmpleadoKey FROM dbo.DimEmpleado)
   OR CapacitacionKey NOT IN(SELECT CapacitacionKey FROM dbo.DimCapacitacion)
   OR OficinaKey NOT IN(SELECT OficinaKey FROM dbo.DimOficina)
   OR DepartamentoKey NOT IN(SELECT DepartamentoKey FROM dbo.DimDepartamento)
   OR PuestoKey NOT IN(SELECT PuestoKey FROM dbo.DimPuesto);
INSERT INTO #Val VALUES(3,'Integridad Ref.','FK válidas en FactCapacitaciones (6 dimensiones)',
    IIF(@v=0,'PASS','FAIL'),
    IIF(@v=0,'Todas las FK de FactCapacitaciones son válidas.',CONCAT(@v,' con FK inválida.')),@v);
GO
 
-- ── V4: Completitud — campos críticos no nulos en DimEmpleado ────────────────
-- NombreCompleto, Genero, Identificacion y FechaContratacion son obligatorios
-- para cualquier análisis de RR.HH. Un NULL en estos campos bloquea reportes.
DECLARE @v INT;
SELECT @v=COUNT(*) FROM dbo.DimEmpleado
WHERE NombreCompleto IS NULL OR Genero IS NULL
   OR Identificacion IS NULL OR FechaContratacion IS NULL;
INSERT INTO #Val VALUES(4,'Completitud','Campos críticos sin NULL en DimEmpleado',
    IIF(@v=0,'PASS','FAIL'),
    IIF(@v=0,'Todos los empleados tienen campos críticos completos.',CONCAT(@v,' con campos nulos.')),@v);
GO
 
-- ── V5: Rango de calificaciones (1.0 – 5.0) ──────────────────────────────────
-- Un valor fuera de rango distorsiona los KPIs de desempeño (promedios, rankings).
DECLARE @v INT;
SELECT @v=COUNT(*) FROM dbo.FactEvaluaciones WHERE Calificacion<1.0 OR Calificacion>5.0;
INSERT INTO #Val VALUES(5,'Rango/Dominio','Calificaciones de desempeño en rango 1.0-5.0',
    IIF(@v=0,'PASS','FAIL'),
    IIF(@v=0,'Todas las calificaciones están en rango válido.',CONCAT(@v,' fuera de rango.')),@v);
GO
 
-- ── V6: Días de ausencia siempre positivos ───────────────────────────────────
DECLARE @v INT;
SELECT @v=COUNT(*) FROM dbo.FactAusencias WHERE DiasAusencia<=0;
INSERT INTO #Val VALUES(6,'Rango/Dominio','Días de ausencia positivos (DiasAusencia > 0)',
    IIF(@v=0,'PASS','FAIL'),
    IIF(@v=0,'Todos los registros tienen DiasAusencia >= 1.',CONCAT(@v,' con días inválidos.')),@v);
GO
 
-- ── V7: Sin duplicados en DimEmpleado ────────────────────────────────────────
-- Si el ETL se ejecuta sin TRUNCATE previo, se generan duplicados que
-- multiplican artificialmente los resultados de las consultas analíticas.
DECLARE @v INT;
SELECT @v=COUNT(*) FROM(
    SELECT EmpleadoID_OLTP FROM dbo.DimEmpleado GROUP BY EmpleadoID_OLTP HAVING COUNT(*)>1
) d;
INSERT INTO #Val VALUES(7,'Unicidad','Sin duplicados en DimEmpleado por EmpleadoID_OLTP',
    IIF(@v=0,'PASS','FAIL'),
    IIF(@v=0,'DimEmpleado no tiene EmpleadoID_OLTP duplicados.',CONCAT(@v,' ID duplicados.')),@v);
GO
 
-- ── V8: Concordancia totales Ausencias OLTP vs DWH ───────────────────────────
DECLARE @a INT,@b INT;
SELECT @a=COUNT(*) FROM RRHH_OLTP.dbo.Ausencias;
SELECT @b=COUNT(*) FROM dbo.FactAusencias;
INSERT INTO #Val VALUES(8,'Concordancia OLTP-DWH','Total ausencias igual en OLTP y DWH',
    IIF(@a=@b,'PASS','FAIL'),
    CONCAT('OLTP=',@a,' | DWH=',@b,' | Diferencia=',ABS(@a-@b)),ABS(@a-@b));
GO
 
-- ── V9: Concordancia totales Evaluaciones OLTP vs DWH ────────────────────────
DECLARE @a INT,@b INT;
SELECT @a=COUNT(*) FROM RRHH_OLTP.dbo.EvaluacionesDesempeno;
SELECT @b=COUNT(*) FROM dbo.FactEvaluaciones;
INSERT INTO #Val VALUES(9,'Concordancia OLTP-DWH','Total evaluaciones igual en OLTP y DWH',
    IIF(@a=@b,'PASS','FAIL'),
    CONCAT('OLTP=',@a,' | DWH=',@b,' | Diferencia=',ABS(@a-@b)),ABS(@a-@b));
GO
 
-- ── V10: Empleados activos con departamento asignado ─────────────────────────
-- Un empleado Activo=1 sin DepartamentoID_OLTP es un error de integridad de negocio.
DECLARE @v INT;
SELECT @v=COUNT(*) FROM dbo.DimEmpleado WHERE Activo=1 AND DepartamentoID_OLTP IS NULL;
INSERT INTO #Val VALUES(10,'Coherencia Negocio','Empleados activos con departamento asignado',
    IIF(@v=0,'PASS','FAIL'),
    IIF(@v=0,'Todos los activos tienen departamento.',CONCAT(@v,' activos sin departamento.')),@v);
GO
 
-- ── V11: Costos de capacitación no negativos ─────────────────────────────────
DECLARE @v INT;
SELECT @v=COUNT(*) FROM dbo.FactCapacitaciones WHERE CostoCapacitacion<0;
INSERT INTO #Val VALUES(11,'Rango/Dominio','Costos de capacitación >= 0',
    IIF(@v=0,'PASS','FAIL'),
    IIF(@v=0,'Ningún costo negativo en FactCapacitaciones.',CONCAT(@v,' con costo negativo.')),@v);
GO
 
-- ── V12: DimFecha cubre el rango mínimo requerido 2023-2025 ──────────────────
-- Si el rango es insuficiente, los registros de hechos fuera de rango no
-- encontrarán FechaKey válida y fallarán al momento del ETL.
DECLARE @mn DATE,@mx DATE;
SELECT @mn=MIN(FechaCompleta),@mx=MAX(FechaCompleta) FROM dbo.DimFecha;
INSERT INTO #Val VALUES(12,'Coherencia Negocio','DimFecha cubre rango 2023-01-01 a 2025-12-31',
    IIF(@mn<='2023-01-01' AND @mx>='2025-12-31','PASS','FAIL'),
    CONCAT('Rango real: ',CAST(@mn AS VARCHAR(12)),' a ',CAST(@mx AS VARCHAR(12))),0);
GO
 
-- ── V13: Antigüedad de empleados coherente (>= 0) ────────────────────────────
-- Un valor negativo indica FechaContratacion en el futuro: error en datos fuente.
DECLARE @v INT;
SELECT @v=COUNT(*) FROM dbo.DimEmpleado WHERE AntiguedadAnios<0;
INSERT INTO #Val VALUES(13,'Rango/Dominio','AntiguedadAnios >= 0 en todos los empleados',
    IIF(@v=0,'PASS','FAIL'),
    IIF(@v=0,'Todos los empleados tienen antigüedad válida.',CONCAT(@v,' con antigüedad negativa.')),@v);
GO
 
-- ── V14: Concordancia totales Capacitaciones OLTP vs DWH ─────────────────────
DECLARE @a INT,@b INT;
SELECT @a=COUNT(*) FROM RRHH_OLTP.dbo.EmpleadosCapacitaciones;
SELECT @b=COUNT(*) FROM dbo.FactCapacitaciones;
INSERT INTO #Val VALUES(14,'Concordancia OLTP-DWH','Total capacitaciones igual en OLTP y DWH',
    IIF(@a=@b,'PASS','FAIL'),
    CONCAT('OLTP=',@a,' | DWH=',@b,' | Diferencia=',ABS(@a-@b)),ABS(@a-@b));
GO
 
-- ============================================================================
--  REPORTE FINAL DE VALIDACIONES
--    Selecciona AMBAS tablas de resultados (detalle + resumen).
--    El porcentaje de éxito debe ser 100.0% si el ETL funcionó correctamente.
-- ============================================================================
-- Tabla detallada: todas las validaciones
SELECT Num AS[#],Categoria AS[Categoría],Nombre AS[Validación],
       Estado AS[Estado],Detalle AS[Detalle],Problemas AS[Problemas]
FROM #Val ORDER BY Num;
 
-- Resumen ejecutivo
SELECT
    COUNT(*)                                         AS [Total Validaciones],
    SUM(CASE WHEN Estado='PASS' THEN 1 ELSE 0 END)  AS [PASS ✓],
    SUM(CASE WHEN Estado='FAIL' THEN 1 ELSE 0 END)  AS [FAIL ✗],
    CAST(SUM(CASE WHEN Estado='PASS' THEN 1.0 ELSE 0 END)/COUNT(*)*100 AS DECIMAL(5,1)) AS [% Éxito]
FROM #Val;
 
DROP TABLE #Val;
GO
PRINT '=== SCRIPT 05 COMPLETADO: 14 validaciones de calidad ejecutadas. ===';
 