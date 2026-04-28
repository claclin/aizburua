param([Parameter(Mandatory = $true)][string]$RegataName)
# Set-StrictMode -Version Latest # Deshabilitado para permitir acceso flexible a propiedades JSON opcionales
$ErrorActionPreference = "Stop"
$rootPath = Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..") 
$jsonPath = Join-Path $rootPath "data\historico-regatas.json"
$plantillaPath = Join-Path $rootPath "data\plantilla_remeros.json"
$remerosPath = Join-Path $rootPath "remeros"
$outPath = Join-Path $rootPath "informes"
$safe = $RegataName -replace '[^\w]', '_'
$htmlFile = Join-Path $outPath "Informe_Aizburua_$safe.html"

if (-not(Test-Path $outPath)) { New-Item -ItemType Directory -Path $outPath | Out-Null }
$data = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$regata = $data.regatas | Where-Object { $_.nombre_corto -eq $RegataName -or $_.nombre -like "*$RegataName*" } | Select-Object -First 1
if (-not $regata) { Write-Error "Regata no encontrada en el historico"; exit 1 }

$remerosDB = @()
if (Test-Path $plantillaPath) {
    $remerosDB = Get-Content $plantillaPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

$cond = $regata.condiciones_campo
$aizd = $regata.aizburua

$ali = $null
if ($aizd.PSObject.Properties['alineacion']) { $ali = $aizd.alineacion }
$g1 = $null
if ($regata.grupos.PSObject.Properties['grupo_1']) { $g1 = $regata.grupos.grupo_1 }
$g2 = $null
if ($regata.grupos.PSObject.Properties['grupo_2']) { $g2 = $regata.grupos.grupo_2 }

# Resultados y Top 3 (usando Grupo 1 por defecto o el que contenga a Aizburua)
$mainGroup = $g1
if ($aizd.PSObject.Properties['grupo']) { $mainGroup = $regata.grupos.$($aizd.grupo) }
$res = @()
if ($mainGroup) { $res = $mainGroup.resultados | Sort-Object { [double]($_.puesto) } }
$aiz = $res | Where-Object { $_.club -eq "AIZBURUA" }
$top1 = $res | Where-Object { [int]$_.puesto -eq 1 } | Select-Object -First 1
$top2 = $res | Where-Object { [int]$_.puesto -eq 2 } | Select-Object -First 2 | Select-Object -Last 1
$top3 = $res | Where-Object { [int]$_.puesto -eq 3 } | Select-Object -First 3 | Select-Object -Last 1

# ---------- Activos Visuales (Logos) ----------
$logo1Base64 = "" ; $logo2Base64 = ""
$logo1Path = Join-Path $rootPath "Logo1.jpg"
$logo2Path = Join-Path $rootPath "Logo2.jpg"

if (Test-Path $logo1Path) {
    $bytes = [System.IO.File]::ReadAllBytes($logo1Path)
    $logo1Base64 = [System.Convert]::ToBase64String($bytes)
}
if (Test-Path $logo2Path) {
    $bytes = [System.IO.File]::ReadAllBytes($logo2Path)
    $logo2Base64 = [System.Convert]::ToBase64String($bytes)
}

# ---------- Funciones ----------
function TS([string]$t) {
    if (-not $t) { return 0.0 }
    if ($t -match '^(\d+):(\d+)[,.](\d+)$') { return [double]$Matches[1] * 60 + [double]$Matches[2] + [double]("0." + $Matches[3]) }
    return 0.0
}
function DiffStr([double]$a, [double]$b) {
    $d = [math]::Round($a - $b, 1)
    if ($d -ge 0) { return "+${d}s" }
    return "${d}s"
}
function PctStr([double]$a, [double]$b) {
    if ($b -le 0) { return "---" }
    $p = [math]::Round((($a - $b) / $b) * 100, 2)
    return "+${p}%"
}
function ToMMSS([double]$s) {
    if ($s -le 0) { return "00:00,0" }
    $m = [math]::Floor($s / 60)
    $sec = $s - ($m * 60)
    $ss = $sec.ToString("00.0", [System.Globalization.CultureInfo]::InvariantCulture).Replace(".", ",")
    return ("{0:00}:$ss" -f $m)
}
function ConvertTo-HtmlEntity($s) {
    if (-not $s) { return "" }
    return $s.ToString().Replace(([string][char]225), "&aacute;").Replace(([string][char]233), "&eacute;").Replace(([string][char]237), "&iacute;").Replace(([string][char]243), "&oacute;").Replace(([string][char]250), "&uacute;").Replace(([string][char]241), "&ntilde;").Replace(([string][char]193), "&Aacute;").Replace(([string][char]201), "&Eacute;").Replace(([string][char]205), "&Iacute;").Replace(([string][char]211), "&Oacute;").Replace(([string][char]218), "&Uacute;").Replace(([string][char]209), "&Ntilde;").Replace(([string][char]186), "&ordm;").Replace(([string][char]170), "&ordf;").Replace(([string][char]191), "&iquest;").Replace(([string][char]161), "&iexcl;")
}
# HM: parsea formato HH:MM (hora de salida) a minutos decimales para comparar con evolucion_meteo
function HM([string]$t) {
    if ($t -match '^(\d+):(\d+)$') { return [double]$Matches[1] * 60 + [double]$Matches[2] }
    return 0.0
}
function Get-MeteoByTime([string]$timeStr) {
    if (-not $cond.evolucion_meteo) { return $null }
    $t = HM $timeStr
    $best = $null ; $bestDiff = 999999
    foreach ($m in $cond.evolucion_meteo) {
        $mt = HM $m.hora
        $diff = [math]::Abs($t - $mt)
        if ($diff -lt $bestDiff) { $bestDiff = $diff; $best = $m }
    }
    return $best
}

function Get-RowerInfo([string]$name, [string]$posicion) {
    if (-not $name) { return $null }
    $cleanName = $name.Replace(".", "").Trim()
    
    # Busqueda en DB con logica de desambiguacion para Maite
    $rower = $null
    if ($cleanName -ieq "Maite") {
        # Si es Maite, miramos la posicion (Babor = Maite Zarra, Estribor = Maite)
        if ($posicion -ieq "Babor") {
            $rower = $remerosDB | Where-Object { $_.nombre -ieq "Maite Zarra" }
        }
        else {
            $rower = $remerosDB | Where-Object { $_.nombre -ieq "Maite" -and $_.posicion -ieq "Estribor" }
        }
    }
    else {
        $rower = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $cleanName -or $_.apodo -ieq $cleanName } | Select-Object -First 1
    }

    $displayName = $name
    $imgBase64 = ""
    $apodo = ""
    $altura = 0
    $peso = 0.0
    $anios = 0

    if ($rower) {
        if ($rower.PSObject.Properties['apodo'] -and $rower.apodo) {
            $apodo = $rower.apodo
            $displayName = $rower.apodo
        }
        
        # Captura robusta de métricas (permitir cualquier tipo numérico)
        try {
            if ($rower.PSObject.Properties['altura_cm'] -and $rower.altura_cm -match '^\d') { $altura = [double]$rower.altura_cm }
            if ($rower.PSObject.Properties['peso_kg'] -and $rower.peso_kg -match '^\d') { $peso = [double]$rower.peso_kg }
            
            # Busqueda robusta de experiencia (evitar problemas con la 'ñ' en PowerShell)
            $propAnios = $rower.PSObject.Properties | Where-Object { $_.Name -match 'experiencia' -and ($_.Name -match 'a.os' -or $_.Name -match 'anios') } | Select-Object -First 1
            if ($propAnios -and ($propAnios.Value -as [double] -ge 0)) { $anios = [double]$propAnios.Value }
        } catch { }

        # Intentar cargar foto
        $photoFile = ""
        if ($apodo) { $photoFile = Join-Path $remerosPath "$apodo.jpg" }
        if (($photoFile -eq "") -or (-not (Test-Path $photoFile))) { $photoFile = Join-Path $remerosPath "$($rower.nombre).jpg" }
        if (-not (Test-Path $photoFile)) { $photoFile = Join-Path $remerosPath "$cleanName.jpg" }

        if (Test-Path $photoFile) {
            $bytes = [System.IO.File]::ReadAllBytes($photoFile)
            $imgBase64 = [System.Convert]::ToBase64String($bytes)
        }
    }

    return [PSCustomObject]@{
        DisplayName  = $displayName.ToUpper()
        ImgBase64    = $imgBase64
        OriginalName = $name
        Altura       = $altura
        Peso         = $peso
        Anios        = $anios
    }
}

# ---------- Calculos de tiempos ----------
$sa = 0; $sg = 0; $s2t = 0; $s3t = 0; $sciaAiz = 0; $sciaG1 = 0; $sciaG2 = 0; $sciaG3 = 0
$tanda1 = $null

if ($aiz) { $sa = TS ($aiz | Select-Object -ExpandProperty tiempo_raw -ErrorAction SilentlyContinue) }
if ($top1) { $sg = TS ($top1 | Select-Object -ExpandProperty tiempo_raw -ErrorAction SilentlyContinue) }
if ($top2) { $s2t = TS ($top2 | Select-Object -ExpandProperty tiempo_raw -ErrorAction SilentlyContinue) }
if ($top3) { $s3t = TS ($top3 | Select-Object -ExpandProperty tiempo_raw -ErrorAction SilentlyContinue) }

$avgG1 = 0 ; $mediaG1Fmt = "00:00,0"
if ($res) {
    try {
        $avgG1 = [math]::Round(($res | ForEach-Object { TS $_.tiempo_raw } | Measure-Object -Average).Average, 1)
        $mediaG1Fmt = ToMMSS $avgG1
    }
    catch { }
}

if ($g1 -and $aiz) {
    $tanda1 = $g1.resultados | Where-Object { $_.tanda -eq $aiz.tanda }
}

$avgT1 = 0 ; $mediaT1Fmt = "00:00,0"
if ($tanda1) {
    try {
        $avgT1 = [math]::Round(($tanda1 | ForEach-Object { TS $_.tiempo_raw } | Measure-Object -Average).Average, 1)
        $mediaT1Fmt = ToMMSS $avgT1
    }
    catch { }
}

# Ciabogas (Segundos y Diferenciales)
if ($aiz) { $sciaAiz = TS ($aiz | Select-Object -ExpandProperty ciaboga_1 -ErrorAction SilentlyContinue) }
if ($top1) { $sciaG1 = TS ($top1 | Select-Object -ExpandProperty ciaboga_1 -ErrorAction SilentlyContinue) }
if ($top2) { $sciaG2 = TS ($top2 | Select-Object -ExpandProperty ciaboga_1 -ErrorAction SilentlyContinue) }
if ($top3) { $sciaG3 = TS ($top3 | Select-Object -ExpandProperty ciaboga_1 -ErrorAction SilentlyContinue) }

$dCiaG1 = DiffStr $sciaG1 $sciaAiz
$dCiaG2 = DiffStr $sciaG2 $sciaAiz
$dCiaG3 = DiffStr $sciaG3 $sciaAiz

$avgCiaG1 = 0 ; $mediaCiaG1Fmt = "00:00,0"
if ($g1) {
    try {
        $avgCiaG1 = [math]::Round(($g1.resultados | ForEach-Object { 
                    if ($_.PSObject.Properties['ciaboga_1']) { TS $_.ciaboga_1 } else { 0 } 
                } | Measure-Object -Average | Select-Object -ExpandProperty Average), 1)
        $mediaCiaG1Fmt = ToMMSS $avgCiaG1
    }
    catch { }
}
$dCiaMediaG1 = DiffStr $avgCiaG1 $sciaAiz

$avgCiaT1 = 0 ; $mediaCiaT1Fmt = "00:00,0"
if ($tanda1) {
    try {
        $avgCiaT1 = [math]::Round(($tanda1 | ForEach-Object { 
                    if ($_.PSObject.Properties['ciaboga_1']) { TS $_.ciaboga_1 } else { 0 } 
                } | Measure-Object -Average | Select-Object -ExpandProperty Average), 1)
        $mediaCiaT1Fmt = ToMMSS $avgCiaT1
    }
    catch { }
}
$dCiaMediaT1 = DiffStr $avgCiaT1 $sciaAiz

# ---------- ANALISIS DINAMICO DE CALLES ----------
$lanesData = @{}
$callesProps = $cond.geometria.PSObject.Properties | Where-Object { $_.Name -like "calle*" }
foreach ($prop in $callesProps) {
    try {
        $cIdStr = $prop.Name -replace "calle", ""
        if (-not $cIdStr) { continue }
        $cId = [int]$cIdStr
        $cResults = $g1.resultados | Where-Object { [int]$_.calle -eq $cId }
        if ($cResults) {
            $avg = [math]::Round(($cResults | ForEach-Object { TS $_.tiempo_raw } | Measure-Object -Average).Average, 1)
            $dif = [math]::Round($avg - $avgAllG1, 1)
            $difStr = "${dif}s"
            if ($dif -gt 0) { $difStr = "+${dif}s" }
            $lanesData[$cId] = @{ 
                avg    = $avg; 
                fmt    = ToMMSS $avg; 
                dif    = $dif; 
                difStr = $difStr;
                label  = $prop.Value.color;
                pos    = $prop.Value.posicion
            }
        }
    }
    catch { 
        Write-Host "Aviso: Error procesando calle $($prop.Name): $($_.Exception.Message)"
    }
}

# Determinar mejor y peor calle
$mejorCalleId = 1 ; $peorCalleId = 1
$minDif = 999.0 ; $maxDif = -999.0
foreach ($cid in $lanesData.Keys) {
    if ($lanesData[$cid].dif -lt $minDif) { $minDif = $lanesData[$cid].dif; $mejorCalleId = $cid }
    if ($lanesData[$cid].dif -gt $maxDif) { $maxDif = $lanesData[$cid].dif; $peorCalleId = $cid }
}

$aizCalle = 1
if ($aiz) { $aizCalle = [int]$aiz.calle }
$saAiz = if ($aiz) { TS $aiz.tiempo_raw } else { 0 }

$mejorDifVal = 0
if ($lanesData.ContainsKey($mejorCalleId)) { $mejorDifVal = $lanesData[$mejorCalleId].dif }
$aizDifPropia = 0
if ($lanesData.ContainsKey($aizCalle)) { $aizDifPropia = $lanesData[$aizCalle].dif }

$sProy = $saAiz - $aizDifPropia + $mejorDifVal
$tProyFmt = ToMMSS $sProy
$puestoProy = ($g1.resultados | Where-Object { (TS $_.tiempo_raw) -le $sProy } | Measure-Object).Count + 1

