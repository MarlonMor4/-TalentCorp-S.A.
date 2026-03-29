/* ╔══════════════════════════════════════════════════════════════════════════╗
   ║                                                                          ║
   ║   SCRIPT 02 — INSERCIÓN DE DATOS EN EL OLTP                            ║
   ║                                                                          ║
   ║   QUÉ HACE: Pobla RRHH_OLTP con datos realistas de TalentCorp S.A.:    ║
   ║             5 oficinas, 5 departamentos, 10 puestos, 50 empleados,      ║
   ║             100 ausencias, 80 evaluaciones, 10 capacitaciones,          ║
   ║             60 asignaciones empleado-capacitación.                      ║
   ║                                                                          ║
   ╚══════════════════════════════════════════════════════════════════════════╝ */
 
USE RRHH_OLTP;
GO
 
-- ============================================================================
-- 2.1  LIMPIEZA PREVIA (idempotencia)
-- ============================================================================
-- Si el script se ejecuta por segunda vez, limpia los datos existentes antes
-- de volver a insertar. El orden es inverso a la creación: primero las tablas
-- dependientes (con FK salientes), luego las referenciadas.
-- DBCC CHECKIDENT reinicia los contadores IDENTITY a 0 para que los IDs
-- comiencen en 1 nuevamente en cada ejecución.
-- ============================================================================
PRINT '[INFO] Limpiando datos previos...';
DELETE FROM dbo.EmpleadosCapacitaciones;  -- Tabla de relación N:M: sin dependientes
DELETE FROM dbo.Capacitaciones;           -- Referenciada por EmpleadosCapacitaciones
DELETE FROM dbo.EvaluacionesDesempeno;    -- Depende de Empleados
DELETE FROM dbo.Ausencias;               -- Depende de Empleados
DELETE FROM dbo.Empleados;              -- Tabla central: borrar después de sus dependientes
DELETE FROM dbo.Puestos;               -- Referenciada por Empleados
DELETE FROM dbo.Departamentos;        -- Referenciada por Empleados; depende de Oficinas
DELETE FROM dbo.Oficinas;            -- Tabla raíz: última en borrarse
 
-- Reiniciar contadores de IDENTITY para que los IDs empiecen en 1
DBCC CHECKIDENT ('dbo.EmpleadosCapacitaciones', RESEED, 0);
DBCC CHECKIDENT ('dbo.Capacitaciones',          RESEED, 0);
DBCC CHECKIDENT ('dbo.EvaluacionesDesempeno',   RESEED, 0);
DBCC CHECKIDENT ('dbo.Ausencias',               RESEED, 0);
DBCC CHECKIDENT ('dbo.Empleados',               RESEED, 0);
DBCC CHECKIDENT ('dbo.Puestos',                 RESEED, 0);
DBCC CHECKIDENT ('dbo.Departamentos',           RESEED, 0);
DBCC CHECKIDENT ('dbo.Oficinas',                RESEED, 0);
GO
PRINT '[OK] Limpieza completada. Todos los IDENTITY reseteados a 0.';
 
-- ============================================================================
-- 2.2  INSERTAR OFICINAS (5 sedes internacionales)
-- ============================================================================
-- Sedes de TalentCorp S.A. distribuidas en Europa y América Latina.
-- El código sigue el patrón CIUDAD_ABREV-ZONA para identificación rápida.
-- ============================================================================
PRINT '[INFO] Insertando oficinas...';
INSERT INTO dbo.Oficinas
    (CodigoOficina, Ciudad, Pais, Region, CodigoPostal, Telefono, Direccion)
VALUES
    ('MAD-CENTRO',    'Madrid',           'España',    'Europa',   '28001',  '+34-910000001', 'Calle Gran Vía 100'),
    ('BOG-NORTE',     'Bogotá',           'Colombia',  'LatAm',    '110111', '+57-601000001', 'Carrera 15 #100-20'),
    ('MEX-POLANCO',   'Ciudad de México', 'México',    'LatAm',    '11560',  '+52-550000001', 'Av. Ejército Nacional 250'),
    ('LIM-SANISIDRO', 'Lima',             'Perú',      'LatAm',    '15073',  '+51-100000001', 'Av. Javier Prado 850'),
    ('BUE-PUERTO',    'Buenos Aires',     'Argentina', 'Cono Sur', 'C1107',  '+54-110000001', 'Av. Alicia Moreau 300');
