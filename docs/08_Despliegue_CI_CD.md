# 08 · Despliegue, CI/CD y APK

## 1. Subir a GitHub

```bash
unzip monte_carlo_simulator.zip && cd monte_carlo_simulator
git init && git add . && git commit -m "Monte Carlo Simulator 1.0.0"
git branch -M main
git remote add origin https://github.com/<usuario>/monte_carlo_simulator.git
git push -u origin main
```

## 2. Workflows

### `ci.yml` (push, PR, manual)

1. **Contenido y verificación estática** (Python 3.12 + tree-sitter): `verify_content.py`, `static_check.py`.
2. **Analizar y probar** (JDK 17 + Flutter 3.35.4):
   ```bash
   flutter create --platforms=android,ios --org com.educationalfactory --project-name monte_carlo_simulator .
   python3 tool/postcreate.py
   flutter pub get
   dart run flutter_launcher_icons
   flutter analyze --no-fatal-infos --no-fatal-warnings
   flutter test --reporter expanded
   ```

### `build-apk.yml` (push a main, etiquetas `v*`, manual)

Genera plataformas, aplica `postcreate.py` (con firma si hay secretos), crea íconos y compila:

- `monte-carlo-simulator-universal.apk`
- `monte-carlo-simulator-arm64-v8a.apk`, `-armeabi-v7a.apk`, `-x86_64.apk`

Se suben como artefacto `monte-carlo-simulator-apk` (30 días). En una etiqueta `v*` se publica además un *release* con los APK.

## 3. Firma de producción (opcional)

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w0 upload-keystore.jks > keystore.b64
```

Secretos del repositorio (*Settings → Secrets and variables → Actions*): `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Sin ellos, el APK usa la firma de depuración (instalable, no publicable en Play Store).

## 4. Qué hace `tool/postcreate.py`

- Etiqueta visible «Monte Carlo» (Android e iOS).
- Permiso `INTERNET` en el manifiesto principal (solo lo usa la IA opcional).
- Firma de producción en `build.gradle.kts` (o `build.gradle`) si existen los secretos; declaraciones después de `plugins {}`.
- Idempotente: puede ejecutarse varias veces.

## 5. Versiones

| Componente | Versión | Nota |
|---|---|---|
| Flutter | 3.35.4 (fijada) | Dart 3.9 |
| JDK | 17 (Temurin) | |
| AGP / Gradle / Kotlin | los de la plantilla de 3.35.4 | No se fijan a mano: una combinación fija envejece antes que la app |
| flutter_riverpod | ^2.6.1 | |
| shared_preferences | ^2.3.2 | |
| flutter_launcher_icons | ^0.14.4 (dev) | |

## 6. Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `flutter create` crea `test/widget_test.dart` con `MyApp` | No debería: el repositorio ya trae `test/widget_test.dart` | Verificar que el archivo existe antes de `create` |
| `flutter analyze` falla por avisos | Versión distinta de Flutter | Usar 3.35.4 o mantener `--no-fatal-warnings` |
| Íconos por defecto | No se ejecutó `flutter_launcher_icons` | `dart run flutter_launcher_icons` tras `create` |
| La IA no responde en release | Falta `INTERNET` | Ejecutar `postcreate.py` tras `create` |
| Cambiar el identificador | `--org` | Editar `--org` en ambos workflows (definitivo antes de publicar) |
