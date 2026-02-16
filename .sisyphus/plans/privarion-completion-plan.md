# Privarion Projesi Tamamlama Planı

## Özet

> **Hızlı Özet**: Privarion macOS gizlilik koruma sistemini PRD gereksinimlerine göre tamamlamak için kapsamlı bir iş planı. Mevcut durumda 4 modül tamamlanmış, 3 modül kısmi, 2 modül eksik. Plan, 3 fazda toplam 47 görev içermekte olup öncelik sırasına göre düzenlenmiştir.
> 
> **Teslimatlar**: Kaynak dosyaları, kod kalitesi düzeltmeleri, yeni modüller, CI/CD altyapısı
> 
> **Tahmini Süre**: 6-9 ay (paralel çalışmayla)
> **Kritik Yol**: Faz 1 (Temel Tamamlama) → Faz 2 (Özellik Genişletme) → Faz 3 (Yeni Modüller)

---

## Bağlam

### Orijinal İstek

Kullanıcı, PRD.md dokümanında istenen projenin tüm yönleriyle eksiksiz bir şekilde tamamlanması için ne yapılması gerektiği konusunda kapsamlı bir analiz raporu istemiştir. Analiz sonucunda eksiklikler tespit edilmiş ve bu plan oluşturulmuştur.

### Görüşme Özeti

**Temel Tartışmalar**:

- Projenin mevcut durumu 86 Swift dosyası ve 37 test dosyası olarak analiz edilmiştir
- PRD'de belirtilen 8 modülden 4'ü tamamlanmış, 3'ü kısmi, 2'si eksik olarak değerlendirilmiştir
- Metis gap analizi sonucunda kritik sorunlar ve öneriler sunulmuştur
- Kod kalitesi sorunları (86 try? instance, 6 kritik force unwrap) tespit edilmiştir

**Araştırma Bulguları**:

- PrivacyCtl/main.swift dosyası 3050 satır ile en büyük dosya olarak belirlenmiştir
- Kaynak dosyaları (Resources klasörü) PRD'de belirtilmesine rağmen mevcut değildir
- STORY-2025-016 concurrency crash düzeltmesi yüksek öncelikli olarak işaretlenmiştir
- Test kapsamı %70 seviyesinde olup genişletilmesi gerekmektedir

### Metis İncelemesi

**Tespit Edilen Boşluklar (Ele Alınan)**:

- 6 kritik force unwrap instance'ı çözüme kavuşturulmuştur - MacAddressRepository, IdentityBackupManager, TCCPermissionEngine, TimeSeriesStorage, Logger, SecurityProfileManager dosyalarında düzeltmeler yapılacaktır
- STORY-2025-016 concurrency crash için özel görev eklenmiştir
- PrivacyCtl/main.swift refactor veya teknik borç olarak belgelenecektir
- Browser/Memory Protection için MVP tanımları netleştirilmiştir

---

## Çalışma Amaçları

### Temel Amaç

PRD dokümanında belirtilen tüm özelliklerin production-ready bir duruma getirilmesi ve macOS gizlilik koruma sisteminin tam işlevsel hale getirilmesidir.

### Somut Teslimatlar

- Kaynak yapılandırma dosyaları (profiller, sandbox profilleri, ağ filtreleri)
- Kod kalitesi sorunlarının giderilmesi (try?, force unwrap)
- Açık TODO'ların tamamlanması
- Kısmi özelliklerin genişletilmesi
- Yeni modüllerin geliştirilmesi (Browser Protection, Memory Protection)
- CI/CD altyapısının kurulması

### Tanımlanmış Düzgünler

- **YAPILMASI GEREKEN**: Çökme önleme için özellik çalışmasından önce 6 kritik force unwrap düzeltilmelidir
- **YAPILMASI GEREKEN**: MVP kriterleri tanımlanmalıdır - Browser/Memory Protection ertelenebilir mi?
- **YAPILMASI GEREKEN**: Her kısmi modül için kabul kriterleri eklenmelidir
- **YAPILMAMASI GEREKEN**: Test edilmemiş çökme-indükleyen kodla sevk edilmemelidir
- **YAPILMAMASI GEREKEN**: Onay olmadan MVP dışında kapsam genişletilmemelidir