PRINT '[OK] 5 oficinas insertadas.';
GO
 
-- ============================================================================
-- 2.3  INSERTAR DEPARTAMENTOS (5 áreas organizacionales)
-- ============================================================================
-- Cada departamento se vincula a una oficina mediante subconsulta por
-- CodigoOficina (no hardcodeamos IDs numéricos para mayor robustez).
-- ============================================================================
PRINT '[INFO] Insertando departamentos...';
INSERT INTO dbo.Departamentos (NombreDepartamento, Descripcion, OficinaID)
SELECT 'Recursos Humanos', 'Gestión integral de talento humano y cultura organizacional',
       OficinaID FROM dbo.Oficinas WHERE CodigoOficina = 'BOG-NORTE';
 
INSERT INTO dbo.Departamentos (NombreDepartamento, Descripcion, OficinaID)
SELECT 'Tecnología', 'Desarrollo de software, soporte e infraestructura tecnológica',
       OficinaID FROM dbo.Oficinas WHERE CodigoOficina = 'MAD-CENTRO';
 
INSERT INTO dbo.Departamentos (NombreDepartamento, Descripcion, OficinaID)
SELECT 'Ventas', 'Gestión comercial, prospección y cierre de negocios',
       OficinaID FROM dbo.Oficinas WHERE CodigoOficina = 'MEX-POLANCO';
 
INSERT INTO dbo.Departamentos (NombreDepartamento, Descripcion, OficinaID)
SELECT 'Finanzas', 'Planeación financiera, contabilidad y control presupuestario',
       OficinaID FROM dbo.Oficinas WHERE CodigoOficina = 'LIM-SANISIDRO';
 
INSERT INTO dbo.Departamentos (NombreDepartamento, Descripcion, OficinaID)
SELECT 'Marketing', 'Gestión de marca, campañas publicitarias y estrategia digital',
       OficinaID FROM dbo.Oficinas WHERE CodigoOficina = 'BUE-PUERTO';
PRINT '[OK] 5 departamentos insertados.';
GO
 
-- ============================================================================
-- 2.4  INSERTAR PUESTOS (10 cargos con rangos salariales en USD)
-- ============================================================================
PRINT '[INFO] Insertando puestos...';
INSERT INTO dbo.Puestos (NombrePuesto, NivelSalarial, SalarioMinimo, SalarioMaximo)
VALUES
    ('Gerente RRHH',                     'Senior',    8000.00, 14000.00),
    ('Analista RRHH',                    'Mid-Level', 3500.00,  7000.00),
    ('Desarrollador Junior',             'Junior',    3000.00,  5500.00),
    ('Desarrollador Senior',             'Senior',    7000.00, 13000.00),
    ('Administrador de Infraestructura', 'Mid-Level', 4500.00,  8500.00),
    ('Analista de Ventas',               'Mid-Level', 3500.00,  7500.00),
    ('Ejecutivo Comercial',              'Junior',    2800.00,  6000.00),
    ('Analista Financiero',              'Mid-Level', 4000.00,  8000.00),
    ('Contador Senior',                  'Senior',    7000.00, 12000.00),
    ('Especialista Marketing Digital',   'Mid-Level', 3500.00,  7800.00);
PRINT '[OK] 10 puestos insertados.';
GO
 
-- ============================================================================
-- 2.5  INSERTAR 5 JEFES DE ÁREA (directivos sin jefe superior)
-- ============================================================================
-- Los jefes se insertan PRIMERO porque el resto del personal necesita
-- referenciar su EmpleadoID en el campo JefeID.
-- JefeID = NULL indica que son los máximos responsables de su área.
-- Las subconsultas resuelven los IDs de departamento y puesto por nombre,
-- evitando hardcodear valores que pueden cambiar entre ejecuciones.
-- ============================================================================
PRINT '[INFO] Insertando jefes de área...';
 
-- Gerente RR.HH. — Bogotá
INSERT INTO dbo.Empleados
    (Identificacion, Nombre, Apellidos, FechaNacimiento, Genero, EstadoCivil,
     Email, Telefono, FechaContratacion, DepartamentoID, PuestoID,
     SalarioActual, JefeID, OficinaID, Activo)
SELECT 'EMP001','Laura','Gómez','1985-03-10','Femenino','Casado(a)',
    'laura.gomez@talentcorp.com','300000001','2018-01-15',
    d.DepartamentoID, p.PuestoID, 12000.00, NULL, d.OficinaID, 1
