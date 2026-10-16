# CycloEdge — Mobile Bike Computer (Android Native)

Aplikasi Komputer Sepeda (*Bike Computer*) modern berbasis **Kotlin Native + Jetpack Compose + SQLite WAL + BLE GATT**, dibangun berdasarkan spesifikasi teknis [spesifikasi_aplikasi_bike_computer_v3.md](spesifikasi_aplikasi_bike_computer_v3.md).

---

## Fitur Utama yang Telah Diimplementasikan

1. **Live Cockpit Telemetry Engine (1 Hz):**
   - Layanan latar belakang persisten (*Foreground Service*) dengan tipe `location`, `connectedDevice`, dan `health` (kompatibel Android 14/15/16).
   - *Partial WakeLock* otomatis untuk mencegah *CPU sleep* saat layar mati atau aplikasi berjalan di latar belakang.
   - Mode cockpit **Portrait** (dudukan stem) dan **Landscape** (dudukan aero bridge) dengan tipografi tabular numerals monospaced (`fontFeatureSettings = "tnum"`).

2. **Integrasi BLE Multi-Sensor & Dual CSC:**
   - Scanning, pairing, dan reconnect otomatis dengan *exponential backoff*.
   - **Heart Rate Monitor (`0x180D`):** Penguraian format `uint8` dan `uint16`, kontak kulit (*sensor contact*), dan interval RR.
   - **Dual CSC (`0x1816`):** Mendukung dua periferal terpisah (sensor Speed di hub roda + sensor Cadence di crank) dengan penanganan *rollover* aritmetika modular $2^{16}$ dan $2^{32}$.
   - **Cycling Power (`0x2A63`):** Instantaneous Power (Watt), Pedal Balance kiri/kanan, dan estimasi kadens dari power meter.

3. **Sensor Fusion & Algoritma Navigasi:**
   - **4-State Kalman Filter:** Estimasi posisi dan kecepatan halus pada koordinat bidang datar ENU lokal.
   - **Dead Reckoning Fallback:** Estimasi jarak dan posisi terus berjalan saat GPS hilang (terowongan/underpass) memanfaatkan sensor putaran roda BLE.
   - **Elevation Complementary Filter:** Penggabungan Barometer + GNSS/DEM dengan histeresis tanjakan ($T \approx 1{,}5\text{ m}$) dan kalkulasi gradien (% grade).
   - **Auto-Pause Histeresis:** Kecepatan $< 2{,}0\text{ km/jam}$ selama 5 detik memicu pause; kecepatan $> 3{,}0\text{ km/jam}$ selama 2 detik memicu resume.
   - **Normalized Power (NP):** Rata-rata bergulir 30 detik dipangkatkan 4, IF, dan TSS.
   - **Direction-Aware Polyline Snapping:** Snapping cerdas dengan validasi sudut heading $\cos(\Delta \theta) \ge 0{,}5$ untuk mencegah sasar pada rute bolak-balik.

4. **Penyimpanan Lokal & Crash Recovery:**
   - Basis data SQLite lokal Room dengan mode **Write-Ahead Logging (WAL)** dan transaksi *batch flush* tiap 3 detik untuk durabilitas data nol-kehilangan (*zero data-loss*).
   - *Crash Recovery Dialog* otomatis saat app dibuka jika ada sesi sebelumnya yang belum difinalisasi akibat baterai habis.

5. **Ekspor File Standar Industri:**
   - **Garmin FIT File Encoder:** Pembangkitan biner berkas `.FIT` lengkap dengan CRC-16 checksum, definition messages, record 1 Hz, dan event start/stop/lap.
   - **GPX 1.1 Exporter:** Ekspor berkas XML GPX dengan ekstensi Garmin TrackPoint (HR & Cadence).

6. **Ergonomi & Ketahanan Luar Ruangan:**
   - **Rain & Sweat Lock:** Kunci layar sentuh anti-ghost touch dari air hujan/keringat (buka kunci dengan menahan layar 2 detik).
   - **Thermal Guard Manager:** Memantau status panas smartphone di bawah terik matahari tropis.
   - **Anti Burn-in OLED:** Dukungan layar true black `#000000` dan mitigasi statis.

---

## Struktur Direktori Kode Sumber

```
bike_comp/
├── app/
│   ├── build.gradle.kts
│   ├── proguard-rules.pro
│   └── src/
│       ├── main/
│       │   ├── AndroidManifest.xml
│       │   ├── res/values/{strings,colors,themes}.xml
│       │   └── java/com/cycloedge/app/
│       │       ├── CycloEdgeApplication.kt
│       │       ├── data/local/
│       │       │   ├── CycloDatabase.kt
│       │       │   ├── entities/{ActivityEntity, TrackpointEntity, ...}.kt
│       │       │   └── dao/{ActivityDao, TrackpointDao, ...}.kt
│       │       ├── domain/
│       │       │   ├── algorithms/{KalmanFilter, ElevationComplementaryFilter, ...}.kt
│       │       │   ├── ble/{BleSensorManager, HeartRateParser, CyclingSpeedCadenceParser, ...}.kt
│       │       │   └── model/{LiveTelemetry, ActivityState, SensorData}.kt
│       │       ├── service/{RecordingForegroundService, ServiceNotificationHelper, WakeLockManager}.kt
│       │       ├── thermal/ThermalGuardManager.kt
│       │       ├── export/{FitFileEncoder, GpxExporter}.kt
│       │       └── ui/
│       │           ├── theme/{Color, Type, Theme}.kt
│       │           ├── cockpit/{CockpitScreen, CockpitPortraitView, CockpitLandscapeView, ...}.kt
│       │           ├── sensors/{SensorPairingScreen, SensorPairingViewModel}.kt
│       │           ├── summary/ActivitySummaryScreen.kt
│       │           └── MainActivity.kt
│       └── test/java/com/cycloedge/app/
│           ├── ble/{HeartRateParserTest, CyclingSpeedCadenceParserTest}.kt
│           └── algorithms/{AutoPauseDetectorTest, NormalizedPowerTest}.kt
├── gradle/
│   ├── libs.versions.toml
│   └── wrapper/gradle-wrapper.properties
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
└── spesifikasi_aplikasi_bike_computer_v3.md
```

---

## Cara Menjalankan Aplikasi di Android Studio

1. Buka **Android Studio** (Hedgehog, Iguana, Koala, Ladybug, atau versi terbaru).
2. Pilih **Open**, arahkan ke direktori `c:\laragon\www\bike_comp`.
3. Pastikan JDK yang digunakan adalah **JDK 17** atau **JDK 21** (*Settings > Build, Execution, Deployment > Build Tools > Gradle > Gradle JDK*).
4. Biarkan Gradle melakukan sinkronisasi dependensi (*Sync Project with Gradle Files*).
5. Sambungkan smartphone Android fisik (aktifkan *USB Debugging* dan *Bluetooth*).
6. Klik tombol **Run 'app'** (Shift + F10).