$veredictoCalles = "Topografia del campo analizada en modalidad N-Calles."
if ([math]::Abs($maxDif - $minDif) -gt 5) {
    $veredictoCalles = "La Calle $peorCalleId fue considerablemente desfavorable (+$( [math]::Round($maxDif - $minDif, 1) )s de diferencia vs $mejorCalleId)."
}

# Analisis por tanda
$tandas = $g1.resultados | Select-Object -ExpandProperty tanda | Sort-Object -Unique
$tandaRows = [System.Collections.Generic.List[string]]::new()
$prevAvgT = 0.0
foreach ($t in $tandas) {
    $tRes = $g1.resultados | Where-Object { $_.tanda -eq $t }
    $hora = ($tRes | Select-Object -First 1).hora_salida
    $avgT = [math]::Round(($tRes | ForEach-Object { TS $_.tiempo_raw } | Measure-Object -Average).Average, 1)
    $fmtT = ToMMSS $avgT
    $rc1 = $tRes | Where-Object { $_.calle -eq 1 }
    $rc2 = $tRes | Where-Object { $_.calle -eq 2 }
    $ac1 = if ($rc1) { [math]::Round((TS ($rc1 | Select-Object -First 1).tiempo_raw), 1) }else { -1 }
    $ac2 = if ($rc2) { [math]::Round((TS ($rc2 | Select-Object -First 1).tiempo_raw), 1) }else { -1 }

    $tandaMeteo = Get-MeteoByTime $hora
    $mPill = ""
    if ($tandaMeteo) { 
        $corrFmt = $tandaMeteo.corriente.Replace("Vaciante", "Marea Bajando")
        $mPill = "<br><span style='font-size:9px; color:#c0001a'>Viento: $($tandaMeteo.viento_kmh) km/h | Ola: $($tandaMeteo.ola_m)m | $corrFmt</span>" 
    }
    
    $calleComent = ""
    if ($ac1 -gt 0 -and $ac2 -gt 0) {
        $difCC = [math]::Round($ac1 - $ac2, 1)
        if ($difCC -gt 3) { $calleComent = " - Calle 1 (Blanca) fue +${difCC}s m&aacute;s lenta que Calle 2 (Roja)" }
        elseif ($difCC -lt -3) { $difCCa = [math]::Abs($difCC); $calleComent = " - Calle 2 (Roja) fue +${difCCa}s m&aacute;s lenta que Calle 1 (Blanca)" }
        else { $calleComent = " - Ambas calles similares en esta tanda" }
    }

    $tendComent = ""
    if ($prevAvgT -gt 0) {
        $delt = [math]::Round($avgT - $prevAvgT, 1)
        if ($delt -lt -4) { $aDelt = [math]::Abs($delt); $tendComent = "<span class='tendencia-buena'>Tanda m&aacute;s r&aacute;pida (-${aDelt}s vs anterior)</span>" }
        elseif ($delt -gt 4) { $tendComent = "<span class='tendencia-mala'>ANOMAL&Iacute;A: Tanda m&aacute;s lenta (+${delt}s vs anterior). Coincide con el empeoramiento del mar</span>" }
        else { $tendComent = "Tiempos estables. El empeoramiento del mar neutraliza la mejora de los clubes" }
    }
    else { $tendComent = "Referencia inicial (Grupo 1)" }

    $avgVel = [math]::Round($regata.distancia_m / $avgT, 2)
    $fmtTandaVal = "$fmtT <span style='font-size:10px; color:#666'>($avgVel m/s)</span>"
    $aizMark = if ($t -eq $aiz.tanda) { ' class="aiz"' }else { "" }
    $tandaRows.Add("<tr${aizMark}><td><strong>Tanda $t</strong></td><td>${hora}h$mPill</td><td>$fmtTandaVal</td><td>${tendComent}${calleComent}</td></tr>")
    $prevAvgT = $avgT
}
$ultimaTanda = ($tandas | Measure-Object -Maximum).Maximum
$trUlt = $g1.resultados | Where-Object { $_.tanda -eq $ultimaTanda }
$avgUlt = [math]::Round(($trUlt | ForEach-Object { TS $_.tiempo_raw } | Measure-Object -Average).Average, 1)
$difGlobal = [math]::Round($avgT1 - $avgUlt, 1)
$tendenciaMarea = if ($cond.marea.estado_en_regata -like "*vaciante*") { " debido al pico de corriente de marea bajando." } else { "." }
$tendenciaGlobal = if ($difGlobal -gt 5) { "Las tandas finales promediaron ${difGlobal}s menos que la Tanda 1. Comportamiento l&oacute;gico por el ranking." }
elseif ($difGlobal -lt -5) { $dga = [math]::Abs($difGlobal); "<strong>ANOMAL&Iacute;A CR&Iacute;TICA:</strong> Las tandas finales promediaron ${dga}s m&aacute;s lentas pese a ser mejores clubes. El mar se endureci&oacute; dr&aacute;sticamente$tendenciaMarea" }
else { "Tiempos planos (${difGlobal}s). Indica un endurecimiento del campo que neutraliz&oacute; la superioridad de los cabezas de serie$tendenciaMarea" }

# Tablas de clasificacion
$trG1 = [System.Text.StringBuilder]::new()
foreach ($r in $res) {
    $cls = if ($r.club -eq "AIZBURUA") { ' class="aiz"' }else { "" }
    [void]$trG1.AppendLine("<tr${cls}><td>$($r.puesto)&ordm;</td><td>$($r.club)</td><td>$($r.hora_salida)h</td><td>T$($r.tanda) C$($r.calle)</td><td>$($r.ciaboga_1)</td><td>$($r.tiempo_raw)</td><td>$($r.handicap)</td><td><strong>$($r.tiempo_final)</strong></td></tr>")
}
$trG2 = [System.Text.StringBuilder]::new()
foreach ($r in $g2.resultados | Sort-Object puesto) {
    [void]$trG2.AppendLine("<tr><td>$($r.puesto)&ordm;</td><td>$($r.club)</td><td>$($r.hora_salida)h</td><td>T$($r.tanda) C$($r.calle)</td><td>$($r.ciaboga_1)</td><td>$($r.tiempo_raw)</td><td>$($r.handicap)</td><td><strong>$($r.tiempo_final)</strong></td></tr>")
}
# Construccion tabla alineacion con edades (ahora con FOTOS y APODOS)
$trAli = [System.Text.StringBuilder]::new()

function New-RowerCell($name, $pos, $isBabor) {
    $info = Get-RowerInfo $name $pos
    $imgHtml = ""
    if ($info.ImgBase64) {
        $imgHtml = "<img src='data:image/jpeg;base64,$($info.ImgBase64)' class='r-avatar' alt='$name'>"
    }
    else {
        $imgHtml = "<div class='r-avatar' style='display:flex;align-items:center;justify-content:center;font-weight:900;color:#999'>?</div>"
    }
    
    $sideBdg = if ($isBabor) { "<span class='bdg'>B</span>" } else { "<span class='bdg'>E</span>" }
    $meta = "$sideBdg"
    
    # Usar datos ya obtenidos por Get-RowerInfo
    if ($info.Peso -gt 0) { $meta += " | <strong>$($info.Peso)</strong> kg" }
    if ($info.Altura -gt 0) { $meta += " | $($info.Altura) cm" }
    if ($info.Anios -ge 0) { $meta += " | $($info.Anios) &ntilde;os exp" }

    return "<div class='r-cell'>$imgHtml <div class='r-info'><span class='r-name'>$(ConvertTo-HtmlEntity $info.DisplayName)</span><span class='r-meta'>$meta</span></div></div>"
}

# --- PROA ---
$proaCell = New-RowerCell $ali.proa.nombre "Proa" $false
[void]$trAli.AppendLine("<tr class='proa-row'><td class='bn'>PROA</td><td colspan='2' style='text-align:center'>$proaCell</td></tr>")

# --- BANCADAS ---
foreach ($n in 6..1) {
    $b = $ali.bancadas."$n"
    $lbl = if ($n -eq 1) { "1 - POPA" } else { "$n" }
    $bCell = New-RowerCell $b.B.nombre "Babor" $true
    $eCell = New-RowerCell $b.E.nombre "Estribor" $false
    [void]$trAli.AppendLine("<tr><td class='bn'>Bancada $lbl</td><td class='bab'>$bCell</td><td class='est'>$eCell</td></tr>")
}

# --- PATRON ---
$patronCell = New-RowerCell $ali.patron.nombre "Patron" $false
[void]$trAli.AppendLine("<tr class='patron-row'><td class='bn'>PATRON</td><td colspan='2' style='text-align:center'>$patronCell</td></tr>")

# Calculos de estad&iacute;sticas de edad, peso y talla
$edadesConfirmadas = [System.Collections.Generic.List[int]]::new()
$pesosTotal = [System.Collections.Generic.List[double]]::new()
$pesosBabor = [System.Collections.Generic.List[double]]::new()
$pesosEstribor = [System.Collections.Generic.List[double]]::new()
$tallasMotor = [System.Collections.Generic.List[int]]::new()
$tallasResto = [System.Collections.Generic.List[int]]::new()

function Collect-RowerData($name, $pos, $side) {
    $r = Get-RowerInfo $name $pos
    if ($r.Peso -gt 0) { 
        [void]$pesosTotal.Add([double]$r.Peso) 
        if ($side -eq "Babor") { [void]$pesosBabor.Add([double]$r.Peso) }
        elseif ($side -eq "Estribor") { [void]$pesosEstribor.Add([double]$r.Peso) }
    }
    # Edades y Experience
    $clean = $name.Replace(".", "").Trim()
    $dbRower = $null
    if ($clean -ieq "Maite") {
        if ($pos -ieq "Babor") { $dbRower = $remerosDB | Where-Object { $_.nombre -ieq "Maite Zarra" } }
        else { $dbRower = $remerosDB | Where-Object { $_.nombre -ieq "Maite" -and $_.posicion -ieq "Estribor" } }
    } else {
        $dbRower = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $clean -or $_.apodo -ieq $clean } | Select-Object -First 1
    }
    
    if ($dbRower -and $dbRower.edad) { [void]$edadesConfirmadas.Add([int]$dbRower.edad) }
}

# Procesar tripulación
Collect-RowerData $ali.proa.nombre "Proa" "Proa"
Collect-RowerData $ali.patron.nombre "Patron" "Patron"
foreach ($n in 1..6) {
    Collect-RowerData $ali.bancadas."$n".B.nombre "Babor" "Babor"
    Collect-RowerData $ali.bancadas."$n".E.nombre "Estribor" "Estribor"
    
    # Recoger tallas para analisis de motor
    $rB = Get-RowerInfo $ali.bancadas."$n".B.nombre "Babor"
    $rE = Get-RowerInfo $ali.bancadas."$n".E.nombre "Estribor"
    if ($n -match "3|4|5") {
        if ($rB.Altura -gt 0) { [void]$tallasMotor.Add($rB.Altura) }
        if ($rE.Altura -gt 0) { [void]$tallasMotor.Add($rE.Altura) }
    } else {
        if ($rB.Altura -gt 0) { [void]$tallasResto.Add($rB.Altura) }
        if ($rE.Altura -gt 0) { [void]$tallasResto.Add($rE.Altura) }
    }
}

$pesoTripulacion = ($pesosTotal | Measure-Object -Sum).Sum
$pesoBabor = ($pesosBabor | Measure-Object -Sum).Sum
$pesoEstribor = ($pesosEstribor | Measure-Object -Sum).Sum
$difPeso = [math]::Round($pesoBabor - $pesoEstribor, 1)

$totalConfirm = $edadesConfirmadas.Count
$totalMiembros = 14
$edadMedia = if ($edadesConfirmadas.Count -gt 0) { [math]::Round(($edadesConfirmadas | Measure-Object -Average).Average, 1) }else { $null }
$edadMediaStr = if ($edadMedia) { "${edadMedia} a&ntilde;os" }else { "Pendiente" }
$edadMin = if ($edadesConfirmadas.Count -gt 0) { ($edadesConfirmadas | Measure-Object -Minimum).Minimum }else { $null }
$edadMax = if ($edadesConfirmadas.Count -gt 0) { ($edadesConfirmadas | Measure-Object -Maximum).Maximum }else { $null }
$edadRangoStr = if ($edadMin -ne $null -and $edadMax -ne $null) { "${edadMin} - ${edadMax} a&ntilde;os" }else { "Pendiente" }


# Analisis especifico por bloque Popa (bancadas 1-2) vs Proa (bancadas 5-6)
$edadesBloquePopa = [System.Collections.Generic.List[int]]::new()
$edadesBloqueCentral = [System.Collections.Generic.List[int]]::new()
$edadesBloqueProa = [System.Collections.Generic.List[int]]::new()
foreach ($n in 1..2) {
    $b = $ali.bancadas."$n"
    $rB = Get-RowerInfo $b.B.nombre "Babor" ; $rE = Get-RowerInfo $b.E.nombre "Estribor"
    if ($rB.Anios -gt 0) { [void]$edadesBloquePopa.Add($rB.Anios) } # Usamos experiencia para estos bloques? No, el skill pide EDAD real.
}
# Re-hacer bloques con edad real
$edadesBloquePopa.Clear(); $edadesBloqueCentral.Clear(); $edadesBloqueProa.Clear()
foreach ($n in 1..2) {
    $b = $ali.bancadas."$n"
    $dbB = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $b.B.nombre.Replace(".", "").Trim() -or $_.apodo -ieq $b.B.nombre.Replace(".", "").Trim() } | Select-Object -First 1
    $dbE = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $b.E.nombre.Replace(".", "").Trim() -or $_.apodo -ieq $b.E.nombre.Replace(".", "").Trim() } | Select-Object -First 1
    if ($dbB.edad) { [void]$edadesBloquePopa.Add($dbB.edad) }
    if ($dbE.edad) { [void]$edadesBloquePopa.Add($dbE.edad) }
}
foreach ($n in 3..4) {
    $b = $ali.bancadas."$n"
    $dbB = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $b.B.nombre.Replace(".", "").Trim() -or $_.apodo -ieq $b.B.nombre.Replace(".", "").Trim() } | Select-Object -First 1
    $dbE = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $b.E.nombre.Replace(".", "").Trim() -or $_.apodo -ieq $b.E.nombre.Replace(".", "").Trim() } | Select-Object -First 1
    if ($dbB.edad) { [void]$edadesBloqueCentral.Add($dbB.edad) }
    if ($dbE.edad) { [void]$edadesBloqueCentral.Add($dbE.edad) }
}
foreach ($n in 5..6) {
    $b = $ali.bancadas."$n"
    $dbB = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $b.B.nombre.Replace(".", "").Trim() -or $_.apodo -ieq $b.B.nombre.Replace(".", "").Trim() } | Select-Object -First 1
    $dbE = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $b.E.nombre.Replace(".", "").Trim() -or $_.apodo -ieq $b.E.nombre.Replace(".", "").Trim() } | Select-Object -First 1
    if ($dbB.edad) { [void]$edadesBloqueProa.Add($dbB.edad) }
    if ($dbE.edad) { [void]$edadesBloqueProa.Add($dbE.edad) }
}

