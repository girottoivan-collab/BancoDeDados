param(
    [string]$Database = "TSTPONTO",
    [string]$User = "dba",
    [Parameter(Mandatory = $true)]
    [string]$Password,
    [string]$DtMonitor = "1900-01-01 00:00:00",
    [string]$Completa = "F",
    [string]$EmpresaSets = "1;1,2",
    [string]$ConsultaFiltro = ""
)

$ErrorActionPreference = "Stop"

function Invoke-Db2 {
    param(
        [string]$Sql,
        [string]$Label
    )

    $tempFile = Join-Path $env:TEMP ("monitorfront_{0}.sql" -f ([guid]::NewGuid().ToString("N")))
    try {
        Set-Content -Path $tempFile -Value $Sql -Encoding ASCII
        $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
        $output = & db2 -x -tvf $tempFile 2>&1
        $exitCode = $LASTEXITCODE
        $elapsed.Stop()

        [pscustomobject]@{
            Label = $Label
            ExitCode = $exitCode
            Seconds = [math]::Round($elapsed.Elapsed.TotalSeconds, 3)
            Output = ($output -join "`n").Trim()
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempFile) {
            Remove-Item -LiteralPath $tempFile -Force
        }
    }
}

function Get-QueryForEmpresaSet {
    param(
        [string]$Path,
        [string]$EmpresaSet,
        [string]$DtMonitor,
        [string]$Completa
    )

    $sql = Get-Content -Path $Path -Raw
    $sql = $sql -replace "(?is)(FROM\s+DBA\.EMPRESA\s+EMPRESA)(\s*\))", "`$1`r`n    WHERE EMPRESA.IDEMPRESA IN ($EmpresaSet)`$2"
    $sql = $sql -replace ":RA_DTMONITOR", "TIMESTAMP('$DtMonitor')"
    $sql = $sql -replace ":RA_COMPLETA", "'$Completa'"
    $sql = $sql -replace "(?is)\s+ORDER\s+BY\s+1\s*,\s*2\s*$", ""

    return $sql
}

function Measure-Count {
    param(
        [string]$Name,
        [string]$Sql
    )

    $countSql = "SELECT COUNT(*) FROM ($Sql) AS MONITOR_QUERY;"
    $result = Invoke-Db2 -Sql $countSql -Label $Name
    $line = ($result.Output -split "`n" | Where-Object { $_.Trim() -match "^\d+$" } | Select-Object -Last 1)
    if ($null -eq $line) {
        $line = ""
    }

    [pscustomobject]@{
        Consulta = $Name
        Linhas = $line.Trim()
        Segundos = $result.Seconds
        ExitCode = $result.ExitCode
        Output = $result.Output
    }
}

$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path
$queries = @(
    [pscustomobject]@{
        Name = "Sem cenario fiscal"
        Path = Join-Path $basePath "SelectProdutosSemCenarioFiscal_v2.txt"
    },
    [pscustomobject]@{
        Name = "Com cenario fiscal"
        Path = Join-Path $basePath "SelectProdutosComCenarioFiscal_v2.txt"
    }
)

if ($ConsultaFiltro -ne "") {
    $queries = $queries | Where-Object { $_.Name -like "*$ConsultaFiltro*" }
}

& db2 connect to $Database user $User using $Password | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Falha ao conectar no banco $Database."
}

try {
    Write-Host "Empresas da base:"
    $empresasSql = @"
SELECT
    E.IDEMPRESA,
    E.UF,
    COUNT(PPP.IDPRODUTO) AS QTD_POLITICA_PRECO
FROM
    DBA.EMPRESA E
    LEFT JOIN DBA.POLITICA_PRECO_PRODUTO PPP ON (
        PPP.IDEMPRESA = E.IDEMPRESA
    )
GROUP BY
    E.IDEMPRESA,
    E.UF
ORDER BY
    E.IDEMPRESA
FETCH FIRST 20 ROWS ONLY;
"@
    $empresas = Invoke-Db2 -Sql $empresasSql -Label "Empresas"
    Write-Host $empresas.Output

    foreach ($empresaSet in ($EmpresaSets -split ";" | Where-Object { $_.Trim() -ne "" })) {
        $empresaSet = $empresaSet.Trim()
        Write-Host ""
        Write-Host "Filtro EMPRESAS_BASE: IDEMPRESA IN ($empresaSet)"
        foreach ($query in $queries) {
            $sql = Get-QueryForEmpresaSet -Path $query.Path -EmpresaSet $empresaSet -DtMonitor $DtMonitor -Completa $Completa
            $result = Measure-Count -Name $query.Name -Sql $sql
            if ($result.ExitCode -eq 0) {
                Write-Host ("  {0}: linhas={1}; segundos={2}" -f $result.Consulta, $result.Linhas, $result.Segundos)
            }
            else {
                Write-Host ("  {0}: erro em {1}s" -f $result.Consulta, $result.Segundos)
                $errors = $result.Output -split "`n" | Where-Object { $_ -match "SQL\d{4}[A-Z]|SQLSTATE|SQL0437W|Código de razão" }
                Write-Host ($errors -join "`n")
            }
        }
    }
}
finally {
    & db2 connect reset | Out-Host
}
