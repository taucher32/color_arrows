# Renkli Oklar (Color Arrows) — Tasarım

Durum: v2 (kıvrılan oklar, dolu tahta, zoom). v1 kodu (tek hücreli oklar) cihazda denendi ve çalışıyor; bu sürüm çekirdek kuralları, üreticiyi ve çizimi değiştirir. Onay: kullanıcı, 2026-09-21.

## 1. Oyun kuralları

**Tahta:** W×H ızgara. **Her hücre tam olarak bir okun parçasıdır, boş hücre yoktur.**

**Ok:** Birbirine 4 yönde komşu, tekrar etmeyen hücrelerden oluşan bir yol (kuyruktan başa doğru, 1–10 hücre, kıvrılabilir) + renk. Yolun son hücresi ok başıdır. Ok başı `dir` yönüne bakar: 2+ hücreli okta bu, son adımın yönüdür; tek hücreli okta `dir` açıkça verilir. İnce çizgi olarak çizilir, çevresinde kare yoktur.

**Yol açık:** Ok başından `dir` yönünde tahta kenarına kadar düz giden hücrelerin hiçbiri başka bir okun (ya da okun kendi gövdesinin) hücresi değildir. Kendi gövdesi önündeyse ok hiç çıkamaz (üretici bunu yapmaz).

**Çıkış:** Ok başı düz yönde ilerleyip tahtadan çıkar, gövdesi kendi izini takip edip arkasından kayar. Çıkan okun hücreleri boşalır; başka hiçbir ok kendiliğinden çıkmaz.

**Hedef:** Tüm oklar hedefte. Tahta boşalınca bölüm biter.

**Bölüm tipleri:**
- *Sırasız:* Herhangi renkten ok çıkarılabilir. Hedef paneli renk başına kalan **ok** sayısını gösterir.
- *Sıralı:* Hedef bir grup dizisi: `Kırmızı 3 → Mavi 2 → Kırmızı 2 → Yeşil 4` (sayılar ok adedi). Aynı anda yalnız aktif gruptaki renk çıkarılabilir. Renk başına grup toplamı, tahtadaki o renkteki ok sayısına eşit.

**Dokunuş:** Dokunulan hücrenin ait olduğu ok işlenir.
- Yol açık + renk geçerli: ok çıkar, sayaç düşer.
- Yanlış renk (sıralı mod): ok titrer, −1 can. (Yanlış renk, yol kontrolünden önce bakılır.)
- Yol kapalı: ok başıyla engele doğru sekip geri döner, −1 can.

**Can:** 3 ile başlar. Bitince ödüllü reklamla +1 can ya da bölümü baştan başla.

### Çözülebilirlik
- *Sırasız:* Ok çıkarmak yalnız hücre boşaltır, hiçbir yolu kapatmaz. Başta çözülebilen tahta hep çözülebilir kalır, oyuncu kilitlenemez.
- *Sıralı:* Aynı garanti yok. Aktif renkten açık ok kalmadıysa ve sıradaki oklar başka renklerin altında kalmışsa takılınabilir. Çözücü arama yapar, oyun sırasında kilitlenme tespit edilir (2.4).
- Üretilen her bölüm çözülebilir: oklar bölüm dosyasında **çıkarma sırasıyla** listelenir; ok 0, 1, 2… sırayla dokunulunca (sıralı modda renk adımlarına uygun) bölüm hiç can kaybetmeden biter.

## 2. Mimari

Yığın: Flutter + Flame, `shared_preferences`, `google_mobile_ads`, ses için `flame_audio`, titreşim için `HapticFeedback`.

Ana ilke: **kurallar saf Dart, çizim Flame, dokunma ve zoom Flutter.** Kural katmanı Flutter/Flame'e bağımlı değil; testler ekransız koşar.

### 2.1 Katmanlar

