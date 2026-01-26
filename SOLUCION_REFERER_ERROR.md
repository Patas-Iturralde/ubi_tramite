# Solución: RefererNotAllowedMapError

Este error significa que tu API key de Google Maps tiene restricciones de dominio y `localhost` no está permitido.

## Solución Rápida:

### Opción 1: Permitir localhost (Recomendado para desarrollo)

1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Ve a **"APIs y servicios"** > **"Credenciales"**
3. Haz clic en tu API key
4. En **"Restricciones de aplicación"**, asegúrate de que esté seleccionado **"Sitios web HTTP"**
5. En **"Restricciones de sitio web"**, haz clic en **"+ AGREGAR UN ELEMENTO"**
6. Agrega estas URLs:
   - `http://localhost:*` (permite cualquier puerto en localhost)
   - O específicamente: `http://localhost:55448/` (el puerto que estás usando)
7. Haz clic en **"Guardar"**

### Opción 2: Quitar restricciones temporalmente (Solo para desarrollo)

⚠️ **ADVERTENCIA**: Esto permite que cualquier sitio use tu API key. Solo hazlo para desarrollo local.

1. Ve a tu API key en Google Cloud Console
2. En **"Restricciones de aplicación"**, selecciona **"Ninguna"**
3. Haz clic en **"Guardar"**
4. **IMPORTANTE**: Vuelve a poner las restricciones antes de desplegar a producción

## Para Producción (Firebase Hosting):

Cuando despliegues a Firebase Hosting, también necesitarás agregar estos dominios:

1. `https://tuguiapp-5364f.web.app`
2. `https://tuguiapp-5364f.firebaseapp.com`
3. Si tienes un dominio personalizado: `https://tudominio.com`

## Verificar que funciona:

1. Guarda los cambios en Google Cloud Console
2. Espera unos segundos (puede tardar hasta 1 minuto en propagarse)
3. Recarga la página en tu navegador (Ctrl+R o Cmd+R)
4. El mapa debería cargarse correctamente

## Nota sobre localhost:

El patrón `http://localhost:*` permite cualquier puerto en localhost, lo cual es útil porque Flutter puede usar diferentes puertos cada vez que ejecutas la app.