FROM dbo.Departamentos d JOIN dbo.Puestos p ON p.NombrePuesto = 'Gerente RRHH'
WHERE d.NombreDepartamento = 'Recursos Humanos';
 
-- Director Tecnología — Madrid
INSERT INTO dbo.Empleados
    (Identificacion, Nombre, Apellidos, FechaNacimiento, Genero, EstadoCivil,
     Email, Telefono, FechaContratacion, DepartamentoID, PuestoID,
     SalarioActual, JefeID, OficinaID, Activo)
SELECT 'EMP002','Carlos','Ruiz','1984-06-21','Masculino','Casado(a)',
    'carlos.ruiz@talentcorp.com','300000002','2017-04-03',
    d.DepartamentoID, p.PuestoID, 12500.00, NULL, d.OficinaID, 1
FROM dbo.Departamentos d JOIN dbo.Puestos p ON p.NombrePuesto = 'Desarrollador Senior'
WHERE d.NombreDepartamento = 'Tecnología';
 
-- Directora Ventas — Ciudad de México
INSERT INTO dbo.Empleados
    (Identificacion, Nombre, Apellidos, FechaNacimiento, Genero, EstadoCivil,
     Email, Telefono, FechaContratacion, DepartamentoID, PuestoID,
     SalarioActual, JefeID, OficinaID, Activo)
SELECT 'EMP003','Mariana','López','1987-11-08','Femenino','Soltero(a)',
    'mariana.lopez@talentcorp.com','300000003','2019-07-01',
    d.DepartamentoID, p.PuestoID, 11000.00, NULL, d.OficinaID, 1
FROM dbo.Departamentos d JOIN dbo.Puestos p ON p.NombrePuesto = 'Analista de Ventas'
WHERE d.NombreDepartamento = 'Ventas';
 
-- Director Finanzas — Lima
INSERT INTO dbo.Empleados
    (Identificacion, Nombre, Apellidos, FechaNacimiento, Genero, EstadoCivil,
     Email, Telefono, FechaContratacion, DepartamentoID, PuestoID,
     SalarioActual, JefeID, OficinaID, Activo)
SELECT 'EMP004','Andrés','Morales','1982-02-18','Masculino','Casado(a)',
    'andres.morales@talentcorp.com','300000004','2016-09-12',
    d.DepartamentoID, p.PuestoID, 11500.00, NULL, d.OficinaID, 1
FROM dbo.Departamentos d JOIN dbo.Puestos p ON p.NombrePuesto = 'Contador Senior'
WHERE d.NombreDepartamento = 'Finanzas';
 
-- Directora Marketing — Buenos Aires
INSERT INTO dbo.Empleados
    (Identificacion, Nombre, Apellidos, FechaNacimiento, Genero, EstadoCivil,
     Email, Telefono, FechaContratacion, DepartamentoID, PuestoID,
     SalarioActual, JefeID, OficinaID, Activo)
SELECT 'EMP005','Sofía','Paredes','1988-05-27','Femenino','Soltero(a)',
    'sofia.paredes@talentcorp.com','300000005','2020-03-20',
    d.DepartamentoID, p.PuestoID, 9800.00, NULL, d.OficinaID, 1
FROM dbo.Departamentos d JOIN dbo.Puestos p ON p.NombrePuesto = 'Especialista Marketing Digital'
WHERE d.NombreDepartamento = 'Marketing';
GO
PRINT '[OK] 5 jefes de área insertados (EMP001-EMP005).';
 
-- ============================================================================
-- 2.6  INSERTAR 45 EMPLEADOS ADICIONALES (total acumulado: 50)
-- ============================================================================
-- Técnica: CTE set-based con ROW_NUMBER() para generar los 45 registros
-- en una sola instrucción INSERT sin cursores ni bucles WHILE.
-- Esto es más eficiente y legible que 45 INSERT individuales.
--
-- Lógica de distribución por departamento (campo 'n' de la CTE Numeros):
--   n=1 a 8  → Recursos Humanos (8 empleados)
--   n=9 a 20 → Tecnología       (12 empleados)
--   n=21-30  → Ventas           (10 empleados)
--   n=31-38  → Finanzas         (8 empleados)
--   n=39-45  → Marketing        (7 empleados)
--
-- JefeID: se resuelve automáticamente uniendo con los empleados cuyo JefeID
-- es NULL (los 5 directivos insertados en el paso anterior).
-- ============================================================================
PRINT '[INFO] Insertando 45 empleados adicionales con CTE...';
 
