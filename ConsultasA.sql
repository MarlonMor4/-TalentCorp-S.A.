/* ╔══════════════════════════════════════════════════════════════════════════╗
   ║                                                                          ║
   ║   SCRIPT 06 — CONSULTAS ANALÍTICAS MULTIDIMENSIONALES (15 CONSULTAS)     ║
   ║                                                                          ║
   ║   QUÉ HACE: Ejecuta 15 consultas estratégicas sobre el DWH que           ║
   ║             generan KPIs e inteligencia accionable para RR.HH.           ║
   ║                                                                          ║
   ╚══════════════════════════════════════════════════════════════════════════╝ */
 
USE RRHH_DW;
GO
 
-- ============================================================================
-- CONSULTA 01: Ausentismo por Departamento y Tipo de Ausencia
-- ============================================================================
-- Análisis : Desglosa eventos de ausentismo por área y categoría.
-- Valor    : Identifica qué departamentos y qué tipos de ausencia generan
--            más días perdidos para priorizar políticas de bienestar.
-- KPIs     : CantidadEventos, TotalDias, PromedioDias, %Justificado.
-- ============================================================================
PRINT '─── CONSULTA 01: Ausentismo por Departamento y Tipo ───';
SELECT
    dd.NombreDepartamento,
    dta.TipoAusencia,
    COUNT(fa.FactAusenciaKey)                                            AS CantidadEventos,
    SUM(fa.DiasAusencia)                                                 AS TotalDiasAusentes,
    CAST(AVG(CAST(fa.DiasAusencia AS DECIMAL(10,2)))AS DECIMAL(6,2))     AS PromedioDiasPorEvento,
    SUM(CASE WHEN fa.JustificadaFlag=1 THEN 1 ELSE 0 END)               AS Justificadas,
    SUM(CASE WHEN fa.JustificadaFlag=0 THEN 1 ELSE 0 END)               AS NoJustificadas,
    CAST(SUM(CASE WHEN fa.JustificadaFlag=1 THEN 1.0 ELSE 0 END)
         /NULLIF(COUNT(*),0)*100 AS DECIMAL(5,1))                        AS PctJustificado
FROM dbo.FactAusencias fa
JOIN dbo.DimDepartamento dd  ON fa.DepartamentoKey = dd.DepartamentoKey
JOIN dbo.DimTipoAusencia dta ON fa.TipoAusenciaKey = dta.TipoAusenciaKey
GROUP BY dd.NombreDepartamento, dta.TipoAusencia
ORDER BY dd.NombreDepartamento, TotalDiasAusentes DESC;
GO
 
-- ============================================================================
-- CONSULTA 02: Evaluaciones de Desempeño Comparadas por Departamento
-- ============================================================================
-- Análisis : Promedio de calificaciones, dispersión estadística y distribución
--            por categoría (Excelente/Bueno/Regular/Deficiente).
-- Valor    : Permite identificar departamentos con desempeño bajo o alta
--            variabilidad, para focalizar planes de coaching y mejora.
-- KPIs     : PromedioCalificacion, Desviación, distribución por categoría.
-- ============================================================================
PRINT '─── CONSULTA 02: Evaluaciones por Departamento ───';
SELECT
    dd.NombreDepartamento,
    COUNT(fe.FactEvaluacionKey)                       AS TotalEvaluaciones,
    CAST(AVG(fe.Calificacion) AS DECIMAL(3,1))         AS PromedioCalificacion,
    CAST(MIN(fe.Calificacion) AS DECIMAL(3,1))         AS Minima,
    CAST(MAX(fe.Calificacion) AS DECIMAL(3,1))         AS Maxima,
    CAST(STDEV(fe.Calificacion) AS DECIMAL(5,3))       AS DesviacionEstandar,
    SUM(CASE WHEN fe.Calificacion>=4.5 THEN 1 ELSE 0 END)              AS Excelente,
    SUM(CASE WHEN fe.Calificacion BETWEEN 3.5 AND 4.4 THEN 1 ELSE 0 END) AS Bueno,
    SUM(CASE WHEN fe.Calificacion BETWEEN 2.5 AND 3.4 THEN 1 ELSE 0 END) AS Regular,
    SUM(CASE WHEN fe.Calificacion<2.5 THEN 1 ELSE 0 END)               AS Deficiente
