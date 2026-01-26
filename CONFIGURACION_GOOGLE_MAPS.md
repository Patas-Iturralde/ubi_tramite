# Configuración de Google Maps para Web

Para que el mapa funcione en la versión web, necesitas configurar una API key de Google Maps.

## Pasos para obtener la API key:

1. **Ve a Google Cloud Console**
   - Visita: https://console.cloud.google.com/

2. **Crea o selecciona un proyecto**
   - Si no tienes un proyecto, crea uno nuevo
   - Si ya tienes uno, selecciónalo

3. **Habilita la API de Google Maps JavaScript**
   - Ve a "APIs y servicios" > "Biblioteca"
   - Busca "Maps JavaScript API"
   - Haz clic en "Habilitar"

4. **Crea una API key**
   - Ve a "APIs y servicios" > "Credenciales"
   - Haz clic en "Crear credenciales" > "Clave de API"
   - Copia la API key generada

5. **Configura restricciones (recomendado para producción)**
   - Haz clic en la API key creada
   - En "Restricciones de aplicación", selecciona "Sitios web HTTP"
   - Agrega tu dominio (ej: `tuguiapp-5364f.web.app` o `tudominio.com`)

## Configurar la API key en el proyecto:

### 1. En `web/index.html`:
Reemplaza `YOUR_GOOGLE_MAPS_API_KEY` con tu API key:

```html
<script src="https://maps.googleapis.com/maps/api/js?key=TU_API_KEY_AQUI&libraries=places"></script>
```

### 2. En `lib/config/google_maps_config.dart`:
Opcionalmente, también puedes configurarla aquí (aunque no es necesaria si ya está en index.html):

```dart
static const String apiKey = 'TU_API_KEY_AQUI';
```

## Notas importantes:

- **Plan gratuito**: Google Maps ofrece un plan gratuito con $200 USD de crédito mensual
- **Límites**: El plan gratuito permite aproximadamente 28,000 cargas de mapa al mes
- **Facturación**: Después del crédito gratuito, se cobra por uso
- **Seguridad**: Siempre configura restricciones de dominio en producción

## Verificar que funciona:

1. Ejecuta la app en web:
   ```bash
   flutter run -d chrome
   ```

2. Deberías ver el mapa de Google Maps cargándose correctamente

3. Si ves un error, verifica:
   - Que la API key esté correctamente configurada
   - Que la API de Maps JavaScript esté habilitada
   - Que las restricciones de dominio permitan tu dominio (si las configuraste)

## Solución de problemas:

### Error: "This page can't load Google Maps correctly"
- Verifica que la API key esté correcta
- Asegúrate de que la API de Maps JavaScript esté habilitada
- Revisa las restricciones de dominio

### Error: "RefererNotAllowedMapError"
- Tu dominio no está en la lista de sitios permitidos
- Agrega tu dominio en las restricciones de la API key

### El mapa no carga
- Abre la consola del navegador (F12) para ver errores
- Verifica que el script de Google Maps se esté cargando correctamente

