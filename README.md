# Aizburua - Motor de Análisis Táctico para Traineras (Veteranos ABE)

![Aizburua Logo](remeros/logo_club.png)

## Descripción
Aizburua es una plataforma avanzada de auditoría y análisis táctico diseñada específicamente para la competición de traineras en la **Liga de Veteranos (Asociación de Beteranos de Euskadi - ABE)**. 

El sistema utiliza un motor heurístico basado en la **Base de Conocimiento** técnica del club (biomecánica, fisiología y reglamentación) para optimizar la alineación de la tripulación, maximizando tanto la potencia absoluta como el retorno del hándicap por edad y género.

## Características Principales

### 1. Auditoría Biomecánica (v4.0)
El motor analiza cada bancada según criterios antropométricos y técnicos específicos:
*   **Zona de Proa:** Control estricto de masa para evitar el *pitching* (cabeceo longitudinal).
*   **Bloque Motor (B3-B5):** Optimización de la palanca vectorial basada en la talla (correlación r=0.67 entre altura y vatios).
*   **Zona de Popa:** Priorización de la estabilidad neurológica y el arco de palada (110°).
*   **Estreles (B6):** Inclusión estratégica de mujeres para mejorar la hidrodinámica y el trimado.

### 2. Algoritmo de Hándicap ABE
Cálculo automatizado de la bonificación de tiempo según la normativa oficial:
*   Umbral de activación a los **45 años**.
*   Bonificación por género (+5s para mujeres ≥ 45 años).
*   Cálculo de "Velocidad Virtual" cruzando PAM real vs ganancia de hándicap.

### 3. Depósito Neurológico y Scoring
Sistema de puntuación de 0 a 100 para la selección de sustitutos, que valora:
*   **Calidad Técnica:** Mapeo de niveles cualitativos (Élite, Alta, Media, Baja).
*   **Experiencia:** Años de remo acumulados.
*   **Ajuste al Biotipo:** Coincidencia con los rangos ideales de peso y altura de cada puesto.

## Estructura del Proyecto

*   `Base Conocimiento/`: Documentación técnica sobre posiciones, fisiología del remo y reglamentación.
*   `data/`: Bases de datos en JSON (plantilla de remeros, histórico de regatas).
*   `scripts/`: El núcleo lógico en PowerShell (`generar_comparativa.ps1`).
*   `informes/`: Reportes HTML generados con visualización profesional de métricas.

## Cómo Utilizar

Para generar un análisis de una regata específica, ejecuta el script principal desde PowerShell:

```powershell
.\scripts\generar_comparativa.ps1 -RegataName "Getxo"
```

El sistema generará un informe HTML detallado con:
1.  Comparativa de rendimiento meteorológico.
2.  Análisis táctico de la alineación.
3.  Sugerencias de reajuste biomecánico con candidatos específicos.

---
**Desarrollado para la optimización del rendimiento en banco fijo.**
