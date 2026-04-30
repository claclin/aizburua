---
description: Genera un informe profesional en HTML con los resultados del análisis de Aizburua. Usa colores del club (rojo) y estructura de ficha técnica con tablas comparativas, condiciones oceanográficas y esquema de tripulación.
---

# Generador de Informes Profesionales — Aizburua (v4.4 Estable)

Esta habilidad transforma los datos del análisis en un documento visual de alto impacto en formato **HTML**, listo para ser compartido o archivado.

---

## 0. REQUISITOS PREVIOS DE DATOS (MANDATORIO)
Antes de proceder con cualquier análisis técnico o generación de informes, el agente DEBE validar que dispone de los siguientes datos específicos. Si falta alguno, DEBE solicitarlo al usuario:
1. **Modalidad:** (Contrarreloj vs Tandas).
2. **Geometría de la Regata:** Número de largos (N), número de ciabogas (Z) y distancia total (D). Estos tres valores son variables y deben confirmarse antes del análisis (ej. 1 largo 0 ciabogas, 2 largos 1 ciaboga, 4 largos 3 ciabogas, etc.).
3. **Eje de Boga y Calles:** Ubicación de las balizas (ej. Muelle vs Mar) y asignación de calles.
4. **Horarios de Salida:** Listado de tandas y horas exactas.

---

## 1. PASO A PASO DEL PROCESO

### PASO 1 — Generación del Informe Individual
El agente debe ejecutar el script principal para la regata específica:
```powershell
pwsh -File "scripts/generar_informe.ps1" -RegataName "[Nombre_Regata]"
```

### PASO 2 — Estudio de Evolución (Temporada)
Tras cada regata, se debe actualizar el informe histórico de la temporada:
```powershell
pwsh -File "scripts/generar_comparativa.ps1" -RegataName "[Nombre_Regata]"
```

---

## 2. ESTÁNDARES TÉCNICOS Y VISUALES (v4.4)

### 2.1 Regla de Codificación Inquebrantable
> [!IMPORTANT]
> **REGLA DE CODIFICACIÓN**: Para cualquier salida HTML generada por los scripts `.ps1`, es MANDATORIO el uso de entidades HTML para caracteres no-ASCII (ej: `&aacute;`, `&ntilde;`). NUNCA usar acentos literales en el código del script que se inyecta en el HTML final.

### 2.2 Motor de Narrativa Dinámica (`Format-TacticalNarrative`)
1. **Limpieza de Datos**: El archivo `historico-regatas.json` NO debe contener etiquetas HTML en la crónica. 
2. **Resaltado Automático**: El script inyecta estilos dinámicos a palabras clave como **ciaboga**, **muro**, **vaciante**, etc.
3. **Regex de PowerShell**: Usar siempre comillas simples (`'`) para evitar que PowerShell interfiera con los grupos de captura (`$1`).

### 2.3 Identidad Corporativa (Protocolo de Estilo v4.4)
1. **Logos**: Integrar `Logo1.jpg` en cabecera y `Logo2.jpg` en pie de página (Base64).
2. **Colores**: Rojo Aizburua `#C0001A`, fondo oscuro `#1a1a2e`.
3. **Tipografía**: Fuentes modernas (Inter/Outfit) vía Google Fonts.

### 2.4 Protocolo de Extracción Meteorológica (OBLIGATORIO)
Al recabar datos oceanográficos y meteorológicos (viento, oleaje, mareas) para una regata, el agente DEBE priorizar consultas web a las siguientes fuentes oficiales en este orden:
1. Euskalmet (`euskalmet.euskadi.eus`)
2. Euskoos (`info.euskoos.eus`)
3. Salvamento Marítimo (`salvamentomaritimo.es`)
4. AEMET (`aemet.es`)
Solo tras constatar falta de datos en estas fuentes (ej. fechas recientes no indexadas), se permite completar la información con búsquedas web genéricas, contrastando los resultados con los patrones oficiales.

---

## 3. NORMAS DE VISUALIZACIÓN DE NOMBRES (OBLIGATORIO)

Todos los nombres de remeros deben mostrarse en **MAYÚSCULAS ABSOLUTAS** (`.ToUpper()`) en el HTML final.

---

## 4. NORMAS ESPECÍFICAS DE AUDITORÍA BIOMECÁNICA (v4.6)

### 4.1 Baremos de Alerta (Visualización en tablas)
| Zona | Límite Crítico | Alerta Visual |
|------|----------------|---------------|
| **B1 (Popa)** | > 85 kg | Rojo (Peso excesivo en zona de equilibrio) |
| **B3-5 (Motor)** | > 85 kg | Justificado (Núcleo de potencia, no se penaliza talla elevada) |
| **B6 (Apoyo)** | > 75 kg | Rojo (Riesgo de cabeceo/pitching) |
| **PROA** | > 75 kg | Rojo (Máxima sensibilidad hidrodinámica) |

### 4.2 Scoring y Bonos
1. **Agilidad Morfológica (Proa / B6):** Se otorga un bonus de **+15 pts** si el peso del remero es ≤ 75kg. Esta regla es estrictamente biomecánica y se aplica independientemente del género del deportista.
2. **HCP (Handicap Oficial ABE - v4.6):**
   - **Edad de Cómputo (Ec):** Se calcula sobre la media de **TODOS** los miembros del bote (14 personas: 12 remeros + proel + patrón).
   - **Tabla Base:** Se usa el valor entero (`[math]::Floor(Ec)`) para consultar la tabla de segundos ABE (base 3500m).
   - **Bonificación de Género:** Se suman **+5 segundos planos** por cada mujer ≥ 45 años presente en la alineación.
   - **Fórmula de Cálculo Final:** `HCP_Regata = (Segundos_Tabla + (5 * N_Mujeres_45)) * (Distancia_Real / 3500)`
   - **Uso:** Fundamental en simulaciones de la "Cascada de Reservas" para evaluar el balance entre veteranía (+hándicap) y potencia física.

### 4.3 Rivales Directos (Playoff de Permanencia)
Para la narrativa estratégica del informe y el aislamiento de métricas competitivas, los rivales directos paramétricos de Aizburua para la zona baja / Playoff son:
- IBERIA
- PLENTZIA
- PONTEJOS
- BILBAO
- ILLUNBE
- SANTURTZI (También conocido como ITSASOKO AMA)
*(Nota: Fortuna ha sido excluido de esta liga de supervivencia por rendimiento técnico superior).*

---

## 5. SECCIONES OBLIGATORIAS DEL INFORME INDIVIDUAL
1. Cabecera Institucional.
2. Bloque de Condiciones Oceanográficas.
3. Dashboard de Posicionamiento.
4. Momento Clave (Breaking Point).
5. Telemetría de Boga y Ritmos (Sin mencionar marcas comerciales).
6. **CRÓNICA DE LA REGATA** (Con resaltado dinámico).
7. Esquema Visual de la Trainera con Auditoría de Pesos.
8. Pie de Página Institucional.

---

## 6. PROTOCOLO DE GESTIÓN DE GITHUB

> [!CAUTION]
> **PROHIBICIÓN DE ACTUALIZACIÓN AUTÓNOMA**: Queda terminantemente prohibido realizar `git push` sin autorización previa.

---
*Última actualización: 30/04/2026 - Consolidación Estándar v4.6 (Nuevo Motor HCP y Paridad Biomecánica)*