;WITH
-- CTE 1: genera los números del 1 al 45
Numeros AS (
    SELECT TOP (45)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.objects
),
-- CTE 2: construye los atributos derivados de cada empleado
Base AS (
    SELECT
        n,
        CONCAT('EMP', RIGHT('000' + CAST(n + 5 AS VARCHAR), 3)) AS Identificacion,
        CASE (n % 10)
            WHEN 1 THEN 'Juan'      WHEN 2 THEN 'Ana'       WHEN 3 THEN 'Pedro'
            WHEN 4 THEN 'Luisa'     WHEN 5 THEN 'Miguel'    WHEN 6 THEN 'Valentina'
            WHEN 7 THEN 'Diego'     WHEN 8 THEN 'Camila'    WHEN 9 THEN 'Jorge'
            ELSE 'Daniela'
        END AS Nombre,
        CASE (n % 10)
            WHEN 1 THEN 'Pérez'     WHEN 2 THEN 'Martínez'  WHEN 3 THEN 'Rodríguez'
            WHEN 4 THEN 'Fernández' WHEN 5 THEN 'Torres'    WHEN 6 THEN 'Ramírez'
            WHEN 7 THEN 'Castro'    WHEN 8 THEN 'Sánchez'   WHEN 9 THEN 'Vargas'
            ELSE 'Mendoza'
        END AS Apellidos,
        DATEADD(DAY, n * 200, '1988-01-01')              AS FechaNacimiento,
        CASE WHEN n % 2 = 0 THEN 'Femenino' ELSE 'Masculino' END AS Genero,
        CASE WHEN n % 3 = 0 THEN 'Casado(a)' ELSE 'Soltero(a)' END AS EstadoCivil,
        CONCAT('empleado', n+5, '@talentcorp.com')       AS Email,
        CONCAT('310000', RIGHT('000'+CAST(n AS VARCHAR),3)) AS Telefono,
        DATEADD(DAY, n * 30, '2020-01-01')               AS FechaContratacion,
        CASE
            WHEN n BETWEEN 1  AND 8  THEN 'Recursos Humanos'
            WHEN n BETWEEN 9  AND 20 THEN 'Tecnología'
            WHEN n BETWEEN 21 AND 30 THEN 'Ventas'
            WHEN n BETWEEN 31 AND 38 THEN 'Finanzas'
            ELSE 'Marketing'
        END AS DepartamentoNombre
    FROM Numeros
),
-- CTE 3: identifica al jefe de cada departamento para asignar JefeID
Jefes AS (
    SELECT d.NombreDepartamento, e.EmpleadoID AS JefeID
    FROM dbo.Empleados e
    JOIN dbo.Departamentos d ON e.DepartamentoID = d.DepartamentoID
    WHERE e.JefeID IS NULL   -- Solo los 5 directivos del paso anterior
)
INSERT INTO dbo.Empleados
    (Identificacion, Nombre, Apellidos, FechaNacimiento, Genero, EstadoCivil,
     Email, Telefono, FechaContratacion, DepartamentoID, PuestoID,
     SalarioActual, JefeID, OficinaID, Activo)