FROM dbo.FactEvaluaciones fe
JOIN dbo.DimDepartamento dd ON fe.DepartamentoKey = dd.DepartamentoKey
GROUP BY dd.NombreDepartamento
ORDER BY PromedioCalificacion DESC;
GO
 
-- ============================================================================
-- CONSULTA 03: Tendencia Mensual de Ausencias (Estacionalidad)
-- ============================================================================
-- Análisis : Evolución del ausentismo mes a mes. Detecta picos estacionales.
-- Valor    : Anticipa meses de alta ausencia para planificar cobertura de
--            personal y evitar brechas operativas en períodos críticos.
-- ============================================================================
PRINT '─── CONSULTA 03: Tendencia Mensual de Ausencias ───';
SELECT
    df.Anio, df.Mes, df.NombreMes,
    COUNT(fa.FactAusenciaKey)                                        AS CantidadEventos,
    SUM(fa.DiasAusencia)                                             AS TotalDiasAusentes,
    COUNT(DISTINCT fa.EmpleadoKey)                                   AS EmpleadosAfectados,
    CAST(SUM(fa.DiasAusencia)*1.0/NULLIF(COUNT(DISTINCT fa.EmpleadoKey),0)
         AS DECIMAL(6,2))                                            AS DiasPromPorEmpleado
FROM dbo.FactAusencias fa
JOIN dbo.DimFecha df ON fa.FechaKey = df.FechaKey
GROUP BY df.Anio, df.Mes, df.NombreMes
ORDER BY df.Anio, df.Mes;
GO
 
-- ============================================================================
-- CONSULTA 04: Top 10 Empleados con Mayor Ausentismo
-- ============================================================================
-- Análisis : Identifica los colaboradores con mayor impacto en ausencias.
-- Valor    : Base para entrevistas de seguimiento y planes de acción de RR.HH.
--            Alto % no justificado = señal de desmotivación o conflicto laboral.
-- ============================================================================
PRINT '─── CONSULTA 04: Top 10 Empleados con Mayor Ausentismo ───';
SELECT TOP 10
    de.NombreCompleto,
    dd.NombreDepartamento,
    dof.Ciudad                                                              AS Oficina,
    COUNT(fa.FactAusenciaKey)                                               AS CantidadEventos,
    SUM(fa.DiasAusencia)                                                    AS TotalDiasAusentes,
    SUM(CASE WHEN fa.JustificadaFlag=1 THEN fa.DiasAusencia ELSE 0 END)     AS DiasJustificados,
    SUM(CASE WHEN fa.JustificadaFlag=0 THEN fa.DiasAusencia ELSE 0 END)     AS DiasNoJustificados,
    CAST(SUM(CASE WHEN fa.JustificadaFlag=0 THEN fa.DiasAusencia ELSE 0 END)*100.0
         /NULLIF(SUM(fa.DiasAusencia),0) AS DECIMAL(5,1))                   AS PctNoJustificado
FROM dbo.FactAusencias fa
JOIN dbo.DimEmpleado     de  ON fa.EmpleadoKey     = de.EmpleadoKey
JOIN dbo.DimDepartamento dd  ON fa.DepartamentoKey = dd.DepartamentoKey
JOIN dbo.DimOficina      dof ON fa.OficinaKey      = dof.OficinaKey
GROUP BY de.NombreCompleto, dd.NombreDepartamento, dof.Ciudad
ORDER BY TotalDiasAusentes DESC;
GO
 
