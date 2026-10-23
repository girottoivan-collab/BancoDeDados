param([string]$Maven = 'mvn.cmd', [string]$Jdk = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.16.8-hotspot', [string]$Destination = 'dist')
$ErrorActionPreference = 'Stop'
$env:JAVA_HOME = $Jdk
Push-Location $PSScriptRoot
try {
    & $Maven -B clean package
    if ($LASTEXITCODE -ne 0) { throw 'Falha na compilação Maven.' }
    $stage = Join-Path $PSScriptRoot ('target\package-input-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    Copy-Item -LiteralPath 'target\importador-cartoes-1.0.0.jar' -Destination $stage -Force
    Copy-Item -LiteralPath 'target\lib' -Destination $stage -Recurse -Force
    & "$Jdk\bin\jpackage.exe" --type app-image --name ImportadorCartoes --app-version 1.3.2 --vendor 'Importador Cartoes' --icon (Join-Path $PSScriptRoot 'assets\app-icon.ico') --input $stage --main-jar importador-cartoes-1.0.0.jar --main-class br.com.cartoes.App --dest $Destination --add-modules java.desktop,java.sql,java.naming,java.security.jgss,java.management,java.rmi,jdk.unsupported,jdk.crypto.ec,jdk.charsets --java-options '-Dfile.encoding=UTF-8'
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao gerar executável.' }
    Copy-Item -LiteralPath 'README.md' -Destination "$Destination\ImportadorCartoes\LEIA-ME.md"
    $sqlDestination = Join-Path $Destination 'ImportadorCartoes\sql'
    New-Item -ItemType Directory -Path $sqlDestination -Force | Out-Null
    Copy-Item -LiteralPath 'sql\releases\objetos_v1.3.2.sql', 'sql\13_consultar_checkpoint.sql', 'sql\README.md' -Destination $sqlDestination
    foreach ($doc in @('APRESENTACAO_SOLUCAO_CLIENTE.md', 'VALIDACAO.md', 'output\pdf\APRESENTACAO_SOLUCAO_CLIENTE.pdf')) {
        if (Test-Path -LiteralPath $doc) { Copy-Item -LiteralPath $doc -Destination "$Destination\ImportadorCartoes" -Force }
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipTemp = Join-Path $PSScriptRoot ($Destination + '\package-' + [guid]::NewGuid().ToString('N') + '.zip')
    [System.IO.Compression.ZipFile]::CreateFromDirectory((Join-Path $PSScriptRoot "$Destination\ImportadorCartoes"), $zipTemp, [System.IO.Compression.CompressionLevel]::Optimal, $true)
    Move-Item -LiteralPath $zipTemp -Destination "$Destination\ImportadorCartoes-Windows-x64.zip" -Force
} finally { Pop-Location }
