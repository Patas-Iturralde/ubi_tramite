# Splash Screen Personalizado - TuGuiApp

## Descripción
Se ha implementado una pantalla de splash personalizada en Flutter que muestra la imagen `fondo.jpeg` como fondo con una barra de progreso animada y efectos visuales.

## Características Implementadas

### 🎨 **Diseño Visual**
- **Imagen de fondo**: Usa `assets/images/fondo.jpeg` como fondo completo
- **Logo personalizado**: Icono de ubicación con fondo circular y sombra
- **Título y subtítulo**: "TuGuiApp" con descripción
- **Efectos visuales**: Sombras, gradientes y transparencias

### ⚡ **Animaciones**
- **Fade in**: Aparición suave de todos los elementos
- **Barra de progreso**: Animación de 3 segundos con gradiente azul-cyan
- **Texto dinámico**: Cambia según el progreso de carga
- **Transición suave**: Navegación fluida a la pantalla principal

### 🔧 **Funcionalidad**
- **Inicialización de Mapbox**: Se configura el token durante la carga
- **Tiempo de carga simulado**: 3 segundos para mostrar la pantalla
- **Navegación automática**: Redirige a `MapScreen` al completarse
- **Manejo de errores**: Navega de todas formas si hay problemas

## Archivos Creados/Modificados

### Nuevo Archivo
- `lib/screens/splash_screen.dart`: Pantalla de splash personalizada

### Archivos Modificados
- `lib/main.dart`: Cambiado el home de `MapScreen` a `SplashScreen`

## Estructura del Código

### Clase Principal
```dart
class SplashScreen extends ConsumerStatefulWidget
```

### Animaciones
- `_progressController`: Controla la barra de progreso (3 segundos)
- `_fadeController`: Controla la aparición de elementos (500ms)
- `_progressAnimation`: Animación de la barra de progreso
- `_fadeAnimation`: Animación de fade in

### Elementos Visuales
1. **Fondo**: Imagen `fondo.jpeg` con `BoxFit.cover`
2. **Logo**: Icono circular con sombra
3. **Título**: "TuGuiApp" con efectos de sombra
4. **Subtítulo**: Descripción de la aplicación
5. **Barra de progreso**: Gradiente azul-cyan animado
6. **Texto de estado**: Cambia según el progreso

## Flujo de Funcionamiento

1. **Inicio**: Se muestra la pantalla de splash inmediatamente
2. **Fade in**: Los elementos aparecen suavemente
3. **Inicialización**: Se configura Mapbox en segundo plano
4. **Progreso**: La barra se llena durante 3 segundos
5. **Texto dinámico**: 
   - "Cargando..." (0-30%)
   - "Inicializando mapa..." (30-70%)
   - "Casi listo..." (70-100%)
6. **Navegación**: Redirige automáticamente a `MapScreen`

## Ventajas sobre el Splash Nativo

### ✅ **Ventajas**
- **Control total**: Animaciones y efectos personalizados
- **Feedback visual**: Barra de progreso y texto de estado
- **Flexibilidad**: Fácil de modificar y personalizar
- **Consistencia**: Mismo diseño en todas las plataformas
- **Experiencia**: Transición suave y profesional

### 🎯 **Características Únicas**
- Barra de progreso con gradiente
- Texto de estado dinámico
- Logo personalizado con efectos
- Animaciones fluidas
- Manejo de errores robusto

## Personalización

### Cambiar el Logo
```dart
// En splash_screen.dart, línea ~80
child: const Icon(
  Icons.location_on,  // Cambiar por tu icono
  size: 60,
  color: Colors.blue,
),
```

### Cambiar el Tiempo de Carga
```dart
// En splash_screen.dart, línea ~30
duration: const Duration(seconds: 3),  // Cambiar el tiempo
```

### Cambiar los Colores
```dart
// Gradiente de la barra de progreso
gradient: const LinearGradient(
  colors: [
    Colors.blue,    // Color inicial
    Colors.cyan,    // Color final
  ],
),
```

## Comandos para Probar

```bash
# Ejecutar la aplicación
flutter run

# Limpiar y reconstruir si es necesario
flutter clean
flutter pub get
flutter run
```

## Notas Técnicas

- **Responsive**: Se adapta a diferentes tamaños de pantalla
- **Performance**: Animaciones optimizadas con `AnimationController`
- **Memory**: Se liberan los controladores al destruir el widget
- **Navigation**: Usa `pushReplacement` para evitar volver atrás
- **Error Handling**: Navega de todas formas si hay errores

## Próximos Pasos

1. **Probar la aplicación** para ver el splash screen en acción
2. **Personalizar el logo** si deseas cambiar el icono
3. **Ajustar el tiempo** si necesitas más o menos tiempo de carga
4. **Modificar colores** para que coincidan con tu marca

