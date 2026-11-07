# Reto oficial — Hackathon UTP × El Comercio 2026

> **Documento de referencia para el equipo Vibe_Pers.**  
> **Origen:** `Reto de la chakaton.docx` (4 páginas, material entregado por la organización).  
> **Propósito de este archivo:** recopilar y organizar **lo que solicita el reto**, sin mezclarlo con la solución, tecnologías o decisiones internas del equipo.  
> **Estado:** especificación del **reto**, no documentación de implementación.

## 1. Planteamiento del reto

Desarrollar, **en 48 horas**, una aplicación dirigida a ciudadanos que les ayude a **encontrar productos y servicios cercanos a su zona de residencia**, recomendados por otros vecinos y accesibles con **costos mínimos y evitando desplazamientos largos**. La solución también debe facilitar **intercambios solidarios** y **coordinación de apoyo comunitario durante emergencias**.

En otras palabras, la solución debe conectar la **economía local de proximidad** con una **red de apoyo vecinal**, tanto para necesidades cotidianas como para situaciones críticas.

**Fuente:** apartado «Reto», página 1 del documento entregado.

## 2. Personas y necesidades a las que responde

El documento se refiere a **ciudadanos y vecinos de una zona o barrio**. Sus necesidades principales son:

- Conocer productos, oficios, profesiones y servicios que se ofrecen **cerca de donde viven**.
- Consultar **recomendaciones hechas por vecinos** de la misma zona para orientar sus decisiones.
- **Solicitar y ofrecer ayuda sin dinero**, mediante préstamos, donaciones, intercambio de habilidades y otras formas de colaboración.
- Identificar **servicios, recursos, necesidades y grupos de apoyo** durante una emergencia.

> Esta sección sintetiza las necesidades descritas en el reto; el documento **no define perfiles de usuario, métodos de registro ni permisos de acceso concretos**.

## 3. Funciones principales exigidas

Las siguientes capacidades aparecen expresamente en el apartado «Características funcionales» del documento:

1. **Información local recomendada:** mostrar información sobre productos y servicios próximos a la zona de residencia.
2. **Promoción y recomendación vecinal:** facilitar que los vecinos promuevan servicios y compartan recomendaciones.
3. **Solicitudes y ofrecimientos solidarios:** permitir pedir y ofrecer ayuda e intercambios entre vecinos.
4. **Apoyo en emergencias:** identificar servicios y grupos de ayuda disponibles cuando ocurre una emergencia.
5. **Coordinación de ayuda:** permitir organizar necesidades de apoyo y recursos entre vecinos durante emergencias.
6. **Geolocalización:** ubicar servicios, recursos y necesidades de apoyo.
7. **Tutorial de uso:** incorporar una explicación para aprender a utilizar la aplicación.
8. **Enfoque móvil y publicación rápida:** publicar en **un máximo de tres clics**.
9. **Funcionamiento online y offline:** contemplar operación con y sin conexión a internet.
10. **Usabilidad y accesibilidad:** ofrecer una experiencia intuitiva y accesible para vecinos del barrio.

**Fuente:** apartados «Características funcionales», páginas 2 y 3.

## 4. Áreas de contenido que debe cubrir la aplicación

### 4.1. Servicios de Proximidad (Economía Local)

**Propósito en el documento:** conectar la oferta de trabajo local e identificar oficios y profesiones útiles en el día a día y durante emergencias.

**Uso cotidiano:**

- Directorio de oficios y profesiones del barrio.
- Ejemplos indicados: gasfitería, carpintería, electricidad, paseadores de mascotas, clases y cerrajería.
- Referencias de confianza mediante el mecanismo denominado **«Visto Bueno Vecinal»**, basado en recomendaciones de vecinos de la misma zona.

**Durante una emergencia:**

- Directorio de servicios y grupos de apoyo disponibles para atender situaciones críticas, complejas o de emergencia.

**Fuente:** «Contenido — 1. Servicios de Proximidad (Economía Local)», página 2.

### 4.2. Cadena de Favores & Red de Solidaridad (Economía Solidaria)

**Propósito en el documento:** disponer de un espacio colaborativo para resolver necesidades **sin dinero**.

**Uso cotidiano:**

- Muro comunitario de necesidades y ofrecimientos.
- Préstamo de herramientas.
- Ayuda temporal.
- Donación de materiales.
- Intercambio de habilidades.
- Movilidad solidaria.

**Durante una emergencia:**

- Tablero de ayuda humanitaria.
- Reportes geolocalizados de vecinos en situación de vulnerabilidad.
- Espacio para coordinar y compartir recursos críticos.

**Fuente:** «Contenido — 2. Cadena de Favores & Red de Solidaridad (Economía Solidaria)», página 2.

## 5. Requisitos transversales que no se deben olvidar

| Requisito del reto | Qué exige el documento | Qué **no** define el documento |
|---|---|---|
| Cercanía | Información útil para la zona de residencia | Radio exacto, delimitación territorial o proveedor de mapas |
| «Visto Bueno Vecinal» | Recomendaciones de vecinos de la misma zona | Fórmula de puntuación, antiabuso o mecanismo de verificación |
| Solidaridad | Ayuda e intercambios sin dinero | Estados, moderación y seguimiento de solicitudes |
| Emergencias | Identificación y coordinación de servicios, recursos y grupos | Botones SOS, envío automático de alertas o integración con autoridades |
| Geolocalización | Ubicación de servicios, recursos y necesidades | Tecnología GPS/mapas y precisión requerida |
| Publicación rápida | Máximo **3 clics para publicar** | Qué formularios específicos debe tener cada publicación |
| Online y offline | Funcionalidad en ambos escenarios | Cuáles acciones se ejecutan offline y cuáles requieren sincronización |
| Tutorial | Guía para usar la aplicación | Formato o cantidad de pantallas |
| Accesibilidad | Interfaz intuitiva y accesible | Estándar técnico específico o métricas concretas |

