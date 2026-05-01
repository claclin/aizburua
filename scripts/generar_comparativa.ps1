param(
    [string]$RegataName = "Getxo"
)

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$dataPath = "$root\data"
$informesPath = "$root\informes"
$remerosImgPath = "$root\remeros"

# Importar datos
$historico = Get-Content "$dataPath\historico-regatas.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$remerosDB = Get-Content "$dataPath\plantilla_remeros.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$regata = $historico.regatas | Where-Object { $_.nombre_corto -eq $RegataName }

if (-not $regata) {
    Write-Error "Regata no encontrada."
    return
}

$aiz = $regata.aizburua
$ali = $aiz.alineacion
$meteoGeneral = $regata.condiciones_campo
$evolucion = $meteoGeneral.evolucion_meteo

# Buscar condiciones especificas
$horaBoga = $aiz.hora_salida
$meteoReal = $evolucion | Where-Object { $_.hora -eq $horaBoga -or $_.desc -match "Aizburua" } | Select-Object -First 1
if (-not $meteoReal) { $meteoReal = $meteoGeneral }

$regataIndex = 0
for ($i=0; $i -lt $historico.regatas.Count; $i++) {
    if ($historico.regatas[$i].nombre_corto -eq $RegataName) {
        $regataIndex = $i + 1
        break
    }
}

# --- L&oacute;gica de Fotos y Nombres ---
function Get-RowerFullInfo([string]$name, [string]$posicion) {
    $displayName = $name
    $cleanName = $name.Replace(".", "").Trim()
    if ($cleanName -ieq "Gorka") { $displayName = "GizonTxiki" }
    elseif ($cleanName -ieq "JAntonio" -or $cleanName -ieq "JANTONIO" -or $cleanName -ieq "J.ANTONIO") { $displayName = "Potxe" }
    elseif ($cleanName -ieq "FJavier") { $displayName = "Jabier" }
    elseif ($cleanName -ieq "Fernando") { $displayName = "Fer" }
    elseif ($cleanName -ieq "I&ntilde;aki" -or $cleanName -ieq "I&ntilde;aki") { $displayName = "I&ntilde;aki" }
    if ($cleanName -ieq "Maite") {
        if ($posicion -eq "Babor") { $displayName = "Maite Zarra" }
        else { $displayName = "Maite" }
    }
    
    # Buscar en DB para m&eacute;tricas con l&oacute;gica flexible
    $rower = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $cleanName -or $_.apodo -ieq $cleanName } | Select-Object -First 1
    $peso = 0.0 ; $altura = 0 ; $anios = 0 ; $genero = "Hombre" ; $expNivel = ""
    if ($rower) {
        try {
            if ($rower.PSObject.Properties['altura_cm'] -and $rower.altura_cm -match '^\d') { $altura = [double]$rower.altura_cm }
            if ($rower.PSObject.Properties['peso_kg'] -and $rower.peso_kg -match '^\d') { $peso = [double]$rower.peso_kg }
            if ($rower.PSObject.Properties['genero'] -and $rower.genero) { $genero = $rower.genero }
            if ($rower.PSObject.Properties['experiencia'] -and $rower.experiencia) { $expNivel = $rower.experiencia }
            $propAnios = $rower.PSObject.Properties | Where-Object { $_.Name -match 'experiencia' -and ($_.Name -match 'a.os' -or $_.Name -match 'anios') } | Select-Object -First 1
            if ($propAnios -and ($propAnios.Value -as [double] -ge 0)) { $anios = [double]$propAnios.Value }
        } catch { }
    }

    $imgBase64 = ""
    $possibleFiles = @("$displayName.jpg", "$cleanName.jpg", "$name.jpg", "I&ntilde;aki.jpg")
    foreach ($f in $possibleFiles) {
        $path = Join-Path $remerosImgPath $f
        if (Test-Path $path) {
            $bytes = [System.IO.File]::ReadAllBytes($path)
            $imgBase64 = [Convert]::ToBase64String($bytes)
            break
        }
    }
    # --- Perfil Est&aacute;ndar para Datos Nulos (v4.2) ---
    if ($peso -le 0)   { $peso = 78.0 }   # Peso est&aacute;ndar Aizburua
    if ($altura -le 0) { $altura = 175 }  # Altura est&aacute;ndar Aizburua

    return [PSCustomObject]@{
        DisplayName = $displayName.ToUpper()
        ImgBase64   = $imgBase64
        Peso        = $peso
        Altura      = $altura
        Anios       = $anios
        Genero      = $genero
        ExpNivel    = $expNivel
    }
}

# --- MOTOR DE HANDICAPS ABE (v4.5) ---
# Basado en handicaps.jpg y Protocolo v4.4
# La Ec se calcula sobre la media de TODOS los miembros del bote.
# Si la media < 45, el HCP de tabla es 0. Adicionalmente, se suman +5s
# por cada mujer >= 45 anios en la alineacion (bonificacion ABE de genero).
function Get-HcpFromTable([double]$avg, [int]$distanciaM, [int]$numMujeres45) {
    # Usar Floor para consultar la tabla de handicaps.jpg
    $v = [math]::Floor($avg)
    
    # Tabla basada en handicaps.jpg (base 3500m)
    $tabla = @{
        45=0; 46=1; 47=2; 48=3; 49=4; 50=6; 51=8; 52=10; 53=12; 54=14; 55=16; 56=19; 57=22; 58=25; 59=28; 60=31;
        61=35; 62=39; 63=43; 64=47; 65=51
    }

    $hcpTabla = if ($v -ge 45 -and $tabla.ContainsKey([int]$v)) { $tabla[[int]$v] } elseif ($v -ge 65) { 50 + ($v - 65) * 4 } else { 0 }
    $baseHcp = if ($v -ge 45 -and $tabla.ContainsKey([int]$v)) { $tabla[[int]$v] } elseif ($v -ge 65) { 50 + ($v - 65) * 4 } else { 0 }
    
    # Sumar bonificacion de genero: +5s PLANOS por cada mujer >= 45 en la alineacion
    $bonusGenero = $numMujeres45 * 5
    
    # Multiplicador por tramos oficiales (Anexo H&aacute;ndicaps Aplicables)
    $coef = 1.0
    if ($distanciaM -ge 4376) { $coef = 1.40 }
    elseif ($distanciaM -ge 4251) { $coef = 1.35 }
    elseif ($distanciaM -ge 4126) { $coef = 1.30 }
    elseif ($distanciaM -ge 4001) { $coef = 1.25 }
    elseif ($distanciaM -ge 3876) { $coef = 1.20 }
    elseif ($distanciaM -ge 3751) { $coef = 1.15 }
    elseif ($distanciaM -ge 3626) { $coef = 1.10 }
    elseif ($distanciaM -ge 3501) { $coef = 1.05 }
    elseif ($distanciaM -ge 3401) { $coef = 1.00 }
    elseif ($distanciaM -ge 3301) { $coef = 0.95 }
    elseif ($distanciaM -ge 3201) { $coef = 0.90 }
    elseif ($distanciaM -ge 3101) { $coef = 0.85 }
    elseif ($distanciaM -ge 3000) { $coef = 0.80 }
    elseif ($distanciaM -ge 2875) { $coef = 0.75 }
    elseif ($distanciaM -ge 2750) { $coef = 0.70 }
    elseif ($distanciaM -ge 2625) { $coef = 0.65 }
    elseif ($distanciaM -ge 2500) { $coef = 0.60 }
    else { $coef = ($distanciaM / 3500) } # Fallback lineal para distancias extremas
    
    # Formula oficial v6.5: (Base + Bonus) * Coeficiente de Tramo
    $totalSeconds = ($baseHcp + $bonusGenero) * $coef
    return [math]::Round($totalSeconds, 1)
}

# Convierte nivel cualitativo de experiencia a puntos (Deposito Neurologico - v4.0)
# Valores extraidos de plantilla_remeros.json: Alta, Media - Alta, Media, Baja, Nuevo
function Get-ExpNivelPts([string]$nivel) {
    if ($nivel -match "Elite|&Eacute;lite")                        { return 20 }
    if ($nivel -match "Alta" -and $nivel -notmatch "Media") { return 20 }  # "Alta" puro
    if ($nivel -match "Media.*Alta|Alta.*Media")            { return 15 }  # "Media - Alta"
    if ($nivel -match "Media")                              { return 10 }  # "Media" puro
    if ($nivel -match "Baja")                               { return 5  }
    return 0  # "Nuevo" o sin dato
}

# --- BANCO DE CONOCIMIENTO DIN&Aacute;MICO (v3.0) ---
$knowledgePool = @(
    @{ Title = "El Dimorfismo Sexual como Ventaja"; Content = "La inclusi&oacute;n de la mujer no es solo una cuesti&oacute;n de h&aacute;ndicap. La mejora en la <strong>relaci&oacute;n potencia/peso</strong> reduce radicalmente la superficie mojada del bote de 200kg, mejorando la <strong>fluidez hidrodin&aacute;mica</strong>." },
    @{ Title = "La Regla de los 45 A&ntilde;os"; Content = "El sistema ABE se activa a los 45 a&ntilde;os. A partir de esa edad, la bonificaci&oacute;n en segundos <strong>compensa matem&aacute;ticamente</strong> el declive natural de la fuerza absoluta, optimizando el tiempo neto." },
    @{ Title = "Biomec&aacute;nica del Banco Fijo"; Content = "En la trainera, el <strong>tronco y los brazos generan el 60% de la potencia</strong>. El modelo ideal exige mantener un <strong>arco de palada de 110 grados</strong> para maximizar la palanca real de 3.25m." },
    @{ Title = "Sincron&iacute;a Hidrodin&aacute;mica"; Content = "El <strong>85% de la resistencia es agua</strong>. La <strong>limpieza en la entrada y salida</strong> de la pala es m&aacute;s rentable t&aacute;cticamente que elevar la frecuencia de palada de forma desordenada." },
    @{ Title = "Gesti&oacute;n de la Acidosis"; Content = "En regatas de 12 minutos, el pH sangu&iacute;neo cae a niveles de 6.74. La estrategia debe priorizar la <strong>econom&iacute;a de movimiento</strong> para mitigar el impacto del lactato en el tramo final." },
    @{ Title = "La Talla como Predictor de Poder"; Content = "Existe una correlaci&oacute;n cr&iacute;tica (<strong>r = 0.67</strong>) entre la estatura y los vatios absolutos. Priorizar remeros altos en el bloque motor (B3-5) es vital para vencer la inercia inicial." },
    @{ Title = "S7 vs IMC en Veteranos"; Content = "El <strong>Sumatorio de 7 pliegues (S7)</strong> es un predictor de rendimiento m&aacute;s fiable que el IMC. Presenta una correlaci&oacute;n negativa (<strong>r = -0.51</strong>) con los vatios relativos." },
    @{ Title = "Prevenci&oacute;n del Pitching"; Content = "Un proel ligero (~70kg) es esencial para que la proa no se 'clave' en el agua. Evitar el cabeceo reduce dr&aacute;sticamente el rozamiento y permite que el bote 'vuele' sobre la ola." },
    @{ Title = "Psicolog&iacute;a del Marcador Master"; Content = "En las bancadas de popa se recomiendan <strong>veteranos (>55 a&ntilde;os)</strong>. Su 'sangre fr&iacute;a' y memoria muscular aseguran un ritmo estable bajo la m&aacute;xima presi&oacute;n competitiva." },
    @{ Title = "Hidrodin&aacute;mica de la Estrecha"; Content = "El mayor volumen de agua desplazada ocurre en las bancadas 3 y 4. Por ello, el <strong>motor central</strong> debe ser el m&aacute;s s&iacute;ncrono para evitar turbulencias que frenen el planeo del bote." },
    @{ Title = "Recuperaci&oacute;n Master: Power Naps"; Content = "En tripulaciones veteranas, el descanso es entrenamiento. Una siesta corta antes de embarcar puede mejorar el rendimiento en un <strong>15%</strong> en sesiones de Potencia Aer&oacute;bica M&aacute;xima (PAM)." },
    @{ Title = "El Secreto del Hankaleku"; Content = "La distancia entre la bancada y la tabla de pies (hankaleku) debe ajustarse milim&eacute;tricamente seg&uacute;n la <strong>longitud femoral</strong> para maximizar la palanca hidrodin&aacute;mica." }
)
$selectedKnowledge = $knowledgePool | Get-Random -Count 4

# --- ANALISIS ---
$edadesReales = @()
$edadesComputo = @()
$numMujeres45 = 0
$pesosBabor = @() ; $pesosEstribor = @() ; $pesosTotal = @()
$tallasMotor = @() ; $tallasExtremos = @()

function Process-Rower($nombre, $pos, $side, $edad) {
    if ($edad) {
        $script:edadesReales += $edad
        $script:edadesComputo += $edad   # todos cuentan en la media para el HCP
        # Detectar mujeres >= 45 para bonificacion ABE de genero
        if ($edad -ge 45) {
            $r = $remerosDB | Where-Object { $_.nombre -eq $nombre } | Select-Object -First 1
            if ($r -and $r.genero -match "Mujer") { $script:numMujeres45++ }
        }
    }
    $info = Get-RowerFullInfo $nombre $pos
    if ($info.Peso -gt 0) { 
        $script:pesosTotal += $info.Peso
        if ($side -eq "Babor") { $script:pesosBabor += $info.Peso }
        elseif ($side -eq "Estribor") { $script:pesosEstribor += $info.Peso }
    }
    if ($info.Altura -gt 0) {
        if ($pos -match "3|4|5") { $script:tallasMotor += $info.Altura }
        else { $script:tallasExtremos += $info.Altura }
    }
}

Process-Rower $ali.proa.nombre "Proa" "Proa" $ali.proa.edad
Process-Rower $ali.patron.nombre "Patron" "Patron" $ali.patron.edad
foreach ($n in 1..6) {
    Process-Rower $ali.bancadas."$n".B.nombre "Bancada $n" "Babor" $ali.bancadas."$n".B.edad
    Process-Rower $ali.bancadas."$n".E.nombre "Bancada $n" "Estribor" $ali.bancadas."$n".E.edad
}

$avgEdadReal = if ($edadesReales.Count -gt 0) { ($edadesReales | Measure-Object -Average).Average } else { 0 }
$avgOficial = $avgEdadReal
$distanciaRegata = if ($regata.distancia_m) { $regata.distancia_m } else { 3500 }

$totalPeso = ($pesosTotal | Measure-Object -Sum).Sum
$totalBabor = ($pesosBabor | Measure-Object -Sum).Sum
$totalEstribor = ($pesosEstribor | Measure-Object -Sum).Sum
$difPeso = $totalBabor - $totalEstribor
$avgTallaMotor = if ($tallasMotor.Count -gt 0) { ($tallasMotor | Measure-Object -Average).Average } else { 0 }
$avgTallaExt = if ($tallasExtremos.Count -gt 0) { ($tallasExtremos | Measure-Object -Average).Average } else { 0 }

# --- CARGA DE LOGOTIPOS ---
$logo1Base64 = "" ; $logo2Base64 = ""
$logo1Path = Join-Path $root "Logo1.jpg"
$logo2Path = Join-Path $root "Logo2.jpg"

if (Test-Path $logo1Path) {
    $bytes = [System.IO.File]::ReadAllBytes($logo1Path)
    $logo1Base64 = [System.Convert]::ToBase64String($bytes)
}
if (Test-Path $logo2Path) {
    $bytes = [System.IO.File]::ReadAllBytes($logo2Path)
    $logo2Base64 = [System.Convert]::ToBase64String($bytes)
}

# --- GENERACION HTML ---
$htmlFile = "$informesPath\Comparativa_Optimizacion_$RegataName.html"
$h = [System.Collections.Generic.List[string]]::new()
$script:usedPhrases = @{}  # Tracking para unicidad absoluta v5.5
$script:seatsNeedingCascade = @()  # Tracking dinamico de asientos que requieren cascada