SELECT
    b.Identificacion, b.Nombre, b.Apellidos, b.FechaNacimiento,
    b.Genero, b.EstadoCivil, b.Email, b.Telefono, b.FechaContratacion,
    d.DepartamentoID,
    -- Asigna el puesto según el departamento y la paridad del número de fila
    CASE
        WHEN b.DepartamentoNombre = 'Recursos Humanos'
            THEN (SELECT PuestoID FROM dbo.Puestos WHERE NombrePuesto='Analista RRHH')
        WHEN b.DepartamentoNombre = 'Tecnología' AND b.n%2=0
            THEN (SELECT PuestoID FROM dbo.Puestos WHERE NombrePuesto='Desarrollador Junior')
        WHEN b.DepartamentoNombre = 'Tecnología' AND b.n%2=1
            THEN (SELECT PuestoID FROM dbo.Puestos WHERE NombrePuesto='Administrador de Infraestructura')
        WHEN b.DepartamentoNombre = 'Ventas' AND b.n%2=0
            THEN (SELECT PuestoID FROM dbo.Puestos WHERE NombrePuesto='Ejecutivo Comercial')
        WHEN b.DepartamentoNombre = 'Ventas' AND b.n%2=1
            THEN (SELECT PuestoID FROM dbo.Puestos WHERE NombrePuesto='Analista de Ventas')
        WHEN b.DepartamentoNombre = 'Finanzas'
            THEN (SELECT PuestoID FROM dbo.Puestos WHERE NombrePuesto='Analista Financiero')
        ELSE    (SELECT PuestoID FROM dbo.Puestos WHERE NombrePuesto='Especialista Marketing Digital')
    END AS PuestoID,
    -- Salario varía por departamento + pequeño incremento según n (simula ajustes de antigüedad)
    CASE
        WHEN b.DepartamentoNombre='Recursos Humanos' THEN 4200+(b.n*20)
        WHEN b.DepartamentoNombre='Tecnología'       THEN 5000+(b.n*50)
        WHEN b.DepartamentoNombre='Ventas'           THEN 3900+(b.n*30)
        WHEN b.DepartamentoNombre='Finanzas'         THEN 4700+(b.n*35)
        ELSE                                              4100+(b.n*25)
    END,
    j.JefeID,       -- El jefe resuelto por la CTE Jefes
    d.OficinaID,
    1               -- Todos los empleados insertados están activos
FROM Base b
JOIN dbo.Departamentos d ON d.NombreDepartamento = b.DepartamentoNombre
JOIN Jefes j             ON j.NombreDepartamento = b.DepartamentoNombre;
GO
PRINT '[OK] 45 empleados adicionales insertados. Total: 50 empleados.';
 
-- ============================================================================
-- 2.7  INSERTAR 100 AUSENCIAS (período 2023-2024)
-- ============================================================================
-- Generación set-based de 100 eventos de ausencia.
-- CROSS JOIN entre sys.objects permite generar más de 100 filas base.
-- La distribución round-robin (módulo sobre COUNT de empleados) garantiza
-- que todos los empleados reciben al menos 2 ausencias asignadas.
-- 20% de las ausencias son injustificadas (n % 5 = 0).
-- ============================================================================
PRINT '[INFO] Insertando 100 ausencias 2023-2024...';
 
;WITH
Numeros AS (
    SELECT TOP (100) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.objects a CROSS JOIN sys.objects b
),
EmpsEnum AS (
    SELECT EmpleadoID, ROW_NUMBER() OVER (ORDER BY EmpleadoID) AS rn
    FROM dbo.Empleados
)
INSERT INTO dbo.Ausencias
    (EmpleadoID, TipoAusencia, FechaInicio, FechaFin, Justificada, Comentarios, FechaRegistro)
SELECT
    e.EmpleadoID,
    -- El tipo rota en ciclo de 4: distribución uniforme entre las 4 categorías
    CASE (n.n % 4)
        WHEN 1 THEN 'Vacaciones'
        WHEN 2 THEN 'Enfermedad'
        WHEN 3 THEN 'Permiso Personal'
        ELSE        'Licencia Médica'
    END,
    DATEADD(DAY, n.n * 5, '2023-01-01'),                -- FechaInicio: avanza 5 días por registro
    DATEADD(DAY, n.n * 5 + (n.n % 6), '2023-01-01'),    -- FechaFin: entre 0 y 5 días después
    CASE WHEN n.n % 5 = 0 THEN 0 ELSE 1 END,            -- 20% injustificadas
    CONCAT('Ausencia registrada #', n.n, '. Tipo: ',
           CASE (n.n%4) WHEN 1 THEN 'Vacaciones' WHEN 2 THEN 'Enfermedad'
                        WHEN 3 THEN 'Permiso Personal' ELSE 'Licencia Médica' END),
    DATEADD(DAY, n.n * 5, '2023-01-01')
FROM Numeros n
JOIN EmpsEnum e ON e.rn = ((n.n-1) % (SELECT COUNT(*) FROM dbo.Empleados)) + 1;
GO
PRINT '[OK] 100 ausencias insertadas.';
 