---

## Doğrulama Stratejisi

> **SIFIR İNSAN MÜDAHALESİ** — Tüm doğrulama aracı tarafından çalıştırılmaktadır. İstisna yoktur.
> "Kullanıcı manuel olarak test eder/onaylar" gerektiren kabul kriterleri YASAKTIR.

### Test Kararı

- **Altyapı Var**: Evet
- **Otomatik Testler**: Test-after (uygulama sonrası)
- **Framework**: XCTest
- **Test Türü**: Uygulama sonrası testler - her görev için test dosyaları eklenecektir

### QA Politikası

Her görev, aşağıda belirtilen aracı tarafından yürütülen QA senaryolarını içermelidir. Kanıtlar `.sisyphus/evidence/` dizinine kaydedilecektir.

| Teslimat Türü | Doğrulama Aracı | Yöntem |
|---------------|------------------|--------|
| Backend/Kütüphane | Bash (swift test) | Test çalıştırma, çıktı karşılaştırma |
| CLI Komutları | interactive_bash (tmux) | Komut çalıştırma, çıktı doğrulama |
| API/Backend | Bash (curl) | İstek gönderme, durum + yanıt doğrulama |
| Yapılandırma | Bash | JSON/syntax doğrulama |

---

## Yürütme Stratejisi

### Paralel Yürütme Dalgaları

Verimliliği en üst düzeye çıkarmak için bağımsız görevler dalgalar halinde gruplandırılmıştır. Her dalga başlamadan önce tamamlanır.

```
Dalga 1 (Hemen Başla — temel + yapı iskelesi):
├── Görev 1: Resources/Profiles yapılandırma dosyaları oluştur
├── Görev 2: Resources/SandboxProfiles sandbox profilleri oluştur
├── Görev 3: Resources/NetworkFilters filtreleme listeleri oluştur
├── Görev 4: 6 kritik force unwrap düzeltmesi
├── Görev 5: STORY-2025-016 concurrency crash düzeltmesi
├── Görev 6: try? instance'lar için sistematik hata yönetimi
└── Görev 7: macOS sürüm gereksinimi doğrulaması

Dalga 2 (Dalga 1'den Sonra — çekirdek modüller, MAKSİMUM PARALEL):
├── Görev 8: Sandbox Manager genişletme (GUI profilleyici)
├── Görev 9: TCC Manager genişletme (geçici izin sistemi)
├── Görev 10: Snapshot Manager genişletme (pre/post execution)
├── Görev 11: Network Filtering genişletme (Tor, bandwidth throttling)
├── Görev 12: Açık TODO'ların tamamlanması (kısmi)
├── Görev 13: CLI komutları (profil, log, export)
└── Görev 14: Test kapsamı genişletme

Dalga 3 (Dalga 2'den Sonra — yeni modüller + altyapı):
├── Görev 15: Browser Fingerprint Protection MVP (User-Agent + Canvas)
├── Görev 16: Memory Protection MVP (process isolation)
├── Görev 17: GitHub Actions CI/CD workflow
├── Görev 18: Güvenlik tarama altyapısı
├── Görev 19: Performance benchmark entegrasyonu
└── Görev 20: Refactor büyük dosyalar (kısmi)

Dalga 4 (Dalga 3'ten Sonra — entegrasyon + doğrulama):
├── Görev 21: Entegrasyon testleri
├── Görev 22: Son kontroller ve temizlik
├── Görev 23: Alpha release hazırlığı
├── Görev 24: Dokümantasyon güncelleme
└── Görev 25: Beta release hazırlığı
```

### Bağımlılık Matrisi

