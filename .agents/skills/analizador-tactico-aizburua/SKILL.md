---
name: analizador-tactico-aizburua
description: Motor de Auditoría y Generación de Informes Tácticos Aizburua (v4.4). Gestiona la alineación, el hándicap ABE, la comparativa biomecánica y el Motor de Narrativa Dinámica.
---

# Analizador Táctico Aizburua (v4.6 Estable)

Este skill es la autoridad única para la gestión de datos, análisis de rendimiento y generación de informes del Club Aizburua. Integra la física del remo con el reglamento ABE.

## 1. FUENTES DE VERDAD (SOBERANÍA DE DATOS)
1.  **DATOS SUMINISTRADOS:** La única fuente válida para tiempos, distancias, recorridos y resultados son los archivos del workspace (`historico-regatas.json`, PDFs, etc.) entregados por el USER.
2.  **PROHIBICIÓN DE INTERNET:** Queda estrictamente PROHIBIDO buscar tiempos, distancias o resultados en internet. Cualquier discrepancia entre internet y el workspace se resuelve a favor del workspace.
3.  **[Protocolo Táctico](file:///c:/Proyectos/Aizburua/Base%20Conocimiento/Protocolo_Analisis_Tactico.md)**: Baremos de hándicap.
4.  **Extracción Meteorológica:** Único caso donde se permite consulta externa (Euskalmet/Aemet) si no hay datos en el workspace.

## 2. FLUJO DE TRABAJO
*   **Generación:** `pwsh -File "scripts/generar_informe.ps1" -RegataName "[Nombre]"`
*   **Sincronización:** Al añadir resultados, asegurar que los puntos de liga estén presentes para el cálculo acumulado.

## 3. ESTÁNDARES TÉCNICOS (v4.7)

### 3.1 Integridad y Clasificación
*   **PROHIBIDO inventar tiempos.** Solo datos reales (C1, C2, T.Real).
*   **Ordenamiento:** Las tablas de rivales se ordenan SIEMPRE por **Puntos Totales de Liga (General)**.
*   **Datos de Telemetría Exactos:** Se deben integrar minuciosamente los ritmos (min/km) y frecuencias de boga (p/min) provistos por el usuario para cada largo o "lap" de la regata.

### 3.2 Auditor&iacute;a T&aacute;ctica y Narrativa (NUEVO v4.8)
*   **Estructura Din&aacute;mica por Largos:** El an&aacute;lisis narrativo DEBE desglosarse de forma dinámica según los largos reales de la regata (pueden ser de 1 a 4 largos). La lógica debe iterar sobre los tramos existentes y no simplificar genéricamente a "Ida y Vuelta".
*   **Tabla Hidrodin&aacute;mica Cruzada (Dinámica):** La secci&oacute;n "C&oacute;mo Remaron" debe usar una tabla horizontal a ancho completo (sin div g2). Las columnas se generar&aacute;n de forma **din&aacute;mica** dependiendo del n&uacute;mero de largos (L1, L2... hasta L4) y culminando en una columna de Fallo/Diagn&oacute;stico. Filas obligatorias: Corriente y Viento, Boga, Metros por palada, Desplazamiento &uacute;til, Velocidad, Brecha.
*   **Evaluaci&oacute;n de Trimado Lateral (3 Niveles):** 
    *   `< 5 kg`: TRIMADO &Oacute;PTIMO (bote plano, sin fricci&oacute;n).
    *   `5 kg a 15 kg`: DESV&Iacute;O LEVE (correcciones menores).
    *   `> 15 kg`: ALERTA DE TRIMADO (bote escora, fricci&oacute;n aerodin&aacute;mica severa, el tim&oacute;n act&uacute;a como freno continuo).
*   **Diagn&oacute;stico F&iacute;sico de Fatiga:** ESTRICTAMENTE PROHIBIDO medir el "desplome" comparando el &uacute;ltimo largo contra el sprint de salida (ej. 3:52). La salida explosiva se debe descontar; el desgaste muscular se eval&uacute;a comparando el **ritmo base** establecido tras la salida frente al ritmo del &uacute;ltimo largo.
*   **Marca Comercial Prohibida:** Queda ESTRICTAMENTE PROHIBIDO usar nombres de marcas (ej: "Garmin"). Usar exclusivamente: "Sensores GPS", "Navegaci&oacute;n", o "Telemetr&iacute;a".

### 3.3 Dashboard de Situación (Reglas de Oro)
*   **Métricas:** El estado de situación debe usar exclusivamente **Puntos de Liga**, nunca segundos.
*   **Márgenes:** El margen de salvación se calcula contra el **5º puesto** del grupo de rivales directos (puestos 6-7 = Playoff).

### 3.4 Normalización y Consolidación
*   **Fusión de Clubes:** "ITSASOKO AMA" y "SANTURTZI" deben ser tratados como el mismo club para la suma de puntos.
*   **Raíz de Nombre:** Usar `Get-ClubRoot` para agrupar variantes (ej: "IBERIA A.T." -> "IBERIA").

### 3.5 Arquitectura de la Bancada (v4.9)
*   **Bloque Motor Central (B3-5):** De acuerdo a la doctrina del club, las bancadas 3, 4 y 5 constituyen el núcleo de potencia. En esta zona, el peso elevado (>85kg) no se penaliza, sino que se justifica por la capacidad de torque y palanca (talla).
*   **Apoyo de Proa (B6):** Zona de transición. Se monitoriza el peso con mayor flexibilidad que el proel.
*   **Proel (PROA):** Es la posición de máxima sensibilidad hidrodinámica. Es el único puesto donde se aplica un límite estricto de peso para evitar el "pitching" (cabeceo) que frena el planeo del bote.

### 3.6 Protocolo de Alertas Visuales (NUEVO v5.0)
*   **Contenedor Estándar (`.tactical-alert`):** Toda advertencia crítica de biomecánica o trimado debe usar este contenedor (fondo rojo suave, borde izquierdo grueso).
*   **Iconografía Robusta (SVG):** Queda ESTRICTAMENTE PROHIBIDO el uso de emojis (ej: ⚠️) en los scripts de generación, ya que provocan errores de codificación (garbage characters) según el entorno. Se debe usar exclusivamente el icono SVG integrado en el CSS o inyectado mediante variable.
*   **Sombra y Contraste:** Las alertas deben incluir `box-shadow` suave para destacar sobre el fondo y asegurar que el técnico identifique el riesgo de forma instantánea.

### 3.7 Terminolog&iacute;a y Narrativa Din&aacute;mica (NUEVO v5.1)
*   **Soberan&iacute;a del Marcaje:** El t&eacute;rmino "Marcaje" o "Marca" queda reservado EXCLUSIVAMENTE para la Bancada 1 (Popa). En las posiciones de Proa (B6 y B7), se deben usar t&eacute;rminos como "Coordinaci&oacute;n", "Apoyo T&eacute;cnico" o "Precisi&oacute;n Proel".
*   **Prohibici&oacute;n de Duplicidad:** El Motor de Narrativa DEBE evitar generar bloques de texto id&eacute;nticos para diferentes remeros en un mismo informe. Se debe usar la variable de banda (`$side` / Babor-Estribor) o la experiencia para variar el enfoque del "Impacto" y la "Elecci&oacute;n", aportando un análisis personalizado y profesional.

### 3.8 Motor de Hándicap ABE (NUEVO v5.5)
*   **Edad de Cómputo Universal**: Para el cálculo del promedio de edad del bote, se incluyen **los 14 tripulantes** (12 bancadas + patrón + proel), independientemente de su edad individual.
*   **Escalado de Tabla**: El valor de la tabla ABE se obtiene aplicando el `Floor` a la edad media resultante.
*   **Bonus de Género Consolidado**: Se añaden **+5 segundos** por cada mujer de ≥ 45 años.
*   **Orden de Operaciones Crítico**: El bonus de género se suma a los segundos de la tabla **antes** de aplicar el factor de escala por distancia (`(Segundos + Bonus) * (Distancia / 3500)`).
*   **Simulación de Cambios**: Al evaluar una reserva, el sistema debe recalcular el número total de mujeres ≥ 45 que quedarían en el bote nuevo, asegurando la coherencia del hándicap resultante.

## 4. DISEÑO Y VISUALIZACIÓN
*   **Diseño Premium:** Rojo Aizburua (`#C0001A`), gradientes oscuros tipo "cockpit" y fuentes Inter/Outfit.
*   **Consistencia:** Contenedor `1600px` máx. Simetría rígida en rejillas (ancho hardcodeado).
*   **Codificación:** Salida siempre en UTF-8 con BOM para asegurar compatibilidad total en Windows/Navegadores.

---
*Última actualización: 30/04/2026 - Consolidación Estándar v5.5 (Estandarización de Hándicap y Lógica de Género)*

## 5. PROTOCOLO DE GESTIÓN DE GITHUB

> [!CAUTION]
> **REGLA DE ORO**: No realizar `git push` sin autorización.
