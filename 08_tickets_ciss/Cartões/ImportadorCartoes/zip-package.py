from pathlib import Path
import zipfile
import sys
root = Path(__file__).resolve().parent / (sys.argv[1] if len(sys.argv) > 1 else 'distfinal')
folder = root / 'ImportadorCartoes'
destination = root / 'ImportadorCartoes-Windows-x64.zip'
with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(folder.rglob('*')):
        if file.is_file():
            archive.write(file, file.relative_to(root))
with zipfile.ZipFile(destination) as archive:
    error = archive.testzip()
    if error:
        raise RuntimeError(error)
print(f'ZIP verificado: {destination} ({destination.stat().st_size:,} bytes)')
