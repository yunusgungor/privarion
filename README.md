# Privarion - macOS Privacy Protection System

🔒 **Privarion**, macOS sisteminde çalışan üçüncü parti uygulamaların kullanıcıyı ve cihazı tanımasını engellemek amacıyla geliştirilmiş, modüler, açık kaynaklı ve genişletilebilir bir gizlilik koruma aracıdır.

## 🎯 Proje Vizyonu

Kullanıcıların dijital kimliklerini koruyarak, gizlilik odaklı bir bilgisayar kullanım deneyimi sunmak.

## 🛡️ Çözülen Problemler

- **Fingerprinting**: Uygulamaların benzersiz cihaz tanımlama girişimleri
- **Telemetri Toplama**: İzinsiz veri toplama ve analitik gönderimi  
- **Cross-Application Tracking**: Uygulamalar arası kullanıcı takibi
- **Persistent Identifiers**: Kalıcı kimlik tanımlayıcılarının oluşturulması

## 🏗️ Sistem Mimarisi

Privarion modüler bir mimari kullanarak farklı gizlilik koruma katmanları sağlar:

```
┌─────────────────────────────────────────────────────────────┐
│                    Kullanıcı Arayüzü                       │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │   CLI Tool      │    │       SwiftUI GUI              │ │
│  │  (privacyctl)   │    │    (PrivacyGuardian.app)       │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      Core Engine                           │
│  ┌─────────────────┐ ┌─────────────────┐ ┌───────────────┐ │
│  │ Config Manager  │ │ Profile Manager │ │ Logger System │ │
│  └─────────────────┘ └─────────────────┘ └───────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      Modül Katmanı                         │
│  ┌───────────────┐ ┌─────────────┐ ┌─────────────────────┐ │
│  │Identity Spoof │ │Network Filter│ │Sandbox Manager      │ │
│  └───────────────┘ └─────────────┘ └─────────────────────┘ │
│  ┌───────────────┐ ┌─────────────┐                         │
│  │Snapshot Mgr   │ │Syscall Hook │                         │
│  └───────────────┘ └─────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Hızlı Başlangıç

### Sistem Gereksinimleri

- macOS 12.0 veya üzeri
- Swift 5.9+
- Xcode 15+ (geliştirme için)

### Kurulum

```bash
# Repository'yi klonlayın
git clone https://github.com/yourusername/privarion.git
cd privarion

# Projeyi derleyin
swift build -c release

# CLI aracını kullanıma hazırlayın
sudo cp .build/release/privacyctl /usr/local/bin/
```

### Temel Kullanım

```bash
# Sistem durumunu kontrol edin
privacyctl status

# Varsayılan profili başlatın
privacyctl start

# Paranoid profile geçin ve başlatın
privacyctl start --profile paranoid

# Sistemi durdurun
privacyctl stop

# Mevcut profilleri listeleyin
privacyctl profile list

# Konfigürasyonu görüntüleyin
privacyctl config list

# Logları takip edin
privacyctl logs --follow
```

## 📋 Özellikler (Geliştirme Aşamasında)

### ✅ Tamamlanmış

- **Core Foundation**: CLI aracı ve temel altyapı
- **Configuration Management**: JSON tabanlı konfigürasyon sistemi
- **Profile Management**: Farklı güvenlik seviyeleri (Default, Paranoid, Balanced)
- **Logging System**: Structured logging ve log rotation

### 🚧 Geliştiriliyor

- **Syscall Hook Module**: Sistem çağrılarını yakalama ve manipülasyon
- **Identity Spoofing Module**: Sistem kimlik bilgilerini değiştirme
- **Network Filter Module**: Ağ trafiği filtreleme ve analitik engelleme

### 📋 Planlanan

- **Sandbox Manager**: Uygulama izolasyonu
- **Snapshot Manager**: Dosya sistemi sanallaştırma
- **SwiftUI GUI**: Grafik kullanıcı arayüzü

## 🔧 Geliştirme

### Proje Yapısı

```
privarion/
├── Package.swift                 # Swift Package Manager
├── Sources/
│   ├── PrivacyCtl/              # CLI executable
│   │   └── main.swift
│   └── PrivarionCore/           # Core library
│       ├── Configuration.swift
│       ├── ConfigurationManager.swift
│       └── Logger.swift
├── Tests/
│   └── PrivarionCoreTests/      # Unit tests
└── .project_meta/               # Codeflow metadata
    ├── .stories/                # Development stories
    ├── .patterns/               # Code patterns
    └── .state/                  # Workflow state