-- ============================================================================
-- CONSULTA 05: Capacitaciones por Departamento y Estado
-- ============================================================================
-- Análisis : Inversión en formación y tasa de completitud por área.
-- Valor    : Mide el avance del plan anual de capacitación y detecta
--            departamentos con baja completitud o alta inversión sin resultado.
-- ============================================================================
PRINT '─── CONSULTA 05: Capacitaciones por Departamento ───';
SELECT
    dd.NombreDepartamento,
    fc.Estado,
    COUNT(fc.FactCapacitacionKey)                                    AS Asignaciones,
    COUNT(DISTINCT fc.EmpleadoKey)                                   AS EmpleadosParticipantes,
    SUM(fc.CostoCapacitacion)                                        AS InversionTotal,
    CAST(SUM(fc.CostoCapacitacion)/NULLIF(COUNT(DISTINCT fc.EmpleadoKey),0)
         AS DECIMAL(12,2))                                           AS CostoPorEmpleado,
    CAST(AVG(fc.CalificacionObtenida) AS DECIMAL(5,1))               AS CalificacionPromedio
FROM dbo.FactCapacitaciones fc
JOIN dbo.DimDepartamento dd ON fc.DepartamentoKey = dd.DepartamentoKey
GROUP BY dd.NombreDepartamento, fc.Estado
ORDER BY dd.NombreDepartamento, fc.Estado;
GO
 
-- ============================================================================
-- CONSULTA 06: Distribución de Antigüedad del Personal
-- ============================================================================
-- Análisis : Clasifica empleados activos por tramos de antigüedad.
-- Valor    : Alta concentración en "<1 año" indica rotación elevada.
--            Alta concentración en ">7 años" puede indicar riesgo de retiro
--            masivo o estancamiento en el plan de sucesión.
-- ============================================================================
PRINT '─── CONSULTA 06: Distribución de Antigüedad ───';
SELECT
    dd.NombreDepartamento,
    COUNT(*)                                                          AS TotalActivos,
    SUM(CASE WHEN de.AntiguedadAnios<1 THEN 1 ELSE 0 END)            AS MenosDeUnAnio,
    SUM(CASE WHEN de.AntiguedadAnios BETWEEN 1 AND 3 THEN 1 ELSE 0 END) AS De1a3Anios,
    SUM(CASE WHEN de.AntiguedadAnios BETWEEN 4 AND 7 THEN 1 ELSE 0 END) AS De4a7Anios,
    SUM(CASE WHEN de.AntiguedadAnios>7 THEN 1 ELSE 0 END)            AS MasDe7Anios,
    CAST(AVG(CAST(de.AntiguedadAnios AS DECIMAL(10,2)))AS DECIMAL(5,1)) AS AntiguedadPromedio
FROM dbo.DimEmpleado de
JOIN dbo.DimDepartamento dd ON de.DepartamentoID_OLTP = dd.DepartamentoID_OLTP
WHERE de.Activo=1
GROUP BY dd.NombreDepartamento
ORDER BY AntiguedadPromedio DESC;
GO
 
-- ============================================================================
-- CONSULTA 07: KPI — Tasa de Ausentismo por Departamento
-- ============================================================================
-- Análisis : Calcula el KPI de tasa de ausentismo más usado en RR.HH.:
--            % de días laborables perdidos respecto al total disponible.
-- Fórmula  : Tasa = (DíasAusentes / (Empleados × 261 díasHábiles)) × 100
--            261 = promedio días laborables anuales (365 − 104 fines de semana)
-- Umbral   : >5% = CRÍTICO | 3-5% = ELEVADO | <3% = NORMAL
-- 📷 CAPTURA CAP-06: resultado completo de esta consulta
-- ============================================================================
PRINT '─── CONSULTA 07: KPI Tasa de Ausentismo por Departamento ─── [CAP-06]';
SELECT
    dd.NombreDepartamento,
    COUNT(DISTINCT fa.EmpleadoKey)                                    AS TotalEmpleados,
    SUM(fa.DiasAusencia)                                              AS TotalDiasAusentes,
    COUNT(DISTINCT fa.EmpleadoKey)*261                                AS DiasLaborablesDisponibles,
    CAST(SUM(fa.DiasAusencia)*100.0
         /NULLIF(COUNT(DISTINCT fa.EmpleadoKey)*261,0) AS DECIMAL(5,2)) AS TasaAusentismoPct,
    CASE
        WHEN SUM(fa.DiasAusencia)*100.0/NULLIF(COUNT(DISTINCT fa.EmpleadoKey)*261,0)>5
             THEN '🔴 CRÍTICO (> 5%)'
        WHEN SUM(fa.DiasAusencia)*100.0/NULLIF(COUNT(DISTINCT fa.EmpleadoKey)*261,0)>3
             THEN '🟡 ELEVADO (3-5%)'
        ELSE '🟢 NORMAL (< 3%)'
    END AS NivelRiesgo