| Görev | Bağımlı | Bloklar | Dalga |
|-------|---------|---------|-------|
| 1-7 | — | 8-14 | 1 |
| 8 | 4, 5 | 21 | 2 |
| 9 | 4, 5 | 21 | 2 |
| 10 | 4, 5 | 21 | 2 |
| 11 | 1, 2, 3 | 21 | 2 |
| 12 | 1 | 21 | 2 |
| 13 | 7 | 21 | 2 |
| 14 | 4, 5 | 21 | 2 |
| 15 | 8, 9, 10 | 22 | 3 |
| 16 | 8, 9, 10 | 22 | 3 |
| 17 | — | — | 3 |
| 18 | — | — | 3 |
| 19 | — | — | 3 |
| 20 | 8, 9, 10 | — | 3 |
| 21 | 8-14 | 23, 24 | 4 |
| 22 | 15, 16, 17 | 25 | 4 |
| 23 | 21 | — | 4 |
| 24 | 21 | — | 4 |
| 25 | 22, 23 | — | 4 |

---

## Görev Listesi

> Her görev Uygulama + Test = TEK GÖREV olarak ele alınır. Asla ayırma.
> Her görev Önerilen Aracı Profili + Paralelleştirme bilgisi + QA Senaryoları içermelidir.

---

### DALGA 1: TEMEL TAMAMLAMA (BAŞLANGIÇ)

- [x] 1. Resources/Profiles Yapılandırma Dosyaları Oluştur

  **Ne Yapılacak**:
  - Resources/Profiles/default.json oluştur - varsayılan gizlilik profili
  - Resources/Profiles/gaming.json oluştur - oyun performans odaklı profil
  - Resources/Profiles/work.json oluştur - iş/günlük kullanım profili
  - Resources/Profiles/paranoid.json oluştur - maksimum gizlilik profili
  - JSON şeması doğrulaması yap

  **Kesinlikle Yapılmaması Gereken**:
  - Mevcut Profile sınıfını bozmadan genişlet
  - Geriye dönük uyumluluğu koru

  **Önerilen Aracı Profili**:
  - **Kategori**: `unspecified-low`
    - Neden: Basit yapılandırma dosyası oluşturma
  - **Beceriler**: []
    - Gerekmiyor

  **Paralelleştirme**:
  - **Paralel Çalıştırılabilir**: Evet
  - **Paralel Grup**: Dalga 1 (Görev 1, 2, 3 ile)
  - **Bloklar**: Görev 8, 11
  - **Bloklu**: — (hemen başlayabilir)

  **Referanslar** (Kritik - Kapsamlı Olun):
  - `Sources/PrivarionCore/Configuration.swift:25-35` - Mevcut profil yapısını incele
  - `Sources/PrivarionCore/SecurityProfileManager.swift:100-200` - Profil yükleme mantığını anla

  **Kabul Kriterleri**:
  - [ ] 4 JSON dosyası oluşturuldu
  - [ ] swift test ProfilTestleri → PASS (geçerli JSON yapısı)
  - [ ] ConfigurationManager dosyaları yükleyebiliyor

  **QA Senaryoları**:

  ```
  Senaryo: Geçerli profil yapılandırması yükleme
    Araç: Bash
    Adımlar:
      1. ConfigurationManager'ı başlat
      2. default.json dosyasını yükle
      3. Profil adını doğrula: "default"
      - Beklenen Sonuç: Profil başarıyla yüklendi, "default" adı döndü
      - Kanıt: .sisyphus/evidence/wave1-task1-profile-load.json
  ```

- [x] 2. Resources/SandboxProfiles Sandbox Profilleri Oluştur

  **Ne Yapılacak**:
  - Resources/SandboxProfiles/minimal.sb oluştur - minimum erişim profili
  - Resources/SandboxProfiles/network-isolated.sb oluştur - ağ izolasyonlu profil
  - Resources/SandboxProfiles/readonly.sb oluştur - salt okunur profil
  - Sandbox sözdizimi doğrulaması yap

  **Paralelleştirme**:
  - **Paralel Çalıştırılabilir**: Evet
  - **Paralel Grup**: Dalga 1 (Görev 1, 2, 3 ile)
  - **Bloklar**: Görev 8
  - **Bloklu**: —

  **Kabul Kriterleri**:
  - [ ] 3 .sb dosyası oluşturuldu
  - [ ] sandbox-exec -p dosya.deneme syntax doğru