```

### Test Çalıştırma

```bash
# Tüm testleri çalıştır
swift test

# Belirli bir test dosyasını çalıştır
swift test --filter PrivarionCoreTests

# Test kapsamını göster
swift test --enable-code-coverage
```

### Linting ve Formatting

```bash
# SwiftLint kurulumu (brew ile)
brew install swiftlint

# Linting kontrolü
swiftlint

# Auto-formatting
swiftformat .
```

## 📊 Profiller

### Default Profile
- Temel gizlilik koruması
- Minimal sistem etkisi
- Telemetri engelleme

### Balanced Profile
- Orta seviye koruma
- İyi performans dengesi
- Hostname ve sistem bilgisi spoofing

### Paranoid Profile
- Maksimum gizlilik koruması
- Tüm modüller aktif
- Kapsamlı identity spoofing

## 🔒 Güvenlik Notları

- **SIP (System Integrity Protection)**: Bazı özellikler SIP'in kapalı olmasını gerektirebilir
- **Code Signing**: Apple imzalı uygulamalarda kısıtlı işlevsellik
- **Entitlements**: Sistem seviyesi erişim için özel izinler gerekli

## 📚 Dokümantasyon

### CLI Komutları

#### Sistem Yönetimi
```bash
privacyctl start [--profile PROFILE]    # Sistemi başlat
privacyctl stop                          # Sistemi durdur  
privacyctl status [--detailed]          # Durum bilgisi
```

#### Konfigürasyon
```bash
privacyctl config list                  # Tüm ayarları listele
privacyctl config get KEY               # Belirli ayarı getir
privacyctl config set KEY VALUE         # Ayar değiştir
privacyctl config reset [--force]       # Varsayılanlara sıfırla
```

#### Profil Yönetimi
```bash
privacyctl profile list                 # Profilleri listele
privacyctl profile switch PROFILE       # Profile geç
privacyctl profile create NAME DESC     # Yeni profil oluştur
privacyctl profile delete NAME          # Profil sil
```

#### Log Yönetimi
```bash
privacyctl logs [--lines N]             # Son N satırı göster
privacyctl logs --follow                # Canlı log takibi
privacyctl logs --rotate                # Log rotation yap
```

## 🤝 Katkıda Bulunma

1. **Fork** edin
2. **Feature branch** oluşturun (`git checkout -b feature/amazing-feature`)
3. **Commit** edin (`git commit -m 'Add amazing feature'`)
4. **Push** edin (`git push origin feature/amazing-feature`)
5. **Pull Request** açın

### Geliştirme İlkeleri

- **Codeflow Methodology**: Proje Codeflow system v3.0 kullanıyor
- **Test-Driven Development**: Her özellik için kapsamlı testler
- **Documentation-First**: Kod dokümantasyonu zorunlu
- **Security-First**: Güvenlik her aşamada öncelik

## 📄 Lisans

Bu proje [MIT License](LICENSE) altında lisanslanmıştır.

## ⚠️ Yasal Uyarı

Bu araç yalnızca kendi cihazınızda ve yasal amaçlar için kullanılmalıdır. Kullanıcılar bu aracın kullanımından doğan tüm sorumluluğu kabul eder.

## 🆘 Destek

- **Issues**: GitHub issues sayfasını kullanın
- **Discussions**: GitHub discussions bölümü
- **Documentation**: Wiki sayfalarını kontrol edin

## 🗓️ Roadmap

### v1.0.0 (2025 Q3)
- ✅ Core Foundation
- 🚧 Syscall Hook Module
- 🚧 Identity Spoofing Module

### v1.1.0 (2025 Q4)
- 📋 Network Filter Module
- 📋 SwiftUI GUI

### v2.0.0 (2026 Q1)
- 📋 Advanced Modules
- 📋 Enterprise Features

---

**Developed with ❤️ using [Codeflow System v3.0](https://github.com/codeflow-system)**
