name: eltonel_full
description: Sistema de Gestion Desayunos El Tonel
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0
  path: ^1.8.3
  provider: ^6.1.1
  url_launcher: ^6.2.2
  file_picker: ^6.1.1
  path_provider: ^2.1.1
  share_plus: ^7.2.1
  crypto: ^3.0.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1

flutter:
  uses-material-design: true

  fonts:
    - family: CourierNew
      fonts:
        - asset: fonts/Courier_New_Regular.ttf
        - asset: fonts/Courier_New_Bold.ttf
          weight: 700
        - asset: fonts/Courier_New_Italic.ttf
          style: italic
        - asset: fonts/Courier_New_Bold_Italic.ttf
          weight: 700
          style: italic