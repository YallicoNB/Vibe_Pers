# MiBarrio

Prototipo vecinal en Flutter para Android e iOS. Incluye comunidades delimitadas en mapa, mercado, recomendaciones y una demostración de emergencias. La documentación funcional está en [`docs/`](docs/).

## Ejecutar en Android

1. Instala Flutter estable, Android Studio y los plugins Flutter y Dart. Comprueba el entorno con `flutter doctor` y acepta las licencias de Android si se solicitan.
2. Clona este repositorio y entra a la carpeta:

   ```bash
   git clone https://github.com/YallicoNB/Vibe_Pers.git
   cd Vibe_Pers
   flutter pub get
   ```

3. Conecta un teléfono Android con depuración USB o inicia un emulador. Comprueba que aparezca con `flutter devices`.
4. Ejecuta `flutter run` o abre la carpeta del repositorio en Android Studio y pulsa **Run**.

En Windows, activa el **Modo de desarrollador** si Flutter indica que necesita soporte para enlaces simbólicos. Para generar el APK de demostración, usa `flutter build apk --release`; quedará en `build/app/outputs/flutter-apk/app-release.apk`. Esta demo usa la firma de depuración configurada en Gradle; antes de publicar en una tienda se necesitará una firma propia.

## APK para jurados

Descarga `MiBarrio-Android-v1.0.1.apk` desde **Releases** de este repositorio y ábrelo en un teléfono Android. No necesitas Android Studio para instalarlo. La app usa el proyecto Supabase de la demo y requiere internet para las funciones compartidas; los documentos de evacuación incluidos se pueden consultar sin conexión tras iniciar sesión.

## Ejecutar en iOS

En una Mac con Xcode y Flutter instalados, ejecuta `flutter pub get`, abre un simulador o conecta un iPhone y usa `flutter run`. La compilación iOS no se ha verificado en este proyecto desde Windows.

## Datos y cuenta de prueba

La app está configurada para el proyecto Supabase compartido de esta demo. La clave incluida en `lib/core/supabase_config.dart` es **publicable**; nunca coloques una clave `service_role`, contraseñas o archivos `local.properties` en el repositorio. Para probar el registro, confirma el correo y después completa el perfil vecinal. El DNI se valida como único al completar el perfil.

**Usa solo datos e imágenes ficticias para la demo.** No cargues un DNI real. Los vecinos, negocios, rutas y puntos seguros de ejemplo son inventados. Los PDF de evacuación incluidos en `assets/evacuation/` sirven para mostrar la interfaz sin internet y **no deben usarse ante una emergencia real**. El SOS no envía alertas reales.

Si necesitas un backend propio, crea un proyecto de Supabase, aplica en orden los archivos de `supabase/migrations/` y luego `supabase/seed.sql` para datos ficticios. Sustituye la URL y la clave publicable en `lib/core/supabase_config.dart`. Las políticas RLS forman parte de las migraciones.

## Verificación

```bash
flutter analyze
flutter test
flutter build apk --debug
```

El análisis y las 13 pruebas pasaron el 8 de noviembre de 2026 en Windows. La documentación sobre fuentes y límites de los mapas está en [`docs/fuentes_evacuacion.md`](docs/fuentes_evacuacion.md).
