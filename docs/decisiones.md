# Registro de decisiones

## 2026-11-07 — Prototipo local previo al backend

- **Responsable:** implementación inicial asistida por Codex; el equipo debe revisar.
- **Motivo:** el equipo aún no tiene un proyecto Supabase. No se pueden demostrar autenticación, RLS, intercambio entre teléfonos ni alertas reales sin servidor.
- **Decisión:** implementar primero navegación y flujos locales persistentes con datos ficticios; rotularlos en todas las pantallas pertinentes.
- **Módulos afectados:** cuenta de prueba, comunidad, mapa, mercado, solidaridad, emergencias y almacenamiento local.
- **Pruebas nuevas:** autovoto/voto duplicado, autorización del autor para aceptar ayuda, navegación principal; ver `pruebas.md`.
- **Límite:** `SharedPreferences` sirve para prototipo local, no para almacenar DNI, fotos de identidad, contraseñas o coordenadas SOS reales. No cumple el backend del MVP final.

## Pendientes para el equipo

1. Confirmar si «3 clics» significa tres acciones principales o tres toques literales. El formulario actual usa tres pasos visibles, pero requiere interacciones adicionales para escribir y elegir foto.
2. Crear proyecto Supabase, definir política de identidad, acceso a fotos y retención antes de usar datos reales.
3. Confirmar roles municipales y quién puede aprobar cambios de junta.
4. Validar proveedor/licencia de mapa base y de rutas seguras. El mapa actual es un esquema sin teselas.
5. Confirmar si FCM puede configurarse y probarse; Realtime por sí solo no entrega push con la app cerrada.
6. Probar permisos GPS, galería, marcador telefónico y compilación en Android físico. iOS sigue sin verificar.