```
lib/
  core/            saf Dart, Flutter/Flame importu YOK
    arrow.dart       Dir, ArrowColor, Cell, Arrow(id, cells, dir, color)
    level.dart       ColorStep, Level (JSON + doğrulama: tam kaplama)
    board.dart       Board: hücre → ok haritası, blockerOf, remove/restore
    solver.dart      peel (açık okları soy), isSolvable
    session.dart     GameSession, TapResult, SessionStatus
    generator.dart   generateLevel: rastgele yollara bölme + yön onarımı
    difficulty.dart  paramsFor, generateFor, bakedLevels
  game/            Flame
    track.dart         Track: ok yolu + düz uzantı, pencere çizimi (saf geometri)
    arrows_game.dart   FlameGame, kamera, tapAtScreen/tapArrow
    arrow_component.dart  ince çizgi + ok başı, çıkış/sekme/titreme animasyonu
    board_component.dart  zemin paneli
  services/          level_repository, progress_store, feedback, ads
  ui/
    hud.dart           can + renk sayaçları
    zoomable_board.dart  InteractiveViewer + +/−/sığdır düğmeleri + dokunma
    level_cards.dart, play_screen.dart
tool/  bake_levels.dart (sıkıştırılmış JSON), bake_sounds.dart
assets/levels/ audio/
```

Bağımlılık yönü: `ui`, `game` → `core`. `core` → hiçbir şey.

### 2.2 Birimler

**Board.** `width*height` uzunluğunda hücre → ok kimliği dizisi. `blockerOf(ok)`: ok başının ötesinden `dir` yönünde kenara kadar yürür, ilk dolu hücrenin okunu (kendisi dahil) döndürür, yoksa null. `remove/restore` okun tüm hücrelerini boşaltır/geri koyar.

**Solver.** `peel(board)`: açık okları tekrar tekrar çıkarır; çıkarma sırasını ve takılıp kalan okları döndürür. `isSolvable(board, steps, {budget})`: sırasızda `peel` ile kesin; sıralıda (kalan ok kümesi üzerinde, `BigInt` maskesiyle bellekli) DFS. Düğüm bütçesi aşılırsa iyimser `true` döner (büyük tahtada gerçek kilitlenme her zaman yakalanmaz; bölümler yine baştan çözülebilir üretilir).

**Generator.** 1) Tahtayı rastgele büyüyen yollara böler (uzunluk 1..`maxLength`, yön değiştirerek). 2) Her yol için baş ucu seçer (tek hücrelide yön seçer). 3) `peel` ile dener; takılan okların başını çevirir (diğer uç / yeni yön), çözülene kadar yineler; olmazsa yeniden böler. 4) Çıkarma sırasını ok sırası (kimlik) yapar. 5) Renk: sırasızda rastgele; sıralıda çıkarma sırasını `groups` ardışık parçaya böler, her parça komşusundan farklı renk alır. Tohuma göre deterministik.

**Flame katmanı.** `ArrowsGame`, `CameraComponent.withFixedResolution` ile tahtanın mantıksal boyutunu ekrana sığdırır. Her ok bir `ArrowComponent`: `Track` üzerinde bir "pencere" çizer (kuyruktan başa uzunluk kadar). Çıkışta pencere yol boyunca ve düz uzantıda ilerler (yılan kayar); sekmede kısa ileri-geri; yanlış renkte yana titreme. Kural önce güncellenir, animasyon sonradan oynar; animasyon sürerken aynı okla dokunma yok sayılır.

**Dokunma ve zoom (Flutter).** `ZoomableBoard`: `InteractiveViewer` (iki parmak yakınlaştır/kaydır, 1×–8×) içinde `GestureDetector`; dokunma konumu `camera.globalToLocal` ile tahta koordinatına, oradan hücreye ve o hücrenin okuna çevrilir (`ArrowsGame.tapAtScreen`). Ekranda +, −, sığdır düğmeleri.

**Overlay'ler.** HUD ve kartlar Flutter widget'ı.

### 2.3 Veri akışı

```
dokunuş -> GestureDetector -> ArrowsGame.tapAtScreen -> hücre -> ok
        -> GameSession.tap(id) -> TapResult
        -> animasyon (game) + ses/titreşim (services) + HUD güncelle
        -> won/lost/çıkmaz ise kart aç, kazanınca progress_store'a yaz
```

Bölüm dosyası (her ok tek satır, okunabilir ve küçük):
`{"w":5,"h":5,"arrows":[{"cells":[[0,0],[1,0],[1,1]],"dir":"down","color":"coral"}, ...],"steps":[{"color":"coral","count":3}]}` (`steps` yoksa sırasız; `arrows` çıkarma sırasında). Yüklerken doğrulanır: her hücre tam bir kez kaplanmış, hücreler komşu ve tekrarsız, `dir` son adımla uyumlu, kimlik = sıra, `steps` toplamı ok sayısıyla eşleşme.