- [x] 3. Resources/NetworkFilters Ağ Filtreleme Listeleri Oluştur

  **Ne Yapılacak**:
  - Resources/NetworkFilters/tracking-domains.txt oluştur - izleme domainleri
  - Resources/NetworkFilters/analytics-endpoints.txt oluştur - analitik endpointleri
  - Resources/NetworkFilters/telemetry-hosts.txt oluştur - telemetri sunucuları
  - Format doğrulaması yap

  **Paralelleştirme**:
  - **Paralel Çalıştırılabilir**: Evet
  - **Paralel Grup**: Dalga 1 (Görev 1, 2, 3 ile)
  - **Bloklar**: Görev 11
  - **Bloklu**: —

  **Kabul Kriterleri**:
  - [ ] 3 metin dosyası oluşturuldu
  - [ ] BlocklistManager dosyaları yükleyebiliyor

- [x] 4. 6 Kritik Force Unwrap Düzeltmesi

  **Ne Yapılacak**:
  - MacAddressRepository.swift'te force unwrap'ı kaldır - nil kontrolü ekle
  - IdentityBackupManager.swift'te force unwrap'ı kaldır
  - TCCPermissionEngine.swift'te force unwrap'ı kaldır
  - TimeSeriesStorage.swift'te force unwrap'ı kaldır
  - Logger.swift'te force unwrap'ı kaldır
  - SecurityProfileManager.swift'te force unwrap'ı kaldır
  - Her düzeltme için test ekle

  **Kesinlikle Yapılmaması Gereken**:
  - Sadece hata yönetimi ekle, davranışı değiştirme
  - Geriye dönük uyumsuz değişiklik yapma

  **Önerilen Aracı Profili**:
  - **Kategori**: `refactoring`
    - Neden: Mevcut kodda güvenli değişiklikler
  - **Beceriler**: []
    - N/A

  **Paralelleştirme**:
  - **Paralel Çalıştırılabilir**: Evet (6 alt görev olarak)
  - **Paralel Grup**: Dalga 1
  - **Bloklar**: Görev 21 (entegrasyon)
  - **Bloklu**: —

  **Referanslar**:
  - `Sources/PrivarionCore/PrivarionError.swift` - Hata türlerini incele
  - Mevcut try-catch örneklerini incele

  **Kabul Kriterleri**:
  - [ ] 6 dosyada force unwrap kaldırıldı
  - [ ] swift test ForceUnwrapTest → PASS
  - [ ] Uygulama çökmeden çalışıyor

- [x] 5. STORY-2025-016 Concurrency Crash Düzeltmesi

  **Ne Yapılacak**:
  - Tests/PrivarionCoreTests/ApplicationLauncherTests.swift:655'teki concurrency crash'i bul
  - Neden analiz et (race condition, incorrect async/await kullanımı)
  - Düzeltmeyi uygula
  - Testi etkinleştir ve çalıştır

  **Önerilen Aracı Profili**:
  - **Kategori**: `deep`
    - Neden: Karmaşık concurrency sorunu
  - **Beceriler**: []

  **Paralelleştirme**:
  - **Paralel Çalıştırılabilir**: Hayır
  - **Dalga**: 1
  - **Bloklar**: —
  - **Bloklu**: —

  **Kabul Kriterleri**:
  - [ ] Concurrency test artık geçiyor
  - [ ] Race condition yok

- [x] 6. try? Instance'lar için Sistematik Hata Yönetimi

  **Ne Yapılacak**:
  - 86 try? instance'ını bul ve sınıflandır
  - Kritik olanları (dosya sistemi, ağ, güvenlik) önce düzelt
  - Her düzeltme için Uygun hata yönetimi ekle
  - Test ekle

  **Paralelleştirme**:
  - **Paralel Çalıştırılabilir**: Hayır
  - **Dalga**: 1
  - **Bloklar**: —
  - **Bloklu**: —

  **Kabul Kriterleri**:
  - [ ] 86 instance'ın %80'i düzeltildi
  - [ ] Kalan %20 belgelendi

