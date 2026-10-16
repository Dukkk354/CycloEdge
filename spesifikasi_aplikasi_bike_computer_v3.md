# Spesifikasi Teknis & Blueprint Produk: CycloEdge (Mobile Bike Computer)

> **Versi 3.0 — Production-Ready Blueprint, 16 Oktober 2026.**
> Dokumen ini merupakan penyempurnaan menyeluruh dari Versi 2.0. Memuat arsitektur sistem level produksi, integrasi sensor BLE multi-periferal, algoritma sensor fusion (Kalman, Baro-GNSS complementary filter, dead reckoning), manajemen termal tropis, skema database SQLite berkinerja tinggi dengan downsampled summary cache, mitigasi burn-in OLED, spesifikasi cockpit portrait & landscape, serta resolusi strategis atas seluruh pertanyaan terbuka.

---

## Ringkasan Perubahan & Penyempurnaan dari v2.0

1. **Sensor Fusion & Dead Reckoning (Bagian 3 & 5):**
   - Ditambahkan algoritma *Dead Reckoning* saat sinyal GNSS terputus (terowongan, flyover, kanopi lebat) memanfaatkan sensor putaran roda dan heading rute.
   - Ditambahkan formulasi matematis konkret untuk *Complementary Filter* elevasi Barometer + GNSS/DEM guna mengeliminasi *drift* cuaca tanpa kehilangan responsivitas tanjakan mikro.
   - Matriks diskrit Kalman Filter (F, H, Q, R) didefinisikan secara eksplisit untuk implementasi langsung pada kode.
2. **Multi-Sensor BLE & Dual CSC (Bagian 4):**
   - Penyelesaian arsitektur untuk *Dual CSC Sensors*: menangani dua sensor independen dengan Service UUID `0x1816` yang sama (satu sensor Speed di hub roda, satu sensor Cadence di arm crank) secara simultan.
   - Penambahan negosiasi MTU, prioritas koneksi (`CONNECTION_PRIORITY_HIGH`), dan strategi reconnect Android tanpa jebakan latensi `autoConnect=true`.
   - Parsing *Pedal Power Balance* (kiri/kanan) pada Cycling Power Measurement (`0x2A63`).
3. **Kepatuhan OS Modern & Manajemen Termal Tropis (Bagian 8 & 11):**
   - Deklarasi Foreground Service Android 14/15/16 (`location`, `connectedDevice`, dan `health`) beserta mitigasi peninjauan Play Store.
   - *Thermal Throttling Controller*: penanganan kenaikan suhu perangkat akibat paparan sinar matahari langsung di iklim tropis Indonesia (adaptasi FPS peta, kecerahan layar, dan mode OLED saver).
   - *OLED Burn-in Mitigation*: teknik pergeseran piksel (*pixel shifting*) periodik untuk elemen HUD statis.
4. **Optimasi Basis Data & Render UI (Bagian 9):**
   - Penambahan kolom `summary_polyline` pada tabel `activities` (format encoded polyline) untuk render instan (<50 ms) pada daftar riwayat dan ringkasan pasca-ride tanpa memuat puluhan ribu `trackpoints`.
   - Kolom `role` dan `is_dead_reckoning` pada skema database.
5. **Ergonomi UI/UX & Cockpit (Bagian 11):**
   - Ditambahkan layout antarmuka **Landscape Cockpit** di samping Portrait untuk dudukan *aero bridge* / *out-front*.
   - Antrean prioritas audio (*Audio Alert Hierarchy*) agar peringatan kritis (bahaya/off-route) tidak terdistorsi oleh cue nutrisi/lap.
6. **Resolusi Strategis (Bagian 17):**
   - Jawaban dan rekomendasi definitif untuk 8 pertanyaan terbuka (arsitektur KMP, strategi rilis Android-first, model monetisasi, hosting tile PMTiles serverless, dan batas target perangkat).

---

## Daftar Isi