FROM dbo.FactAusencias fa
JOIN dbo.DimDepartamento dd ON fa.DepartamentoKey = dd.DepartamentoKey
GROUP BY dd.NombreDepartamento
ORDER BY TasaAusentismoPct DESC;
GO
 
-- ============================================================================
-- CONSULTA 08: Inversión en Capacitación por Oficina (Análisis Geográfico)
-- ============================================================================
-- Análisis : Distribución del presupuesto de formación por sede geográfica.
-- Valor    : Detecta brechas de inversión entre sedes y permite comparar
--            el esfuerzo de formación per cápita entre regiones.
-- ============================================================================
PRINT '─── CONSULTA 08: Inversión en Capacitación por Oficina ───';
SELECT
    dof.Ciudad, dof.Pais, dof.Region,
    COUNT(DISTINCT fc.EmpleadoKey)                                   AS EmpleadosCapacitados,
    COUNT(fc.FactCapacitacionKey)                                    AS TotalAsignaciones,
    SUM(fc.CostoCapacitacion)                                        AS InversionTotal,
    CAST(AVG(fc.CostoCapacitacion) AS DECIMAL(12,2))                 AS CostoPromPorAsignacion,
    CAST(SUM(fc.CostoCapacitacion)/NULLIF(COUNT(DISTINCT fc.EmpleadoKey),0)
         AS DECIMAL(12,2))                                           AS InversionPorEmpleado
FROM dbo.FactCapacitaciones fc
JOIN dbo.DimOficina dof ON fc.OficinaKey = dof.OficinaKey
GROUP BY dof.Ciudad, dof.Pais, dof.Region
ORDER BY InversionTotal DESC;
GO
 
-- ============================================================================
-- CONSULTA 09: Análisis Trimestral de Evaluaciones
-- ============================================================================
-- Análisis : Evolución del desempeño organizacional por trimestre.
-- Valor    : Permite ver si las iniciativas de mejora (coaching, cambios
--            estructurales) tienen impacto positivo en los resultados.
-- ============================================================================
PRINT '─── CONSULTA 09: Análisis Trimestral de Evaluaciones ───';
SELECT
    df.Anio, df.Trimestre,
    CONCAT('Q',df.Trimestre,'-',df.Anio)                                  AS Periodo,
    COUNT(fe.FactEvaluacionKey)                                           AS TotalEvaluaciones,
    CAST(AVG(fe.Calificacion) AS DECIMAL(3,1))                             AS PromedioCalificacion,
    SUM(CASE WHEN fe.Calificacion>=4.5 THEN 1 ELSE 0 END)                 AS Excelente,
    SUM(CASE WHEN fe.Calificacion BETWEEN 3.5 AND 4.4 THEN 1 ELSE 0 END)  AS Bueno,
    SUM(CASE WHEN fe.Calificacion BETWEEN 2.5 AND 3.4 THEN 1 ELSE 0 END)  AS Regular,
    SUM(CASE WHEN fe.Calificacion<2.5 THEN 1 ELSE 0 END)                  AS Deficiente
FROM dbo.FactEvaluaciones fe
JOIN dbo.DimFecha df ON fe.FechaKey = df.FechaKey
GROUP BY df.Anio, df.Trimestre
ORDER BY df.Anio, df.Trimestre;
GO
 
