---
description: Genera un informe profesional en HTML con los resultados del análisis de Aizburua. Usa colores del club (rojo) y estructura de ficha técnica con tablas comparativas, condiciones oceanográficas y esquema de tripulación.
---

# Generador de Informes Profesionales — Aizburua

Esta habilidad transforma los datos del análisis en un documento visual de alto impacto en formato **HTML**, listo para ser compartido o archivado.

---

## 1. PASO A PASO DEL PROCESO

### PASO 1 — Generación del Informe Individual
El agente debe ejecutar el script principal para la regata específica:
```powershell
pwsh -File ".agents/skills/generador-informes/scripts/generar_informe.ps1" -RegataName "[Nombre_Regata]"
```

### PASO 2 — Estudio de Evolución (Temporada)
Tras cada regata, se debe actualizar el informe histórico de la temporada:
```powershell
pwsh -File ".agents/skills/generador-informes/scripts/generar_comparativa.ps1" -RegataName "[Nombre_Regata]"
```

---

## 2. ESTÁNDARES TÉCNICOS Y VISUALES (v2.6)

### 2.1 Regla de Codificación Inquebrantable
> [!IMPORTANT]
> **REGLA DE CODIFICACIÓN**: Para cualquier salida HTML generada por los scripts `.ps1`, es MANDATORIO el uso de entidades HTML para caracteres no-ASCII (ej: `&aacute;`, `&ntilde;`, `&ordm;`). NUNCA usar acentos literales en el código del script que se inyecta en el HTML final.

### 2.2 Identidad Corporativa (Protocolo de Estilo v3.0)
1. **Logos**: Integrar `Logo1.jpg` (Escudo) en cabecera y `Logo2.jpg` en pie de página.
2. **Estilo Cabecera (Header)**:
   - Altura: `75px`.
   - Efecto: `filter: drop-shadow(0 2px 8px rgba(0,0,0,0.4))`.
   - Espaciado: `gap: 20px`.
3. **Estilo Pie de Página (Footer)**:
   - Altura: `45px`.
   - Efecto: `filter: grayscale(1) brightness(3)`, `opacity: 0.8`.
4. **Portabilidad**: Las imágenes DEBEN convertirse a **Base64** dentro del script para que el HTML sea un archivo único autónomo.
5. **Colores**: Rojo Aizburua `#C0001A`, fondo oscuro `#1a1a2e`.

### 2.3 Métricas de Eficiencia
- **MpP**: No usar el término "Nulo"; usar **"Crítico"** o **"Insuficiente"**.
- **Lógica de Ritmo**: No asumir agotamiento por defecto; contrastar con las condiciones del campo.

### 2.4 Resiliencia Estructural y Arquitectura Agnóstica
- **Renderizado N-Calles**: La disposición HTML de "Micro-Topografía" y cálculos estadísticos deben iterar dinámicamente sobre la propiedad `geometria` del origen (soportando N calles y Contrareloj). No hardcodear elementos a 2 columnas.
- **Sintaxis PowerShell Defensiva**: Queda prohibido el uso de asignaciones sobre condicionales directas (ej: `$a = if(x){1}`). Toda la lógica condicional empleará bloques estándar para evitar fallos de parser genéricos (`NullArrayIndex` o errores de motor). No forzar `Set-StrictMode`.
- **Topografía Dinámica**: La narrativa térmica y el esfuerzo físico deben deducirse mediante Regex evaluando las etiquetas de orografía (ej. `-match "rio|canal|exterior"` vs `"playa|protegida"`).

---

## 3. NORMAS DE VISUALIZACIÓN DE NOMBRES (OBLIGATORIO)

> [!IMPORTANT]
> Estas reglas son INMUTABLES y se aplican a AMBOS scripts (`generar_informe.ps1` y `generar_comparativa.ps1`).

### 3.1 Nombres Siempre en MAYÚSCULAS
Todos los nombres y apodos de remeros deben mostrarse en **mayúsculas absolutas** en el HTML. Esto se garantiza aplicando `.ToUpper()` sobre `$displayName` en el `return` de la función `Get-RowerInfo` / `Get-RowerFullInfo`:
```powershell
# CORRECTO
DisplayName = $displayName.ToUpper()

# INCORRECTO — PROHIBIDO
DisplayName = $displayName
```
Ejemplos resultantes: `GizonTxiki` → **GIZONTXIKI** | `Fer` → **FER** | `Potxe` → **POTXE**

---

## 4. NORMAS ESPECÍFICAS DEL INFORME COMPARATIVO (`generar_comparativa.ps1`)

### 4.1 Header — Fecha de la Regata (no fecha de generación)
La esquina superior derecha del header DEBE mostrar la **fecha de la regata** (`$regata.fecha`), NO la fecha/hora de generación del documento.

```powershell
# CORRECTO
"<strong style='font-size:18px'>" + $regata.fecha + "</strong>"

# INCORRECTO — PROHIBIDO
"Ultima Actualizaci&oacute;n<br><strong style='font-size:18px'>" + (Get-Date -Format "dd/MM/yyyy HH:mm") + "</strong>"
```

### 4.2 Footer — Sin número de versión
El pie de página SOLO debe mostrar el nombre institucional del club, SIN número de versión:

