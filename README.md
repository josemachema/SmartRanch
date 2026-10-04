# 🤠 Smart Ranch — Ganadería Inteligente & Telemetría IoT

Sistema integral de monitoreo ganadero y telemetría satelital en tiempo real para hatos en Sonora, México. Integra collares inteligentes ESP32 con sensores biométricos, radioenlaces LoRa/WiFi, mapas satelitales GPS, control de estrés calórico (THI) y protocolo de contingencia por desconexión.

---

## 📂 Estructura del Repositorio

El proyecto está organizado en una arquitectura monorepo modular:

```
SMARTRANCH_Final/
├── 📱 app/smart_ranch/     # Aplicación Cliente Flutter (Android, iOS, Web, Windows)
│   ├── lib/               # Código fuente Dart (Pantallas, Modelos, Servicios, Widgets)
│   │   ├── screens/       # 18 Pantallas (GPS, Hato, THI, Bebederos, Alertas, etc.)
│   │   ├── models/        # Modelos de datos (SensorReading, TroughReading, etc.)
│   │   ├── services/      # Servicios (DemoService, RanchApiService, AuthService)
│   │   └── widgets/       # Componentes reusables UI/UX
│   ├── test/              # 24 Pruebas automatizadas (Unit, Widget y Contingencia)
│   └── pubspec.yaml       # Dependencias del proyecto Flutter
│
├── 🖥️ backend/             # API REST & Servidor de Sincronización
│   └── ...                # Endpoints de gestión ganadera y base de datos
│
├── 📡 firmware/            # Código para Microcontroladores ESP32 & Sensores
│   └── ...                # Lectura MLX90614, ADXL345, NEO-6M GPS y LoRa 915MHz
│
└── 📄 README.md           # Documentación general del proyecto
```

> 💡 **Nota para desarrolladores:** Para ver o editar la aplicación de Flutter, navega a la carpeta [`app/smart_ranch/`](./app/smart_ranch/).

---

## 🚀 Módulos Principales de la Aplicación (`app/smart_ranch/`)

1. **🗺️ GPS Satelital & Geocercas (`gps_map_screen.dart`):**
   * Rastreo de ganado en mapas OpenStreetMap en tiempo real.
   * **Protocolo de Contingencia LKP (Last Known Position):** En caso de pérdida de señal, el sistema congela la última coordenada satelital y proyecta un círculo de dispersión estimado según los minutos transcurridos.
   * Brújula y cálculo de distancia real en metros desde el smartphone del vaquero.

2. **🌡️ Monitor de Confort Térmico & THI (`dashboard_screen.dart`):**
   * Semáforo de estrés calórico para el clima árido de Sonora (Alerta $\ge 72$, Peligro $\ge 79$, Emergencia $\ge 84$).
   * Sensores infrarrojos MLX90614 para temperatura corporal bovina.

3. **💧 Monitoreo de Bebederos & Aguajes (`water_dashboard_screen.dart`):**
   * Sensores ultrasónicos con telemetría de nivel y porcentaje.
   * Registro histórico de consumo y alertas de estiaje.

4. **📋 Inventario de Hato & Cédula Oficial (`herd_screen.dart`):**
   * Vista dual: Cuadrícula de tarjetas táctiles y tabla de datos expandida.
   * Registro oficial SINIIGA y vinculación automática a collares IoT.

5. **⚙️ Configuración & Diagnóstico de Red (`settings_screen.dart`, `system_status_screen.dart`):**
   * Presets rápidos para 8 municipios de Sonora (Puerto Peñasco, Cananea, Hermosillo, Caborca, etc.).
   * Ping HTTP en tiempo real a Firebase Realtime Database con medición de latencia en milisegundos.
   * Inspector de telemetría JSON crudo y simulador de contingencia.

---

## 🛠️ Cómo Ejecutar la Aplicación

### Requisitos Previos
* Flutter SDK $\ge 3.2.0$
* Dart SDK $\ge 3.0.0$

### Pasos de Instalación y Ejecución
```bash
# 1. Ingresar a la carpeta de la aplicación
cd app/smart_ranch

# 2. Obtener dependencias
flutter pub get

# 3. Ejecutar pruebas automatizadas (24 tests)
flutter test

# 4. Iniciar en Windows Desktop o Chrome
flutter run -d windows
# o para web:
flutter run -d chrome
```

---

## 🧪 Estado de Pruebas & Calidad
* **Análisis estático:** `flutter analyze lib/` $\rightarrow$ **0 errores / 0 advertencias**.
* **Pruebas automáticas:** `flutter test` $\rightarrow$ **100% pasando (24/24 tests)**.