-- ============================================================================
-- CONSULTA 10: Diversidad de Género por Departamento (D&I)
-- ============================================================================
-- Análisis : Distribución porcentual de género en cada departamento.
-- Valor    : Indicador clave de Diversidad, Equidad e Inclusión (D&I).
--            Identifica áreas con brechas de género para acciones afirmativas.
-- Técnica  : SUM(...) OVER(PARTITION BY) calcula el total del departamento
--            sin necesidad de subconsulta, directamente en el SELECT.
-- ============================================================================
PRINT '─── CONSULTA 10: Diversidad de Género por Departamento ───';
SELECT
    dd.NombreDepartamento, de.Genero,
    COUNT(*)                                                              AS CantidadEmpleados,
    CAST(COUNT(*)*100.0/SUM(COUNT(*)) OVER(PARTITION BY dd.NombreDepartamento)
         AS DECIMAL(5,1))                                                 AS PctEnDepartamento
FROM dbo.DimEmpleado de
JOIN dbo.DimDepartamento dd ON de.DepartamentoID_OLTP = dd.DepartamentoID_OLTP
WHERE de.Activo=1
GROUP BY dd.NombreDepartamento, de.Genero
ORDER BY dd.NombreDepartamento, CantidadEmpleados DESC;
GO
 
-- ============================================================================
-- CONSULTA 11: Ranking de Desempeño por Departamento (Top 3)
-- ============================================================================
-- Análisis : Clasifica a los empleados dentro de cada departamento según
--            su calificación promedio histórica de desempeño.
-- Valor    : Identifica los mejores colaboradores (retención, sucesión,
--            reconocimiento) y quienes necesitan más apoyo.
-- Técnica  : CTE + RANK() OVER(PARTITION BY departamento ORDER BY calif DESC)
-- 📷 CAPTURA CAP-07: resultado completo de esta consulta
-- ============================================================================
PRINT '─── CONSULTA 11: Top 3 Empleados por Desempeño en cada Departamento ─── [CAP-07]';
WITH Desempeno AS (
    SELECT
        de.NombreCompleto, dd.NombreDepartamento,
        CAST(AVG(fe.Calificacion) AS DECIMAL(3,1)) AS PromedioCalif,
        COUNT(fe.FactEvaluacionKey)                AS TotalEvaluaciones,
        RANK() OVER(PARTITION BY dd.NombreDepartamento ORDER BY AVG(fe.Calificacion) DESC) AS Ranking
    FROM dbo.FactEvaluaciones fe
    JOIN dbo.DimEmpleado     de ON fe.EmpleadoKey     = de.EmpleadoKey
    JOIN dbo.DimDepartamento dd ON fe.DepartamentoKey = dd.DepartamentoKey
    GROUP BY de.NombreCompleto, dd.NombreDepartamento
)
SELECT NombreDepartamento, Ranking, NombreCompleto, PromedioCalif, TotalEvaluaciones
FROM Desempeno
WHERE Ranking<=3
ORDER BY NombreDepartamento, Ranking;
GO
 
-- ============================================================================
-- CONSULTA 12: Capacitaciones por Costo y Calificación Obtenida (ROI)
-- ============================================================================
-- Análisis : Cruza inversión por programa vs calificación promedio obtenida.
-- Valor    : Una capacitación cara con calificación baja tiene bajo ROI.
--            Permite decidir qué programas renovar, reemplazar o escalar.
-- ============================================================================
PRINT '─── CONSULTA 12: ROI de Capacitaciones ───';
SELECT
    dc.NombreCapacitacion, dc.Proveedor, dc.DuracionDias,
    COUNT(fc.FactCapacitacionKey)                                     AS VecesAsignada,
    SUM(fc.CostoCapacitacion)                                         AS InversionTotal,
    CAST(AVG(fc.CalificacionObtenida) AS DECIMAL(5,1))                AS CalifPromedioObtenida,
    CAST(SUM(CASE WHEN fc.Estado='Completada' THEN 1.0 ELSE 0 END)
         /COUNT(*)*100 AS DECIMAL(5,1))                               AS TasaCompletitudPct,
    SUM(CASE WHEN fc.Estado='Completada' THEN 1 ELSE 0 END)           AS Completadas,
    SUM(CASE WHEN fc.Estado='En Curso' THEN 1 ELSE 0 END)             AS EnCurso
