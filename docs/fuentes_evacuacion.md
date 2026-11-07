# Fuentes para la capa de emergencia

## Zona piloto: Lurigancho-Chosica, Lima

Se eligió Lurigancho-Chosica porque INDECI publica varios planos sectoriales con rutas y zonas seguras: [Quebrada El Pedregal](https://portal.indeci.gob.pe/wp-content/uploads/2018/09/Chosica.pdf), [Quebrada Quirio / Nicolás de Piérola](https://portal.indeci.gob.pe/wp-content/uploads/2018/09/QuebradaQuirio.pdf) y [Mariscal Castilla](https://portal.indeci.gob.pe/wp-content/uploads/2018/09/AAHHMariscalCastilla.pdf). La biblioteca [SIGRID de CENEPRED](https://sigrid.cenepred.gob.pe/sigridv3/documento/biblioteca?c=+Lurigancho-Chosica) también cataloga mapas sectoriales.

Para Chaclacayo se encontró un [plan distrital 2023–2027](https://www.gob.pe/institucion/munichaclacayo/normas-legales/4994128-184-2023-alc-mdch), pero no una colección sectorial comparable de rutas georreferenciables en las fuentes consultadas. Para Ate tampoco se encontró una colección sectorial comparable en esas fuentes. Esta comparación no afirma que no existan otros planes municipales.

Los tres planos de INDECI consultados llevan fecha de elaboración de 2015. Son documentos PDF y no contienen una capa digital de coordenadas lista para importar. Por ello la app enlaza a los planos como referencia histórica, sin inferir ubicaciones o rutas de sus imágenes. La capa interactiva consulta `emergency_resources` y solo muestra registros no ficticios con coordenadas, fuente y fecha de verificación. No se insertan puntos seguros hasta contrastar las coordenadas y la vigencia con Defensa Civil.

## Requisitos antes de publicar puntos

1. Obtener geodatos o coordenadas verificadas de la autoridad competente para cada sector.
2. Registrar peligro cubierto, fecha de revisión, fuente y responsable. Una zona segura ante huaico no es automáticamente segura ante sismo u otro evento.
3. Revisar el sitio físicamente y mantener un proceso de actualización y retiro.
