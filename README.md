# 📊 Sistema Integral de Business Intelligence: TalentCorp S.A.
### Proyecto Integrador - Gestión Analítica de Recursos Humanos

Este repositorio contiene la implementación de una solución de **Business Intelligence (BI)** de extremo a extremo, diseñada para transformar datos operativos de Recursos Humanos en inteligencia estratégica. El proyecto abarca desde el diseño del modelo transaccional hasta la validación de calidad en un Data Warehouse.

---

## 👥 Integrantes
* **[Tu Nombre / Marlon Mora]**
* **[Integrante 2]**
* **[Integrante 3]**

---

## 🚀 Estructura del Proyecto (Entregables)

El proyecto se organiza en 10 scripts SQL estructurados para ser ejecutados secuencialmente, garantizando la integridad del flujo de datos:

| Orden | Archivo | Descripción |
| :--- | :--- | :--- |
| 1 | `01_Crear_RRHH_OLTP.sql` | Creación de la base de datos operacional con integridad referencial. |
| 2 | `02_Poblar_RRHH_OLTP.sql` | Inserción de datos maestros (Empleados, Oficinas, Puestos). |
| 3 | `03_Crear_RRHH_DWH.sql` | Estructura base del Data Warehouse. |
| 4 | `04_Crear_Dimensiones.sql` | Implementación de las 7 dimensiones del modelo. |
| 5 | `05_Crear_Hechos.sql` | Implementación de las 3 tablas de hechos (Ausencias, Evaluaciones, Capacitaciones). |
| 6 | `06_ETL_Poblar_DimTiempo.sql` | Script de generación procedimental de la dimensión temporal. |
| 7 | `07_ETL_Cargar_Dimensiones.sql` | Proceso de transformación y carga (ETL) de dimensiones. |
| 8 | `08_ETL_Cargar_Hechos.sql` | Carga de métricas y cálculos de hechos desde el OLTP. |
| 9 | `09_Validaciones_DWH.sql` | **14 pruebas de calidad** con reporte automatizado PASS/FAIL. |
| 10 | `10_Consultas_Analiticas.sql` | **15 consultas estratégicas** y KPIs multidimensionales. |

---

## 🏗️ Arquitectura Técnica

### Modelo Transaccional (OLTP)
Diseñado en **3ra Forma Normal (3NF)** para asegurar la consistencia en el registro de la operativa diaria: contrataciones, evaluaciones de desempeño, gestión de ausencias y planes de capacitación.

### Modelo Analítico (Data Warehouse)
Se implementó un **Esquema Estrella (Star Schema)** desnormalizado que permite:
* **Dimensiones:** Empleado, Oficina, Departamento, Puesto, Tiempo, Tipo de Ausencia y Capacitación.
* **Tablas de Hechos:** Métricas de ausentismo, inversión en formación y rendimiento laboral.

---

## 📉 KPIs y Valor de Negocio
A través de las consultas analíticas incluidas, el sistema responde a preguntas críticas:
* **Tasa de Ausentismo:** ¿Qué departamentos generan más días perdidos?
* **ROI de Capacitación:** ¿Existe correlación entre la inversión en cursos y la mejora en evaluaciones?
* **Análisis de Salarios:** Distribución de costos por nivel de puesto y región geográfica.
* **Eficiencia por Oficina:** Comparativa de KPIs entre sedes (Ej: Medellín vs. Bogotá).

---

## ✅ Calidad de Datos (Data Quality)
El proyecto incluye un robusto sistema de validación que verifica:
1. **Integridad:** Ausencia de registros huérfanos.
2. **Consistencia:** El conteo de registros coincide entre el origen y el destino.
3. **Lógica de Negocio:** Validación de que no existan fechas de contratación futuras o salarios negativos.

---

## 🛠️ Tecnologías
* **Motor:** Microsoft SQL Server
* **Lenguaje:** T-SQL (Transact-SQL)
* **Modelado:** dbdiagram.io
* **Control de Versiones:** Git & GitHub

---

## 🔗 Enlaces de Interés
* **Diagrama del Modelo:** [Link a dbdiagram.io aquí]
* **Documentación Final:** Ver carpeta `/documentacion`
