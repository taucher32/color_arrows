# Renkli Oklar (Color Arrows) — Tasarım

Durum: taslak, tüm açık kararlar kapandı, kullanıcı onayı bekliyor. Kod henüz yok.

## 1. Oyun kuralları

**Tahta:** W×H ızgara. Hücre boş ya da ok. Ok = renk + yön (↑ ↓ ← →).

**Yol açık:** Okun baktığı yönde tahta kenarına kadar tüm hücreler boş.

**Hedef:** Tüm oklar hedefte. Tahta boşalınca bölüm biter. Fazladan/hedef dışı ok yok.

**Bölüm tipleri:**
- *Sırasız:* Herhangi renkten ok çıkarılabilir. Hedef paneli renk başına kalan sayıyı gösterir.
- *Sıralı:* Hedef bir grup dizisi: `Kırmızı 3 → Mavi 2 → Kırmızı 2 → Yeşil 4`. Aynı anda yalnız aktif gruptaki renk çıkarılabilir. Grup sayılarının renk başına toplamı tahtadaki ok sayısına eşit.

**Dokunuş:** Yalnız dokunulan ok işlenir, hiçbir ok kendiliğinden çıkmaz.
- Yol açık + renk geçerli: ok çıkar, sayaç düşer.
- Yol kapalı: ok engele doğru sekip geri döner, −1 can.
- Yanlış renk (sıralı mod): ok titrer, −1 can.

**Can:** 3 ile başlar. Bitince ödüllü reklamla +1 can ya da bölümü baştan başla.

