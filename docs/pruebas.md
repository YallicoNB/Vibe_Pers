# Pruebas del prototipo local

## Automatizadas

Ejecutar desde la raíz del proyecto:

```powershell
flutter analyze
flutter test
```

Resultados del 7 de noviembre de 2026:

- `flutter analyze`: sin problemas.
- `flutter test`: cinco pruebas correctas (voto, aceptación de ayuda, persistencia y separación por comunidad, navegación y gesto SOS de dos dedos).

## Recorrido manual recomendado en Android

1. Omitir tutorial. Abrir Comunidad y comprobar que Las Palmeras tiene líder de prueba.
2. Cambiar al vecino Carmen: Los Olivos no tiene líder y muestra el recordatorio.
3. Volver a Ana: abrir Mapa, buscar fichas y alternar lista/mapa esquemático.
4. Entrar en servicio de Luis: Ana puede quitar/poner visto bueno; cambiar a Luis y comprobar que no puede recomendarse.
5. Publicar producto con foto y precio; cerrar/reabrir app y comprobar persistencia local.
6. En Ayuda sin dinero, abrir el pedido de silla de ruedas de Ana. Cambiar a María, responder; volver a Ana, aceptar y resolver.
7. Activar modo avión. Comprobar lectura de fichas guardadas y creación local. La app no debe afirmar que otro teléfono las recibió.
8. En Emergencias, apoyar dos dedos por menos de 2 segundos (no activa), luego por 2 segundos (activa simulación). Finalizar o extender manualmente.
9. Probar alternativa accesible con confirmación. Probar abrir el marcador para 105, 116 y 106 **sin iniciar una llamada de prueba**.

## Pendiente de verificación

- Build Android en la sesión normal del usuario y ejecución en emulador/teléfono. En el entorno aislado de Codex, Gradle recibió `AccessDeniedException` al abrir `core-for-system-modules.jar` y un JAR de su caché; el análisis y los tests Dart sí pasaron. Se pidió verificar el APK desde PowerShell del usuario.
- Registro real, documentos, RLS, sincronización, SOS entre dispositivos, caducidad de servidor, push e iOS; requieren backend o infraestructura que aún no existe.
