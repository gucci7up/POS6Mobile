# POS6Mobile — Contexto del proyecto

App Flutter POS para cajeras, versión móvil del POS de escritorio **MBSport Racing Dogs**.
Diseñada para **Sunmi V2S** (Android 6" portrait) y cualquier Android similar.
Misma lógica que el POS de escritorio, UI rediseñada para pantalla táctil vertical.

---

## Para compilar el APK (requiere Android Studio / Android SDK)

```bash
# 1. Clonar
git clone https://github.com/gucci7up/POS6Mobile.git
cd POS6Mobile

# 2. Instalar dependencias
flutter pub get

# 3. Compilar
flutter build apk --release

# 4. APK listo en:
build/app/outputs/flutter-apk/app-release.apk
```

Instalar en Android: copiar el APK al teléfono → activar "Instalar fuentes desconocidas" → abrir el APK.

---

## Stack

- **Flutter** — Android target, portrait only, minSdk 21 (Android 5+)
- **Backend** — `https://api.mbsport.lat` (NestJS, mismo que el POS de escritorio)
- **Impresora Sunmi interna** — `sunmi_printer_plus`
- **Impresora Bluetooth** — `print_bluetooth_thermal` + `esc_pos_utils_plus`
- **Permisos** — `permission_handler`

---

## Pantallas

| Tab | Pantalla | Descripción |
|-----|----------|-------------|
| POS | Jugada | Apuestas: GANADOR / EXACTA / TRIFECTA + modos R / R/2 / REVERSA / RANDOM |
| TICKETS | Ventas | Lista de tickets vendidos con estados |
| CARRERAS | Resultados | Historial de resultados por carrera |
| REPORTES | Cuotas | Cuotas en vivo de la carrera actual |
| PREMIOS | Premios | Tickets WON pendientes de pago, búsqueda táctil, botón PAGAR |

También: pantalla de **Login** (número acceso 12 dígitos + PIN 8 dígitos, teclado numérico táctil) y **Configuración** de impresora.

---

## Perros

| # | Nombre | Color |
|---|--------|-------|
| 1 | ROJO | Rojo |
| 2 | BLANCO | Blanco/Gris |
| 3 | AZUL | Azul |
| 4 | VERDE | Verde |
| 5 | AMARILLO | Amarillo |
| 6 | NEGRO | Negro |

---

## Notas

- Sin `window_manager` (solo para desktop)
- Fuente disponible: `assets/fonts/din-next-lt-pro-regular.ttf`
- El `pubspec.yaml` ya apunta al nombre correcto de la fuente
- GitHub Actions workflow existe (`.github/workflows/build-apk.yml`) pero se recomienda compilar localmente con Android Studio