### 2.4 Hata yönetimi ve kilitlenme
- Bozuk bölüm dosyası: yükleme reddedilir, günlüğe yazılır, bölüm atlanır.
- Sıralı modda her hamleden sonra (yalnız tahta değiştiyse) `isSolvable(mevcut durum)` çalışır; false ise "Çıkış kalmadı" kartı: baştan başla, can gitmez. Büyük tahtada bütçe aşımı iyimser sayılır.
- Reklam yüklenemezse buton gizlenir. Reklam SDK'sı başlangıcı bloklamaz.
- `shared_preferences` okunamazsa 1. bölümden başlanır.

### 2.5 Test
- `core/`: yol/engel (kendi gövdesi dahil), çok hücreli okun çıkışında hücre boşalması, tap sonuçları, sıralı adımlar, kilitlenme, JSON doğrulama (tam kaplama).
- Generator: farklı boyutlarda üretilen bölümlerde tam kaplama + çıkarma sırasının (oklar 0,1,2…) canlı oyunda hiç can kaybetmeden kazanmayla bitmesi; tohuma göre determinizm; 20×20 üretim süresi.
- Baked bölümlerin hepsi yüklenir ve aynı tekrar oyunuyla kazanılır.
- `Track` geometrisi, `ArrowsGame` (dokunma → hücre → ok, animasyon durumları), zoom düğmeleri, HUD, `PlayScreen`.
- Görsel doğrulama emülatörde/cihazda.

### 2.6 Görünüm

Modern, sade. Tahta zeminden net ayrılır, dikkat okların renginde toplanır.

**Yerleşim:** Üstte HUD (bölüm no, can, hedef sayaçları), altta tahta alanı (zoom edilebilir), sağ altta zoom düğmeleri.

**Renkler (koyu tema):**

| Rol | Renk |
|---|---|
| Arka zemin | `#0E141B` |
| Tahta paneli | `#18212C`, köşe yuvarlama 20, hafif gölge |
| Ana metin / ikincil | `#E8EEF5` / `#8A99AB` |
| Ok renkleri (en fazla 5) | mercan `#FF6B6B`, kehribar `#FFB84D`, nane `#4ADE9A`, gök `#4DA8FF`, mor `#A78BFA` |

**Oklar:** Yalnız ince, yuvarlak uçlu renkli çizgi (kalınlık ≈ hücrenin %16'sı) ve dolu üçgen ok başı. Kare/gövde yok, ızgara noktası yok. Renk körlüğü için şekil işareti **yoktur** (bilinçli tercih: sade görünüm).

**Durumlar:** Aktif renk dışındaki oklar soluk (%35 opaklık). HUD'da renk sayaçları düz renkli nokta + sayı; sıralı modda adım çipleri (biten ✓, aktif çerçeveli, bekleyen sayı). Can: dolu/boş daire.

**Hareket:** 150–250 ms, ease-out. Çıkış: yılan gibi kayar. Sekme: kısa ileri-geri. Yanlış renk: yana titreme. Parçacık/konfeti yok.

**Yazı:** Sistem yazı tipi.

## 3. Kapsam dışı
İpucu, bölüm haritası, açık tema, renk körü işaretleri, pinch dışında hareket (çift dokunma zoom vb.), 8 yön, renkli çıkış kapıları.

## 4. Kararlar
1. Oklar kıvrılan yollar; tahta tamamen dolu (kullanıcı, örnek resimle).
2. Boyut ilerledikçe büyür: 5×5 → 20×20. Ok uzunluğu üst sınırı 3 → 10 hücre.
3. Zoom: iki parmak + +/−/sığdır düğmeleri.
4. Sıralı modda kilitlenme çalışma anında tespit edilir; büyük tahtada bütçe aşımı iyimser.
5. İlk ~10 bölüm sırasız, sonra sıralı; her 5. bölüm sırasız.
6. İlk 30 bölüm üreticiyle pişirilip JSON olarak gelir, sonrası çalışma anında üretilir.
