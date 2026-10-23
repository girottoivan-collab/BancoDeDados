param(
    [Parameter(Mandatory = $true)]
    [string]$Password
)

$source = 'C:\Users\ivan.girotto\.codex\attachments\31f120bc-fc24-4772-a338-94e46505afae\pasted-text.txt'
$ddl = Get-Content -LiteralPath $source -Raw
$startMarker = "    IF LC_CUSTOMEDIOREPLICADO = 'T' THEN"
$endMarker = '    -- DESABILITADO: Custo medio'
$start = $ddl.IndexOf($startMarker, [System.StringComparison]::Ordinal)
$end = $ddl.IndexOf($endMarker, [System.StringComparison]::Ordinal)

if ($start -lt 0 -or $end -le $start) {
    throw 'Nao foi possivel identificar o trecho de custo medio replicado.'
}

$before = $ddl.Substring(0, $start)
$section = $ddl.Substring($start, $end - $start)
$after = $ddl.Substring($end)

function Replace-ExactCount {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Replacement,
        [int]$Expected,
        [string]$Name
    )

    $count = [regex]::Matches($Text, $Pattern).Count
    if ($count -ne $Expected) {
        throw "${Name}: esperadas $Expected ocorrencias; encontradas $count."
    }
    return [regex]::Replace($Text, $Pattern, $Replacement)
}

# Cada V0 passa a representar um local em uma data, e nao todos os locais da data.
$section = Replace-ExactCount $section 'ES\.IDSUBPRODUTO,\r?\n(?<i>\s*)ES\.DTMOVIMENTO,' "ES.IDSUBPRODUTO,`r`n`${i}ES.IDLOCALESTOQUE,`r`n`${i}ES.DTMOVIMENTO," 4 'SELECT de V0'
$section = Replace-ExactCount $section 'ES\.IDSUBPRODUTO,\r?\n(?<i>\s*)ES\.DTMOVIMENTO\r?\n' "ES.IDSUBPRODUTO,`r`n`${i}ES.IDLOCALESTOQUE,`r`n`${i}ES.DTMOVIMENTO`r`n" 4 'GROUP BY de V0'
$section = Replace-ExactCount $section 'V0\.IDSUBPRODUTO\r?\n(?<i>\s*)ORDER BY' "V0.IDSUBPRODUTO,`r`n`${i}V0.IDLOCALESTOQUE`r`n`${i}ORDER BY" 4 'PARTITION BY de V0'

# Tipos 1 e 2 devem escolher primeiro a ultima linha de cada local. So entao
# aplicam os criterios de saldo/valor positivos, sem voltar para uma data antiga.
$filterPattern = '(?s)\) AS V0\s+WHERE\s+\(\s*QTDSALDOINICIAL \+ QTDENTRAESTOQUE \+ QTDAJUSTEBALANCO\s*\) > 0 AND\s+\(\s*VALSALDOINICIAL \+ VALENTRAESTOQUE \+ VALAJUSTEBALANCO\s*\) > 0\s+\) AS ESTOQUE\s+WHERE\s+LINHA = 1'
$filterReplacement = ") AS V0`r`n                        ) AS ESTOQUE`r`n                    WHERE`r`n                        LINHA = 1 AND`r`n                        ( QTDSALDOINICIAL + QTDENTRAESTOQUE + QTDAJUSTEBALANCO ) > 0 AND`r`n                        ( VALSALDOINICIAL + VALENTRAESTOQUE + VALAJUSTEBALANCO ) > 0"
$section = Replace-ExactCount $section $filterPattern $filterReplacement 2 'Filtros dos tipos 1 e 2'

$ddl = $before + $section + $after

# '!' e terminador para nao conflitar com os parametros @EMPRESA, @PRODUTO etc.
$inputSql = "CONNECT TO UNICOOP2 USER dba USING $Password !`r`n$ddl!`r`nCONNECT RESET !"
$db2 = 'C:\Program Files\IBM\SQLLIB\BIN\db2.exe'
$inputSql | & $db2 -td!
if ($LASTEXITCODE -ne 0) {
    throw "DB2 retornou codigo $LASTEXITCODE ao substituir a funcao."
}