FROM dbo.FactCapacitaciones fc
JOIN dbo.DimCapacitacion dc ON fc.CapacitacionKey = dc.CapacitacionKey
GROUP BY dc.NombreCapacitacion, dc.Proveedor, dc.DuracionDias
ORDER BY InversionTotal DESC;
GO
 
-- ============================================================================
-- CONSULTA 13: Detección de Riesgo — Ausentismo No Justificado
-- ============================================================================
-- Análisis : Empleados con mayor cantidad de ausencias injustificadas.
-- Valor    : Base para las entrevistas de seguimiento de RR.HH.
--            Alto % de injustificadas puede indicar desmotivación, conflictos
--            o problemas personales que requieren intervención temprana.
-- ============================================================================
PRINT '─── CONSULTA 13: Detección de Riesgo por Ausentismo Injustificado ───';
SELECT
    de.NombreCompleto, dd.NombreDepartamento, dof.Ciudad AS Oficina,
    SUM(CASE WHEN fa.JustificadaFlag=0 THEN 1 ELSE 0 END)               AS AusenciasNoJust,
    SUM(CASE WHEN fa.JustificadaFlag=0 THEN fa.DiasAusencia ELSE 0 END)  AS DiasNoJust,
    SUM(fa.DiasAusencia)                                                  AS TotalDias,
    CAST(SUM(CASE WHEN fa.JustificadaFlag=0 THEN fa.DiasAusencia ELSE 0 END)*100.0
         /NULLIF(SUM(fa.DiasAusencia),0) AS DECIMAL(5,1))                 AS PctNoJustificado,
    CASE
        WHEN SUM(CASE WHEN fa.JustificadaFlag=0 THEN 1 ELSE 0 END)>=3 THEN '🔴 ALERTA ALTA'
        WHEN SUM(CASE WHEN fa.JustificadaFlag=0 THEN 1 ELSE 0 END)=2  THEN '🟡 ALERTA MEDIA'
        ELSE '🟢 SEGUIMIENTO'
    END AS NivelAlerta
FROM dbo.FactAusencias fa
JOIN dbo.DimEmpleado     de  ON fa.EmpleadoKey     = de.EmpleadoKey
JOIN dbo.DimDepartamento dd  ON fa.DepartamentoKey = dd.DepartamentoKey
JOIN dbo.DimOficina      dof ON fa.OficinaKey      = dof.OficinaKey
GROUP BY de.NombreCompleto, dd.NombreDepartamento, dof.Ciudad
HAVING SUM(CASE WHEN fa.JustificadaFlag=0 THEN 1 ELSE 0 END)>0
ORDER BY AusenciasNoJust DESC, DiasNoJust DESC;
GO
 
