# Sentinel

Aplicacion Flutter enfocada en seguridad personal. Incluye alerta SOS, captura de evidencia, historial de incidentes, contactos de emergencia, directorio de apoyo y chatbot con Groq.

## Que Incluye

- Registro e inicio de sesion
- Configuracion obligatoria del primer contacto de emergencia
- Boton SOS con ubicacion, audio y video
- Apartado de evidencias para organizar incidentes y preparar denuncias
- Directorio de centros de apoyo con rutas y llamadas
- Chatbot conectado a Groq
- Personalizacion de icono y nombre de la app en Android

## Requisitos

- Flutter SDK compatible con Dart `3.11.x`
- VS Code con extensiones de Flutter y Dart
- Git
- Para correr en Android:
  - Android SDK
  - emulador o dispositivo fisico
- Opcional:
  - clave de Groq para el chatbot

## Instalacion Rapida En VS Code

### 1. Instala Flutter

Descarga el SDK oficial de Flutter y descomprimelo en una ruta simple, por ejemplo:

```text
C:\src\flutter
```

### 2. Configura Flutter En Tu Terminal

Opcion A: agrega Flutter al `PATH`.

Ruta recomendada:

```text
C:\src\flutter\bin
```

Opcion B: usa la variable `FLUTTER_ROOT` si no quieres tocar el `PATH`.

Ejemplo en PowerShell:

```powershell
$env:FLUTTER_ROOT="C:\src\flutter"
```

### 3. Abre El Proyecto En VS Code

```bash
git clone <TU_REPO>
cd test01
code .
```

El repositorio incluye recomendaciones de extensiones en `.vscode/extensions.json`, asi que VS Code deberia sugerirte instalar:

- Flutter
- Dart

### 4. Verifica Tu Entorno

Si `flutter` ya esta en `PATH`:

```bash
flutter doctor
flutter pub get
```

Si no esta en `PATH`, usa los scripts del repo:

```bash
flutter_safe.cmd doctor
flutter_safe.cmd pub get
```

### 5. Ejecuta La App

Sin Groq:

```bash
flutter_safe.cmd run
```

Con Groq:

```bash
flutter_groq.cmd run
```

## Configuracion Del Chatbot Con Groq

Este proyecto no debe subir claves reales al repositorio.

1. Crea tu archivo local:

```bash
copy .env.groq.example .env.groq.local
```

2. Completa tus valores:

```env
GROQ_API_KEY=pega_aqui_tu_clave_real
GROQ_CHAT_MODEL=llama-3.3-70b-versatile
```

3. Ejecuta:

```bash
flutter_groq.cmd run
```

Tambien puedes compilar:

```bash
flutter_groq.cmd build apk --debug
```

## Configuracion Del Backend

Por defecto la app usa este backend:

```text
http://144.22.43.169:3000
```

Si quieres apuntar a otro backend:

```bash
flutter run --dart-define=BACKEND_URL=http://localhost:3000
```

O desde `.env.groq.local` si usas `flutter_groq.cmd`:

```env
BACKEND_URL=http://localhost:3000
```

## Comandos Utiles

```bash
flutter_safe.cmd doctor
flutter_safe.cmd pub get
flutter_safe.cmd run
flutter_safe.cmd analyze
flutter_safe.cmd test
flutter_safe.cmd build apk --debug
flutter_groq.cmd run
```

## Estructura Del Proyecto

```text
lib/
  core/
    constants/
    network/
    routes/
    services/
    theme/
  features/
    auth/
    chatbot/
    directory/
    education/
    emergency/
    evidence/
    home/
    profile/
  shared/
```

## Archivos Locales Ignorados

El `.gitignore` ya evita subir por error:

- `.env.groq.local` y otros `.env` locales
- `.dart_tool/`, `build/`, `coverage/`
- `.idea/` y configuraciones locales de VS Code
- archivos firmados como `*.jks`, `*.keystore`
- archivos exportados como `*.apk`, `*.aab`, `*.ipa`
- archivos comprimidos como `*.zip`, `*.rar`, `*.7z`

## Checklist Antes De Hacer Commit Y Push

1. Verifica que no haya claves reales en el repo.
2. Revisa el estado del proyecto:

```bash
git status
```

3. Corre validaciones:

```bash
flutter_safe.cmd analyze
flutter_safe.cmd test
```

4. Haz commit y push:

```bash
git add .
git commit -m "feat: actualiza el proyecto"
git push origin <tu-rama>
```

## Notas De Portabilidad

- `flutter_safe.cmd` permite trabajar incluso si Flutter no esta en `PATH`, siempre que definas `FLUTTER_ROOT`.
- `flutter_groq.cmd` lee la configuracion desde `.env.groq.local`.
- El proyecto puede abrirse en otra maquina sin rutas fijas locales.
- `pubspec.lock` se mantiene en el repo porque esta app es una aplicacion Flutter, no una libreria.

## Seguridad

- No subas claves reales de Groq al repositorio.
- No distribuyas builds de produccion con claves embebidas en el cliente.
- Para produccion, lo recomendable es mover la integracion con Groq al backend.

## Licencia

Agrega aqui la licencia que vayas a usar antes de publicar el repositorio.