1. [Ikhtisar Produk](#1-ikhtisar-produk)
2. [Kebutuhan (Requirements) Terukur](#2-kebutuhan-requirements-terukur)
3. [Arsitektur Sistem & Alur Proses Bisnis](#3-arsitektur-sistem--alur-proses-bisnis)
4. [Integrasi Sensor Bluetooth Low Energy (BLE)](#4-integrasi-sensor-bluetooth-low-energy-ble)
5. [Algoritma Sensor Fusion, Metrik & Filtering](#5-algoritma-sensor-fusion-metrik--filtering)
6. [Peta, Rute & Navigasi](#6-peta-rute--navigasi)
7. [Rekomendasi Tech Stack: KMP + Native](#7-rekomendasi-tech-stack-kmp--native)
8. [Spesifik Platform: Android & iOS](#8-spesifik-platform-android--ios)
9. [Skema Basis Data Lokal (SQLite WAL)](#9-skema-basis-data-lokal-sqlite-wal)
10. [Backend, Encoding FIT & Sinkronisasi](#10-backend-encoding-fit--sinkronisasi)
11. [Desain UI/UX & Ergonomi Cockpit Sepeda](#11-desain-uiux--ergonomi-cockpit-sepeda)
12. [Backlog Fitur Lanjutan (Pasca-MVP)](#12-backlog-fitur-lanjutan-pasca-mvp)
13. [Privasi & Keamanan (UU PDP & Enkripsi)](#13-privasi--keamanan-uu-pdp--enkripsi)
14. [Strategi Pengujian & Chaos Testing](#14-strategi-pengujian--chaos-testing)
15. [Roadmap Pengembangan (Sprint 0 - 5)](#15-roadmap-pengembangan-sprint-0---5)
16. [Register Risiko & Mitigasi Teknis](#16-register-risiko--mitigasi-teknis)
17. [Keputusan Arsitektur & Jawaban Pertanyaan Terbuka](#17-keputusan-arsitektur--jawaban-pertanyaan-terbuka)
18. [Glosarium Istilah](#18-glosarium-istilah)

---

## 1. Ikhtisar Produk

### 1.1. Visi
CycloEdge mentransformasi smartphone modern menjadi komputer sepeda (*bike computer*) kelas profesional yang andal, presisi, dan mudah dibaca dalam kondisi luar ruang ekstrem, meniadakan ketergantungan pada *dedicated head unit* berharga mahal (Garmin Edge, Wahoo ELEMNT, Hammerhead Karoo).

### 1.2. Batasan Ruang Lingkup MVP (Non-Goals)
- **Bukan Jejaring Sosial:** Tidak menyediakan feed sosial, like, komentar, atau leaderboard publik internal (sinkronisasi diarahkan ke Strava/Intervals.icu).
- **Tanpa Radio ANT+:** Fokus eksklusif pada Bluetooth Low Energy (BLE GATT SIG standard) karena keterbatasan perangkat keras ponsel modern.
- **Tanpa Sensor Proprietary Tertutup:** Tidak mendukung radar Garmin Varia (ANT+/Radar profile) atau shifting elektronik nirkabel (Shimano Di2 / SRAM eTap) pada versi MVP.
- **Routing In-App Disederhanakan:** Routing online titik A-ke-B dengan snapping jalan sepeda. Pembuatan rute multi-titik kompleks dianjurkan melalui import GPX/FIT.
- **Tanpa Companion Smartwatch pada MVP:** Wear OS dan Apple Watch dijadwalkan pada Fase 2.

### 1.3. Persona Pengguna
1. **Roadie Komuter-Rekreasi:** Bersepeda 30–80 km di jalan beraspal. Membutuhkan navigasi GPX anti-sasar, visualisasi kecepatan & detak jantung yang terbaca sekilas (*glanceable*), dan auto-upload ke Strava.
2. **Pesepeda Jarak Jauh & Gravel (Audax/Touring):** Menempuh 100–300 km (4–12 jam). Mengutamakan efisiensi baterai, peta offline mutlak tanpa koneksi internet, off-route alarm yang jelas, dan jaminan data tidak hilang saat ponsel kehabisan daya.
3. **Pesepeda Berbasis Data (Performance/Latihan):** Memakai cadence sensor, dual-sided power meter, dan chest strap HR. Mengutamakan latensi update data 1 Hz yang presisi, pembacaan 3s/10s Power, Normalized Power (NP), dan integritas file `.FIT`.

### 1.4. Prinsip Rekayasa Inti (Core Engineering Principles)
1. **Zero Data-Loss & Realtime Persistence:** Data telemetri tidak boleh hilang akibat *OS background kill*, crash memori, atau baterai habis. Maksimum kehilangan data yang dapat ditoleransi adalah 1–5 detik terakhir sebelum pemadaman mendadak.
2. **Keterbacaan Luar Ruang Ekstrem (*Glanceability*):** Tipografi tabular numerik monospaced, kontras rasio ≥ 7:1, hierarki informasi 3 tingkat (Primer: Kecepatan/Jarak, Sekunder: Kadens/HR/Power, Tersier: Jam/Elevasi).
3. **Standarisasi Protokol Terbuka:** Kepatuhan ketat terhadap spesifikasi Bluetooth SIG GATT dan format biner Garmin FIT Protocol.
4. **Local-First & Offline-First:** 100% fungsi perekaman, metrik sensor, navigasi polyline, dan penyimpanan database berjalan mandiri tanpa jaringan internet.
5. **Mitigasi Termal Tropis:** Manajemen beban komputasi dinamis terhadap kenaikan suhu baterai ponsel saat terpapar terik matahari di atas aspal jalan raya.

---

## 2. Kebutuhan (Requirements) Terukur

### 2.1. Kebutuhan Fungsional (Functional Requirements)
*Prioritas: **M** = MVP (Sprint 0–5), **F2** = Fase 2 Pasca-MVP.*

| ID | Kebutuhan Fungsional | Deskripsi Teknis | Prioritas |
| :--- | :--- | :--- | :---: |
| **FR-REC-01** | Telemetri 1 Hz | Pengambilan sampel posisi GNSS, elevasi, kecepatan, HR, kadens, dan power tiap 1000 ms | M |
| **FR-REC-02** | Auto-Pause Histeresis | Pause otomatis saat kecepatan < 2,0 km/jam selama 5s; resume saat kecepatan > 3,0 km/jam selama 2s | M |
| **FR-REC-03** | Manajemen Lap | Pencatatan lap manual via tombol/remote dan auto-lap berbasis jarak (mis. tiap 5 km) | M |
| **FR-REC-04** | Auto-Crash Recovery | Deteksi status `RECORDING` yang belum difinalisasi saat app boot; pemulihan instan ke sesi aktif | M |
| **FR-SEN-01** | BLE GATT Manager | Scanning, pairing, auto-reconnect sensor Heart Rate (`0x180D`), CSC (`0x1816`), Power (`0x1818`) | M |
| **FR-SEN-02** | Dual CSC Parsing | Dukungan dua periferal `0x1816` terpisah secara simultan (Speed Sensor di roda + Cadence di crank) | M |
| **FR-SEN-03** | Freshness Indicator | Menandai metrik sebagai basi (`--`) jika sensor tidak mengirim data > 3-5 detik | M |
| **FR-NAV-01** | Import Rute GPX/FIT/TCX | Parsing berkas rute eksternal, validasi geometri, downsampling RDP, dan rendering polyline | M |
| **FR-NAV-02** | Off-Route Detection | Peringatan instan visual, suara, dan haptic jika jarak tegak lurus ke rute > ambang batas (30-50 m) | M |
| **FR-NAV-03** | Offline Corridor Maps | Penyimpanan paket peta PMTiles vektor lokal untuk koridor rute 2–5 km | M |
| **FR-NAV-04** | Dead Reckoning | Estimasi jarak dan posisi saat GNSS hilang menggunakan sensor roda dan arah rute | M |
| **FR-NAV-05** | Online A-to-B Routing | Pembuatan rute point-to-point via backend OSM yang menghindari jalan tol dan jalan terlarang sepeda | M |
| **FR-UI-01** | Grid Data Dinamis | Pilihan layout data field 2, 4, 6, atau 8 metrik per halaman yang dapat dikustomisasi | M |
| **FR-UI-02** | Dual Cockpit Orientation| Tampilan responsif Portrait (stem mount) dan Landscape (aero handlebar mount) | M |
| **FR-UI-03** | Rain & Sweat Screen Lock| Penguncian layar sentuh dengan gestur pembuka khusus guna mencegah sentuhan palsu air | M |
| **FR-UI-04** | Adaptasi Tema & Anti Burn-in | Tema Kontras Tinggi (Siang/OLED Hitam) dan pergeseran piksel pelindung panel OLED | M |
| **FR-EXP-01** | Ekspor File FIT & GPX | Pembangkitan berkas biner `.FIT` standar industri dan `.GPX` ke penyimpanan lokal | M |
| **FR-EXP-02** | Sinkronisasi Strava | Pengunggahan latar belakang berkas FIT ke Strava API v3 melalui antrean retry otomatis | M |
| **FR-ANA-01** | Ringkasan Pasca-Ride | Tampilan peta rute, statistik ringkas, kurva elevasi, grafik zona HR, dan daftar lap | M |
| **FR-TRN-01** | Metrik Latihan Inti | Perhitungan real-time 3s/10s Power, Normalized Power (NP), Max Speed/Power | M |
| **FR-TRN-02** | Advanced Training Metrics | Perhitungan IF, TSS, dan distribusi waktu dalam 7 zona power | F2 |
| **FR-SAF-01** | Incident Detection | Deteksi kecelakaan via akselerometer ponsel + timer hitung mundur + SMS darurat | F2 |
| **FR-BIKE-01** | Profil Sepeda & Odometer | Pelacakan jarak tempuh komponen sepeda dan peringatan servis rantai/ban | F2 |

### 2.2. Kebutuhan Non-Fungsional (Non-Functional Requirements)

```
+-------------------------------------------------------------------------------+
|                       TARGET NON-FUNGSIONAL UTAMA                             |
+-------------------------------------------------------------------------------+
| Durabilitas Data    : Kehilangan <= 5 detik saat forced-kill / baterai mati   |
| Konsumsi Baterai    : <= 12%/jam (Mode Hemat OLED) | <= 18%/jam (Peta Aktif)   |
| Latensi Display     : Update metrik di UI <= 200 ms dari event sensor BLE     |
| Render Map          : Stabil >= 45-60 FPS pada MapLibre Vector                |
| Akurasi Jarak       : Selisih <= 0,8% dibanding Garmin Edge pada rute 20 km   |
| Ukuran DB per Ride  : <= 2 MB untuk sesi berkendara 4 jam (14.400 trackpoints)|
| Offline Resilience  : 100% fungsi perekaman dan navigasi berjalan tanpa sinyal|
+-------------------------------------------------------------------------------+
```

---

## 3. Arsitektur Sistem & Alur Proses Bisnis

### 3.1. Diagram Blok Arsitektur Sistem

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          PERANGKAT KERAS & SENSOR                                │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐   │
│  │  BLE Sensors (1-10Hz)│  │   GNSS Chipset (1Hz) │  │ Barometer / Altimeter│   │
│  │  - HR Monitor (0x180D)│  │   - Lat, Lon, Doppler   │  │ - Tekanan Udara (hPa)│   │
│  │  - Dual CSC (0x1816) │  │   - Horizontal Accuracy │  │ - Resolusi 0.1 m     │   │
│  │  - Power (0x1818)    │  │   - Bearing / Heading   │  │                      │   │
│  └──────────┬───────────┘  └──────────┬───────────┘  └──────────┬───────────┘   │
└─────────────┼─────────────────────────┼─────────────────────────┼───────────────┘
              │                         │                         │
┌─────────────┼─────────────────────────┼─────────────────────────┼───────────────┐
│             ▼                         ▼                         ▼               │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐   │
│  │ BLE Peripheral Engine│  │ GNSS Validation &    │  │ Elevation Fusion     │   │
│  │ - Parsing Byte SIG   │  │ Kalman Filter (ENU)  │  │ - Baro-GNSS Filter   │   │
│  │ - Rollover Arithmetic│  │ - Outlier Rejection  │  │ - EMA Smoothing      │   │
│  │ - Freshness Watchdog │  │ - Zero-Velocity Lock │  │ - Hysteresis Ascent  │   │
│  └──────────┬───────────┘  └──────────┬───────────┘  └──────────┬───────────┘   │
│             │                         │                         │               │
│             └───────────────────┐     │     ┌───────────────────┘               │
│                                 ▼     ▼     ▼                                   │
│                     ┌───────────────────────────────────────┐                   │
│                     │      Live Telemetry Engine (1 Hz)     │                   │
│                     │  - Dead Reckoning Fallback Synthesizer│                   │
│                     │  - State Machine & Auto-Pause Logic   │                   │
│                     │  - Rolling Average (3s, 10s, 30s NP)  │                   │
│                     └───────────────────┬───────────────────┘                   │
│                                         │                                       │
│       ┌─────────────────────────────────┼─────────────────────────────────┐     │
│       ▼                                 ▼                                 ▼     │
│ ┌──────────────┐               ┌─────────────────┐               ┌────────────┐ │
│ │ Ring Buffer  │ (1-5s batch)  │Navigation Engine│               │UI State    │ │
│ │ In-Memory    ├──────────────▶│- Route Snapping │               │Flow / State│ │
│ └──────┬───────┘               │- Off-Route Alert│               └─────┬──────┘ │
│        │                       │- Cue Generator  │                     │        │
│        ▼                       └────────┬────────┘                     │        │
│ ┌──────────────┐                        │                              │        │
│ │ SQLite (WAL) │                        │                              ▼        │
│ │ Local Storage│                        │               ┌─────────────────────┐ │
│ └──────┬───────┘                        ▼               │ Jetpack Compose /   │ │
│        │                      ┌──────────────────┐      │ SwiftUI Cockpit View│ │
│        │ (On STOP)            │Audio Alert Queue │      │ - Metric HUD        │ │
│        ▼                      │- Priority Ducking│      │ - MapLibre Vector   │ │
│ ┌──────────────┐              └──────────────────┘      │ - Thermal Guard     │ │
│ │ FIT Encoder  ├───────────────┐                        └─────────────────────┘ │
│ │ Garmin SDK   │               ▼                                                │
│ └──────┬───────┘       ┌───────────────┐                                        │
│        │               │ WorkManager / │                                        │
│        └──────────────▶│ BGTask Queue  ├─────────▶ Strava API v3 / Cloud Backup │
│                        └───────────────┘                                        │
│                                                                                 │
│                CORE RECORDING FOREGROUND SERVICE (Isolated LifeCycle)           │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 3.2. State Machine Aktivitas Perekaman

Sistem mengimplementasikan mesin keadaan (*finite state machine*) yang tangguh terhadap gangguan siklus hidup aplikasi:

```
                          ┌───────────────┐
                          │     IDLE      │
                          └───────┬───────┘
                                  │ Pre-ride checks pass (GPS Lock & Sensors)
                                  ▼
                          ┌───────────────┐
                   ┌─────▶│     READY     │
                   │      └───────┬───────┘
                   │              │ User presses [START]
                   │              ▼
                   │      ┌───────────────┐◀───────────────────────────┐
                   │      │   RECORDING   │                            │
                   │      └───────┬───────┘                            │
                   │              │                                    │
                   │      ┌───────┴───────────────────────┐            │
                   │      │                               │            │
                   │      │ Speed < 2 km/h (5s)           │ User Pause │
                   │      ▼                               ▼            │
                   │  ┌───────────────┐               ┌──────────────┐ │
                   │  │  AUTO-PAUSED  │               │ MANUAL-PAUSED│ │
                   │  └───────┬───────┘               └──────┬───────┘ │
                   │          │                              │         │
                   │          │ Speed > 3 km/h (2s)          │ Resume  │
                   │          └───────────────┬──────────────┘         │
                   │                          └────────────────────────┘
                   │
                   │ User triggers [STOP] (Long press 1.5s)
                   ▼
          ┌───────────────┐
          │    STOPPED    │
          └───┬───────┬───┘
              │       │
       [SAVE] │       │ [DISCARD] (With confirmation modal)
              ▼       ▼
    ┌───────────┐   ┌─────────────┐
    │ FINISHED  │   │  DISCARDED  │
    └───────────┘   └─────────────┘

  [CRASH / FORCE-KILL / OS-TERMINATION WHILE RECORDING/PAUSED]
              │
              ▼ (Next App Launch)
    ┌───────────────────┐
    │    RECOVERING     │
    └─────────┬─────────┘
              ├─▶ [PILIHAN 1: LANJUTKAN] ──▶ Tandai gap sebagai PAUSE ──▶ RECORDING
              ├─▶ [PILIHAN 2: SIMPAN]    ──▶ Finalisasi data tersimpan ──▶ FINISHED
              └─▶ [PILIHAN 3: BUANG]     ──▶ Tandai status ────────────▶ DISCARDED
```

---

## 4. Integrasi Sensor Bluetooth Low Energy (BLE)

### 4.1. Arsitektur Dual Sensor CSC (`0x1816`)
Masalah umum pesepeda adalah menggunakan dua unit sensor terpisah (misalnya merek Magene S3+, MoFit, atau XOSS) di mana satu unit dipasang di tromol roda sebagai Sensor Kecepatan (*Speed*) dan unit lainnya dipasang di lengan engkol (*crank*) sebagai Sensor Kadens (*Cadence*). Kedua perangkat memancarkan Service UUID standar yang sama (`0x1816`), namun dengan bit flags karakteristik `0x2A5B` yang berbeda.

```
       ┌────────────────────────┐         ┌────────────────────────┐
       │   Speed Sensor (Hub)   │         │ Cadence Sensor (Crank) │
       │ MAC: AA:BB:CC:11:22:33 │         │ MAC: DD:EE:FF:44:55:66 │
       │ Service: 0x1816        │         │ Service: 0x1816        │
       └───────────┬────────────┘         └───────────┬────────────┘
                   │                                  │
                   │ flags & 0x01 = 1 (Wheel Only)    │ flags & 0x02 = 1 (Crank Only)
                   ▼                                  ▼
       ┌───────────────────────────────────────────────────────────┐
       │                 CycloEdge Sensor Manager                  │
       │  - Slot 1: Speed Source    <-- Paired to AA:BB:CC:11:22:33│
       │  - Slot 2: Cadence Source  <-- Paired to DD:EE:FF:44:55:66│
       └───────────────────────────────────────────────────────────┘
```

#### Logika Penanganan Byte CSC Measurement (`0x2A5B`):
```kotlin
fun parseCSC(bytes: ByteArray, deviceAddress: String, wheelCircumferenceMeters: Double) {
    val flags = bytes[0].toInt()
    var offset = 1

    val hasWheel = (flags and 0x01) != 0
    val hasCrank = (flags and 0x02) != 0

    if (hasWheel) {
        val wheelRevs = readUInt32LE(bytes, offset)
        val wheelEventTime = readUInt16LE(bytes, offset + 4) // Satuan: 1/1024 detik
        offset += 6
        processWheelData(deviceAddress, wheelRevs, wheelEventTime, wheelCircumferenceMeters)
    }

    if (hasCrank) {
        val crankRevs = readUInt16LE(bytes, offset)
        val crankEventTime = readUInt16LE(bytes, offset + 2) // Satuan: 1/1024 detik
        offset += 4
        processCrankData(deviceAddress, crankRevs, crankEventTime)
    }
}
```

#### Penanganan Rollover Aritmetika Modular:
Event time berbasis integer `uint16` mengalami *overflow/rollover* setiap $2^{16} / 1024 \approx 64$ detik. Begitu pula `crankRevs` ($2^{16}$) dan `wheelRevs` ($2^{32}$).
Perhitungan selisih mutlak dilakukan dengan aritmetika modular:
$$\Delta \text{Revs}_{\text{wheel}} = (\text{wheel}_{\text{now}} - \text{wheel}_{\text{prev}}) \pmod{2^{32}}$$
$$\Delta \text{Revs}_{\text{crank}} = (\text{crank}_{\text{now}} - \text{crank}_{\text{prev}}) \pmod{2^{16}}$$
$$\Delta \text{Ticks} = (\text{time}_{\text{now}} - \text{time}_{\text{prev}}) \pmod{2^{16}}$$
$$\Delta t = \frac{\Delta \text{Ticks}}{1024.0} \quad (\text{detik})$$

Jika $\Delta t > 4.0\text{ s}$ atau $\Delta \text{Ticks} = 0$, kecepatan dan kadens sesaat disetel ke 0 (menandakan pesepeda sedang meluncur/*coasting* atau berhenti).

### 4.2. Parsing Cycling Power & Left/Right Balance (`0x2A63`)
Karakteristik Cycling Power `0x2A63` diawali dengan flags 16-bit, diikuti nilai daya sesaat (*Instantaneous Power*) dalam satuan Watt (`sint16`).

```kotlin
fun parseCyclingPower(bytes: ByteArray): PowerData {
    val flags = readUInt16LE(bytes, 0)
    val instantaneousPowerWatts = readSInt16LE(bytes, 2)
    var offset = 4

    var pedalBalancePercent: Double? = null
    var isRightPedal: Boolean? = null

    // Bit 0: Pedal Power Balance Present
    if ((flags and 0x0001) != 0) {
        val rawBalance = bytes[offset].toUByte().toInt()
        offset += 1
        isRightPedal = (rawBalance and 0x80) != 0 // Bit 7: 1 = Right, 0 = Left
        val balanceVal = (rawBalance and 0x7F) * 0.5 // Bit 0-6: resolusi 0.5%
        pedalBalancePercent = balanceVal
    }

    // Bit 2: Accumulated Torque Present (uint16)
    if ((flags and 0x0004) != 0) offset += 2

    // Bit 4: Wheel Revolution Data Present (uint32 + uint16)
    if ((flags and 0x0010) != 0) offset += 6

    // Bit 5: Crank Revolution Data Present (uint16 revs + uint16 time) -> Sumber Kadens Power Meter
    var cadenceRpm: Int? = null
    if ((flags and 0x0020) != 0) {
        val crankRevs = readUInt16LE(bytes, offset)
        val crankTime = readUInt16LE(bytes, offset + 2)
        offset += 4
        cadenceRpm = calculateCadenceFromPowerMeter(crankRevs, crankTime)
    }

    return PowerData(instantaneousPowerWatts, pedalBalancePercent, isRightPedal, cadenceRpm)
}
```

### 4.3. Manajemen Koneksi & Reconnection Watchdog
1. **Prioritas Koneksi:** Saat status berpindah ke `RECORDING`, Android mewajibkan panggilan `bluetoothGatt.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH)` untuk memperkecil *connection interval* (11.25–15 ms), memastikan paket data tidak terlambat masuk.
2. **Hindari `autoConnect = true` pada Reconnect:** Pemanggilan `connectGatt(..., autoConnect = true)` di Android menggunakan pemindaian pasif berdaya rendah oleh pengendali Bluetooth OS yang dapat menunda penyambungan kembali hingga 2–5 menit. Solusi: Gunakan pemindaian terarah eksplisit (*scan with filter*) dengan *exponential backoff* (1s, 2s, 4s, 8s, maks 10s) dan sambungkan dengan `autoConnect = false`.
3. **Data Freshness Watchdog:** Jika paket data terakhir dari suatu sensor lebih tua dari ambang batas:
   - Heart Rate: > 5 detik $\rightarrow$ nilai diubah menjadi `--` (indikator abu-abu).
   - Speed / Cadence / Power: > 3 detik $\rightarrow$ nilai diubah menjadi `0` atau `--`.

---

## 5. Algoritma Sensor Fusion, Metrik & Filtering

### 5.1. Matriks Diskrit Kalman Filter Posisi GNSS
Untuk mereduksi *jitter* posisi dan lonjakan koordinat saat melaju di dekat tebing, pepohonan, atau gedung, digunakan 4-State Linear Kalman Filter pada bidang datar lokal ENU (East-North-Up) dengan titik referensi asal $\mathbf{p}_0 = (\text{lat}_0, \text{lon}_0)$:

$$\mathbf{x}_k = \begin{bmatrix} p_e \\ p_n \\ v_e \\ v_n \end{bmatrix}_k, \quad
\mathbf{F} = \begin{bmatrix} 
1 & 0 & \Delta t & 0 \\ 
0 & 1 & 0 & \Delta t \\ 
0 & 0 & 1 & 0 \\ 
0 & 0 & 0 & 1 
\end{bmatrix}, \quad
\mathbf{H} = \begin{bmatrix} 
1 & 0 & 0 & 0 \\ 
0 & 1 & 0 & 0 
\end{bmatrix}$$

- **Vektor Pengukuran:** $\mathbf{z}_k = [z_e, z_n]^T$ diperoleh dari proyeksi koordinat WGS84 ke meter lokal.
- **Matriks Kovarian Pengukuran $\mathbf{R}_k$:** Ditentukan secara dinamis dari nilai `accuracy` horizontal ($s_{\text{acc}}$) yang dikirim oleh GNSS:
$$\mathbf{R}_k = \begin{bmatrix} s_{\text{acc}}^2 & 0 \\ 0 & s_{\text{acc}}^2 \end{bmatrix}$$
- **Matriks Noise Proses $\mathbf{Q}$:** Dimodelkan dari varians percepatan maksimum sepeda $\sigma_a \approx 1{,}5\ \text{m/s}^2$:
$$\mathbf{Q} = \sigma_a^2 \begin{bmatrix} 
\frac{\Delta t^4}{4} & 0 & \frac{\Delta t^3}{2} & 0 \\ 
0 & \frac{\Delta t^4}{4} & 0 & \frac{\Delta t^3}{2} \\ 
\frac{\Delta t^3}{2} & 0 & \Delta t^2 & 0 \\ 
0 & \frac{\Delta t^3}{2} & 0 & \Delta t^2 
\end{bmatrix}$$

### 5.2. Filter Komplementer Barometer & GNSS/DEM
Sensor barometer ponsel (`TYPE_PRESSURE` / `CMAltimeter`) sangat sensitif terhadap perubahan elevasi sesaat ($< 0{,}2\ \text{m}$), namun rentan terhadap *drift* akibat fluktuasi tekanan atmosfer cuaca. Untuk itu diterapkan *Complementary Filter*:

```
Tekanan Udara P ──▶ [Hypsometric Eq] ──▶ h_baro ──┐
                                                  │ (+)
                                                  ▼
                                                [ ∑ ] ──▶ h_fused(t)
                                                  ▲
GNSS / DEM Alt  ──▶ [Low-Pass Filter] ──▶ h_ref  ──┘ (+)
```

#### Persamaan Matematika:
$$h_{\text{raw\_baro}}(t) = 44330.0 \times \left(1.0 - \left(\frac{P(t)}{P_0}\right)^{\frac{1}{5.255}}\right)$$
$$h_{\text{fused}}(t) = (1 - \alpha) \cdot \Big(h_{\text{raw\_baro}}(t) + \Delta_{\text{offset}}(t-1)\Big) + \alpha \cdot h_{\text{ref}}(t)$$
$$\Delta_{\text{offset}}(t) = h_{\text{fused}}(t) - h_{\text{raw\_baro}}(t)$$

Di mana $\alpha = \frac{\Delta t}{\tau + \Delta t}$. Dengan $\tau \approx 300\text{ detik}$ (konstanta waktu 5 menit) dan $\Delta t = 1.0\text{ s}$, maka $\alpha \approx 0{,}0033$. Hal ini mempertahankan respons elevasi cepat dari barometer sekaligus mengikat ketinggian absolut pada GNSS/DEM jangka panjang.

### 5.3. Dead Reckoning saat Sinyal GNSS Hilang
Ketika pesepeda memasuki terowongan atau jalan di bawah jembatan layang bertingkat di mana akurasi GNSS drop ($s_{\text{acc}} > 35\ \text{m}$ atau data lokasi berhenti masuk):
1. **Jarak & Kecepatan:** 100% dipasok dari sensor putaran roda BLE CSC:
   $$\Delta d = \Delta \text{Revs}_{\text{wheel}} \times C$$
2. **Posisi Sintetis:**
   - Jika sedang mengikuti rute aktif: posisi disintesiskan dengan memajukan titik sepanjang polyline rute sejauh $\Delta d$.
   - Jika tanpa rute aktif: posisi diproyeksikan menggunakan *last known heading* ($\theta$):
     $$\text{lat}_{\text{new}} = \text{lat}_{\text{prev}} + \frac{\Delta d \cdot \cos(\theta)}{R_{\text{earth}}}, \quad \text{lon}_{\text{new}} = \text{lon}_{\text{prev}} + \frac{\Delta d \cdot \sin(\theta)}{R_{\text{earth}} \cdot \cos(\text{lat}_{\text{prev}})}$$
3. **Penandaan:** Sampel trackpoint dicatat dengan kolom `is_dead_reckoning = 1` dan `gps_accuracy_m = NULL`.

---

## 6. Peta, Rute & Navigasi

### 6.1. Format PMTiles Vektor Lokal (Serverless Architecture)
Alih-alih menjalankan server lokal HTTP di dalam smartphone (yang rentan dihentikan oleh OS) atau melanggar *Tile Usage Policy* OpenStreetMap:
- Peta offline didistribusikan dalam format berkas biner tunggal **PMTiles v3** (berbasis arsitektur cloud-optimized tile).
- Melalui MapLibre Native SDK, berkas `.pmtiles` dibaca langsung dari penyimpanan internal perangkat (`file:///data/user/0/.../regions/bandung.pmtiles`) menggunakan *custom protocol handler* / *archive adapter* tanpa overhead server HTTP lokal.
- Pengguna dapat mengunduh koridor rute (*route buffer* selebar 3 km) dengan rata-rata ukuran file hanya 15–40 MB untuk rute sepanjang 100 km.

### 6.2. Algoritma Direction-Aware Polyline Snapping
Untuk mencegah kesalahan snapping pada jalur bolak-balik (*out-and-back*), jalan melingkar (*looping*), atau jembatan layang bertumpuk, algoritma proyeksi titik wajib memvalidasi keselarasan arah (*directional bearing check*):

```
                   Titik Sepeda P (Bearing = 45°)
                          ▲
                         │ d_perp
                         ▼
        A ───────────────────────▶ B  (Segmen Rute Maju, Bearing = 40°)
        [VALID: cos(45° - 40°) = 0.996 > 0.5]

        C ◀─────────────────────── D  (Segmen Rute Balik, Bearing = 220°)
        [INVALID / REJECTED: cos(45° - 220°) = -0.96 < 0.5]
```

$$\cos(\Delta \theta) = \cos(\theta_{\text{heading}} - \theta_{\text{segment}})$$
Kandidat proyeksi segmen rute hanya dianggap valid jika $\cos(\Delta \theta) \geq 0{,}5$ (perbedaan arah $< 60^\circ$).

### 6.3. Hierarki Peringatan Suara & Audio Ducking
Ketika notifikasi suara dipicu, CycloEdge menggunakan `AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE` dengan mode *Duck Others*, menurunkan volume pemutar musik (Spotify/YouTube Music) menjadi 20% selama pesan diucapkan:

| Prioritas | Kategori Alert | Pola Getar | Bunyi / TTS Audio |
| :---: | :--- | :--- | :--- |
| **1 (Kritis)** | Off-Route Alarm | 3x Panjang (500ms on, 200ms off) | "Peringatan! Keluar rute 50 meter" |
| **2 (Tinggi)** | Turn Guidance Cue | 2x Pendek (200ms on, 100ms off) | "100 meter lagi, belok kanan ke Jalan Riau" |
| **3 (Sedang)** | Back on Route | 1x Panjang (400ms) | "Kembali ke rute" |
| **4 (Info)** | Lap Split Summary | 1x Pendek (150ms) | "Lap 5 selesai. Rata-rata 31 km/jam" |
| **5 (Pemberitahuan)**| Pengingat Minum/Makan| 2x Lembut (100ms) | Chime nada ganda |

---

## 7. Rekomendasi Tech Stack: KMP + Native

### 7.1. Keputusan Arsitektur Definitif

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ARSITEKTUR CYCLOEDGE                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  [UI Layer: Deklaratif & Platform-Optimized]                                │
│   - Android: Kotlin + Jetpack Compose (Material 3 + Canvas Rendering)       │
│   - iOS    : Swift + SwiftUI + ActivityKit (Dynamic Island / Live Activity) │
├─────────────────────────────────────────────────────────────────────────────┤
│  [Shared Core Engine: Kotlin Multiplatform (KMP)]                           │
│   - Algoritma Filtering (Kalman Filter, Haversine, EMA, Baro Complementary) │
│   - Parser Protokol BLE (HR 0x180D, CSC 0x1816, Power 0x1818)              │
│   - State Machine Perekaman & Histeresis Auto-Pause                         │
│   - Formulasi Metrik (NP, IF, TSS, Rolling Power)                           │
│   - Logika Navigasi (Snapping, Off-route detection, Cue Trigger)            │
│   - Database Layer: SQLDelight / Room KMP (Multiplatform SQLite WAL)        │
├─────────────────────────────────────────────────────────────────────────────┤
│  [Native OS Support Services]                                               │
│   - Android: Foreground Service (Location + ConnectedDevice + Health)      │
│   - iOS    : CLLocationManager (Background Mode) + CoreBluetooth Restore    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2. Keunggulan Arsitektur KMP Dibandingkan Pilihan Lain
1. **Performa Native Tanpa Bridge:** KMP dikompilasi menjadi bytecode JVM/ART untuk Android dan framework C/Obj-C binary native untuk iOS. Tidak ada *JavaScript bridge* (seperti React Native) yang memicu *frame drop* atau latensi pembacaan data sensor 1 Hz.
2. **Logika Bisnis & Matematika 100% Identik:** Seluruh rumus kompleks (Kalman, rollover byte CSC, histeresis pause, NP) ditulis satu kali dalam KMP, menjamin kalkulasi jarak dan kecepatan menghasilkan angka yang persis sama di Android dan iOS.
3. **Strategi Rilis Android-First Terjamin:** UI Android dibangun menggunakan Jetpack Compose secara penuh. Saat porting ke iOS dimulai, seluruh modul *Core Engine* sudah teruji 100% melalui unit-test, memangkas waktu pengerjaan iOS hingga 60%.

---

## 8. Spesifik Platform: Android & iOS

### 8.1. Konfigurasi Android 14/15/16 Foreground Service
Pada Android 14 (API 34) dan Android 15 (API 35), deklarasi tipe foreground service wajib dilakukan secara eksplisit pada `AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Izin Lokasi & Sensor -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    
    <!-- Izin BLE Android 12+ -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" 
                     android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    
    <!-- Izin Foreground Service Wajib Android 14+ -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_HEALTH" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <application ...>
        <service
            android:name=".service.RecordingForegroundService"
            android:foregroundServiceType="location|connectedDevice|health"
            android:exported="false" />
    </application>
</manifest>
```

Saat service dihidupkan dalam kode Kotlin:
```kotlin
ServiceCompat.startForeground(
    this,
    NOTIFICATION_ID,
    buildNotification(),
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION or
        ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE or
        ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
    } else {
        0
    }
)
```

### 8.2. Pengendali Manajemen Termal Tropis (Thermal Throttling Controller)
Di Indonesia, suhu permukaan aspal pada siang hari dapat mencapai 45°C. Smartphone yang terpasang di setang terpapar radiasi matahari langsung dan panas internal prosesor.
CycloEdge mengimplementasikan pendengar status termal sistem (`PowerManager.OnThermalStatusChangedListener`):

```kotlin
class ThermalGuardManager(private val context: Context) {
    fun registerThermalListener(onStatusChange: (ThermalAction) -> Unit) {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            powerManager.addThermalStatusListener { status ->
                when (status) {
                    PowerManager.THERMAL_STATUS_NONE,
                    PowerManager.THERMAL_STATUS_LIGHT -> {
                        onStatusChange(ThermalAction.Normal(targetFps = 60))
                    }
                    PowerManager.THERMAL_STATUS_MODERATE -> {
                        // Turunkan render peta ke 30 FPS, reduksi kecerahan layar 15%
                        onStatusChange(ThermalAction.ThrottleStage1(targetFps = 30))
                    }
                    PowerManager.THERMAL_STATUS_SEVERE -> {
                        // Turunkan render ke 15 FPS, matikan layer kontur 3D pada peta
                        onStatusChange(ThermalAction.ThrottleStage2(targetFps = 15, disableComplexLayers = true))
                    }
                    PowerManager.THERMAL_STATUS_CRITICAL -> {
                        // Alihkan ke Mode Saver Layar Hitam (Hanya angka putih monokrom)
                        onStatusChange(ThermalAction.EmergencyOledMode)
                    }
                }
            }
        }
    }
}
```

---

## 9. Skema Basis Data Lokal (SQLite WAL)

### 9.1. Konfigurasi Database Engine
```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA foreign_keys = ON;
PRAGMA temp_store = MEMORY;
PRAGMA cache_size = -8000; -- Alokasi memori cache ~8 MB
```

### 9.2. Tabel Master & Riwayat Aktivitas
```sql
-- Tabel Master Aktivitas (Dilengkapi Summary Polyline untuk Render Instan)
CREATE TABLE activities (
    id TEXT PRIMARY KEY,                       -- UUID v4
    title TEXT NOT NULL,
    sport TEXT NOT NULL DEFAULT 'cycling',
    bike_id TEXT REFERENCES bikes(id) ON DELETE SET NULL,
    profile_id TEXT REFERENCES activity_profiles(id) ON DELETE SET NULL,
    route_id TEXT REFERENCES routes(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'RECORDING'
        CHECK (status IN ('RECORDING','PAUSED','STOPPED','FINISHED','DISCARDED')),
    start_time_ms INTEGER NOT NULL,
    end_time_ms INTEGER,
    last_checkpoint_ms INTEGER,
    total_distance_m REAL NOT NULL DEFAULT 0,
    elapsed_s INTEGER NOT NULL DEFAULT 0,
    moving_s INTEGER NOT NULL DEFAULT 0,
    avg_speed_mps REAL,
    max_speed_mps REAL,
    avg_heart_rate INTEGER,
    max_heart_rate INTEGER,
    avg_cadence INTEGER,
    avg_power_w INTEGER,
    max_power_w INTEGER,
    normalized_power_w INTEGER,
    total_ascent_m REAL NOT NULL DEFAULT 0,
    total_descent_m REAL NOT NULL DEFAULT 0,
    calories_kcal INTEGER,
    fit_file_path TEXT,
    summary_polyline TEXT,                     -- Google Encoded Polyline (<50 KB) untuk render cepat di UI
    notes TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
CREATE INDEX idx_activities_status ON activities(status);
CREATE INDEX idx_activities_start ON activities(start_time_ms DESC);

-- Tabel Trackpoints (Detail 1 Hz dengan Flag Dead Reckoning)
CREATE TABLE trackpoints (
    activity_id TEXT NOT NULL,
    ts_ms INTEGER NOT NULL,
    latitude REAL,
    longitude REAL,
    gps_accuracy_m REAL,
    elevation_m REAL,
    distance_m REAL NOT NULL,
    speed_mps REAL,
    heart_rate INTEGER,
    cadence INTEGER,
    power_w INTEGER,
    temperature_c REAL,
    grade_pct REAL,
    is_paused INTEGER NOT NULL DEFAULT 0,
    is_dead_reckoning INTEGER NOT NULL DEFAULT 0, -- 1 jika dihasilkan saat GNSS hilang
    PRIMARY KEY (activity_id, ts_ms),
    FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
) WITHOUT ROWID;

-- Tabel Sensor Terpasang (Mendukung Peran Spesifik Dual CSC)
CREATE TABLE paired_sensors (
    sensor_id TEXT PRIMARY KEY,                -- BLE MAC Address (Android) atau UUID (iOS)
    name TEXT NOT NULL,
    sensor_type TEXT NOT NULL                  -- 'HEART_RATE','CSC','POWER'
        CHECK (sensor_type IN ('HEART_RATE','CSC','POWER')),
    role TEXT NOT NULL DEFAULT 'COMBO'         -- 'SPEED_ONLY','CADENCE_ONLY','COMBO','HR','POWER'
        CHECK (role IN ('SPEED_ONLY','CADENCE_ONLY','COMBO','HR','POWER')),
    bike_id TEXT REFERENCES bikes(id) ON DELETE SET NULL,
    is_enabled INTEGER NOT NULL DEFAULT 1,
    last_battery_pct INTEGER,
    last_connected_at INTEGER
);

-- Antrean Sinkronisasi Latar Belakang (Sync Jobs)
CREATE TABLE sync_jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    activity_id TEXT NOT NULL,
    provider TEXT NOT NULL                     -- 'STRAVA','INTERVALS','LOCAL_EXPORT'
        CHECK (provider IN ('STRAVA','INTERVALS','LOCAL_EXPORT')),
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING','UPLOADING','PROCESSING','DONE','FAILED','SKIPPED')),
    external_id TEXT,
    attempts INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    next_retry_at INTEGER,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    UNIQUE (activity_id, provider),
    FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
);
```

---

## 10. Backend, Encoding FIT & Sinkronisasi

### 10.1. Implementasi Garmin FIT File Encoder
Protokol biner FIT (*Flexible and Interoperable Data Transfer*) adalah format *de-facto* olahraga global. CycloEdge menggunakan implementasi resmi dari Garmin FIT SDK:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        STRUKTUR FILE BINER FIT                         │
├────────────────────────────────────────────────────────────────────────┤
│ 1. File Header (14 bytes): Data Size, Protocol Version, ".FIT", CRC-16 │
├────────────────────────────────────────────────────────────────────────┤
│ 2. Definition Message (File ID: ID, Type = Activity, Manufacturer)     │
│ 3. Data Message (File ID)                                              │
├────────────────────────────────────────────────────────────────────────┤
│ 4. Definition Message (Device Info: CycloEdge App, Sensors Serial)     │
│ 5. Data Message (Device Info)                                          │
├────────────────────────────────────────────────────────────────────────┤
│ 6. Definition Message (Event: Timer Start)                             │
│ 7. Data Message (Event: Timer Start)                                   │
├────────────────────────────────────────────────────────────────────────┤
│ 8. Definition & Data Messages (Record: 1 Hz Telemetry)                 │
│    - Timestamp (detik sejak 1989-12-31 UTC)                            │
│    - Semicircles Latitude & Longitude (deg * 2^31 / 180)               │
│    - Enhanced Speed (mm/s), Enhanced Altitude ((m + 500) * 5)          │
│    - Heart Rate (bpm), Cadence (rpm), Power (watts)                    │
├────────────────────────────────────────────────────────────────────────┤
│ 9. Definition & Data Messages (Lap & Session Aggregates)               │
├────────────────────────────────────────────────────────────────────────┤
│ 10. 2-Byte File CRC-16 Checksum (Polynomial 0x1021)                    │
└────────────────────────────────────────────────────────────────────────┘
```

### 10.2. Siklus Alur OAuth & Upload Strava API v3

```
  [Aplikasi CycloEdge]          [Backend OAuth Proxy]            [Strava API v3]
           │                              │                             │
    1. Klik "Connect Strava"              │                             │
    ───────┼─────────────────────────────▶│                             │
           │                              │─── 2. Redirect OAuth Web ──▶│
           │                              │    (Scope: activity:write)  │
           │◀─────────────────────────────┴─────────────────────────────│
           │   3. User Beri Izin (Menerima auth_code via Deeplink)      │
           │                                                            │
    4. Kirim auth_code                    │                             │
    ───────┼─────────────────────────────▶│                             │
           │                              │─── 5. Tukar Client Secret ─▶│
           │                              │◀── 6. Access & Refresh Token│
           │◀── 7. Kirim Secure Token ────│                             │
           │    (Simpan di Keystore)      │                             │
           │                              │                             │
  ──────────────────────── AKTIVITAS SELESAI (STOP & SAVE) ───────────────
           │                                                            │
    8. Worker Upload FIT (Multipart POST /api/v3/uploads)               │
    ───────────────────────────────────────────────────────────────────▶│
           │◀── 9. Return upload_id (Status: "Your activity is still...")│
           │                                                            │
    10. Polling Status (GET /api/v3/uploads/{upload_id}) tiap 5 detik   │
    ───────────────────────────────────────────────────────────────────▶│
           │◀── 11. Status: "Your activity is ready." (activity_id: 123) │
           │                                                            │
    12. Update sync_jobs: status = 'DONE', external_id = '123'          │
```

---

## 11. Desain UI/UX & Ergonomi Cockpit Sepeda

### 11.1. Layout Cockpit Portrait (Stem Mount)
```
+-------------------------------------------------------+
| GPS [●●●●]     BAT [92%]      HR [♥ 152 Z3]     10:42 |  <- Top Status Bar
+-------------------------------------------------------+
|                                                       |
|                                                       |
|                  MAP VIEW (Vector 2.5D)               |
|            - Polyline Biru Kontras Tinggi             |
|            - Indikator Panah Turn 100m Kanan          |
|            - Tombol Cepat: [Recenter] [Zoom In/Out]   |
|                                                       |
|                                                       |
+---------------------------+---------------------------+
| SPEED (km/h)              | DISTANCE                  |
|          34.8             |         48.2 km           |
+---------------------------+---------------------------+
| CADENCE (rpm)             | HEART RATE (bpm)          |
|           88              |      154   [Z3 TEMPO]     |
+---------------------------+---------------------------+
| POWER (3s Watts)          | ELEVATION GAIN            |
|          245 W            |          520 m            |
+---------------------------+---------------------------+
| [ LOCK ]   |   [ + LAP ]  |  [ PAUSE ]  |  [ STOP* ]  |  <- *Stop = Tahan 1.5s
+-------------------------------------------------------+
```

### 11.2. Layout Cockpit Landscape (Aero Handlebar Mount)
Untuk pesepeda *time-trial*, gravel, atau pengguna dudukan *out-front* horizontal:

```
+-----------------------------------------------------------------------------------------+
| GPS [●●●●]  BAT [88%]   10:42            CYCLOEDGE LIVE COCKPIT            HR [♥ 148] Z3|
+-------------------------------------------+------------------------------+--------------+
|                                           | SPEED (km/h)                 | DISTANCE     |
|                                           |            35.2              |   52.4 km    |
|                MAP VIEW                   +------------------------------+--------------+
|         - Vector Navigation Track         | CADENCE (rpm) | HR (bpm)     | POWER (3s)   |
|         - Turn-by-Turn Overlay            |      90       |  148 [Z3]    |    260 W     |
|         - Bounding Koridor 3 km           +---------------+--------------+--------------+
|                                           | TIME          | AVG SPEED    | ASCENT       |
|                                           |   01:42:15    |  30.8 km/h   |    610 m     |
+-------------------------------------------+---------------+--------------+--------------+
| [LOCK SCREEN]       |       [MANUAL LAP]        |        [PAUSE]       |  [STOP (HOLD)] │
+-----------------------------------------------------------------------------------------+
```

### 11.3. Mitigasi Layar Burn-in Panel OLED
Smartphone modern menggunakan panel OLED/AMOLED. Tampilan angka kecepatan yang menyala statis berjam-jam berisiko menimbulkan bayangan permanen (*burn-in*).
1. **Periodic Pixel Shifting:** Setiap interval 5 menit, seluruh koordinat kontainer grid metrik digeser secara halus sebesar 1–2 piksel secara melingkar (atas $\rightarrow$ kanan $\rightarrow$ bawah $\rightarrow$ kiri). Pergeseran ini tidak kasat mata bagi pengendara sepeda, namun meratakan beban emisi sub-piksel OLED.
2. **True Black Background:** Menggunakan warna `#000000` absolut pada latar belakang sehingga sub-piksel OLED benar-benar mati, menghemat konsumsi daya baterai hingga 40%.
3. **Tabular Numerals Font:** Mewajibkan font dengan angka monospaced (`fontFeatureSettings = "tnum"`) seperti Inter atau Roboto Mono agar lebar angka tetap stabil saat berubah dari `1` ke `8`.

---

## 12. Backlog Fitur Lanjutan (Pasca-MVP)

1. **Turn-by-Turn Offline Lengkap:** Komputasi instruksi manuver belokan dan *auto-rerouting* di perangkat tanpa sinyal internet menggunakan mesin BRouter / Valhalla C++ embedded.
2. **ClimbPro Elevation Profiler:** Deteksi otomatis segmen tanjakan di depan rute secara interaktif (menampilkan sisa jarak tanjakan, gradien rata-rata, dan visualisasi warna kelandaian).
3. **Peringatan Keselamatan (Incident Detection):** Pemantauan guncangan tinggi mendadak via akselerometer diikuti kondisi diam (*zero velocity*); memicu hitung mundur 30 detik sebelum mengirimkan SMS darurat beserta koordinat lokasi ke kontak terdaftar.
4. **Live Tracking via Web Link:** Pengiriman paket data lokasi terkompresi tiap 30 detik ke server CycloEdge agar keluarga dapat memantau posisi pengendara secara real-time melalui peramban web.
5. **Smart Trainer FTMS Mode:** Kontrol resistansi erg-mode pada smart trainer indoor via Bluetooth FTMS (`0x1826`).

---

## 13. Privasi & Keamanan (UU PDP & Enkripsi)

1. **Kepatuhan UU PDP No. 27 Tahun 2022:** Data biometrik detak jantung (*Heart Rate & HRV*) dikategorikan sebagai Data Pribadi Bersifat Spesifik. Aplikasi wajib menyertakan persetujuan eksplisit (*opt-in consent modal*) sebelum merekam data sensor kesehatan.
2. **Zona Privasi Otomatis (Privacy Zones):** Pengguna dapat menetapkan radius proteksi (mis. 500 meter) di sekitar rumah atau kantor. Algoritma ekspor FIT/Strava memotong (*truncate*) titik koordinat yang berada di dalam zona ini, melindungi lokasi tempat tinggal pengguna dari publik.
3. **Penyimpanan Token OAuth Aman:** Kredensial *access token* dan *refresh token* tidak boleh disimpan di tabel SQLite biasa, melainkan disimpan pada Android Keystore (`EncryptedSharedPreferences`) dan iOS Keychain Services.

---

## 14. Strategi Pengujian & Chaos Testing

### 14.1. Unit Test Parser Biner
Pengujian berbasis byte array mentah (*raw hexadecimal fixtures*) untuk menguji:
- HR byte payload (`uint8` vs `uint16`, dengan/tanpa RR interval).
- CSC rollover event time ($65535 \rightarrow 12$).
- Power Measurement dengan pedal balance kiri dan kanan.

### 14.2. Pengujian Ketahanan Sistem (Chaos & Soak Testing)
1. **Forced Process Murder:** Mematikan paksa proses aplikasi via terminal adb (`adb shell am kill com.cycloedge.app`) saat merekam pada kecepatan 35 km/jam. Verifikasi pemulihan data 100% saat app dibuka kembali.
2. **Bluetooth Churn Test:** Menghidupkan dan mematikan radio Bluetooth sistem setiap 60 detik selama sesi rekam berjalan. Verifikasi auto-reconnect sensor berhasil tanpa membuat service crash.
3. **Soak Test 8 Jam:** Menjalankan mock location GPS 1 Hz dan 3 koneksi peripheral BLE selama 8 jam tanpa henti pada perangkat fisik untuk memverifikasi tidak terjadi kebocoran memori (*memory leak*) pada coroutine flows dan alokasi SQLite.

---

## 15. Roadmap Pengembangan (Sprint 0 - 5)

| Sprint | Durasi | Target Utama & Deliverables | Kriteria Kelulusan (Definition of Done) |
| :--- | :---: | :--- | :--- |
| **Sprint 0** | M1–M2 | **Fondasi & Spike Uji Risiko OEM:**<br>- Setup KMP Shared Architecture & SQLite WAL.<br>- Spike Foreground Service di HP Xiaomi, Samsung, Oppo.<br>- Verifikasi lisensi Garmin FIT SDK & Strava API. | Lolos rekam background 2 jam di background layar mati pada HP OEM tanpa terbunuh. |
| **Sprint 1** | M3–M5 | **Core Telemetry Engine:**<br>- Foreground Service + Location Pipeline 1 Hz.<br>- Kalman Filter + Histeresis Auto-Pause.<br>- Batch commit SQLite & Alur Crash Recovery. | Force-kill data loss $\le 5$ detik; deviasi jarak $\le 0.8\%$ pada rute uji 20 km. |
| **Sprint 2** | M6–M8 | **Integrasi Sensor BLE GATT:**<br>- Scanner, Pairing, Reconnect Watchdog.<br>- Parser HR (`0x180D`), Dual CSC (`0x1816`), Power (`0x1818`).<br>- Dead reckoning saat GNSS hilang. | Koneksi 3 sensor simultan selama 2 jam tanpa putus permanen; unit test parser lulus 100%. |
| **Sprint 3** | M9–M11| **Peta, Koridor Offline & Navigasi:**<br>- MapLibre Native + PMTiles vector tile reader.<br>- Import rute GPX/FIT/TCX + Snapping arah rute.<br>- Audio Alert Queue & Deteksi Off-Route. | Navigasi & off-route alarm berfungsi penuh dalam mode pesawat (offline). |
| **Sprint 4** | M12–M14|**Cockpit UI, FIT Encoding & Strava:**<br>- Grid HUD Portrait & Landscape berkontras tinggi.<br>- Generator file biner FIT (Garmin SDK).<br>- Background Worker Upload Strava API v3. | Berkas FIT valid dan terverifikasi di Strava, Garmin Connect, dan intervals.icu. |
| **Sprint 5** | M15–M17|**Hardening, Thermal Guard & Beta:**<br>- Thermal Throttling Manager & Proteksi Burn-in.<br>- Privacy Zones & Audit UU PDP.<br>- Distribusi Closed Beta (Play Store & TestFlight). | Uji lapangan 100 km nyata; 0 isu kehilangan data terbuka; lulus uji review toko aplikasi. |

---

## 16. Register Risiko & Mitigasi Teknis

| ID | Risiko Teknis | Dampak | Probabilitas | Rencana Mitigasi Konkret |
| :--- | :--- | :---: | :---: | :--- |
| **R1** | OS OEM mematikan service di background | Kritis | Sangat Tinggi | Implementasikan foreground service bertipe benar, *partial wake-lock*, panduan onboarding autostart per merek, dan auto-restart `START_STICKY`. |
| **R2** | Dua sensor CSC memancarkan UUID identik | Tinggi | Tinggi | Pisahkan penanganan data berdasarkan MAC address / UUID perangkat dan bit flags byte 0 (`0x01` untuk speed, `0x02` untuk cadence). |
| **R3** | Ponsel panas ekstrem di setang sepeda | Tinggi | Tinggi | Terapkan *ThermalGuardManager*: turunkan framerate peta (15 FPS), matikan 3D layer, atau aktifkan mode darurat OLED layar hitam monokrom. |
| **R4** | Burn-in pada layar smartphone OLED | Sedang | Sedang | Terapkan algoritma *pixel shifting* periodik setiap 5 menit pada container metrik teks angka. |
| **R5** | Kehilangan daya mendadak (baterai drop) | Kritis | Sedang | Flush SQLite transaksi batch tiap 1–3 detik dengan WAL mode; checkpointing berkala agar pemulihan instan saat boot. |
| **R6** | Pelanggaran kebijakan caching OpenStreetMap | Tinggi | Rendah | Menggunakan paket PMTiles mandiri berbasis OpenMapTiles yang di-host di storage S3/CDN sendiri; 0 request ke server OSM publik. |

---

## 17. Keputusan Arsitektur & Jawaban Pertanyaan Terbuka

Berikut adalah keputusan final atas 8 pertanyaan terbuka pada versi sebelumnya:

1. **Urutan Platform & Tech Stack:**
   - **Keputusan:** Terapkan **Kotlin Multiplatform (KMP) Core Engine** dengan fokus implementasi **Android First** (Jetpack Compose). Android mencakup >85% pangsa pasar pesepeda di Indonesia dan memiliki kompleksitas manajemen baterai OEM paling kritis. Seluruh logika algoritma dan BLE pada modul KMP akan langsung di-*reuse* saat rilis antarmuka iOS (SwiftUI).
2. **Model Bisnis & Monetisasi:**
   - **Keputusan:** Model **Freemium Berkelanjutan**:
     - *Fitur Gratis:* Rekam sensor tak terbatas, metrik standar, auto-pause, ekspor FIT, dan sinkronisasi Strava.
     - *Fitur Premium (CycloEdge Pro - Rp 29.000/bulan atau Rp 199.000/tahun):* Unduh peta offline tanpa batas, visualisasi profil tanjakan ClimbPro, audio turn-by-turn guidance, dan metrik latihan canggih (NP/IF/TSS).
3. **Cakupan Backend MVP:**
   - **Keputusan:** Backend MVP dibuat ramping (*lean microservices*): hanya mencakup **OAuth Proxy (Strava)**, penyedia tile PMTiles koridor rute, dan endpoint routing A-ke-B sederhana berbasis GraphHopper. Perekaman data dan profil pengguna 100% lokal di smartphone.
4. **Integrasi Pihak Ketiga:**
   - **Keputusan:** MVP fokus eksklusif pada **Strava API v3** dan **Ekspor Lokal Berkas FIT/GPX**. Ekspor lokal memungkinkan pengguna mengunggah manual ke Intervals.icu, TrainingPeaks, atau Garmin Connect tanpa membebani jadwal rilis MVP.
5. **Hosting Peta & Anggaran Tile:**
   - **Keputusan:** Menggunakan **Cloudflare R2 Object Storage + Cloudflare CDN** untuk menyimpan paket biner PMTiles regional Indonesia. Biaya egress Cloudflare R2 adalah \$0 (bebas biaya transfer data keluar), menjaga biaya operasional server mendekati nol pada fase peluncuran awal.
6. **Batas Versi OS Minimum:**
   - **Android:** Android 10.0 (API Level 29) ke atas (mencakup 94% perangkat aktif, mendukung BLE GATT stabil dan FGS modern).
   - **iOS:** iOS 16.0 ke atas (mencakup >90% iPhone aktif, mendukung ActivityKit Live Activities).
7. **Fokus Wilayah Awal:**
   - **Keputusan:** **Indonesia**. Disesuaikan dengan karakteristik rute lokal (menghindari jalan tol, penyesuaian kontur tropis, dan mitigasi OEM smartphone Asia seperti Xiaomi/Transsion/Oppo/Vivo).
8. **Validasi Ambang NFR:**
   - **Keputusan:** Target NFR (kehilangan data $\le 5$ detik, deviasi jarak $\le 0{,}8\%$, konsumsi baterai $\le 12\%$/jam pada mode hemat) dibekukan sebagai syarat kelulusan pengujian pada Sprint 0 dan Sprint 1.

---

## 18. Glosarium Istilah

- **BLE (Bluetooth Low Energy):** Protokol komunikasi nirkabel hemat daya untuk sensor olahraga.
- **GATT (Generic Attribute Profile):** Standar hierarki Bluetooth SIG yang mengatur Services, Characteristics, dan Descriptors.
- **CSC (Cycling Speed and Cadence):** Profil BLE standar untuk pengukuran putaran roda dan kayuhan pedal.
- **FIT (Flexible and Interoperable Data Transfer):** Format biner terkompresi Garmin untuk pertukaran data telemetri olahraga.
- **Dead Reckoning:** Metode penentuan posisi saat ini berdasarkan estimasi kecepatan, jarak tempuh, dan arah sebelumnya ketika sinyal pemandu (GNSS) tidak tersedia.
- **KMP (Kotlin Multiplatform):** Teknologi kompilasi bersama logika bisnis lintas sistem operasi Android, iOS, dan Desktop.
- **PMTiles:** Format berkas tunggal terindeks berbasis piramida tile peta vektor yang mendukung kueri HTTP Range Request atau pembacaan file lokal langsung.
- **WAL (Write-Ahead Logging):** Mode operasi database SQLite di mana perubahan data dicatat terlebih dahulu dalam log terpisah sebelum disatukan ke file utama, menjamin integritas data saat terjadi gangguan daya listrik mendadak.
- **Tabular Numerals (`tnum`):** Desain glif angka tipografi dengan lebar horizontal yang persis sama untuk seluruh angka (0 sampai 9), mencegah teks bergoyang saat nilai berubah dinamis.