-- ============================================================================
-- 2.8  INSERTAR 80 EVALUACIONES DE DESEMPEÑO
-- ============================================================================
-- Las evaluaciones se distribuyen entre todos los empleados.
-- El evaluador es siempre el jefe del departamento (JefeID IS NULL).
-- Las calificaciones van de 3.0 a 5.0 (rango realista para empresa operativa).
-- Fórmula: 3.0 + (n%20 * 0.1) → valores: 3.0, 3.1, 3.2 ... 4.9, luego vuelve a 3.0
-- ============================================================================
PRINT '[INFO] Insertando 80 evaluaciones de desempeño...';
 
;WITH
Numeros AS (
    SELECT TOP (80) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.objects
),
EmpsEnum AS (
    SELECT EmpleadoID, DepartamentoID,
           ROW_NUMBER() OVER (ORDER BY EmpleadoID) AS rn
    FROM dbo.Empleados
),
JefesPorDepto AS (
    SELECT DepartamentoID, EmpleadoID AS EvaluadorID
    FROM dbo.Empleados WHERE JefeID IS NULL
)
INSERT INTO dbo.EvaluacionesDesempeno
    (EmpleadoEvaluadoID, FechaEvaluacion, Calificacion, EvaluadorID, Comentarios, FechaRegistro)
SELECT
    e.EmpleadoID,
    DATEADD(DAY, n.n * 12, '2023-01-15'),   -- Una evaluación cada ~12 días: cubre 2023-2024
    CAST(ROUND(3.0 + ((n.n % 20) * 0.1), 1) AS DECIMAL(3,1)),
    j.EvaluadorID,
    CONCAT('Evaluación semestral #', n.n, '. ',
        CASE WHEN (n.n%20)*0.1 >= 1.5 THEN 'Supera expectativas del rol.'
             WHEN (n.n%20)*0.1 >= 0.8  THEN 'Cumple satisfactoriamente los objetivos.'
             ELSE 'Presenta áreas de oportunidad identificadas y seguimiento planificado.' END),
    DATEADD(DAY, n.n * 12, '2023-01-15')
FROM Numeros n
JOIN EmpsEnum e    ON e.rn = ((n.n-1) % (SELECT COUNT(*) FROM dbo.Empleados)) + 1
JOIN JefesPorDepto j ON j.DepartamentoID = e.DepartamentoID;
GO
PRINT '[OK] 80 evaluaciones insertadas.';
 
-- ============================================================================
-- 2.9  INSERTAR 10 CAPACITACIONES (programas de formación)
-- ============================================================================
PRINT '[INFO] Insertando 10 programas de capacitación...';
INSERT INTO dbo.Capacitaciones
    (NombreCapacitacion, Descripcion, Proveedor, Costo, FechaInicio, FechaFin)
VALUES
    ('Liderazgo Efectivo',
     'Habilidades de liderazgo, gestión de equipos y toma de decisiones estratégicas',
     'SkillCenter',   1500.00, '2023-02-10', '2023-02-12'),
    ('Excel Avanzado',
     'Funciones avanzadas, Power Query, tablas dinámicas y dashboards corporativos',
     'DataAcademy',    800.00, '2023-03-05', '2023-03-06'),
    ('Power BI para Análisis',
     'Modelado de datos con DAX, relaciones y visualización interactiva de KPIs',
     'BI Labs',        1200.00, '2023-04-15', '2023-04-17'),
    ('Python para Automatización',
     'Automatización de tareas y análisis de datos con pandas y matplotlib',
     'TechSchool',     1800.00, '2023-05-20', '2023-05-24'),
    ('Marketing Digital',
     'Estrategia SEO/SEM, campañas en redes sociales y métricas de conversión',
     'GrowthHub',      1000.00, '2023-06-10', '2023-06-12'),
    ('SQL Server y T-SQL',
     'Consultas complejas, optimización de índices y procedimientos almacenados',
     'DB Institute',   1600.00, '2023-07-05', '2023-07-08'),
    ('Comunicación Corporativa',
     'Habilidades de comunicación oral, escrita y presentaciones ejecutivas',
     'Talent Academy',  600.00, '2024-01-12', '2024-01-13'),
    ('Gestión del Tiempo',
     'Metodologías de productividad, priorización y gestión de la carga laboral',
     'SkillCenter',     500.00, '2024-02-20', '2024-02-20'),
    ('Finanzas para No Financieros',
     'Conceptos financieros clave, lectura de estados e indicadores de rentabilidad',
     'FinancePro',      900.00, '2024-03-14', '2024-03-15'),
    ('Analítica de RR.HH.',
     'KPIs de talento, people analytics y dashboards de gestión del capital humano',
     'HR Metrics',     1400.00, '2024-05-10', '2024-05-12');