```powershell
# CORRECTO
"<p>CLUB AIZBURUA &mdash; SISTEMA DE AN&Aacute;LISIS ESTRAT&Eacute;GICO</p>"

# INCORRECTO — PROHIBIDO
"<p>CLUB AIZBURUA &mdash; SISTEMA DE AN&Aacute;LISIS ESTRAT&Eacute;GICO &mdash; V2.8</p>"
```

### 4.3 Alertas de Desequilibrio Local — Tarjetas Visuales
La sección de alertas NO usa `<ul><li>`. Cada alerta se renderiza como una **tarjeta individual** con fondo y borde de color:

```powershell
# CORRECTO
$alertHtml = $benchAlerts | ForEach-Object {
    "<div style='background:#fff0f2; border-left:4px solid #e11d48; padding:14px 18px; border-radius:8px; font-size:15px; line-height:1.5'>$_</div>"
}
$h.Add("<div style='display:flex; flex-direction:column; gap:12px; margin-top:8px'>" + ($alertHtml -join "") + "</div>")

# INCORRECTO — PROHIBIDO
$h.Add("<ul>" + ($benchAlerts | ForEach-Object { "<li>$_</li>" } | Out-String) + "</ul>")
```

#### 4.4 Motor de Análisis Puesto a Puesto (v4.0 — Realidad Aizburua)

> [!IMPORTANT]
> La tabla "Diagnóstico de la Estructura de Poder" tiene **7 columnas obligatorias**: Puesto | Lado | Titular | Perfil Completo | Exp.(a) | Análisis Táctico | Mejor Alternativa de Plantilla.

#### `Get-RowerFullInfo` — Modelo de Datos (7 campos)
Retorna: `DisplayName` (MAYÚSCULAS), `ImgBase64`, `Peso` (kg), `Altura` (cm), `Anios` (experiencia remo), `Genero` ("Hombre"/"Mujer"), `ExpNivel` ("Alta"/"Media-Alta"/"Media"/"Baja"/"Nuevo").

#### `Get-HcpSeconds` — Contribución al HCP del Bote (v4.0)
> [!IMPORTANT]
> Solo computan remeros **≥45 años**. Bajo 45, la aportación es **0** independientemente del género.
*   **Escala ABE:** 45-49: 2s | 50-54: 4s | 55-59: 7s | 60-64: 10s | 65-69: 14s | 70+: 18s.
*   **Mujer ≥45:** +5s adicionales.

#### `Test-PositionFit` — Matriz de Auditoría Biomecánica
Detecta si un puesto está **mal cubierto**. Criterios basados en la Base de Conocimiento:

| Zona | Criterio de FALLO (Alerta) | Justificación Técnica |
|------|---------------------------|-----------------------|
| **B1 (Popa)** | Edad < 45 ó Peso > 85kg ó Altura < 1.70m | Estabilidad neurológica y arco 110° |
| **B2 (Contram.)** | Peso < 75 kg ó Peso > 88 kg | Tracción reactiva (más fuerte que B1) |
| **B3-4 (Motor)** | Altura < 1.76m ó Peso < 75kg ó Edad > 65 | Pérdida de palanca vectorial (r=0.67) |
| **B6 (Estreles)** | Hombre en el puesto (si hay mujeres) ó Peso > 80kg | Optimización de trimado y planeo |
| **B7 (Proel)** | Peso > 75 kg | Riesgo de Pitching (cabeceo) |

#### `Get-BestAlternative` — Sistema de Scoring (0-100 pts)
1. **Depósito Neurológico (Máx 50):** `(años × 2) + BonusNivel` (Alta/Elite:20, M-Alta:15, Media:10, Baja:5).
2. **Biotipo Documental (Máx 25):** Ajuste a los rangos ideales de peso/altura de la zona. (+15 bonus Mujer en B6).
3. **Eficiencia HCP (Máx 25):** `(Delta Segundos HCP) × 2.5`.

> [!CAUTION]
> **Umbral de Calidad**: Si ningún candidato supera los **15 pts** en el Depósito Neurológico, el sistema NO sugerirá ningún reajuste para evitar retrocesos técnicos.

---

## 5. SECCIONES OBLIGATORIAS DEL INFORME INDIVIDUAL (Orden)
1. Cabecera Institucional.
2. Bloque de Condiciones Oceanográficas.
3. Dashboard de Posicionamiento (Oficial, Normalizada, Proyectada, Raw).
4. Lucha por la Permanencia (PlayOFF).
5. Momento Clave (Breaking Point).
6. Comparativa Pro (vs Ganador/Podio).
7. Telemetría de Boga y Ritmos Garmin.
8. Diagnóstico Termomecánico Segmentado.
9. Perfil de Edad Triple (Popa, Centro, Proa).
10. Esquema Visual de la Trainera.
11. Pie de Página Institucional.

---

## 6. PROTOCOLO DE GESTIÓN DE GITHUB (REGLA DE ORO)

> [!CAUTION]
> **PROHIBICIÓN DE ACTUALIZACIÓN AUTÓNOMA**: El agente tiene estrictamente PROHIBIDO realizar operaciones de `git push` o `git remote update` sin la autorización previa y explícita del usuario.

### Procedimiento obligatorio:
1. Realizar los cambios en local.
2. Informar al usuario de las modificaciones realizadas.
3. Solicitar permiso: "¿Deseas que suba estos cambios a GitHub?".
4. Ejecutar el push ÚNICAMENTE tras recibir confirmación afirmativa.
