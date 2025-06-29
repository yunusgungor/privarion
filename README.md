# Privarion - macOS Privacy Protection System

🔒 **Privarion**, macOS sisteminde çalışan üçüncü parti uygulamaların kullanıcıyı ve cihazı tanımasını engellemek amacıyla geliştirilmiş, modüler, açık kaynaklı ve genişletilebilir bir gizlilik koruma aracıdır.

> **Geliştirme Durumu:** Aktif olarak [Codeflow System v3.0](https://github.com/codeflow-system) kullanılarak geliştirilmektedir. Sürekli iyileştirme döngüsü ve pattern-driven development yaklaşımı benimsenmiştir.

## 🎯 Proje Vizyonu

Kullanıcıların dijital kimliklerini koruyarak, gizlilik odaklı bir bilgisayar kullanım deneyimi sunmak ve professional-grade macOS privacy protection sağlamak.

## 🛡️ Çözülen Problemler

- **Fingerprinting**: Uygulamaların benzersiz cihaz tanımlama girişimleri
- **Telemetri Toplama**: İzinsiz veri toplama ve analitik gönderimi  
- **Cross-Application Tracking**: Uygulamalar arası kullanıcı takibi
- **Persistent Identifiers**: Kalıcı kimlik tanımlayıcılarının oluşturulması
- **Hardware Fingerprinting**: Sistem donanımı tabanlı takip yöntemleri

## 🏗️ Sistem Mimarisi

Privarion modüler bir mimari kullanarak farklı gizlilik koruma katmanları sağlar:

```
┌─────────────────────────────────────────────────────────────┐
│                    Kullanıcı Arayüzü                       │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │   CLI Tool      │    │     SwiftUI GUI Application     │ │
│  │  (privacyctl)   │    │    (PrivacyGuardian.app)       │ │
│  │  ✅ Tamamlandı   │    │    🚧 Geliştiriliyor           │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    PrivarionCore Engine                     │
│  ┌─────────────────┐ ┌─────────────────┐ ┌───────────────┐ │
│  │ Config Manager  │ │ Profile Manager │ │ Logger System │ │
│  │  ✅ Tamamlandı   │ │  ✅ Tamamlandı   │ │ ✅ Tamamlandı  │ │
│  └─────────────────┘ └─────────────────┘ └───────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      Modül Katmanı                         │
│  ┌───────────────┐ ┌─────────────┐ ┌─────────────────────┐ │
│  │Identity Spoof │ │Network Filter│ │Sandbox Manager      │ │
│  │ ✅ Tamamlandı  │ │ 📋 Planlanan │ │ 📋 Planlanan        │ │
│  └───────────────┘ └─────────────┘ └─────────────────────┘ │
│  ┌───────────────┐ ┌─────────────┐                         │
│  │Snapshot Mgr   │ │Syscall Hook │                         │
│  │ 📋 Planlanan   │ │ ✅ Tamamlandı│                         │
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

# Projeyi derleyin (Release mode)
swift build -c release

# CLI aracını sistem dizinine kopyalayın
sudo cp .build/release/privacyctl /usr/local/bin/

# İzinleri ayarlayın
sudo chmod +x /usr/local/bin/privacyctl

# Kurulumu doğrulayın
privacyctl --version
```

### Hızlı Başlangıç

```bash
# Sistem durumunu kontrol edin
privacyctl status --detailed

# Mevcut profilleri ve konfigürasyonu görün
privacyctl profile list
privacyctl config list

# Default profili ile sistemi başlatın
privacyctl start

# Sistem loglarını takip edin (ayrı terminal)
privacyctl logs --follow

# Sistem durumunu kontrol edin
privacyctl status

# Sistemi durdurun
privacyctl stop
```

### Advanced Usage

```bash
# Profil Yönetimi
privacyctl start --profile paranoid          # Paranoid profile geçip başlat
privacyctl profile switch balanced           # Profile geç
privacyctl profile create custom "My Config" # Özel profil oluştur

# Modül Yönetimi  
privacyctl module list                       # Modülleri listele
privacyctl module status identity-spoofing   # Modül durumu
privacyctl module enable syscall-hook        # Modül aktifleştir

# Konfigürasyon Yönetimi
privacyctl config set logging.level debug    # Debug logging aktif
privacyctl config get identity.spoofing      # Identity spoof ayarları
privacyctl config export backup.json         # Konfigürasyon backup

# Log ve Monitoring
privacyctl logs --module identity-spoofing   # Modül logları
privacyctl logs --lines 100 --format json    # JSON format loglar
privacyctl status --json                     # Machine-readable status
```

## 📋 Özellikler ve Geliştirme Durumu

### ✅ Tamamlanmış (Production Ready)

- **Core Foundation**: Swift Package Manager yapısı ve temel CLI altyapısı
- **Professional CLI Interface**: ArgumentParser tabanlı hiyerarşik komut yapısı
- **Configuration Management**: JSON tabanlı konfigürasyon sistemi ve validation
- **Profile Management**: Farklı güvenlik seviyeleri (Default, Paranoid, Balanced)
- **Logging System**: Structured logging, log rotation ve real-time monitoring
- **Identity Spoofing Module**: Hardware/software kimlik bilgilerini değiştirme
- **Syscall Hook Module**: Sistem çağrılarını yakalama ve manipülasyon
- **Rollback Management**: Güvenli geri alma mekanizmaları

### 🚧 Aktif Geliştirme (STORY-2025-005)

- **SwiftUI GUI Application**: Native macOS GUI (Clean Architecture)
  - Real-time module status monitoring
  - Professional configuration management UI
  - Profile management with preview functionality
  - CLI-GUI seamless integration
  - Native macOS design patterns

### 📋 Planlanan (Next Cycles)

- **Network Filter Module**: Ağ trafiği filtreleme ve analitik engelleme
- **Sandbox Manager**: Uygulama izolasyonu ve sandboxing
- **Snapshot Manager**: Dosya sistemi sanallaştırma
- **Advanced GUI Features**: Kullanıcı onboarding ve training materials

## 🔧 Geliştirme

### Proje Yapısı (Codeflow System v3.0)

```
privarion/
├── Package.swift                    # Swift Package Manager
├── PRD.md                          # Product Requirements Document
├── Sources/
│   ├── PrivacyCtl/                 # CLI executable (ArgumentParser)
│   │   └── main.swift
│   ├── PrivarionCore/              # Core library (Shared framework)
│   │   ├── Configuration.swift      # ✅ Configuration management
│   │   ├── ConfigurationManager.swift
│   │   ├── ConfigurationProfileManager.swift
│   │   ├── Logger.swift            # ✅ Structured logging
│   │   ├── IdentitySpoofingManager.swift # ✅ Identity spoofing
│   │   ├── HardwareIdentifierEngine.swift
│   │   ├── SyscallHookManager.swift # ✅ Syscall hooks
│   │   ├── RollbackManager.swift   # ✅ Rollback mechanisms
│   │   └── SystemCommandExecutor.swift
│   └── PrivarionHook/              # C interop for syscall hooks
│       ├── privarion_hook.c        # ✅ C implementation
│       ├── module.modulemap
│       └── include/privarion_hook.h
├── Tests/
│   ├── PrivarionCoreTests/         # ✅ Unit tests (90%+ coverage)
│   └── PrivarionHookTests/
├── .project_meta/                  # Codeflow System metadata
│   ├── .stories/                   # Development stories & roadmap
│   │   ├── roadmap.json           # ✅ Product roadmap
│   │   ├── story_2025-001.json    # ✅ Core Foundation
│   │   ├── story_2025-003.json    # ✅ Identity Spoofing
│   │   ├── story_2025-004.json    # ✅ Professional CLI
│   │   └── story_2025-005.json    # 🚧 SwiftUI GUI (Current)
│   ├── .patterns/                  # Reusable code patterns
│   │   └── pattern_catalog.json   # ✅ 17 validated patterns
│   ├── .state/                     # Workflow state management
│   │   └── workflow_state.json    # Current: cycle_planned
│   ├── .context7/                  # External research cache
│   └── .sequential_thinking/       # Decision analysis logs
└── .github/
    └── instructions/
        └── codeflow.instructions.md # ✅ Codeflow System v3.0 specs
```

### Test ve Kalite Kontrolleri

```bash
# Tüm testleri çalıştır (unit + integration)
swift test

# Test coverage raporu ile
swift test --enable-code-coverage

# Belirli test suite'ini çalıştır
swift test --filter PrivarionCoreTests
swift test --filter PrivarionHookTests

# Performance testleri
swift test --filter PerformanceTests

# Memory leak testleri
leaks --atExit -- swift test
```

### Code Quality ve Linting

```bash
# SwiftLint kurulumu (Homebrew)
brew install swiftlint

# Linting kontrolü (zero errors required)
swiftlint

# Auto-formatting
swiftformat .

# Security scan
swift package audit

# Dependency vulnerability check
swift package show-dependencies --format json | jq
```

### Pattern-Driven Development

Bu proje [Codeflow System v3.0](https://github.com/codeflow-system) metodolojisini kullanıyor:

- **Pattern Catalog**: 17 validated pattern aktif kullanımda
- **Context7 Research**: External best practices integration  
- **Sequential Thinking**: Structured decision-making process
- **Quality Gates**: Automated quality validation at each phase
- **Continuous Learning**: Pattern evolution from implementation results

## 📊 Profiller

### Default Profile
- **Hedef Kullanıcı**: Günlük kullanım, temel gizlilik koruması
- **Sistem Etkisi**: Minimal (<%5 CPU, <50MB RAM)
- **Korunan Alanlar**: Telemetri engelleme, basic fingerprint protection
- **Aktif Modüller**: Configuration Manager, Basic Logger
- **Uyumluluk**: Tüm uygulamalarla %100 uyumlu

### Balanced Profile  
- **Hedef Kullanıcı**: İş kullanımı, güvenlik-performans dengesi
- **Sistem Etkisi**: Orta (<%10 CPU, <100MB RAM)
- **Korunan Alanlar**: Hostname spoofing, system info masking, network fingerprinting
- **Aktif Modüller**: Identity Spoofing (partial), Syscall Hook (selective)
- **Uyumluluk**: Most apps compatible, bazı developer tools etkilenebilir

### Paranoid Profile
- **Hedef Kullanıcı**: Maximum security, gizlilik odaklı kullanım
- **Sistem Etkisi**: Yüksek (<%20 CPU, <200MB RAM)
- **Korunan Alanlar**: Comprehensive identity spoofing, hardware fingerprint masking
- **Aktif Modüller**: Tüm modüller maksimum seviyede aktif
- **Uyumluluk**: Bazı uygulamalar sorun yaşayabilir, manual whitelist gerekebilir

### Custom Profile
- **Hedef Kullanıcı**: Advanced users, özel gereksinimler
- **Sistem Etkisi**: Konfigürasyona bağlı
- **Korunan Alanlar**: Kullanıcı tanımlı
- **Aktif Modüller**: Granular kontrol
- **Uyumluluk**: Kullanıcı sorumluluğunda

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

### Geliştirme Süreci (Codeflow System v3.0)

1. **Issue/Story Creation**: Problem tanımlama ve story oluşturma
2. **Context7 Research**: External best practices araştırması  
3. **Sequential Thinking**: Yapılandırılmış problem analizi
4. **Pattern Consultation**: Mevcut pattern catalog'dan faydalanma
5. **Implementation**: Pattern-guided development
6. **Quality Gates**: Automated quality validation
7. **Learning Extraction**: Pattern evolution ve catalog güncelleme

### Contribution Workflow

```bash
# 1. Fork ve local setup
git clone https://github.com/yourusername/privarion.git
cd privarion
git checkout -b feature/amazing-feature

# 2. Development environment setup
swift build
swift test

# 3. Story planning (if new feature)
# - Check .project_meta/.stories/roadmap.json
# - Create story following template in .project_meta/.docs/templates/

# 4. Implementation 
# - Follow pattern catalog guidelines
# - Maintain test coverage ≥90%
# - Update documentation

# 5. Quality validation
swift test --enable-code-coverage
swiftlint
swiftformat .

# 6. Commit and push
git add .
git commit -m "feat: Add amazing feature (STORY-2025-XXX)"
git push origin feature/amazing-feature

# 7. Create Pull Request
# - Reference story/issue number
# - Include pattern compliance check
# - Ensure all quality gates pass
```

### Geliştirme İlkeleri ve Standards

- **Codeflow Methodology**: Proje Codeflow System v3.0 kullanıyor
- **Verification-First Development**: Her feature comprehensive testing ile geliştirilir
- **Pattern-Driven Architecture**: Validated pattern catalog'dan faydalanılır
- **Context7 Research**: External best practices mandatory olarak araştırılır
- **Sequential Thinking**: Tüm major kararlar structured analysis ile alınır
- **Documentation-First**: Living documentation sürekli güncellenir
- **Security-First**: Güvenlik her aşamada öncelik
- **Quality Gates**: Automated quality validation her phase'de zorunlu

### Code Standards

```swift
// ✅ DOĞRU: Pattern-compliant error handling
public func startPrivacyProtection() throws {
    do {
        try validateConfiguration()
        try initializeModules()
        try activateProtection()
        logger.info("Privacy protection started successfully")
    } catch let error as PrivarionError {
        logger.error("Failed to start privacy protection", metadata: ["error": "\(error)"])
        throw error
    } catch {
        let wrappedError = PrivarionError.systemError(underlying: error)
        logger.error("Unexpected error during startup", metadata: ["error": "\(error)"])
        throw wrappedError
    }
}

// ❌ YANLIŞ: Poor error handling
public func startPrivacyProtection() {
    // No validation, no error handling, no logging
    initializeModules()
    activateProtection()
}
```

### Performance Requirements

- **Build Time**: ≤ 2 minutes for full build
- **Test Execution**: ≤ 30 seconds for unit tests  
- **Memory Usage**: ≤ 200MB for paranoid profile
- **CPU Usage**: ≤ 20% sustained load
- **Startup Time**: ≤ 3 seconds for CLI commands

## 📄 Lisans

Bu proje [MIT License](LICENSE) altında lisanslanmıştır.

## ⚠️ Yasal Uyarı

Bu araç yalnızca kendi cihazınızda ve yasal amaçlar için kullanılmalıdır. Kullanıcılar bu aracın kullanımından doğan tüm sorumluluğu kabul eder.

## 🆘 Destek

- **Issues**: GitHub issues sayfasını kullanın
- **Discussions**: GitHub discussions bölümü
- **Documentation**: Wiki sayfalarını kontrol edin

## 🗓️ Roadmap ve Development Timeline

### ✅ v0.8.0 - Core Foundation (Tamamlandı)
- ✅ Core CLI Infrastructure (STORY-2025-001)  
- ✅ Configuration & Profile Management
- ✅ Structured Logging System
- ✅ Basic Module Framework

### ✅ v0.9.0 - Privacy Modules (Tamamlandı)  
- ✅ Syscall Hook Module (STORY-2025-002)
- ✅ Identity Spoofing Module (STORY-2025-003)
- ✅ Professional CLI Enhancement (STORY-2025-004)
- ✅ Hardware Identifier Engine
- ✅ Rollback Management System

### 🚧 v1.0.0 - GUI Foundation (2025 Q3 - Current)
- 🚧 **SwiftUI GUI Application** (STORY-2025-005 - In Planning)
  - Native macOS application with Clean Architecture
  - Real-time module status monitoring
  - Professional configuration management interface
  - Profile management with preview functionality
  - Seamless CLI-GUI integration
- 📋 Network Filter Module foundation
- 📋 Advanced error handling and recovery

### 📋 v1.1.0 - Advanced Features (2025 Q4)
- 📋 Network Traffic Analysis & Filtering
- 📋 Sandbox Manager for app isolation
- 📋 Advanced GUI features (dashboards, analytics)
- 📋 User onboarding and training materials
- 📋 Performance optimization

### 📋 v2.0.0 - Enterprise Features (2026 Q1)
- 📋 Snapshot Manager (filesystem virtualization)
- 📋 Advanced threat detection
- 📋 Enterprise deployment tools
- 📋 API for third-party integrations
- 📋 Advanced reporting and analytics

### Development Methodology

Bu roadmap [Codeflow System v3.0](https://github.com/codeflow-system) ile yönetiliyor:
- **Story-Driven Development**: Her feature detaylı story olarak planlanıyor
- **Quality Gates**: Her phase'de automated quality validation
- **Pattern Evolution**: Successful patterns catalog'a ekleniyor
- **Continuous Learning**: Her cycle'dan öğrenme çıkarımı yapılıyor
- **External Research**: Context7 ile industry best practices integration

## 🆘 Destek ve Community

### Teknik Destek
- **Issues**: [GitHub Issues](https://github.com/yourusername/privarion/issues) - Bug reports ve feature requests
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/privarion/discussions) - Community Q&A
- **Documentation**: [Project Wiki](https://github.com/yourusername/privarion/wiki) - Comprehensive guides
- **Security Issues**: security@privarion.dev (Private reporting)

### Development Community
- **Pattern Catalog**: `.project_meta/.patterns/pattern_catalog.json` - Reusable development patterns
- **Story Planning**: `.project_meta/.stories/` - Development roadmap ve planning
- **Codeflow System**: [Methodology docs](https://github.com/codeflow-system) - Development framework

### Getting Help

```bash
# CLI help system
privacyctl --help                    # General help
privacyctl start --help              # Command-specific help
privacyctl config --help             # Configuration help

# Diagnostic information  
privacyctl status --detailed --json  # Machine-readable diagnostics
privacyctl logs --export diag.log    # Export logs for support

# Version and build info
privacyctl --version                 # Version information
privacyctl debug system              # System compatibility check
```

### Contributing Guidelines
- [CONTRIBUTING.md](CONTRIBUTING.md) - Detailed contribution guidelines
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) - Community standards
- [SECURITY.md](SECURITY.md) - Security policy ve responsible disclosure

## 📄 Lisans

Bu proje [MIT License](LICENSE) altında lisanslanmıştır.

## ⚠️ Yasal Uyarı

Bu araç yalnızca kendi cihazınızda ve yasal amaçlar için kullanılmalıdır. Kullanıcılar bu aracın kullanımından doğan tüm sorumluluğu kabul eder.

---

**Geliştirme Durumu**: Aktif development, [Codeflow System v3.0](https://github.com/codeflow-system) ile sürekli iyileştirme döngüsünde

**Son Güncelleme**: 2025-06-30 | **Current State**: `cycle_planned` | **Target Story**: STORY-2025-005 (SwiftUI GUI Foundation)