-- ============================================================================
-- CONSULTA 14: Dashboard KPIs Anuales de RR.HH.
-- ============================================================================
-- Análisis : Vista ejecutiva anual con los 3 grandes KPIs: ausentismo,
--            desempeño e inversión en formación — en una sola fila por año.
-- Valor    : Diseñada para presentaciones ejecutivas y reuniones de directorio.
--            Muestra la evolución interanual de los indicadores estratégicos.
-- Técnica  : Subconsultas correlacionadas para cruzar 3 tablas de hechos.
-- 📷 CAPTURA CAP-08: resultado completo de esta consulta
-- ============================================================================
PRINT '─── CONSULTA 14: Dashboard KPIs Anuales de RR.HH. ─── [CAP-08]';
SELECT
    df.Anio,
    COUNT(DISTINCT fa.EmpleadoKey)                                    AS EmpleadosConAusencias,
    SUM(fa.DiasAusencia)                                              AS TotalDiasAusentes,
    CAST(AVG(CAST(fa.DiasAusencia AS DECIMAL(10,2)))AS DECIMAL(6,2))  AS DiasPromPorEvento,
    -- Desempeño promedio del año (subconsulta correlacionada por año)
    CAST((SELECT AVG(fe2.Calificacion)
          FROM dbo.FactEvaluaciones fe2
          JOIN dbo.DimFecha df2 ON fe2.FechaKey=df2.FechaKey
          WHERE df2.Anio=df.Anio) AS DECIMAL(3,1))                    AS PromedioDesempeno,
    -- Inversión total en capacitación del año
    (SELECT SUM(fc2.CostoCapacitacion)
     FROM dbo.FactCapacitaciones fc2
     JOIN dbo.DimFecha df3 ON fc2.FechaKey=df3.FechaKey
     WHERE df3.Anio=df.Anio)                                          AS InversionCapacitacion,
    -- Capacitaciones completadas en el año
    (SELECT COUNT(*)
     FROM dbo.FactCapacitaciones fc3
     JOIN dbo.DimFecha df4 ON fc3.FechaKey=df4.FechaKey
     WHERE df4.Anio=df.Anio AND fc3.Estado='Completada')              AS CapacitacionesCompletadas
FROM dbo.FactAusencias fa
JOIN dbo.DimFecha df ON fa.FechaKey=df.FechaKey
GROUP BY df.Anio
ORDER BY df.Anio;
GO
 
-- ============================================================================
-- CONSULTA 15: Resumen Ejecutivo por Oficina (Vista Gerencial Geográfica)
-- ============================================================================
-- Análisis : Consolida los 5 indicadores clave de RR.HH. agrupados por sede.
-- Valor    : El Director de RR.HH. puede comparar simultáneamente TODAS las
--            sedes en headcount, antigüedad, desempeño, ausencias y formación.
--            Identifica cuáles sedes requieren más atención o recursos.
-- ============================================================================
PRINT '─── CONSULTA 15: Resumen Ejecutivo por Oficina ─── [CAP-09]';
SELECT
    dof.Ciudad, dof.Pais, dof.Region,
    COUNT(DISTINCT de.EmpleadoKey)                                    AS HeadcountActivo,
    CAST(AVG(CAST(de.AntiguedadAnios AS DECIMAL(10,2)))AS DECIMAL(5,1)) AS AntiguedadPromedio,
    CAST((SELECT AVG(fe2.Calificacion)
          FROM dbo.FactEvaluaciones fe2
          WHERE fe2.OficinaKey=dof.OficinaKey) AS DECIMAL(3,1))        AS DesempenoPromedio,
    (SELECT SUM(fa2.DiasAusencia)
     FROM dbo.FactAusencias fa2
     WHERE fa2.OficinaKey=dof.OficinaKey)                              AS TotalDiasAusentes,
    (SELECT SUM(fc2.CostoCapacitacion)
     FROM dbo.FactCapacitaciones fc2
     WHERE fc2.OficinaKey=dof.OficinaKey)                              AS InversionCapacitacion,
    CAST((SELECT SUM(CASE WHEN fc3.Estado='Completada' THEN 1.0 ELSE 0 END)
                 /NULLIF(COUNT(*),0)*100
          FROM dbo.FactCapacitaciones fc3
          WHERE fc3.OficinaKey=dof.OficinaKey) AS DECIMAL(5,1))        AS TasaCompletitudCapPct
FROM dbo.DimEmpleado de
JOIN dbo.DimOficina dof ON de.OficinaID_OLTP = dof.OficinaID_OLTP
WHERE de.Activo=1
GROUP BY dof.OficinaKey, dof.Ciudad, dof.Pais, dof.Region
ORDER BY HeadcountActivo DESC;
GO

select *from FactAusencias;
 