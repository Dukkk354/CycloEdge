# Spesifikasi Teknis & Blueprint Produk: CycloEdge (Mobile Bike Computer)

> **Versi 2.0, 16 Oktober 2026.** Revisi menyeluruh dari v1. Dokumen ini memuat ikhtisar produk, kebutuhan terukur, arsitektur sistem, proses bisnis, integrasi sensor BLE, algoritma metrik, peta dan navigasi, tech stack, skema database, sinkronisasi, panduan UI/UX, privasi, strategi pengujian, roadmap, dan register risiko untuk aplikasi komputer sepeda *mobile* dengan kapabilitas setara Garmin Edge.

---

## Ringkasan Perubahan dari v1

- **Ditambahkan:** non-goals, persona, kompetitor, requirements dengan ID dan target terukur, state machine aktivitas, alur *crash recovery*, backend dan sinkronisasi, privasi dan keamanan, strategi pengujian, register risiko, pertanyaan terbuka, dan glosarium.
- **Dikoreksi:** rumus kecepatan roda (satuan waktu 1/1024 detik dan *rollover*), parsing HR (bit energy expended), auto-pause (histeresis), kalkulasi grade dan total ascent (smoothing dan ambang), serta sumber tile peta offline (kebijakan tile OSM).
- **Diperluas:** skema database (laps, events, profil, sepeda, sync jobs, route points, offline regions), detail Android dan iOS (tipe foreground service, izin, OEM kill, state restoration), encoding FIT, alur Strava, dan roadmap (Sprint 0 dan Sprint 5).
- **Diperbaiki:** UI/UX untuk aksesibilitas (buta warna, tabular numerals, target sentuh), tombol fisik, dan keamanan saat berkendara.

## Daftar Isi

