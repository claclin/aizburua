---
name: analizador-tactico-aizburua
description: Motor de Auditoría y Generación de Informes Tácticos Aizburua (v6.0). Gestiona el Equilibrio Global, Cascada de Reservas, Hándicap ABE y Narrativa Dinámica.
---

# Analizador Táctico Aizburua (v6.0 Estable)

Este skill es la autoridad única para la gestión de datos, análisis de rendimiento y generación de informes del Club Aizburua. Integra la física del remo con el reglamento ABE y el nuevo sistema de Equilibrio Estructural.

## 1. FUENTES DE VERDAD (SOBERANÍA DE DATOS)
1.  **DATOS SUMINISTRADOS:** La única fuente válida para tiempos, distancias, recorridos y resultados son los archivos del workspace (`historico-regatas.json`, PDFs, etc.) entregados por el USER.
2.  **PROHIBICIÓN DE INTERNET:** Queda estrictamente PROHIBIDO buscar tiempos, distancias o resultados en internet.
3.  **[Protocolo Táctico](file:///c:/Proyectos/Aizburua/Base%20Conocimiento/Protocolo_Analisis_Tactico.md)**: Baremos de hándicap.
4.  **Extracción Meteorológica:** Único caso donde se permite consulta externa (Euskalmet/Aemet) si no hay datos en el workspace.

## 2. FLUJO DE TRABAJO
*   **Generación:** `pwsh -File "scripts/generar_comparativa.ps1" -RegataName "[Nombre]"` (Motor de Optimización).
*   **Informes:** `pwsh -File "scripts/generar_informe.ps1" -RegataName "[Nombre]"` (Crónica Post-Regata).

## 3. ESTÁNDARES TÉCNICOS (v6.0)

### 3.1 Integridad y Clasificación
*   **PROHIBIDO inventar tiempos.** Solo datos reales (C1, C2, T.Real).
*   **Ordenamiento:** Las tablas de rivales se ordenan SIEMPRE por **Puntos Totales de Liga (General)**.

### 3.2 Auditoría Táctica y Narrativa
*   **Estructura Din&aacute;mica por Largos:** Desglose según los largos reales de la regata (1 a 4).
*   **Tabla Hidrodin&aacute;mica Cruzada:** Generación dinámica de columnas (L1, L2... L4) y diagnóstico final.
*   **Diagn&oacute;stico de Fatiga:** Evaluar el **ritmo base** tras la salida frente al ritmo del último largo.

### 3.3 Equilibrio Global y Cascada de Reservas (NUEVO v6.0)
*   **Detecci&oacute;n de Asimetr&iacute;a Lateral:** Se debe auditar el peso de cada bancada comparando Babor vs Estribor.
    *   `< 5 kg`: TRIMADO &Oacute;PTIMO.
    *   `5 kg a 15 kg`: DESV&Iacute;O LEVE.
    *   `> 15 kg`: **ALERTA CR&Iacute;TICA (EQUILIBRIO ESTRUCTURAL)**. Requiere propuesta de cambio automática.
*   **Cascada de Reservas Inteligente:** Al detectar un fallo de biotipo o una asimetría > 15kg, el sistema debe buscar en el banquillo (`plantilla_remeros.json`) la alternativa que mejor resuelva el déficit específico (usando `targetWeight`).
*   **Dictamen de Reajuste (El Movimiento Maestro):**
    *   **Prioridad 1:** Movimientos de Corrección (Biotipo y Equilibrio Estructural) mediante sustituciones del banquillo.
    *   **Prioridad 2:** Optimización de Torque (Intercambios Internos) entre jóvenes y veteranos para maximizar la palanca en el motor central.

### 3.4 Arquitectura de la Bancada (Biotipos)
*   **Bloque Motor Central (B3-5):** Núcleo de potencia. Se exige talla (>176cm) y masa crítica (>75kg).
*   **Contramarca (B2):** Perfil de tracción pesada (75-88kg) para asentar la popa.
*   **Popa/Marca (B1):** Estabilidad y ritmo. Peso medio (<85kg) y veteranía (>45 años).
*   **Proel (PROA):** Máxima sensibilidad. Límite estricto de peso (<80kg) para evitar cabeceo.

### 3.5 Motor de Hándicap ABE (v5.5)
*   **Edad de Cómputo Universal**: Incluye los **14 tripulantes**.
*   **Bonus de Género**: +5 segundos por cada mujer de ≥ 45 años, sumados **antes** del escalado por distancia.
*   **Sincronizaci&oacute;n de Cambios**: Las simulaciones de reservas deben actualizar dinámicamente el contador de mujeres elegibles para reflejar el HCP real del bote propuesto.

### 3.6 Protocolo de Alertas Visuales
*   **Contenedor Estándar (`.tactical-alert`):** Fondo rojo suave, borde izquierdo grueso (`#ea580c` para equilibrio, `#C0001A` para biotipo).
*   **Iconografía Robusta (SVG):** PROHIBIDO el uso de emojis. Usar exclusivamente el icono SVG estándar.

## 4. DISEÑO Y VISUALIZACIÓN
*   **Diseño Premium:** Rojo Aizburua (`#C0001A`), gradientes oscuros y fuentes Inter.
*   **Codificación:** Salida siempre en UTF-8 con BOM.

---
*Última actualización: 01/05/2026 - Consolidación Estándar v6.0 (Equilibrio Global y Cascada Dinámica)*
