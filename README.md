# Eli Player

Aplicación multiplataforma (Android, Windows y Linux) construida en Flutter/Dart que replica la experiencia de Seal utilizando **exclusivamente `yt-dlp`** como motor de descarga y conversión. Incluye reproductor integrado (audio/video), cola de descargas, historial y gestión completa de biblioteca.

## Características clave

- Descargas concurrentes con cola, estados y progreso en tiempo real (porcentaje, velocidad, ETA).
- Conversión de audio (MP3/M4A) y video (MP4/MKV) usando únicamente `yt-dlp` + `ffmpeg` embebidos.
- Gestión de playlists: se resuelven los metadatos con `yt-dlp` y se encolan todas las entradas individualmente.
- Guardado de metadatos, miniaturas, historial y biblioteca con SQLite (`sqflite`/`sqflite_common_ffi`).
- Reproductor integrado con `just_audio`/`video_player`, controles de velocidad, volumen, repetir, aleatorio y visualización de onda.
- Reproducción en segundo plano y notificación persistente en Android (via `just_audio_background`).
- Tema oscuro con acentos pastel inspirado en Seal, animaciones suaves (`flutter_animate`).
- Configuración persistente (formato preferido, carpeta destino, tema claro/oscuro) mediante `SettingsService`.
- Panel de logs en tiempo real (disponible mediante `LoggerService.logStream`) y almacenamiento local de bitácoras.

## Estructura del proyecto

```
lib/
  pages/              # Vistas principales (Descargas, Biblioteca)
  widgets/            # Componentes reutilizables (tiles, hojas, player, visualizador)
  services/           # Servicios: descargas, reproductor, ajustes, biblioteca, logger
    yt_dlp/           # Cliente seguro para interactuar con yt-dlp
  models/             # Modelos de dominio (tareas, metadata, configuraciones)
  theme/              # Temas y paletas
  utils/              # Utilidades (formatos, plataforma, launcher)
assets/
  binaries/           # Binarios embebidos de yt-dlp por plataforma
  ffmpeg/             # Binarios embebidos de ffmpeg por plataforma
  images/             # Recursos gráficos (miniaturas por defecto, íconos, etc.)
```

## Binarios requeridos

Por política del repositorio no se incluyen los ejecutables reales. Debes añadirlos manualmente antes de compilar:

```
assets/binaries/linux/yt-dlp
assets/binaries/windows/yt-dlp.exe
assets/binaries/android/yt-dlp

assets/ffmpeg/linux/ffmpeg
assets/ffmpeg/windows/ffmpeg.exe
assets/ffmpeg/android/ffmpeg
```

> **Nota:** puedes dejar archivos vacíos de marcador temporal durante el desarrollo. En ejecución real, la app detecta la ausencia del binario y descarga automáticamente la última versión desde GitHub (puedes desactivar la descarga desde `YtDlpBinaryManager`).

## Configuración inicial

1. Instala Flutter 3.19+ y Dart 3.2+.
2. Asegúrate de que `flutter doctor` esté limpio.
3. Ejecuta `flutter pub get`.
4. Opcional: coloca los binarios descritos arriba para trabajar sin conexión.

### Android

- Se usa un canal nativo (`MethodChannel` `eli_player/system`) para abrir la carpeta de destino. Revisa `android/app/src/main/kotlin/.../MainActivity.kt`.
- Permisos de almacenamiento se gestionan con `permission_handler`; asegúrate de actualizar los `AndroidManifest` según sea necesario.

### Windows / Linux

- Se utiliza `sqflite_common_ffi` + `sqlite3_flutter_libs` para ofrecer SQLite nativo.
- Abrir carpeta de descarga se realiza con `explorer`/`xdg-open`/`open -R` según plataforma.

## Servicios principales

### DownloaderService

- Resuelve metadatos con `YtDlpClient.resolveMetadata`.
- Gestiona cola, reintentos y estados.
- Ejecuta `yt-dlp` mediante `SafeProcessRunner` (ningún `Process.run`, ni shell).
- Copia/descarga los binarios con `YtDlpBinaryManager` y cachea miniaturas.
- Guarda entradas en `LibraryService` y notifica a `PlaybackService`.

### PlaybackService

- Centraliza la reproducción de audio/video, controla volumen, velocidad, loop y shuffle.
- Integra `just_audio_background` para notificaciones y reproducción en segundo plano.
- Exponer `positionStream`, `volume`, `speed`, `isPlaying` para la UI.

## Scripts útiles

En `scripts/` puedes añadir tareas de automatización (por ejemplo para empaquetar binarios personalizados). Actualmente es una carpeta reservada.

## Próximos pasos sugeridos

- Reemplazar los archivos de marcador por binarios reales, asegurando permisos de ejecución (la app hace `chmod +x` automáticamente en Unix).
- Ejecutar `flutter pub get` y `flutter run` en las plataformas deseadas.
- Añadir íconos, nombre de paquete y configuraciones específicas según la plataforma objetivo.
- Ampliar el panel de logs en la UI usando `LoggerService.logStream` si se requiere depuración avanzada.

---

Proyecto generado por Codex (GPT-5). Cualquier duda o extensión adicional, avísame.
