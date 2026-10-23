# Ícone

Imagem fornecida pelo usuário: https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTu7COSsEtOJ5Qq49OFCqbQ0RBLugrguiOuf7qe7i1jRw&s=10

`icone-original` preserva o download. `app-icon.ico` contém imagens de 16, 24, 32, 48, 64, 128 e 256 pixels; `src/main/resources/app-icon.png` é usado pela janela Java. A conversão mantém a imagem inteira, sem recortes.

Para regenerar com JDK 17, a partir da pasta do projeto:

```powershell
java tools/PrepareIcon.java assets/icone-original src/main/resources/app-icon.png assets/app-icon.ico
```
