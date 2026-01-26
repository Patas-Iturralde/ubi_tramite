# Pasos para Crear la API Key de Google Maps

## Paso 1: Ir a Credenciales

1. En Google Cloud Console, ve a **"APIs y servicios"** en el menú lateral
2. Haz clic en **"Credenciales"**

## Paso 2: Crear la API Key

1. En la parte superior de la página, haz clic en **"+ CREAR CREDENCIALES"**
2. Selecciona **"Clave de API"** del menú desplegable

## Paso 3: Copiar la API Key

1. Se abrirá un diálogo con tu nueva API key
2. **¡IMPORTANTE!** Copia la API key inmediatamente (se verá algo como: `AIzaSyC...`)
3. Haz clic en **"Cerrar"** (no en "Restringir clave" todavía)

## Paso 4: Configurar Restricciones (Recomendado)

1. En la lista de credenciales, haz clic en el nombre de tu API key recién creada
2. En **"Restricciones de aplicación"**, selecciona **"Sitios web HTTP"**
3. En **"Restricciones de sitio web"**, haz clic en **"+ AGREGAR UN ELEMENTO"**
4. Agrega tu dominio:
   - Para desarrollo local: `http://localhost:*` (permite cualquier puerto)
   - Para Firebase Hosting: `https://tuguiapp-5364f.web.app` y `https://tuguiapp-5364f.firebaseapp.com`
   - Para tu dominio personalizado (si lo tienes): `https://tudominio.com`

5. En **"Restricciones de API"**, selecciona **"Limitar clave"**
6. En el selector, marca solo **"Maps JavaScript API"**
7. Haz clic en **"Guardar"**

## Paso 5: Configurar en tu Proyecto

1. Abre el archivo `web/index.html` en tu proyecto
2. Busca esta línea:
   ```html
   <script src="https://maps.googleapis.com/maps/api/js?key=YOUR_GOOGLE_MAPS_API_KEY&libraries=places"></script>
   ```
3. Reemplaza `YOUR_GOOGLE_MAPS_API_KEY` con tu API key real
4. Debería quedar algo así:
   ```html
   <script src="https://maps.googleapis.com/maps/api/js?key=AIzaSyC_Tu_API_KEY_AQUI&libraries=places"></script>
   ```

## Paso 6: Verificar

1. Ejecuta tu app en web:
   ```bash
   flutter run -d chrome
   ```
2. Deberías ver el mapa de Google Maps cargándose correctamente

## Notas Importantes:

- **Nunca compartas tu API key públicamente** (no la subas a repositorios públicos)
- **Configura restricciones** para evitar uso no autorizado
- **Monitorea el uso** en Google Cloud Console para evitar cargos inesperados
- El plan gratuito incluye $200 USD de crédito mensual (aproximadamente 28,000 cargas de mapa)

## Solución de Problemas:

### Error: "This page can't load Google Maps correctly"
- Verifica que la API key esté correctamente copiada en `index.html`
- Asegúrate de que no haya espacios extra antes o después de la key

### Error: "RefererNotAllowedMapError"
- Tu dominio no está en la lista de sitios permitidos
- Agrega tu dominio en las restricciones de la API key (Paso 4)

### El mapa no aparece
- Abre la consola del navegador (F12) y revisa los errores
- Verifica que la Maps JavaScript API esté habilitada
- Asegúrate de que la API key tenga permisos para Maps JavaScript API