$avgBloquePopa = if ($edadesBloquePopa.Count -gt 0) { [math]::Round(($edadesBloquePopa | Measure-Object -Average).Average, 1) }else { $null }
$avgBloqueCentral = if ($edadesBloqueCentral.Count -gt 0) { [math]::Round(($edadesBloqueCentral | Measure-Object -Average).Average, 1) }else { $null }
$avgBloqueProa = if ($edadesBloqueProa.Count -gt 0) { [math]::Round(($edadesBloqueProa | Measure-Object -Average).Average, 1) }else { $null }
$avgPopaStr = if ($avgBloquePopa) { "${avgBloquePopa} a&ntilde;os" }else { "Pendiente" }
$avgCentralStr = if ($avgBloqueCentral) { "${avgBloqueCentral} a&ntilde;os" }else { "Pendiente" }
$avgProaStr = if ($avgBloqueProa) { "${avgBloqueProa} a&ntilde;os" }else { "Pendiente" }

# Variables planas para el HTML
$aizPuesto = $aizd.puesto_en_grupo
$aizTotal = $aizd.total_en_grupo
$aizCalle = $aiz.calle
$aizTanda = $aiz.tanda
$aizHora = $aiz.hora_salida
$aizHcp = $aiz.handicap
$aizRaw = $aiz.tiempo_raw
$aizFin = $aiz.tiempo_final
$aizCiab = $aiz.ciaboga_1
$t1Nom = $top1.club ; $t1Raw = $top1.tiempo_raw ; $t1Hora = $top1.hora_salida ; $t1T = $top1.tanda ; $t1C = $top1.calle ; $t1Ciab = $top1.ciaboga_1
$t2Nom = $top2.club ; $t2Raw = $top2.tiempo_raw ; $t2Hora = $top2.hora_salida ; $t2T = $top2.tanda ; $t2C = $top2.calle ; $t2Ciab = $top2.ciaboga_1
$t3Nom = $top3.club ; $t3Raw = $top3.tiempo_raw ; $t3Hora = $top3.hora_salida ; $t3T = $top3.tanda ; $t3C = $top3.calle ; $t3Ciab = $top3.ciaboga_1
$RegNombre = $regata.nombre
$RegFecha = $regata.fecha

# Calcular Puesto Raw (Potencia Bruta sin Handicap comparando tiempos Raw reales)
$sAizRaw = TS $aiz.tiempo_raw
$aizPuestoRaw = ($g1.resultados | Where-Object { (TS $_.tiempo_raw) -lt $sAizRaw } | Measure-Object).Count + 1

# Calcular Puesto Normalizado (Tiempo Final descontando Handicap de Calle comparado con Tiempos Finales)
$sAizFin = TS $aiz.tiempo_final
$sAizNorm = $sAizFin - $difC1
$aizPuestoNorm = ($g1.resultados | Where-Object { (TS $_.tiempo_final) -lt $sAizNorm } | Measure-Object).Count + 1

$RegLugar = $regata.lugar
$g1Hora = $g1.hora_inicio
$g2Hora = $g2.hora_inicio
$g1Gan = $g1.ganador ; $g1GanRaw = $g1.tiempo_ganador_raw ; $g1GanFin = $g1.tiempo_ganador_final
$g2Gan = $g2.ganador ; $g2GanRaw = $g2.tiempo_ganador_raw ; $g2GanFin = $g2.tiempo_ganador_final
# ---------- METEOROLOGIA REAL (Boga Aizburua) ----------
$meteoReal = Get-MeteoByTime $aizHora
$CondVkmh = if ($meteoReal.viento_kmh) { $meteoReal.viento_kmh } else { $cond.viento.velocidad_kmh }
$CondVms = [math]::Round($CondVkmh / 3.6, 1)
$CondVdir = if ($meteoReal.viento_dir) { $meteoReal.viento_dir } else { $cond.viento.direccion }
$CondVdesc = "Fuerza $($cond.viento.fuerza_beaufort) Beaufort"
$CondOla = if ($meteoReal.ola_m) { $meteoReal.ola_m } else { $cond.olas.altura_m }
$CondMar = if ($meteoReal.ola_desc) { $meteoReal.ola_desc } else { "$($cond.olas.tipo) ($($cond.olas.direccion))" }

$CondAire = $cond.temperatura_aire_c
$CondAgua = $cond.temperatura_agua_c
$CondSal = $cond.salinidad_psu
# Densidad calculada dinamicamente: agua salada ~1025 + aprox. 0.4 kg/m3 por PSU extra sobre 35
$CondDens = [math]::Round(1000 + ($CondSal * 0.7) + (0.006 * (1500 - ($CondAgua * 100))), 1)
$CondCoef = $cond.marea.coeficiente
$MareaPM = $cond.marea.pleamar_1
$MareaBM = $cond.marea.bajamar_diurna
$MareaEst = if ($meteoReal.corriente) { $meteoReal.corriente } else { $cond.marea.estado_en_regata }
$dG1 = DiffStr $sg $sa    ; $pG1 = PctStr $sg $sa
$dG2 = DiffStr $s2t $sa   ; $pG2 = PctStr $s2t $sa
$dG3 = DiffStr $s3t $sa   ; $pG3 = PctStr $s3t $sa
$dGm1 = DiffStr $avgG1 $sa ; $pGm1 = PctStr $avgG1 $sa
$dTm1 = DiffStr $avgT1 $sa ; $pTm1 = PctStr $avgT1 $sa

# ---------- ANALISIS RIVALES DIRECTOS PLAYOFF ----------
$rivalesNombres = @("SANTURTZI", "PLENTZIA", "BILBAO", "IBERIA", "ILLUNBE", "PONTEJOS", "FORTUNA")
$resEnLucha = $g1.resultados | Where-Object { $rivalesNombres -contains $_.club -or $_.club -eq "AIZBURUA" } | Sort-Object { [double](TS $_.tiempo_final) }
$puestoEnLucha = 1
$trLucha = [System.Text.StringBuilder]::new()
foreach ($r in $resEnLucha) {
    $cls = if ($r.club -eq "AIZBURUA") { ' class="aiz"' } else { "" }
    
    # Calculos de tiempo y puntos
    $sRaw = TS $r.tiempo_raw
    $sFin = TS $r.tiempo_final
    $difLucha = DiffStr $sFin $sAizFin
    $colorDif = if ($sFin -lt $sAizFin) { "#C0001A" } else { "#145a32" }
    
    # Calculo de puntos de liga (Pool del Grupo 1)
    $pts = ($g1.total_participantes + 1) - $r.puesto
    
    # --- ANALISIS POR LARGOS (RAW) ---
    $sL1_R = TS $r.ciaboga_1
    $sL1_Aiz = TS $aiz.ciaboga_1
    $sL2_R = $sRaw - $sL1_R
    $sL2_Aiz = (TS $aiz.tiempo_raw) - $sL1_Aiz
    
    $difL1 = DiffStr $sL1_R $sL1_Aiz
    $colorL1 = if ($sL1_R -lt $sL1_Aiz) { "#C0001A" } else { "#145a32" }
    $difL2 = DiffStr $sL2_R $sL2_Aiz
    $colorL2 = if ($sL2_R -lt $sL2_Aiz) { "#C0001A" } else { "#145a32" }
    
    # Alerta de zona PlayOFF
    $isPeligro = $r.puesto -ge ($g1.total_participantes - 1)
    $peligroIcon = if ($isPeligro) { " <span title='Puesto de PlayOFF' style='color:#C0001A; cursor:help'>&#9888;</span>" } else { "" }
    
    [void]$trLucha.AppendLine("<tr${cls}><td><strong>$puestoEnLucha&ordm;</strong></td><td>$($r.club)$peligroIcon</td><td>$(ToMMSS $sL1_R) <span style='font-size:9px; color:$colorL1'>($difL1)</span></td><td>$(ToMMSS $sL2_R) <span style='font-size:9px; color:$colorL2'>($difL2)</span></td><td>$(ToMMSS $sRaw)</td><td style='font-size:10px; color:#666'>$($r.handicap)</td><td><strong>$($r.tiempo_final)</strong></td><td style='color:$colorDif'><strong>$difLucha</strong></td><td style='text-align:center; background:rgba(0,0,0,0.03)'><strong>$pts</strong></td></tr>")
    $puestoEnLucha++
}

# --- NARRATIVA DETALLADA DE SITUACION ---
$idxAizLucha = 0; for ($i = 0; $i -lt $resEnLucha.Count; $i++) { if ($resEnLucha[$i].club -eq "AIZBURUA") { $idxAizLucha = $i; break } }
$isAizPeligro = $aizPuesto -ge ($g1.total_participantes - 1)

# Datos para la narrativa
$totalEnLucha = $resEnLucha.Count
$rivEncima = if ($idxAizLucha -gt 0) { $resEnLucha[$idxAizLucha - 1] } else { $null }
$rivDebajo = if ($idxAizLucha -lt ($totalEnLucha - 1)) { $resEnLucha[$idxAizLucha + 1] } else { $null }

# --- DASHBOARD ESTRATEGICO (ESTADO DE SITUACION) ---
$ptsAiz = ($g1.total_participantes + 1) - $aizPuesto
$ptsPeligro = ($g1.total_participantes + 1) - ($g1.total_participantes - 1)
$margenPts = $ptsAiz - $ptsPeligro

# Tiempos de defensa/ataque
$mErrorSec = if ($rivDebajo) { [math]::Abs([double]((TS $rivDebajo.tiempo_final) - $sAizFin)) } else { 0 }
$dCazaSec = if ($rivEncima) { [math]::Abs([double]((TS $rivEncima.tiempo_final) - $sAizFin)) } else { 0 }

# Colores y Textos de Estado
$colorStatus = if ($isAizPeligro) { "#C0001A" } else { "#145a32" }
$bgStatus = if ($isAizPeligro) { "#fff2f2" } else { "#f2fdf5" }
$txtStatus = if ($isAizPeligro) { "ZONA DE PLAYOFF" } else { "FUERA DE PELIGRO" }
$icoStatus = if ($isAizPeligro) { "&#9888;" } else { "&#9989;" }

$situacionHTML = New-Object System.Text.StringBuilder
[void]$situacionHTML.Append("<div style='background:$bgStatus; border:1px solid $colorStatus; ")
[void]$situacionHTML.AppendLine("border-left-width:5px; padding:12px; margin-bottom:15px; border-radius:4px;'>")
[void]$situacionHTML.Append("<div style='color:$colorStatus; font-weight:bold; font-size:15px; ")
[void]$situacionHTML.AppendLine("margin-bottom:2px;'>$icoStatus $txtStatus</div>")
[void]$situacionHTML.AppendLine("<div style='font-size:11px; color:#555'>Situaci&oacute;n actual en el PlayOFF</div>")
[void]$situacionHTML.AppendLine("</div>")

# Ficha de Puntos
[void]$situacionHTML.Append("<div style='padding:10px; border-left:4px solid #1a3a6a; ")
[void]$situacionHTML.AppendLine("background:#f8f9fa; margin-bottom:10px;'>")
[void]$situacionHTML.AppendLine("<div style='font-size:10px; text-transform:uppercase; color:#666; font-weight:bold'>Margen de Puntos</div>")
[void]$situacionHTML.Append("<div style='font-size:18px; font-weight:bold; color:#1a3a6a'>$margenPts Pts ")
[void]$situacionHTML.AppendLine("<span style='font-size:11px; font-weight:normal; color:#888'>sobre el 11&ordm;</span></div>")
[void]$situacionHTML.AppendLine("</div>")

# Ficha de Defensa (Margen de Error)
$txtDefensa = if ($rivDebajo) { "vs <strong>$($rivDebajo.club)</strong>" } else { "Sin amenaza directa" }
[void]$situacionHTML.Append("<div style='padding:10px; border-left:4px solid #555; ")
[void]$situacionHTML.AppendLine("background:#f8f9fa; margin-bottom:10px;'>")
[void]$situacionHTML.AppendLine("<div style='font-size:10px; text-transform:uppercase; color:#666; font-weight:bold'>Defensa (Margen de Error)</div>")
[void]$situacionHTML.Append("<div style='font-size:18px; font-weight:bold; color:#333'>$(ToMMSS $mErrorSec) ")
[void]$situacionHTML.AppendLine("<span style='font-size:11px; font-weight:normal; color:#888'>$txtDefensa</span></div>")
[void]$situacionHTML.AppendLine("</div>")

# Ficha de Ataque (Distancia de Caza)
$txtAtaque = if ($rivEncima) { "vs <strong>$($rivEncima.club)</strong>" } else { "L&iacute;der de zona" }
[void]$situacionHTML.Append("<div style='padding:10px; border-left:4px solid #d35400; ")
[void]$situacionHTML.AppendLine("background:#f8f9fa; margin-bottom:10px;'>")
[void]$situacionHTML.AppendLine("<div style='font-size:10px; text-transform:uppercase; color:#666; font-weight:bold'>Ataque (Distancia de Caza)</div>")
[void]$situacionHTML.Append("<div style='font-size:18px; font-weight:bold; color:#d35400'>$(ToMMSS $dCazaSec) ")
[void]$situacionHTML.AppendLine("<span style='font-size:11px; font-weight:normal; color:#888'>$txtAtaque</span></div>")
[void]$situacionHTML.AppendLine("</div>")

# Nota estrat&eacute;gica din&aacute;mica (Rivales a +/- 2 puntos)
$rivalesCercanos = $resEnLucha | Where-Object { 
    $p = ($g1.total_participantes + 1) - $_.puesto
    [math]::Abs($p - $ptsAiz) -le 2 -and $_.club -ne "AIZBURUA"
} | ForEach-Object { $_.club }
$txtRivales = $rivalesCercanos -join ", "

$notaEstrategica = "<div style='font-size:11px; color:#666; border-top:1px solid #eee; padding-top:10px; margin-top:15px'><strong>Nota Estrat&eacute;gica:</strong> Tus rivales directos son <strong>$txtRivales</strong>. La clave es terminar consistentemente por delante de ellos para blindar la permanencia.</div>"

$situacionLucha = $situacionHTML.ToString()

# ---------- Construccion del HTML ----------
$h = [System.Collections.Generic.List[string]]::new()

