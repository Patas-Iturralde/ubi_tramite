# Guía de Despliegue Web en Firebase Hosting

Esta guía te ayudará a publicar tu aplicación Flutter en Firebase Hosting.

## Prerrequisitos

1. **Node.js instalado** (para Firebase CLI)
2. **Cuenta de Firebase** con el proyecto `tuguiapp-5364f`
3. **Flutter SDK** instalado y configurado

## Paso 1: Instalar Firebase CLI

Abre tu terminal y ejecuta:

```bash
npm install -g firebase-tools
```

Si no tienes npm instalado, primero instala Node.js desde [nodejs.org](https://nodejs.org/)

## Paso 2: Iniciar sesión en Firebase

```bash
firebase login
```

Esto abrirá tu navegador para autenticarte con tu cuenta de Google asociada a Firebase.

## Paso 3: Verificar el proyecto

Verifica que estés usando el proyecto correcto:

```bash
firebase use --add
```

Selecciona el proyecto `tuguiapp-5364f` cuando te lo pida.

O verifica el proyecto actual:

```bash
firebase use
```

## Paso 4: Construir la aplicación web

Antes de desplegar, necesitas construir la versión web de tu app Flutter:

```bash
flutter build web --release
```

Este comando generará los archivos estáticos en la carpeta `build/web/`.

**Nota importante**: Si tu app usa Mapbox o servicios que requieren configuración específica para web, asegúrate de que estén configurados correctamente.

## Paso 5: Verificar la configuración

Los siguientes archivos ya están configurados:

- ✅ `.firebaserc` - Configuración del proyecto Firebase
- ✅ `firebase.json` - Configuración de hosting

## Paso 6: Desplegar en Firebase Hosting

Una vez construida la app, despliega con:

```bash
firebase deploy --only hosting
```

Este comando:
- Subirá los archivos de `build/web/` a Firebase Hosting
- Te dará una URL donde estará disponible tu app (algo como: `https://tuguiapp-5364f.web.app`)

## Paso 7: Verificar el despliegue

Después del despliegue, Firebase te mostrará la URL de tu aplicación. Visítala para verificar que todo funcione correctamente.

También puedes ver tus sitios desplegados en la [Consola de Firebase](https://console.firebase.google.com/project/tuguiapp-5364f/hosting)

## Comandos útiles

### Ver el estado del hosting
```bash
firebase hosting:sites:list
```

### Ver el historial de despliegues
```bash
firebase hosting:channel:list
```

### Desplegar a un canal de preview (para testing)
```bash
firebase hosting:channel:deploy preview-channel-name
```

### Abrir la consola de Firebase
```bash
firebase open hosting
```

## Actualizaciones futuras

Para actualizar tu aplicación web después de hacer cambios:

1. Construye la nueva versión:
   ```bash
   flutter build web --release
   ```

2. Despliega nuevamente:
   ```bash
   firebase deploy --only hosting
   ```

## Solución de problemas

### Error: "Firebase CLI not found"
- Asegúrate de haber instalado Firebase CLI: `npm install -g firebase-tools`

### Error: "Not authorized"
- Ejecuta `firebase login` nuevamente

### Error: "Project not found"
- Verifica que el proyecto `tuguiapp-5364f` exista en tu consola de Firebase
- Ejecuta `firebase use --add` para seleccionar el proyecto

### La app no carga correctamente
- Verifica que `flutter build web --release` se haya ejecutado sin errores
- Revisa la consola del navegador para ver errores de JavaScript
- Asegúrate de que todas las dependencias estén configuradas para web

### Problemas con Mapbox en web
- Verifica que tengas la configuración correcta de Mapbox para web
- Revisa que las claves de API estén configuradas en `firebase_options.dart`

## Configuración adicional (opcional)

### Dominio personalizado

Si quieres usar tu propio dominio:

1. Ve a Firebase Console > Hosting
2. Haz clic en "Agregar dominio personalizado"
3. Sigue las instrucciones para verificar tu dominio

### Variables de entorno

Si necesitas configurar variables de entorno para producción, puedes hacerlo en la consola de Firebase o usar Firebase Functions.

## Notas importantes

- La primera vez que despliegues, puede tardar unos minutos
- Los archivos estáticos se cachean, así que los cambios pueden tardar unos minutos en aparecer
- Firebase Hosting tiene un plan gratuito generoso, pero revisa los límites en la documentación oficial