- [x] 7. macOS Sürüm Gereksinimi Doğrulaması

  **Ne Yapılacak**:
  - PRD.md: 12.0+
  - README.md: 13.0+
  - Package.swift: .v13
  - Tutarsızlığı gider ve birini standart olarak seç

  **Paralelleştirme**:
  - **Paralel Çalıştırılabilir**: Evet
  - **Dalga**: 1
  - **Bloklar**: —
  - **Bloklu**: —

---

### DALGA 2: ÖZELLİK GENİŞLETME

- [x] 8. Sandbox Manager Genişletme

  **Ne Yapılacak**:
  - GUI profilleyici görünümü oluştur - SwiftUI'de sandbox profili editor
  - Container-based izolasyon temeli ekle (chroot/jail wrapper)
  - Custom profil oluşturma desteği ekle
  - Read-only profil implementasyonunu tamamla

  **Önerilen Aracı Profili**:
  - **Kategori**: `visual-engineering`
    - Neden: SwiftUI görünümü oluşturma
  - **Beceriler**: []

  **Kabul Kriterleri**:
  - [ ] Sandbox profili editor görünümü çalışıyor
  - [ ] Profil oluşturma/düzenleme işlevi çalışıyor

- [x] 9. TCC Manager Genişletme

  **Ne Yapılacak**:
  - Geçici izin verme sistemi oluştur (timeout-based)
  - İzin değişiklik alert sistemi ekle
  - TCC.db okuma/yazma işlevlerini genişlet

  **Kabul Kriterleri**:
  - [ ] Geçici izin verilebiliyor
  - [ ] Alert sistemi çalışıyor

- [x] 10. Snapshot Manager Genişletme

  **Ne Yapılacak**:
  - Pre-execution snapshot stratejisi implementasyonu
  - Post-execution snapshot stratejisi implementasyonu
  - Incremental snapshot desteği
  - Scheduled snapshot desteği

  **Kabul Kriterleri**:
  - [ ] Uygulama öncesi snapshot oluşturulabiliyor
  - [ ] Uygulama sonrası restore çalışıyor

- [x] 11. Network Filtering Genişletme

  **Ne Yapılacak**:
  - Tor proxy entegrasyonu (SOCKS5 proxy wrapper)
  - Bandwidth throttling (tc/trafik şekillendirme)
  - Proxy chain yapılandırması
  - DoH zorlaması genişletme

  **Kabul Kriterleri**:
  - [ ] Tor proxy üzerinden trafi yönlendirme çalışıyor
  - [ ] Bant genişliği sınırlama işlevi çalışıyor

- [x] 12. Açık TODO'ları Tamamlama (Kısmi)

  **Ne Yapılacak**:
  - Profil oluşturma/düzenleme/silme → %50 tamamlanacak
  - Log dışa aktarma/temizleme
  - Sistem başlatma/durdurma
  - Ayarlar içe aktarma

  **Kabul Kriterleri**:
  - [ ] En az 10 TODO tamamlandı

- [x] 13. CLI Komutları Genişletme

  **Ne Yapılacak**:
  - privacyctl profile create komutu
  - privacyctl profile export komutu
  - privacyctl logs export komutu
  - privacyctl system start/stop komutu

  **Kabul Kriterleri**:
  - [ ] Tüm komutlar çalışıyor
  - [ ] --help çıktısı doğru

- [x] 14. Test Kapsamı Genişletme

  **Ne Yapılacak**:
  - Unit test coverage'ı %70'ten %85'e çıkar
  - Entegrasyon testleri ekle
  - Her yeni özellik için test ekle

  **Kabul Kriterleri**:
  - [ ] Coverage %85+
  - [ ] Tüm testler geçiyor

---

### DALGA 3: YENİ MODÜLLER + ALTYAPI