$h.Add("<!DOCTYPE html><html lang='es'><head><meta charset='UTF-8'><title>Estudio de Evoluci&oacute;n - Aizburua</title>")
$h.Add("<style>
    :root { --r: #C0001A; --b: #1a1e2e; --w: #ffffff; --lg: #f3f4f6; }
    body { font-family: 'Inter', -apple-system, sans-serif; background: #e5e7eb; margin: 0; color: #1e293b; }
    .header { background: linear-gradient(90deg, #0b1120 0%, #1e293b 100%); color: white; padding: 40px 60px; border-bottom: 6px solid var(--r); display: flex; justify-content: space-between; align-items: center; }
    .header-logo { display: flex; align-items: center; gap: 20px; }
    .logo-header { height: 75px; width: auto; filter: drop-shadow(0 2px 8px rgba(0,0,0,0.4)); }
    .logo-footer { height: 45px; width: auto; opacity: 0.8; filter: grayscale(1) brightness(3); }
    .header-title h1 { margin: 0; font-size: 32px; text-transform: uppercase; letter-spacing: 3px; font-weight: 900; }
    .header-title p { margin: 5px 0 0; font-size: 14px; opacity: 0.8; letter-spacing: 2px; }
    .main { padding: 40px; width: 95%; max-width: 1600px; margin: 0 auto; }
    .metric-row { display: grid; grid-template-columns: repeat(4, 1fr); gap: 25px; margin-bottom: 40px; }
    .metric-card { background: white; border-radius: 15px; padding: 35px; border-top: 8px solid var(--r); box-shadow: 0 4px 25px rgba(0,0,0,0.1); }
    .m-label { font-size: 12px; font-weight: 800; color: #64748b; text-transform: uppercase; margin-bottom: 12px; }
    .m-value { font-size: 42px; font-weight: 900; color: #0f172a; }
    .section-title { font-size: 24px; font-weight: 900; margin: 80px 0 30px; text-transform: uppercase; border-left: 8px solid var(--r); padding-left: 25px; color: #1e293b; }
    .card-table { background: white; border-radius: 15px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.15); width: 100%; margin-bottom: 40px; }
    table { width: 100%; border-collapse: collapse; }
    thead th { background: #1e293b; color: white; text-align: left; padding: 25px; font-size: 13px; text-transform: uppercase; letter-spacing: 1.5px; }
    tbody td { padding: 25px; border-bottom: 1px solid #f1f5f9; font-size: 17px; vertical-align: middle; }
    .rower-info { display: flex; align-items: center; gap: 20px; }
    .avatar { width: 80px; height: 80px; border-radius: 12px; object-fit: cover; background: #eee; border: 2px solid #ddd; }
    .r-name { font-weight: 900; color: #0f172a; font-size: 18px; text-transform: uppercase; }
    .badge { padding: 6px 15px; border-radius: 6px; font-size: 12px; font-weight: 900; text-transform: uppercase; }
    .b-bab { background: #e0f2fe; color: #0369a1; }
    .b-est { background: #dcfce7; color: #15803d; }
    .lit-text { font-size: 18px; line-height: 1.6; color: #334155; font-weight: 500; text-align: justify; }
    .legend-box { background: #1e293b; color: white; border-radius: 15px; padding: 35px; margin: 30px 0 60px; display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 30px; }
    .legend-item b { color: var(--r); display: block; margin-bottom: 8px; font-size: 15px; text-transform: uppercase; letter-spacing: 1px; }
    .legend-item p { margin: 0; font-size: 14px; opacity: 0.9; line-height: 1.4; text-align: justify; }
    .clima-grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 20px; margin-bottom: 30px; }
    .clima-item { background: white; padding: 20px; border-radius: 12px; border-top: 5px solid #cbd5e1; }
    .clima-item.active { border-top-color: #0ea5e9; background: #f0f9ff; }
    .clima-item h4 { margin: 0 0 10px; text-transform: uppercase; font-size: 14px; color: #64748b; }
    .clima-item p { margin: 0; font-size: 14px; line-height: 1.4; color: #1e293b; }
    .benchmark-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-top: 20px; }
    .bench-card { background: #f8fafc; padding: 15px; border-radius: 10px; border-left: 4px solid #cbd5e1; font-size: 14px; }
    .bench-card.winner { border-left-color: #f59e0b; background: #fffbeb; }
    .foundation-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 25px; margin-bottom: 25px; }
    .foundation-card { background: white; padding: 30px; border-radius: 15px; box-shadow: 0 4px 20px rgba(0,0,0,0.05); border-left: 10px solid var(--r); display: flex; flex-direction: column; width: 100%; box-sizing: border-box; }
    .foundation-card.full-width { grid-column: 1 / -1; }
    .foundation-card h3 { color: var(--b); margin-top: 0; font-size: 20px; text-transform: uppercase; border-bottom: 2px solid #f1f5f9; padding-bottom: 10px; margin-bottom: 15px; }
    .foundation-card p { font-size: 16px; line-height: 1.6; color: #475569; text-align: justify; margin: 0; }
    .opt-box { background: #fff0f2; border: 2px solid var(--r); border-radius: 15px; padding: 35px; margin-bottom: 40px; width: 100%; box-sizing: border-box; }
    .tactical-alert { background: #fef2f2; border-left: 6px solid var(--r); padding: 16px 20px; border-radius: 8px; margin-top: 15px; color: #991b1b; font-size: 15px; font-weight: 500; line-height: 1.6; display: flex; align-items: flex-start; gap: 14px; box-shadow: 0 2px 10px rgba(192, 0, 26, 0.08); }
    .alert-icon { flex-shrink: 0; margin-top: 2px; }
    .footer { background: #0f172a; color: white; padding: 80px; text-align: center; margin-top: 100px; border-top: 15px solid var(--r); }
</style></head><body>")

# HEADER
$logo1Html = if ($logo1Base64) { "<img src='data:image/jpeg;base64,$logo1Base64' class='logo-header' alt='Aizburua'>" } else { "<div style='width:70px;height:70px;background:var(--r);border-radius:10px;display:flex;align-items:center;justify-content:center;font-weight:900;font-size:30px'>A</div>" }
$h.Add("<div class='header'><div class='header-logo'>$logo1Html <div class='header-title'><h1>Estudio de Evoluci&oacute;n</h1><p>CLUB AIZBURUA &mdash; TEMPORADA 2026</p></div></div><div style='text-align:right'><strong style='font-size:18px'>" + $regata.lugar + " &mdash; " + $regata.fecha + "</strong></div></div>")

$h.Add("<div class='main'>")

# METRICAS
$velKmh = if ($aiz.analisis.datos_garmin.velocidad_media_kmh) { $aiz.analisis.datos_garmin.velocidad_media_kmh } else { 0 }
$ritmo  = if ($aiz.analisis.datos_garmin.ritmo_medio) { $aiz.analisis.datos_garmin.ritmo_medio } else { "-" }

$h.Add("<div class='metric-row'><div class='metric-card'><div class='m-label'>Regatas Analizadas</div><div class='m-value'>$regataIndex</div></div><div class='metric-card'><div class='m-label'>Ritmo Medio Bote</div><div class='m-value'>$ritmo</div></div><div class='metric-card'><div class='m-label'>Velocidad Media</div><div class='m-value'>$velKmh km/h</div></div>
<div class='metric-card'><div class='m-label'>Edad Media Aizburua</div><div class='m-value'>$([math]::Round($avgEdadReal,1))</div></div>
</div>")

# COMPARATIVA CLIMATOLOGICA
$h.Add("<div class='section-title' style='margin-top:0'>Evoluci&oacute;n del Campo de Regateo (An&aacute;lisis de Tandas)</div>")
$h.Add("<div class='clima-grid'>")
foreach ($ev in $evolucion) {
    $activeClass = if ($ev.hora -eq $horaBoga -or $ev.desc -match "Aizburua") { " active" } else { "" }
    $title = if ($activeClass) { "Boga Aizburua ($($ev.hora)h)" } else { "$($ev.desc) ($($ev.hora)h)" }
    $h.Add("<div class='clima-item$activeClass'><h4>$title</h4><p>Viento: <strong>$($ev.viento_kmh) km/h ($($ev.viento_dir))</strong><br>Ola: <strong>$($ev.ola_m)m</strong><br>Corriente: <strong>$($ev.corriente)</strong></p></div>")
}
$h.Add("</div>")

# LEYENDA T&Eacute;CNICA (Base Conocimiento Aizburua)
$script:usedPhrases = @{}  # Inicializaci&oacute;n cr&iacute;tica para unicidad
$h.Add("<div class='section-title'>Leyenda de Conceptos T&eacute;cnicos Avanzados</div><div class='legend-box'>
    <div class='legend-item'><b>PAM (Potencia Aer&oacute;bica M&aacute;xima)</b><p>Capacidad del remero para sostener vatios de alta intensidad. Un PAM elevado es el motor que permite mantener el bote por encima de los 14 km/h en tramos de boga plana sin ayuda de corriente.</p></div>
    <div class='legend-item'><b>Masa Inercial (Efecto Volante)</b><p>Biomec&aacute;nica aplicada a remeros veteranos de gran peso (>85kg). Su masa act&uacute;a como un acumulador de energ&iacute;a cin&eacute;tica (momentum), compensando la p&eacute;rdida de explosividad natural con la edad y estabilizando el planeo entre paladas.</p></div>
    <div class='legend-item'><b>S7 (Sumatorio 7 Pliegues)</b><p>Indicador de composici&oacute;n corporal. Un S7 optimizado asegura que el peso del remero es masa muscular activa, maximizando la relaci&oacute;n potencia/peso fundamental en competiciones de largo aliento.</p></div>
    <div class='legend-item'><b>MPP (Metros Por Palada)</b><p>M&eacute;trica de eficiencia t&eacute;cnica absoluta. Indica el avance neto del casco por cada ciclo. Valores de 10.5m o superiores indican una transmisi&oacute;n de potencia impecable y una hidrodin&aacute;mica de excelencia.</p></div>
</div>")

# FUNDAMENTOS
$h.Add("<div class='section-title'>Fundamentos del Modelo de Rendimiento</div><div class='foundation-grid'>")
foreach ($k in $selectedKnowledge) { $h.Add("<div class='foundation-card'><h3>$($k.Title)</h3><p>$($k.Content)</p></div>") }
$h.Add("</div>")

# COMPARATIVA DE MASAS Y TALLA
$h.Add("<div class='section-title'>An&aacute;lisis de Masas y Biometr&iacute;a del Bote</div>")
$h.Add("<div class='metric-row'>")
$h.Add("<div class='metric-card'><div class='m-label'>Peso Total (Tripulaci&oacute;n)</div><div class='m-value'>$totalPeso kg</div></div>")
$h.Add("<div class='metric-card'><div class='m-label'>Equilibrio Babor/Estribor</div><div class='m-value'>" + [math]::Round($difPeso, 1) + " kg</div></div>")
$h.Add("<div class='metric-card'><div class='m-label'>Talla Media Bloque Motor</div><div class='m-value'>" + [math]::Round($avgTallaMotor, 1) + " cm</div></div>")
$h.Add("<div class='metric-card'><div class='m-label'>Talla Media Extremos</div><div class='m-value'>" + [math]::Round($avgTallaExt, 1) + " cm</div></div>")
$h.Add("</div>")

# DIAGNOSTICO DE PODER
$h.Add("<div class='section-title'>1. Diagn&oacute;stico de la Estructura de Poder</div>")
$h.Add("<div class='card-table'><table><thead><tr><th>Puesto</th><th>Lado</th><th>Titular</th><th>Perfil Completo</th><th>Exp.(a)</th><th>An&aacute;lisis T&aacute;ctico</th><th>Mejor Alternativa de Plantilla</th></tr></thead><tbody>")

    # Icono SVG para alertas (Seguro contra errores de codificacion)
    $svgIcon = "<svg class='alert-icon' width='22' height='22' viewBox='0 0 24 24' fill='none' stroke='#C0001A' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'><path d='M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z'></path><line x1='12' y1='9' x2='12' y2='13'></line><line x1='12' y1='17' x2='12.01' y2='17'></line></svg>"

    # Inicializaci&oacute;n del rastreador de frases &uacute;nicas para evitar repeticiones en todo el informe
    $script:usedPhrases = @{}

function Get-OptLiterature($pos, $age, $name, $side) {
    $info = Get-RowerFullInfo $name $side
    $displayName = $info.DisplayName
    
    if ($pos -eq "PATRON") {
        return "<strong>Director de Orquesta:</strong> Liderazgo y estrategia.<br><strong>Elecci&oacute;n:</strong> $displayName marca el rumbo y gestiona la energ&iacute;a del equipo.<br><strong>Impacto:</strong> Base del h&aacute;ndicap del bote."
    }

    # --- MOTOR DE NARRATIVA DIN&Aacute;MICA v6.2 ---
    $pool = @{
        Popa = @{
            Veteran = @{
                Subs = @("Maestr&iacute;a en Sincron&iacute;a de Popa", "Memoria Muscular y Control de Ritmo", "Sincron&iacute;a R&iacute;tmica de Alta Competici&oacute;n", "Gesti&oacute;n T&aacute;ctica de la Fatiga Master", "Arquitectura R&iacute;tmica de Popa", "Vig&iacute;a de Cadencia y Estabilidad", "Regulador de Tensi&oacute;n Cinem&aacute;tica", "Metr&oacute;nomo Biomec&aacute;nico de Popa", "Estratega de Tracci&oacute;n Sostenida", "Pilar de Referencia R&iacute;tmica", "Liderazgo Biomec&aacute;nico Master", "Sensor de Ritmo y Estabilidad", "Estratega de Marca en Popa", "Referente de Cohesi&oacute;n T&aacute;ctica", "Anclaje de Sincron&iacute;a Master")
                Elections = @(
                    "$displayName es el anclaje r&iacute;tmico de la popa, proyectando una cadencia que unifica a toda la bancada mediante una pausa t&eacute;cnica en el recobro que maximiza el deslizamiento hidrodin&aacute;mico del casco.",
                    "$displayName lidera el pulso desde la marca, utilizando su memoria muscular para mantener una transmisi&oacute;n de potencia limpia y constante, evitando micro-frenadas que penalicen el avance entre paladas r&iacute;tmicas.",
                    "$displayName estabiliza el bloque trasero con $($info.Altura)cm de palanca, permitiendo un arco de palada de 110 grados que sirve de referencia visual absoluta para la coordinaci&oacute;n s&iacute;ncrona de su banda.",
                    "$displayName aporta una boga estructurada de popa que act&uacute;a como un filtro cin&eacute;tico, absorbiendo las irregularidades del agua y permitiendo que el motor central descargue su potencia sobre una base estable.",
                    "$displayName utiliza su veteran&iacute;a para modular la intensidad t&aacute;ctica, conservando vatios cr&iacute;ticos para el sprint final mediante una gesti&oacute;n inteligente del lactato y la eficiencia del gesto t&eacute;cnico.",
                    "$displayName asegura que la frecuencia de palada se mantenga inalterable ante cambios en la corriente del r&iacute;o, actuando como un metr&oacute;nomo biomec&aacute;nico que garantiza la fluidez del boga en todo momento.",
                    "$displayName proyecta una tracci&oacute;n profunda y sostenida, minimizando el tiempo de pala al aire y maximizando la presi&oacute;n efectiva sobre el agua, lo que eleva el MPP (Metros por Palada) del conjunto.",
                    "$displayName act&uacute;a como el vig&iacute;a de cadencia en popa, detectando desviaciones en la sincron&iacute;a y corrigiendo el pulso r&iacute;tmico de forma instintiva para mantener el planeo longitudinal del bote.",
                    "$displayName coordina la transmisi&oacute;n de fuerzas en la zona de marca, asegurando que cada vatio generado se traduzca en una proyecci&oacute;n lineal n&iacute;tida, reduciendo el rozamiento por oscilaciones laterales.",
                    "$displayName aporta una madurez t&eacute;cnica que permite leer el estado de la mar desde la popa, ajustando el &aacute;ngulo de entrada de la pala para evitar turbulencias que frenen la velocidad de crucero.",
                    "$displayName gestiona la cadencia con una econom&iacute;a de movimiento magistral, eliminando tensiones innecesarias en los hombros y permitiendo que la energ&iacute;a fluya directamente hacia la pala en el ataque.",
                    "$displayName unifica el vector de fuerza de popa mediante una extensi&oacute;n de brazos milim&eacute;trica, asegurando que el inicio de la tracci&oacute;n sea simult&aacute;neo y equilibrado en ambos lados de la trainera.",
                    "$displayName aporta una solidez neurol&oacute;gica en el marcador, manteniendo la calma t&aacute;ctica en situaciones de m&aacute;xima presi&oacute;n y guiando al equipo con una boga de gran autoridad y limpieza t&eacute;cnica.",
                    "$displayName optimiza el trimado de popa mediante un control preciso del peso en el banco, evitando que el bote se hunda en el ataque y favoreciendo un planeo m&aacute;s prolongado en la fase de recobro.",
                    "$displayName lidera la transici&oacute;n tras la ciaboga con una boga de gran amplitud, facilitando que el bote recupere su velocidad de crucero sin necesidad de realizar paladas cortas y asfixiantes."
                )
                Impacts = @(
                    "Su intervenci&oacute;n en popa compensa la fatiga acumulada mediante una t&eacute;cnica que ahorra vatios par&aacute;sitos, permitiendo que la trainera mantenga su velocidad punta en los tramos de mayor exigencia f&iacute;sica.",
                    "Garantiza que el momentum del bote no decaiga en el tramo final, transformando la veteran&iacute;a en una ventaja biomec&aacute;nica que reduce dr&aacute;sticamente el impacto del &aacute;cido l&aacute;ctico en la calidad de la boga.",
                    "Mitiga el impacto de las corrientes adversas mediante una tracci&oacute;n larga y segura, asegurando que el bote 'pise' con firmeza y no pierda sustentaci&oacute;n hidrodin&aacute;mica en el momento de m&aacute;xima carga.",
                    "Reduce las vibraciones estructurales del casco al unificar el vector de fuerza de su banda, lo que se traduce en un avance m&aacute;s silencioso, eficiente y con menor resistencia al avance frontal.",
                    "Proporciona una base de sustentaci&oacute;n r&iacute;tmica que eleva la eficiencia de los remeros m&aacute;s j&oacute;venes, permitiendo que estos enfoquen su potencia explosiva sobre una referencia de cadencia impecable.",
                    "Minimiza el arrastre par&aacute;sito en la salida de pala, favoreciendo un deslizamiento m&aacute;s prolongado y limpio, indicador clave de una hidrodin&aacute;mica de alto nivel en tripulaciones de veteranos.",
                    "Asegura una entrada de pala silenciosa y reactiva, optimizando la presi&oacute;n hidrodin&aacute;mica desde el inicio del ataque, lo que garantiza una aceleraci&oacute;n constante y fluida en cada ciclo r&iacute;tmico.",
                    "Optimiza el aprovechamiento del h&aacute;ndicap t&aacute;ctico de popa, aportando una solidez que reduce el margen de error bajo fatiga extrema, asegurando que el tiempo final sea el m&aacute;ximo exponente de su potencial.",
                    "Estabiliza el centro de gravedad del bote en el momento del ataque masivo, evitando que la trainera se escore y asegurando que la quilla mantenga su alineaci&oacute;n perfecta con el vector de avance.",
                    "Facilita la transici&oacute;n r&iacute;tmica tras las ciabogas, liderando la recuperaci&oacute;n de la velocidad de crucero con una boga profunda que maximiza el aprovechamiento de la inercia generada por el bloque motor.",
                    "Su t&eacute;cnica de recobro pausado reduce la p&eacute;rdida de velocidad residual, permitiendo que el bote 'corra' m&aacute;s metros entre paladas y mejorando la eficiencia hidrodin&aacute;mica en m&aacute;s de un 3% t&eacute;cnico.",
                    "Asegura que el bote no sufra desaceleraciones bruscas en el tramo final, manteniendo un flujo de agua laminar constante bajo el casco gracias a una boga de gran limpieza y precisi&oacute;n.",
                    "Reduce el estr&eacute;s mec&aacute;nico sobre el tim&oacute;n al proporcionar un empuje sim&eacute;trico y predecible, lo que permite al patr&oacute;n gobernar con mayor suavidad y reducir el rozamiento por correcciones.",
                    "Mejora la respuesta r&iacute;tmica de todo el equipo, actuando como un filtro que elimina las irregularidades del motor central y proyecta una cadencia n&iacute;tida hacia las bancadas delanteras.",
                    "Consigue que el h&aacute;ndicap de edad se traduzca en una ventaja competitiva real, aportando una solidez que permite al equipo mantener ritmos de boga agresivos con un menor riesgo de descoordinaci&oacute;n."
                )
            }

            Power = @{
                Subs = @("Motor de Marca y Tracci&oacute;n Pesada", "Eje de Potencia en la Popa", "Perfil de Fuerza y Control de Marca", "Anclaje de Potencia Hidrodin&aacute;mica", "Vector de Fuerza de Popa", "Referente de Potencia r&iacute;tmica", "Eje de Tracci&oacute;n de Alta Intensidad", "Pilar de Fuerza en Marca", "Motor de Propulsi&oacute;n Frontal de Popa", "Control de Potencia en Popa", "Masa de Soporte y Tracci&oacute;n", "Sensor de Fuerza y Marca Potente", "Estratega de Potencia en Popa", "Referente de Empuje Estructural", "Anclaje de Vatios en Popa")
                Elections = @(
                    "$displayName inyecta vatios de alto impacto cerca del eje de giro, proporcionando la aceleraci&oacute;n necesaria para romper la resistencia del agua tras cada ataque explosivo. Su potencia bruta es el catalizador que permite que el bote gane inercia de forma casi instant&aacute;nea, situando a la trainera en una posici&oacute;n de ventaja competitiva desde las primeras paladas.",
                    "$displayName aporta una explosividad r&iacute;tmica que revitaliza el avance del bote en condiciones de mar rizada, manteniendo la tensi&oacute;n cin&eacute;tica constante y elevada. Su capacidad para aplicar fuerza de forma reactiva permite que el bote no se detenga entre paladas, manteniendo una velocidad media superior gracias a una entrega de potencia muy agresiva.",
                    "$displayName dinamiza la salida del bote tras las ciabogas, convirtiendo la fuerza muscular en una proyecci&oacute;n lineal de gran eficiencia biomec&aacute;nica y potencia. Su funci&oacute;n es cr&iacute;tica en las maniobras de giro, donde su torque ayuda a pivotar el bote con mayor rapidez, ahorrando segundos vitales que pueden definir el resultado final de la tanda.",
                    "$displayName utiliza su masa activa para generar un torque superior en la fase de ataque, traccionando con una agresividad controlada y muy efectiva en cada ciclo. Al anclar su potencia en el punto de m&aacute;xima resistencia, consigue que la trainera 'salte' hacia adelante, minimizando el tiempo de respuesta del casco ante las demandas del patr&oacute;n.",
                    "$displayName proyecta una potencia masiva en la zona de marca, traccionando con una palanca optimizada para maximizar el par motor en la popa de la embarcaci&oacute;n. Su envergadura f&iacute;sica le permite mover grandes vol&uacute;menes de agua con cada palada, asegurando que la propulsi&oacute;n trasera sea el motor que empuje al resto del equipo hacia la victoria.",
                    "$displayName asegura un empuje contundente en el primer tercio de la palada, elevando la velocidad punta del bote de forma casi instant&aacute;nea tras el ataque inicial. Esta 'pegada' frontal es la que define la capacidad de respuesta del bote ante los ataques de los rivales, permitiendo defender la calle con una autoridad biomec&aacute;nica indiscutible.",
                    "$displayName coordina su potencia con el marcador de la banda contraria, equilibrando las fuerzas de empuje para una trayectoria rectil&iacute;nea y eficiente en el r&iacute;o. Su simetr&iacute;a de fuerza es fundamental para evitar correcciones de rumbo innecesarias por parte del patr&oacute;n, lo que reduce el rozamiento lateral y mejora la fluidez hidrodin&aacute;mica global.",
                    "$displayName utiliza su envergadura para anclar la palada en el agua, proporcionando una base de fuerza s&oacute;lida sobre la que el bote puede pivotar de forma segura. Esta solidez estructural permite que la potencia generada no se disipe en flexiones del remo o la regala, garantizando que cada gramo de energ&iacute;a se transforme en metros de avance real.",
                    "$displayName inyecta una energ&iacute;a vibrante en la zona de popa, obligando al resto de la tripulaci&oacute;n a mantener un nivel de exigencia f&iacute;sica alto y constante. Su boga es un recordatorio visual de la intensidad necesaria para competir al m&aacute;s alto nivel, actuando como un motor an&iacute;mico y f&iacute;sico que eleva el rendimiento de toda su bancada.",
                    "$displayName destaca por su capacidad de mantener vatios elevados durante toda la regata, actuando como el principal motor de fuerza en la popa de la trainera. Su resistencia a la fatiga le permite mantener una entrega de par motor constante, evitando que el bote pierda su 'pegada' en los kil&oacute;metros finales donde la mayor&iacute;a de los rivales empiezan a ceder.",
                    "$displayName destaca por una boga de gran potencia hidrodin&aacute;mica, capaz de mover grandes vol&uacute;menes de agua con una autoridad f&iacute;sica superior en cada palada. Su capacidad para mantener la presi&oacute;n sobre la pala en los tramos de boga contra corriente es vital para que la trainera no pierda su inercia de avance.",
                    "$displayName inyecta una fuerza estructural en la marca que asegura que la potencia generada por el bloque motor se traduzca en una aceleraci&oacute;n n&iacute;tida. Su boga es el pilar de vatios del equipo, proporcionando una referencia de empuje que obliga a que toda la tripulaci&oacute;n rinda al m&aacute;s alto de sus posibilidades biomec&aacute;nicas.",
                    "$displayName utiliza su fortaleza f&iacute;sica para asentar el bote en el agua, evitando que la trainera pierda su trimado longitudinal por falta de potencia en popa. Al descargar su fuerza en el momento del ataque, consigue que el morro se eleve ligeramente, favoreciendo el planeo y reduciendo la superficie mojada del casco.",
                    "$displayName coordina la transmisi&oacute;n de vatios con una precisi&oacute;n que minimiza las p&eacute;rdidas por rozamiento interno en la biomec&aacute;nica de la boga r&iacute;tmica de alta intensidad. Su boga destaca por una fluidez que esconde una potencia demoledora, permitiendo que el bote avance con una suavidad aparente que esconde un rendimiento real de alt&iacute;simo nivel.",
                    "$displayName aporta la robustez necesaria en la marca para que el equipo pueda afrontar regatas de gran exigencia f&iacute;sica con total garant&iacute;a de rendimiento. Su potencia es el seguro de vida de Aizburua, garantizando que la trainera siempre tendr&aacute; la fuerza necesaria para competir contra las mejores tripulaciones de la categor&iacute;a."
                )
                Impacts = @(
                    "Consigue vencer la resistencia inicial del agua con un torque masivo, reduciendo dr&aacute;sticamente el tiempo de respuesta del bote ante cambios de ritmo t&aacute;cticos. Esta capacidad de aceleraci&oacute;n es lo que permite al bote 'escaparse' en los momentos clave, obligando a los rivales a realizar un sobreesfuerzo que a menudo no pueden sostener.",
                    "Reduce el arrastre hidrodin&aacute;mico al mantener una presi&oacute;n constante y elevada sobre la pala durante toda la fase de tracci&oacute;n efectiva del ciclo. Al no permitir que la presi&oacute;n caiga al final de la palada, consigue que el bote mantenga su sustentaci&oacute;n, evitando que la popa se hunda y genere turbulencias que frenen el planeo.",
                    "Mantiene el bote en un estado de planeo activo incluso en las zonas de boga m&aacute;s exigentes, evitando que el casco pierda sustentaci&oacute;n por fatiga muscular. Su potencia es la que sostiene la velocidad de crucero en las condiciones m&aacute;s adversas, asegurando que la trainera mantenga su trayectoria incluso con vientos de cara significativos.",
                    "Maximiza la transferencia de energ&iacute;a desde el banco hasta la pala, asegurando que cada vatio generado se traduzca en metros de avance real y efectivo. Esta eficiencia de transmisi&oacute;n es el resultado de una biomec&aacute;nica perfecta, donde el tronco y los brazos trabajan en total sincron&iacute;a para exprimir al m&aacute;ximo la palanca hidrodin&aacute;mica.",
                    "Genera una aceleraci&oacute;n residual tras el ataque que permite al bote mantener velocidades de crucero superiores a la media de la tanda competitiva. Este 'efecto empuje' es vital para mantener la moral alta, sintiendo que la trainera corre f&aacute;cil y responde con nobleza a cada demanda de fuerza realizada por el equipo.",
                    "Mitiga las desaceleraciones en el recobro mediante una entrega de fuerza progresiva que mantiene el flujo hidrodin&aacute;mico bajo el casco del bote. Al suavizar la salida de la pala, evita que el bote sufra micro-frenadas que, acumuladas a lo largo de 3 millas, pueden suponer una p&eacute;rdida de varios segundos preciosos en el cron&oacute;metro.",
                    "Optimiza la hidrodin&aacute;mica lateral al reducir el tiempo de permanencia de la pala en el agua, favoreciendo un deslizamiento m&aacute;s eficiente y prolongado. Esta t&eacute;cnica de 'entrada y salida limpia' es la marca de un remero de alto nivel, capaz de aplicar una fuerza masiva sin comprometer la limpieza del gesto t&eacute;cnico en ning&uacute;n momento.",
                    "Asegura que la popa no se hunda durante el ataque masivo, equilibrando la potencia con una t&eacute;cnica de salida de pala muy depurada y reactiva. Al mantener la horizontalidad del bote, consigue que la superficie mojada sea la m&iacute;nima posible, lo que reduce la resistencia al avance y permite que el bote 'vuele' sobre la superficie del agua.",
                    "Aumenta la tasa de metros por palada (MPP), permitiendo al bote avanzar m&aacute;s con el mismo n&uacute;mero de ciclos r&iacute;tmicos por minuto de boga. Esta mejora en la eficiencia t&eacute;cnica es el mejor predictor de un buen resultado en regatas de larga distancia, donde la econom&iacute;a de esfuerzo es la clave para llegar con fuerzas al tramo final.",
                    "Proporciona la robustez estructural necesaria para soportar las cargas de trabajo m&aacute;s altas sin comprometer la integridad de la boga colectiva. Su presencia en la popa es una garant&iacute;a de potencia, un seguro de vida biomec&aacute;nico que permite al resto de la tripulaci&oacute;n confiar en que la trainera siempre tendr&aacute; ese extra de velocidad cuando sea necesario.",
                    "Optimiza la hidrodin&aacute;mica de la proa al asentar el bote desde la popa con una potencia que favorece el planeo longitudinal del casco. Su tracci&oacute;n ayuda a que el bote se mantenga 'plano' sobre el agua, reduciendo el arrastre y permitiendo que la trainera deslice con una facilidad biomec&aacute;nica excepcional.",
                    "Mejora la transmisi&oacute;n de fuerzas estructurales en la regala de popa, asegurando que el tolete soporte la carga sin p&eacute;rdidas por deformaci&oacute;n el&aacute;stica. Su boga destaca por una solidez que garantiza que la energ&iacute;a se transmita &iacute;ntegramente al remo, maximizando el impacto de cada palada en el cron&oacute;metro de la regata.",
                    "Contribuye a un paso por agua de gran calibre t&eacute;cnico, donde la potencia se libera de forma progresiva para evitar picos de fatiga muscular innecesarios. Esta gesti&oacute;n de la curva de fuerza es fundamental para aguantar los 20 minutos de la prueba al m&aacute;s alto nivel competitivo posible en la liga.",
                    "Facilita la maniobrabilidad del bote mediante una marca potente que ayuda a realizar correcciones de rumbo r&aacute;pidas en coordinaci&oacute;n con el patr&oacute;n del equipo. Su capacidad para subir los vatios de forma instant&aacute;nea permite que la trainera responda con agilidad a las demandas del tim&oacute;n, algo vital en las ciabogas.",
                    "Asegura una boga de gran proyecci&oacute;n lineal, ganando metros en cada ciclo de palada gracias a una entrega de potencia s&oacute;lida y muy bien coordinada en marca. Esta proyecci&oacute;n es el factor que permite a Aizburua marcar los mejores tiempos en los parciales de boga plana, donde la potencia de marca es determinante."
                )
            }
            Agile = @{
                Subs = @("Referente de Agilidad y Marca Din&aacute;mica", "Eje de Coordinaci&oacute;n R&iacute;tmica en Popa", "Perfil de Velocidad y Control de Marca", "Sensor de Boga y Respuesta R&aacute;pida en Popa", "Gesti&oacute;n de Frecuencia y Fluidez de Marca", "Dinamismo r&iacute;tmico de Popa Cr&iacute;tico", "Eje de Reactividad en Marca", "Pilar de Agilidad Biomec&aacute;nica", "Motor de Frecuencia Frontal de Popa", "Control de Fluidez en Popa", "Referente de Salida de Pala y Planeo", "Sensor de Ritmo y Agilidad Master", "Estratega de Frecuencia en Popa", "Referente de Deslizamiento Estructural", "Anclaje de Fluidez en Popa")
                Elections = @(
                    "$displayName facilita una boga extremadamente fluida que minimiza las vibraciones estructurales del casco durante todo el ciclo de palada r&iacute;tmica. Su agilidad le permite adaptarse instant&aacute;neamente a cualquier cambio de ritmo, asegurando que la conexi&oacute;n entre el patr&oacute;n y el motor central sea siempre n&iacute;tida, directa y sin retardos cin&eacute;ticos.",
                    "$displayName optimiza la entrada de la pala en el agua, reduciendo las salpicaduras y el frenado par&aacute;sito en el momento cr&iacute;tico del ataque frontal. Su boga destaca por una 'limpieza de ataque' que permite al bote aprovechar la inercia residual sin interrupciones mec&aacute;nicas, favoreciendo un avance mucho m&aacute;s arm&oacute;nico y eficiente en cada ciclo.",
                    "$displayName asegura una limpieza t&eacute;cnica excepcional en la salida de la pala, facilitando un recobro r&aacute;pido, a&eacute;reo y perfectamente coordinado con su banda. Al minimizar el tiempo de fricci&oacute;n de la pala con el agua al final de la tracci&oacute;n, consigue que el bote no pierda velocidad en la fase de deslizamiento, mejorando el MPP global de forma notable.",
                    "$displayName aporta una agilidad que permite ajustar el ritmo de boga de forma casi instant&aacute;nea seg&uacute;n las necesidades t&aacute;cticas del patr&oacute;n en cada tramo. Esta reactividad es vital en regatas de r&iacute;o con muchas corrientes cambiantes, donde la capacidad de subir o bajar un par de paladas por minuto sin perder el orden es una ventaja t&aacute;ctica decisiva.",
                    "$displayName coordina su banda con una boga el&eacute;ctrica y reactiva que facilita el mantenimiento de altas frecuencias de palada sin incurrir en fatiga prematura. Su t&eacute;cnica de recobro acelerado permite que la tripulaci&oacute;n mantenga la trainera en una zona de alta intensidad durante m&aacute;s tiempo, ideal para estrategias de presi&oacute;n constante sobre los rivales.",
                    "$displayName destaca por su capacidad de 'volar' sobre el agua en el recobro, minimizando el impacto del viento y mejorando el trimado longitudinal del conjunto. Al mover el remo con una ligereza excepcional, evita que la masa del cuerpo genere inercias negativas que podr&iacute;an desestabilizar el bote en el momento de m&aacute;xima velocidad de planeo.",
                    "$displayName utiliza su ligereza para compensar posibles excesos de peso en la popa, mejorando la flotabilidad y el planeo del bote en condiciones de poca mar. Su perfil biomec&aacute;nico es el complemento ideal para remeros m&aacute;s pesados, aportando el equilibrio necesario para que la trainera mantenga su quilla en la posici&oacute;n hidrodin&aacute;mica perfecta.",
                    "$displayName proyecta una boga muy t&eacute;cnica que prioriza la calidad del gesto sobre la fuerza bruta, optimizando la econom&iacute;a de movimiento en cada palada. Esta eficiencia es la que permite al equipo mantener ritmos de competici&oacute;n durante toda la regata, guardando energ&iacute;a para el ataque final gracias a una boga que 'no gasta' vatios innecesarios.",
                    "$displayName act&uacute;a como el conector r&iacute;tmico entre el marcador y el motor central, suavizando las transiciones de fuerza en la bancada de forma magistral. Su boga es el 'lubricante' r&iacute;tmico que hace que el bloque motor funcione con suavidad, evitando tirones que podr&iacute;an penalizar la transmisi&oacute;n de potencia hacia la pala del remo.",
                    "$displayName aporta una visi&oacute;n perif&eacute;rica y t&eacute;cnica que ayuda a corregir errores de boga en tiempo real dentro de su zona de influencia directa en la popa. Su capacidad para detectar peque&ntilde;os desajustes en la sincron&iacute;a de su banda permite realizar correcciones sobre la marcha, manteniendo la cohesi&oacute;n t&eacute;cnica de la tripulaci&oacute;n bajo m&aacute;xima presi&oacute;n.",
                    "$displayName destaca por una boga de gran dinamismo r&iacute;tmico, capaz de adaptarse a las variaciones del viento con una agilidad t&eacute;cnica superior en cada ciclo competitivo. Su capacidad para 'robar' segundos al cron&oacute;metro mediante una frecuencia de palada el&eacute;ctrica es vital para ganar las tandas m&aacute;s ajustadas de la liga.",
                    "$displayName inyecta una fluidez estructural en la marca que asegura que la potencia generada por el bloque motor se traduzca en una proyecci&oacute;n lineal n&iacute;tida y constante. Su boga es el lubricante biomec&aacute;nico del equipo, eliminando las asperezas r&iacute;tmicas y garantizando que el bote avance con una suavidad y rapidez excepcionales.",
                    "$displayName utiliza su reactividad f&iacute;sica para asentar el bote en el agua tras cada palada, evitando rebotes par&aacute;sitos que podr&iacute;an penalizar la velocidad neta de la regata. Al mover su cuerpo con una agilidad master, consigue que el trimado longitudinal se recupere de forma inmediata, manteniendo la quilla plana y el avance limpio.",
                    "$displayName coordina la transmisi&oacute;n de vatios con una ligereza que minimiza las p&eacute;rdidas por fatiga mental en la biomec&aacute;nica de la boga r&iacute;tmica de alta intensidad. Su boga destaca por una naturalidad que permite que el equipo fluya con el agua, convirtiendo el esfuerzo f&iacute;sico en una danza coordinada de potencia y agilidad extrema.",
                    "$displayName aporta la chispa necesaria en la marca para que el equipo pueda realizar ataques t&aacute;cticos sorpresa con total garant&iacute;a de &eacute;xito y rapidez. Su agilidad es el factor diferencial de Aizburua en los metros finales, garantizando que la trainera siempre tendr&aacute; ese cambio de marcha necesario para ganar la bandera."
    )
                Impacts = @(
                    "Evita el arrastre innecesario de la popa mediante un control milim&eacute;trico del &aacute;ngulo de entrada, mejorando la velocidad punta del bote de forma directa. Al asegurar que la pala entre en el agua con el &aacute;ngulo exacto, maximiza la propulsi&oacute;n desde el primer cent&iacute;metro de recorrido, reduciendo las p&eacute;rdidas de potencia por resbalamiento.",
                    "Mantiene la din&aacute;mica de avance incluso en presencia de corrientes laterales complejas, compensando la deriva con una boga m&aacute;s reactiva y el&eacute;ctrica. Su habilidad para 'leer' la presi&oacute;n del agua le permite ajustar la tracci&oacute;n para mantener el rumbo sin necesidad de que el patr&oacute;n use excesivamente el tim&oacute;n, lo que reduce el rozamiento.",
                    "Optimiza la hidrodin&aacute;mica lateral al reducir el tiempo de fricci&oacute;n de la pala, favoreciendo un deslizamiento m&aacute;s limpio y prolongado en cada palada efectiva. Esta t&eacute;cnica de 'toque y fuera' es la esencia de la boga moderna en banco fijo, permitiendo que la trainera mantenga su planeo sin las interrupciones que provoca una salida de pala pesada.",
                    "Reduce el estr&eacute;s mec&aacute;nico sobre el remo y la regala, prolongando la eficiencia f&iacute;sica de la tripulaci&oacute;n durante toda la regata de largo recorrido. Al aplicar la fuerza de forma progresiva y sin impactos secos, protege la musculatura de sus compa&ntilde;eros de banda, permitiendo que el equipo llegue al final de la prueba con una mayor reserva de gluc&oacute;geno.",
                    "Facilita el 'vuelo' del remo en el recobro, minimizando el cabeceo (pitching) de la popa y manteniendo un trimado longitudinal estable y eficiente. Este control del movimiento de masas es lo que permite que el bote mantenga su 'trim' ideal, asegurando que la proa no se clave ni la popa se hunda excesivamente, reduciendo la resistencia total.",
                    "Asegura que el bote no pierda inercia en los momentos de cambio de direcci&oacute;n, aportando una fluidez que es clave en las maniobras t&aacute;cticas de la regata. Su boga es el motor que mantiene la trainera en movimiento constante, evitando los tiempos muertos que suelen ocurrir cuando el equipo intenta recuperar el orden tras una maniobra compleja o una racha de viento.",
                    "Mejora la respuesta del bote ante ataques de los rivales, permitiendo subir el ritmo con una agilidad que sorprende por su eficacia biomec&aacute;nica superior. Esta capacidad de 'cambio de marcha' es una de las mayores virtudes de un remero &aacute;gil, permitiendo que el equipo responda con autoridad a cualquier desaf&iacute;o que se presente en la mar.",
                    "Reduce la formaci&oacute;n de estelas par&aacute;sitas en la popa, lo que se traduce en una menor resistencia al avance y mayor velocidad neta en cada largo de boga. Una estela limpia es el mejor indicador de que el remero est&aacute; trabajando en total armon&iacute;a con el agua, transformando la potencia en avance sin desperdiciar energ&iacute;a en turbulencias innecesarias.",
                    "Permite una boga m&aacute;s aerodin&aacute;mica en el recobro, lo que es vital en regatas con fuerte viento de proa o rachas laterales que intentan frenar el bote. Al mantener un perfil bajo y una salida de pala r&aacute;pida, reduce la superficie de exposici&oacute;n al viento, permitiendo que el bote mantenga su velocidad incluso en las condiciones meteorol&oacute;gicas m&aacute;s duras.",
                    "Contribuye a una sensaci&oacute;n de ligereza en el bote que eleva la moral de la tripulaci&oacute;n al sentir que la trainera 'corre' f&aacute;cil y sin aparente esfuerzo. Esta sensaci&oacute;n de fluidez es fundamental para mantener la concentraci&oacute;n y la motivaci&oacute;n durante los 15-20 minutos de competici&oacute;n, permitiendo que el equipo rinda al m&aacute;ximo de su capacidad t&eacute;cnica.",
                    "Optimiza la transmisi&oacute;n de fuerzas din&aacute;micas al remo, asegurando que cada palada tenga una respuesta inmediata en el avance real del bote hidrodin&aacute;mico. Su t&eacute;cnica de 'golpe r&aacute;pido' es la clave para mover la masa de la embarcaci&oacute;n con una agilidad que sorprende a los rivales y motiva a sus compa&ntilde;eros.",
                    "Mejora la coordinaci&oacute;n de la salida de agua en popa, reduciendo el arrastre mediante un gesto t&eacute;cnico que libera la trainera de cualquier atadura superficial. Al limpiar el flujo de popa, favorece un planeo m&aacute;s estable y r&aacute;pido, lo que se traduce en una mejora directa de la velocidad media neta de la regata.",
                    "Contribuye a un paso por agua de alt&iacute;sima frecuencia t&eacute;cnica, donde la agilidad se convierte en el motor de proyecci&oacute;n principal del equipo en la tanda. Esta boga de 'alta gama' es el resultado de un entrenamiento espec&iacute;fico orientado a la excelencia biomec&aacute;nica y a la coordinaci&oacute;n r&iacute;tmica absoluta.",
                    "Facilita la lectura del ritmo por parte del bloque motor central, sirviendo como un sensor de frecuencia de alta sensibilidad y precisi&oacute;n para el equipo. Su boga es el recordatorio constante de que la rapidez y la limpieza son el camino m&aacute;s corto hacia la victoria en el banco fijo moderno.",
                    "Asegura una boga de gran proyecci&oacute;n que destaca por su capacidad de 'robar' metros en el recobro, gracias a una agilidad t&eacute;cnica que es la envidia de la liga. Esta capacidad de deslizamiento es lo que permite a Aizburua competir al m&aacute;s alto nivel, manteniendo la inercia con una elegancia y rapidez inigualables."
                )
            }
        }
        Motor = @{
            Torque = @{
                Subs = @("N&uacute;cleo de Tracci&oacute;n Pesada", "Potencia Bruta y Torque Absoluto", "Eje de Fuerza Motriz Central", "Bloque de Empuje Masivo", "Generador de Par Motor Central", "V&eacute;rtice de Potencia PAM", "Motor de Tracci&oacute;n Estructural", "Impulsor de Alto Par Biomec&aacute;nico", "N&uacute;cleo de Fuerza de Crucero", "Eje de Proyecci&oacute;n Vectorial", "Masa de Soporte y Torque Central", "Sensor de Fuerza y Empuje S&oacute;lido", "Estratega de Potencia en Motor", "Referente de Tracci&oacute;n Estructural", "Anclaje de Vatios en Motor Central")
                Elections = @(
                    "$displayName act&uacute;a como el motor principal del bloque central, aplicando un torque masivo que define la velocidad base y el car&aacute;cter competitivo del bote. Su capacidad para traccionar con una fuerza absoluta superior asegura que la trainera mantenga su planeo incluso en las condiciones de mar m&aacute;s pesadas, actuando como el pilar de potencia del equipo.",
                    "$displayName inyecta vatios cr&iacute;ticos en el momento de m&aacute;xima carga hidrodin&aacute;mica, asegurando que el bote no pierda inercia en la zona central de m&aacute;xima manga. Su tracci&oacute;n es el anclaje biomec&aacute;nico que permite que el resto de la tripulaci&oacute;n aplique su fuerza con seguridad, sabiendo que el n&uacute;cleo del bote responde con una firmeza y potencia inamovibles.",
                    "$displayName tracciona con un torque absoluto que permite vencer la resistencia del agua incluso en las condiciones de mar m&aacute;s pesadas y adversas del d&iacute;a. Su boga se caracteriza por una entrega de fuerza explosiva en el inicio de la palada, rompiendo la inercia del agua con una autoridad que se siente en toda la estructura de la trainera, elevando la velocidad neta.",
                    "$displayName utiliza su potencia muscular bruta para anclar la boga en el centro del bote, proporcionando un punto de apoyo s&oacute;lido para el resto de la tripulaci&oacute;n. Esta solidez estructural es fundamental para que la energ&iacute;a generada en las bancadas de popa y proa no se pierda por deformaciones del casco, garantizando una transmisi&oacute;n de vatios limpia y directa.",
                    "$displayName ejerce una tracci&oacute;n profunda, larga y sostenida, maximizando el tiempo de presi&oacute;n efectiva sobre la pala en cada ciclo r&iacute;tmico de alta intensidad. Al mantener la pala en el agua durante un arco de palada optimizado, consigue mover un volumen de agua superior, lo que se traduce en un mayor avance por palada (MPP) y una eficiencia t&eacute;cnica de nivel &eacute;lite.",
                    "$displayName destaca por una entrega de fuerza explosiva en el ataque, rompiendo la inercia del agua con una autoridad biomec&aacute;nica superior en cada palada. Su capacidad para aplicar el par motor m&aacute;ximo de forma instant&aacute;nea es lo que permite al bote responder con agresividad ante cualquier intento de adelantamiento por parte de los rivales, defendiendo la calle con vatios reales.",
                    "$displayName coordina el bloque motor con una potencia que obliga a las bancadas delanteras a mantener una tracci&oacute;n de alta intensidad y precisi&oacute;n. Su boga es el marcador de fuerza del bote, exigiendo al resto de la tripulaci&oacute;n un compromiso f&iacute;sico total para igualar su entrega de energ&iacute;a, lo que eleva el rendimiento global de la trainera de forma significativa.",
                    "$displayName utiliza su gran envergadura para generar un arco de palada masivo, moviendo un volumen de agua superior al promedio del equipo en cada ciclo. Esta capacidad de 'palanca larga' es vital para vencer la resistencia hidrodin&aacute;mica en tramos de corriente en contra, donde la fuerza bruta bien aplicada es el &uacute;nico camino para mantener una velocidad competitiva.",
                    "$displayName inyecta vatios constantes que son el pilar de la velocidad de crucero, permitiendo al bote mantener ritmos altos sin desfallecer en el tramo final. Su resistencia a la fatiga en la zona de m&aacute;xima Potencia Aer&oacute;bica M&aacute;xima (PAM) asegura que el motor del bote no se detenga, manteniendo una presi&oacute;n constante que asfixia a las tripulaciones rivales.",
                    "$displayName act&uacute;a como el pulm&oacute;n de fuerza de la banda, traccionando con una palanca que optimiza el par motor en el punto de m&aacute;xima manga del bote. Su posici&oacute;n central le permite actuar como el eje sobre el que pivota la fuerza de toda su banda, asegurando que la potencia se transmita de forma equilibrada y eficiente hacia la quilla de la embarcaci&oacute;n.",
                    "$displayName inyecta un torque estructural que es vital para mantener la cuaderna del bote bajo control en los momentos de m&aacute;xima tensi&oacute;n biomec&aacute;nica. Su boga es el motor de tracci&oacute;n profunda que asegura que el bote no 'pierda la cara' a la regata incluso cuando el cansancio empieza a mellar la t&eacute;cnica de los dem&aacute;s.",
                    "$displayName utiliza su masa de soporte para traccionar con una potencia que se traduce en una proyecci&oacute;n lineal n&iacute;tida y muy potente. Al descargar sus vatios en la zona central, consigue que la trainera se desplace con una autoridad f&iacute;sica superior, marcando la diferencia en los parciales de boga plana.",
                    "$displayName coordina la transmisi&oacute;n de par motor con una precisi&oacute;n que minimiza las p&eacute;rdidas por rozamiento estructural en la regala del bote. Su boga destaca por una solidez que garantiza que cada vatio generado por sus piernas se convierta en avance real, elevando el MPP global de toda la tripulaci&oacute;n competitiva.",
                    "$displayName aporta la robustez necesaria en el bloque motor para que el equipo pueda afrontar los ataques de los rivales con total garant&iacute;a de &eacute;xito. Su potencia es el seguro de vida de la embarcaci&oacute;n, proporcionando una reserva de fuerza que es determinante en los kil&oacute;metros finales de la prueba.",
                    "$displayName destaca por una boga de gran calibre f&iacute;sico, capaz de mover la masa de la trainera con una autoridad t&eacute;cnica envidiable en cada palada. Su capacidad para sostener el par motor m&aacute;ximo durante toda la regata es lo que permite a Aizburua imponer su ritmo y dominar la tanda desde el primer largo."
                )
                Impacts = @(
                    "Maximiza la generaci&oacute;n de vatios en el v&eacute;rtice de Potencia Aer&oacute;bica M&aacute;xima (PAM), elevando significativamente el techo de rendimiento global del equipo. Su intervenci&oacute;n es la que permite al bote alcanzar velocidades de planeo que de otro modo ser&iacute;an imposibles de sostener, transformando la energ&iacute;a muscular en una propulsi&oacute;n hidrodin&aacute;mica de alta eficiencia.",
                    "Vence la inercia negativa con una palanca masiva que permite mover m&aacute;s volumen de agua en cada palada con un esfuerzo relativo optimizado por t&eacute;cnica. Al aplicar la fuerza en el punto justo de la palada, minimiza las p&eacute;rdidas de energ&iacute;a por turbulencias, asegurando que cada gramo de fuerza se traduzca en metros reales de avance sobre la superficie del agua.",
                    "Estabiliza el planeo del bote bajo condiciones de carga extrema, evitando que el casco se 'clave' en el oleaje de proa por falta de empuje central. Su potencia es la que mantiene el morro del bote elevado, permitiendo que la trainera 'monte' la ola con mayor facilidad y reduciendo dr&aacute;sticamente el rozamiento por impacto frontal contra el agua.",
                    "Genera una tracci&oacute;n tan potente que permite al bote mantener velocidades competitivas incluso con vientos de cara muy significativos y persistentes. Esta capacidad de 'perforar' el viento es lo que define a un bloque motor de primer nivel, capaz de mantener el cron&oacute;metro bajo control incluso cuando las condiciones meteorol&oacute;gicas intentan frenar el avance.",
                    "Reduce la p&eacute;rdida de velocidad entre paladas mediante una entrega de fuerza progresiva que mantiene el bote en una tensi&oacute;n cin&eacute;tica ideal y constante. Al suavizar la curva de potencia, consigue que el bote no sufra tirones, manteniendo un flujo de agua laminar bajo el casco que es la esencia de la velocidad hidrodin&aacute;mica en el banco fijo.",
                    "Asegura que el centro de gravedad del bote se desplace de forma lineal y r&aacute;pida, minimizando los tirones que penalizan el flujo natural del agua. Esta linealidad en el avance es fundamental para ahorrar energ&iacute;a a largo plazo, permitiendo que la tripulaci&oacute;n mantenga ritmos de boga muy altos con un coste metab&oacute;lico relativamente bajo.",
                    "Optimiza el aprovechamiento de la energ&iacute;a metab&oacute;lica al concentrar el esfuerzo en la fase de m&aacute;xima eficiencia de la palanca del remo hidrodin&aacute;mico. Al evitar picos de fuerza innecesarios en fases de bajo rendimiento de la pala, consigue que cada vatio generado sea un vatio que 'corre', maximizando la rentabilidad t&eacute;cnica de cada palada.",
                    "Contribuye a una estela limpia y potente, indicativo biomec&aacute;nico de que la energ&iacute;a se est&aacute; transformando &iacute;tegramente en avance hidrodin&aacute;mico real. Una estela de alta energ&iacute;a es el sello de un bloque motor que trabaja en sinton&iacute;a, moviendo el agua con una autoridad que proyecta la trainera hacia adelante con una eficiencia visualmente impactante.",
                    "Mejora la respuesta del bote ante cambios bruscos de corriente, proporcionando la fuerza necesaria para mantener el rumbo sin desviaciones par&aacute;sitas. Su torque central act&uacute;a como un ancla din&aacute;mica que sujeta el bote en su calle, permitiendo que el patr&oacute;n se centre en la estrategia sin tener que luchar constantemente contra la deriva del agua.",
                    "Proporciona la base de vatios necesaria para que las bancadas de proa puedan centrarse en la agilidad y limpieza del planeo frontal del conjunto. Al encargarse de la tracci&oacute;n pesada, libera a los proeles de la necesidad de aplicar fuerza bruta, permitiendo que estos se enfoquen en la lectura de la ola y la prevenci&oacute;n del cabeceo.",
                    "Garantiza una boga de gran calibre t&eacute;cnico que inspira confianza al resto del equipo, actuando como el motor de referencia en el bloque central de la embarcaci&oacute;n. Al sentir que el n&uacute;cleo del bote es inexpugnable, los remeros de proa y popa pueden centrarse en su propia boga con total seguridad.",
                    "Maximiza la proyecci&oacute;n lineal del bote en cada palada, ganando metros preciosos gracias a una entrega de par motor masiva y muy bien coordinada con el resto del bloque motor. Esta proyecci&oacute;n es el factor determinante que permite a Aizburua marcar los mejores tiempos en los parciales de boga plana.",
                    "Mejora la estabilidad lateral del conjunto mediante una tracci&oacute;n equilibrada que evita balanceos innecesarios en la zona de m&aacute;xima manga de la trainera. Al proporcionar una base de potencia s&oacute;lida, facilita un planeo m&aacute;s estable y r&aacute;pido, reduciendo el rozamiento del casco con el agua.",
                    "Contribuye a una estela m&aacute;s n&iacute;tida y potente, indicativo de que el bloque motor est&aacute; trabajando en su zona de m&aacute;xima rentabilidad hidrodin&aacute;mica y eficiencia t&eacute;cnica. Una estela limpia es el sello de una trainera que 'pisa' fuerte, transformando la potencia en velocidad con una naturalidad excepcional.",
                    "Optimiza el rendimiento del equipo en los tramos de regata con marea en contra, donde el torque masivo es vital para mantener el avance constante del bote hidrodin&aacute;mico. Su capacidad para 'tirar' de la masa en las peores condiciones es lo que distingue a los grandes motores centrales de Aizburua."
                )
            }
            Dynamic = @{
                Subs = @("Motor Din&aacute;mico de Alta Frecuencia", "Impulsor R&iacute;tmico de Alta Reactividad", "Eje de Reactividad Biomec&aacute;nica Central", "Dinamizador de Frecuencia de Boga", "Vector de Reactividad Central", "N&uacute;cleo de Agilidad de Crucero", "Regulador de Cadencia Central", "Eje de Transmisi&oacute;n R&aacute;pida", "Dinamizador r&iacute;tmico del Motor", "Impulsor de Alta Frecuencia Central", "Motor de Frecuencia y Agilidad", "Sensor de Ritmo y Reacci&oacute;n", "Estratega de Frecuencia en Motor", "Referente de Dinamismo Estructural", "Anclaje de Cadencia en Motor Central")
                Elections = @(
                    "$displayName aporta una velocidad de palada excepcional que permite elevar las revoluciones del bote de forma inmediata ante cualquier orden t&aacute;ctica. Su dinamismo es el que permite que el motor central no se 'atranque' en frecuencias bajas, manteniendo una boga vibrante que facilita el mantenimiento de la velocidad punta en tramos de viento a favor.",
                    "$displayName inyecta una agilidad necesaria en la boga central, facilitando la transici&oacute;n fluida entre el final del ataque y el inicio de la tracci&oacute;n efectiva. Al reducir el tiempo de respuesta biomec&aacute;nico, consigue que la potencia se aplique de forma m&aacute;s inmediata, minimizando los micro-descensos de velocidad que ocurren al inicio de cada ciclo de palada.",
                    "$displayName optimiza la frecuencia r&iacute;tmica del motor, asegurando que el bloque central responda con rapidez a los cambios de ritmo t&aacute;cticos del patr&oacute;n. Su capacidad para subir la cadencia sin perder la limpieza del gesto es lo que permite al equipo realizar ataques por sorpresa o responder a las embestidas de los rivales en los metros finales.",
                    "$displayName proporciona una boga el&eacute;ctrica y reactiva que reduce el tiempo de 'muerto' entre paladas, manteniendo el avance del bote continuo y fluido. Esta continuidad es la clave para que la trainera mantenga su sustentaci&oacute;n, evitando que el casco se hunda en el agua durante el recobro, lo que se traduce en una mejora directa de la velocidad media.",
                    "$displayName dinamiza el paso por agua con una boga de alta frecuencia que evita que el bote se 'asiente' demasiado y pierda su planeo natural hidrodin&aacute;mico. Su boga act&uacute;a como un motor de altas revoluciones, ideal para situaciones de regata donde la agilidad r&iacute;tmica es m&aacute;s determinante que la fuerza bruta, como en las salidas o en las maniobras de ciaboga.",
                    "$displayName coordina el ritmo de su banda con una reactividad que facilita el seguimiento por parte de los remeros menos experimentados de la tripulaci&oacute;n. Su gesto t&eacute;cnico es n&iacute;tido y f&aacute;cil de leer, actuando como un faro r&iacute;tmico que unifica el bloque central y asegura que todos los remeros de su banda trabajen con la misma cadencia y energ&iacute;a.",
                    "$displayName destaca por un recobro r&aacute;pido y controlado, permitiendo que el bote mantenga su inercia sin interferencias mec&aacute;nicas en el banco de boga. Al mover su masa corporal con una agilidad superior, evita generar inercias negativas que podr&iacute;an frenar el bote, asegurando que el planeo se mantenga durante el mayor tiempo posible entre tracciones.",
                    "$displayName utiliza su agilidad para compensar las fluctuaciones de la ola, ajustando el tiempo de palada para maximizar la tracci&oacute;n efectiva en todo momento. Su capacidad para 'sentir' el agua le permite adaptar la profundidad y el &aacute;ngulo de la pala en cada palada, asegurando que el agarre sea siempre &oacute;ptimo independientemente del estado de la mar.",
                    "$displayName inyecta un dinamismo que contagia a toda la bancada, elevando la moral del grupo al sentir una boga vibrante y con mucha vida en el motor central. Esta sensaci&oacute;n de 'bote ligero' es fundamental para mantener la intensidad psicol&oacute;gica de la regata, permitiendo que el equipo rinda por encima de sus posibilidades f&iacute;sicas te&oacute;ricas.",
                    "$displayName act&uacute;a como el motor de revoluciones del bote, asegurando que el ritmo de boga se mantenga en la zona de m&aacute;xima eficiencia PAM de forma constante. Su boga es el pulso del equipo, manteniendo una frecuencia que optimiza el consumo de ox&iacute;geno y permite que los remeros m&aacute;s fuertes puedan descargar su potencia con una cadencia inmejorable.",
                    "$displayName inyecta una energ&iacute;a reactiva en el motor que es vital para afrontar los ataques t&aacute;cticos con m&aacute;xima garant&iacute;a de &eacute;xito. Su boga destaca por una chispa biomec&aacute;nica que obliga al resto de la tripulaci&oacute;n a no bajar la guardia, manteniendo una tensi&oacute;n competitiva constante en cada largo de la regata.",
                    "$displayName utiliza su agilidad para dinamizar la boga en condiciones de viento de popa, donde la rapidez del ataque es m&aacute;s determinante que la fuerza bruta. Al mover la pala con una velocidad superior, consigue 'enganchar' la ola con mayor facilidad, favoreciendo un planeo m&aacute;s prolongado y eficiente de la trainera.",
                    "$displayName coordina la frecuencia del motor con una precisi&oacute;n que minimiza las p&eacute;rdidas por fatiga r&iacute;tmica en la tripulaci&oacute;n de Aizburua. Su boga es el lubricante biomec&aacute;nico que permite que el bloque motor fluya con el agua, convirtiendo el esfuerzo f&iacute;sico en una proyecci&oacute;n lineal n&iacute;tida y muy r&aacute;pida sobre la superficie.",
                    "$displayName aporta la reactividad necesaria en la zona central para que el equipo pueda realizar cambios de marcha explosivos en los momentos m&aacute;s cr&iacute;ticos. Su dinamismo es el factor diferencial que permite al bote ganar metros preciosos en cada sprint t&aacute;ctico, asegurando una posici&oacute;n de ventaja competitiva real.",
                    "$displayName destaca por una boga de gran dinamismo biomec&aacute;nico, capaz de adaptarse a las variaciones del ritmo con una naturalidad t&eacute;cnica excepcional en cada palada. Su capacidad para sostener frecuencias de boga de &eacute;lite sin perder la limpieza del gesto es lo que permite a la trainera marcar los mejores tiempos parciales."
                )
                Impacts = @(
                    "Favorece la reactividad tras las ciabogas, permitiendo que el bote recupere su velocidad punta en un menor n&uacute;mero de paladas explosivas y din&aacute;micas. Esta capacidad de recuperaci&oacute;n es vital en regatas de cuatro largos, donde cada segundo perdido en la salida de la boya puede ser determinante para el resultado final de la prueba.",
                    "Mantiene la sustentaci&oacute;n hidrodin&aacute;mica constante mediante ciclos de palada cortos y potentes que evitan cualquier tipo de desaceleraci&oacute;n par&aacute;sita en el avance. Al mantener el agua en movimiento constante bajo el casco, reduce el rozamiento por fricci&oacute;n y permite que el bote mantenga velocidades competitivas con un gasto energ&eacute;tico m&aacute;s contenido.",
                    "Agiliza el ciclo de palada en crucero, lo que resulta en un ahorro energ&eacute;tico cr&iacute;tico al mantener el bote siempre en su zona de confort hidrodin&aacute;mica. Esta eficiencia r&iacute;tmica es la que permite al equipo llegar con una mayor frescura al &uacute;ltimo largo, donde su capacidad para subir el ritmo marcar&aacute; la diferencia frente a tripulaciones m&aacute;s fatigadas.",
                    "Optimiza la coordinaci&oacute;n entre las bancadas delanteras y traseras mediante un ritmo central vibrante, n&iacute;tido y muy f&aacute;cil de seguir para todos. Su boga es el pegamento t&eacute;cnico de la trainera, asegurando que la potencia se transmita de forma s&iacute;ncrona desde la proa hasta la popa, eliminando los retardos que penalizan la proyecci&oacute;n lineal del conjunto.",
                    "Aumenta la tasa de aceleraci&oacute;n por palada, permitiendo al bote responder de forma agresiva y contundente ante los ataques de los rivales en cualquier momento. Esta capacidad de respuesta t&aacute;ctica es una de las mayores virtudes de un motor din&aacute;mico, aportando al patr&oacute;n la herramienta necesaria para gestionar la regata con una autoridad biomec&aacute;nica superior.",
                    "Minimiza el tiempo de exposici&oacute;n de la pala al aire durante el recobro, reduciendo el impacto del viento y mejorando la aerodin&aacute;mica global del conjunto. Al mover el remo con una velocidad superior en la fase a&eacute;rea, reduce las p&eacute;rdidas de velocidad por resistencia al aire, lo que es especialmente relevante en d&iacute;as de fuerte viento racheado.",
                    "Asegura un trimado longitudinal m&aacute;s estable al evitar movimientos bruscos de masa en el banco, favoreciendo un flujo de agua laminar constante bajo el casco. Su control sobre la inercia del cuerpo permite que el bote mantenga su quilla plana, minimizando el cabeceo y asegurando que la superficie mojada sea siempre la m&iacute;nima posible para la velocidad actual.",
                    "Mejora la eficiencia hidrodin&aacute;mica global al reducir las micro-frenadas que ocurren cuando el ritmo de boga es demasiado pesado o lento para las condiciones. Al mantener una cadencia el&eacute;ctrica, consigue que el bote no se 'clave' en el agua entre paladas, favoreciendo un avance mucho m&aacute;s fluido y natural que se traduce en mejores tiempos.",
                    "Permite al patr&oacute;n jugar con la estrategia de regata, sabiendo que el motor central responder&aacute; al instante a cualquier demanda de ritmo o intensidad t&aacute;ctica. Esta versatilidad biomec&aacute;nica es un activo invaluable en situaciones de regata igualada, donde la capacidad de cambiar la boga en cuesti&oacute;n de segundos puede desequilibrar la balanza.",
                    "Contribuye a una boga m&aacute;s el&eacute;ctrica que penaliza menos la musculatura en regatas largas, retrasando la aparici&oacute;n de la fatiga central de forma estrat&eacute;gica. Al priorizar la frecuencia sobre la fuerza bruta en los tramos de boga plana, reserva las energ&iacute;as de los remeros para los momentos de m&aacute;xima exigencia, optimizando el rendimiento metab&oacute;lico.",
                    "Optimiza la transmisi&oacute;n de fuerzas din&aacute;micas al remo, asegurando que cada palada tenga una respuesta inmediata en el avance real del bote hidrodin&aacute;mico. Su t&eacute;cnica de 'reacci&oacute;n r&aacute;pida' es la clave para mover la masa de la embarcaci&oacute;n con una agilidad que motiva a sus compa&ntilde;eros y desmoraliza a los rivales directos.",
                    "Mejora la coordinaci&oacute;n de la salida de agua en el motor, reduciendo el arrastre mediante un gesto t&eacute;cnico que libera la trainera de cualquier atadura superficial innecesaria. Al limpiar el flujo central, favorece un planeo m&aacute;s estable y r&aacute;pido, lo que se traduce en una mejora directa de la velocidad neta en cada largo.",
                    "Contribuye a un paso por agua de gran dinamismo r&iacute;tmico, donde la agilidad se convierte en el motor de proyecci&oacute;n principal de la tripulaci&oacute;n en la regata. Esta boga de 'vanguardia' es el resultado de una biomec&aacute;nica perfecta, orientada a la excelencia en la frecuencia y a la coordinaci&oacute;n r&iacute;tmica absoluta.",
                    "Facilita la lectura de la frecuencia por parte de las bancadas de popa, sirviendo como un sensor de ritmo de alta fidelidad y precisi&oacute;n t&eacute;cnica para el equipo. Su boga es el recordatorio constante de que la rapidez y la fluidez son el camino m&aacute;s corto hacia la victoria en las competiciones de banco fijo de alto nivel.",
                    "Asegura una boga de gran proyecci&oacute;n que destaca por su capacidad de 'volar' sobre la superficie del agua en cada recobro r&iacute;tmico din&aacute;mico. Esta capacidad de deslizamiento es lo que permite a Aizburua competir contra los mejores, manteniendo la inercia con una elegancia y rapidez t&eacute;cnica que definen el estilo de la trainera."
                )
            }
            Inertial = @{
                Subs = @("Volante de Inercia de Alta Eficiencia", "Estabilizador de Masa y Momentum", "Perfil de Inercia Hidrodin&aacute;mica Proyectada", "Eje de Sustentaci&oacute;n Inercial", "M&oacute;dulo de Inercia de Crucero", "Masa Cr&iacute;tica de Soporte Inercial", "Estabilizador de Centro de Gravedad", "Anclaje Inercial de Alta Potencia", "Vector de Momentum Estructural", "Pilar de Inercia Biomec&aacute;nica", "Inercia Funcional de Crucero", "Sensor de Momentum y Masa", "Estratega de Inercia en Motor", "Referente de Sustentaci&oacute;n Pasiva", "Anclaje de Inercia en Motor Central")
                Elections = @(
                    "$displayName aprovecha su peso estrat&eacute;gico para mantener la inercia del bote, actuando como un 'volante de inercia' que suaviza el avance en cada ciclo r&iacute;tmico. Su masa corporal se convierte en un acumulador de energ&iacute;a cin&eacute;tica que ayuda a que el bote mantenga su velocidad de crucero en los momentos de recobro.",
                    "$displayName asegura un avance constante en el tramo de boga plana, utilizando su masa para compensar las fluctuaciones del viento y la corriente adversa. Su presencia en el motor central aporta una solidez inercial que impide que el bote se detenga ante peque&ntilde;os impactos de ola, manteniendo una velocidad media estable.",
                    "$displayName proyecta su masa corporal hacia el planeo, convirtiendo el peso en energ&iacute;a cin&eacute;tica que prolonga el deslizamiento hidrodin&aacute;mico de la trainera. Su t&eacute;cnica de boga pausada pero profunda es el complemento ideal para este efecto inercial, asegurando que la potencia se descargue en el momento de m&aacute;xima eficiencia.",
                    "$displayName utiliza su gran envergadura para anclar la inercia del bote, proporcionando una base s&oacute;lida sobre la que construir un ritmo estable y potente de crucero. Al mover su cuerpo con una cadencia controlada, minimiza las aceleraciones bruscas, favoreciendo un flujo de agua laminar constante.",
                    "$displayName estabiliza el centro de gravedad del bote, utilizando su volumen para anclar la plataforma de boga en condiciones de oleaje duro. Su funci&oacute;n es vital para mantener la trainera 'asentada' en el agua, evitando rebotes que penalizan el tiempo neto al aumentar la resistencia por fricci&oacute;n.",
                    "$displayName destaca por una boga pausada pero con una entrega de fuerza masiva, ideal para mantener la velocidad en tramos de gran exigencia. Su capacidad para mover grandes vol&uacute;menes de agua con una frecuencia moderada es la marca de un remero de inercia funcional de alto rendimiento.",
                    "$displayName act&uacute;a como el contrapeso ideal en el motor central, equilibrando las masas para evitar cabeceos innecesarios en la zona de m&aacute;xima manga. Su posici&oacute;n estrat&eacute;gica permite que la trainera mantenga un trimado horizontal perfecto, maximizando la superficie de planeo hidrodin&aacute;mico.",
                    "$displayName inyecta una inercia positiva que ayuda a que el bote no se detenga entre paladas, manteniendo una velocidad media muy alta en todo momento. Su boga es el motor de momentum que sostiene al equipo en los momentos de fatiga extrema, asegurando que la trainera no pierda su inercia residual.",
                    "$displayName utiliza su potencia muscular para mover su propio peso de forma eficiente, transform&aacute;ndolo en un activo t&aacute;ctico de estabilidad. Su biomec&aacute;nica est&aacute; orientada a maximizar el aprovechamiento de su masa, convirti&eacute;ndola en una fuerza motriz que empuja al bote desde el centro con autoridad.",
                    "$displayName coordina el bloque motor con una boga profunda que maximiza el aprovechamiento de la inercia en cada largo competitivo. Su boga destaca por una tracci&oacute;n que parece no terminar nunca, manteniendo la presi&oacute;n sobre el agua hasta el final, lo que garantiza que el bote 'vuele' en el recobro.",
                    "$displayName aporta una masa cr&iacute;tica que estabiliza la trainera ante las rachas de viento racheado, actuando como un lastre activo que mejora la navegaci&oacute;n. Su boga es el ancla din&aacute;mica que permite que el resto del motor central se enfoque en la frecuencia, mientras &eacute;l asegura la proyecci&oacute;n lineal.",
                    "$displayName optimiza la transmisi&oacute;n de vatios mediante un uso inteligente de su centro de gravedad, descargando la fuerza en el momento de m&aacute;xima presi&oacute;n. Esta t&eacute;cnica de 'ca&iacute;da sobre el remo' permite mover el bote con una eficiencia inalcanzable para remeros m&aacute;s ligeros.",
                    "$displayName genera un efecto de succi&oacute;n inercial que ayuda a que el bote mantenga su trayectoria rectil&iacute;nea incluso con corrientes laterales fuertes. Su boga es la columna vertebral de la estabilidad en el bloque motor, proporcionando una base de fuerza inamovible y muy potente.",
                    "$displayName utiliza su veteran&iacute;a para dosificar la inercia, asegurando que el bote no pierda velocidad en los tramos de boga contra corriente. Su capacidad para mantener la 'bola' del bote en movimiento es fundamental para no agotar las reservas de gluc&oacute;geno de la tripulaci&oacute;n.",
                    "$displayName proyecta una boga de gran calibre que desplaza el agua con una autoridad biomec&aacute;nica superior, elevando el MPP del equipo. Su intervenci&oacute;n garantiza que la trainera mantenga un ritmo de crucero de &eacute;lite, minimizando el impacto de las variaciones externas del campo.",
                    "$displayName utiliza su veteran&iacute;a para gestionar la inercia r&iacute;tmica, asegurando que el bote no pierda velocidad en los tramos de boga plana contra corriente. Su capacidad para mantener la 'bola' del bote in movimiento es fundamental para no agotar las reservas de gluc&oacute;geno de la tripulaci&oacute;n de Aizburua.",
                    "$displayName inyecta una inercia pasiva que ayuda a estabilizar la trainera ante las rachas de viento racheado, actuando como un lastre activo de alta eficiencia. Su boga destaca por una tracci&oacute;n profunda que aprovecha su masa para generar un empuje constante y muy predecible para el resto de la tripulaci&oacute;n.",
                    "$displayName coordina el bloque motor con una boga de gran proyecci&oacute;n, donde el peso se convierte en un activo t&aacute;ctico para el planeo hidrodin&aacute;mico. Al mover su cuerpo con una cadencia master, consigue que la trainera deslice con una facilidad biomec&aacute;nica excepcional, ahorrando segundos preciosos en cada largo.",
                    "$displayName aporta la solidez necesaria en el n&uacute;cleo del bote para que el equipo pueda mantener ritmos de competici&oacute;n de &eacute;lite bajo m&aacute;xima fatiga muscular. Su boga es el motor de inercia funcional que sostiene al equipo en los momentos m&aacute;s cr&iacute;ticos, garantizando un rendimiento constante y muy competitivo.",
                    "$displayName destaca por una boga de gran calibre biomec&aacute;nico, capaz de desplazar el agua con una autoridad f&iacute;sica que se traduce in metros reales de avance neta. Su capacidad para sostener la velocidad de crucero mediante el uso de su masa es lo que permite al equipo dominar la tanda con una superioridad t&eacute;cnica n&iacute;tida."
                )
                Impacts = @(
                    "Vence la resistencia en mar pesada mediante el uso inteligente del 'momentum', atravesando la ola con una menor p&eacute;rdida de velocidad relativa. Esta capacidad de 'perforar' el agua permite al equipo mantener ritmos de competici&oacute;n en las condiciones m&aacute;s duras y exigentes.",
                    "Reduce las turbulencias por cabeceo (pitching) al estabilizar el centro de gravedad del bote, mejorando dr&aacute;sticamente la hidrodin&aacute;mica global. Al mantener el morro en una posici&oacute;n estable, asegura que el flujo de agua sea constante, facilitando el planeo y reduciendo la fricci&oacute;n superficial.",
                    "Aporta una estabilidad inercial que es clave para mantener la velocidad de crucero en largos prolongados sin incurrir en fatiga prematura. Al delegar parte del avance en la inercia de su masa, consigue que el bote mantenga su velocidad con un menor coste metab&oacute;lico para el resto del equipo.",
                    "Transforma el peso elevado en un activo t&aacute;ctico (efecto volante) que ayuda a conservar la energ&iacute;a cin&eacute;tica de toda la tripulaci&oacute;n durante la prueba. Este efecto es vital en los tramos de regata con corriente a favor, donde la masa inercial ayuda a que el bote recorra m&aacute;s metros por impulso.",
                    "Mitiga las deceleraciones bruscas en el recobro, manteniendo una velocidad de avance mucho m&aacute;s homog&eacute;nea durante todo el ciclo de boga r&iacute;tmica. Al evitar los picos de frenado, reduce el esfuerzo necesario para volver a acelerar la trainera en cada palada, optimizando la energ&iacute;a total.",
                    "Asegura que el bote 'pise' con firmeza en el agua, evitando rebotes hidrodin&aacute;micos que podr&iacute;an penalizar el tiempo neto de la regata. Esta solidez de apoyo es fundamental para que los marcadores puedan mantener un ritmo estable, sabiendo que la base central del bote es un anclaje de inercia s&oacute;lido.",
                    "Optimiza el trimado lateral al actuar como un anclaje de masa en su banda, compensando posibles desequilibrios de fuerza del equipo. Su peso ayuda a mantener la horizontalidad de la trainera, lo que es vital para que las palas de ambos lados trabajen a la misma profundidad hidrodin&aacute;mica.",
                    "Aumenta la eficiencia de la tracci&oacute;n al proporcionar una resistencia inercial que facilita el apoyo de la pala en el momento del ataque inicial. Al tener una masa mayor que mover, la pala encuentra un punto de apoyo m&aacute;s firme, permitiendo una descarga de potencia m&aacute;s inmediata y efectiva.",
                    "Contribuye a una sensaci&oacute;n de robustez en el bote, permitiendo que la trainera mantenga su trayectoria incluso con vientos cruzados fuertes. Su masa act&uacute;a como una quilla din&aacute;mica que sujeta el bote en su calle, proporcionando una plataforma de gobierno noble y predecible para el patr&oacute;n.",
                    "Permite una boga m&aacute;s econ&oacute;mica en t&eacute;rminos de ox&iacute;geno al delegar parte del avance en la inercia generada por la masa en movimiento. Esta 'inercia funcional' es un recurso t&aacute;ctico de primer nivel, donde la gesti&oacute;n de la energ&iacute;a es clave para conseguir el mejor tiempo final en la tanda.",
                    "Maximiza el planeo hidrodin&aacute;mico al reducir las micro-frenadas, lo que permite al equipo mantener velocidades de crucero superiores con una menor frecuencia de palada. Su intervenci&oacute;n es el catalizador que permite que el bote 'deslice' con una facilidad biomec&aacute;nica excepcional.",
                    "Garantiza que la potencia del motor central se traduzca en metros reales de avance, evitando que la trainera 'baile' sobre el agua. Su masa inercial es el pilar que sujeta la velocidad del bote, asegurando que cada vatio generado tenga un impacto directo en el cron&oacute;metro.",
                    "Reduce el impacto de las corrientes de fondo en la r&iacute;a, aportando una solidez que permite al bote avanzar con una trayectoria rectil&iacute;nea y limpia. Su boga es el motor de estabilidad que permite al patr&oacute;n centrarse en la trazada &oacute;ptima sin preocuparse por la deriva lateral.",
                    "Proporciona una ventaja t&aacute;ctica en los tramos de regata con viento de cara, donde su masa ayuda a romper la resistencia del aire y mantener la proyecci&oacute;n. Esta capacidad de 'perforar' los elementos es lo que distingue a los remeros de inercia funcional de Aizburua.",
                    "Asegura una llegada al tramo final con una mayor reserva de potencia, gracias a una boga que ha priorizado la eficiencia inercial durante toda la prueba. Su contribuci&oacute;n es la garant&iacute;a de que la trainera tendr&aacute; ese extra de velocidad necesario para ganar la tanda en el sprint de meta."
                )
            }
            Balance = @{
                Subs = @("Equilibrio T&eacute;cnico y Soporte Master", "Referente de Estabilidad y Transmisi&oacute;n", "Soporte R&iacute;tmico del Bloque Motor", "Gesti&oacute;n de Potencia y Eficiencia Central", "Pilar Biomec&aacute;nico de la Bancada", "Coordinador de Esfuerzo Central", "Eje de Estabilidad Biomec&aacute;nica", "Soporte R&iacute;tmico de Alta Madurez", "Referente de Transmisi&oacute;n S&iacute;ncrona", "Gesti&oacute;n de Esfuerzo en el Motor", "Equilibrio Biomec&aacute;nico Master", "Sensor de Estabilidad y Apoyo", "Estratega de Soporte en Motor", "Referente de Cohesi&oacute;n Estructural", "Anclaje de Estabilidad en Motor Central")
                Elections = @(
                    "$displayName aporta una estabilidad master que sirve de base s&oacute;lida para que los remeros m&aacute;s j&oacute;venes puedan aplicar toda su fuerza bruta sin riesgos. Su boga destaca por una madurez t&eacute;cnica que asegura que el bloque motor central funcione como un reloj suizo, manteniendo una sincron&iacute;a perfecta que es la base del planeo hidrodin&aacute;mico de la trainera.",
                    "$displayName asegura una transmisi&oacute;n s&iacute;ncrona y eficiente de la potencia desde las piernas hasta el remo, evitando fugas de energ&iacute;a par&aacute;sitas en la bancada. Al mantener una postura biomec&aacute;nicamente impecable, consigue que cada gramo de fuerza generado en el banco se transmita de forma &iacute;tegra hacia la pala, optimizando el rendimiento de cada vatio invertido.",
                    "$displayName lidera el bloque central con una boga pausada pero muy potente que garantiza la homogeneidad del esfuerzo en toda la bancada de su banda. Su capacidad para mantener el orden bajo fatiga es lo que permite que el bote no se desuna en los momentos cr&iacute;ticos de la regata, actuando como el pegamento r&iacute;tmico que mantiene a la tripulaci&oacute;n unida.",
                    "$displayName gestiona la entrega de potencia de forma inteligente y t&aacute;ctica, optimizando el consumo de ox&iacute;geno en los tramos m&aacute;s duros del recorrido. Su veteran&iacute;a le permite saber cu&aacute;ndo apretar y cu&aacute;ndo conservar, asegurando que el bote mantenga una velocidad media alta durante los 3 kil&oacute;metros sin riesgo de desfallecimiento metab&oacute;lico.",
                    "$displayName act&uacute;a como el eje de equilibrio de su banda, asegurando que la potencia se transmita de forma lineal y limpia hacia el casco de la embarcaci&oacute;n. Su boga es un ejemplo de control cin&eacute;tico, donde el tronco y los brazos trabajan en total armon&iacute;a para maximizar la palanca hidrodin&aacute;mica, reduciendo el estr&eacute;s mec&aacute;nico sobre la estructura de la trainera.",
                    "$displayName destaca por una t&eacute;cnica de palada muy depurada que minimiza el gasto energ&eacute;tico sin comprometer la velocidad de crucero en ning&uacute;n momento. Esta eficiencia t&eacute;cnica es el resultado de a&ntilde;os de experiencia, donde el remero ha aprendido a leer la presi&oacute;n del agua para aplicar la fuerza justa en el momento exacto de m&aacute;xima rentabilidad biomec&aacute;nica.",
                    "$displayName aporta una calma r&iacute;tmica que es vital para mantener la concentraci&oacute;n del equipo en los momentos de m&aacute;xima fatiga muscular y mental. Su presencia en el motor central transmite seguridad al resto de compa&ntilde;eros, permitiendo que el equipo mantenga la 'cabeza fr&iacute;a' para ejecutar la estrategia marcada por el patr&oacute;n bajo cualquier circunstancia.",
                    "$displayName coordina el paso por agua con una precisi&oacute;n que evita la formaci&oacute;n de turbulencias en la zona de m&aacute;xima manga del bote hidrodin&aacute;mico. Al asegurar que la pala entre y salga del agua con una limpieza total, minimiza la resistencia al avance, permitiendo que la potencia generada por los remeros m&aacute;s fuertes se traduzca en una velocidad de planeo superior.",
                    "$displayName utiliza su veteran&iacute;a para corregir sutilmente el trimado del bote mediante peque&ntilde;os ajustes en la presi&oacute;n de su palada en tiempo real. Esta capacidad de ajuste microm&eacute;trico es lo que diferencia a un remero master de uno joven, aportando una finura t&eacute;cnica que permite que la trainera navegue siempre en su posici&oacute;n de m&iacute;nima resistencia.",
                    "$displayName inyecta una solidez que permite al motor central funcionar como una unidad perfectamente engranada y muy eficiente r&iacute;tmicamente. Su boga es el soporte sobre el que descansa el ritmo del bote, proporcionando una referencia estable y potente que ayuda a que el resto de la tripulaci&oacute;n mantenga un arco de palada largo y efectivo.",
                    "$displayName destaca por una boga de gran equilibrio estructural, capaz de compensar las asimetr&iacute;as de empuje con una naturalidad t&eacute;cnica superior en cada palada. Su capacidad para armonizar las fuerzas de su banda asegura que la trainera navegue con una horizontalidad envidiable, minimizando el rozamiento lateral del casco.",
                    "$displayName inyecta una estabilidad necesaria en el motor central, asegurando que el trimado lateral se mantenga constante bajo m&aacute;xima carga competitiva. Su boga destaca por una firmeza en el apoyo que evita cualquier tipo de balanceo par&aacute;sito, garantizando un avance limpio y n&iacute;tido de toda la tripulaci&oacute;n.",
                    "$displayName utiliza su coordinaci&oacute;n biomec&aacute;nica para armonizar la boga de su banda, actuando como el regulador de fuerza y equilibrio del equipo. Al sentir el agua con una sensibilidad master, consigue ajustar la presi&oacute;n de su palada para compensar las irregularidades de la mar, manteniendo la estabilidad del conjunto.",
                    "$displayName coordina la transmisi&oacute;n de vatios con una simetr&iacute;a que minimiza las p&eacute;rdidas por gui&ntilde;ada hidrodin&aacute;mica de la embarcaci&oacute;n en cada ciclo. Su boga es el pilar de equilibrio sobre el que se apoya el resto del bloque motor, proporcionando una base s&oacute;lida y muy predecible para que el equipo rinda al m&aacute;ximo.",
                    "$displayName aporta la firmeza necesaria en el bloque motor para que la trainera navegue con una horizontalidad y rapidez excepcionales en la regata. Su boga destaca por una naturalidad que esconde una gran potencia t&eacute;cnica, permitiendo que el bote avance con una suavidad aparente que es el sello de la boga de Aizburua."
                )
                Impacts = @(
                    "Optimiza el aprovechamiento del h&aacute;ndicap del motor, aportando una madurez t&eacute;cnica que reduce dr&aacute;sticamente los errores bajo fatiga acumulada. Su presencia no solo suma segundos por la tabla ABE, sino que ahorra segundos reales al evitar fallos t&eacute;cnicos que podr&iacute;an penalizar la velocidad del bote en el tramo final de la competici&oacute;n.",
                    "Asegura una entrega de potencia constante y sin fisuras r&iacute;tmicas, lo que se traduce en un paso por agua fluido, potente y sin tirones par&aacute;sitos. Esta continuidad en la tracci&oacute;n es fundamental para mantener el flujo laminar bajo el casco, asegurando que la trainera no pierda su sustentaci&oacute;n hidrodin&aacute;mica en ning&uacute;n momento del ciclo de boga.",
                    "Mantiene la fluidez en el n&uacute;cleo del bote, actuando como un amortiguador natural de las irregularidades r&iacute;tmicas de la tripulaci&oacute;n en la regata. Al absorber las peque&ntilde;as variaciones de cadencia de sus compa&ntilde;eros, consigue que el bote mantenga una velocidad media m&aacute;s alta, reduciendo las p&eacute;rdidas de energ&iacute;a por aceleraciones innecesarias.",
                    "Mejora la coordinaci&oacute;n t&eacute;cnica de su banda, asegurando que el &aacute;ngulo de palada sea el &oacute;ptimo para maximizar la tracci&oacute;n hidrodin&aacute;mica efectiva. Su boga sirve de gu&iacute;a para los remeros colindantes, unificando la profundidad de la pala y el tiempo de presi&oacute;n, lo que resulta en una propulsi&oacute;n mucho m&aacute;s coherente y potente por parte de todo el bloque.",
                    "Reduce la fatiga mental del bloque motor al proporcionar un ritmo de boga predecible, s&oacute;lido y extremadamente eficiente en cada ciclo r&iacute;tmico. Al saber exactamente qu&eacute; esperar de su compa&ntilde;ero de bancada, el resto de remeros pueden centrarse en su propia entrega de potencia, lo que eleva la eficiencia global de la tripulaci&oacute;n de forma notable.",
                    "Facilita el mantenimiento de la velocidad en condiciones de mar rizada, aportando una estabilidad que es clave para no perder el planeo hidrodin&aacute;mico. Su capacidad para mantener el orden t&eacute;cnico cuando el agua se vuelve dif&iacute;cil es una garant&iacute;a de rendimiento, permitiendo que el bote siga 'corriendo' mientras otros rivales empiezan a perder su fluidez.",
                    "Asegura que la trainera no pierda su trimado longitudinal, equilibrando las fuerzas de empuje con una gesti&oacute;n magistral de la palanca biomec&aacute;nica. Al modular su entrega de fuerza seg&uacute;n las necesidades del bote, consigue que la quilla se mantenga siempre paralela a la superficie del agua, minimizando el rozamiento y maximizando la velocidad punta.",
                    "Contribuye a una boga m&aacute;s silenciosa y limpia, lo que indica una menor resistencia al avance y un mejor aprovechamiento de la potencia generada. El silencio de su palada es el indicador de una t&eacute;cnica perfecta, donde la pala interact&uacute;a con el agua sin generar turbulencias innecesarias, transformando cada vatio en avance puro y efectivo.",
                    "Optimiza la transmisi&oacute;n de vatios al remo, asegurando que cada gramo de fuerza se convierta en avance real sin p&eacute;rdidas estructurales en la regala. Su boga destaca por una firmeza en el apoyo que permite descargar toda la energ&iacute;a de las piernas de forma instant&aacute;nea, maximizando la efectividad de la palanca hidrodin&aacute;mica en el momento de m&aacute;xima carga.",
                    "Aporta la experiencia necesaria para gestionar las rachas de viento lateral, ajustando la boga para mantener la velocidad sin comprometer el ritmo colectivo. Su capacidad de adaptaci&oacute;n le permite compensar los empujes del viento mediante sutiles cambios en el arco de palada, manteniendo la trainera en su rumbo ideal con una econom&iacute;a de esfuerzo magistral.",
                    "Mejora la estabilidad r&iacute;tmica del bloque motor al proporcionar una referencia de equilibrio s&oacute;lida que gu&iacute;a la boga de toda la tripulaci&oacute;n del equipo. Al sentir la firmeza en el centro, los remeros pueden sincronizar su propia entrega de potencia con mayor confianza, resultando en una propulsi&oacute;n mucho m&aacute;s coherente.",
                    "Maximiza la eficiencia de la tracci&oacute;n mediante un control milim&eacute;trico del trimado lateral, asegurando que ambas bandas trabajen a la misma profundidad hidrodin&aacute;mica. Esta simetr&iacute;a de boga es fundamental para evitar la deriva y garantizar que el esfuerzo del equipo se traduzca &iacute;ntegramente en velocidad de avance neta.",
                    "Contribuye a una boga de gran proyecci&oacute;n lineal que destaca por su capacidad de mantener el bote estable incluso bajo frecuencias de boga de alt&iacute;sima intensidad. Su equilibrio es el factor que permite a Aizburua mantener su velocidad de crucero en las condiciones m&aacute;s dif&iacute;ciles, asegurando un rendimiento constante y muy competitivo.",
                    "Garantiza una llegada al tramo final con una moral de equipo elevada, sintiendo que el n&uacute;cleo del bote es un motor inagotable de estabilidad y seguridad. Al ver que el equilibrio no se pierde, el resto de la tripulaci&oacute;n se siente motivada para dar su 100%, resultando en un rendimiento colectivo que supera las expectativas f&iacute;sicas."
                )
            }
        }
        Proa = @{
            React = @{
                Subs = @("Reactividad Proel y Vanguardia Hidrodin&aacute;mica", "Sensor de Boga y Respuesta Frontal", "Agilidad de Proa en Aguas Abiertas", "Perfil de Ataque R&aacute;pido y Ligero", "Dinamismo de Proa Cr&iacute;tico", "Sensor de Oleaje y Respuesta R&aacute;pida", "Agilidad Frontal de Alta Frecuencia", "Proel de Ataque Din&aacute;mico", "Eje de Reactividad Frontal", "Vanguardia de Planeo de Proa", "Reactividad Frontal Master", "Sensor de Agilidad y Proyecci&oacute;n", "Estratega de Ataque en Proa", "Referente de Fluidez Estructural", "Anclaje de Reactividad en Proa")
                Elections = @(
                    "$displayName evita el hundimiento de la proa en la ola mediante una boga ligera, reactiva y muy t&eacute;cnica que mantiene el morro elevado en todo momento. Su agilidad es el seguro de vida del bote en condiciones de mar movida, asegurando que la trainera 'monte' la ola en lugar de chocar contra ella, lo que preserva la inercia ganada por el bloque motor central.",
                    "$displayName permite un planeo frontal superior, ajustando su masa corporal para facilitar que el bote 'monte' la ola con total facilidad hidrodin&aacute;mica. Su capacidad para mover el tronco con rapidez durante el recobro ayuda a trimar el bote de forma din&aacute;mica, compensando los movimientos del agua y manteniendo la plataforma de boga en una horizontalidad perfecta.",
                    "$displayName agiliza el ataque de proa, proporcionando la primera tracci&oacute;n que rompe la inercia del agua en cada nuevo ciclo de palada r&iacute;tmica de alta intensidad. Al ser el primero en 'clavar' la pala, marca el inicio de la fase de propulsi&oacute;n para el resto de la tripulaci&oacute;n, actuando como el gatillo biomec&aacute;nico que activa la potencia de toda la trainera.",
                    "$displayName coordina el apoyo delantero con una boga de alta frecuencia que estabiliza el avance en aguas movidas o con corrientes fuertes y cambiantes. Su boga act&uacute;a como un sensor de presi&oacute;n que informa al patr&oacute;n sobre la dureza del agua en la vanguardia, permitiendo realizar ajustes t&aacute;cticos inmediatos para mantener la velocidad media competitiva.",
                    "$displayName utiliza su ligereza para 'liberar' la proa, permitiendo que el bote responda con rapidez a los cambios de rumbo del patr&oacute;n durante la tanda. Al reducir el lastre en el tren delantero, consigue que la trainera sea mucho m&aacute;s maniobrable, algo vital en las ciabogas y en las luchas por la calle preferente donde la agilidad es m&aacute;s importante que la fuerza.",
                    "$displayName destaca por una entrada de pala el&eacute;ctrica que minimiza el impacto frontal contra la ola, mejorando sensiblemente el flujo hidrodin&aacute;mico del conjunto. Su t&eacute;cnica de 'ataque a&eacute;reo' permite que la pala entre en el agua sin salpicaduras par&aacute;sitas, asegurando un agarre inmediato y potente que propulsa el bote con una limpieza t&eacute;cnica de nivel excepcional.",
                    "$displayName aporta una visi&oacute;n frontal privilegiada que ayuda a anticipar los movimientos del agua y ajustar la boga en consecuencia para toda su banda. Su capacidad de lectura de la mar le permite 'esquivar' los senos de la ola m&aacute;s profundos, ajustando la profundidad de la palada para mantener siempre un apoyo s&oacute;lido y evitar paladas en el aire (asustar al pez).",
                    "$displayName coordina con el resto de la vanguardia para asegurar una tracci&oacute;n sim&eacute;trica que mantenga el bote perfectamente rectil&iacute;neo en el momento del ataque inicial. Esta sincron&iacute;a en la proa es la base de un buen rumbo, ya que cualquier desequilibrio de fuerza se magnifica a lo largo de los 12 metros de la trainera, penalizando la eficiencia del conjunto.",
                    "$displayName utiliza su agilidad para realizar un recobro muy a&eacute;reo, evitando que las salpicaduras de la ola frenen el avance del bote en la fase de deslizamiento. Al mantener los remos altos y limpios durante la fase de recuperaci&oacute;n, minimiza la resistencia al aire y al agua, permitiendo que la inercia residual del bloque motor trabaje sin ning&uacute;n tipo de freno externo.",
                    "$displayName inyecta una energ&iacute;a reactiva en la proa que es vital para mantener la trainera 'viva' en condiciones de mar picada o viento racheado de proa. Su boga es un ejemplo de dinamismo, obligando a que la punta del bote est&eacute; siempre en movimiento ascendente, lo que favorece el planeo y reduce dr&aacute;sticamente la superficie mojada en el tren delantero.",
                    "$displayName destaca por un ataque ultra-r&aacute;pido que sit&uacute;a la proa en el agua con una precisi&oacute;n milim&eacute;trica en cada ciclo r&iacute;tmico competitivo. Su capacidad para 'clavar' la pala de forma instant&aacute;nea asegura que el bote no pierda inercia en el momento cr&iacute;tico de la entrada, proporcionando un apoyo frontal s&oacute;lido y muy reactivo.",
                    "$displayName inyecta una reactividad frontal que es vital para superar el cabeceo r&aacute;pido en condiciones de mar picada o viento de proa racheado. Su boga destaca por una chispa biomec&aacute;nica que obliga al bote a mantenerse 'vivo' en la vanguardia, evitando que el morro se clave y reduciendo la resistencia al avance de forma notable.",
                    "$displayName utiliza su agilidad biomec&aacute;nica para 'robar' metros en la entrada de la pala, maximizando la tracci&oacute;n efectiva del equipo de Aizburua. Al mover sus brazos con una rapidez excepcional, consigue que la fase de propulsi&oacute;n sea m&aacute;s larga y eficiente, elevando el MPP global de su banda con una naturalidad t&eacute;cnica envidiable.",
                    "$displayName coordina la salida de agua en proa con una limpieza que favorece el planeo inmediato y n&iacute;tido de la trainera competitiva de &eacute;lite. Su t&eacute;cnica de 'liberaci&oacute;n frontal' es la clave para que el bote no se detenga tras la tracci&oacute;n, permitiendo que la inercia trabaje a favor del equipo en cada ciclo de palada.",
                    "$displayName aporta la chispa necesaria en las bancadas delanteras para que el bote responda con nobleza a cada demanda del patr&oacute;n del equipo. Su reactividad es el factor diferencial en las ciabogas, garantizando que la proa gire con una rapidez sorprendente y recupere la l&iacute;nea de boga de forma instant&aacute;nea y potente."
                )
                Impacts = @(
                    "Proporciona una respuesta inmediata al oleaje, permitiendo al patr&oacute;n realizar correcciones de rumbo m&aacute;s precisas, seguras y r&aacute;pidas en cada momento. Esta reactividad de proa es la que permite al equipo trazar las ciabogas m&aacute;s cerradas de la tanda, ganando metros preciosos a los rivales gracias a un punto de giro &aacute;gil y perfectamente coordinado con el tim&oacute;n.",
                    "Facilita la recuperaci&oacute;n del trimado longitudinal tras cada palada, asegurando que el bote recupere su posici&oacute;n ideal de planeo hidrodin&aacute;mico de forma inmediata. Al evitar que el morro se hunda al final de la tracci&oacute;n, consigue que el flujo de agua bajo el casco se mantenga laminar, lo que se traduce en una menor p&eacute;rdida de velocidad entre cada ciclo de boga.",
                    "Maximiza la precisi&oacute;n en la maniobra de ciaboga al proporcionar un punto de giro &aacute;gil, potente y que reduce dr&aacute;sticamente el radio de giro de la trainera. Su boga de ciaboga es una lecci&oacute;n de biomec&aacute;nica, utilizando la palanca del remo para pivotar la masa de 800kg con una facilidad que solo la combinaci&oacute;n de agilidad y t&eacute;cnica puede conseguir.",
                    "Reduce el impacto del choque contra la ola (slamming), suavizando el avance del bote y mejorando el confort t&eacute;cnico de toda la tripulaci&oacute;n en el agua. Al 'levantar' la proa justo antes del impacto con la cresta, minimiza la desaceleraci&oacute;n brusca que suele ocurrir en mar abierta, manteniendo una velocidad de crucero mucho m&aacute;s constante y menos fatigante.",
                    "Mejora la sustentaci&oacute;n de la proa en el recobro, evitando que el casco arrastre agua innecesaria y penalice la velocidad punta neta del conjunto en regata. Esta ligereza frontal es el mejor aliado del planeo, permitiendo que el bote mantenga su quilla plana y su morro fuera del agua, reduciendo la resistencia total al avance en m&aacute;s de un 15% seg&uacute;n los modelos t&eacute;cnicos.",
                    "Asegura un ataque n&iacute;tido y sin dudas, lo que es fundamental para que el resto de la tripulaci&oacute;n sienta un apoyo frontal s&oacute;lido y gu&iacute;e su propia boga. Su 'golpe' inicial es la referencia para los motores centrales, unificando el tiempo de entrada y asegurando que la potencia de todo el equipo se descargue de forma perfectamente s&iacute;ncrona sobre el agua.",
                    "Optimiza la hidrodin&aacute;mica de la proa al reducir el tiempo de fricci&oacute;n de la pala en el agua, favoreciendo un deslizamiento m&aacute;s largo y eficiente del bote. Al 'robar' metros en cada palada mediante una salida de pala ultra-r&aacute;pida, consigue elevar el MPP de su banda, compensando posibles d&eacute;ficits de fuerza bruta con una eficiencia t&eacute;cnica de primer orden competitivo.",
                    "Contribuye a una boga m&aacute;s aerodin&aacute;mica en la vanguardia, lo que es cr&iacute;tico en regatas con fuerte viento de proa o rachas laterales que intentan frenar el bote. Al mantener un perfil de boga bajo y compacto, reduce la superficie de exposici&oacute;n al viento, permitiendo que la trainera mantenga su velocidad de crucero incluso en las condiciones meteorol&oacute;gicas m&aacute;s duras.",
                    "Facilita la lectura de la regata desde la vanguardia, aportando informaci&oacute;n visual que el patr&oacute;n puede utilizar para su estrategia t&aacute;ctica en tiempo real. Su capacidad para detectar cambios en la marea o la aparici&oacute;n de rachas de viento en el campo de regatas permite al equipo anticiparse a las dificultades, manteniendo siempre la calle m&aacute;s ventajosa para su boga.",
                    "Aporta la agilidad necesaria para subir la frecuencia de palada de forma instant&aacute;nea en el momento de m&aacute;xima exigencia t&aacute;ctica o ataque final. Su boga es el motor de revoluciones del bote, capaz de subir la cadencia en cuesti&oacute;n de segundos para responder a un ataque rival o para lanzar el sprint definitivo hacia la boya de meta con total autoridad.",
                    "Maximiza la reactividad biomec&aacute;nica en la vanguardia, permitiendo que el equipo mantenga la 'bola' del bote en movimiento incluso con frecuencias de boga extremas. Esta capacidad de mantener el bote vivo es lo que permite a Aizburua marcar la diferencia en los metros finales, donde la agilidad t&eacute;cnica decide la victoria.",
                    "Optimiza la hidrodin&aacute;mica de la entrada frontal, reduciendo el choque contra la ola mediante una boga ligera y perfectamente coordinada con el ritmo de proa. Al 'montar' el agua con suavidad, evita desaceleraciones bruscas que podr&iacute;an penalizar el tiempo neto, garantizando un avance laminar y muy eficiente.",
                    "Mejora la respuesta de la vanguardia ante las demandas de agilidad del tim&oacute;n, facilitando trazar las l&iacute;neas m&aacute;s cortas e inteligentes en el r&iacute;o. Al contar con una proa reactiva, el bote responde con mayor nobleza a cada indicaci&oacute;n del patr&oacute;n, ahorrando metros preciosos en cada largo de la regata.",
                    "Contribuye a un flujo de agua m&aacute;s estable bajo el casco al evitar movimientos de masa bruscos que podr&iacute;an provocar turbulencias innecesarias en el planeo frontal. Su boga fluida es el mejor aliado del hidrodinamismo de proa, asegurando que la superficie de contacto con el agua sea siempre la m&aacute;s eficiente posible.",
                    "Garantiza una boga de gran proyecci&oacute;n que destaca por su capacidad de 'robar' metros en el recobro r&iacute;tmico, gracias a una agilidad t&eacute;cnica superior. Esta capacidad de deslizamiento es lo que permite al equipo competir al m&aacute;s alto nivel, manteniendo la inercia con una elegancia y rapidez t&eacute;cnica que definen el estilo Aizburua."
                )
            }
            Vision = @{
                Subs = @("Coordinaci&oacute;n de Proa Master y Control", "Visi&oacute;n T&eacute;cnica y Referencia Frontal", "Estrategia de Proa y Gesti&oacute;n de Ataque", "Perfil T&eacute;cnico de Alta Precisi&oacute;n Frontal", "Maestr&iacute;a en Lectura de Ola", "Gu&iacute;a T&eacute;cnico de la Vanguardia", "Estratega Frontal de Alta Madurez", "Referente de Precisi&oacute;n en Proa", "Vig&iacute;a Biomec&aacute;nico de proa", "Control r&iacute;tmico de la Vanguardia", "Visi&oacute;n Frontal Master", "Sensor de Estrategia y Control", "Estratega de Proyecci&oacute;n en Proa", "Referente de Cohesi&oacute;n T&aacute;ctica", "Anclaje de Visi&oacute;n en Proa")
                Elections = @(
                    "$displayName aporta una veteran&iacute;a t&eacute;cnica cr&iacute;tica para leer el estado cambiante del agua y ajustar la boga de proa con maestria master absoluta. Su experiencia le permite anticipar el movimiento de la ola segundos antes de que impacte con el casco, ajustando el arco de palada para que la tracci&oacute;n sea siempre efectiva y el bote no pierda ni un gramo de inercia hidrodin&aacute;mica.",
                    "$displayName asegura la simetr&iacute;a frontal absoluta del bote, coordinando el esfuerzo del bloque de proa para un avance perfectamente rectil&iacute;neo y potente. Su boga es la referencia t&eacute;cnica de la vanguardia, manteniendo un orden y una limpieza de gesto que se contagia al resto de la tripulaci&oacute;n, facilitando que el bloque motor central pueda trabajar con total confianza y seguridad.",
                    "$displayName optimiza la entrada en proa mediante una lectura experta de la ola, evitando entradas 'sucias' que podr&iacute;an frenar el bote en plena aceleraci&oacute;n. Su t&eacute;cnica de 'agarre profundo' asegura que la pala encuentre agua densa y sin aire desde el primer cent&iacute;metro, maximizando la propulsi&oacute;n frontal y reduciendo las p&eacute;rdidas de potencia por turbulencia superficial.",
                    "$displayName lidera el apoyo delantero con una boga de gran control que sirve de gu&iacute;a t&eacute;cnica absoluta para el resto de la tripulaci&oacute;n en la tanda. Su presencia en la vanguardia es un seguro contra la descoordinaci&oacute;n, manteniendo una cadencia estable y predecible que ayuda a que el bote navegue con una nobleza excepcional incluso bajo las condiciones de fatiga m&aacute;s extremas del d&iacute;a.",
                    "$displayName act&uacute;a como el vig&iacute;a t&eacute;cnico de la trainera, anticipando con su boga las correcciones necesarias ante el oleaje lateral o las corrientes de r&iacute;o. Su capacidad para modular la presi&oacute;n de su palada ayuda a que el bote mantenga su rumbo ideal sin necesidad de correcciones bruscas del tim&oacute;n, lo que redunda en una mejora directa de la eficiencia hidrodin&aacute;mica del casco.",
                    "$displayName destaca por una gesti&oacute;n magistral del arco de palada en proa, asegurando que la tracci&oacute;n sea efectiva desde el primer cent&iacute;metro de recorrido. Su biomec&aacute;nica est&aacute; orientada a exprimir al m&aacute;s alto nivel la palanca del remo, aprovechando su experiencia para aplicar la fuerza en el punto de m&aacute;xima rentabilidad, ahorrando vatios para el tramo final de la regata.",
                    "$displayName aporta una calma t&eacute;cnica en la vanguardia que es vital para que el bloque motor pueda centrarse en la entrega de vatios de alta intensidad. Su boga pausada, pero extremadamente potente y precisa, transmite una sensaci&oacute;n de control absoluto que eleva la moral de toda la tripulaci&oacute;n, sintiendo que la trainera est&aacute; siempre bajo el mando de manos expertas.",
                    "$displayName utiliza su experiencia para modular la intensidad del ataque en proa, evitando picos de fuerza que desestabilicen el trimado longitudinal del conjunto. Al suavizar la curva de potencia en la vanguardia, consigue que el bote no 'pique' el agua, favoreciendo un deslizamiento laminar que es la marca de las mejores tripulaciones de veteranos de la liga.",
                    "$displayName coordina con el patr&oacute;n la estrategia de boga en aguas dif&iacute;ciles, aportando una visi&oacute;n experta desde la primera l&iacute;nea de boga en la proa. Su capacidad para comunicarse mediante el gesto t&eacute;cnico permite que el equipo ajuste su intensidad sin necesidad de gritos, manteniendo una concentraci&oacute;n total en el esfuerzo f&iacute;sico y en la boga r&iacute;tmica colectiva.",
                    "$displayName inyecta una precisi&oacute;n en la salida de la pala que es clave para evitar frenados par&aacute;sitos en la fase de m&aacute;xima velocidad de planeo frontal. Su t&eacute;cnica de 'salida el&eacute;ctrica' libera el bote de cualquier atadura con el agua al final de la tracci&oacute;n, permitiendo que la inercia generada por el motor se traduzca en una proyecci&oacute;n lineal m&aacute;s larga y eficiente.",
                    "$displayName destaca por una lectura t&aacute;ctica del campo de regatas que permite anticipar las rachas de viento y ajustar la boga de proa en tiempo real. Su capacidad para detectar cambios sutiles en la presi&oacute;n del aire le permite modular su palada para mantener la estabilidad del conjunto, actuando como un sensor meteorol&oacute;gico humano.",
                    "$displayName inyecta una visi&oacute;n de proyecci&oacute;n lineal que ayuda a guiar el rumbo de la trainera en coordinaci&oacute;n con el bloque delantero de Aizburua. Su boga destaca por una direccionalidad impecable, asegurando que cada vatio generado se traduzca en metros reales de avance hacia la meta, minimizando las derivas laterales.",
                    "$displayName utiliza su experiencia master para optimizar el paso por ola, reduciendo el impacto del agua sobre el casco mediante una boga inteligente y muy t&eacute;cnica. Al ajustar el arco de palada seg&uacute;n la altura de la ola, consigue que el bote navegue con una suavidad excepcional, protegiendo la inercia del bloque motor central.",
                    "$displayName coordina la informaci&oacute;n de proa hacia el bloque motor, asegurando que la tripulaci&oacute;n est&eacute; siempre alineada con el objetivo t&aacute;ctico de la regata. Su boga es el canal de comunicaci&oacute;n r&iacute;tmica del equipo, transmitiendo las sensaciones de la vanguardia para que el motor central pueda ajustar su entrega de potencia.",
                    "$displayName aporta la serenidad necesaria en los momentos de m&aacute;xima tensi&oacute;n para mantener una boga limpia y una estrategia de proa ganadora. Su veteran&iacute;a es el ancla emocional del equipo, permitiendo que los remeros m&aacute;s j&oacute;venes mantengan el orden t&eacute;cnico bajo la presi&oacute;n de la competici&oacute;n final."
                )
                Impacts = @(
                    "Evita las turbulencias de cabeceo (pitching) mediante una boga controlada que mantiene la estabilidad de la plataforma de boga central del conjunto. Al amortiguar el impacto de la ola con su propia boga, asegura que los remeros m&aacute;s fuertes no sufran tirones secos que podr&iacute;an provocar lesiones o p&eacute;rdidas de sincron&iacute;a en los momentos de m&aacute;xima tensi&oacute;n competitiva.",
                    "Facilita el planeo en zonas estrechas o de corrientes complejas, donde la precisi&oacute;n t&eacute;cnica es mucho m&aacute;s importante que la fuerza bruta inicial. Su boga es la que permite al bote 'enhebrar' la aguja entre las boyas de ciaboga o las balizas de meta con una precisi&oacute;n quir&uacute;rgica, asegurando que el equipo no pierda ni un metro por errores de rumbo o deriva.",
                    "Garantiza la limpieza absoluta en el ataque frontal, reduciendo la formaci&oacute;n de estelas par&aacute;sitas que afectar&iacute;an a la hidrodin&aacute;mica de los remos centrales. Una proa limpia es el primer paso para una boga de excelencia, y su t&eacute;cnica asegura que el agua llegue a las bancadas de motor en las mejores condiciones de flujo posibles, maximizando el agarre del resto.",
                    "Mejora la comunicaci&oacute;n t&aacute;ctica en la proa, asegurando que todas las maniobras de boga se ejecuten con una sincronizaci&oacute;n impecable y sin dudas t&eacute;cnicas. Su liderazgo desde la vanguardia es un activo estrat&eacute;gico que permite al patr&oacute;n delegar parte de la gesti&oacute;n de la proa en manos expertas, centr&aacute;ndose &eacute;l en la estrategia global de la tanda frente a los rivales.",
                    "Asegura una entrada de pala silenciosa, efectiva y profunda, maximizando la hidrodin&aacute;mica frontal en condiciones de mar rizada o viento racheado fuerte. Al evitar la entrada de aire en el hueco de la palada, garantiza que la propulsi&oacute;n sea constante desde el inicio, eliminando el riesgo de 'remar en falso' que tanto penaliza la velocidad en aguas abiertas.",
                    "Optimiza el aprovechamiento del h&aacute;ndicap en la zona delantera, aportando una madurez que es el mejor predictor de eficiencia t&eacute;cnica en el banco fijo. Su presencia no solo aporta segundos en los despachos por su edad, sino que los gana en el agua gracias a una boga que aprovecha cada gramo de fuerza con una rentabilidad biomec&aacute;nica cercana al 100%.",
                    "Contribuye a un avance m&aacute;s suave y fluido, reduciendo las vibraciones mec&aacute;nicas que penalizan el confort y la moral de todo el equipo en la trainera. Una boga fluida es menos cansada mentalmente, permitiendo que la tripulaci&oacute;n mantenga la concentraci&oacute;n durante m&aacute;s tiempo, lo que se traduce en una mayor consistencia r&iacute;tmica en los tramos decisivos de la prueba.",
                    "Mejora el trimado longitudinal al evitar movimientos bruscos de masa en la proa, favoreciendo un deslizamiento laminar constante bajo el casco del bote. Al mover su cuerpo con una suavidad master, asegura que la trainera no sufra el efecto 'sube y baja' que tanto rozamiento genera, manteniendo el bote siempre en su zona de m&iacute;nima resistencia hidrodin&aacute;mica.",
                    "Aporta la seguridad necesaria para afrontar ciabogas al l&iacute;mite de la boya, sabiendo que el proel responder&aacute; con una t&eacute;cnica perfecta y sin errores bajo presi&oacute;n. Su boga de ciaboga es el ancla sobre la que el bote gira, proporcionando un punto de apoyo firme y seguro que permite realizar la maniobra con la m&aacute;xima agresividad y rapidez posible.",
                    "Facilita la transici&oacute;n de ritmos en el tramo final de la regata, aportando una claridad t&eacute;cnica que ayuda a mantener la forma f&iacute;sica bajo m&aacute;xima fatiga muscular. Su boga es el recordatorio de que la t&eacute;cnica debe imperar cuando las fuerzas flaquean, permitiendo que el equipo termine la regata con una elegancia y potencia que a menudo se traduce en segundos de ventaja.",
                    "Contribuye a un trimado longitudinal impecable mediante una boga que asienta el morro sin clavar la proa en el agua. Este equilibrio es fundamental para que la trainera navegue siempre en su zona de m&iacute;nima resistencia hidrodin&aacute;mica.",
                    "Optimiza la respuesta del tim&oacute;n al proporcionar una proa reactiva y ligera que facilita los cambios de rumbo t&aacute;cticos del patr&oacute;n. Su visi&oacute;n frontal permite al equipo anticiparse a las corrientes y elegir siempre la mejor trazada.",
                    "Mejora la sincron&iacute;a de la vanguardia al actuar como el n&uacute;cleo de control r&iacute;tmico que unifica el esfuerzo del bloque de proa. Una proa sincronizada es el primer paso para una boga de &eacute;lite y un avance perfectamente rectil&iacute;neo.",
                    "Asegura un paso por ola m&aacute;s suave y eficiente, reduciendo las desaceleraciones bruscas que penalizan el tiempo neto en regatas de mar abierta. Su boga es el amortiguador biomec&aacute;nico que protege la inercia de todo el equipo."
                )
            }
            Support = @{
                Subs = @("Bloque de Presi&oacute;n y Apoyo Frontal", "Masa de Soporte en Zona de Ataque", "Potencia Estabilizadora de Proa", "Refuerzo T&aacute;ctico del Bloque Delantero", "Anclaje Frontal de Alta Potencia", "Refuerzo de Fuerza en Vanguardia", "Pilar de Tracci&oacute;n de Proa", "Masa Cr&iacute;tica de Empuje Frontal", "Vector de Fuerza en la Vanguardia", "Apoyo Potente de Ataque Frontal", "Soporte Frontal de Alta Inercia", "Eje de Empuje y Control de Proa", "Estratega de Apoyo en Vanguardia", "Referente de Potencia Estructural", "Anclaje de Soporte en Proa")
                Elections = @(
                    "$displayName ejerce una presi&oacute;n de proa constante que ayuda a asentar el bote en el agua durante toda la fase de tracci&oacute;n efectiva del ciclo r&iacute;tmico. Su potencia en la vanguardia es el contrapunto ideal para el motor central, asegurando que la propulsi&oacute;n se distribuya de forma m&aacute;s homog&eacute;nea a lo largo de toda la trainera, evitando que el bote pierda su horizontalidad.",
                    "$displayName coordina el bloque delantero aportando una potencia extra que es fundamental para vencer la resistencia del viento de cara en la tanda de regata. Su tracci&oacute;n profunda y potente es el motor secundario que empuja la proa a trav&eacute;s de la ola, permitiendo que el bote mantenga su inercia incluso cuando las condiciones meteorol&oacute;gicas intentan frenarlo.",
                    "$displayName inyecta vatios de apoyo fundamentales para mantener la velocidad punta en condiciones de mar pesada o corrientes fuertes y adversas en el r&iacute;o. Al descargar su potencia en el bloque delantero, consigue que la trainera 'perfore' el agua con mayor autoridad, reduciendo la formaci&oacute;n de olas par&aacute;sitas y mejorando la eficiencia hidrodin&aacute;mica global del conjunto.",
                    "$displayName utiliza su masa para estabilizar el morro del bote, evitando que las rachas de viento lateral desv&iacute;en la trayectoria frontal de la embarcaci&oacute;n. Su peso act&uacute;a como un anclaje hidrodin&aacute;mico que sujeta la proa en su sitio, facilitando enormemente el trabajo de gobierno del patr&oacute;n y permitiendo que el bote navegue de forma m&aacute;s rectil&iacute;nea y eficiente.",
                    "$displayName aporta un plus de potencia en la zona de proa, traccionando con una palanca que refuerza el ataque inicial de toda su banda competitiva. Su envergadura f&iacute;sica le permite aplicar un torque superior en la vanguardia, lo que es vital para que el bote no se 'clave' en el agua al inicio de la palada, manteniendo una aceleraci&oacute;n constante y fluida.",
                    "$displayName destaca por una tracci&oacute;n profunda y contundente en la proa, obligando al agua a ceder ante un empuje biomec&aacute;nico superior en cada palada efectiva. Su boga se caracteriza por un agarre inmediato y una descarga de fuerza progresiva que mantiene el bote en planeo constante, asegurando que la vanguardia de la trainera siempre est&eacute; en la posici&oacute;n ideal.",
                    "$displayName coordina con el motor central para asegurar que la proa no pierda inercia r&iacute;tmica, aportando vatios de refuerzo en cada palada de alta intensidad. Su funci&oacute;n es la de un amplificador de fuerza, recogiendo el ritmo de la popa y potenci&aacute;ndolo en la zona delantera, unificando la entrega de energ&iacute;a de todo el equipo de forma magistral y potente.",
                    "$displayName utiliza su fortaleza f&iacute;sica para anclar el bote en el momento del ataque inicial, proporcionando una base de fuerza que recorre toda la trainera de punta a punta. Esta solidez biomec&aacute;nica es la que permite que el bote responda con nobleza a las demandas de potencia del patr&oacute;n, convirtiendo cada palada en un avance real que se siente en el cron&oacute;metro.",
                    "$displayName inyecta una energ&iacute;a masiva en la vanguardia, permitiendo al bote romper la ola con una autoridad t&eacute;cnica envidiable y mucha potencia bruta bien aplicada. Su presencia en la proa es un mensaje de fuerza para los rivales, demostrando que Aizburua cuenta con un bloque compacto y capaz de mantener la intensidad en cualquier zona del bote sin fisuras.",
                    "$displayName act&uacute;a como el refuerzo de potencia necesario para que el proel pueda centrarse en la agilidad del gesto t&eacute;cnico y en la lectura de la ola. Al encargarse de la tracci&oacute;n pesada en el bloque delantero, libera a la vanguardia de parte de la carga f&iacute;sica, permitiendo que la punta del bote funcione con una eficacia y limpieza t&eacute;cnica inmejorables.",
                    "$displayName destaca por un empuje estructural que refuerza la boga de la vanguardia, aportando la solidez necesaria para el planeo frontal en condiciones adversas. Su potencia muscular es el motor que asegura que el morro del bote no pierda inercia, manteniendo una presi&oacute;n constante sobre la pala en cada ciclo r&iacute;tmico.",
                    "$displayName inyecta una fuerza de apoyo en las bancadas delanteras que asegura que la proa no se clave excesivamente en el momento del ataque masivo. Su boga destaca por una firmeza que ayuda a elevar ligeramente el morro, favoreciendo el planeo y reduciendo la superficie mojada del casco de forma n&iacute;tida.",
                    "$displayName utiliza su potencia muscular para anclar el ritmo en la proa, proporcionando una base s&oacute;lida para la agilidad t&eacute;cnica de sus compa&ntilde;eros de vanguardia. Al descargar su fuerza de forma sim&eacute;trica, garantiza que el bote mantenga su trayectoria rectil&iacute;nea incluso bajo frecuencias de boga de alta intensidad.",
                    "$displayName coordina la transmisi&oacute;n de vatios en la zona delantera con una eficacia que se traduce en metros reales de ventaja competitiva en cada largo de boga. Su boga es el pilar de fuerza frontal del equipo, proporcionando una referencia de empuje que motiva a toda la tripulaci&oacute;n a rendir al m&aacute;ximo.",
                    "$displayName aporta la robustez necesaria en el bloque de proa para que el equipo pueda mantener ritmos altos de competici&oacute;n sin riesgo de fatiga t&eacute;cnica prematura. Su boga destaca por una solidez que es el seguro de vida de la vanguardia, garantizando que el bote siempre tendr&aacute; la fuerza necesaria para ganar la bandera."
                )
                Impacts = @(
                    "Exige una precisi&oacute;n absoluta en la salida de la palada para evitar que el peso extra en la proa genere un efecto de hundimiento par&aacute;sito en el planeo. Al extremar la limpieza en el momento de retirar el remo, consigue que el bote recupere su trimado longitudinal de forma instant&aacute;nea, transformando su potencia en una proyecci&oacute;n lineal limpia y muy efectiva.",
                    "Requiere un control del planeo perfecto para compensar la masa adicional en la vanguardia, lo que obliga a una coordinaci&oacute;n superior con el resto de su banda. Esta exigencia t&eacute;cnica extra se traduce en una boga m&aacute;s atenta y precisa, lo que a menudo resulta en una mejora indirecta de la eficiencia global de la tripulaci&oacute;n al no poder permitirse fallos de trimado.",
                    "Estabiliza el morro en condiciones de mar dura y movida, proporcionando una inercia frontal que ayuda a mantener el rumbo firme dentro de la propia ola. Su masa act&uacute;a como un amortiguador de impactos, suavizando el avance de la trainera en aguas abiertas y permitiendo que el bloque motor central trabaje con una mayor consistencia r&iacute;tmica y potencia.",
                    "Aumenta la capacidad de tracci&oacute;n total en la proa, permitiendo un avance m&aacute;s contundente y seguro en situaciones de m&aacute;xima exigencia competitiva y fatiga. Al contar con un proel de apoyo fuerte, el bote dispone de un reservorio de potencia extra que puede ser decisivo en los adelantamientos o en las defensas de baliza m&aacute;s apretadas de la tanda.",
                    "Compensa las posibles derivas frontales mediante una entrega de potencia asim&eacute;trica controlada, estabilizando el rumbo en corrientes de r&iacute;o complejas. Su capacidad para ajustar la fuerza de su palada independientemente del resto permite corregir sutilmente la trayectoria del bote, reduciendo la necesidad de usar el tim&oacute;n y mejorando la velocidad neta.",
                    "Asegura que el bote mantenga su inercia de proa en los momentos de menor frecuencia r&iacute;tmica, evitando que el casco se detenga entre paladas de alta intensidad. Esta continuidad inercial es vital para la econom&iacute;a de esfuerzo, permitiendo que el bote siga 'corriendo' durante el recobro sin necesidad de aplicar fuerzas explosivas constantes para recuperar la velocidad.",
                    "Mejora la respuesta del bote ante ataques de fuerza de los rivales, proporcionando los vatios necesarios para contrarrestar cualquier movimiento t&aacute;ctico enemigo. Su presencia en la proa es un seguro de vida biomec&aacute;nico, garantizando que la vanguardia del bote siempre tendr&aacute; la fuerza necesaria para responder a las demandas del patr&oacute;n en los momentos cr&iacute;ticos.",
                    "Optimiza la hidrodin&aacute;mica frontal al proporcionar una masa que asienta el bote en el agua, reduciendo los rebotes par&aacute;sitos por falta de peso en la proa (bote saltar&iacute;n). Al mantener el morro en contacto constante con el agua, mejora el agarre de la quilla y reduce la resistencia aerodin&aacute;mica, lo que se traduce en un avance m&aacute;s predecible y r&aacute;pido.",
                    "Contribuye a una estela m&aacute;s potente y n&iacute;tida, indicativo biomec&aacute;nico de que el apoyo frontal est&aacute; trabajando en total sincron&iacute;a con el motor central del equipo. Una estela n&iacute;tida es el sello de una trainera que no desperdicia energ&iacute;a, donde cada palada desde la proa hasta la popa contribuye a la proyecci&oacute;n lineal del conjunto con una eficiencia impecable.",
                    "Aporta la robustez necesaria para soportar los embates del mar en regatas de gran dureza meteorol&oacute;gica, manteniendo la integridad de la boga frontal en todo momento. Su fortaleza es el pilar sobre el que se apoya la vanguardia de Aizburua, asegurando que el bote siempre estar&aacute; en disposici&oacute;n de competir al m&aacute;s alto nivel independientemente de lo dif&iacute;cil que se ponga el agua.",
                    "Mejora la estabilidad de la plataforma de boga al proporcionar un apoyo frontal s&oacute;lido y potente que contrarresta las oscilaciones laterales. Esta solidez biomec&aacute;nica es la que permite al bloque motor central trabajar con total confianza.",
                    "Optimiza el aprovechamiento de la fuerza bruta en la vanguardia, convirtiendo cada vatio generado en una proyecci&oacute;n lineal n&iacute;tida y muy contundente. Su presencia en la proa es un mensaje de potencia y autoridad para el resto de la liga.",
                    "Contribuye a una boga m&aacute;s compacta y resistente al viento, reduciendo la superficie de exposici&oacute;n y facilitando el mantenimiento de la velocidad de crucero. Al actuar como un escudo de potencia, protege la inercia del bloque motor.",
                    "Asegura un agarre profundo y sin aire en cada palada, maximizando la tracci&oacute;n efectiva en condiciones de mar pesada o corrientes fuertes en el r&iacute;o. Su boga es el motor de tracci&oacute;n pesada que garantiza el avance real del bote.",
                    "Garantiza una llegada al final de la regata con una reserva de potencia t&eacute;cnica envidiable, liderando el sprint final con una boga profunda y muy potente. Su fortaleza es el seguro de vida de la proa en los momentos m&aacute;s cr&iacute;ticos."
                )
            }
        }
    }

    # --- L&Oacute;GICA DE UNICIDAD Y SELECCI&Oacute;N (v6.2) ---
    $sub = "" ; $eleccion = "" ; $impacto = ""
    $hashSeed = "$name$pos$side"
    $hashValue = [Math]::Abs($hashSeed.GetHashCode())

    # Funci&oacute;n interna para obtener variante &uacute;nica
    function Get-UniqueVariant([string]$path, [int]$seed, [int]$count) {
        $v = $seed % $count
        $attempts = 0
        # Forzar b&uacute;squeda de variante no usada en este informe
        while ($script:usedPhrases.ContainsKey("$path-$v") -and $attempts -lt $count) {
            $v = ($v + 1) % $count
            $attempts++
        }
        $script:usedPhrases["$path-$v"] = $true
        return $v
    }

    if ($pos -match "1|2|POPA") {
        $role = if ($age -ge 55) { "Veteran" } elseif ($info.Peso -ge 82) { "Power" } else { "Agile" }
        $poolCount = $pool.Popa.$role.Subs.Count
        $variant = Get-UniqueVariant "Popa-$role" $hashValue $poolCount
        $sub = $pool.Popa.$role.Subs[$variant]
        $eleccion = $pool.Popa.$role.Elections[$variant]
        $impacto = $pool.Popa.$role.Impacts[$variant]
    }
    elseif ($pos -match "3|4|5") {
        $role = if ($age -le 50 -and $info.Peso -ge 85) { "Torque" } elseif ($age -le 50 -and $info.Peso -lt 85) { "Dynamic" } elseif ($age -gt 50 -and $info.Peso -ge 90) { "Inertial" } else { "Balance" }
        $poolCount = $pool.Motor.$role.Subs.Count
        $variant = Get-UniqueVariant "Motor-$role" $hashValue $poolCount
        $sub = $pool.Motor.$role.Subs[$variant]
        $eleccion = $pool.Motor.$role.Elections[$variant]
        $impacto = $pool.Motor.$role.Impacts[$variant]
        
        if ($info.Peso -ge 90) {
            $impacto += "<div class='tactical-alert'>$svgIcon<span><b>MASA INERCIAL FUNCIONAL (Justificaci&oacute;n Biomec&aacute;nica):</b> A sus $age a&ntilde;os, los $($info.Peso)kg de $displayName no son lastre par&aacute;sito, sino un acumulador cin&eacute;tico. Esta masa ayuda a mantener la velocidad de crucero ('momentum') entre paladas, compensando la p&eacute;rdida de explosividad natural con la edad y estabilizando el planeo longitudinal del bloque motor central.</span></div>"
        }
    }
    elseif ($pos -match "6|PROA") {
        $role = if ($info.Peso -le 75 -and $age -le 50) { "React" } elseif ($info.Peso -le 75 -and $age -gt 50) { "Vision" } else { "Support" }
        $poolCount = $pool.Proa.$role.Subs.Count
        $variant = Get-UniqueVariant "Proa-$role" $hashValue $poolCount
        $sub = $pool.Proa.$role.Subs[$variant]
        $eleccion = $pool.Proa.$role.Elections[$variant]
        $impacto = $pool.Proa.$role.Impacts[$variant]

        if ($info.Peso -gt 80) {
            $impacto += "<div class='tactical-alert'>$svgIcon<span><strong>ADVERTENCIA DE TRIMADO:</strong> Los $($info.Peso)kg de $displayName en proa pueden forzar un 'pitching' excesivo (hundimiento del morro). Se recomienda una salida de pala ultra-limpia para no clavar la proa en el recobro y mantener la hidrodin&aacute;mica frontal.</span></div>"
        }
    }

    $titulo = if ($pos -match "1|2|POPA") { "Popa / Marca" } elseif ($pos -match "3|4|5") { "Motor Central" } elseif ($pos -match "6|PROA") { "Proa / Apoyo" } else { "Posici&oacute;n" }

    if ($sub) {
        return "<div style='line-height:1.7; font-size:15px'><strong>${titulo}:</strong> <span style='color:var(--b)'>$sub</span> ($age a&ntilde;os)<br><div style='margin-top:6px'><strong>Elecci&oacute;n T&aacute;ctica:</strong> $eleccion</div><div style='margin-top:4px'><strong>Impacto Biomec&aacute;nico:</strong> $impacto</div></div>"
    }

    return "<strong>Posici&oacute;n ${pos}:</strong> Perfil de $($info.Peso)kg y $($info.Altura)cm."
}

# Pre-construir lista de alineados para poder filtrar alternativas desde el roster
$nombresAlineados = @($ali.proa.nombre, $ali.patron.nombre)
foreach ($n in 1..6) {
    $nombresAlineados += $ali.bancadas."$n".B.nombre
    $nombresAlineados += $ali.bancadas."$n".E.nombre
}

# Calcula el mejor sustituto disponible en la plantilla para un puesto dado
# Calcula el mejor sustituto disponible en la plantilla para un puesto dado
# Si se proporciona targetWeight, el sistema prioriza equilibrar la banda
function Get-BestAlternative([string]$posZone, [string]$side, [int]$titularAge, [string]$titularName, [double]$targetWeight = 0) {
    # Filtro de posicion basado en la zona del bote (posZone tiene prioridad sobre side)
    $posFilter = if ($posZone -eq "PROA") {
        "Proa|Babor|Estribor"               # remeros de cualquier banda o proa pueden ir a proa
    } elseif ($posZone -eq "PATRON") {
        "Patron"
    } else {
        switch ($side) {
            "Babor"    { "Babor" }
            "Estribor" { "Estribor" }
            default    { "." }
        }
    }
    $allCandidates = $remerosDB | Where-Object {
        $_.nombre -notin $nombresAlineados -and
        ($_.posicion -match $posFilter -or $_.posicion -eq "Babor y Estribor")
    }

    # Filtrar solo candidatos que SUPERAN los criterios del puesto (no replicar el mismo problema)
    $candidates = $allCandidates | Where-Object {
        $c = $_
        $edadC = if ($c.PSObject.Properties['edad'] -and $c.edad) { [int]$c.edad } else { 50 }
        $pesoC = if ($c.PSObject.Properties['peso_kg'] -and $c.peso_kg -match '^\d') { [double]$c.peso_kg } else { 0 }
        $altC  = if ($c.PSObject.Properties['altura_cm'] -and $c.altura_cm -match '^\d') { [double]$c.altura_cm } else { 0 }
        $aniosC = 0
        $propA = $c.PSObject.Properties | Where-Object { $_.Name -match 'experiencia' -and ($_.Name -match 'a.os' -or $_.Name -match 'anios') } | Select-Object -First 1
        if ($propA -and ($propA.Value -as [double] -ge 0)) { $aniosC = [double]$propA.Value }
        $fakeInfo = [PSCustomObject]@{ Peso=$pesoC; Altura=$altC; Anios=$aniosC; Genero="Hombre" }
        Test-PositionFit $posZone $edadC $fakeInfo
    }

    if (-not $candidates) { return $null }

    $scored = $candidates | ForEach-Object {
        $c = $_
        $edadC  = if ($c.PSObject.Properties['edad']   -and $c.edad)   { [int]$c.edad }    else { 50 }
        $pesoC  = if ($c.PSObject.Properties['peso_kg'] -and $c.peso_kg -match '^\d') { [double]$c.peso_kg } else { 0 }
        $altC   = if ($c.PSObject.Properties['altura_cm'] -and $c.altura_cm -match '^\d') { [double]$c.altura_cm } else { 0 }
        $genC   = if ($c.PSObject.Properties['genero'] -and $c.genero) { $c.genero } else { "Hombre" }
        $expC   = if ($c.PSObject.Properties['experiencia'] -and $c.experiencia) { $c.experiencia } else { "" }
        $propA  = $c.PSObject.Properties | Where-Object { $_.Name -match 'experiencia' -and ($_.Name -match 'a.os' -or $_.Name -match 'anios') } | Select-Object -First 1
        $aniosC = if ($propA -and ($propA.Value -as [double] -ge 0)) { [double]$propA.Value } else { 0 }
        
        # Calcular impacto HCP del cambio
        $numP = 14
        $tInfo = Get-RowerFullInfo $titularName ""
        $baseMujeres = $script:numMujeres45
        
        # Calcular nuevas mujeres >= 45 en la alineacion simulada
        $newMujeres = $baseMujeres
        if ($titularAge -ge 45 -and $tInfo.Genero -match "Mujer") { $newMujeres-- }
        if ($edadC -ge 45 -and $genC -match "Mujer") { $newMujeres++ }

        $baseHcpV = Get-HcpFromTable $avgOficial $distanciaRegata $baseMujeres
        
        # Nueva edad media: (SumaOriginal - EdadTitular + EdadCandidato) / 14
        $sumaO = $avgOficial * $numP
        $nuevaSum = $sumaO - $titularAge + $edadC
        $nuevaEd = $nuevaSum / $numP
        $nuevoHcpV  = Get-HcpFromTable $nuevaEd $distanciaRegata $newMujeres
        
        $delta = $nuevoHcpV - $baseHcpV

        # === SISTEMA DE PUNTUACION v4.0 (Base Conocimiento Aizburua) ===

        # 1. DEPOSITO NEUROLOGICO (max ~50 pts)
        # Combina a&ntilde;os de experiencia con nivel cualitativo del JSON
        $scoreExp  = [math]::Min($aniosC, 15) * 2   # a&ntilde;os: max 30 pts
        $scoreExp += Get-ExpNivelPts $expC            # nivel: &Eacute;lite/Alta=20, Media-Alta=15, Media=10, Baja=5

        # 2. BIOTIPO DOCUMENTAL por zona (max ~25 pts)
        # Rangos extraidos de Posiciones1.md, Posiciones2.md, Posiciones3.md
        $scoreBio = 0
        if ($posZone -eq "PROA" -or $posZone -match "^Bancada [56]") {
            # Zona Proa: prima ligereza. Posiciones3.md: "m&aacute;s ligero ~70-72kg"
            if     ($pesoC -le 72)                    { $scoreBio += 20 }
            elseif ($pesoC -le 75)                    { $scoreBio += 12 }
            elseif ($pesoC -le 78)                    { $scoreBio +=  5 }
            else                                       { $scoreBio -= 10 }
            # B6/B7: bonus por agilidad morfol&oacute;gica (<= 75kg). 
            # Requisito v4.3: Peso <= 75kg para que el beneficio de fisonom&iacute;a no se pierda por lastre.
            if ($posZone -match "^Bancada 6|^PROA" -and $pesoC -le 75) { $scoreBio += 15 }
        }
        elseif ($posZone -match "^Bancada [34]") {
            # Motor: prima talla. Posiciones1.md: r=0.67 talla/vatios. ARC1 media: 1.83m
            if     ($altC -ge 190)                     { $scoreBio += 25 }
            elseif ($altC -ge 185)                     { $scoreBio += 20 }
            elseif ($altC -ge 180)                     { $scoreBio += 12 }
            elseif ($altC -ge 176)                     { $scoreBio +=  5 }
            else                                        { $scoreBio -=  8 }
            # Peso ideal Motor: 80-90kg. Posiciones3.md: "m&aacute;s altos, fuertes y pesados"
            if     ($pesoC -ge 80 -and $pesoC -le 90)  { $scoreBio += 10 }
            elseif ($pesoC -ge 75 -and $pesoC -lt 80)  { $scoreBio +=  5 }
            # Edad ideal Motor: 40-49 (mayor PAM). analisis_2.md: "Los Motores"
            if     ($edadC -ge 40 -and $edadC -le 49)  { $scoreBio +=  8 }
            elseif ($edadC -ge 50 -and $edadC -le 59)  { $scoreBio +=  3 }
            elseif ($edadC -gt 65)                      { $scoreBio -= 10 }
        }
        elseif ($posZone -match "^Bancada 2") {
            # Contramarca: m&aacute;s fuerte que B1. Posiciones3.md: "~78-82kg"
            if     ($pesoC -ge 78 -and $pesoC -le 82) { $scoreBio += 20 }
            elseif ($pesoC -ge 75 -and $pesoC -lt 78) { $scoreBio += 10 }
            elseif ($pesoC -gt 82 -and $pesoC -le 88) { $scoreBio +=  8 }
            else                                        { $scoreBio -=  5 }
        }
        elseif ($posZone -match "^Bancada 1") {
            # Popa/Marca: veteran&iacute;a y ritmo. Posiciones3.md: ">55a, 74-78kg, estatura media-alta"
            if     ($edadC -ge 60)                     { $scoreBio += 15 }
            elseif ($edadC -ge 55)                     { $scoreBio += 10 }
            elseif ($edadC -ge 45)                     { $scoreBio +=  5 }
            # Peso ideal Popa: 74-78kg (evitar apopamiento)
            if     ($pesoC -ge 74 -and $pesoC -le 78)  { $scoreBio +=  8 }
            elseif ($pesoC -ge 70 -and $pesoC -lt 74)  { $scoreBio +=  4 }
            elseif ($pesoC -gt 78 -and $pesoC -le 85)  { $scoreBio +=  2 }
            # Altura: media-alta para arco de palada de 110&deg;. Posiciones2.md
            if     ($altC -ge 180)                     { $scoreBio +=  8 }
            elseif ($altC -ge 175)                     { $scoreBio +=  5 }
            elseif ($altC -ge 170)                     { $scoreBio +=  2 }
        }

        # 3. EFICIENCIA HCP ABE (max ~25 pts)
        # Cada segundo ganado respecto al titular vale 2.5 pts
        $scoreHcp = $delta * 2.5

        # 4. EQUILIBRIO ESTRUCTURAL (v5.0)
        # Si hay un targetWeight, restamos puntos segun la desviacion (max -30 pts)
        $scoreBal = 0
        if ($targetWeight -gt 0) {
            $diff = [math]::Abs($pesoC - $targetWeight)
            $scoreBal = [math]::Max(-30, (15 - $diff) * 2) # Bonus si < 15kg diff, penaliza si > 15kg
        }

        $score = $scoreExp + $scoreBio + $scoreHcp + $scoreBal

        [PSCustomObject]@{ Rower=$c; Score=$score; HcpDelta=$delta; Edad=$edadC; Peso=$pesoC; Altura=$altC; Anios=$aniosC; Genero=$genC; Hcp=$hcpC; ExpNivel=$expC; ScoreExp=($scoreExp); ScoreBal=$scoreBal }
    }
    # Umbral minimo de Deposito Neurologico: si ningun candidato supera 15 pts de experiencia,
    # no se sugiere nadie (evitar sugerir perfiles que son un retroceso tactico respecto al titular)
    $validScored = $scored | Where-Object { $_.ScoreExp -ge 15 }
    if (-not $validScored) { return $null }
    return $validScored | Sort-Object Score -Descending | Select-Object -First 1
}

# Evalua si un puesto esta MAL cubierto segun la Matriz Tactica documentada (Base Conocimiento v4.0)
# Fuentes: Posiciones1.md (r=0.67 talla/vatios), Posiciones3.md (perfiles por bancada), analisis_2.md
function Test-PositionFit([string]$posZone, [int]$age, $info) {
    # PATRON: puesto &uacute;nico, no se evalua biomec&aacute;nicamente
    if ($posZone -eq "PATRON") { return $true }

    # PROA (B7): ligereza cr&iacute;tica. Fuente: Posiciones3.md - "m&aacute;s ligero ~70-72kg, evitar pitching"
    if ($posZone -eq "PROA") {
        if ($info.Peso -gt 75)  { return $false }  # Riesgo de Pitching (cabeceo longitudinal)
        if ($info.Anios -lt 2)  { return $false }  # Veteran&iacute;a t&eacute;cnica obligatoria en proa
        return $true
    }

    # BANCADA 6 (Estreles): zona de transici&oacute;n hacia proa, masa controlada
    # Fuente: Posiciones3.md - "ligeros y muy t&eacute;cnicos ~74-76kg"
    if ($posZone -match "^Bancada 6") {
        if ($info.Peso -gt 80) { return $false }   # Exceso lastre en zona de estrechamiento
        return $true
    }

    # BANCADA 5 (apoyo motor-proa): transici&oacute;n r&iacute;tmica, perfil h&iacute;brido
    if ($posZone -match "^Bancada 5") {
        if ($info.Peso -gt 82)  { return $false }
        return $true
    }

    # BANCADAS 3 y 4 (Motor Central): m&aacute;xima palanca vectorial y potencia absoluta
    # Fuente: Posiciones1.md - correlaci&oacute;n r=0.67 talla/vatios. Media club: 1.76m. Elite: 1.83m
    if ($posZone -match "^Bancada [34]") {
        if ($info.Altura -gt 0 -and $info.Altura -lt 176) { return $false }  # Debajo del biotipo est&aacute;ndar
        if ($info.Peso   -gt 0 -and $info.Peso   -lt 75)  { return $false }  # Masa insuficiente (manga m&aacute;xima: 1.72m)
        if ($age -gt 65)                                   { return $false }  # Declive de PAM critico
        return $true
    }

    # BANCADA 2 (Contramarca): soporte r&iacute;tmico y tracci&oacute;n reactiva
    # Fuente: Posiciones3.md - "m&aacute;s fuertes que los marcas, ~78-82kg"
    if ($posZone -match "^Bancada 2") {
        if ($info.Peso -lt 75) { return $false }  # Insuficiente para rol de tracci&oacute;n
        if ($info.Peso -gt 88) { return $false }  # Exceso que compromete el trimado
        return $true
    }

    # BANCADA 1 (Popa/Marca): estabilidad neurologica, arco de palada de 110&deg;
    # Fuente: Posiciones3.md - ">55 a&ntilde;os, peso medio 74-78kg, estatura media-alta"
    if ($posZone -match "^Bancada 1") {
        if ($age -lt 45)                                       { return $false }  # Sin veteran&iacute;a m&iacute;nima para marcar ritmo
        if ($info.Peso -gt 85)                                 { return $false }  # Riesgo de apopamiento (hundimiento de popa)
        if ($info.Altura -gt 0 -and $info.Altura -lt 170)     { return $false }  # Arco de palada comprometido (<110&deg;)
        return $true
    }

    return $true
}

function Add-RowerRow($posName, $side, $name, $age, $targetWeight = 0) {
    $info    = Get-RowerFullInfo $name $side
    $imgHtml = if ($info.ImgBase64) { "<img src='data:image/jpeg;base64,$($info.ImgBase64)' class='avatar'>" } else { "<div class='avatar' style='display:flex;align-items:center;justify-content:center;font-weight:900;color:#999'>?</div>" }
    $badge   = if ($side -eq "Babor") { "b-bab" } elseif ($side -eq "Estribor") { "b-est" } else { "badge" }
    $lit     = Get-OptLiterature $posName $age $name $side

    # Perfil completo
    $pesoText   = if ($info.Peso   -gt 0) { "<strong>$($info.Peso)</strong> kg" } else { "-" }
    $altText    = if ($info.Altura -gt 0) { "$($info.Altura) cm" } else { "-" }
    $genIcon    = if ($info.Genero -match "Mujer") { "&female;" } else { "&male;" }
    $expText    = if ($info.Anios  -ge 0) { "$($info.Anios)" } else { "-" }
    $expNivText = if ($info.ExpNivel) { $info.ExpNivel } else { "-" }
    $perfilHtml = "$age a. / $pesoText / $altText<br><small style='color:#64748b'>$genIcon &nbsp;Exp: $expNivText</small>"

    # Buscar alternativa cuando el puesto NO esta bien cubierto O hay desequilibrio critico (>15kg)
    $isFit  = Test-PositionFit $posName $age $info
    $imbalance = if ($targetWeight -gt 0) { [math]::Abs($info.Peso - $targetWeight) } else { 0 }
    
    $altHtml = ""
    if (-not $isFit -or $imbalance -gt 15) {
        $alt = Get-BestAlternative $posName $side $age $name $targetWeight
        if ($alt) {
            $apodo      = if ($alt.Rower.PSObject.Properties['apodo'] -and $alt.Rower.apodo) { $alt.Rower.apodo } else { $alt.Rower.nombre }
            $reajusteReason = if (-not $isFit) { "REAJUSTE POR BIOTIPO" } else { "EQUILIBRIO ESTRUCTURAL" }
            $script:seatsNeedingCascade += @{ 
                Zone = $posName; 
                Side = $side; 
                TitAge = $age; 
                TitName = $name; 
                AltName = $apodo;
                AltPeso = $alt.Peso;
                AltEdad = $alt.Edad;
                Reason = $reajusteReason
            }
            $genIconAlt = if ($alt.Genero -match "Mujer") { "&female;" } else { "&male;" }
            $expAltStr  = if ($alt.ExpNivel) { $alt.ExpNivel } else { "-" }

            # Calcular impacto HCP del cambio
            $numPersonas = 14
            $baseMujeres = $script:numMujeres45
            
            # Calcular nuevas mujeres >= 45 en la alineacion simulada
            $newMujeres = $baseMujeres
            if ($age -ge 45 -and $info.Genero -match "Mujer") { $newMujeres-- }
            if ($alt.Edad -ge 45 -and $alt.Genero -match "Mujer") { $newMujeres++ }

            $baseHcpVal = Get-HcpFromTable $avgOficial $distanciaRegata $baseMujeres
            
            # Nueva edad media: (SumaOriginal - EdadTitular + EdadCandidato) / 14
            $sumaOriginal = $avgOficial * $numPersonas
            $nuevaSuma = $sumaOriginal - $age + $alt.Edad
            $nuevaEdad = $nuevaSuma / $numPersonas
            $nuevoHcpVal  = Get-HcpFromTable $nuevaEdad $distanciaRegata $newMujeres
            
            $hcpDeltaTotal = $nuevoHcpVal - $baseHcpVal

            $hcpImpacto = if ($hcpDeltaTotal -gt 0) {
                "<span style='color:#15803d;font-size:12px'><strong>&#9650; HCP: +$($hcpDeltaTotal)s</strong> (ganancia para el bote)</span>"
            } elseif ($hcpDeltaTotal -lt 0) {
                "<span style='color:#b91c1c;font-size:12px'><strong>&#9660; HCP: -$(-$hcpDeltaTotal)s</strong> (p&eacute;rdida para el bote)</span>"
            } else {
                "<span style='color:#64748b;font-size:12px'>HCP: sin impacto</span>"
            }

            $altLines = @(
                "<div style='background:#fff7ed;border-left:3px solid #ea580c;padding:10px 12px;border-radius:6px;font-size:14px;line-height:1.6'>",
                "<strong style='font-size:15px;color:#9a3412'>$reajusteTitle</strong><br>",
                "<strong style='font-size:14px'>$($apodo.ToUpper())</strong><br>",
                "$($alt.Edad) a. / $($alt.Peso) kg / $($alt.Altura) cm &nbsp;$genIconAlt<br>",
                "Exp: $expAltStr &nbsp;| $($alt.Anios) a&ntilde;os<br>",
                "$hcpImpacto</div>"
            )
            $altHtml = $altLines -join ""
        }
    }

    return "<tr><td><strong>$posName</strong></td><td><span class='badge $badge'>$side</span></td><td><div class='rower-info'>$imgHtml <span class='r-name'>$($info.DisplayName)</span></div></td><td style='font-size:15px'>$perfilHtml</td><td style='text-align:center;font-weight:800'>$expText</td><td class='lit-text'>$lit</td><td>$altHtml</td></tr>"
}

$benchAlerts = @()
$h.Add((Add-RowerRow "PROA" "Babor" $ali.proa.nombre $ali.proa.edad))
foreach ($n in 6..1) {
    $b = $ali.bancadas."$n"
    $rB = Get-RowerFullInfo $b.B.nombre "Babor"
    $rE = Get-RowerFullInfo $b.E.nombre "Estribor"
    
    # Calcular desequilibrio lateral por bancada
    $difBancada = [math]::Abs($rB.Peso - $rE.Peso)
    if ($difBancada -gt 5) {
        $benchAlerts += "<strong>Bancada $n</strong>: Diferencial de <strong>$([math]::Round($difBancada, 1)) kg</strong> ($($rB.DisplayName) vs $($rE.DisplayName))."
    }

    $h.Add((Add-RowerRow "Bancada $n" "Babor" $b.B.nombre $b.B.edad $rE.Peso))
    $h.Add((Add-RowerRow "Bancada $n" "Estribor" $b.E.nombre $b.E.edad $rB.Peso))
}
$h.Add((Add-RowerRow "PATRON" "Centro" $ali.patron.nombre $ali.patron.edad))
$h.Add("</tbody></table></div>")

# --- AUDITOR&Iacute;A T&Eacute;CNICA AVANZADA (v3.2) ---
$h.Add("<div class='section-title'>2. Auditor&iacute;a de Optimizaci&oacute;n Biomec&aacute;nica</div>")

# Grilla Unificada de Auditor&iacute;a
$h.Add("<div class='foundation-grid'>")
  $proelInfo = Get-RowerFullInfo $ali.proa.nombre "Proa"
  $trimadoMsg = if ([math]::Abs($difPeso) -gt 20) { "<strong>Alerta Cr&iacute;tica:</strong> Severa asimetr&iacute;a lateral (" + [math]::Round($difPeso, 1) + " kg). El bote tender&aacute; a escorar y el gui&ntilde;ado penalizar&aacute; el avance recto." } elseif ([math]::Abs($difPeso) -gt 10) { "<strong>Advertencia:</strong> Desequilibrio lateral moderado (" + [math]::Round($difPeso, 1) + " kg). Requerir&aacute; compensaci&oacute;n biomec&aacute;nica cont&iacute;nua por parte del patr&oacute;n." } else { "<strong>Sinergia Estructural:</strong> Excelente distribuci&oacute;n de pesos (desviaci&oacute;n lateral de s&oacute;lo " + [math]::Abs([math]::Round($difPeso, 1)) + " kg), maximizando el deslizamiento libre del casco." }
  $proelMsg = if ($proelInfo.Peso -gt 75) { " Adem&aacute;s, la masa de $($proelInfo.DisplayName) ($($proelInfo.Peso)kg) en proa hundir&aacute; excesivamente el morro, incrementando el coeficiente de arrastre." } elseif ($proelInfo.Peso -lt 65) { " El peso pluma de $($proelInfo.DisplayName) ($($proelInfo.Peso)kg) garantiza una proa elevada, cortando la ola con m&iacute;nima fricci&oacute;n frontal." } else { " La masa del proel ($($proelInfo.Peso)kg) se encuentra en el punto dulce biomec&aacute;nico." }
$ainhoaInfo = Get-RowerFullInfo "Ainhoa" "Estribor"
$ainhoaMsg = ""
if ($ali.bancadas."6".E.nombre -match "Ainhoa") {
    $ainhoaMsg = " <br><br><strong>Acierto T&aacute;ctico:</strong> La elecci&oacute;n de <strong>$($ainhoaInfo.DisplayName)</strong> ($($ainhoaInfo.Peso)kg) en proa es clave: aligera el tren delantero y mitiga el impacto de un proel pesado."
}
$h.Add("<div class='foundation-card' style='border-left-color:#0ea5e9'><h3>Gesti&oacute;n del Trimado y Masas</h3><p>$trimadoMsg $proelMsg$ainhoaMsg</p></div>")

$h.Add("<div class='foundation-card' style='border-left-color:#e11d48'><h3>Alertas de Desequilibrio Local</h3>")
if ($benchAlerts.Count -gt 0) {
    $alertHtml = $benchAlerts | ForEach-Object { "<div style='background:#fff0f2; border-left:4px solid #e11d48; padding:14px 18px; border-radius:8px; font-size:15px; line-height:1.5'>$_</div>" }
    $h.Add("<div style='display:flex; flex-direction:column; gap:12px; margin-top:8px'>" + ($alertHtml -join "") + "</div>")
} else {
    $h.Add("<p>No se han detectado desequilibrios cr&iacute;ticos por bancada (umbral 5kg).</p>")
}
$h.Add("</div>")
  $b1B = Get-RowerFullInfo $ali.bancadas."1".B.nombre "Babor"
  $b1E = Get-RowerFullInfo $ali.bancadas."1".E.nombre "Estribor"
  $b1Age = ($b1B.Edad + $b1E.Edad) / 2
  $b1Txt = if ($b1Age -ge 55) { "Su acentuada veteran&iacute;a ($([math]::Round($b1Age,1)) a&ntilde;os de media) es cr&iacute;tica para mitigar el impacto del lactato y mantener el bloque unido en los metros finales." } elseif ($b1Age -ge 45) { "Su experiencia aporta el temple necesario para gobernar el ritmo sin perder la explosividad en la ciaboga." } else { "Su juventud y empuje inyectan una alta frecuencia r&iacute;tmica, ideal para estrategias de ataque agresivo desde la salida." }
  $h.Add("<div class='foundation-card full-width' style='border-left-color:#145a32'><h3>Estabilidad en Popa (B1)</h3><p><strong>An&aacute;lisis T&aacute;ctico:</strong> La combinaci&oacute;n de $($b1B.DisplayName) y $($b1E.DisplayName) en la marca establece el pulso del bote. $b1Txt</p></div>")
  $motorMsg = if ($avgTallaMotor -lt 180) { "La talla media del motor ($([math]::Round($avgTallaMotor,1))cm) exige una frecuencia de boga m&aacute;s alta para compensar la menor longitud de palanca." } elseif ($avgTallaMotor -gt 183) { "Excepcional envergadura media ($([math]::Round($avgTallaMotor,1))cm), permitiendo paladas largas y un avance muy eficiente con bajo gasto energ&eacute;tico." } else { "Talla media s&oacute;lida ($([math]::Round($avgTallaMotor,1))cm), garantizando un buen compromiso entre torque hidrodin&aacute;mico y agilidad de recobro." }
  $b3B = Get-RowerFullInfo $ali.bancadas."3".B.nombre "Babor"
  $b3E = Get-RowerFullInfo $ali.bancadas."3".E.nombre "Estribor"
  $pesoB3 = $b3B.Peso + $b3E.Peso
  $b3Msg = ""
  if ($pesoB3 -gt 185) {
      $b3Msg = "<br><br><strong style='color:var(--r)'>ALERTA INERCIAL B3:</strong> Carga extrema de <strong>$pesoB3 kg</strong> ($($b3B.DisplayName) + $($b3E.DisplayName)). Genera un efecto 'volante de inercia' magn&iacute;fico en recta, pero exige un enorme trabajo a las bancadas extremas en giros."
  } elseif ($pesoB3 -gt 175) {
      $b3Msg = "<br><br><strong style='color:var(--r)'>AVISO ESTRUCTURAL B3:</strong> Bloque pesado de <strong>$pesoB3 kg</strong>. Estabiliza el casco con oleaje frontal, aunque puede ralentizar la salida tras las balizas."
  }
  $h.Add("<div class='foundation-card' style='border-left-color:#f59e0b'><h3>An&aacute;lisis del Bloque Motor (B3-B5)</h3><p><strong>Rendimiento Esperado:</strong> $motorMsg $b3Msg</p></div>")
  
  $potenciaMsg = if ($avgOficial -gt 55) { "Se requiere gestionar los picos de &aacute;cido l&aacute;ctico para sostener el h&aacute;ndicap t&aacute;ctico de $([math]::Round($avgOficial, 1)) a&ntilde;os." } else { "Se sugiere aprovechar el perfil metab&oacute;lico para atacar con series explosivas (PAM) dado el h&aacute;ndicap oficial de $([math]::Round($avgOficial, 1)) a&ntilde;os." }
  $h.Add("<div class='foundation-card' style='border-left-color:#6c5ce7'><h3>Diagn&oacute;stico de Potencia</h3><p>Con un tonelaje total de <strong>$totalPeso kg</strong>, la relaci&oacute;n de vatios/kg proyectada es de alto rendimiento. $potenciaMsg</p></div>")

$h.Add("</div>")

# --- MOTOR DE OPTIMIZACI&Oacute;N: EL MOVIMIENTO MAESTRO Y PLAN DE PLANTILLA ---
$h.Add("<div class='opt-box'>")
$h.Add("<h3 style='color:var(--r); margin-top:0; text-transform:uppercase; font-size:18px'>Dictamen de Reajuste: El Movimiento Maestro</h3>")

$jovenesPopaProa = @()
$veteranosMotor = @()
$rosterSugerencias = @()

# Escaneo de alineaci&oacute;n actual
foreach ($n in @(1, 2, 5, 6)) {
    $b = $ali.bancadas."$n"
    foreach ($side in "B", "E") {
        $rower = $b.$side
        if ($rower.edad -le 50 -and $rower.edad -gt 0) { 
            $sideName = if ($side -eq "B") { "Babor" } else { "Estribor" }
            $info = Get-RowerFullInfo $rower.nombre $sideName
            $jovenesPopaProa += @{ Nombre = $rower.nombre; Edad = $rower.edad; Bancada = $n; Lado = $sideName; Peso = $info.Peso } 
        }
    }
}
foreach ($n in @(3, 4)) {
    $b = $ali.bancadas."$n"
    foreach ($side in "B", "E") {
        $rower = $b.$side
        if ($rower.edad -ge 55) { 
            $sideName = if ($side -eq "B") { "Babor" } else { "Estribor" }
            $info = Get-RowerFullInfo $rower.nombre $sideName
            $veteranosMotor += @{ Nombre = $rower.nombre; Edad = $rower.edad; Bancada = $n; Lado = $sideName; Peso = $info.Peso } 
        }
    }
}

# Buscar sustitutos ideales en Roster (usa $nombresAlineados ya construido arriba)
if ($ali.proa.edad -gt 60 -or $proelInfo.Peso -gt 80) {
    $sustitutoProa = $remerosDB | Where-Object { $nombresAlineados -notcontains $_.nombre -and $_.posicion -match "Babor" -and $_.peso_kg -lt 75 -and $_.edad -lt 55 } | Select-Object -First 1
    if ($sustitutoProa) {
        $rosterSugerencias += "<strong>PARA PROA:</strong> Incorporar a <strong>$($sustitutoProa.nombre)</strong> ($($sustitutoProa.peso_kg)kg, $($sustitutoProa.edad)a) para corregir el exceso de peso y mejorar la reactividad."
    }
}

# Producir Informe de Cambios (EL MOVIMIENTO MAESTRO)
$movimientosRealizados = 0

# 1. Prioridad: Corregir fallos de Biotipo o Equilibrio Lateral detectados en el escaneo
if ($script:seatsNeedingCascade.Count -gt 0) {
    foreach ($seat in $script:seatsNeedingCascade) {
        $color = if ($seat.Reason -eq "EQUILIBRIO ESTRUCTURAL") { "#ea580c" } else { "var(--r)" }
        $h.Add("<p style='font-size:16px; margin-bottom:15px'><strong>MOVIMIENTO DE CORRECCI&Oacute;N ($($seat.Reason)):</strong> Sustituir a <strong>$($seat.TitName) ($($seat.TitAge)a)</strong> por <strong>$($seat.AltName) ($($seat.AltPeso)kg, $($seat.AltEdad)a)</strong>.</p>")
        $h.Add("<div style='display:grid; grid-template-columns: 1fr 1fr; gap:15px; margin-bottom:25px'>")
        $h.Add("<div style='background:white; padding:15px; border-radius:8px; border-left:4px solid $color; flex:1'><strong>Impacto en $($seat.Zone):</strong> La incorporaci&oacute;n de $($seat.AltName) resuelve el d&eacute;ficit de $($seat.Reason.ToLower()).</div>")
        $h.Add("<div style='background:white; padding:15px; border-radius:8px; border-left:4px solid #1e293b; flex:1'><strong>Justificaci&oacute;n T&aacute;ctica:</strong> Se prioriza la estabilidad del bloque $($seat.Zone) ($($seat.Side)) para garantizar un trimado hidrodin&aacute;mico superior.</div>")
        $h.Add("</div>")
        $movimientosRealizados++
    }
}

# 2. Secundario: Optimización por torque (Jóvenes vs Veteranos)
if ($jovenesPopaProa.Count -gt 0 -and $veteranosMotor.Count -gt 0) {
    $h.Add("<h3 style='color:#1e293b; margin-top:30px; text-transform:uppercase; font-size:16px; border-top:1px solid #fee2e2; padding-top:20px'>Optimizaci&oacute;n de Torque (Intercambios Internos)</h3>")
    foreach ($joven in $jovenesPopaProa) {
        # Evitar duplicar si el joven ya fue sugerido para cambio desde el banquillo
        $yaSustituido = $script:seatsNeedingCascade | Where-Object { $_.TitName -eq $joven.Nombre }
        if ($yaSustituido) { continue }
        
        $vetNombres = ($veteranosMotor | ForEach-Object { "$($_.Nombre) ($($_.Edad)a)" }) -join " o "
        $h.Add("<p style='font-size:16px; margin-bottom:15px'><strong>PROPUESTA INTERNA:</strong> Intercambiar a <strong>$($joven.Nombre) ($($joven.Peso)kg)</strong> con <strong>$vetNombres</strong>.</p>")
        $h.Add("<div style='display:grid; grid-template-columns: 1fr 1fr; gap:15px; margin-bottom:25px'>")
        $h.Add("<div style='background:white; padding:15px; border-radius:8px; border-left:4px solid var(--r); flex:1'><strong>Rol de $($joven.Nombre):</strong> Aportar&aacute; sus $($joven.Peso)kg de masa activa en el bloque motor. Justificaci&oacute;n: Mayor torque y aprovechamiento de fuerza explosiva.</div>")
        $h.Add("<div style='background:white; padding:15px; border-radius:8px; border-left:4px solid #1e293b; flex:1'><strong>Rol de ${vetNombres}:</strong> Asegurar el ritmo estable en Bancada $($joven.Bancada). Justificaci&oacute;n: Su veteran&iacute;a compensa el lactato en puntas.</div>")
        $h.Add("</div>")
    }
}

if ($rosterSugerencias.Count -gt 0) {
    $h.Add("<h3 style='color:#1e293b; margin-top:30px; text-transform:uppercase; font-size:16px; border-top:1px solid #fee2e2; padding-top:20px'>Potencial de Mejora desde Plantilla (Fichajes Internos)</h3>")
    foreach ($sug in $rosterSugerencias) {
        $h.Add("<p style='background:#f1f5f9; padding:15px; border-radius:8px; border-left:4px solid #64748b'>$sug</p>")
    }
}

if ($jovenesPopaProa.Count -eq 0 -and $rosterSugerencias.Count -eq 0) {
    $h.Add("<p style='font-size:17px; line-height:1.7; color:#1e293b'>La alineaci&oacute;n actual es biomec&aacute;nicamente coherente. Los pesos extremos est&aacute;n justificados por su posici&oacute;n central.</p>")
}
$h.Add("</div>")

# --- ANÁLISIS DE CONTINGENCIA (PLANES B EN CASCADA) ---
$h.Add("<div class='section-title'>2.B. Auditor&iacute;a del Banquillo: Planes de Contingencia (Top 3)</div>")
$h.Add("<div class='foundation-grid'>")

function Get-CascadeHtmlBlock($zoneTitle, $posZone, $side, $titularAge, $titularName) {
    $posFilter = if ($posZone -eq "PROA") { "Proa|Babor|Estribor" } elseif ($posZone -eq "PATRON") { "Patron" } else { $side }
    $allC = $remerosDB | Where-Object { $_.nombre -notin $nombresAlineados -and ($_.posicion -match $posFilter -or $_.posicion -eq "Babor y Estribor") }
    $scored = $allC | ForEach-Object {
        $c = $_
        $edadC = if ($c.PSObject.Properties['edad'] -and $c.edad) { [int]$c.edad } else { 50 }
        $pesoC = if ($c.PSObject.Properties['peso_kg'] -and $c.peso_kg -match '^\d') { [double]$c.peso_kg } else { 0 }
        $altC  = if ($c.PSObject.Properties['altura_cm'] -and $c.altura_cm -match '^\d') { [double]$c.altura_cm } else { 0 }
        $genC  = if ($c.PSObject.Properties['genero'] -and $c.genero) { $c.genero } else { "Hombre" }
        $expC  = if ($c.PSObject.Properties['experiencia'] -and $c.experiencia) { $c.experiencia } else { "" }
        $propA = $c.PSObject.Properties | Where-Object { $_.Name -match 'experiencia' -and ($_.Name -match 'a.os' -or $_.Name -match 'anios') } | Select-Object -First 1
        $aniosC= if ($propA -and ($propA.Value -as [double] -ge 0)) { [double]$propA.Value } else { 0 }
        
        # --- CÁLCULO HCP ---
        $numP = 14
        $tInfo = Get-RowerFullInfo $titularName ""
        $baseMujeres = $script:numMujeres45
        
        # Calcular nuevas mujeres >= 45 en la alineacion simulada
        $newMujeres = $baseMujeres
        if ($titularAge -ge 45 -and $tInfo.Genero -match "Mujer") { $newMujeres-- }
        if ($edadC -ge 45 -and $genC -match "Mujer") { $newMujeres++ }

        $baseHcpV = Get-HcpFromTable $avgOficial $distanciaRegata $baseMujeres
        
        $nuevaSum = ($avgOficial * $numP) - $titularAge + $edadC
        $nuevaEd = $nuevaSum / $numP
        $nuevoHcpV = Get-HcpFromTable $nuevaEd $distanciaRegata $newMujeres
        
        $delta = $nuevoHcpV - $baseHcpV
        $sHcp = $delta * 2.5
        
        # --- SCORE EXP ---
        $sExp = [math]::Min($aniosC, 15) * 2 + (Get-ExpNivelPts $expC)
        
        # --- SCORE BIO ---
        $sBio = 0; $bioReason = ""
        if ($posZone -eq "PROA") {
            if ($pesoC -le 72) { $sBio+=20; $bioReason="Peso pluma ideal, previene totalmente el pitching (+20 pts)." }
            elseif ($pesoC -le 75) { $sBio+=10; $bioReason="Peso l&iacute;mite aceptable para el trimado frontal (+10 pts)." }
            else { $sBio-=10; $bioReason="Lastre excesivo en proa, riesgo severo de hundimiento (-10 pts)." }
        } elseif ($posZone -match "^Bancada 6") {
            if ($pesoC -le 76) { $sBio+=15; $bioReason="Masa id&oacute;nea para zona de estrechamiento (+15 pts)." }
            elseif ($pesoC -le 80) { $sBio+=5; $bioReason="Peso ajustado al l&iacute;mite de la bancada (+5 pts)." }
            else { $sBio-=8; $bioReason="Exceso de peso para bancada tan avanzada (-8 pts)." }
        } elseif ($posZone -match "^Bancada 5") {
            if ($pesoC -le 82) { $sBio+=15; $bioReason="Masa correcta para transici&oacute;n r&iacute;tmica (+15 pts)." }
            else { $sBio-=5; $bioReason="Lastre no recomendado para apoyo de motor (-5 pts)." }
        } elseif ($posZone -match "^Bancada [34]") {
            if ($altC -ge 190) { $sBio+=25; $bioReason="Envergadura de &eacute;lite para el Motor (+25 pts)." }
            elseif ($altC -ge 185) { $sBio+=20; $bioReason="Excelente palanca para bloque motor (+20 pts)." }
            elseif ($altC -ge 180) { $sBio+=12; $bioReason="Estatura m&iacute;nima ideal superada (+12 pts)." }
            elseif ($altC -ge 176) { $sBio+=5;  $bioReason="Talla ajustada pero v&aacute;lida (+5 pts)." }
            else { $sBio-=8; $bioReason="Falta de palanca severa para el bloque central (-8 pts)." }
            
            if ($pesoC -ge 80 -and $pesoC -le 90) { $sBio+=10; $bioReason+=" Peso ideal para tracci&oacute;n masiva (+10 pts)." }
            elseif ($pesoC -lt 75) { $sBio-=10; $bioReason+=" Falta de masa cr&iacute;tica para tracci&oacute;n (-10 pts)." }
        } elseif ($posZone -match "^Bancada 2") {
            if ($pesoC -ge 78 -and $pesoC -le 82) { $sBio+=20; $bioReason="Ajuste de peso perfecto para Contramarca (+20 pts)." }
            elseif ($pesoC -ge 75 -and $pesoC -lt 78) { $sBio+=10; $bioReason="Peso aceptable, aporta tracci&oacute;n sin hundir popa (+10 pts)." }
            elseif ($pesoC -gt 82 -and $pesoC -le 88) { $sBio+=8; $bioReason="Algo pesado, pero aporta fuerza bruta (+8 pts)." }
            else { $sBio-=5; $bioReason="Desajuste de peso cr&iacute;tico para esta bancada (-5 pts)." }
        } elseif ($posZone -match "^Bancada 1|POPA") {
            if ($pesoC -ge 75 -and $pesoC -le 80) { $sBio+=20; $bioReason="Peso perfecto para asentar popa sin frenar (+20 pts)." }
            elseif ($pesoC -gt 80 -and $pesoC -le 85) { $sBio+=10; $bioReason="Marca pesado, v&aacute;lido si aporta gran PAM (+10 pts)." }
            elseif ($pesoC -lt 75) { $sBio-=5; $bioReason="Popa demasiado ligera, falta de asiento de guiada (-5 pts)." }
            else { $sBio-=10; $bioReason="Exceso de peso severo, riesgo de apopamiento (-10 pts)." }
        } else {
            $sBio+=5; $bioReason="Biometr&iacute;a est&aacute;ndar aprobada (+5 pts)."
        }
        
        if ($posZone -match "^Bancada 6|^PROA" -and $pesoC -le 75) {
            $sBio += 15
            $bioReason += " Bonus Agilidad Morfol&oacute;gica (+15 pts)."
        }
        
        $tot = $sExp + $sBio + $sHcp
        [PSCustomObject]@{ Nombre=$c.nombre; Tot=$tot; SExp=$sExp; SBio=$sBio; SHcp=$sHcp; Delta=$delta; Reason=$bioReason; Edad=$edadC; Peso=$pesoC; Alt=$altC; Exp=$expC }
    } | Where-Object { $_.SExp -ge 15 } | Sort-Object Tot -Descending | Select-Object -First 3

    $html = "<div class='foundation-card full-width' style='border-left-color:#6366f1; background:#f8fafc'><h3>Cascada de Reservas: $zoneTitle ($side) <span style='font-size:14px; font-weight:normal; color:#64748b'>[Sustituyendo a $titularName]</span></h3>"
    $html += "<p style='color:#475569; font-size:15px; margin-top:-5px; margin-bottom:15px'><em>Evaluando alternativas viables en banquillo contra el perfil te&oacute;rico ideal de la <strong>$posZone</strong>, incluyendo el impacto de H&aacute;ndicap (HCP). Solo se muestran remeros que superan el filtro de seguridad por Dep&oacute;sito Neurol&oacute;gico (&gt;15 pts).</em></p>"
    $medals = @("&#129351;", "&#129352;", "&#129353;")
    for ($idx = 0; $idx -lt 3; $idx++) {
        $medal = $medals[$idx]
        $colorBorder = if ($idx -eq 0) { '#eab308' } elseif ($idx -eq 1) { '#94a3b8' } else { '#d97706' }
        $html += "<div style='background:white; border:1px solid #cbd5e1; border-left:4px solid $colorBorder; padding:12px 15px; margin-bottom:10px; border-radius:6px;'>"
        
        if ($idx -lt $scored.Count) {
            $s = $scored[$idx]
            $html += "<strong style='font-size:16px; color:#1e293b'>$medal $($s.Nombre.ToUpper())</strong> <span style='color:#64748b; font-size:14px'>($($s.Edad)a / $($s.Peso)kg / $($s.Alt)cm)</span> &nbsp;&mdash;&nbsp; <strong style='color:#0f172a'>Score Total: $($s.Tot) pts</strong><br>"
            $html += "<span style='font-size:14px; color:#334155; display:block; margin-top:5px'><strong>Dep&oacute;sito Neurol&oacute;gico:</strong> $($s.SExp) pts ($($s.Exp)). <strong>Impacto HCP:</strong> $($s.SHcp) pts ($($s.Delta)s). <strong>Justificaci&oacute;n Biomec&aacute;nica:</strong> $($s.Reason)</span>"
        } else {
            $html += "<strong style='font-size:16px; color:#94a3b8'>$medal BANQUILLO VAC&Iacute;O</strong><br>"
            $html += "<span style='font-size:14px; color:#64748b; display:block; margin-top:5px'><em>No hay m&aacute;s reservas disponibles que superen el corte t&eacute;cnico de seguridad (&gt;15 pts).</em></span>"
        }
        $html += "</div>"
    }
    $html += "</div>"
    return $html
}

if ($script:seatsNeedingCascade.Count -gt 0) {
    foreach ($seat in $script:seatsNeedingCascade) {
        $zTitle = "Relevos para $($seat.Zone)"
        $h.Add((Get-CascadeHtmlBlock $zTitle $seat.Zone $seat.Side $seat.TitAge $seat.TitName))
    }
} else {
    $h.Add("<p style='font-size:16px; color:#1e293b; padding:15px; background:#f8fafc; border-left:4px solid #10b981; border-radius:6px'><strong>Validaci&oacute;n Biomec&aacute;nica:</strong> Ning&uacute;n remero titular presenta un fallo cr&iacute;tico de biotipo que justifique abrir un plan de contingencia contra el banquillo disponible.</p>")
}
$h.Add("</div>")

# BENCHMARK Y DICTAMEN
$h.Add("<div class='section-title'>3. Comparativa de Competidores y Proyecci&oacute;n de Temporada</div><div style='background:white; border-radius:15px; padding:40px; box-shadow: 0 10px 30px rgba(0,0,0,0.15); font-size:19px; line-height:1.7'><p>Comparativa Tiempos Finales en el Grupo:</p><div class='benchmark-grid'>")
$grupoAiz = $regata.grupos.$($aiz.grupo)
$topResultados = $grupoAiz.resultados | Sort-Object puesto | Select-Object -First 5
$aizResult = $grupoAiz.resultados | Where-Object { $_.club -match "AIZBURUA" }
$mostrarAiz = $false
foreach ($res in $topResultados) {
    if ($res.club -match "AIZBURUA") { $mostrarAiz = $true }
    $clase = if ($res.puesto -eq 1) { "bench-card winner" } else { "bench-card" }
    $textoExtra = if ($res.puesto -eq 1) { " (Ganador)" } else { "" }
    $h.Add("<div class='$clase'><strong>$($res.club):</strong> $($res.tiempo_final)$textoExtra</div>")
}
if (-not $mostrarAiz -and $aizResult) {
    $h.Add("<div class='bench-card' style='border-left-color: var(--r)'><strong>AIZBURUA:</strong> $($aizResult.tiempo_final) (Puesto $($aizResult.puesto))</div>")
}
$h.Add("</div><div style='margin-top:40px; border-top:3px solid #f1f5f9; padding-top:30px; background: #fef2f2; padding: 25px; border-radius: 12px; border-left: 8px solid var(--r)'><strong style='font-size:22px; color:var(--r)'>Dictamen Final de Direcci&oacute;n T&eacute;cnica:</strong><br><br>Con una tripulaci&oacute;n de <strong>$totalPeso kg</strong>, la clave es la eficiencia hidrodin&aacute;mica. Debemos aprovechar la veteran&iacute;a para mantener el rumbo en condiciones de viento cruzado, compensando el desequilibrio de <strong>$([math]::Round($difPeso, 1)) kg</strong> mediante una sincron&iacute;a perfecta en la entrada de la pala.</div></div>")

$h.Add("</div>") # Fin main
$h.Add("<div class='footer'>")
if ($logo2Base64) {
    $h.Add("<img src='data:image/jpeg;base64,$logo2Base64' class='logo-footer' alt='Branding Aizburua'>")
}
$h.Add("<p>CLUB AIZBURUA &mdash; SISTEMA DE AN&Aacute;LISIS ESTRAT&Eacute;GICO</p></div></body></html>")

$content = $h -join "`n"
$utf8WithBom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($htmlFile, $content, $utf8WithBom)
Write-Host "Informe de Evolucion generado: $htmlFile"
Invoke-Item $htmlFile