**Renk bilgisi:** Renk körlüğü için her rengin ayrıca bir şekil/desen işareti olur (v1'de ok gövdesinde küçük simge).

### Çözülebilirlik (düzeltme)
- *Sırasız:* Ok çıkarmak hiçbir okun yolunu kapatmaz, yalnız açar. Başta çözülebilen tahta hep çözülebilir kalır; oyuncu kilitlenemez. Başlangıçta çözülemeyen tek durum karşılıklı engelleme döngüsüdür.
- *Sıralı:* Aynı kilit garantisi **yok**. Aktif grup k ok ister ama o an yolu açık k ok yoksa, kalanlar sonraki gruptaki bir okun altında kalmışsa takılırsın. Hangi k oku seçtiğin sonraki durumu değiştirir. Bu yüzden sıralı modda çözücü bir arama yapar (bkz. 2.4) ve oyun çalışırken de kilitlenmeyi tespit eder.

## 2. Mimari

Yığın: Flutter + Flame (yeni proje `oyun_2`), `shared_preferences`, `google_mobile_ads`, ses için `flame_audio` (audioplayers üstünde), titreşim için `HapticFeedback` (Flutter services).

Ana ilke: **kurallar saf Dart, çizim Flame.** Kural katmanı Flutter/Flame'e bağımlı değil; testler ekransız koşar.

### 2.1 Katmanlar

```
lib/
  core/            saf Dart, Flutter/Flame importu YOK
    arrow.dart       Dir, ArrowColor, Arrow(id, cell, dir, color)
    level.dart       Level(width, height, arrows, steps?)  steps = grup dizisi (null = sırasız)
    session.dart     GameSession: durum + tap(id) -> TapResult
    solver.dart      isSolvable(session/level), sıralı mod için arama
    generator.dart   prosedürel bölüm üretimi (solver ile doğrulanmış)
  game/            Flame
    arrows_game.dart   FlameGame, kamera, session'ı tutar
    board_component.dart
    arrow_component.dart   TapCallbacks, çıkış/sekme animasyonu
  ui/              Flutter overlay'leri (GameWidget.overlayBuilders)
    hud, level_end, out_of_lives, menu
  services/
    progress_store.dart  shared_preferences: açılan bölüm, ayarlar
    audio.dart, haptics.dart, ads.dart
assets/levels/       elle tasarlanan ~30 bölüm (JSON)
test/                core için birim testleri
```

Bağımlılık yönü: `ui`, `game` → `core`. `core` → hiçbir şey. `services` → dışarıdaki paketler; `game`/`ui` sadece küçük arayüzler üzerinden kullanır (test için sahte sürümü konabilsin diye).

### 2.2 Birimler

**GameSession** (çekirdek). Girdi: `Level`. Durum: kalan oklar, aktif grup (sıralı mod), kalan can. Tek yazma noktası `tap(arrowId) -> TapResult`:
`Removed(arrow)`, `Blocked(arrow, blocker)`, `WrongColor(arrow)`, sonrasında `won` / `lost` bayrakları. Flame'e hiçbir şey bilmez; sadece sonucu döndürür.

**Solver.** `bool isSolvable(state)`. Sırasızda: açık bir ok bulunduğu sürece çıkar, tahta boşalırsa true. Sıralıda: (çıkarılmış ok kümesi, grup indeksi) üzerinde DFS + bellekleme. Tahta küçük (≤ ~40 ok) olduğundan yeterli.

**Generator.** Bölüm tahtadan geriye doğru kurulur: boş tahtaya oklar tek tek geri yerleştirilir; çözüm zaten elde. Sıralı modda grup dizisi bu çıkış sırasından türetilir ve solver ile doğrulanır. Zorluk parametreleri: boyut, doluluk, renk sayısı, mod, grup sayısı, çözüm derinliği.

**Flame katmanı.** `ArrowsGame` `CameraComponent.withFixedResolution` ile sabit mantıksal boyut kullanır; ekran oranı farkı harici alanla karşılanır. Her ok bir `PositionComponent` + `TapCallbacks`. Dokunuşta `session.tap()` çağrılır, dönen `TapResult` animasyona çevrilir (`MoveEffect` ile çıkış/sekme, titreşim için kısa `MoveEffect` dizisi). Animasyon durumu kural durumunu belirlemez; kural önce güncellenir, animasyon sonradan oynar. Animasyon sürerken tekrar dokunma o ok için yok sayılır.

**Overlay'ler.** HUD (can, hedef paneli), kazanma/kaybetme ekranları, menü Flutter widget'ı olarak `GameWidget` üstünde. Oyun ile `ValueNotifier`/`ChangeNotifier` üzerinden konuşur; `provider` gerekirse yalnız buraya gelir.

### 2.3 Veri akışı

```
dokunuş -> ArrowComponent.onTapUp
        -> GameSession.tap(id)
        -> TapResult
        -> animasyon (game) + ses/titreşim (services) + HUD güncelle (overlay)
        -> won/lost ise overlay aç, progress_store'a yaz
```

Bölüm dosyası: `{ "w": 6, "h": 6, "arrows": [{"x":1,"y":2,"dir":"right","color":"red"}], "steps": [{"color":"red","count":3}] }` (`steps` yoksa sırasız). Yüklerken doğrulanır: hücre çakışması, sınır dışı, `steps` toplamı ok sayısıyla eşleşme, `isSolvable`.

### 2.4 Hata yönetimi ve kilitlenme
- Bozuk/çözülemez bölüm dosyası: yükleme reddedilir, hata günlüğe yazılır, bölüm atlanır (geliştirmede test başarısız olur).
- Reklam yüklenemezse: ödüllü reklam düğmesi gizlenir, baştan başla kalır. Oyun reklama bağımlı çalışmaz.
- `shared_preferences` okunamazsa 1. bölümden başlanır.

### 2.5 Test
- `core/` birim testleri (Flame'siz): açık/kapalı yol, tap sonuçları, can düşmesi, sıralı grup geçişi, kazanma.
- Solver: bilinen çözülebilir/çözülemez tahtalar; kilitlenme örneği (sıralı).
- Generator: üretilen 1000 bölüm, her biri `isSolvable`.
- Elle tasarlanan bölümlerin hepsi yükleme testinden geçer.
- Flame: en az bir bileşen testi (dokun → session çağrıldı); görsel doğrulama cihazda elle.

### 2.6 Görünüm

Modern, sade, az renkli. Tahta zeminden net ayrılır, dikkat okların renginde toplanır.

**Yerleşim:** Üstte HUD (can, hedef paneli), ortada tahta, altta boşluk. Tek ekran, gereksiz süs yok.

**Renkler (koyu tema, tek tema v1):**

| Rol | Renk |
|---|---|
| Arka zemin | `#0E141B` (çok koyu lacivert-gri) |
| Tahta paneli | `#18212C`, 16 px köşe yuvarlama, hafif gölge |
| Izgara / boş hücre | `#243040`, küçük soluk nokta ya da çok ince çizgi |
| Ana metin | `#E8EEF5`, ikincil metin `#8A99AB` |
| Ok renkleri (en fazla 5) | mercan `#FF6B6B`, kehribar `#FFB84D`, nane `#4ADE9A`, gök `#4DA8FF`, mor `#A78BFA` |

Ok renkleri birbirinden ve zeminden ayrılacak kadar doygun, ama aynı parlaklık ailesinde tutulur. Zemin, panel ve ızgara tek bir soğuk gri tonundan türer; ekstra vurgu rengi yok.

**Oklar:** Yuvarlatılmış köşeli düz dolgu, gradient yok. Renk körlüğü için her rengin gövdesinde küçük bir şekil işareti (daire, kare, üçgen, artı, yıldız).

**Durumlar:**
- Aktif grup rengi (sıralı mod): HUD'da vurgulu, tahtada aynı renkteki oklar normal, diğerleri hafif soluk (%55 opaklık). Dokunma yine yanlış renkse can gider.
- Yolu kapalı ok: engele doğru sekip sarsılır, ek hata rengi yok.
- Can: küçük dolu/boş daire sırası.

**Hareket:** Kısa ve yumuşak (150–250 ms, ease-out). Çıkışta ok yönünde kayıp ekrandan çıkar. Parçacık/konfeti yok; bölüm sonu ekranı sade bir kart.

**Yazı:** Sistem yazı tipi, kalın başlık, düz gövde. Ek font paketi yok.

**Kapsam dışı:** Açık tema, tema seçimi, dekoratif arka plan resmi.

## 3. Kapsam dışı (v1)
İpucu, bölüm haritası, kaskad/zincir çıkış, 8 yön, çok hücreli oklar, renkli çıkış kapıları. Bölüm seçimi yerine oyun son açık bölümden açılır.

## 4. Kararlar
1. Sıralı modda kilitlenme çalışma anında tespit edilir (2.4). Güvenli üretim v1 kapsamı dışı.
2. Bölüm sırası: ilk ~10 bölüm sırasız (kuralı öğretir), sonra sıralı bölümler; ara ara sırasız bölüm nefes aldırır.
3. Tahta üst sınırı 8×8.