- [x] 15. Browser Fingerprint Protection MVP

  **Ne Yapılacak**:
  - User-Agent sahteleme modülü oluştur
  - Canvas fingerprint masking oluştur
  - Tarayıcı eklentisi için temel altyapı
  - Test senaryoları yaz

  **Önerilen Aracı Profili**:
  - **Kategori**: `unspecified-high`
    - Neden: Yeni modül geliştirme
  - **Beceriler**: []

  **MVP Kapsamı**:
  - User-Agent + Canvas fingerprint koruması
  - WebGL/font/screen spoofing sonraki faza

  **Kabul Kriterleri**:
  - [ ] User-Agent değiştirilebiliyor
  - [ ] Canvas fingerprint her çağrıda farklı hash üretiyor
  - [ ] swift test BrowserProtectionTest → PASS

- [x] 16. Memory Protection MVP

  **Ne Yapılacak**:
  - Process memory isolation oluştur
  - mmap/randomization temeli
  - Anti-debugging teknikleri (temel)
  - Test senaryoları yaz

  **Kabul Kriterleri**:
  - [ ] Process memory izolasyonu çalışıyor
  - [ ] Dışarıdan bellek erişimi engelleniyor

- [ ] 17. GitHub Actions CI/CD Workflow

  **Ne Yapılacak**:
  - .github/workflows/test.yml oluştur
  - SwiftLint kontrolleri ekle
  - Swift test otomasyonu ekle
  - Build doğrulama ekle

  **Önerilen Aracı Profili**:
  - **Kategori**: `unspecified-low`
    - Neden: CI/CD yapılandırma
  - **Beceriler**: []

  **Kabul Kriterleri**:
  - [ ] Workflow dosyası var
  - [ ] PR'da testler otomatik çalışıyor

- [ ] 18. Güvenlik Tarama Altyapısı

  **Ne Yapılacak**:
  - Dependency güvenlik taraması (Dependabot)
  - Static code analysis (SwiftLint)
  - Güvenlik testleri için temel

  **Kabul Kriterleri**:
  - [ ] Dependabot etkin
  - [ ] SwiftLint yapılandırılmış

- [ ] 19. Performance Benchmark Entegrasyonu

  **Ne Yapılacak**:
  - Mevcut benchmark testlerini çalıştır
  - Sonuçları karşılaştır
  - Performans regresyon testi oluştur

  **Kabul Kriterleri**:
  - [ ] Benchmark sonuçları kaydediliyor
  - [ ] Regresyon tespit ediliyor

- [ ] 20. Refactor Büyük Dosyalar (Kısmi)

  **Ne Yapılacak**:
  - AuditLogger.swift (1659 satır) → modüler yapıya böl
  - AnomalyDetectionEngine.swift (1616 satır) → alt modüllere ayır
  - SecurityProfileManager.swift (1181 satır) → sorumlulukları ayır

  **Önerilen Aracı Profili**:
  - **Kategori**: `refactoring`
    - Neden: Büyük dosya yeniden yapılandırma
  - **Beceriler**: []

  **Kabul Kriterleri**:
  - [ ] Dosyalar 1000 satır altına indi
  - [ ] Testler geçiyor

---

### DALGA 4: ENTEGRASYON + DOĞRULAMA

- [ ] 21. Entegrasyon Testleri

  **Ne Yapılacak**:
  - Modüller arası etkileşim testleri
  - Uçtan uca iş akışı testleri
  - Platform uyumluluk testleri

  **Kabul Kriterleri**:
  - [ ] Tüm entegrasyon testleri geçiyor
  - [ ] Intel ve Apple Silicon'da çalışıyor

- [ ] 22. Son Kontroller ve Temizlik

  **Ne Yapılacak**:
  - Kod temizliği (gereksiz yorumlar, debug kodları)
  - Dokümantasyon güncelleme
  - Versiyon numarası güncelleme

  **Kabul Kriterleri**:
  - [ ] Kod temiz
  - [ ] Dokümantasyon güncel