> **Importante para las IA:** completar estos aspectos será tarea de la **documentación de solución de Vibe_Pers**, no de este archivo de requisitos oficiales. Nunca presentar una decisión interna como obligación del organizador.

## 6. Criterios de evaluación — funcionalidad y propuesta

El documento indica que se evaluarán los **aspectos funcionales, técnicos y el valor de la solución propuesta** para seleccionar a los finalistas.

Se mencionan expresamente los siguientes criterios:

- **Usabilidad:** sistema intuitivo, sin dificultades en sus elementos.
- **Confiabilidad:** funcionamiento estable, acorde con el objetivo para el que se creó.
- **Escalabilidad:** posibilidad de incorporar funcionalidades más complejas a futuro.
- **Propuesta:** exposición de la idea o proyecto considerando riesgos y beneficios para la institución.
- **Código y programa:** interfaz y funcionalidad implementadas completamente.
- **Innovación y creatividad:** solución original, con ideas nuevas y exitosas que respondan a la problemática.

**Fuente:** «Criterios de evaluación — Sobre la funcionalidad del proyecto», página 1.

> El material **no asigna porcentajes ni puntajes numéricos** a estos criterios. No inventar ponderaciones.

## 7. Criterios de evaluación — presentación

El documento también menciona los siguientes aspectos de presentación:

- **Comunicación y rol del equipo:** lenguaje adecuado al contexto técnico o formal, fluidez, continuidad y dominio del contenido.
- **Manejo del tiempo:** respetar la duración asignada y demostrar una planificación clara.
- **Recursos audiovisuales:** emplear apoyos visuales, como imágenes, texto y gráficos.
- **Organización de la presentación:** exposición clara y ordenada, con propósito y conclusiones.
- **Respuestas a preguntas:** capacidad para contestar las consultas de los evaluadores.

**Fuente:** «Criterios de evaluación — Sobre la presentación del proyecto», página 4.

## 8. Cronograma indicado en el documento del reto

| Hito | Fecha y horario |
|---|---|
| Etapa de desarrollo | **Viernes 6 al domingo 8 de noviembre de 2026**; duración de 48 horas |
| Presentación de propuestas | **10, 11 y 12 de noviembre**, a las **7:00 p. m.** |
| Elección de finalistas | **13 de noviembre** |
| Sustentación de finalistas | **Martes 17 de noviembre, 6:00–8:30 p. m.** |
| Resultados y premiación | **Martes 17 de noviembre, 8:30 p. m.** |

**Fuente:** «Cronograma», página 3. Para detalles operativos de acceso, nube y entrega, consultar por separado el documento de la reunión de inducción.

## 9. Límites de esta especificación

El documento oficial **no impone explícitamente**:

- Flutter, React, Android nativo, iOS nativo ni otro framework concreto.
- PostgreSQL, Supabase, Firebase u otra base de datos o servicio cloud.
- Registro con fotografía de DNI, carné de extranjería o pasaporte.
- Roles específicos de vecinos, líderes y municipalidades.
- Métodos de verificación de identidad o de recomendaciones.
- Botón SOS de dos dedos ni una duración fija para compartir ubicación.
- WhatsApp como canal de contacto obligatorio.
- Un modelo concreto de marketplace, pagos o comisiones.
- Un conjunto específico de mapas, servicios externos o APIs.

Estas decisiones pueden aparecer en `Vibe_Pers_Documentacion_Funcional_Tecnica_MVP.md` como **diseño del equipo**, pero **no deben confundirse con el enunciado original**.

## 10. Checklist de cobertura del reto para el equipo de desarrollo

> Lista de comprobación **derivada del contenido oficial**. No es una rúbrica nueva ni introduce nuevas obligaciones.

- [ ] Los ciudadanos pueden descubrir productos y servicios próximos.
- [ ] Pueden consultar y compartir recomendaciones vecinales.
- [ ] Existe un mecanismo de solicitudes y ofrecimientos de ayuda solidaria sin dinero.
- [ ] Se pueden identificar servicios y grupos de apoyo durante emergencias.
- [ ] Se pueden coordinar necesidades y recursos durante emergencias.
- [ ] Se geolocalizan servicios, recursos o necesidades de apoyo.
- [ ] Existe un tutorial de uso.
- [ ] Se puede publicar en un máximo de tres clics.
- [ ] Se contempla funcionamiento online y offline.
- [ ] La aplicación es intuitiva y accesible.
- [ ] La aplicación es estable y demuestra una funcionalidad real.
- [ ] El equipo puede explicar el valor, los riesgos, la escalabilidad y la innovación.

---

### Instrucción de uso para otras IA

1. **Leer este documento primero:** contiene el reto y los criterios expuestos por los organizadores.
2. **Leer después la documentación funcional de Vibe_Pers:** contiene las decisiones tomadas por el equipo.
3. **Ante un conflicto:** señalar la discrepancia y dar prioridad a los requisitos del reto oficial; consultar al equipo antes de cambiar una decisión confirmada.
4. **No inventar** funcionalidades, ponderaciones, criterios de aceptación ni integraciones oficiales.
5. **Mantener trazabilidad:** cuando se implemente una función, relacionarla con la sección correspondiente de este documento.

*Documento organizado a partir de las imágenes y textos contenidos en `Reto de la chakaton.docx`. Es una síntesis fiel de contenido, no una transcripción literal certificada.*
