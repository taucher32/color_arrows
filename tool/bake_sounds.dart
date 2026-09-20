// Writes the four short sound effects to assets/audio as 16-bit mono WAV.
// Run from the project root: dart run tool/bake_sounds.dart
// Swap the files for real recordings any time; names are what the game uses.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const _rate = 22050;

/// Each note is (frequency Hz, seconds); a 0 Hz note is silence.
Uint8List _wav(List<(double, double)> notes) {
  final samples = <int>[];
  for (final (freq, seconds) in notes) {
    final n = (seconds * _rate).round();
    for (var i = 0; i < n; i++) {
      final fade = min(1.0, min(i, n - i) / (0.008 * _rate));
      final v = freq == 0 ? 0.0 : sin(2 * pi * freq * i / _rate);
      samples.add((v * fade * 0.35 * 32767).round());
    }
  }
  final data = ByteData(44 + samples.length * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, _rate, Endian.little);
  data.setUint32(28, _rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  final dir = Directory('assets/audio')..createSync(recursive: true);
  final sounds = <String, List<(double, double)>>{
    'remove.wav': [(660, 0.05), (880, 0.07)],
    'blocked.wav': [(160, 0.14)],
    'win.wav': [(523, 0.1), (659, 0.1), (784, 0.1), (1047, 0.22)],
    'lose.wav': [(392, 0.14), (330, 0.14), (262, 0.26)],
  };
  sounds.forEach((name, notes) {
    File('${dir.path}/$name').writeAsBytesSync(_wav(notes));
  });
  stdout.writeln('wrote ${sounds.length} sounds to ${dir.path}');
}
