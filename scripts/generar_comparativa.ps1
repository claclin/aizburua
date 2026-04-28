param(
    [string]$RegataName = "Getxo"
)

$root = "c:\Proyectos\Aizburua"
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
$meteoReal = $evolucion | Where-Object { $_.hora -eq $horaBoga }
if (-not $meteoReal) { $meteoReal = $meteoGeneral }

# --- Lógica de Fotos y Nombres ---
function Get-RowerFullInfo([string]$name, [string]$posicion) {
    $displayName = $name
    $cleanName = $name.Replace(".", "").Trim()
    if ($cleanName -ieq "Gorka") { $displayName = "GizonTxiki" }
    elseif ($cleanName -ieq "JAntonio" -or $cleanName -ieq "JANTONIO" -or $cleanName -ieq "J.ANTONIO") { $displayName = "Potxe" }
    elseif ($cleanName -ieq "FJavier") { $displayName = "Jabier" }
    elseif ($cleanName -ieq "Fernando") { $displayName = "Fer" }
    elseif ($cleanName -ieq "Iñaki" -or $cleanName -ieq "I&ntilde;aki") { $displayName = "I&ntilde;aki" }
    if ($cleanName -ieq "Maite") {
        if ($posicion -eq "Babor") { $displayName = "Maite Zarra" }
        else { $displayName = "Maite" }
    }
    
    # Buscar en DB para métricas con lógica flexible
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

# Contribucion estimada al HCP del bote por remero (solo >=45 anios computan)
# NOTA: tabla oficial ABE pendiente de confirmar - valores son estimaciones
function Get-HcpSeconds([int]$edad, [string]$genero) {
    if ($edad -lt 45) { return 0 }  # <45 anios: sin aportacion al HCP del bote
    $base = 0
    if     ($edad -ge 70) { $base = 18 }
    elseif ($edad -ge 65) { $base = 14 }
    elseif ($edad -ge 60) { $base = 10 }
    elseif ($edad -ge 55) { $base = 7  }
    elseif ($edad -ge 50) { $base = 4  }
    elseif ($edad -ge 45) { $base = 2  }
    $mujerBonus = if ($genero -match "Mujer") { 5 } else { 0 }  # +5s extra por ser mujer (>=45)
    return $base + $mujerBonus
}

# Convierte nivel cualitativo de experiencia a puntos (Deposito Neurologico - v4.0)
# Valores extraidos de plantilla_remeros.json: Alta, Media - Alta, Media, Baja, Nuevo
function Get-ExpNivelPts([string]$nivel) {
    if ($nivel -match "Elite|Élite")                        { return 20 }
    if ($nivel -match "Alta" -and $nivel -notmatch "Media") { return 20 }  # "Alta" puro
    if ($nivel -match "Media.*Alta|Alta.*Media")            { return 15 }  # "Media - Alta"
    if ($nivel -match "Media")                              { return 10 }  # "Media" puro
    if ($nivel -match "Baja")                               { return 5  }
    return 0  # "Nuevo" o sin dato
}

# --- BANCO DE CONOCIMIENTO DINÁMICO (v3.0) ---
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
$edades = @()
$pesosBabor = @() ; $pesosEstribor = @() ; $pesosTotal = @()
$tallasMotor = @() ; $tallasExtremos = @()

function Process-Rower($n, $pos, $side) {
    $info = Get-RowerFullInfo $n $pos
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

if ($ali.proa.edad) { $edades += $ali.proa.edad }
Process-Rower $ali.proa.nombre "Proa" "Proa"

if ($ali.patron.edad) { $edades += $ali.patron.edad }
Process-Rower $ali.patron.nombre "Patron" "Patron"

foreach ($n in 1..6) {
    if ($ali.bancadas."$n".B.edad) { $edades += $ali.bancadas."$n".B.edad }
    Process-Rower $ali.bancadas."$n".B.nombre "Bancada $n" "Babor"
    
    if ($ali.bancadas."$n".E.edad) { $edades += $ali.bancadas."$n".E.edad }
    Process-Rower $ali.bancadas."$n".E.nombre "Bancada $n" "Estribor"
}
$avgEdad = ($edades | Measure-Object -Average).Average
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
    .main { padding: 40px; width: 95%; max-width: 1700px; margin: 0 auto; }
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
    .footer { background: #0f172a; color: white; padding: 80px; text-align: center; margin-top: 100px; border-top: 15px solid var(--r); }
</style></head><body>")

# HEADER
$logo1Html = if ($logo1Base64) { "<img src='data:image/jpeg;base64,$logo1Base64' class='logo-header' alt='Aizburua'>" } else { "<div style='width:70px;height:70px;background:var(--r);border-radius:10px;display:flex;align-items:center;justify-content:center;font-weight:900;font-size:30px'>A</div>" }
$h.Add("<div class='header'><div class='header-logo'>$logo1Html <div class='header-title'><h1>Estudio de Evoluci&oacute;n</h1><p>CLUB AIZBURUA &mdash; TEMPORADA 2026</p></div></div><div style='text-align:right'><strong style='font-size:18px'>" + $regata.fecha + "</strong></div></div>")

$h.Add("<div class='main'>")

# METRICAS
$h.Add("<div class='metric-row'><div class='metric-card'><div class='m-label'>Regatas Analizadas</div><div class='m-value'>1</div></div><div class='metric-card'><div class='m-label'>Media MPP L1 Mar</div><div class='m-value'>8.14 m</div></div><div class='metric-card'><div class='m-label'>Velocidad Media L1</div><div class='m-value'>4.41 m/s</div></div><div class='metric-card'><div class='m-label'>Edad Media Aizburua</div><div class='m-value'>" + [math]::Round($avgEdad, 2) + "</div></div></div>")

# COMPARATIVA CLIMATOLOGICA
$h.Add("<div class='section-title' style='margin-top:0'>Evoluci&oacute;n del Campo de Regateo (An&aacute;lisis de Tandas)</div>")
$h.Add("<div class='clima-grid'>")
$prev = $evolucion | Where-Object { $_.hora -eq "10:30" }
$h.Add("<div class='clima-item'><h4>Tandas Anteriores (10:30h)</h4><p>Viento: <strong>$($prev.viento_kmh) km/h</strong><br>Ola: <strong>$($prev.ola_m)m</strong><br>Corriente: <strong>$($prev.corriente)</strong><br><br><span style='color:#15803d'>&bull; Escenario m&aacute;s favorable. Menor resistencia hidrodin&aacute;mica en el largo de vuelta.</span></p></div>")
$h.Add("<div class='clima-item active'><h4>Boga Aizburua ($($horaBoga)h)</h4><p>Viento: <strong>$($meteoReal.viento_kmh) km/h</strong><br>Ola: <strong>$($meteoReal.ola_m)m</strong><br>Corriente: <strong>$($meteoReal.corriente)</strong><br><br><span style='color:#0369a1'>&bull; Ventana de transici&oacute;n. Aizburua rem&oacute; con el inicio de la <strong>vaciante m&aacute;xima</strong>.</span></p></div>")
$post = $evolucion | Where-Object { $_.hora -eq "11:30" }
$h.Add("<div class='clima-item'><h4>Tandas Posteriores (11:30h)</h4><p>Viento: <strong>$($post.viento_kmh) km/h</strong><br>Ola: <strong>$($post.ola_m)m</strong><br>Corriente: <strong>$($post.corriente)</strong><br><br><span style='color:#b91c1c'>&bull; Escenario cr&iacute;tico. El empeoramiento progresivo penaliz&oacute; los tiempos finales.</span></p></div>")
$h.Add("</div>")

# LEYENDA
$h.Add("<div class='section-title'>Leyenda de Conceptos T&eacute;cnicos</div><div class='legend-box'><div class='legend-item'><b>PAM (Potencia Aer&oacute;bica M&aacute;xima)</b><p>Es la fuerza real de los remeros. Cuanto m&aacute;s PAM, m&aacute;s r&aacute;pido se mueve el bote en el agua.</p></div><div class='legend-item'><b>S7 (Sumatorio 7 Pliegues)</b><p>Medici&oacute;n de grasa corporal. Un S7 bajo indica mayor masa muscular libre de grasa, lo que es el mejor predictor de potencia en veteranos.</p></div><div class='legend-item'><b>Power Naps (Siestas T&eacute;cnicas)</b><p>Descansos de 20 min antes del embarque que resetean el sistema nervioso y pueden elevar el rendimiento en un 15%.</p></div><div class='legend-item'><b>MPP (Metros Por Palada)</b><p>Indica cu&aacute;nto avanza el bote cada vez que remamos. Es la eficiencia t&eacute;cnica.</p></div></div>")

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

function Get-OptLiterature($pos, $age, $name, $side) {
    $info = Get-RowerFullInfo $name $side
    $displayName = $info.DisplayName
    
    if ($pos -eq "PATRON") {
        return "<strong>Director de Orquesta:</strong> Liderazgo y estrategia.<br><strong>Elecci&oacute;n:</strong> $displayName marca el rumbo y gestiona las Power Naps.<br><strong>Impacto:</strong> Base del h&aacute;ndicap del bote."
    }

    $titulo = if ($pos -match "1|2|POPA") { "Popa / Marca" } elseif ($pos -match "3|4") { "Motor Central" } elseif ($pos -match "5|6|PROA") { "Proa / Apoyo" } else { "Posici&oacute;n" }
    if ($pos -match "1|2|POPA") {
        if ($age -ge 55) {
            $sub = "Perfil de veteran&iacute;a estructurada ($age a&ntilde;os)."
            $eleccion = "$displayName asegura la sincron&iacute;a del marcador con sus $($info.Anios) a&ntilde;os de experiencia."
            $impacto = "Estabiliza el ritmo final seg&uacute;n la 'Psicolog&iacute;a Master', compensando el lactato con memoria muscular."
        } elseif ($info.Peso -ge 82) {
            $sub = "Potencia joven de alta inercia ($($info.Peso)kg)."
            $eleccion = "$displayName inyecta vatios pesados cerca del eje del patr&oacute;n para vencer la resistencia inicial."
            $impacto = "PAM de alto rango ($age a&ntilde;os), pero su palanca de $($info.Altura)cm ser&iacute;a un 12% m&aacute;s eficiente en el centro."
        } else {
            $sub = "Agilidad t&eacute;cnica y ligereza ($($info.Peso)kg)."
            $eleccion = "$displayName facilita una boga fluida y r&aacute;pida, evitando el arrastre de popa."
            $impacto = "Mantiene el bote din&aacute;mico en la zona de ritmo, ideal para condiciones de corriente variable."
        }
        return "<div style='line-height:1.6'><strong>${titulo}:</strong> $sub<br><strong>Elecci&oacute;n:</strong> $eleccion<br><strong>Impacto:</strong> $impacto</div>"
    }

    # BANCADAS 3-4 (MOTOR CENTRAL)
    if ($pos -match "3|4") {
        $justificacion = ""
        if ($info.Peso -ge 90) {
            $justificacion = "<br><span style='color:#b91c1c; font-size:0.9em'><strong>Justificaci&oacute;n Estructural:</strong> Los $($info.Peso)kg de $displayName solo son sostenibles en la manga de $pos para no comprometer el trimado longitudinal.</span>"
        }

        if ($age -le 50 -and $info.Peso -ge 85) {
            $sub = "Potencia bruta y torque absoluto ($($info.Peso)kg)."
            $eleccion = "$displayName actúa como el motor principal de tracci&oacute;n del bote."
            $impacto = "Maximiza los vatios en el v&eacute;rtice de potencia (PAM), vital seg&uacute;n la 'Regla de los 45 a&ntilde;os'.$justificacion"
        } elseif ($age -le 50 -and $info.Peso -lt 85) {
            $sub = "Motor din&aacute;mico de alta frecuencia."
            $eleccion = "$displayName aporta velocidad de palada con sus $($info.Altura)cm de palanca equilibrada."
            $impacto = "Favorece la reactividad tras la ciaboga sin penalizar la superficie mojada.$justificacion"
        } elseif ($age -gt 50 -and $info.Peso -ge 90) {
            $sub = "Masa inercial extrema para crucero."
            $eleccion = "$displayName mantiene la inercia hidrodin&aacute;mica en la zona de mayor presi&oacute;n del agua."
            $impacto = "Vence la resistencia del casco en condiciones de mar pesada, aportando estabilidad por peso.$justificacion"
        } else {
            $sub = "Equilibrio veteran&iacute;a y bonificaci&oacute;n."
            $eleccion = "$displayName aporta estabilidad de boga con $($info.Anios) a&ntilde;os de experiencia acumulada."
            $impacto = "Optimiza el h&aacute;ndicap master mientras mantiene la fluidez hidrodin&aacute;mica del motor.$justificacion"
        }
        return "<div style='line-height:1.6'><strong>${titulo}:</strong> $sub<br><strong>Elecci&oacute;n:</strong> $eleccion<br><strong>Impacto:</strong> $impacto</div>"
    }

    # BANCADAS 5-6 (PROA)
    if ($pos -match "5|6|PROA") {
        $alertaPeso = if ($info.Peso -gt 80) { "<br><span style='color:#b91c1c; font-size:0.9em'><strong>ADVERTENCIA:</strong> Los $($info.Peso)kg de $displayName en proa fuerzan el pitching frontal.</span>" } else { "" }
        if ($info.Peso -le 75 -and $age -le 50) {
            $sub = "Reactividad proel y ligereza ($($info.Peso)kg)."
            $eleccion = "$displayName evita el hundimiento de la l&iacute;nea de proa permitiendo el planeo."
            $impacto = "Respuesta inmediata a las correcciones del patr&oacute;n en condiciones de oleaje.$alertaPeso"
        } elseif ($info.Peso -le 75 -and $age -gt 50) {
            $sub = "Visi&oacute;n t&eacute;cnica y control de proa."
            $eleccion = "$displayName aporta ligereza ($($info.Peso)kg) y veteran&iacute;a en el marcaje delantero."
            $impacto = "Optimiza la entrada de la pala evitando turbulencias en la zona de 'pitching'.$alertaPeso"
        } else {
            $sub = "Masa extra en zona de apoyo."
            $eleccion = "$displayName ejerce presi&oacute;n de proa con un perfil de $($info.Peso)kg y $($info.Altura)cm."
            $impacto = "Exige una t&eacute;cnica de salida de pala perfecta para no frenar el planeo del bote.$alertaPeso"
        }
        return "<div style='line-height:1.6'><strong>${titulo}:</strong> $sub<br><strong>Elecci&oacute;n:</strong> $eleccion<br><strong>Impacto:</strong> $impacto</div>"
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
function Get-BestAlternative([string]$posZone, [string]$side, [int]$titularHcp) {
    # Filtro de posicion basado en la zona del bote (posZone tiene prioridad sobre side)
    $posFilter = if ($posZone -eq "PROA") {
        "Proa|Babor"               # remeros de Proa O Babor pueden ir a proa
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
        $hcpC   = Get-HcpSeconds $edadC $genC
        $delta  = $hcpC - $titularHcp

        # === SISTEMA DE PUNTUACION v4.0 (Base Conocimiento Aizburua) ===

        # 1. DEPOSITO NEUROLOGICO (max ~50 pts)
        # Combina años de experiencia con nivel cualitativo del JSON
        $scoreExp  = [math]::Min($aniosC, 15) * 2   # años: max 30 pts
        $scoreExp += Get-ExpNivelPts $expC            # nivel: Élite/Alta=20, Media-Alta=15, Media=10, Baja=5

        # 2. BIOTIPO DOCUMENTAL por zona (max ~25 pts)
        # Rangos extraidos de Posiciones1.md, Posiciones2.md, Posiciones3.md
        $scoreBio = 0
        if ($posZone -eq "PROA" -or $posZone -match "^Bancada [56]") {
            # Zona Proa: prima ligereza. Posiciones3.md: "más ligero ~70-72kg"
            if     ($pesoC -le 72)                    { $scoreBio += 20 }
            elseif ($pesoC -le 75)                    { $scoreBio += 12 }
            elseif ($pesoC -le 78)                    { $scoreBio +=  5 }
            else                                       { $scoreBio -= 10 }
            # B6: bonus por ser Mujer >45. Posiciones3.md: "ideal para mujeres de más de 45"
            if ($posZone -match "^Bancada 6" -and $genC -match "Mujer" -and $edadC -ge 45) { $scoreBio += 15 }
        }
        elseif ($posZone -match "^Bancada [34]") {
            # Motor: prima talla. Posiciones1.md: r=0.67 talla/vatios. ARC1 media: 1.83m
            if     ($altC -ge 190)                     { $scoreBio += 25 }
            elseif ($altC -ge 185)                     { $scoreBio += 20 }
            elseif ($altC -ge 180)                     { $scoreBio += 12 }
            elseif ($altC -ge 176)                     { $scoreBio +=  5 }
            else                                        { $scoreBio -=  8 }
            # Peso ideal Motor: 80-90kg. Posiciones3.md: "más altos, fuertes y pesados"
            if     ($pesoC -ge 80 -and $pesoC -le 90)  { $scoreBio += 10 }
            elseif ($pesoC -ge 75 -and $pesoC -lt 80)  { $scoreBio +=  5 }
            # Edad ideal Motor: 40-49 (mayor PAM). analisis_2.md: "Los Motores"
            if     ($edadC -ge 40 -and $edadC -le 49)  { $scoreBio +=  8 }
            elseif ($edadC -ge 50 -and $edadC -le 59)  { $scoreBio +=  3 }
            elseif ($edadC -gt 65)                      { $scoreBio -= 10 }
        }
        elseif ($posZone -match "^Bancada 2") {
            # Contramarca: más fuerte que B1. Posiciones3.md: "~78-82kg"
            if     ($pesoC -ge 78 -and $pesoC -le 82) { $scoreBio += 20 }
            elseif ($pesoC -ge 75 -and $pesoC -lt 78) { $scoreBio += 10 }
            elseif ($pesoC -gt 82 -and $pesoC -le 88) { $scoreBio +=  8 }
            else                                        { $scoreBio -=  5 }
        }
        elseif ($posZone -match "^Bancada 1") {
            # Popa/Marca: veteranía y ritmo. Posiciones3.md: ">55a, 74-78kg, estatura media-alta"
            if     ($edadC -ge 60)                     { $scoreBio += 15 }
            elseif ($edadC -ge 55)                     { $scoreBio += 10 }
            elseif ($edadC -ge 45)                     { $scoreBio +=  5 }
            # Peso ideal Popa: 74-78kg (evitar apopamiento)
            if     ($pesoC -ge 74 -and $pesoC -le 78)  { $scoreBio +=  8 }
            elseif ($pesoC -ge 70 -and $pesoC -lt 74)  { $scoreBio +=  4 }
            elseif ($pesoC -gt 78 -and $pesoC -le 85)  { $scoreBio +=  2 }
            # Altura: media-alta para arco de palada de 110°. Posiciones2.md
            if     ($altC -ge 180)                     { $scoreBio +=  8 }
            elseif ($altC -ge 175)                     { $scoreBio +=  5 }
            elseif ($altC -ge 170)                     { $scoreBio +=  2 }
        }

        # 3. EFICIENCIA HCP ABE (max ~25 pts)
        # Cada segundo ganado respecto al titular vale 2.5 pts
        $scoreHcp = $delta * 2.5

        $score = $scoreExp + $scoreBio + $scoreHcp

        [PSCustomObject]@{ Rower=$c; Score=$score; HcpDelta=$delta; Edad=$edadC; Peso=$pesoC; Altura=$altC; Anios=$aniosC; Genero=$genC; Hcp=$hcpC; ExpNivel=$expC; ScoreExp=($scoreExp) }
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
    # PATRON: puesto único, no se evalua biomecánicamente
    if ($posZone -eq "PATRON") { return $true }

    # PROA (B7): ligereza crítica. Fuente: Posiciones3.md - "más ligero ~70-72kg, evitar pitching"
    if ($posZone -eq "PROA") {
        if ($info.Peso -gt 75)  { return $false }  # Riesgo de Pitching (cabeceo longitudinal)
        if ($info.Anios -lt 2)  { return $false }  # Minimo de veterania en zona crítica
        return $true
    }

    # BANCADA 6 (Estreles): zona de transición hacia proa, masa controlada
    # Fuente: Posiciones3.md - "ligeros y muy técnicos ~74-76kg"
    if ($posZone -match "^Bancada 6") {
        if ($info.Peso -gt 80) { return $false }   # Exceso lastre en zona de estrechamiento
        return $true
    }

    # BANCADA 5 (apoyo motor-proa): transición rítmica, perfil híbrido
    if ($posZone -match "^Bancada 5") {
        if ($info.Peso -gt 82)  { return $false }
        if ($info.Anios -lt 2)  { return $false }
        return $true
    }

    # BANCADAS 3 y 4 (Motor Central): máxima palanca vectorial y potencia absoluta
    # Fuente: Posiciones1.md - correlación r=0.67 talla/vatios. Media club: 1.76m. Elite: 1.83m
    if ($posZone -match "^Bancada [34]") {
        if ($info.Altura -gt 0 -and $info.Altura -lt 176) { return $false }  # Debajo del biotipo estándar
        if ($info.Peso   -gt 0 -and $info.Peso   -lt 75)  { return $false }  # Masa insuficiente (manga máxima: 1.72m)
        if ($age -gt 65)                                   { return $false }  # Declive de PAM crítico
        return $true
    }

    # BANCADA 2 (Contramarca): soporte rítmico y tracción reactiva
    # Fuente: Posiciones3.md - "más fuertes que los marcas, ~78-82kg"
    if ($posZone -match "^Bancada 2") {
        if ($info.Peso -lt 75) { return $false }  # Insuficiente para rol de tracción
        if ($info.Peso -gt 88) { return $false }  # Exceso que compromete el trimado
        return $true
    }

    # BANCADA 1 (Popa/Marca): estabilidad neurológica, arco de palada de 110°
    # Fuente: Posiciones3.md - ">55 años, peso medio 74-78kg, estatura media-alta"
    if ($posZone -match "^Bancada 1") {
        if ($age -lt 45)                                       { return $false }  # Sin veteranía mínima para marcar ritmo
        if ($info.Peso -gt 85)                                 { return $false }  # Riesgo de apopamiento (hundimiento de popa)
        if ($info.Altura -gt 0 -and $info.Altura -lt 170)     { return $false }  # Arco de palada comprometido (<110°)
        return $true
    }

    return $true
}

function Add-RowerRow($posName, $side, $name, $age) {
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

    # Solo buscar alternativa cuando el puesto NO esta bien cubierto
    $isFit  = Test-PositionFit $posName $age $info
    $altHtml = ""
    if (-not $isFit) {
        $hcp = Get-HcpSeconds $age $info.Genero
        $alt = Get-BestAlternative $posName $side $hcp
        if ($alt) {
            $apodo      = if ($alt.Rower.PSObject.Properties['apodo'] -and $alt.Rower.apodo) { $alt.Rower.apodo } else { $alt.Rower.nombre }
            $genIconAlt = if ($alt.Genero -match "Mujer") { "&female;" } else { "&male;" }
            $expAltStr  = if ($alt.ExpNivel) { $alt.ExpNivel } else { "-" }

            # Calcular impacto HCP del cambio a nivel de bote
            $hcpTitular   = Get-HcpSeconds $age $info.Genero
            $hcpCandidato = Get-HcpSeconds $alt.Edad $alt.Genero
            $hcpDelta     = $hcpCandidato - $hcpTitular
            $hcpImpacto = if ($alt.Edad -lt 45) {
                "<span style='color:#b45309;font-size:12px'><strong>&#9888; HCP: sin aportaci&oacute;n al bote</strong> ($($alt.Edad)a &lt;45 a&ntilde;os)</span>"
            } elseif ($hcpDelta -gt 0) {
                "<span style='color:#15803d;font-size:12px'><strong>&#9650; HCP: +${hcpDelta}s</strong> (ganancia para el bote)</span>"
            } elseif ($hcpDelta -lt 0) {
                "<span style='color:#b91c1c;font-size:12px'><strong>&#9660; HCP: ${hcpDelta}s</strong> (p&eacute;rdida para el bote)</span>"
            } else {
                "<span style='color:#64748b;font-size:12px'>HCP: sin impacto</span>"
            }

            $altLines = @(
                "<div style='background:#fff7ed;border-left:3px solid #ea580c;padding:10px 12px;border-radius:6px;font-size:14px;line-height:1.6'>",
                "<strong style='font-size:15px;color:#9a3412'>REAJUSTE SUGERIDO</strong><br>",
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

    $h.Add((Add-RowerRow "Bancada $n" "Babor" $b.B.nombre $b.B.edad))
    $h.Add((Add-RowerRow "Bancada $n" "Estribor" $b.E.nombre $b.E.edad))
}
$h.Add((Add-RowerRow "PATRON" "Centro" $ali.patron.nombre $ali.patron.edad))
$h.Add("</tbody></table></div>")

# --- AUDITORÍA TÉCNICA AVANZADA (v3.2) ---
$h.Add("<div class='section-title'>2. Auditor&iacute;a de Optimizaci&oacute;n Biomec&aacute;nica</div>")

# Grilla Unificada de Auditoría
$h.Add("<div class='foundation-grid'>")

# Fila 1: Trimado y Estabilidad
$proelInfo = Get-RowerFullInfo $ali.proa.nombre "Proa"
$trimadoMsg = if ([math]::Abs($difPeso) -gt 15) { "<strong>Conflicto:</strong> El desequilibrio lateral global de " + [math]::Round($difPeso, 1) + " kg requiere correcci&oacute;n." } else { "<strong>Acierto:</strong> El equilibrio de masas global es &oacute;ptimo (dif. de " + [math]::Abs([math]::Round($difPeso, 1)) + " kg)." }
$proelMsg = if ($proelInfo.Peso -gt 75) { " El proel ($($proelInfo.DisplayName)) supera los 75kg, lo que podr&iacute;a generar <strong>pitching</strong> excesivo." } else { " El peso del proel ($($proelInfo.Peso)kg) es ideal." }
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

# Estabilidad en Popa (Full Width)
$b1B = Get-RowerFullInfo $ali.bancadas."1".B.nombre "Babor"
$b1E = Get-RowerFullInfo $ali.bancadas."1".E.nombre "Estribor"
$h.Add("<div class='foundation-card full-width' style='border-left-color:#145a32'><h3>Estabilidad en Popa (B1)</h3><p><strong>Acierto T&aacute;ctico:</strong> El uso de $($b1B.DisplayName) y $($b1E.DisplayName) en popa busca asegurar un ritmo estable. Su veteran&iacute;a es cr&iacute;tica para mitigar el impacto del lactato en el tramo final de la regata.</p></div>")

# Fila 2: Potencia y Fisiología
$motorMsg = if ($avgTallaMotor -lt 180) { "La talla media del motor ($([math]::Round($avgTallaMotor,1))cm) es inferior al ideal biomec&aacute;nico (182cm), limitando la palanca real." } else { "Excelente talla media ($([math]::Round($avgTallaMotor,1))cm) en el bloque motor, maximizando el torque." }
$b3B = Get-RowerFullInfo $ali.bancadas."3".B.nombre "Babor"
$b3E = Get-RowerFullInfo $ali.bancadas."3".E.nombre "Estribor"
$pesoB3 = $b3B.Peso + $b3E.Peso
$b3Msg = ""
if ($pesoB3 -gt 175) {
    $b3Msg = "<br><br><strong style='color:var(--r)'>ALERTA INERCIAL B3:</strong> El bloque central soporta una carga masiva de <strong>$pesoB3 kg</strong> ($($b3B.DisplayName) + $($b3E.DisplayName)). Esta 'masa inercial' ayuda a mantener la velocidad de crucero, pero penaliza dr&aacute;sticamente la aceleraci&oacute;n tras la ciaboga."
}
$h.Add("<div class='foundation-card' style='border-left-color:#f59e0b'><h3>An&aacute;lisis del Bloque Motor (B3-B5)</h3><p><strong>Evaluaci&oacute;n:</strong> $motorMsg $b3Msg</p></div>")

$h.Add("<div class='foundation-card' style='border-left-color:#6c5ce7'><h3>Diagn&oacute;stico de Potencia</h3><p>Con un peso total de tripulaci&oacute;n de <strong>$totalPeso kg</strong>, la relaci&oacute;n potencia/peso es aceptable. Se sugiere priorizar entrenamientos de potencia aer&oacute;bica m&aacute;xima (PAM) para compensar el h&aacute;ndicap de edad media de <strong>$([math]::Round($avgEdad, 1)) a&ntilde;os</strong>.</p></div>")

$h.Add("</div>")

# --- MOTOR DE OPTIMIZACIÓN: EL MOVIMIENTO MAESTRO Y PLAN DE PLANTILLA ---
$h.Add("<div class='opt-box'>")
$h.Add("<h3 style='color:var(--r); margin-top:0; text-transform:uppercase; font-size:18px'>Dictamen de Reajuste: El Movimiento Maestro</h3>")

$jovenesPopaProa = @()
$veteranosMotor = @()
$rosterSugerencias = @()

# Escaneo de alineación actual
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

# Producir Informe de Cambios
if ($jovenesPopaProa.Count -gt 0 -and $veteranosMotor.Count -gt 0) {
    foreach ($joven in $jovenesPopaProa) {
        $vetNombres = ($veteranosMotor | ForEach-Object { "$($_.Nombre) ($($_.Edad)a)" }) -join " o "
        $h.Add("<p style='font-size:16px; margin-bottom:15px'><strong>PROPUESTA INTERNA:</strong> Intercambiar a <strong>$($joven.Nombre) ($($joven.Peso)kg)</strong> con <strong>$vetNombres</strong>.</p>")
        $h.Add("<div style='display:grid; grid-template-columns: 1fr 1fr; gap:15px; margin-bottom:25px'>")
        $h.Add("<div style='background:white; padding:15px; border-radius:8px; border-left:4px solid var(--r); flex:1'><strong>Rol de $($joven.Nombre):</strong> Aportar&aacute; sus $($joven.Peso)kg de masa activa en el bloque motor. Justificaci&oacute;n: Mayor torque y aprovechamiento de sus $($joven.Edad) a&ntilde;os de fuerza explosiva.</div>")
        $h.Add("<div style='background:white; padding:15px; border-radius:8px; border-left:4px solid #1e293b; flex:1'><strong>Rol de ${vetNombres}:</strong> Asegurar el ritmo estable en Bancada $($joven.Bancada). Justificaci&oacute;n: Su veteran&iacute;a compensa el lactato en la zona de marca final.</div>")
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

# BENCHMARK Y DICTAMEN
$h.Add("<div class='section-title'>3. Comparativa de Edad y Proyecci&oacute;n de Temporada</div><div style='background:white; border-radius:15px; padding:40px; box-shadow: 0 10px 30px rgba(0,0,0,0.15); font-size:19px; line-height:1.7'><p>Comparativa de Edad Media con los rivales:</p><div class='benchmark-grid'><div class='bench-card winner'><strong>GETXO:</strong> 55.64a (Ganador)</div><div class='bench-card'><strong>AIZBURUA:</strong> " + [math]::Round($avgEdad, 2) + "a</div><div class='bench-card'><strong>BILBAO:</strong> 56.14a</div><div class='bench-card'><strong>IBERIA:</strong> 56.79a</div><div class='bench-card'><strong>PLENTZIA:</strong> 56.21a</div><div class='bench-card'><strong>FORTUNA:</strong> 58.29a</div></div><div style='margin-top:40px; border-top:3px solid #f1f5f9; padding-top:30px; background: #fef2f2; padding: 25px; border-radius: 12px; border-left: 8px solid var(--r)'><strong style='font-size:22px; color:var(--r)'>Dictamen Final de Direcci&oacute;n T&eacute;cnica:</strong><br><br>Con una tripulaci&oacute;n de <strong>$totalPeso kg</strong>, la clave es la eficiencia hidrodin&aacute;mica. Debemos aprovechar la veteran&iacute;a para mantener el rumbo en condiciones de viento cruzado, compensando el desequilibrio de <strong>$([math]::Round($difPeso, 1)) kg</strong> mediante una sincron&iacute;a perfecta en la entrada de la pala.</div></div>")

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
