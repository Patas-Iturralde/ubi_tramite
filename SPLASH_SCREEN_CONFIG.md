# Configuración del Splash Screen

## Descripción
Se ha configurado un splash screen nativo para la aplicación UbiTrámite usando la imagen `fondo.jpeg` como fondo.

## Configuración Implementada

### Archivos Modificados
- `pubspec.yaml`: Se agregó la dependencia `flutter_native_splash` y la configuración del splash screen
- Se agregó `assets/images/fondo.jpeg` a los assets del proyecto

### Configuración del Splash Screen
```yaml
flutter_native_splash:
  image: assets/images/fondo.jpeg
  color: "#1a1a2e"
  android: true
  ios: true
```

### Archivos Generados

#### Android
- `android/app/src/main/res/drawable/launch_background.xml`
- `android/app/src/main/res/drawable-v21/launch_background.xml`
- `android/app/src/main/res/values/styles.xml`
- `android/app/src/main/res/values-night/styles.xml`
- `android/app/src/main/res/values-v31/styles.xml`
- `android/app/src/main/res/values-night-v31/styles.xml`
- Imágenes de splash en diferentes resoluciones:
  - `drawable-hdpi/splash.png`
  - `drawable-mdpi/splash.png`
  - `drawable-xhdpi/splash.png`
  - `drawable-xxhdpi/splash.png`
  - `drawable-xxxhdpi/splash.png`

#### iOS
- `ios/Runner/Assets.xcassets/LaunchBackground.imageset/`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/`
- `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- `ios/Runner/Info.plist` (actualizado)

## Cómo Funciona

1. **Al iniciar la aplicación**: El sistema operativo muestra el splash screen nativo antes de que Flutter se cargue completamente.

2. **Duración**: El splash screen se muestra hasta que la aplicación Flutter esté lista para mostrar su interfaz.

3. **Compatibilidad**: Funciona tanto en Android como en iOS, con soporte para diferentes resoluciones de pantalla.

## Comandos Útiles

### Regenerar el Splash Screen
Si necesitas cambiar la imagen o configuración:
```bash
flutter pub run flutter_native_splash:create
```

### Remover el Splash Screen
```bash
flutter pub run flutter_native_splash:remove
```

### Limpiar y Reconstruir
```bash
flutter clean
flutter pub get
flutter pub run flutter_native_splash:create
```

## Notas Importantes

- La imagen `fondo.jpeg` se redimensiona automáticamente para diferentes resoluciones de pantalla
- El color de fondo `#1a1a2e` se usa como respaldo si la imagen no cubre toda la pantalla
- El splash screen es completamente nativo, por lo que se muestra inmediatamente al abrir la aplicación
- No requiere código adicional en la aplicación Flutter

## Próximos Pasos

1. Ejecutar la aplicación para ver el splash screen en acción
2. Probar en diferentes dispositivos para verificar que se vea correctamente
3. Si es necesario, ajustar la configuración en `pubspec.yaml` y regenerar