PRINT '[OK] 10 capacitaciones insertadas.';
GO
 
-- ============================================================================
-- 2.10  INSERTAR 60 ASIGNACIONES EMPLEADO-CAPACITACIÓN
-- ============================================================================
-- La CTE con PARTITION BY EmpleadoID, CapacitacionID + WHERE rep = 1 garantiza
-- que no se inserten pares duplicados, respetando la restricción UNIQUE de la tabla.
-- 75% de las asignaciones están 'Completadas', 25% 'En Curso'.
-- ============================================================================
PRINT '[INFO] Insertando 60 asignaciones de capacitación...';
 
;WITH
Numeros AS (
    SELECT TOP (60) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.objects
),
EmpsEnum AS (
    SELECT EmpleadoID, ROW_NUMBER() OVER (ORDER BY EmpleadoID) AS rn FROM dbo.Empleados
),
CapsEnum AS (
    SELECT CapacitacionID, ROW_NUMBER() OVER (ORDER BY CapacitacionID) AS rn FROM dbo.Capacitaciones
),
Pares AS (
    SELECT n.n, e.EmpleadoID, c.CapacitacionID,
           ROW_NUMBER() OVER (PARTITION BY e.EmpleadoID, c.CapacitacionID ORDER BY n.n) AS rep
    FROM Numeros n
    JOIN EmpsEnum e ON e.rn = ((n.n-1) % (SELECT COUNT(*) FROM dbo.Empleados)) + 1
    JOIN CapsEnum c ON c.rn = ((n.n-1) % (SELECT COUNT(*) FROM dbo.Capacitaciones)) + 1
)
INSERT INTO dbo.EmpleadosCapacitaciones
    (EmpleadoID, CapacitacionID, CalificacionObtenida, FechaCompletado, Estado, Comentarios)
SELECT
    EmpleadoID, CapacitacionID,
    CASE WHEN n%4=0 THEN NULL ELSE CAST(60+(n%41) AS DECIMAL(5,2)) END,
    CASE WHEN n%4=0 THEN NULL ELSE DATEADD(DAY, n*10, '2023-02-15') END,
    CASE WHEN n%4=0 THEN 'En Curso' ELSE 'Completada' END,
    CONCAT('Seguimiento #', n, '. ',
           CASE WHEN n%4=0 THEN 'Curso actualmente en progreso.'
                WHEN (n%41)>25 THEN 'Desempeño sobresaliente en el programa.'
                ELSE 'Completado satisfactoriamente.' END)
FROM Pares
WHERE rep = 1;   -- Solo insertar pares únicos para cumplir la restricción UNIQUE
GO
PRINT '[OK] 60 asignaciones de capacitación insertadas.';
 
-- ============================================================================
-- VERIFICACIÓN SCRIPT 02
--
-- La tabla de conteos debe mostrar exactamente:
-- Oficinas=5, Departamentos=5, Puestos=10, Empleados=50,
-- Ausencias=100, EvaluacionesDesempeno=80, Capacitaciones=10,
-- EmpleadosCapacitaciones=60
-- ============================================================================
SELECT 'Oficinas'               AS Tabla, COUNT(*) AS TotalRegistros FROM dbo.Oficinas          UNION ALL
SELECT 'Departamentos',                   COUNT(*)                   FROM dbo.Departamentos      UNION ALL
SELECT 'Puestos',                         COUNT(*)                   FROM dbo.Puestos            UNION ALL
SELECT 'Empleados',                       COUNT(*)                   FROM dbo.Empleados          UNION ALL
SELECT 'Ausencias',                       COUNT(*)                   FROM dbo.Ausencias          UNION ALL
SELECT 'EvaluacionesDesempeno',           COUNT(*)                   FROM dbo.EvaluacionesDesempeno UNION ALL
SELECT 'Capacitaciones',                  COUNT(*)                   FROM dbo.Capacitaciones     UNION ALL
SELECT 'EmpleadosCapacitaciones',         COUNT(*)                   FROM dbo.EmpleadosCapacitaciones;
GO
PRINT '=== SCRIPT 02 COMPLETADO: RRHH_OLTP poblada con datos de TalentCorp. ===';