1. [Ikhtisar Produk](#1-ikhtisar-produk)
2. [Kebutuhan (Requirements)](#2-kebutuhan-requirements)
3. [Arsitektur & Proses Bisnis](#3-arsitektur--proses-bisnis)
4. [Integrasi Sensor Bluetooth Low Energy (BLE)](#4-integrasi-sensor-bluetooth-low-energy-ble)
5. [Algoritma Metrik & Filtering](#5-algoritma-metrik--filtering)
6. [Peta, Rute & Navigasi](#6-peta-rute--navigasi)
7. [Rekomendasi Tech Stack](#7-rekomendasi-tech-stack)
8. [Spesifik Platform: Android & iOS](#8-spesifik-platform-android--ios)
9. [Skema Basis Data Lokal (SQLite)](#9-skema-basis-data-lokal-sqlite)
10. [Backend, Ekspor & Sinkronisasi](#10-backend-ekspor--sinkronisasi)
11. [Desain UI/UX Khusus Sepeda](#11-desain-uiux-khusus-sepeda)
12. [Backlog Fitur Lanjutan (Pasca-MVP)](#12-backlog-fitur-lanjutan-pasca-mvp)
13. [Privasi & Keamanan](#13-privasi--keamanan)
14. [Strategi Pengujian](#14-strategi-pengujian)
15. [Roadmap Pengembangan](#15-roadmap-pengembangan)
16. [Register Risiko](#16-register-risiko)
17. [Pertanyaan Terbuka](#17-pertanyaan-terbuka)
18. [Glosarium](#18-glosarium)

---

## 1. Ikhtisar Produk

### 1.1. Visi

CycloEdge adalah unit komputer sepeda terpadu berbasis smartphone: merekam, menavigasi, dan menganalisis perjalanan bersepeda dengan keandalan dan keterbacaan setara head unit khusus, tanpa membeli perangkat tambahan.

### 1.2. Non-Goals (MVP)

- Bukan jejaring sosial atau platform komunitas (segment leaderboard, feed, klub).
- Tidak mendukung ANT+ (HP umumnya tidak memiliki radio ANT+). Hanya BLE standar.
- Tidak mendukung sensor proprietary tertutup (radar Garmin Varia, shifting Di2/eTap) pada MVP.
- Tidak ada routing offline di perangkat pada MVP (lihat bagian 6.3). Route planning membutuhkan koneksi internet.
- Tidak ada pelatihan terstruktur (workout interval berpandu) pada MVP.
- Tidak ada companion smartwatch pada MVP.

### 1.3. Persona

| Persona | Kebutuhan Utama | Implikasi Desain |
| :--- | :--- | :--- |
| **Roadie komuter-rekreasi** (gowes pagi, 30-80 km) | Navigasi rute GPX, kecepatan, HR dari jam (Coros/Garmin), upload Strava | Layar kontras tinggi, auto-pause, rekam stabil |
| **Pesepeda tur/gravel** (ride 4-8 jam) | Peta offline, baterai awet, off-route alert, rekam tanpa putus | Mode hemat baterai, recovery, offline region |
| **Pesepeda berbasis data** (power meter, latihan) | Power, kadens, zona, NP/TSS, ekspor FIT bersih | Parsing sensor akurat, FIT valid, metrik latihan |

### 1.4. Posisi terhadap Kompetitor (Hipotesis, Validasi di Riset)

| Produk | Kekuatan Umum | Peluang untuk CycloEdge |
| :--- | :--- | :--- |
| Aplikasi rekam sosial (mis. Strava) | Komunitas, segment, analisis | Layar bike-computer khusus, navigasi offline, kustomisasi data field |
| Aplikasi rute (mis. Komoot, Ride with GPS) | Perencanaan dan navigasi rute | Rekam sensor lengkap dan recovery yang andal |
| Head unit dedicated (Garmin, Wahoo, Karoo) | Baterai, tombol fisik, sensor lengkap | Tanpa biaya perangkat tambahan, peta dan data lokal Indonesia |

### 1.5. Prinsip Desain Utama

1. **Zero Data-Loss & Realtime Persistence:** Data telemetri tidak boleh hilang akibat sistem operasi mematikan aplikasi di latar belakang (*background kills*), crash mendadak, atau baterai habis. Batas yang diterima: kehilangan paling banyak beberapa detik terakhir saat daya padam total, tanpa file korup.
2. **Keterbacaan Luar Ruang Ekstrem (*Glanceability*):** Antarmuka harus terbaca dalam fraksi detik di bawah sinar matahari langsung dan getaran jalan raya.
3. **Standarisasi Ekosistem Olahraga:** Menggunakan protokol BLE GATT standar untuk interoperabilitas dengan Coros, Garmin, Wahoo, Polar, Magene, dan sensor pihak ketiga lainnya.
4. **Local-First:** Merekam, menavigasi (di area yang sudah diunduh), dan menyimpan data harus berfungsi penuh tanpa akun dan tanpa jaringan. Backend hanya menambah kemampuan, tidak menjadi syarat.
5. **Safety-First:** Interaksi saat bergerak harus minimal (satu sentuhan, long-press untuk aksi destruktif, isyarat suara dan getar) agar pengendara tidak perlu menatap layar lama.

---

## 2. Kebutuhan (Requirements)

### 2.1. Kebutuhan Fungsional

Prioritas: **M** = MVP, **F2** = Fase 2.

| ID | Kebutuhan | Prioritas |
| :--- | :--- | :---: |
| FR-REC-01 | Merekam aktivitas 1 Hz (posisi, elevasi, kecepatan, HR, kadens, power) | M |
| FR-REC-02 | Auto-pause dan manual pause/resume dengan histeresis | M |
| FR-REC-03 | Lap manual dan auto-lap berdasarkan jarak | M |
| FR-REC-04 | Recovery otomatis aktivitas yang terputus (crash/kill/baterai habis) | M |
| FR-SEN-01 | Pairing dan auto-reconnect sensor HR, CSC, dan Power via BLE | M |
| FR-SEN-02 | Indikator status dan baterai sensor, nilai basi ditampilkan sebagai `--` | M |
| FR-NAV-01 | Import rute GPX/FIT/TCX dan tampil di peta | M |
| FR-NAV-02 | Off-route alert (suara, visual, getar) | M |
| FR-NAV-03 | Peta offline berdasarkan region/koridor rute | M |
| FR-NAV-04 | Turn-by-turn dengan cue suara | F2 |
| FR-NAV-05 | Route planner (gambar rute di peta, snapping ke jalan sepeda) | M |
| FR-UI-01 | Halaman data yang dapat dikonfigurasi (field, jumlah, urutan) | M |
| FR-UI-02 | Mode siang/malam otomatis dan manual | M |
| FR-UI-03 | Screen lock (anti ghost-touch hujan/keringat) | M |
| FR-EXP-01 | Ekspor FIT dan GPX ke penyimpanan lokal/share sheet | M |
| FR-EXP-02 | Upload otomatis ke Strava dengan antrean retry | M |
| FR-EXP-03 | Tulis ke Health Connect / HealthKit | F2 |
| FR-ANA-01 | Ringkasan aktivitas: peta, grafik, zona, lap, rekor pribadi | M |
| FR-TRN-01 | Metrik latihan: NP, IF, TSS, zona power | F2 |
| FR-SAF-01 | Deteksi jatuh dan kirim lokasi ke kontak darurat, live tracking | F2 |
| FR-BIKE-01 | Manajemen sepeda: odometer, keliling roda, pengingat servis | F2 |

### 2.2. Kebutuhan Non-Fungsional (Target Awal)

> Semua angka adalah **target awal** yang divalidasi dan disesuaikan pada Sprint 0 berdasarkan perangkat uji nyata.

| ID | Kategori | Target |
| :--- | :--- | :--- |
| NFR-DAT-01 | Durabilitas data | Setelah *force-kill* atau OS kill, data yang hilang paling banyak 5 detik terakhir; 0 file/aktivitas korup |
| NFR-DAT-02 | Recovery | 100% aktivitas berstatus `RECORDING`/`PAUSED` tersisa dapat dipulihkan saat app dibuka kembali |
| NFR-ACC-01 | Akurasi jarak | Error ≤ 1% dibanding perangkat referensi pada rute 20 km langit terbuka |
| NFR-PWR-01 | Baterai | ≤ 20%/jam dengan layar menyala dan peta aktif; ≤ 8%/jam dalam mode layar hemat |
| NFR-PRF-01 | Responsivitas | Metrik di UI diperbarui ≤ 1 detik; peta ≥ 30 FPS (target 60 FPS); cold start ke status READY ≤ 3 detik |
| NFR-BLE-01 | Stabilitas BLE | Auto-reconnect ≤ 10 detik setelah dropout; sesi 4 jam tanpa putus permanen |
| NFR-STB-01 | Stabilitas | Rekam 6 jam tanpa crash dan tanpa kebocoran memori yang terukur |
| NFR-STO-01 | Penyimpanan | Satu aktivitas 4 jam di database ≤ 5 MB (perkiraan ±1,5 MB) |
| NFR-OFF-01 | Offline | Navigasi dan off-route alert 100% berfungsi tanpa jaringan di dalam region yang sudah diunduh |
| NFR-A11Y-01 | Keterbacaan | Kontras angka utama ≥ 7:1 (setara WCAG AAA) pada kedua tema |

---

## 3. Arsitektur & Proses Bisnis

### 3.1. Diagram Arsitektur

```
[ BLE Sensors: HR / CSC / Power ]    [ GNSS (Fused/Fine 1 Hz) ]    [ Barometer ]
        │ GATT notify                        │                          │
        ▼                                    ▼                          ▼
 [ Sensor Manager ]                  [ Location Filter ]         [ Elevation Fusion ]
 (parse, freshness, rollover)        (validasi + outlier + Kalman) (baro + DEM + histeresis)
        └─────────────────┬──────────────────┴──────────────────────────┘
                          ▼
              [ Live Telemetry Engine (tick 1 Hz) ]
                          │
     ┌────────────────────┼──────────────────────────┐
     ▼                    ▼                          ▼
[ Ring Buffer ]   [ Navigation Engine ]      [ UI State Holder ]
     │            (progress, off-route, cue)   → Metric Grid, MapLibre,
     ▼ flush 1-5 s                               Alert (suara/getar)
[ SQLite (WAL) ] ◀── Recovery saat app dibuka
     │ (saat STOP)
     ▼
[ Aggregator ] → [ FIT/GPX Encoder ] → [ Sync Queue (sync_jobs) ] → Strava / Ekspor / Health
```

**Prinsip arsitektur:** Mesin perekaman (*Recording Engine*) berjalan di dalam foreground service/proses yang terpisah dari siklus hidup UI. UI hanya *mengamati* state (Flow/Observable). Jika Activity/View dimatikan, perekaman tetap berjalan.

### 3.2. State Machine Aktivitas

```
 launch ─▶ [ IDLE ] ── GPS/sensor siap ──▶ [ READY ] ── mulai ──▶ [ RECORDING ] ◀──┐
                                                                    │  ▲             │
                                                       pause/auto-pause │ resume/auto-resume
                                                                    ▼  │             │
                          [ SAVED / DISCARDED ] ◀── simpan/buang ── [ STOPPED ] ◀── [ PAUSED ] ─┘
                                                                               stop

 launch dengan aktivitas berstatus RECORDING/PAUSED tersisa:
   ─▶ [ RECOVERING ] ── lanjutkan ──▶ RECORDING
                      ── simpan   ──▶ STOPPED
                      ── buang    ──▶ DISCARDED
```

| Transisi | Pemicu | Aksi Sistem |
| :--- | :--- | :--- |
| IDLE → READY | Izin lengkap, GPS lock, sensor terpilih terhubung (atau dilewati) | Aktifkan pre-ride checklist |
| READY → RECORDING | Pengguna menekan Start | Buat baris `activities` (`status=RECORDING`), nyalakan foreground service, catat event `START` |
| RECORDING → PAUSED | Manual atau auto-pause | Catat event `PAUSE`, hentikan akumulasi *moving time* (trackpoint tetap ditulis dengan `is_paused=1`) |
| PAUSED → RECORDING | Manual atau auto-resume | Catat event `RESUME` |
| PAUSED/RECORDING → STOPPED | Long-press Stop + konfirmasi | Flush buffer, catat event `STOP`, hitung agregat |
| STOPPED → SAVED | Simpan | Buat FIT/GPX, masukkan antrean `sync_jobs`, status `FINISHED` |
| STOPPED → DISCARDED | Buang + konfirmasi | Hapus data (atau tandai `DISCARDED` dan bersihkan terjadwal) |
| (launch) → RECOVERING | Ada aktivitas berstatus `RECORDING`/`PAUSED` | Tampilkan dialog pemulihan |

### 3.3. Fase 1: Pra-Aktivitas (Persiapan & Konfigurasi)

1. **Pemeriksaan Izin & Kesiapan (*Pre-Ride Checklist*):**
   - Izin lokasi, Bluetooth, notifikasi; status hemat baterai OEM (lihat bagian 8.3).
   - GPS lock dengan indikator akurasi; baterai HP; sisa penyimpanan.
   - Peta offline untuk area rute sudah diunduh (jika ada rute aktif).
2. **Sensor Scanning & Pairing:**
   - Aplikasi memindai *peripheral* BLE di sekitar dan mengelompokkannya berdasarkan service standar (Heart Rate, CSC, Power).
   - Pengguna memilih sensor (misal: jam Coros dalam mode *Broadcast Heart Rate*). Pastikan fitur broadcast di jam menyala. Beberapa perangkat hanya mengizinkan satu koneksi sekaligus.
   - Identifier perangkat disimpan di `paired_sensors` untuk *Auto-Reconnect*. Gunakan identifier yang disediakan platform (UUID di iOS; alamat di Android, dengan cadangan nama dan service UUID).
   - Keliling roda dapat dikonfigurasi per sepeda (lihat bagian 4.4).
3. **Route Planner / Import:**
   - Pengguna menggambar rute di peta interaktif dengan titik *waypoint*. Routing engine (berbasis OpenStreetMap) menghasilkan *polyline* yang mengikuti jalan sepeda beserta profil elevasi.
   - Alternatif: import `.GPX`, `.FIT`, atau `.TCX` dari penyimpanan lokal atau tautan (Strava/Komoot/Ride with GPS).
   - Rute disederhanakan (Ramer-Douglas-Peucker), dihitung jarak kumulatif, ascent, dan cue belok (lihat bagian 6).
   - Peta area rute diunduh lokal (*offline region*, koridor sepanjang rute) agar navigasi tetap berfungsi tanpa sinyal.

### 3.4. Fase 2: Aktivitas Berjalan (Live Telemetry & Tracking Engine)

1. **Inisialisasi Layanan Prioritas Tinggi:**
   - Android: *Foreground Service* dengan tipe yang benar (`location` dan `connectedDevice`), persistent notification, dan partial wake-lock.
   - iOS: *Background Modes* untuk location dan bluetooth-central, serta *Core Bluetooth state restoration* (lihat bagian 8).
2. **Data Ingestion Loop (tick 1 Hz):**
   - **GPS:** koordinat, akurasi horizontal, kecepatan Doppler, dan bearing.
   - **Sensor BLE:** HR, CSC, dan Power via notifikasi. Setiap sampel diberi *timestamp* sistem dan diperiksa kesegarannya.
   - **Elevasi:** barometer jika tersedia (dikalibrasi), cadangan berupa kueri DEM atau altitude GPS (bagian 5.4).
3. **Filtering & Kalkulasi Metrik:** lihat bagian 5 (validasi GPS, Kalman Filter, jarak Haversine, elevasi, grade, auto-pause, zona).
4. **Navigasi & Off-Route Detection:** lihat bagian 6.6.
5. **Persistensi Lokal:**
   - Sampel per detik masuk *ring buffer* di memori, lalu di-*flush* ke SQLite (mode WAL) tiap 1-5 detik dalam **satu transaksi batch**, bukan satu insert per detik, agar I/O tidak membebani thread utama maupun baterai.
   - Setiap flush juga memperbarui `activities.last_checkpoint_ms` dan agregat berjalan (jarak, durasi) untuk pemulihan cepat.
   - Event (`PAUSE`, `RESUME`, `LAP`, `GPS_LOST`, `SENSOR_LOST`, `BATTERY_LOW`) ditulis ke `activity_events`.
6. **Manajemen Baterai Saat Merekam:**
   - Baterai ≤ 15%: sarankan mode hemat (layar OLED hitam minimal, kurangi FPS peta, kecerahan turun). Baterai ≤ 5%: *auto-save* checkpoint dan peringatan.
   - Pantau kondisi termal. Jika HP terlalu panas di bawah matahari, tampilkan peringatan dan turunkan beban render (HP yang overheat dapat meredupkan layar atau mematikan GPS).

### 3.5. Alur Crash Recovery

1. Saat app dibuka, kueri `activities` dengan `status IN ('RECORDING','PAUSED')`.
2. Untuk setiap hasil: hitung ulang agregat dari `trackpoints`, tentukan `last_checkpoint_ms` dan waktu putus.
3. Tampilkan dialog: **Lanjutkan** (resume, dengan *gap* yang ditandai sebagai `PAUSE` dari waktu putus sampai sekarang), **Simpan** (finalisasi apa adanya), atau **Buang**.
4. Catat event `RECOVERED` agar tampak pada ringkasan dan FIT (event timer stop/start di titik putus).
5. Jika *service* dimatikan OS tetapi masih ada baterai, `START_STICKY` (Android) atau *state restoration* (iOS) mencoba menyalakan ulang perekaman otomatis dan menandai gap yang terjadi.

### 3.6. Fase 3: Pasca-Aktivitas (Kompilasi & Sinkronisasi)

1. **Kompilasi Data Stat:** Total Distance, Elapsed Time, Moving Time, Average/Max Speed, Total Ascent/Descent, Avg/Max HR, Avg/Max Power, NP (jika power tersedia), Time in Zones (HR dan power), data per lap, dan kalori perkiraan.
2. **Generasi Berkas Standar Industri:** Susun trackpoint menjadi `.FIT` (utama) dan `.GPX` (opsional). FIT jauh lebih ringkas dan mendukung metrik sensor granular termasuk RR/HRV. Detail encoding di bagian 10.3.
3. **Antrean Sinkronisasi:** Tambahkan baris di `sync_jobs` per tujuan (Strava, ekspor lokal, Health). Worker menangani retry dengan backoff, bahkan setelah app ditutup (WorkManager di Android, BGTaskScheduler di iOS).
4. **Ringkasan:** Tampilkan ringkasan dengan peta, grafik kecepatan/elevasi/HR, zona, lap, dan rekor pribadi.

---

## 4. Integrasi Sensor Bluetooth Low Energy (BLE)

Jam olahraga (Coros, Garmin, Polar) dan sensor modern memakai profil GATT standar dari Bluetooth SIG.

### 4.1. Service & Characteristic Standar

| Tipe Sensor | Service UUID | Characteristic UUID | Data yang Diperoleh | Prioritas |
| :--- | :--- | :--- | :--- | :---: |
| **Heart Rate** | `0x180D` | `0x2A37` (HR Measurement) | BPM, Sensor Contact, Energy Expended, RR-Interval | M |
| **Cycling Speed & Cadence** | `0x1816` | `0x2A5B` (CSC Measurement), `0x2A5C` (CSC Feature) | Cumulative Wheel Revs, Last Wheel Event Time, Cumulative Crank Revs, Last Crank Event Time | M |
| **Cycling Power** | `0x1818` | `0x2A63` (Power Measurement), `0x2A65` (Feature) | Instantaneous Power (W), Pedal Power Balance, data crank | M |
| **Battery** | `0x180F` | `0x2A19` (Battery Level) | Persentase baterai sensor | M |
| **Device Information** | `0x180A` | (beragam) | Produsen, model, firmware | F2 |
| **Fitness Machine (FTMS)** | `0x1826` | `0x2AD2` (Indoor Bike Data), `0x2AD9` (Control Point) | Data dan kontrol smart trainer | F2 |

> **Catatan:** ANT+ tidak didukung HP pada umumnya, sehingga sensor yang hanya mendukung ANT+ (termasuk radar Varia dan shifting Di2) berada di luar cakupan.

### 4.2. Parsing Heart Rate Measurement (`0x2A37`)

Byte pertama adalah *Flags* (bitfield):

- **Bit 0:** Format HR (0 = `uint8`, 1 = `uint16`). Jam Coros umumnya mengirim `uint8`.
- **Bit 1-2:** *Sensor Contact*. Nilai 2 = didukung tetapi tidak menempel, 3 = didukung dan menempel; nilai 0 atau 1 = tidak didukung.
- **Bit 3:** *Energy Expended* hadir (2 byte, kJ).
- **Bit 4:** RR-Interval hadir (satuan 1/1024 detik, satu atau lebih `uint16`).

```
flags = b[0]
hr16       = flags & 0x01
contact    = (flags >> 1) & 0x03
has_energy = (flags >> 3) & 0x01
has_rr     = (flags >> 4) & 0x01

i = 1
hr = hr16 ? u16le(b, i) : u8(b, i);  i += hr16 ? 2 : 1
if has_energy: i += 2
if has_rr:
    while i + 1 < len(b):
        rr_ms = u16le(b, i) * 1000 / 1024;  i += 2
```

**Validasi:** abaikan sampel dengan `hr == 0` atau `contact == 2`, dan tampilkan `--` jika tidak ada sampel valid selama > 5 detik. RR-Interval disimpan untuk HRV dan pesan `hrv` pada FIT.

### 4.3. Parsing CSC Measurement (`0x2A5B`)

*Flags*: bit 0 = data roda hadir, bit 1 = data crank hadir.

```
flags = b[0]
i = 1
if flags & 0x01:   // roda
    wheel_revs = u32le(b, i);  wheel_time = u16le(b, i+4);  i += 6
if flags & 0x02:   // crank
    crank_revs = u16le(b, i);  crank_time = u16le(b, i+2)
```

Waktu event (`wheel_time`, `crank_time`) bersatuan **1/1024 detik** dan berupa `uint16` yang *rollover* tiap ±64 detik. Selisih dihitung dengan aritmetika modular:

```
dRev_wheel  = (wheel_now - wheel_prev) mod 2^32
dRev_crank  = (crank_now - crank_prev) mod 2^16
dTick       = (time_now  - time_prev)  mod 2^16
dt          = dTick / 1024.0                       // detik
```

Kecepatan dan kadens:

$$v\ (\text{m/s}) = \frac{\Delta N_{\text{wheel}} \times C\ (\text{m})}{\Delta t}, \qquad \Delta t = \frac{\Delta \text{ticks}}{1024}$$

$$\text{Cadence (rpm)} = \frac{\Delta N_{\text{crank}}}{\Delta t} \times 60$$

dengan $C$ adalah keliling roda dalam meter. Kecepatan km/jam = $v \times 3{,}6$.

**Aturan penting:**
- Sampel pertama setelah (re)connect hanya menjadi *baseline*, tidak dihitung.
- Jika `dTick == 0` (tidak ada event baru), pertahankan nilai terakhir sampai batas waktu (kecepatan ±2 detik, kadens ±3 detik), setelahnya anggap 0.
- Buang hasil tidak wajar (kecepatan > 30 m/s atau `dt` > 5 detik setelah reconnect).
- Kecepatan sensor roda lebih responsif dan akurat daripada GPS saat akselerasi, di terowongan, atau di bawah kanopi pohon, sehingga diprioritaskan (bagian 5.1).

### 4.4. Keliling Roda

- Default per ukuran ban (contoh: 700×25c ≈ 2105 mm, 700×28c ≈ 2136 mm), disimpan per sepeda.
- Kalibrasi manual: ukur *roll-out* (satu putaran roda penuh dengan beban pengendara) atau kalibrasi otomatis dengan membandingkan jarak sensor vs GPS pada ≥ 5 km langit terbuka.

### 4.5. Parsing Cycling Power Measurement (`0x2A63`)

Urutan: `flags` (`uint16`), *Instantaneous Power* (`sint16`, Watt), lalu field opsional sesuai flag.

| Bit Flag | Field Opsional |
| :---: | :--- |
| 0 | Pedal Power Balance (`uint8`, resolusi 0,5%) |
| 2 | Accumulated Torque (`uint16`) |
| 4 | Wheel Revolution Data (`uint32` + `uint16`) |
| 5 | Crank Revolution Data (`uint16` + `uint16`), sumber kadens dari power meter |

Kadens dari power meter memakai rumus crank yang sama dengan CSC. Field yang tidak hadir harus dilewati sesuai urutan flag agar offset byte tidak bergeser.

### 4.6. Sensor Manager

- **Koneksi:** gunakan identifier tersimpan untuk koneksi langsung (bukan pindai ulang). Android: `connectGatt` dengan reconnect. iOS: permintaan `connect` yang tertunda dan *state restoration*.
- **Reconnect:** *exponential backoff* 1, 2, 4, 8, maksimum 10 detik, tidak pernah menyerah selama aktivitas berjalan.
- **Kesegaran data:** tandai nilai basi (HR > 5 detik, CSC/Power > 3 detik) dan tampilkan `--` serta ikon status. Jangan menahan nilai lama.
- **Event:** catat `SENSOR_LOST` dan `SENSOR_RESTORED` ke `activity_events`.
- **Multi-sensor:** satu sensor per peran (HR, speed, cadence, power). Jika ada beberapa kandidat, pengguna memilih sumber utama.

---

## 5. Algoritma Metrik & Filtering

### 5.1. Sumber Kecepatan (Urutan Prioritas)

1. Sensor roda (jika segar dan wajar).
2. Kecepatan Doppler dari GPS (`location.speed`) bila akurasi kecepatan baik.
3. Hasil diferensiasi posisi terfilter (cadangan).

### 5.2. Pipeline Filter Posisi GPS

1. **Validasi:** tolak sampel dengan akurasi horizontal > 30 m (dapat dikonfigurasi), *timestamp* tidak monoton, atau lokasi *mock* (kecuali mode pengujian).
2. **Outlier:** tolak sampel yang menyiratkan kecepatan > 30 m/s dari posisi terakhir yang diterima.
3. **Kalman Filter** 4-state pada koordinat lokal ENU (meter) relatif terhadap titik awal: $\mathbf{x} = [x,\ y,\ v_x,\ v_y]^{T}$.
   - *Measurement noise* $R = \sigma_{acc}^2$, dengan $\sigma_{acc}$ dari nilai `accuracy` tiap sampel.
   - *Process noise* dari asumsi percepatan acak $\sigma_a \approx 1{,}0\text{-}2{,}0\ \text{m/s}^2$.
4. **Zero-Velocity Update:** jika kecepatan Doppler < 0,5 m/s, bekukan posisi untuk mencegah *drift* semu saat berhenti.

### 5.3. Jarak (Haversine)

Jarak antar titik terfilter:

$$d = 2r \arcsin\left(\sqrt{\sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta \lambda}{2}\right)}\right), \qquad r = 6{,}371{,}008.8\ \text{m}$$

Untuk mencegah akumulasi *noise* saat melambat atau berhenti, abaikan langkah jarak yang lebih kecil dari $\max(1\ \text{m},\ 0{,}5\times \text{akurasi})$ ketika kecepatan Doppler < 1 m/s. Jika sensor roda tersedia, jarak dapat dihitung dari putaran roda dan dikoreksi oleh GPS.

### 5.4. Elevasi

**Sumber (prioritas):**
1. **Barometer** (Android `TYPE_PRESSURE`, iOS `CMAltimeter`). Tekanan dikonversi ke ketinggian:
$$h = 44330 \times \left(1 - \left(\frac{P}{P_0}\right)^{1/5{,}255}\right)$$
   Kalibrasi $P_0$ saat start memakai DEM atau altitude GPS, lalu koreksi *offset* perlahan (filter komplementer, gain kecil) untuk mengimbangi perubahan cuaca.
2. **DEM** (Copernicus GLO-30 atau SRTM 30 m; ubin elevasi pada peta) sebagai cadangan.
3. **Altitude GPS** sebagai cadangan terakhir (paling berisik).

**Smoothing:** median 5 sampel, lalu EMA.

**Total Ascent/Descent dengan histeresis:**

```
anchor = h_0
for each h in smoothed_elevation:
    if h - anchor >= T:  ascent  += (h - anchor);  anchor = h
    elif anchor - h >= T: descent += (anchor - h); anchor = h
```

Ambang $T$: ±1-2 m untuk barometer, ±5-10 m untuk DEM/GPS. Tanpa ambang ini, total ascent akan membengkak.

### 5.5. Grade (Kelandaian)

Hitung kelandaian pada jendela jarak, bukan per detik:

$$\text{Grade (\%)} = \frac{h_t - h_{t-w}}{d_t - d_{t-w}} \times 100, \qquad w \approx 30\text{-}50\ \text{m}$$

- Gunakan elevasi yang sudah di-*smooth*.
- Wajibkan $\Delta d \geq 20\ \text{m}$ dan batasi tampilan ke ±30%.
- Gradient ke depan (profil rute) dihitung dari `route_points` yang sudah dihaluskan.

### 5.6. Auto-Pause dengan Histeresis

- **Masuk pause:** kecepatan < 2,0 km/jam terus-menerus selama ≥ 5 detik (dapat dikonfigurasi 3-10 detik).
- **Lanjut:** kecepatan > 3,0 km/jam selama ≥ 2 detik.
- Gunakan kecepatan sensor roda bila ada. Ambang berbeda untuk masuk dan keluar mencegah *flapping* akibat *jitter* GPS.
- Saat pause, `moving time` berhenti tetapi `elapsed time` tetap jalan; trackpoint tetap ditulis dengan `is_paused=1`.

### 5.7. Waktu

- Hitung durasi dengan jam monoton (`SystemClock.elapsedRealtime` / `ProcessInfo.systemUptime`), bukan jam dinding, agar kebal terhadap perubahan zona waktu atau koreksi waktu otomatis.
- Simpan *timestamp* absolut dalam UTC milidetik.

### 5.8. Zona Detak Jantung & Power

**Zona HR default (% HRmax), dapat dikonfigurasi atau berbasis LTHR:**

| Zona | Nama | % HRmax |
| :---: | :--- | :--- |
| Z1 | Recovery | 50-60% |
| Z2 | Endurance | 60-70% |
| Z3 | Tempo | 70-80% |
| Z4 | Threshold | 80-90% |
| Z5 | Anaerobic | 90-100% |

**Zona power (% FTP, skema umum):** Z1 < 55%, Z2 56-75%, Z3 76-90%, Z4 91-105%, Z5 106-120%, Z6 121-150%, Z7 > 150%.

### 5.9. Metrik Turunan

- **Avg Speed** dihitung dari jarak dibagi *moving time*; **Max Speed** dari nilai tersaring (abaikan lonjakan GPS).
- **Normalized Power (NP):** rata-rata bergulir 30 detik dari power, dipangkatkan 4, dirata-ratakan, lalu diakarkan pangkat 4.
$$\text{IF} = \frac{\text{NP}}{\text{FTP}}, \qquad \text{TSS} = \frac{t_{\text{detik}} \times \text{NP} \times \text{IF}}{\text{FTP} \times 3600} \times 100$$
- **Kalori:** dengan power, kerja mekanis (kJ) ≈ kcal sebagai perkiraan kasar. Tanpa power, gunakan perkiraan berbasis HR (opsional, butuh profil pengguna).
- **Metrik per lap:** jarak, durasi bergerak, avg speed/HR/power, ascent.

---

## 6. Peta, Rute & Navigasi

### 6.1. Sumber Tile & Gaya Peta

- **Renderer:** MapLibre Native SDK (open-source, mendukung vector tiles).
- **Sumber tile:** gunakan **PMTiles/MBTiles** vector tile (skema OpenMapTiles atau Protomaps) yang di-host sendiri (object storage + CDN, dengan HTTP range request untuk PMTiles) atau dari penyedia berbayar.
- **Penting:** server tile publik OpenStreetMap (`tile.openstreetmap.org`) melarang unduhan massal untuk cache offline. Jangan gunakan untuk *offline tile caching*.
- **Atribusi:** tampilkan "© OpenStreetMap contributors" dan atribusi penyedia tile.
- **Gaya:** dua tema (siang dan malam/OLED), lapisan khusus sepeda (jalur sepeda, kelas jalan, kontur), dan garis rute berkontras tinggi.

### 6.2. Offline Region Manager

- Pengguna memilih area (bounding box) atau **koridor rute** (buffer 2-5 km di sepanjang polyline).
- Tampilkan **estimasi ukuran** sebelum unduh; dukung progres, jeda/lanjut, dan hapus. Simpan metadata di tabel `offline_regions`.
- Zoom vector yang disarankan: sekitar 8-15 untuk koridor rute.
- Pada pre-ride checklist, peringatkan jika rute aktif belum tercakup region offline.

### 6.3. Routing

| Mode | Teknologi | Cakupan |
| :--- | :--- | :--- |
| **Online (backend)** | GraphHopper atau OSRM, profil `bike`/`racingbike`/`mtb` dari OSM | MVP |
| **Offline di perangkat** | BRouter atau Valhalla (data routing per region) | Fase 2 (periksa lisensi dan ukuran data) |

**Catatan khusus Indonesia:**
- Profil routing wajib **menghindari jalan tol** dan ruas bertag `bicycle=no` (sepeda dilarang di jalan tol).
- Infrastruktur jalur sepeda terbatas dan lalu lintas sepeda motor padat. Beri opsi preferensi *"hindari jalan arteri padat"* dan prioritaskan jalan kecil/tenang.
- Kualitas data OSM bervariasi antar daerah. Sediakan tombol laporan rute buruk (Fase 2).

### 6.4. Data Elevasi untuk Rute

Gunakan DEM (Copernicus GLO-30 atau SRTM 30 m) atau ubin *terrain-RGB* untuk profil elevasi rute yang digambar. Rute impor GPX/FIT yang sudah memiliki elevasi dipakai apa adanya setelah di-*smooth*.

### 6.5. Import GPX/FIT/TCX

1. Parse dan validasi (koordinat valid, minimal beberapa titik, urutan waktu opsional).
2. Sederhanakan dengan **Ramer-Douglas-Peucker** (toleransi ±3-5 m) sambil menjaga elevasi. Batasi jumlah titik (misal ≤ 20.000).
3. Hitung jarak kumulatif (`dist_from_start_m`), total ascent/descent, dan simpan ke `route_points`.
4. Ekstrak *waypoint*/instruksi belok menjadi `route_cues` bila ada.

### 6.6. Navigation Engine

**Progress snapping.** Proyeksikan posisi ke polyline rute dalam jendela pencarian ±500 m dari progres terakhir (agar benar pada rute melingkar atau *out-and-back*). Dengan proyeksi ekuirektangular lokal:

$$x = (\lambda - \lambda_0)\, R \cos\phi_0, \qquad y = (\phi - \phi_0)\, R$$

jarak titik $P$ ke segmen $AB$:

$$t = \text{clamp}\left(\frac{(P-A)\cdot(B-A)}{\lVert B-A\rVert^{2}},\ 0,\ 1\right), \qquad d_{\perp} = \lVert P - (A + t(B-A)) \rVert$$

**Off-route detection:**
- Ambang adaptif: $d_\perp > \max(30\ \text{m},\ 2\times\text{akurasi GPS})$.
- *Debounce*: kondisi harus bertahan ≥ 5 detik berturut-turut sebelum alert.
- *Cooldown* ulang alert 30 detik; saat kembali ke rute, kirim cue "Kembali ke rute".
- Opsi *"kembali ke rute"*: panah/bearing ke titik rute terdekat di depan (offline), atau permintaan *re-route* (online).

**Turn cue:**
- Pemicu adaptif berdasarkan kecepatan (target ±10 detik sebelum belokan, misal sekitar 300 m, 100 m, 30 m).
- Suara memakai TTS platform dengan *audio ducking* terhadap musik. Cue juga ditampilkan visual dan getar.

**ETA & progres:** ETA dari rata-rata kecepatan bergerak 10 menit terakhir; tampilkan sisa jarak dan sisa ascent.

---

## 7. Rekomendasi Tech Stack

Kebutuhan pemrosesan real-time, koneksi Bluetooth persisten, dan rendering peta mulus menentukan pilihan teknologi.

```
+------------------------------------------------------------------------+
|                      Rekomendasi Arsitektur                            |
+------------------------------------------------------------------------+
| [Opsi 1 - Rekomendasi Terbaik] Fully Native                            |
| Android: Kotlin + Jetpack Compose + Room + Coroutines Flows            |
| iOS: Swift + SwiftUI + CoreBluetooth + GRDB + Swift Concurrency        |
+------------------------------------------------------------------------+
| [Opsi 2 - Cross-Platform Terbaik] Flutter (Dart)                       |
| flutter_blue_plus + maplibre + drift (SQLite) + isolates               |
| + layanan background native (foreground service / background modes)    |
+------------------------------------------------------------------------+
```

### 7.1. Analisis Perbandingan

| Parameter | Native (Kotlin & Swift) | Flutter (Dart) | React Native |
| :--- | :--- | :--- | :--- |
| **BLE di Background** | **Sangat Tinggi** (akses langsung `BluetoothGatt` / CoreBluetooth) | **Tinggi** (plugin `flutter_blue_plus`, tetap perlu servis native) | **Sedang** (rentan throttling di *bridge*) |
| **Background Location & Doze** | **Sangat Akurat** (kontrol penuh WAKELOCK dan foreground service) | **Bagus** (perlu *method channel* native tambahan) | **Cukup Rumit** (sering terkena OS power-saving kill) |
| **Performa Render Peta & UI** | **Maksimal** | **Tinggi** (Impeller) | **Sedang** |
| **Kecepatan Pengembangan** | Dua basis kode (Kotlin & Swift) | Satu basis kode | Satu basis kode |
| **Risiko Fitur Khusus OS** | Terendah | Sedang | Tertinggi |

**Keputusan:**
- Jika fokus pada performa dan keandalan setara unit profesional: **Native (Kotlin & Swift)**.
- Jika ingin MVP secepat mungkin dengan sumber daya terbatas: **Flutter**, dengan *Recording Engine* (service, BLE, lokasi) tetap ditulis native di sisi Android/iOS dan UI Flutter hanya mengamatinya.
- **Hindari React Native** untuk proyek ini karena batasan latensi thread Bluetooth dan *background loop* GPS.
- **Strategi urutan rilis (usulan):** Android lebih dulu (pangsa Android sangat dominan di Indonesia), iOS menyusul. Lihat bagian 17.

### 7.2. Pustaka & Ekosistem

| Kebutuhan | Pilihan |
| :--- | :--- |
| Peta | **MapLibre Native** + tile PMTiles/MBTiles (bagian 6.1) |
| Routing online | **GraphHopper** atau **OSRM** (profil `bike`, `racingbike`, `mtb`) |
| Routing offline (Fase 2) | BRouter atau Valhalla, periksa lisensi dan ukuran data |
| FIT | **Garmin FIT SDK** (Java/Kotlin, Swift, C, C#). Periksa syarat lisensi FIT Protocol |
| Database lokal | SQLite via Room (Android) atau GRDB.swift (iOS), WAL aktif |
| Penjadwalan background | WorkManager (Android), BGTaskScheduler (iOS) |
| Penyimpanan rahasia | Android Keystore / EncryptedSharedPreferences, iOS Keychain |
| Crash & analitik | Crash reporting (mis. Crashlytics atau Sentry); analitik dengan persetujuan |
| CI/CD | Build dan uji otomatis, distribusi beta (Play Internal Testing, TestFlight) |

---

## 8. Spesifik Platform: Android & iOS

### 8.1. Android

- **Foreground Service:** deklarasikan `android:foregroundServiceType="location|connectedDevice"` dan izin `FOREGROUND_SERVICE_LOCATION` serta `FOREGROUND_SERVICE_CONNECTED_DEVICE` (Android 14+). Notifikasi persisten menampilkan jarak, waktu, dan tombol Pause/Stop.
- **Izin bertahap:**
  - Lokasi presisi (`ACCESS_FINE_LOCATION`).
  - Android 12+: `BLUETOOTH_SCAN` (gunakan flag `neverForLocation` bila tidak menurunkan lokasi dari scan) dan `BLUETOOTH_CONNECT`. Android ≤ 11 membutuhkan izin lokasi untuk pemindaian.
  - Android 13+: `POST_NOTIFICATIONS`.
  - `ACCESS_BACKGROUND_LOCATION` umumnya **tidak diperlukan** jika foreground service bertipe `location` dimulai saat app terlihat di layar. Verifikasi di Sprint 0 (menyederhanakan peninjauan Google Play).
- **Lokasi:** `FusedLocationProviderClient` dengan prioritas akurasi tinggi dan interval 1000 ms. Sediakan cadangan `LocationManager` (GPS) untuk perangkat tanpa layanan Google. Pertimbangkan data GNSS mentah (dual-frequency L1/L5) pada Fase 2 untuk akurasi di kota.
- **Wake-lock:** partial wake-lock selama merekam; lepaskan saat berhenti.
- **Restart:** `START_STICKY` dan jalur recovery (bagian 3.5).

### 8.2. iOS

- **Background Modes:** `location` dan `bluetooth-central`.
- **CLLocationManager:** `allowsBackgroundLocationUpdates = true`, `pausesLocationUpdatesAutomatically = false`, akurasi terbaik, tipe aktivitas olahraga/navigasi.
- **Core Bluetooth:** gunakan *state preservation and restoration* (`CBCentralManagerOptionRestoreIdentifierKey`) agar koneksi sensor dapat dipulihkan setelah app dihentikan sistem.
- **Elevasi:** `CMAltimeter` untuk perubahan ketinggian relatif.
- **Fase 2:** Live Activity untuk tampilan data di layar kunci.

### 8.3. Ancaman OEM Kill (Sangat Relevan di Indonesia)

Produsen seperti Xiaomi/Redmi/Poco, Oppo/Realme, Vivo, dan Samsung menerapkan manajemen baterai agresif yang dapat mematikan foreground service.

- Sediakan **onboarding per merek** (panduan visual): aktifkan *autostart*, setel baterai ke "Tanpa batasan", kunci app di *recent apps*.
- Deteksi kondisi pengaturan yang berisiko dan tampilkan peringatan di *pre-ride checklist*.
- Permintaan pengecualian optimasi baterai (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) dibatasi kebijakan Play. Gunakan hanya bila memenuhi syarat, jika tidak arahkan pengguna ke pengaturan sistem.
- Ukur dan dokumentasikan perilaku per perangkat dalam *test matrix* (bagian 14).

### 8.4. Tombol Fisik & Remote

- **Tombol Volume:** di iOS tidak didukung resmi untuk dialihfungsikan, dan di Android umumnya hanya terdeteksi saat app aktif di layar. **Jangan dijanjikan sebagai fitur inti** sebelum diverifikasi di Sprint 0.
- **Alternatif yang lebih andal:** remote Bluetooth (HID/media key) di setang atau tombol media pada earphone, ditangani lewat `MediaSession` (Android) dan `MPRemoteCommandCenter` (iOS). Contoh pemetaan: tombol 1 = Lap, tombol 2 = Pause/Resume.

---

## 9. Skema Basis Data Lokal (SQLite)

### 9.1. Pengaturan Koneksi

```sql
PRAGMA journal_mode = WAL;     -- tetap aktif (persisten pada file)
PRAGMA synchronous  = NORMAL;  -- aman terhadap app crash; ganti FULL untuk durabilitas maksimum (lebih lambat)
PRAGMA foreign_keys = ON;      -- WAJIB di setiap koneksi, kalau tidak ON DELETE CASCADE tidak jalan
PRAGMA user_version = 1;       -- versi skema untuk migrasi
```

> **Catatan durabilitas:** dengan WAL dan `synchronous=NORMAL`, crash atau kill app tidak menghilangkan data yang sudah di-*commit*. Pada kehilangan daya total (HP mati), beberapa transaksi terakhir dapat hilang tetapi database tidak korup. Karena itu *flush* dilakukan tiap 1-5 detik.

### 9.2. Profil, Sepeda, dan Pengaturan

```sql
-- Profil pengguna (satu baris)
CREATE TABLE user_profile (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    display_name TEXT,
    birth_year INTEGER,
    weight_kg REAL,
    max_hr INTEGER,
    resting_hr INTEGER,
    lthr INTEGER,
    ftp_watts INTEGER,
    hr_zones_json TEXT,        -- batas zona kustom
    power_zones_json TEXT,
    units TEXT NOT NULL DEFAULT 'metric',  -- 'metric' | 'imperial'
    language TEXT NOT NULL DEFAULT 'id'
);

-- Sepeda
CREATE TABLE bikes (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    bike_type TEXT,                         -- 'ROAD','GRAVEL','MTB','URBAN'
    wheel_circumference_mm INTEGER NOT NULL DEFAULT 2105,
    odometer_meters REAL NOT NULL DEFAULT 0,
    is_default INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL
);

-- Pengingat perawatan (Fase 2)
CREATE TABLE maintenance_items (
    id TEXT PRIMARY KEY,
    bike_id TEXT NOT NULL REFERENCES bikes(id) ON DELETE CASCADE,
    name TEXT NOT NULL,                     -- 'Rantai','Ban belakang', dst.
    interval_meters REAL NOT NULL,
    last_service_odometer_m REAL NOT NULL DEFAULT 0,
    notes TEXT
);

-- Profil aktivitas (layout data page, alert, auto-pause)
CREATE TABLE activity_profiles (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,                     -- 'Road','MTB','Indoor'
    sport TEXT NOT NULL DEFAULT 'cycling',
    auto_pause_enabled INTEGER NOT NULL DEFAULT 1,
    auto_pause_stop_kmh REAL NOT NULL DEFAULT 2.0,
    auto_pause_resume_kmh REAL NOT NULL DEFAULT 3.0,
    auto_lap_distance_m INTEGER,
    data_pages_json TEXT NOT NULL,          -- konfigurasi halaman dan field
    alerts_json TEXT
);

-- Zona privasi (disembunyikan saat ekspor/sinkronisasi)
CREATE TABLE privacy_zones (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    radius_m INTEGER NOT NULL DEFAULT 300,
    is_active INTEGER NOT NULL DEFAULT 1
);
```

### 9.3. Aktivitas, Trackpoint, Lap, dan Event

```sql
-- Sesi aktivitas (waktu = epoch milidetik UTC; kecepatan = m/s agar konsisten dengan FIT)
CREATE TABLE activities (
    id TEXT PRIMARY KEY,                    -- UUID
    title TEXT NOT NULL,
    sport TEXT NOT NULL DEFAULT 'cycling',
    bike_id TEXT REFERENCES bikes(id) ON DELETE SET NULL,
    profile_id TEXT REFERENCES activity_profiles(id) ON DELETE SET NULL,
    route_id TEXT REFERENCES routes(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'RECORDING'
        CHECK (status IN ('RECORDING','PAUSED','STOPPED','FINISHED','DISCARDED')),
    start_time_ms INTEGER NOT NULL,
    end_time_ms INTEGER,
    last_checkpoint_ms INTEGER,             -- diperbarui tiap flush (untuk recovery)
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
    notes TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
CREATE INDEX idx_activities_status ON activities(status);
CREATE INDEX idx_activities_start ON activities(start_time_ms DESC);

-- Trackpoint (1 baris/detik). WITHOUT ROWID: kunci komposit = indeks, hemat ruang dan I/O.
-- Lat/lon nullable agar sampel sensor tetap tersimpan saat GPS hilang atau indoor.
CREATE TABLE trackpoints (
    activity_id TEXT NOT NULL,
    ts_ms INTEGER NOT NULL,
    latitude REAL,
    longitude REAL,
    gps_accuracy_m REAL,
    elevation_m REAL,
    distance_m REAL NOT NULL,               -- jarak kumulatif dari start
    speed_mps REAL,
    heart_rate INTEGER,
    cadence INTEGER,
    power_w INTEGER,
    temperature_c REAL,
    grade_pct REAL,
    is_paused INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (activity_id, ts_ms),
    FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
) WITHOUT ROWID;

-- Interval RR (untuk HRV dan pesan hrv pada FIT)
CREATE TABLE rr_intervals (
    activity_id TEXT NOT NULL,
    ts_ms INTEGER NOT NULL,
    rr_ms REAL NOT NULL,
    FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
);
CREATE INDEX idx_rr_activity ON rr_intervals(activity_id, ts_ms);

-- Lap
CREATE TABLE laps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    activity_id TEXT NOT NULL,
    lap_index INTEGER NOT NULL,
    trigger TEXT NOT NULL DEFAULT 'MANUAL', -- 'MANUAL','DISTANCE','TIME','POSITION'
    start_ms INTEGER NOT NULL,
    end_ms INTEGER,
    distance_m REAL,
    moving_s INTEGER,
    avg_speed_mps REAL,
    avg_heart_rate INTEGER,
    avg_power_w INTEGER,
    ascent_m REAL,
    UNIQUE (activity_id, lap_index),
    FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
);

-- Event timeline (dipakai juga untuk pesan event pada FIT)
CREATE TABLE activity_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    activity_id TEXT NOT NULL,
    ts_ms INTEGER NOT NULL,
    event_type TEXT NOT NULL,   -- START, PAUSE, RESUME, STOP, LAP, AUTO_PAUSE, GPS_LOST,
                                -- GPS_RESTORED, SENSOR_LOST, SENSOR_RESTORED, BATTERY_LOW,
                                -- OFF_ROUTE, BACK_ON_ROUTE, RECOVERED
    data_json TEXT,
    FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
);
CREATE INDEX idx_events_activity ON activity_events(activity_id, ts_ms);
```

### 9.4. Rute, Cue, dan Peta Offline

```sql
-- Master rute
CREATE TABLE routes (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    source TEXT NOT NULL,                   -- 'DRAWN','GPX','FIT','TCX','STRAVA','KOMOOT'
    distance_m REAL NOT NULL,
    ascent_m REAL NOT NULL DEFAULT 0,
    descent_m REAL NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- Titik rute (sudah disederhanakan; jarak kumulatif disimpan untuk progres cepat)
CREATE TABLE route_points (
    route_id TEXT NOT NULL,
    seq INTEGER NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    elevation_m REAL,
    dist_from_start_m REAL NOT NULL,
    PRIMARY KEY (route_id, seq),
    FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE
) WITHOUT ROWID;

-- Instruksi belok / waypoint
CREATE TABLE route_cues (
    route_id TEXT NOT NULL,
    seq INTEGER NOT NULL,
    dist_from_start_m REAL NOT NULL,
    cue_type TEXT NOT NULL,                 -- 'LEFT','RIGHT','STRAIGHT','UTURN','POI',...
    text TEXT,
    PRIMARY KEY (route_id, seq),
    FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE
) WITHOUT ROWID;

-- Region peta offline
CREATE TABLE offline_regions (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    min_lat REAL NOT NULL, min_lon REAL NOT NULL,
    max_lat REAL NOT NULL, max_lon REAL NOT NULL,
    min_zoom INTEGER NOT NULL,
    max_zoom INTEGER NOT NULL,
    tile_source TEXT NOT NULL,
    size_bytes INTEGER,
    status TEXT NOT NULL DEFAULT 'PENDING', -- 'PENDING','DOWNLOADING','READY','FAILED'
    downloaded_at INTEGER
);
```

### 9.5. Sensor dan Antrean Sinkronisasi

```sql
-- Sensor yang pernah dipasangkan
CREATE TABLE paired_sensors (
    sensor_id TEXT PRIMARY KEY,             -- UUID (iOS) atau alamat (Android), sesuai platform
    name TEXT NOT NULL,
    sensor_type TEXT NOT NULL
        CHECK (sensor_type IN ('HEART_RATE','SPEED','CADENCE','SPEED_CADENCE','POWER')),
    bike_id TEXT REFERENCES bikes(id) ON DELETE SET NULL,
    is_enabled INTEGER NOT NULL DEFAULT 1,
    last_battery_pct INTEGER,
    last_connected_at INTEGER
);

-- Antrean sinkronisasi generik (menggantikan is_synced_strava)
CREATE TABLE sync_jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    activity_id TEXT NOT NULL,
    provider TEXT NOT NULL,                 -- 'STRAVA','INTERVALS','TRAININGPEAKS','LOCAL_EXPORT','HEALTH'
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING','UPLOADING','PROCESSING','DONE','FAILED','SKIPPED')),
    external_id TEXT,                       -- id aktivitas di penyedia
    attempts INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    next_retry_at INTEGER,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    UNIQUE (activity_id, provider),
    FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
);
```

### 9.6. Catatan Implementasi Database

- **Token OAuth tidak disimpan di SQLite.** Gunakan Keystore/Keychain.
- **Batch insert:** tulis trackpoint dalam satu transaksi per flush (`INSERT OR REPLACE`). Perkiraan ±100 byte/baris, jadi 4 jam (±14.400 baris) ≈ 1,5 MB.
- **Checkpoint WAL:** jalankan `wal_checkpoint(PASSIVE)` berkala dan `TRUNCATE` setelah aktivitas selesai agar file WAL tidak membengkak.
- **Migrasi:** kelola lewat `PRAGMA user_version` dengan skrip migrasi berurutan dan uji migrasi dari tiap versi.
- **Retensi:** simpan FIT hasil ekspor sebagai sumber kebenaran. Sediakan opsi pembersihan data mentah lama.
- **Privacy zone:** diterapkan **saat ekspor/sinkronisasi**, bukan saat penyimpanan lokal.

---

## 10. Backend, Ekspor & Sinkronisasi

### 10.1. Prinsip

Aplikasi *local-first*: seluruh perekaman bekerja tanpa backend. Backend hanya menambah kemampuan.

### 10.2. Komponen Backend

| Komponen | Fungsi | Prioritas |
| :--- | :--- | :---: |
| **OAuth proxy** | Penukaran kode OAuth (mis. Strava) dengan *client secret* di server. Rahasia ini tidak boleh tertanam di app | M |
| **Routing API** | GraphHopper/OSRM di balik API | M |
| **Tile hosting (CDN)** | Menyajikan PMTiles/vector tile dan paket region offline | M |
| **Akun & backup awan** | Sinkron rute dan pengaturan antar perangkat | F2 |
| **Live tracking & safety** | Tautan pelacakan langsung, notifikasi kontak darurat | F2 |
| **Analitik & crash** | Pelaporan dengan persetujuan pengguna | M |

### 10.3. Encoding FIT

**Urutan pesan** pada file `activity`: `file_id` → `file_creator` → `device_info` → `event` (timer start) → `record` (1 Hz) dan `hrv` → `event` (pause/resume/stop) → `lap` → `session` → `activity`.

**Konversi satuan penting:**

| Field | Konversi |
| :--- | :--- |
| `timestamp` | Detik sejak 1989-12-31 00:00:00 UTC, yaitu `unix_s - 631065600` |
| `position_lat/long` | Derajat × (2³¹ / 180) → *semicircles* |
| `enhanced_speed` | m/s × 1000 (mm/s) |
| `enhanced_altitude` | (meter + 500) × 5 |
| `distance` | meter × 100 (cm) |

**Validasi hasil:** unggah ke Strava/Garmin Connect/intervals.icu atau alat FIT (mis. FIT File Tool, konversi ke CSV) dan jadikan file referensi sebagai *golden test*. Sediakan **GPX** (dengan ekstensi TrackPoint untuk HR/kadens) sebagai ekspor cadangan.

### 10.4. Integrasi Strava

1. **Autentikasi:** OAuth2 melalui backend proxy. Minta scope `activity:write` (tambah `read` bila diperlukan). Access token berumur pendek, jadi implementasikan *refresh token*.
2. **Upload:** `POST /api/v3/uploads` (multipart) dengan `file`, `data_type=fit`, `name`, dan `external_id` (ID aktivitas lokal) untuk deduplikasi.
3. **Polling:** `GET /api/v3/uploads/{id}` hingga `activity_id` tersedia atau ada error (mis. duplikat). Perbarui `sync_jobs`.
4. **Retry:** *exponential backoff*, tetap jalan walau app tertutup.
5. **Rate limit:** ada batas per 15 menit dan per hari. Cek dokumentasi terbaru dan hormati header limit.
6. **Kepatuhan:** baca *API Agreement* dan *Brand Guidelines* terbaru (logo, penggunaan data). Aplikasi baru umumnya awalnya dibatasi jumlah atlet terhubung sampai disetujui, jadi **ajukan sejak Sprint 0**.

### 10.5. Ekspor & Integrasi Lain

- **Lokal:** share sheet (iOS) dan Storage Access Framework (Android).
- **intervals.icu / TrainingPeaks:** upload via API masing-masing (Fase 2).
- **Garmin Connect:** API resmi melalui program developer/partner. Alternatifnya pengguna mengimpor file FIT secara manual.
- **Health Connect (Android) dan HealthKit (iOS):** tulis sesi olahraga, rute, dan HR (Fase 2).

---

## 11. Desain UI/UX Khusus Sepeda

Ponsel dipasang di *out-front handlebar mount*, terpapar matahari langsung, terguncang, dan dioperasikan dengan satu tangan atau sarung tangan. Pengendara hanya punya sepersekian detik untuk melirik layar.

### 11.1. Layout Utama

```
+------------------------------------------+
|  GPS ●●●  [BAT 88%]  [HR ♥ 142 Z3]  ● ○ ○ |  <- Status bar (+ indikator halaman)
+------------------------------------------+
|                                          |
|            MAP VIEW (±50%)               |
|      - Vector Map (Dark/Light mode)      |
|      - Garis rute kontras tinggi         |
|      - Indikator belok / off-route       |
|                                          |
+------------------------------------------+
| SPEED (km/h)      | DISTANCE             |
|   32.4            |    45.2 km           |  <- Field besar, glanceable
+-------------------+----------------------+
| AVG SPEED         | HEART RATE           |
|   28.1 km/h       |    148 bpm  Z3       |  <- Warna + LABEL zona
+-------------------+----------------------+
| TIME              | ELEVATION GAIN       |
|   01:36:20        |    480 m             |
+------------------------------------------+
|  [ LOCK ]   [ LAP ]   [ PAUSE ]  [ STOP* ]|  <- *STOP = tekan lama
+------------------------------------------+
```

### 11.2. Halaman yang Dapat Digeser

| Halaman | Isi |
| :--- | :--- |
| **Peta + Metrik** | Layout di atas (default) |
| **Data Penuh** | 4-8 field besar tanpa peta |
| **Navigasi** | Cue belok, sisa jarak, panah arah, profil elevasi ke depan |
| **Elevasi/Tanjakan** | Profil rute, posisi, kelandaian saat ini |
| **Sensor & Status** | Status GPS, sensor, baterai, penyimpanan |
| **Lap** | Daftar dan ringkasan lap |

Halaman dan field dikonfigurasi per **profil aktivitas** (Road, MTB, Indoor). Gestur geser dapat dikunci bersama *screen lock* untuk mencegah sentuhan tak sengaja.

### 11.3. Tipografi & Layout

1. **Angka tabular:** gunakan font dengan angka lebar tetap agar angka tidak "bergoyang" saat berubah. Aktifkan fitur OpenType `tnum` (mis. Inter) atau gunakan font mono seperti Roboto Mono atau JetBrains Mono. Jangan berasumsi Bebas Neue atau DIN Alternate bertabular, **uji dulu**.
2. **Ukuran:** field utama ≥ 48 sp (idealnya 60-72 sp), label kecil dan jelas.
3. **Palet kontras tinggi:**
   - **Mode Siang:** latar putih murni (`#FFFFFF`), angka hitam (`#000000`), garis rute biru tua atau magenta.
   - **Mode Malam / OLED Saver:** latar hitam murni (`#000000`), teks putih, aksen hijau neon (`#39FF14`) atau kuning stabilo (`#FFF01F`).
   - Target kontras angka utama ≥ 7:1.
4. **Pergantian tema otomatis** berdasarkan sensor cahaya dengan histeresis (hindari berkedip) dan *override* manual.

### 11.4. Warna Zona yang Ramah Buta Warna

Warna saja tidak cukup. Setiap zona harus diberi **label teks ("Z3") dan/atau ikon/bentuk**.

| Zona | Warna Saran | Label |
| :--- | :--- | :---: |
| Zone 1 (Recovery) | Abu-abu `#9E9E9E` | Z1 |
| Zone 2 (Endurance) | Biru `#2979FF` | Z2 |
| Zone 3 (Tempo) | Hijau `#00C853` | Z3 |
| Zone 4 (Threshold) | Oranye `#FF9100` | Z4 |
| Zone 5 (Anaerobic) | Merah `#FF1744` | Z5 |

Verifikasi kontras tiap warna pada kedua tema dan simulasikan dengan filter buta warna.

### 11.5. Proteksi Operasional & Interaksi

- **Rain & Sweat Lock:** satu ketukan mengunci layar sentuh agar kebal terhadap *ghost touch* dari hujan/keringat. Buka kunci dengan gestur yang disengaja (tahan atau geser).
- **Target sentuh besar:** ≥ 56 dp untuk tombol utama (mode sarung tangan 64 dp).
- **Aksi destruktif aman:** Stop dengan *long-press*, Buang dengan konfirmasi.
- **Tombol eksternal:** remote Bluetooth/media key (bagian 8.4).
- **Layar:** `keep screen on` dengan mode *screen saver* opsional (layar hitam minimal, bangun saat ada alert atau sentuhan) untuk menghemat baterai.

### 11.6. Alert (Suara, Getar, Visual)

| Alert | Pemicu | Catatan |
| :--- | :--- | :--- |
| Off Route | Deviasi melewati ambang (bagian 6.6) | Suara + getar + banner merah |
| Kembali ke Rute | Kembali dalam ambang | Suara singkat |
| Zone Warning | HR di Zone 5 melebihi durasi tertentu | Dapat dikonfigurasi |
| Lap | Lap manual/otomatis | Ucapkan jarak dan rata-rata kecepatan |
| Sensor/GPS Hilang | Data basi | Banner non-intrusif |
| Baterai Kritis | ≤ 15% / ≤ 5% | Tawarkan mode hemat |
| Pengingat Makan/Minum | Timer kustom | Opsional |

Gunakan *audio ducking* terhadap musik dan prioritaskan alert sehingga tidak saling menimpa.

### 11.7. Onboarding, Status Kosong & Error

- **Onboarding izin:** layar penjelasan sebelum dialog izin sistem, lalu panduan OEM (bagian 8.3).
- **Status error yang jelas:** GPS lemah ("Sinyal GPS lemah"), sensor terputus ("HR terputus, menyambung ulang..."), penyimpanan hampir penuh, dan baterai kritis.
- **Ringkasan pasca-ride:** peta rute, statistik utama, grafik, zona, lap, rekor pribadi, status sinkronisasi.

### 11.8. Aksesibilitas & Lokalisasi

- Layar pra/pasca-ride mendukung TalkBack/VoiceOver. Layar berkendara memakai ukuran tetap yang teruji, bukan *dynamic type* tak terbatas.
- Bahasa Indonesia dan Inggris; satuan metrik/imperial; format angka dan waktu 24 jam sesuai lokal.

---

## 12. Backlog Fitur Lanjutan (Pasca-MVP)

| Fitur | Deskripsi | Catatan |
| :--- | :--- | :--- |
| **Turn-by-turn penuh** | Cue suara dan visual dari instruksi routing, re-route otomatis | Butuh data instruksi dan, untuk offline, routing di perangkat |
| **Deteksi tanjakan (ala ClimbPro)** | Deteksi tanjakan di depan, tampilkan sisa jarak, rata-rata grade, dan ascent | Memakai profil elevasi rute (bagian 5.5) |
| **Workout terstruktur** | Interval berpandu dengan target power/HR dan alert | Format workout impor (FIT workout / ZWO) |
| **Metrik latihan** | NP, IF, TSS, zona power, beban latihan | Rumus di bagian 5.9 |
| **Keselamatan** | Deteksi jatuh via akselerometer, hitung mundur, kirim lokasi ke kontak darurat, live tracking via tautan | Perlu backend dan penanganan *false positive* |
| **Segment** | Pencocokan segment dan waktu lokal | Skema dan privasi perlu desain tersendiri |
| **Smart trainer (FTMS)** | Mode indoor, kontrol resistansi | Service `0x1826` |
| **Health Connect / HealthKit** | Tulis sesi olahraga ke ekosistem kesehatan | Bagian 10.5 |
| **Manajemen sepeda** | Odometer per sepeda, pengingat servis | Tabel `bikes`, `maintenance_items` |
| **Cuaca & angin** | Prakiraan dan arah angin sepanjang rute | Butuh API cuaca |
| **Companion smartwatch** | Tampilan data di Wear OS/Apple Watch | Proyek terpisah |
| **Live Activity (iOS)** | Metrik di layar kunci | Bagian 8.2 |
| **GNSS dual-frequency** | Akurasi lebih baik di area kota | Android, data GNSS mentah |
| **Routing offline** | Re-route tanpa jaringan | BRouter/Valhalla |
| **Laporan kualitas data rute** | Pengguna melaporkan ruas jalan buruk/dilarang | Terhubung ke pipeline OSM |

---

## 13. Privasi & Keamanan

### 13.1. Data yang Diproses

| Data | Sensitivitas | Catatan |
| :--- | :--- | :--- |
| Lokasi dan rute | Tinggi (dapat mengungkap rumah dan kebiasaan) | Privacy zone saat ekspor/sinkronisasi |
| Detak jantung, HRV | Tinggi (dapat tergolong data kesehatan) | Butuh persetujuan eksplisit |
| Profil (berat, usia, FTP) | Sedang | Disimpan lokal |
| Token OAuth | Kritis | Keystore/Keychain, bukan SQLite |

### 13.2. Kebijakan dan Kepatuhan

- **UU Pelindungan Data Pribadi (UU No. 27 Tahun 2022):** data detak jantung dapat tergolong data pribadi yang bersifat spesifik (data kesehatan), sehingga membutuhkan dasar pemrosesan dan persetujuan yang jelas. Konsultasikan dengan penasihat hukum sebelum rilis.
- **Persetujuan eksplisit** untuk analitik, crash reporting, dan berbagi data. Opsi untuk menolak tanpa kehilangan fungsi inti.
- **Hak pengguna:** ekspor semua data, hapus akun dan data di backend, dan hapus data lokal.
- **Privacy zone:** lingkaran radius (mis. 200-500 m) di sekitar lokasi sensitif. Titik awal/akhir yang jatuh di dalamnya dipangkas pada FIT/GPX yang diekspor atau diunggah.
- **Formulir toko aplikasi:** *Data Safety* (Google Play) dan *Privacy Nutrition Labels* (Apple) harus akurat. Penggunaan lokasi di latar belakang memerlukan justifikasi pada peninjauan Play Store.

### 13.3. Keamanan

- Token dan rahasia di Keystore/Keychain; semua komunikasi jaringan lewat TLS.
- *Client secret* OAuth hanya di backend.
- Validasi file impor (GPX/FIT/TCX) terhadap ukuran berlebih dan XML berbahaya (nonaktifkan entitas eksternal).
- Hindari menulis data sensitif ke log produksi.
- Enkripsi pada basis data lokal dipertimbangkan jika risiko pencurian perangkat dianggap tinggi (menimbang biaya performa).

---

## 14. Strategi Pengujian

### 14.1. Pengujian Otomatis

- **Unit test parser BLE** dengan fixture byte: HR `uint8` dan `uint16`, dengan dan tanpa RR, CSC dengan *rollover* (`uint16`/`uint32`), Power dengan flag opsional.
- **Unit test algoritma:** Kalman, Haversine, grade, hysteresis ascent, auto-pause (dengan input yang sengaja bergetar), dan perhitungan NP.
- **Golden test FIT:** hasil encoding dibanding file referensi dan dibuka di beberapa alat/layanan.
- **Test migrasi database** dari setiap versi skema.
- **Test persistensi:** simulasikan crash di tengah flush dan verifikasi recovery.

### 14.2. Simulasi

- **GPS:** *replay* file GPX (mock location Android, simulasi lokasi di Xcode) termasuk skenario lonjakan akurasi, terowongan, dan berhenti lama.
- **BLE:** peripheral tiruan (mis. nRF Connect atau app penguji) yang mengirim HR/CSC/Power, termasuk putus-sambung.

### 14.3. Uji Kekacauan & Ketahanan (*Chaos Testing*)

- **Force-kill** app saat merekam, mode pesawat, matikan/nyalakan Bluetooth, baterai 5%, dan mode hemat daya.
- **Soak test** 6 jam dengan layar menyala dan layar mati.
- **Termal:** HP di bawah matahari langsung dalam mount.
- **Penyimpanan hampir penuh.**

### 14.4. Test Matrix Perangkat

| Kategori | Contoh |
| :--- | :--- |
| Samsung (One UI) | Seri A dan S |
| Xiaomi/Redmi/Poco (MIUI/HyperOS) | Pengujian manajemen baterai agresif |
| Oppo/Realme (ColorOS) | Pengujian autostart |
| Vivo (Funtouch/OriginOS) | Pengujian background |
| Google Pixel | Referensi Android murni |
| iPhone (SE dan model terbaru) | Berbagai versi iOS |

Sertakan rentang versi Android (minimal API yang didukung hingga terbaru) dan perangkat tanpa layanan Google bila mendukungnya.

### 14.5. Uji Lapangan & Akurasi

- Bandingkan jarak, elevasi, dan kecepatan dengan perangkat referensi (Garmin/Wahoo) pada rute yang sama: langit terbuka, bawah kanopi pohon, kota padat, dan terowongan.
- Ukur konsumsi baterai per jam pada berbagai konfigurasi (peta aktif, layar hemat, dengan/tanpa sensor).
- **Beta tertutup:** Play Internal Testing dan TestFlight dengan pesepeda nyata, disertai *crash reporting*.

---

## 15. Roadmap Pengembangan

> **Asumsi:** tim 2-3 engineer per platform. Jika native dua platform dikerjakan berurutan (Android dulu), iOS menambah sekitar 4-6 minggu setelah engine Android stabil. Total ±17 minggu per platform lebih realistis dibanding 12 minggu pada v1 karena menambahkan Sprint 0 (de-risking) dan Sprint 5 (hardening).

### Sprint 0: Fondasi & De-Risking (Minggu 1-2)

- Setup repo, CI, struktur modul, dan kerangka arsitektur (engine terpisah dari UI).
- **Spike risiko:** foreground service + BLE di background selama 2 jam dengan layar mati pada ≥ 5 perangkat (termasuk Xiaomi/Oppo/Samsung).
- Putuskan sumber tile dan lisensinya; daftarkan aplikasi Strava dan ajukan kuota atlet; tinjau lisensi Garmin FIT SDK.
- Verifikasi kebutuhan izin (apakah `ACCESS_BACKGROUND_LOCATION` perlu) dan kelayakan tombol fisik.
- Wireframe UI diuji di sepeda nyata.
- **Kriteria selesai:** laporan hasil spike per perangkat, keputusan tech stack dan tile dibekukan, target NFR divalidasi/disesuaikan.

### Sprint 1: Core Engine & Persistensi (Minggu 3-5)

- Foreground service, wake-lock, dan state machine aktivitas.
- Pipeline GPS 1 Hz: validasi, Kalman Filter, jarak, kecepatan, durasi, auto-pause histeresis.
- Penulisan batch ke SQLite WAL, tabel `activity_events`, dan **alur crash recovery**.
- **Kriteria selesai:** force-kill saat rekam kehilangan ≤ 5 detik data, rekam 4 jam tanpa crash, error jarak ≤ 1% pada rute uji 20 km, unit test algoritma lulus.

### Sprint 2: Integrasi BLE GATT (Minggu 6-8)

- Pemindaian, pairing, auto-reconnect, dan Sensor Manager.
- Parser HR (`0x180D`), CSC (`0x1816`), Power (`0x1818`), Battery, dengan penanganan *rollover* dan kesegaran data.
- Kalibrasi keliling roda; pengujian dengan Coros (broadcast HR) dan sensor kadens/kecepatan.
- **Kriteria selesai:** sesi BLE 1 jam dengan layar mati tanpa putus permanen; reconnect ≤ 10 detik; semua fixture parser lulus.

### Sprint 3: Peta, Rute & Navigasi (Minggu 9-11)

- Integrasi MapLibre, tile PMTiles/MBTiles, dan offline region manager.
- Import GPX/FIT/TCX, penyederhanaan rute, dan profil elevasi.
- Progress snapping, off-route alert dengan debounce, dan route planner online.
- **Kriteria selesai:** navigasi dan off-route berjalan tanpa jaringan di region terunduh; alert palsu minim pada rute uji.

### Sprint 4: UI, FIT & Sinkronisasi (Minggu 12-14)

- Layout grid metrik berkontras tinggi, halaman yang dapat dikonfigurasi, profil aktivitas, tema otomatis.
- Zona HR dengan label, alert suara/getar, dan screen lock.
- Encoder `.FIT` (Garmin FIT SDK), ekspor GPX, antrean `sync_jobs`, OAuth Strava via proxy, dan upload otomatis.
- Ringkasan pasca-aktivitas.
- **Kriteria selesai:** FIT valid di Strava dan minimal dua alat lain; upload Strava sukses dengan retry saat offline.

### Sprint 5: Hardening & Rilis Beta (Minggu 15-17)

- Uji lapangan, soak test, baterai, dan termal; perbaikan temuan.
- Onboarding OEM, pre-ride checklist, dan penyempurnaan error state.
- Privasi: persetujuan, privacy zone, ekspor/hapus data; formulir toko aplikasi.
- Beta tertutup (Play Internal Testing / TestFlight) dan persiapan rilis.
- **Kriteria selesai:** semua NFR utama terpenuhi atau memiliki rencana mitigasi; tidak ada isu *data-loss* terbuka; lolos peninjauan toko aplikasi.

---

## 16. Register Risiko

| ID | Risiko | Dampak | Mitigasi |
| :--- | :--- | :---: | :--- |
| R1 | OEM mematikan foreground service (Xiaomi/Oppo/Vivo/Samsung) | Tinggi | Spike Sprint 0, onboarding per merek, deteksi pengaturan, recovery |
| R2 | Koneksi BLE putus berkala / sensor hanya mengizinkan satu koneksi | Sedang | Reconnect agresif, kesegaran data, panduan pairing, uji multi-perangkat |
| R3 | Akurasi GPS buruk di kota/bawah pohon | Sedang | Validasi akurasi, Kalman, Doppler, sensor roda; GNSS dual-frequency (F2) |
| R4 | Pelanggaran kebijakan tile OSM untuk offline | Tinggi | Gunakan sumber tile sendiri atau berbayar sejak awal |
| R5 | Persetujuan Strava lambat / kuota atlet terbatas | Sedang | Ajukan di Sprint 0; ekspor FIT sebagai cadangan |
| R6 | Isu lisensi Garmin FIT SDK | Sedang | Tinjau syarat sejak Sprint 0; siapkan alternatif encoder |
| R7 | HP overheating di bawah matahari | Sedang | Peringatan termal, kurangi FPS, mode layar hemat, uji lapangan |
| R8 | Peninjauan Play Store untuk lokasi background / FGS | Sedang | Hindari `ACCESS_BACKGROUND_LOCATION` bila bisa, siapkan justifikasi dan deklarasi |
| R9 | Fitur tombol volume tidak dapat diandalkan | Rendah | Jangan jadikan inti; sediakan remote Bluetooth |
| R10 | Cakupan melebar (scope creep) dan jadwal molor | Tinggi | Kunci MVP (bagian 2), backlog di bagian 12, tinjau tiap sprint |
| R11 | Kualitas data OSM Indonesia dan rute melewati jalan terlarang (tol) | Sedang | Profil routing menghindari tol dan `bicycle=no`; validasi rute |
| R12 | Pelanggaran privasi/UU PDP | Tinggi | Persetujuan eksplisit, privacy zone, tinjauan hukum |

---

## 17. Pertanyaan Terbuka

1. **Urutan platform:** Android dulu lalu iOS, atau dua platform paralel? Native atau Flutter dengan engine native?
2. **Model bisnis:** gratis, berbayar sekali, atau berlangganan? Fitur mana yang menjadi premium (peta offline, metrik latihan, keselamatan)?
3. **Cakupan backend pada MVP:** hanya proxy OAuth dan routing, atau sekalian akun dan backup awan?
4. **Integrasi di luar Strava:** apakah intervals.icu, TrainingPeaks, atau Komoot perlu masuk MVP?
5. **Sumber tile dan anggaran:** host mandiri (PMTiles) atau penyedia berbayar? Perkiraan biaya CDN dan penyimpanan?
6. **Target perangkat minimum:** versi Android/iOS terendah dan apakah perangkat tanpa layanan Google didukung?
7. **Wilayah target awal:** Indonesia saja atau global? Berdampak pada regulasi privasi dan cakupan peta.
8. **Ambang akurasi dan baterai:** apakah target NFR pada bagian 2.2 sesuai ekspektasi pengguna setelah hasil Sprint 0?

---

## 18. Glosarium

| Istilah | Arti |
| :--- | :--- |
| **BLE** | Bluetooth Low Energy |
| **GATT** | Generic Attribute Profile, struktur service/characteristic pada BLE |
| **CSC** | Cycling Speed and Cadence |
| **FTMS** | Fitness Machine Service (smart trainer) |
| **ANT+** | Protokol nirkabel olahraga (tidak didukung HP pada umumnya) |
| **FIT** | Flexible and Interoperable Data Transfer, format biner Garmin untuk data olahraga |
| **GPX / TCX** | Format XML untuk jejak/rute dan data latihan |
| **WAL** | Write-Ahead Logging pada SQLite |
| **DEM** | Digital Elevation Model |
| **RR / HRV** | Selang antar detak / variabilitas detak jantung |
| **NP / IF / TSS** | Normalized Power / Intensity Factor / Training Stress Score |
| **FTP** | Functional Threshold Power |
| **LTHR** | Lactate Threshold Heart Rate |
| **FGS** | Foreground Service (Android) |
| **OEM kill** | Pembunuhan proses oleh manajemen baterai produsen HP |
| **Cross-track distance** | Jarak tegak lurus titik ke garis rute |
| **Kalman Filter** | Algoritma estimasi untuk menghaluskan data GPS |
| **tnum** | Fitur font *tabular numerals* (angka lebar tetap) |
| **Privacy zone** | Area yang titik awal/akhirnya disembunyikan saat berbagi aktivitas |
