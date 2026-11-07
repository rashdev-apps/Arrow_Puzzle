// Synthesises the game's sound effects into assets/sounds/ as 16-bit PCM
// WAV files, so the repo ships no binary audio blobs.
//
// Usage (from the project root):
//   dart run tool/generate_sounds.dart

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  final dir = Directory('assets/sounds')..createSync(recursive: true);

  _writeWav('${dir.path}/whoosh.wav', 0.35, (t, ctx) {
    // Noise burst with a falling bandpass feel: noise * descending sine gate.
    final gate = sin(pi * t) * (1 - t * 0.6);
    final wobble = sin(2 * pi * (900 - 1400 * t) * ctx.time);
    return ctx.noise() * wobble * gate * 0.9;
  });

  _writeWav('${dir.path}/buzz.wav', 0.25, (t, ctx) {
    // Low square-ish buzz, two quick pulses.
    final pulse = (t < 0.45 || (t > 0.55 && t < 0.9)) ? 1.0 : 0.0;
    final square = (sin(2 * pi * 140 * ctx.time) >= 0 ? 1.0 : -1.0);
    return square * pulse * sin(pi * t) * 0.5;
  });

  _writeWav('${dir.path}/win.wav', 0.9, (t, ctx) {
    // Little rising jingle: C5 E5 G5 C6, each 0.22s.
    const notes = [523.25, 659.25, 783.99, 1046.5];
    final idx = (t * notes.length).floor().clamp(0, notes.length - 1);
    final local = (t * notes.length) - idx;
    final env = exp(-local * 6);
    return sin(2 * pi * notes[idx] * ctx.time) * env * 0.6;
  });

  _writeWav('${dir.path}/click.wav', 0.08, (t, ctx) {
    return ctx.noise() * exp(-t * 40) * 0.7;
  });

  _writeWav('${dir.path}/coin.wav', 0.3, (t, ctx) {
    // Two bright sine blips a fifth apart.
    final f = t < 0.5 ? 987.77 : 1318.5;
    final local = t < 0.5 ? t : t - 0.5;
    return sin(2 * pi * f * ctx.time) * exp(-local * 8) * 0.6;
  });

  _writeWav('${dir.path}/heart.wav', 0.4, (t, ctx) {
    // Descending sad tone.
    final f = 320 - 160 * t;
    return sin(2 * pi * f * ctx.time) * sin(pi * t) * 0.6;
  });

  stdout.writeln('Sounds written to ${dir.path}');
}

class _Ctx {
  final Random rng;
  double time = 0;
  _Ctx(this.rng);

  double noise() => rng.nextDouble() * 2 - 1;
}

void _writeWav(String path, double duration,
    double Function(double t, _Ctx ctx) synth) {
  const rate = 22050;
  final frames = (duration * rate).round();
  final ctx = _Ctx(Random(42));
  final data = Int16List(frames);
  for (var i = 0; i < frames; i++) {
    ctx.time = i / rate;
    final t = i / frames.toDouble();
    data[i] = (synth(t, ctx).clamp(-1.0, 1.0) * 32767).round();
  }

  final bytes = ByteData(44 + frames * 2);
  void str(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  bytes.setUint32(4, 36 + frames * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, rate, Endian.little);
  bytes.setUint32(28, rate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  str(36, 'data');
  bytes.setUint32(40, frames * 2, Endian.little);
  for (var i = 0; i < frames; i++) {
    bytes.setInt16(44 + i * 2, data[i], Endian.little);
  }

  File(path).writeAsBytesSync(bytes.buffer.asUint8List());
  stdout.writeln('Wrote $path (${frames / rate}s)');
}