$h.Add('<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">')
$h.Add('<title>Informe Aizburua - ' + $RegNombre + '</title>')
$h.Add('<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700;900&display=swap" rel="stylesheet">')
$h.Add('<style>
@media print {
  body { background: #fff !important; -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
  .card, .wrap, .st, .cc, .stitle, tr, .pb, .info-box, .leg, .boat-container { page-break-inside: avoid !important; break-inside: avoid !important; }
  h2, .stitle, .ch { page-break-after: avoid !important; break-after: avoid !important; }
}
:root{--r:#C0001A;--rd:#8B0013;--rl:#f8e6e9;--dk:#1a1a2e;--gy:#5a6170;--lg:#f4f4f8;--bd:#e0e0e8;--wh:#fff;--blu:#1e3a5f;--grn:#1a4a2e}
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:Inter,sans-serif;background:var(--lg);color:var(--dk);font-size:13px;line-height:1.6}
.stitle { 
    font-weight: 900; font-size: 24px; color: #ffffff !important; 
    background: linear-gradient(135deg, #b01c2e 0%, #1a1a2e 100%); 
    padding: 18px 28px; border-radius: 12px; margin: 60px 0 30px 0; 
    border-left: 10px solid #000; border-bottom: 2px solid rgba(255,255,255,0.15);
    box-shadow: 0 10px 25px rgba(0,0,0,0.2); 
    text-transform: uppercase; letter-spacing: 2px;
    text-shadow: 0 2px 4px rgba(0,0,0,0.5);
    display: flex; align-items: center;
}
.card { background: #fff; border-radius: 12px; padding: 28px; box-shadow: 0 12px 30px rgba(0,0,0,0.08); margin-bottom: 35px; border: 1px solid #eee; position: relative; overflow: hidden; }
.ch { display: flex; align-items: center; margin-bottom: 22px; border-bottom: 3px solid #f0f0f0; padding-bottom: 18px; gap: 5px; }
.ch h2 { font-size: 19px; margin: 0; color: #111; font-weight: 800; text-transform: uppercase; letter-spacing: 0.5px; }
.ico { 
    width: 38px; height: 38px; border-radius: 8px; display: flex; align-items: center; justify-content: center; 
    margin-right: 12px; font-weight: 900; font-size: 18px; color: #fff; flex-shrink: 0; box-shadow: 0 4px 8px rgba(0,0,0,0.15);
}
.ico-h { background: #b01c2e; } /* Horario */
.ico-r { background: #0a3d62; } /* Ritmo */
.ico-a { background: #145a32; } /* Alineacion */
.ico-e { background: #6c5ce7; } /* Estadisticas */
.ico-star { background: #f39c12; } /* Recomendaciones */
.ico-1 { background: var(--rd); } /* Grupo 1 */
.ico-2 { background: #444; } /* Grupo 2 */
.ico-c { background: #2980b9; } /* Comparativa */
.ico-p { background: #34495e; } /* Posicionamiento */
.ico-v { background: #1e3a5f; } /* Variables */
.ico-alert { background: #d35400; } /* Alerta */
.hdr{background:linear-gradient(135deg,var(--dk) 0%,#16213e 60%,var(--rd) 100%);color:#fff;padding:40px 60px;display:flex;align-items:center;justify-content:space-between;border-bottom:6px solid var(--r)}
.brand-group{display:flex;align-items:center;gap:20px}
.logo-header{height:75px;width:auto;filter:drop-shadow(0 2px 8px rgba(0,0,0,0.4))}
.ht h1{font-size:22px;font-weight:900;letter-spacing:1px;text-transform:uppercase;color:#fff;line-height:1}
.ht .sub{font-size:10px;color:rgba(255,255,255,.6);letter-spacing:3px;margin-top:5px;font-weight:700}
.hm{text-align:right;border-left:1px solid rgba(255,255,255,.15);padding-left:24px}
.hm .rn{font-size:14px;font-weight:700;color:#fff;line-height:1.4}
.hm .fd{font-size:11px;color:rgba(255,255,255,.65);margin-top:5px}
.hm .hora-badge{display:inline-block;background:rgba(192,0,26,.5);border:1px solid rgba(255,80,80,.6);border-radius:6px;padding:5px 12px;font-size:12px;font-weight:700;color:#fff;margin-top:8px;letter-spacing:1px}
.wrap{max-width:1150px;margin:0 auto;padding:28px 24px}
.g2{display:grid;grid-template-columns:1fr 1fr;gap:18px}
.g4{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}
.gs{display:grid;grid-template-columns:repeat(auto-fit,minmax(115px,1fr));gap:10px}
.st{background:var(--lg);border-radius:8px;padding:10px 12px;border-left:3px solid var(--r)}
.st .lbl{font-size:9px;text-transform:uppercase;letter-spacing:1px;color:var(--gy)}
.st .val{font-size:15px;font-weight:700;color:var(--dk);margin-top:2px}
.st .sbl{font-size:9px;color:var(--gy);margin-top:1px;line-height:1.3}
.pb{border-radius:10px;padding:14px 10px;border:2px solid transparent}
.pb.real{background:var(--r);color:#fff;border-color:var(--rd)}
.pb.norm{background:var(--dk);color:#fff}
.pb.proy{background:var(--blu);color:#fff}
.pb.raw{background:var(--grn);color:#fff}
.pb .pn{font-size:30px;font-weight:900;line-height:1;text-align:center}
.pb .pt{font-size:11px;font-weight:700;text-align:center;margin-top:4px;opacity:.9;line-height:1.3}
.pb .pd{font-size:9px;text-align:center;margin-top:6px;opacity:.7;line-height:1.3;font-style:italic}
.legend-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-top:14px}
.leg{border-radius:6px;padding:9px 11px;font-size:10px;line-height:1.5}
.leg .lt{font-weight:700;font-size:10px;margin-bottom:4px;text-transform:uppercase;letter-spacing:.5px}
.leg.real{background:var(--rl);border-left:3px solid var(--r);color:var(--rd)}
.leg.norm{background:#e8eaf6;border-left:3px solid var(--dk);color:var(--dk)}
.leg.proy{background:#e3eeff;border-left:3px solid var(--blu);color:var(--blu)}
.leg.raw{background:#e8f5e9;border-left:3px solid var(--grn);color:var(--grn)}
table{width:100%;border-collapse:collapse;font-size:11.5px}
thead th{background:var(--r);color:#fff;padding:8px 9px;text-align:left;font-size:9px;letter-spacing:1px;text-transform:uppercase;font-weight:700}
tbody tr:nth-child(even){background:#fafafa}
tbody tr:hover{background:#fff0f2}
tbody td{padding:7px 9px;border-bottom:1px solid #eee;color:var(--dk)}
tr.aiz td{background:var(--rl)!important;font-weight:700;color:var(--rd)!important}
.bp{background:linear-gradient(135deg,#fff0f2,#ffe0e5);border:2px solid var(--r);border-radius:10px;padding:16px 20px}
.bpl{font-size:9px;text-transform:uppercase;letter-spacing:2px;color:var(--r);font-weight:700;margin-bottom:6px}
.diag-box { background: #f8fbff; border: 1px solid #d0e1f9; border-left: 5px solid #1e3a5f; border-radius: 8px; padding: 22px; margin-top: 15px; }
.diag-header { color: #1e3a5f; font-weight: 900; font-size: 13px; text-transform: uppercase; letter-spacing: 1.5px; border-bottom: 2px solid #d0e1f9; padding-bottom: 10px; margin-bottom: 18px; }
.diag-segment { margin-bottom: 15px; line-height: 1.6; }
.diag-label { font-weight: 800; color: #C0001A; text-transform: uppercase; font-size: 10px; display: block; margin-bottom: 4px; letter-spacing: 0.5px; }
.diag-content { font-size: 13.5px; color: #334155; }
.diag-content strong { color: #1e3a5f; }
.cc{background:linear-gradient(135deg,#0f1b35,#1a2a50);border-radius:12px;padding:20px;color:#fff;border-left:5px solid var(--r)}
.cc h2{font-size:10px;text-transform:uppercase;letter-spacing:2px;color:rgba(255,255,255,.6);margin-bottom:8px}
.cnum{font-size:40px;font-weight:900;color:var(--r);line-height:1}
.cverd{display:inline-block;margin-top:8px;padding:4px 12px;border-radius:20px;background:var(--r);color:#fff;font-size:10px;font-weight:700;text-transform:uppercase}
.tt{width:100%;border-collapse:separate;border-spacing:3px}
.tt td{padding:7px 10px;border-radius:5px;text-align:center;font-size:12px;font-weight:600;border:none}
.bn{background:#1a1a2e!important;color:#fff!important;font-weight:700!important}
.bab{background:#d4edfa!important;color:#0a3d62!important}
.est{background:#d5f5e3!important;color:#145a32!important}
.proa-row td{background:var(--rl)!important;color:var(--rd)!important;font-weight:700!important;text-align:center}
.patron-row td{background:var(--r)!important;color:#fff!important;font-weight:700!important;text-align:center}
.bl{display:inline-block;padding:2px 8px;border-radius:20px;font-size:10px;font-weight:700;letter-spacing:1px;margin-right:8px;background:rgba(0,0,0,.2)}
.bdg{display:inline-block;padding:1px 5px;border-radius:3px;font-size:9px;font-weight:700;background:rgba(0,0,0,.15)}
.rl{list-style:none}
.rl li{padding:9px 13px;border-radius:6px;margin-bottom:6px;background:var(--lg);border-left:3px solid var(--r);font-size:12px;line-height:1.6}
.stitle{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:2px;color:var(--gy);margin:24px 0 8px;display:flex;align-items:center;gap:10px}
.stitle::after{content:"";flex:1;height:1px;background:var(--bd)}
.bg1{background:var(--r);color:#fff;display:inline-block;padding:3px 10px;border-radius:20px;font-size:10px;font-weight:700;margin-bottom:10px}
.bg2{background:var(--blu);color:#fff;display:inline-block;padding:3px 10px;border-radius:20px;font-size:10px;font-weight:700;margin-bottom:10px}
.info-box{background:#fffbe6;border:1px solid #f5c842;border-radius:8px;padding:10px 14px;font-size:11px;color:#7a5a00;margin-bottom:12px;line-height:1.6}
.tendencia-buena{color:#0a7a3a;font-weight:600}
.tendencia-mala{color:var(--r);font-weight:600}
.timeline-container{display:flex;justify-content:space-between;align-items:flex-end;min-height:240px;background:linear-gradient(180deg,#f8fafc,#f0f4f8);padding:30px 50px 20px;border-radius:12px;margin:25px 0;border:1px solid #d0dae1;position:relative}
.tl-label-y{position:absolute;left:-38px;top:50%;transform:rotate(-90deg);font-size:10px;color:var(--gy);font-weight:700;text-transform:uppercase;letter-spacing:1px}
.tl-tick{display:flex;flex-direction:column;align-items:center;flex:1}
.tl-bar-group{display:flex;align-items:flex-end;gap:10px;min-height:140px}
.tl-bar-wind{width:28px;background:linear-gradient(180deg,#e8384f,var(--r));border-radius:4px 4px 0 0;transition:all 0.3s}
.tl-bar-wave{width:16px;background:linear-gradient(180deg,#4a90d9,var(--blu));border-radius:3px 3px 0 0}
.tl-time{font-size:13px;font-weight:800;margin-top:12px;color:var(--dk)}
.tl-desc{font-size:10px;color:var(--gy);margin-top:3px;text-align:center;line-height:1.2}
.leg-tl{display:flex;gap:20px;justify-content:center;margin-top:14px}
.leg-item{display:flex;align-items:center;gap:6px;font-size:10px;font-weight:700;text-transform:uppercase}
.dot{width:10px;height:10px;border-radius:2px}
.ftr{background:var(--dk);color:rgba(255,255,255,.5);padding:40px;text-align:center;font-size:10px;border-top:5px solid var(--r);display:flex;flex-direction:column;align-items:center;gap:15px}
.logo-footer{height:45px;width:auto;opacity:0.8;filter:grayscale(1) brightness(3)}
.lane-split { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 20px; margin: 25px 0; }
.lane-box { border-radius: 12px; padding: 22px; position: relative; overflow: hidden; border: 1px solid rgba(0,0,0,0.05); box-shadow: 0 4px 15px rgba(0,0,0,0.03); }
.lane-box::before { content: ""; position: absolute; top: 0; left: 0; width: 6px; height: 100%; }
.lane-1 { background: linear-gradient(135deg, #f8fbff 0%, #ebf4ff 100%); border-top: 1px solid #d0e1f9; }
.lane-1::before { background: #1e3a5f; }
.lane-2 { background: linear-gradient(135deg, #fffafa 0%, #fff1f1 100%); border-top: 1px solid #f9d0d0; }
.lane-2::before { background: #c0001a; }
.lane-tag { position: absolute; top: 10px; right: 15px; font-size: 34px; font-weight: 900; opacity: 0.25; pointer-events: none; }
.lane-title { font-size: 13px; font-weight: 800; text-transform: uppercase; letter-spacing: 1.5px; margin-bottom: 15px; border-bottom: 1px solid rgba(0,0,0,0.05); padding-bottom: 8px; }
.lane-item { font-size: 12px; line-height: 1.6; margin-bottom: 12px; }
.lane-item strong { display: block; font-size: 10px; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 2px; }
.dir-hdr { font-size: 10px; font-weight: 800; background: rgba(0,0,0,0.06); padding: 4px 8px; border-radius: 4px; margin: 12px 0 8px; text-transform: uppercase; letter-spacing: 1px; color: #555; display: inline-block; }
.conc-box { background: #faf9f0; border: 1px solid #e8dfbe; border-radius: 10px; padding: 18px; margin-top: 20px; border-left: 5px solid #d35400; }
.conc-title { font-size: 12px; font-weight: 800; text-transform: uppercase; color: #d35400; letter-spacing: 1.5px; margin-bottom: 8px; display: flex; align-items: center; gap: 8px;}
.r-cell { display: flex; align-items: center; gap: 12px; text-align: left !important; padding: 8px !important; width: fit-content; margin: 0 auto; }
.r-avatar { width: 50px; height: 50px; border-radius: 10px; object-fit: cover; border: 2px solid rgba(255,255,255,0.8); box-shadow: 0 4px 10px rgba(0,0,0,0.15); background: #eee; flex-shrink: 0; }
.r-info { display: flex; flex-direction: column; gap: 2px; }
.r-name { font-weight: 800; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px; }
.r-meta { font-size: 10px; opacity: 0.7; font-weight: 600; }
@media print{body{background:#fff;font-size:11px}.card{box-shadow:none;break-inside:avoid}.hdr,.aiz td,.pb,.bp,.cc,.proa-row td,.patron-row td,.bn,.bab,.est,thead th,.bg1,.bg2,.leg,.lane-box,.conc-box{-webkit-print-color-adjust:exact;print-color-adjust:exact}}
</style></head><body>')

# -------- HEADER con LOGO --------
$h.Add('<div class="hdr">')
$h.Add('  <div class="brand-group">')
if ($logo1Base64) {
    $h.Add('    <img src="data:image/jpeg;base64,' + $logo1Base64 + '" class="logo-header" alt="Aizburua">')
}
else {
    $h.Add('    <div style="width:75px;height:75px;background:var(--r);border-radius:50%;display:flex;align-items:center;justify-content:center;font-weight:900;font-size:24px">A</div>')
}
$h.Add('    <div class="ht"><h1>Aizburua</h1><div class="sub">Informe T&eacute;cnico de Rendimiento &mdash; Liga AKK 11.1</div></div>')
$h.Add('  </div>')
$h.Add('  <div class="hm">')
$h.Add('    <div class="rn">' + $RegNombre + '</div>')
$h.Add('    <div class="fd">' + $RegFecha + ' &nbsp;&mdash;&nbsp; ' + $RegLugar + '</div>')
$h.Add('    <div class="hora-badge">Grupo 1 &mdash; Tanda ' + $aizTanda + ' &mdash; Salida ' + $aizHora + 'h &mdash; Calle ' + $aizCalle + '</div>')
$h.Add('  </div>')
$h.Add('</div>')
$h.Add('<div class="wrap">')

# -------- HORARIO DE LA REGATA --------
$h.Add('<div class="stitle">Horario y Estructura de la Regata</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-h">H</div><h2>Cu&aacute;ndo sali&oacute; cada grupo</h2></div><div class="g2">')

$h.Add('<div class="info-box"><strong>GRUPO 2 &mdash; ' + $g2Hora + 'h (10:30 a 10:39)</strong><br>')
$h.Add('' + $g2.total_participantes + ' clubes, salidas de 2 en 2 cada 2 minutos (Calle 1 y Calle 2 simultaneas)<br>')
$h.Add('Ganador: <strong>' + $g2Gan + '</strong> con ' + $g2GanRaw + ' reales / ' + $g2GanFin + ' con handicap</div>')
$h.Add('<div class="info-box"><strong>GRUPO 1 &mdash; ' + $g1Hora + 'h (11:00 a 11:10) &mdash; Aqui compite Aizburua</strong><br>')
$h.Add('' + $g1.total_participantes + ' clubes, salidas de 2 en 2 cada 2 minutos (Calle 1 y Calle 2 simultaneas)<br>')
$h.Add('Ganador: <strong>' + $g1Gan + '</strong> con ' + $g1GanRaw + ' reales / ' + $g1GanFin + ' con handicap<br>')
$h.Add('<strong>Aizburua: Tanda 1, Calle ' + $aizCalle + ', salida a las ' + $aizHora + 'h</strong></div>')
$h.Add('</div></div>')

# -------- CONDICIONES --------
$h.Add('<div class="stitle">Condiciones del Campo el Dia de la Regata</div>')
$h.Add('<div class="card" style="border-left:4px solid #1e3a5f"><div class="ch"><div class="ico ico-v">V</div><h2 style="color:#1e3a5f;text-transform:uppercase;letter-spacing:1px;font-weight:900">Variables Atmosfericas y Campo Nautico</h2></div>')

# Geometría Principal y Marea (destacado arriba)
$h.Add('<div class="cc" style="margin-bottom:20px;border-left:4px solid var(--r);display:grid;grid-template-columns: 1.8fr 1fr;gap:20px;align-items:center;background:linear-gradient(90deg, #1e3a5f, #152945)">')
$h.Add('<div><h2 style="color:#a8c0e0;font-size:11px;letter-spacing:2px;margin-bottom:12px;text-transform:uppercase">Geometria tactica del Campo (Muelle &harr; Mar)</h2>')
$h.Add('<div style="font-size:14px;line-height:1.5;color:#e2e8f0;padding-right:15px">')
$h.Add('<strong style="color:#fff">Distancia:</strong> ' + $regata.distancia_m + 'm (2 largos de ' + [math]::Round($regata.distancia_m / 2) + 'm, 1 ciaboga)<br>')
$h.Add('<strong style="color:#fff">Eje de Boga:</strong> ' + $cond.geometria.eje + '<br>')
$h.Add('<strong style="color:#fff">Calle 1 (Blanca):</strong> ' + $cond.geometria.calle1.posicion + ' (M&aacute;s corriente)<br>')
$h.Add('<strong style="color:#fff">Calle 2 (Roja):</strong> ' + $cond.geometria.calle2.posicion + ' (M&aacute;s protegida)<br>')
$vDir = $cond.viento.direccion
$vKmh = $cond.viento.velocidad_kmh
$oDir = $cond.olas.direccion
$oAlt = $cond.olas.altura_m
$h.Add('<strong style="color:#fff">Largo 1 (IDA &rarr; NNW):</strong> Muelle &rarr; San Inazio. Viento ' + $vDir + ' (' + $vKmh + ' km/h) de trav&eacute;s por estribor. Ola ' + $oDir + ' (' + $oAlt + 'm) de amura babor. Corriente a favor.<br>')
$h.Add('<strong style="color:#fff">Largo 2 (VUELTA &rarr; SSE):</strong> San Inazio &rarr; Muelle. Viento ' + $vDir + ' (' + $vKmh + ' km/h) de aleta babor. Ola ' + $oDir + ' (' + $oAlt + 'm) de popa. <span style="color:#ff6b6b;font-weight:700">Corriente EN CONTRA.</span></div></div>')
$coefCtx = "MAREA MUERTA &mdash; Corriente m&iacute;nima. Campo m&aacute;s neutro."
if ($CondCoef -ge 90) { $coefCtx = 'MAREA VIVA &mdash; Corrientes m&aacute;ximas. Muy adversas a la vuelta.' }
elseif ($CondCoef -ge 60) { $coefCtx = 'MAREA MODERADA-ALTA &mdash; Corriente considerable. Penaliza la vuelta.' }
elseif ($CondCoef -ge 30) { $coefCtx = 'MAREA MEDIA &mdash; Corriente moderada. Impacto controlable.' }

$h.Add('<div style="text-align:right;background:rgba(0,0,0,.25);padding:18px 22px;border-radius:10px;border:1px solid rgba(255,255,255,.05);box-shadow:inset 0 2px 10px rgba(0,0,0,.2)">')
$h.Add('<h2 style="font-size:10px;color:#a8c0e0;letter-spacing:2px;margin-bottom:2px;text-transform:uppercase">Coeficiente Marea <span style="font-weight:400;opacity:.6">(escala 0&ndash;120)</span></h2>')
$h.Add('<div style="font-size:9px;color:#64748b;margin-bottom:6px">0 = Mar muerta &nbsp;|&nbsp; 60 = Media &nbsp;|&nbsp; 120 = M&aacute;xima viva</div>')
$h.Add('<div class="cnum" style="font-size:42px;line-height:1;margin-bottom:8px;color:#fff;text-shadow:0 2px 4px rgba(0,0,0,.5);font-weight:900">' + $cond.marea.coeficiente + '</div>')
    
$mEstado = $cond.marea.estado_en_regata
if ($mEstado -like "*vaciante*") { $mEstado = "Marea Bajando (Corriente hacia el Mar)" }
    
$h.Add('<div class="cverd" style="font-size:9px;margin-bottom:10px;background:var(--r);color:#fff;display:inline-block;padding:3px 10px;border-radius:4px;font-weight:700;letter-spacing:1px">' + $mEstado.ToUpper() + '</div><br>')
$h.Add('<div style="font-size:10px;text-align:left;color:#94a3b8;line-height:1.5;border-left:2px solid rgba(255,255,255,.2);padding-left:10px;margin-top:6px">')
$h.Add('<strong style="color:#cbd5e1">' + $coefCtx + '</strong><br>')
$h.Add('Bajamar: <strong style="color:#e2e8f0">' + $cond.marea.bajamar_diurna + 'h</strong> &mdash; Al bajar la marea, el agua de la r&iacute;a sale hacia el mar, creando una corriente que ayuda a la IDA pero dificulta enormemente la VUELTA al muelle.</div></div>')
$h.Add('</div>')
    
# --- DETECCION DE MODALIDAD Y DINAMIZACION DE CALLES ---
$modalidad = "calles"
if ($regata.PSObject.Properties['modalidad']) {
    $modalidad = $regata.modalidad
}
    
if ($modalidad -eq "contrareloj") {
    $h.Add('<div class="stitle">Evolucion Tactica del Campo (Contrareloj)</div>')
    $h.Add('<p style="font-size:12px; color:#555; margin-bottom:15px; margin-top:-20px;">Analisis de la variabilidad del campo de regatas a lo largo del tiempo. En modalidad C.R., el factor determinante es el cambio de las condiciones entre el primer y ultimo bote.</p>')
    $h.Add('<div class="lane-box lane-1" style="border-left:6px solid #1e3a5f">')
    $h.Add('<div class="lane-title" style="color:#1e3a5f">Trazada Unica - Analisis Temporal</div>')
    $h.Add('<div class="dir-hdr" style="color:#1e3a5f; background:#e6f0ff">&rarr; LARGO 1 (IDA)</div>')
    $ayuda = "frena"
    if ($cond.marea.estado_en_regata -like "*vaciante*") { $ayuda = "ayuda" }
    $h.Add('<div class="lane-item"><strong>Inercia de Salida</strong>Campo influenciado por ' + $cond.marea.estado_en_regata + '. La corriente ' + $ayuda + ' el avance inicial hacia la baliza exterior.</div>')
    $h.Add('<div class="dir-hdr" style="color:#c0001a; background:#fbeeee">&larr; LARGO 2 (VUELTA)</div>')
    $h.Add('<div class="lane-item"><strong>Resistencia del Retorno</strong>Impacto directo del viento ' + $cond.viento.direccion + ' y la ola de ' + $cond.olas.direccion + ' sobre la fatiga acumulada.</div>')
    $h.Add('</div>')
}
else {
    $h.Add('<div class="stitle">Micro-Topografia Nautica por Calles (Ida vs Vuelta)</div>')
    $h.Add('<p style="font-size:12px; color:#555; margin-bottom:15px; margin-top:5px; padding-left:2px;">Desglose del impacto de la hidrodin&aacute;mica dependiente del sentido de la boga. Las condiciones asim&eacute;tricas penalizan o benefician a cada calle seg&uacute;n se salga hacia alta mar o retroceda a la r&iacute;a.</p>')
    $h.Add('<div class="lane-split">')
        
    # Iterar sobre las calles definidas en la geometria
    $callesDinas = $cond.geometria.PSObject.Properties | Where-Object { $_.Name -like "calle*" }
    foreach ($prop in $callesDinas) {
        $cId = $prop.Name.Replace("calle", "")
        $cData = $prop.Value
        $cStyle = "lane-1" ; $cColor = "#1e3a5f"
        if ([int]$cId % 2 -eq 0) { $cStyle = "lane-2" ; $cColor = "#c0001a" }
            
        # Inferencia de impacto segun posicion
        $pos = $cData.posicion.ToLower()
        $txtIda = ""
        $txtVue = ""
        $vDir = $cond.viento.direccion
            
        if ($pos -match "rio|canal|exterior") {
            $txtIda = "<strong style='display:block;margin-bottom:4px;color:#1e3a5f'>CORRIENTE A FAVOR (M&Aacute;XIMA)</strong>Al coincidir con el eje central de desag&uuml;e del r&iacute;o en marea bajando, ofrece el mayor empuje `"gratuito`" al barco de todo el campo de regatas.<br><br><strong style='display:block;margin-bottom:4px;color:#1e3a5f'>VIENTO ($vDir) Y OLA</strong><br>El abatimiento de brisa lateral es f&aacute;cilmente mitigado por la alta velocidad de avance impulsada por la marea. Ola muy limpia."
            $txtVue = "<strong style='display:block;margin-bottom:4px;color:#c0001a'>CORRIENTE EN CONTRA (EL `"MURO`")</strong>El canal principal eyecta contra la proa el flujo de agua m&aacute;s denso y r&aacute;pido imaginable. Exige una enorme entrega muscular y frena dr&aacute;sticamente el deslizamiento (ca&iacute;da de MpP).<br><br><strong style='display:block;margin-bottom:4px;color:#c0001a'>EMPOPADA FALLIDA</strong><br>Aunque el viento de $vDir acaricie la aleta y una ola sana cruce la popa, la extrema succi&oacute;n de la marea te roba la velocidad necesaria para montarse sostenidamente encima de las crestas; asfixia inevitable."
        }
        else {
            $txtIda = "<strong style='display:block;margin-bottom:4px;color:#1e3a5f'>CORRIENTE A FAVOR (REDUCIDA)</strong>Al estar pegada a la orilla rocosa y la playa, la fricci&oacute;n perimetral ralentiza el paso del agua de r&iacute;a frente a la zona de alta profundidad. Menos ayuda, boga m&aacute;s lenta s&oacute;lo hacia afuera.<br><br><strong style='display:block;margin-bottom:4px;color:#1e3a5f'>VIENTO ($vDir) Y OLA</strong><br>Mar de fondo parcialmente encrespado por rotura costera temprana. Turbulencia de aire procedente de contorno portuario."
            $txtVue = "<strong style='display:block;margin-bottom:4px;color:#c0001a'>CORRIENTE EN CONTRA (MITIGADA)</strong>El temido `"muro`" del centro del canal es francamente m&aacute;s d&eacute;bil y vadeable bajo la ribera rocosa. Permite mantener el golpe rotacional en cotas sostenibles.<br><br><strong style='display:block;margin-bottom:4px;color:#c0001a'>EMPOPADA APROVECHABLE (SURF EFECTIVO)</strong><br>De cara a la Vuelta, sin ese rozamiento f&oacute;sil extremo desde proa, la tripulaci&oacute;n s&iacute; empalma el planeo con el golpe de empuje cruzado de $vDir sobre la espalda junto a la estela de la onda."
        }

        $h.Add('<div class="lane-box ' + $cStyle + '"><div class="lane-tag">C' + $cId + '</div>')
        $h.Add('<div class="lane-title" style="color:' + $cColor + '">Calle ' + $cId + ' (' + $cData.color + ') - ' + $cData.posicion + '</div>')
            
        $h.Add('<div class="dir-hdr" style="color:#1e3a5f; background:#e6f0ff">&rarr; LARGO 1 (IDA: HACIA EL ABRA)</div>')
        $h.Add('<div class="lane-item">' + $txtIda + '</div>')
            
        $h.Add('<div class="dir-hdr" style="color:#c0001a; background:#fbeeee">&larr; LARGO 2 (VUELTA: AL MUELLE)</div>')
        $h.Add('<div class="lane-item">' + $txtVue + '</div>')
        $h.Add('</div>')
    }
    $h.Add('</div>')
}
    
# Conclusion Táctica Dinámica
$h.Add('<div class="conc-box">')
$h.Add('<div class="conc-title">&#9875; CONCLUSI&Oacute;N T&Aacute;CTICA DEL CAMPO (' + $regata.lugar.ToUpper() + ')</div>')
$h.Add('<div style="font-size:13px; line-height:1.6; color:#333">')
$h.Add('<p style="margin-bottom:10px">En resumen, bajo un r&eacute;gimen de <strong>' + $cond.marea.estado_en_regata + '</strong>, el rendimiento hidrodin&aacute;mico real de las calles dibuja dos realidades antag&oacute;nicas y asim&eacute;tricas seg&uacute;n qu&eacute; rumbo toques:</p>')
$h.Add('<ul style="margin-left:20px; margin-bottom:12px; color:#444">')
    
$peorCIdVal = 1
if ($peorCalleId) { $peorCIdVal = $peorCalleId }
$mejorCIdVal = 2
if ($mejorCalleId) { $mejorCIdVal = $mejorCalleId }
    
$h.Add('<li style="margin-bottom:6px">Para la <strong>IDA</strong> (Sentido Alta Mar): La <strong>Calle ' + $peorCIdVal + '</strong> es netamente m&aacute;s r&aacute;pida porque discurre por el torrente central de evacuaci&oacute;n hidrogr&aacute;fica. Aizburua lleg&oacute; a virar a escasos segundos reales del L&iacute;der de Grupo navegando as&iacute;.</li>')
$h.Add('<li style="margin-bottom:6px">Para la <strong>VUELTA</strong> (Sentido Base de Muelle): La <strong>Calle ' + $mejorCIdVal + '</strong> es inmensamente superior por pura amortiguaci&oacute;n isob&aacute;rica orillada. Los l&iacute;deres usaron esta v&iacute;a blindada protegi&eacute;ndose colosalmente mientras surfaban.</li>')
$h.Add('</ul>')
$h.Add('<p style="font-weight:700; color:#1a1a2e; padding-top:6px; border-top:1px dashed #dca;">Veredicto Final Total: La balanza de ingenier&iacute;a n&aacute;utica corona a la Calle ' + $mejorCIdVal + ' en el c&oacute;mputo global. Y esto se cristaliza porque el castigo de p&eacute;rdida volum&eacute;trica (segundos esfumados del crono de Vuelta) escalando infructuosamente el "muro f&iacute;sico" excede con aplastante margen est&aacute;ndar la d&eacute;bil inercia y renta que la riada facilitatoria regal&oacute; al ir.</p>')
$h.Add('</div></div>')


# Linea de Tiempo Atmosférica (Evolución de Viento y Mar)
if ($cond.evolucion_meteo) {
    $h.Add('<div style="margin:30px 0"><div class="bpl" style="color:var(--blu);margin-bottom:10px">Evolucion Atmosferica (10:30 &rarr; 11:30)</div>')
    $h.Add('<div class="timeline-container"><div class="tl-label-y">Intensidad</div>')
    # Flechas FROM: apuntan DESDE donde viene el viento (convenci&oacute;n meteorol&oacute;gica)
    $dirArrows = @{ 'N' = '&darr;'; 'NE' = '&swarr;'; 'E' = '&larr;'; 'SE' = '&nwarr;'; 'S' = '&uarr;'; 'SW' = '&nearr;'; 'W' = '&rarr;'; 'NW' = '&searr;'; 'NNE' = '&swarr;'; 'NNW' = '&searr;'; 'ENE' = '&larr;'; 'ESE' = '&nwarr;'; 'SSE' = '&nwarr;'; 'SSW' = '&nearr;'; 'WNW' = '&rarr;'; 'WSW' = '&rarr;' }
    foreach ($m in $cond.evolucion_meteo) {
        $wH = [math]::Max($m.viento_kmh * 5, 12)
        $oH = [math]::Max($m.ola_m * 65, 12)
        
        $wDir = ""
        if ($m.viento_dir -and $dirArrows[$m.viento_dir]) { $wDir = $dirArrows[$m.viento_dir] }
        
        $wDirLabel = ""
        if ($m.viento_dir) { $wDirLabel = $m.viento_dir }
        $h.Add("<div class='tl-tick'><div class='tl-bar-group'>")
        $h.Add("<div style='display:flex;flex-direction:column;align-items:center'><span style='font-size:16px;color:var(--r);margin-bottom:1px'>$wDir</span><span style='font-size:11px;font-weight:800;color:var(--r)'>$($m.viento_kmh)</span><span style='font-size:8px;color:#666;margin-bottom:3px'>$wDirLabel</span><div class='tl-bar-wind' style='height:${wH}px'></div></div>")
        $h.Add("<div style='display:flex;flex-direction:column;align-items:center'><span style='font-size:11px;font-weight:800;color:var(--blu);margin-bottom:3px'>$($m.ola_m)m</span><div class='tl-bar-wave' style='height:${oH}px'></div></div>")
        $h.Add("</div><div class='tl-time'>$($m.hora)h</div><div class='tl-desc'>$($m.desc)</div></div>")
    }
    $h.Add('</div><div class="leg-tl">')
    $h.Add('<div class="leg-item"><div class="dot" style="background:var(--r)"></div> Viento (km/h)</div>')
    $h.Add('<div class="leg-item"><div class="dot" style="background:var(--blu)"></div> Ola (m)</div>')
    $h.Add('</div></div>')

    # Grid de 5 variables atmosfericas (debajo del timeline)
    $h.Add('<div class="gs" style="border-top:1px solid var(--bd);padding-top:20px;margin-top:5px">')
    $h.Add('<div class="st"><div class="lbl" style="color:#64748b;font-weight:700;font-size:10px;text-transform:uppercase;letter-spacing:1px">Term&oacute;metr&iacute;a Aire / Agua</div><div class="val" style="font-size:18px">' + $CondAire + '&deg;C / ' + $CondAgua + '&deg;C</div><div class="sbl">Superfice y dique Arriluze</div></div>')
    $h.Add('<div class="st"><div class="lbl" style="color:#64748b;font-weight:700;font-size:10px;text-transform:uppercase;letter-spacing:1px">Densidad del Agua</div><div class="val" style="font-size:18px">' + $CondDens + ' kg/m&sup3;</div><div class="sbl">Salinidad ' + $CondSal + ' PSU &mdash; agua +densa que dulce</div></div>')
    $h.Add('<div class="st"><div class="lbl" style="color:#64748b;font-weight:700;font-size:10px;text-transform:uppercase;letter-spacing:1px">Viento</div><div class="val" style="font-size:18px">' + $CondVkmh + ' km/h (' + $CondVms + ' m/s)</div><div class="sbl">' + $CondVdir + ' &mdash; ' + $CondVdesc + '</div></div>')
    $h.Add('<div class="st"><div class="lbl" style="color:#64748b;font-weight:700;font-size:10px;text-transform:uppercase;letter-spacing:1px">Estado del Mar</div><div class="val" style="font-size:13px;color:#1e3a5f;line-height:1.2">' + $CondOla + 'm &mdash; ' + $CondMar + '</div><div class="sbl">Ola NW dificulta la vuelta al muelle</div></div>')
    $h.Add('<div class="st"><div class="lbl" style="color:#64748b;font-weight:700;font-size:10px;text-transform:uppercase;letter-spacing:1px">Horario Mareas</div><div class="val" style="font-size:14px;color:#1e3a5f">PM ' + $MareaPM + 'h / BM ' + $MareaBM + 'h</div><div class="sbl">' + $MareaEst + '</div></div>')
    $h.Add('</div>')
}

# -------- DASHBOARD con leyenda --------
$h.Add('<div class="stitle">Posicionamiento de Aizburua &mdash; 4 formas de leer el resultado</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-p">P</div><h2>Que significan estos numeros</h2></div>')
$h.Add('<div class="g4">')
$h.Add('<div class="pb real"><div class="pn">' + $aizPuesto + '&ordm;/' + $aizTotal + '</div><div class="pt">Puesto Oficial</div><div class="pd">El del marcador. Con el handicap que asigna la liga a cada club.</div></div>')
$h.Add('<div class="pb norm"><div class="pn">' + $aizPuestoNorm + '&ordm;/' + $aizTotal + '</div><div class="pt">Sin Desventaja de Calle</div><div class="pd">Midiendo el "tiempo oficial" como si hubieran remado en aguas neutras (sin penalizaci&oacute;n por Calle ' + $aizCalle + ').</div></div>')
$h.Add('<div class="pb proy"><div class="pn">' + $puestoProy + '&ordm;/' + $aizTotal + '</div><div class="pt">Potencia en Calle Mas Rapida</div><div class="pd">Midiendo el "tiempo raw puro", si hubieran corrido sin handicap en la calle ganadora.</div></div>')
$h.Add('<div class="pb raw"><div class="pn">' + $aizPuestoRaw + '&ordm;/' + $aizTotal + '</div><div class="pt">Sin Handicap de Liga</div><div class="pd">El puesto que habr&iacute;an ocupado ignorando los handicaps reglamentarios, a potencia bruta en su calle real.</div></div>')
$h.Add('</div>')
$h.Add('<div class="legend-grid">')
$h.Add('<div class="leg real"><div class="lt">Puesto Oficial</div>Resultado en el acta de la regata. El handicap iguala clubes de distinto nivel para que la puntuacion de liga sea equilibrada.</div>')
$h.Add('<div class="leg norm"><div class="lt">Sin Desventaja de Calle</div>Las calles no son iguales: la corriente y el viento favorecen unas sobre otras. Este numero estima donde habria quedado Aizburua si el sorteo hubiera sido neutro.</div>')
$h.Add('<div class="leg proy"><div class="lt">En la Calle Mas Rapida</div>Simulacion: si Aizburua hubiera salido desde la calle con mejores condiciones (Calle ' + $mejorCalleId + ' en esta regata), el tiempo estimado seria <strong>' + $tProyFmt + '</strong>.</div>')
$h.Add('<div class="leg raw"><div class="lt">Sin Handicap de Liga</div>La liga asigna ventajas de tiempo a clubes de menor nivel historico. Sin ese ajuste, este es el puesto por tiempo remado puro.</div>')
$h.Add('</div></div>')

# -------- GRUPO 1 --------
$h.Add('<div class="stitle">Clasificaci&oacute;n Completa &mdash; Grupo 1 (' + $g1Hora + 'h) &mdash; Aizburua compite aqu&iacute;</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-1">1</div><h2>' + $g1.total_participantes + ' participantes &mdash; Ganador: ' + $g1Gan + ' &mdash; Salida primera tanda: ' + $g1Hora + 'h</h2></div>')

$h.Add('<span class="bg1">GRUPO 1 &mdash; ' + $g1Hora + 'h</span>')
$h.Add('<table><thead><tr><th>Pos</th><th>Club</th><th>Hora Salida</th><th>Tanda / Calle</th><th>1a Ciaboga</th><th>Tiempo Real Remado</th><th>Handicap de Liga</th><th>Tiempo Oficial</th></tr></thead><tbody>')
$h.Add($trG1.ToString())
$h.Add('</tbody></table>')
$h.Add('<div style="margin-top:10px;font-size:11px;color:var(--gy)">Media del grupo (tiempo real): <strong>' + $mediaG1Fmt + '</strong> &nbsp;|&nbsp; Media Tanda ' + $aizTanda + ' de Aizburua (tiempo real): <strong>' + $mediaT1Fmt + '</strong></div>')
$h.Add('<div class="info-box" style="margin-top:10px;font-size:10px"><strong>Como leer esta tabla:</strong> "Tiempo Real Remado" = segundos reales en el agua, la medida justa para comparar rendimiento fisico. "Tiempo Oficial" = tiempo real MENOS el handicap de la liga = el que cuenta para la puntuacion.</div>')
$h.Add('</div>')

# -------- GRUPO 2 --------
$h.Add('<div class="stitle">Clasificaci&oacute;n Completa &mdash; Grupo 2 (' + $g2Hora + 'h)</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-2">2</div><h2>' + $g2.total_participantes + ' participantes &mdash; Ganador: ' + $g2Gan + ' &mdash; Salida primera tanda: ' + $g2Hora + 'h</h2></div>')

$h.Add('<span class="bg2">GRUPO 2 &mdash; ' + $g2Hora + 'h</span>')
$h.Add('<table><thead><tr><th>Pos</th><th>Club</th><th>Hora Salida</th><th>Tanda / Calle</th><th>1a Ciaboga</th><th>Tiempo Real Remado</th><th>Handicap de Liga</th><th>Tiempo Oficial</th></tr></thead><tbody>')
$h.Add($trG2.ToString())
$h.Add('</tbody></table></div>')

$h.Add('</div>') # Cierra la primera columna del G2 de alineación

# -------- COMPARATIVA DE RENDIMIENTO --------
$h.Add('<div class="stitle">Cu&aacute;nto le sac&oacute; cada rival a Aizburua (usando tiempo real remado)</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-c">C</div><h2>Aizburua vs el Ganador, el Podio y la Media del Grupo 1</h2></div>')

$h.Add('<div class="info-box">Se compara el <strong>tiempo real remado</strong> (sin handicap) para medir el rendimiento fisico de cada trainera. La columna <strong>"vs Aizburua"</strong> muestra la diferencia de tiempo: los valores <strong>negativos (-)</strong> indican que el club fue m&aacute;s r&aacute;pido que Aizburua, y los <strong>positivos (+)</strong> que fue m&aacute;s lento.</div>')
$h.Add('<table><thead><tr><th>Club</th><th>Hora Salida</th><th>1a Ciaboga (dif.)</th><th>Tiempo Real</th><th>vs Aizburua</th><th>En porcentaje</th><th>Nota</th></tr></thead><tbody>')
$h.Add('<tr class="aiz"><td><strong>AIZBURUA</strong> &mdash; T' + $aizTanda + ' C' + $aizCalle + '</td><td>' + $aizHora + 'h</td><td>' + $aizCiab + '</td><td><strong>' + $aizRaw + '</strong></td><td>referencia</td><td>---</td><td>Oficial: ' + $aizFin + '</td></tr>')
$h.Add('<tr><td>1&ordm; <strong>' + (ConvertTo-HtmlEntity $t1Nom) + '</strong> (ganador)</td><td>' + $t1Hora + 'h</td><td>' + $t1Ciab + ' <span style="font-size:10px; color:#C0001A">(' + $dCiaG1 + ')</span></td><td>' + $t1Raw + '</td><td style="color:#C0001A"><strong>' + $dG1 + '</strong></td><td style="color:#C0001A">' + $pG1 + '</td><td>T' + $t1T + ' C' + $t1C + '</td></tr>')
$h.Add('<tr><td>2&ordm; <strong>' + (ConvertTo-HtmlEntity $t2Nom) + '</strong></td><td>' + $t2Hora + 'h</td><td>' + $t2Ciab + ' <span style="font-size:10px; color:#C0001A">(' + $dCiaG2 + ')</span></td><td>' + $t2Raw + '</td><td style="color:#C0001A"><strong>' + $dG2 + '</strong></td><td style="color:#C0001A">' + $pG2 + '</td><td>T' + $t2T + ' C' + $t2C + '</td></tr>')
$h.Add('<tr><td>3&ordm; <strong>' + (ConvertTo-HtmlEntity $t3Nom) + '</strong></td><td>' + $t3Hora + 'h</td><td>' + $t3Ciab + ' <span style="font-size:10px; color:#C0001A">(' + $dCiaG3 + ')</span></td><td>' + $t3Raw + '</td><td style="color:#C0001A"><strong>' + $dG3 + '</strong></td><td style="color:#C0001A">' + $pG3 + '</td><td>T' + $t3T + ' C' + $t3C + '</td></tr>')
$h.Add('<tr style="background:#f0f8ff"><td><em>Media del Grupo 1</em></td><td>---</td><td>' + $mediaCiaG1Fmt + ' <span style="font-size:10px; color:#1a3a6a">(' + $dCiaMediaG1 + ')</span></td><td><em>' + $mediaG1Fmt + '</em></td><td style="color:#1a3a6a"><strong>' + $dGm1 + '</strong></td><td style="color:#1a3a6a">' + $pGm1 + '</td><td>12 participantes</td></tr>')
$h.Add('<tr style="background:#f0f8ff"><td><em>Media Tanda ' + $aizTanda + ' (misma hora)</em></td><td>' + $aizHora + 'h</td><td>' + $mediaCiaT1Fmt + ' <span style="font-size:10px; color:#1a3a6a">(' + $dCiaMediaT1 + ')</span></td><td><em>' + $mediaT1Fmt + '</em></td><td style="color:#1a3a6a"><strong>' + $dTm1 + '</strong></td><td style="color:#1a3a6a">' + $pTm1 + '</td><td>Misma franja horaria</td></tr>')
$h.Add('</tbody></table></div>')

# -------- SECCION RIVALES DIRECTOS PLAYOFF --------
$h.Add('<div class="stitle">Lucha por la Permanencia &mdash; Objetivo PlayOFF</div>')
$h.Add('<div class="card" style="border-top: 5px solid #d35400"><div class="ch"><div class="ico ico-alert" style="background:#d35400">P</div><h2>Rendimiento vs Rivales Directos</h2></div>')
$h.Add('<div class="g2" style="grid-template-columns: 1.8fr 1fr; gap:30px; align-items: start">')
$h.Add('<div><p style="margin-bottom:15px; font-size:12px; color:#555">An&aacute;lisis exhaustivo frente a rivales directos. La secuencia muestra el tiempo real (L1+L2), el handicap aplicado y el resultado oficial final.</p>')
$h.Add('<table style="font-size:12px"><thead><tr style="background:#d35400"><th>#</th><th>Club</th><th>L1 ida (dif)</th><th>L2 vta (dif)</th><th>T. Real</th><th>Hcp</th><th>T. Final</th><th>vs AIZ</th><th>Pts</th></tr></thead><tbody>')
$h.Add($trLucha.ToString())
$h.Add('</tbody></table></div>')
$h.Add('<div style="min-width: 300px"><div class="bpl" style="color:#d35400; margin-bottom:12px">ESTADO DE SITUACI&Oacute;N</div>' + $situacionLucha + $notaEstrategica + '</div>')
$h.Add('</div></div>')

# -------- ANALISIS DE CONDICIONES POR HORA Y CALLE --------
$h.Add('<div class="stitle">An&aacute;lisis de Tiempos por Tanda y Calle (Nivel vs Condiciones)</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-alert">!</div><h2>Evoluci&oacute;n de los promedios durante el Grupo 1 (11:00h a 11:25h aprox.)</h2></div>')

$h.Add('<div class="info-box" style="color:#0a3d62;background:#e3eeff;border-color:#bbd2f5"><strong>Contexto importante sobre las tandas:</strong> El orden de salida esta dictado por las clasificaciones (los peores primero, los mejores al final). Por tanto, es natural que las marcas mejoren tanda a tanda. <strong>Solo si las tandas finales son MAS LENTAS podemos afirmar que las condiciones del campo empeoraron.</strong><br><br>' + $tendenciaGlobal + '</div>')
$h.Add('<table><thead><tr><th>Franja Horaria</th><th>Hora de Salida</th><th>Tiempo Medio Real (Vel.)</th><th>Analisis (considerando que los cabezas de serie salen despues)</th></tr></thead><tbody>')
$h.Add($tandaRows -join "`n")
$h.Add('</tbody></table>')
$h.Add('<div style="margin-top:16px"><div class="bpl" style="margin-bottom:8px">IMPACTO DE LAS CALLES EN EL GRUPO 1</div>')
$h.Add('<table><thead><tr><th>Calle</th><th>Tiempo Medio Real de todos los clubs</th><th>Ventaja o Desventaja vs media</th><th>Veredicto</th></tr></thead><tbody>')

foreach ($cid in ($lanesData.Keys | Sort-Object)) {
    $lane = $lanesData[$cid]
    $rowCls = ""
    if ($aizCalle -eq $cid) { $rowCls = ' class="aiz"' }
    
    $veredicto = "Neutral"
    if ($lane.dif -gt 2) { $veredicto = "M&aacute;s lenta" }
    elseif ($lane.dif -lt -2) { $veredicto = "M&aacute;s r&aacute;pida" }
    
    $h.Add('<tr' + $rowCls + '><td><strong>Calle ' + $cid + '</strong></td><td>' + $lane.fmt + '</td><td style="color:#C0001A">' + $lane.difStr + ' sobre la media del grupo</td><td>' + $veredicto + '</td></tr>')
}
$h.Add('</tbody></table>')
$h.Add('<div style="margin-top:10px;padding:12px;background:var(--rl);border-radius:6px;font-size:12px;color:var(--rd)"><strong>Resumen del impacto en Aizburua:</strong> ' + $veredictoCalles + '. Aizburua sali&oacute; desde Calle ' + $aizCalle + '. Simulando la salida desde Calle ' + $mejorCalleId + ': tiempo estimado <strong>' + $tProyFmt + '</strong> &rarr; <strong>' + $puestoProy + '&ordm; puesto</strong> en lugar de ' + $aizPuesto + '&ordm;.</div>')
$h.Add('</div></div>')


# -------- ANALISIS DE CALLE + BREAKING POINT --------
$h.Add('<div class="g2" style="margin-top:18px">')
$h.Add('<div class="cc"><h2>La Calle Que le Toco a Aizburua</h2><div class="cnum">Calle ' + $aizCalle + '</div>')
$h.Add('<div style="margin-top:10px;font-size:12px;color:rgba(255,255,255,.85);line-height:1.9">')
    
foreach ($cid in ($lanesData.Keys | Sort-Object)) {
    $lane = $lanesData[$cid]
    $h.Add('Tiempo medio Calle ' + $cid + ': <strong>' + $lane.fmt + '</strong><br>')
}
    
$aizLane = $lanesData[$aizCalle]
$h.Add('La Calle ' + $aizCalle + ' fue <strong style="color:#ff9999">' + $aizLane.difStr + '</strong> mas lenta que la media.<br>')
$h.Add('Tiempo estimado en Calle ' + $mejorCalleId + ': <strong style="color:#ff9999">' + $tProyFmt + '</strong><br>')
$h.Add('Puesto estimado: <strong style="color:#ff9999">' + $puestoProy + '&ordm; de ' + $aizTotal + '</strong></div>')
    
$verTexto = "Calle Penalizada (" + $aizLane.difStr + ")"
if ($aizLane.dif -lt -1) { $verTexto = "Calle Favorable (" + $aizLane.difStr + ")" }
elseif ($aizLane.dif -le 1) { $verTexto = "Calle Neutra (" + $aizLane.difStr + ")" }
    
$h.Add('<div class="cverd">' + $verTexto + '</div>')
    
$mTextExplicativo = $cond.marea.estado_en_regata
if ($mTextExplicativo -like "*vaciante*") { $mTextExplicativo = "Marea Bajando (Corriente M&aacute;xima)" }
    
$h.Add('<div style="margin-top:12px;font-size:10px;color:rgba(255,255,255,.6);line-height:1.5">')
$h.Add('<strong>Causa t&eacute;cnica:</strong> ' + $mTextExplicativo + '. El impacto de la calle depende de su posicion (Rio vs Playa) y del estado de la marea en el momento de la tanda.<br>')
$h.Add('Handicap de liga de Aizburua: ' + $aizHcp + '</div>')
$h.Add('</div>')
$h.Add('<div class="bp"><div class="bpl">DONDE SE PERDI&Oacute; LA REGATA &mdash; EL MOMENTO CLAVE</div>')
$h.Add('<p style="font-size:13.5px; line-height:1.7; color:#333">En la <strong>primera parte (hasta la 1a ciaboga)</strong>, Aizburua marc&oacute; <strong>' + $aizCiab + '</strong> frente al ganador ' + (ConvertTo-HtmlEntity $t1Nom) + ' con <strong>' + $t1Ciab + '</strong>. Diferencia a mitad de recorrido: <strong>solo +12 segundos</strong>. La regata estaba viva.<br><br>')
$h.Add('En la <strong>segunda parte (vuelta)</strong>, esos 12 segundos se convirtieron en <strong>+42 segundos de diferencia total</strong> con el ganador. Se perdieron 30 segundos adicionales solo en la vuelta.<br><br>')
$h.Add('<strong>Por qu&eacute; ocurri&oacute; esto:</strong> El equipo gestion&oacute; la ida con un ritmo potente y controlado de <strong>32-33 p/min</strong> aprovechando la marea a favor, lo que permiti&oacute; llegar a la ciaboga con vida t&aacute;ctica (+12s). A la vuelta (Marea Bajando en contra), el escenario requer&iacute;a <strong>"surfear" la ola de popa y aprovechar el viento de aleta</strong>. Sin embargo, al subir la intensidad a <strong>34-36 p/min</strong> para intentar vencer el muro de la corriente, se asfixi&oacute; la remada. Al final, la fuerza de la corriente anul&oacute; la ayuda del viento y la ola, provocando una p&eacute;rdida de "agarre" que los rivales capitalizaron mejor para abrir la brecha definitiva.</p></div>')
$h.Add('</div>')

# -------- BOGA Y RENDIMIENTO (GARMIN) --------
$fL1 = "(Sin datos)"
if ($aizd.analisis.frecuencia_boga_L1_real) { $fL1 = $aizd.analisis.frecuencia_boga_L1_real }
$fL2 = "(Sin datos)"
if ($aizd.analisis.frecuencia_boga_L2_real) { $fL2 = $aizd.analisis.frecuencia_boga_L2_real }

$dg = $aizd.analisis.datos_garmin

# Calculo de velocidades dinámicas (m/s) y Metros por Palada (MpP)
$distLargo = $regata.distancia_m / 2
$velL1 = 0 ; $velL2 = 0
if ($sciaAiz -gt 0) { $velL1 = [math]::Round($distLargo / $sciaAiz, 2) }
if ($saAiz -gt $sciaAiz) { $velL2 = [math]::Round($distLargo / ($saAiz - $sciaAiz), 2) }

$dropVel = 0
if ($velL1 -gt 0) { $dropVel = [math]::Round((($velL2 - $velL1) / $velL1) * 100, 0) }

$mppL1 = "---" ; $mppL2 = "---"
if ($fL1 -match '(\d+)-(\d+)') { 
    $avgL1 = ([int]$Matches[1] + [int]$Matches[2]) / 2 
    if ($avgL1 -gt 0) { $mppL1 = [math]::Round(($velL1 * 60) / $avgL1, 2) }
}
if ($fL2 -match '(\d+)-(\d+)') { 
    $avgL2 = ([int]$Matches[1] + [int]$Matches[2]) / 2 
    if ($avgL2 -gt 0) { $mppL2 = [math]::Round(($velL2 * 60) / $avgL2, 2) }
}

$h.Add('<div class="stitle">C&oacute;mo Remaron &mdash; An&aacute;lisis Cruzado de Ritmo y Telemetr&iacute;a</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-r">R</div><h2>Estimaci&oacute;n del Ritmo por Tramo &mdash; Tiempo total real: ' + $aizRaw + ' minutos</h2></div>')

if ($dg) {
    $h.Add('<div class="g2" style="margin-bottom:15px;">')
    $fmtRitmo = $dg.ritmo_medio.Replace("/km", " min/km")
    $h.Add('<div class="info-box" style="background:#f0f4ff;border-color:#1a3a6a;color:#1a3a6a"><strong>M&eacute;tricas Garmin (Mando Patr&oacute;n):</strong><br>Distancia Real: ' + $dg.distancia_real_m + 'm | Desv&iacute;o: +' + $dg.desvio_distancia_m + 'm<br>Ritmo Medio: ' + $fmtRitmo + ' | Vel. M&aacute;xima: ' + $dg.velocidad_maxima_kmh + ' km/h</div>')
    $h.Add('<div class="info-box" style="background:#fffbe6;border-color:#f5c842;color:#7a5a00"><strong>Impacto del Desv&iacute;o:</strong><br>' + $dg.conclusion_desvio + '</div>')

    $h.Add('</div>')
}

$h.Add('<div class="g2">')
$h.Add('<table><thead><tr><th>Dato Hidrodin&aacute;mico</th><th>Largo 1 (ida al mar)</th><th>Largo 2 (vuelta a puerto)</th><th>Fallo Estructural</th></tr></thead><tbody>')
$h.Add('<tr><td>Corriente y Ola</td><td>Marea a favor, viento en contra</td><td>Marea en contra, viento a popa</td><td style="color:#C0001A">Incapacidad en empopadas</td></tr>')
$h.Add('<tr><td>Frecuencia de boga</td><td>' + $fL1 + ' p/min</td><td>' + $fL2 + ' p/min</td><td style="color:#C0001A">Asfixia: +frecuencia rotacional</td></tr>')
$h.Add('<tr><td>Metros por palada</td><td><strong>' + $mppL1 + ' m</strong></td><td><strong>' + $mppL2 + ' m</strong></td><td style="color:#C0001A">P&eacute;rdida del "agarre" al agua</td></tr>')
$h.Add('<tr><td colspan="4" style="background:#fffbe6; font-size:10px; color:#7a5a00; font-style:italic">Nota: La marea bajando infla los metros por palada a la ida y los penaliza a la vuelta. Lo cr&iacute;tico es el desplome del 17% en velocidad.</td></tr>')
$h.Add('<tr><td>Desplazamiento &uacute;til</td><td>Palada ancha y eficiente</td><td>Cr&iacute;tico / Remando al vac&iacute;o (Derrape)</td><td style="color:#C0001A">El barco se "frena" entre paladas</td></tr>')
$h.Add('<tr><td>Velocidad media</td><td>' + $velL1 + ' m/s (ida)</td><td>' + $velL2 + ' m/s (hundimiento)</td><td style="color:#C0001A">' + $dropVel + '% de desplome en velocidad</td></tr>')
$h.Add('<tr><td>Guerra VS el L&iacute;der</td><td>Aizburua aguanta (+12s)</td><td>Aizburua desaparece (+30s extra)</td><td style="color:#C0001A">Total de 42s de brecha</td></tr>')
$h.Add('</tbody></table>')

# Diagnostico Segmentado Profesional
$h.Add('<div class="diag-box">')
$h.Add('<div class="diag-header">An&aacute;lisis Termomec&aacute;nico &mdash; S&iacute;ndrome de Asfixia Rotacional</div>')

$h.Add('<div class="diag-segment">')
$h.Add('<span class="diag-label">FASE 1: ATAQUE (Largo 1)</span>')
$h.Add('<div class="diag-content">Aizburua sostuvo un ritmo agresivo <strong>sub-4:00/km</strong> con una boga larga y eficiente (32-33 p/min). En la 1a ciaboga, la diferencia era de <strong>solo +12 segundos</strong>. La regata estaba viva y el bloque central manten&iacute;a la potencia hidrodin&aacute;mica.</div>')
$h.Add('</div>')

$h.Add('<div class="diag-segment">')
$h.Add('<span class="diag-label">PUNTO DE INFLEXI&Oacute;N (Giro)</span>')
$h.Add('<div class="diag-content">Al realizar la ciaboga, la f&iacute;sica del campo se invirti&oacute;: el "colch&oacute;n" de corriente a favor desapareci&oacute;, convirti&eacute;ndose en un <strong>muro invisible de vaciado</strong> en la Calle 1.</div>')
$h.Add('</div>')

$h.Add('<div class="diag-segment">')
$h.Add('<span class="diag-label">FASE 2: EL MURO (Largo 2)</span>')
$h.Add('<div class="diag-content">El diferencial se ampli&oacute; de +12s a <strong>+42s finales</strong>. Se perdieron <strong>30 segundos extras</strong> solo en la vuelta. La penalizaci&oacute;n hidrodin&aacute;mica de la Calle 1 hizo que el bote se hundiera estructuralmente por encima de los 4:30/km pese al esfuerzo de la tripulaci&oacute;n.</div>')
$h.Add('</div>')

$h.Add('<div class="diag-segment" style="margin-bottom:0">')
$h.Add('<span class="diag-label" style="color:#1e3a5f">DIAGN&Oacute;STICO FINAL: ASFIXIA ROTACIONAL</span>')
$h.Add('<div class="diag-content">En un intento desesperado por vencer la resistencia, la tripulaci&oacute;n <strong>subi&oacute; la frecuencia</strong> (34-36 p/min). Esta descompensaci&oacute;n provoc&oacute; que se <strong>"remara en vac&iacute;o"</strong>: alto gasto card&iacute;aco pero avance (MpP) insuficiente.</div>')
$h.Add('</div>')

$h.Add('</div>')
$h.Add('</div></div>')


# -------- ALINEACION --------
$h.Add('<div class="stitle">Tripulaci&oacute;n de Aizburua</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-a">A</div><h2>Disposici&oacute;n en la Trainera &mdash; Bancada 1 = Popa (junto al patr&oacute;n), Bancada 6 = Proa</h2></div><div class="g2" style="align-items:start">')

$h.Add('<table class="tt"><thead><tr>')
$h.Add('<th style="background:#1a1a2e;color:#fff;border-radius:5px;padding:7px">Bancada</th>')
$h.Add('<th style="background:#0a3d62;color:#fff;border-radius:5px;padding:7px">Babor (lado izq.) &mdash; edad</th>')
$h.Add('<th style="background:#145a32;color:#fff;border-radius:5px;padding:7px">Estribor (lado der.) &mdash; edad</th>')
$h.Add('</tr></thead><tbody>')
$h.Add($trAli.ToString())
$h.Add('</tbody></table>')

# -- LEYENDA A LA DERECHA DE LA TABLA --
$h.Add('<div style="background:var(--lg);border-radius:10px;padding:14px;align-self:start"><div style="font-size:10px;text-transform:uppercase;color:var(--gy);margin-bottom:10px">Datos de Salida y Edad</div><div style="display:grid;gap:7px">')
$h.Add('<div style="background:#d4edfa;padding:7px 12px;border-radius:5px;font-size:11px;color:#0a3d62"><strong>Babor (B)</strong>: Lado izquierdo mirando de popa hacia proa</div>')
$h.Add('<div style="background:#d5f5e3;padding:7px 12px;border-radius:5px;font-size:11px;color:#145a32"><strong>Estribor (E)</strong>: Lado derecho mirando de popa hacia proa</div>')
$h.Add('<div style="background:var(--rl);padding:7px 12px;border-radius:5px;font-size:11px;color:var(--rd)"><strong>Bancada 1 &mdash; POPA</strong>: Los dos remeros m&aacute;s cercanos al patr&oacute;n</div>')
$h.Add('<div style="background:#f0f4ff;padding:7px 12px;border-radius:5px;font-size:11px;color:#1a3a6a"><strong>Tanda ' + $aizTanda + ' &mdash; Calle ' + $aizCalle + '</strong> | Salida: ' + $aizHora + 'h | H&aacute;ndicap de liga: ' + $aizHcp + '</div>')
    if ($totalConfirm -gt 0) {
        $h.Add('<div style="background:#fff8e1;padding:7px 12px;border-radius:5px;font-size:11px;color:#7a5a00"><strong>Edad Media Tripulaci&oacute;n</strong>: <strong>' + $edadMediaStr + '</strong> (' + $totalConfirm + '/' + $totalMiembros + ' confirmadas)</div>')
    }
    $h.Add('</div></div>')
    $h.Add('</div>') # Cierra el g2 para que la tabla y leyenda estén juntas

    # --- TABLA DE EQUILIBRIO DE MASAS (NUEVA SECCIÓN) ---
$difColor = if ([math]::Abs($difPeso) -gt 15) { "#C0001A" } else { "#145a32" }
$h.Add('<div style="margin-top:20px; background:#f8f9fa; border-radius:10px; padding:20px; border:1px solid #ddd">')
$h.Add('<div style="font-size:11px; font-weight:800; text-transform:uppercase; letter-spacing:1px; margin-bottom:15px; color:#555">Equilibrio de Masas y Trimado Lateral (Excl. Proa/Patr&oacute;n para B/E)</div>')
$h.Add('<div style="display:grid; grid-template-columns: repeat(4, 1fr); gap:15px">')
$h.Add('<div class="st" style="border-left-color:#1a1a2e"><div class="lbl">Peso Total Tripulaci&oacute;n</div><div class="val">' + $pesoTripulacion + ' kg</div><div class="sbl">Incluye Proa y Patr&oacute;n</div></div>')
$h.Add('<div class="st" style="border-left-color:#0a3d62"><div class="lbl">Total Babor (B1-B6)</div><div class="val">' + $pesoBabor + ' kg</div><div class="sbl">Motor de babor</div></div>')
$h.Add('<div class="st" style="border-left-color:#145a32"><div class="lbl">Total Estribor (E1-E6)</div><div class="val">' + $pesoEstribor + ' kg</div><div class="sbl">Motor de estribor</div></div>')
$h.Add('<div class="st" style="border-left-color:' + $difColor + '"><div class="lbl">Desequilibrio Lateral</div><div class="val">' + $difPeso + ' kg</div><div class="sbl">Diferencia Babor - Estribor</div></div>')
$h.Add('</div>')

if ([math]::Abs($difPeso) -gt 20) {
    $h.Add('<div class="info-box" style="margin-top:15px; background:#fff2f2; border-color:#ffcccc; color:#C0001A">')
    $h.Add('<strong>ALERTA DE TRIMADO:</strong> Existe un desequilibrio lateral cr&iacute;tico de <strong>' + $difPeso + ' kg</strong>. El bote tender&aacute; a escorar hacia el lado m&aacute;s pesado, aumentando el rozamiento y dificultando el trabajo del patr&oacute;n para mantener el rumbo.</div>')
} else {
    $h.Add('<div class="info-box" style="margin-top:15px; background:#f2fdf5; border-color:#ccffdd; color:#145a32">')
    $h.Add('<strong>TRIMADO &Oacute;PTIMO:</strong> El equilibrio lateral es excelente (diferencia de ' + [math]::Abs($difPeso) + ' kg). El bote navegar&aacute; plano, maximizando la eficiencia de cada palada.</div>')
}
$h.Add('</div>')
$h.Add('</div>') # Cierra el card

# -------- ANALISIS DE EDAD --------
$h.Add('<div class="stitle">Perfil de Edad de la Tripulaci&oacute;n</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-e">E</div><h2>M&eacute;tricas de Edad &mdash; Referencia para comparativas futuras entre regatas</h2></div>')

if ($totalConfirm -lt $totalMiembros) {
    $h.Add('<div class="info-box">Edades confirmadas: <strong>' + $totalConfirm + ' de ' + $totalMiembros + '</strong>. Las estad&iacute;sticas parciales se basan en las edades disponibles. Puedes completarlas en el JSON con el dato del patr&oacute;n + PDF de alineaci&oacute;n.</div>')
}
$h.Add('<div class="gs" style="margin-bottom:16px">')
$h.Add('<div class="st"><div class="lbl">Edad Media Tripulaci&oacute;n</div><div class="val">' + $edadMediaStr + '</div><div class="sbl">' + $totalConfirm + '/' + $totalMiembros + ' datos confirmados</div></div>')
$h.Add('<div class="st"><div class="lbl">Rango de Edades</div><div class="val">' + $edadRangoStr + '</div><div class="sbl">El m&aacute;s joven vs el m&aacute;s veterano</div></div>')
$h.Add('<div class="st"><div class="lbl">Media Bloque Popa (B1-B2)</div><div class="val">' + $avgPopaStr + '</div></div>')
$h.Add('<div class="st"><div class="lbl">Media Bloque Central (B3-B4)</div><div class="val">' + $avgCentralStr + '</div></div>')
$h.Add('<div class="st"><div class="lbl">Media Bloque Proa (B5-B6)</div><div class="val">' + $avgProaStr + '</div></div>')
$h.Add('</div>')
$h.Add('<div class="info-box" style="font-size:11px"><strong>Para qu&eacute; sirve esto en futuras regatas:</strong> La edad media de la tripulaci&oacute;n cambia con cada regata seg&uacute;n la alineaci&oacute;n. Correlacionar la edad media con el tiempo real remado permitir&aacute; identificar si existe un umbral &oacute;ptimo de edad para esta tripulaci&oacute;n, y si la rotaci&oacute;n de remeros entre regatas afecta positiva o negativamente al rendimiento. En categor&iacute;a veteranos, factores como la gesti&oacute;n energ&eacute;tica y la t&eacute;cnica compensan la p&eacute;rdida de potencia bruta por edad.</div>')
$h.Add('</div>')

# -------- RECOMENDACIONES --------
$h.Add('<div class="stitle">Conclusiones T&eacute;cnicas Inmediatas</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-star">*</div><h2>Puntos de Acci&oacute;n Concretos tras la Radiograf&iacute;a F&iacute;sica</h2></div><ul class="rl">')

$h.Add('<li><strong>Corregir el p&aacute;nico hidrodin&aacute;mico a no avanzar.</strong> Al virar en ciaboga y encontrar la Marea Bajando en contra, la reacci&oacute;n de subir frecuencias (34-36 p/min) fue contraproducente. Contra corriente fuerte, m&aacute;s ritmo sin "agarre" solo genera asfixia. La consigna debe ser frialdad: mantener una boga larga para poder "enganchar" las olas de popa que el viento regalaba a la vuelta.</li>')
$h.Add('<li><strong>Entrenar la caza e identificaci&oacute;n de empopadas.</strong> A pesar de la corriente en contra, el viento de aleta y la ola de popa eran aliados t&aacute;cticos. Los l&iacute;deres abrieron brecha porque surfearon el campo mientras Aizburua luchaba contra el agua. Es cr&iacute;tico que el patr&oacute;n y las bancadas de popa coordinen tirones para capitalizar cada empuje de la ola.</li>')
$h.Add('<li><strong>Optimizar la geometr&iacute;a del tim&oacute;n (+10s artificiales perdidos).</strong> El Garmin es claro: +40 metros sobre la trazada te&oacute;rica del campo regalan ~9.8 segundos gratis a los rivales. Ce&ntilde;ir el bote lo mejor posible a la cuerda de las balizas supone escalar virtualmente hasta el puesto proyectado de <strong>' + $puestoProy + '&ordm;</strong> clasificado.</li>')
$h.Add('<li><strong>La Marea Bajando en Calle 1 fue inasumible.</strong> Estructuralmente, la l&iacute;nea interior de la r&iacute;a penaliz&oacute; masivamente el avance. Es una variante externa que solo se mitiga con una gesti&oacute;n t&eacute;cnica impecable del planeo por popa.</li>')
$h.Add('</ul></div>')
$h.Add('</div>')
$h.Add('<div class="ftr">')
if ($logo2Base64) {
    $h.Add('  <img src="data:image/jpeg;base64,' + $logo2Base64 + '" class="logo-footer" alt="Branding Aizburua">')
}
$h.Add('  <div>Club Aizburua &mdash; Liga AKK 11.1 &mdash; ' + $RegFecha + ' &mdash; ' + $RegLugar + '</div>')
$h.Add('</div>')
$h.Add('</body></html>')

$content = $h -join "`n"
[System.IO.File]::WriteAllText($htmlFile, $content, [System.Text.Encoding]::UTF8)
Write-Host "HTML generado: $htmlFile"
Write-Host "Recomendacion: Usa Chrome (Ctrl+P) si deseas guardar el informe como PDF."
Invoke-Item $htmlFile