- [ ] 23. Alpha Release Hazırlığı

  **Ne Yapılacak**:
  - Alpha sürümü oluştur
  - TestFlight/Homebrew hazırlığı
  - Beta testçi topluluğu oluştur

  **Kabul Kriterleri**:
  - [ ] Alpha sürümü çalışıyor
  - [ ] TestFlight'a yüklenebilir

- [ ] 24. Beta Release Hazırlığı

  **Ne Yapılacak**:
  - Beta sürümü oluştur
  - Feedback mekanizması
  - Hata izleme sistemi

  **Kabul Kriterleri**:
  - [ ] Beta sürümü yayınlandı
  - [ ] Feedback toplanabiliyor

---

## Son Doğrulama Dalgası

> Tüm uygulama görevlerinden SONRA 4 inceleme aracı PARALEL olarak çalışır. HEPSİ ONAYLAMALI. Red → düzelt → tekrar çalıştır.

- [ ] F1. **Plan Uyumluluk Denetimi** — `oracle`

  Planı baştan sona okuyun. Her "Olmalı" için uygulama var mı (dosya oku, curl endpoint, komut çalıştır). Her "Olmamalı" için yasaklı pattern kod tabanında var mı — bulunursa dosya:satır ile reddet. Evidence dosyalarının .sisyphus/evidence/ içinde var olduğunu doğrula. Teslimatları plana karşı karşılaştır.
  Çıktı: `Olmalı [N/N] | Olmamalı [N/N] | Görevler [N/N] | KARAR: ONAYLA/REDDET`

- [ ] F2. **Kod Kalitesi İncelemesi** — `unspecified-high`

  `swift build` + `swift test` çalıştırın. Tüm değiştirilen dosyaları inceleyin: `as any`/`@ts-ignore`, boş catchler, console.log prodda, yorum satırı kodlar, kullanılmayan importlar. AI slop kontrolü: aşırı yorumlar, over-abstraction, generic isimler (data/result/item/temp).
  Çıktı: `Build [GEÇTİ/BAŞARISIZ] | Testler [N geçti/N başarısız] | Dosyalar [N temiz/N sorunlu] | KARAR`

- [ ] F3. **Gerçek Manuel QA** — `unspecified-high`

  Temiz durumdan başlayın. HER GÖREVDEKİ HER QA senaryosunu çalıştırın — tam adımları izleyin, kanıt kaydedin. Çapraz görev entegrasyonunu test edin (birlikte çalışan özellikler, izolasyon değil). Edge case'leri test edin: boş durum, geçersiz input, hızlı eylemler. .sisyphus/evidence/final-qa/ içine kaydedin.
  Çıktı: `Senaryolar [N/N geçti] | Entegrasyon [N/N] | Edge Case'ler [N test edildi] | KARAR`

- [ ] F4. **Kapsam Sadakati Kontrolü** — `deep`

  Her görev için: "Ne yapılacak" oku, gerçek diff'i oku (git log/diff). 1:1 doğrula — spec'deki her şey inşa edildi (eksik yok), spec dışında bir şey inşa edilmedi (creep yok). "Kesinlikle Yapılmaması Gereken" uyumunu kontrol et. Çapraz görev kontaminasyonu tespit et: Görev N, Görev M'nin dosyalarına dokunuyor mu. Hesaplanmamış değişiklikleri işaretle.
  Çıktı: `Görevler [N/N uyumlu] | Kontaminasyon [TEMİZ/N sorun] | Hesaplanmamış [TEMİZ/N dosya] | KARAR`

---

## Başarı Kriterleri

### Doğrulama Komutları

```bash
swift test                          # Tüm testler geçmeli
swift build -c release              # Release build başarılı
swift lint                         # Kod kalitesi kontrolü
```

### Son Kontrol Listesi

- [ ] Tüm "Olmalı" özellikler mevcut
- [ ] Tüm "Olmamalı" özellikler yok
- [ ] Tüm testler geçiyor
- [ ] CI/CD pipeline çalışıyor
- [ ] Dokümantasyon güncel
- [ ] macOS 13.0+ uyumlu
- [ ] Intel ve Apple Silicon'da test edilmiş
