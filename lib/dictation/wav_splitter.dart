import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Splits long recordings into pieces under the API's upload limit (Groq's free tier accepts 25 MB, about 13 minutes
/// of 16 kHz WAV). Each cut lands in the quietest moment near the limit so no word is split in half.
class WavSplitter {
  /// Leaves headroom under the 25 MB limit.
  static const maxBytes = 20 * 1000 * 1000;

  /// How far back from the limit to look for a pause.
  static const _searchSeconds = 10;

  /// Returns the pieces in order, written to [into], or null when [wav] already fits or isn't a 16-bit PCM WAV file.
  static Future<List<File>?> split(File wav, Directory into, {int maxBytes = maxBytes}) async {
    if (await wav.length() <= maxBytes) return null;
    final raf = await wav.open();
    try {
      final format = await _WavFormat.read(raf);
      if (format == null) return null;
      final align = format.blockAlign;
      final budget = (maxBytes - _WavFormat.headerBytes) ~/ align * align;
      final window = min(format.byteRate * _searchSeconds, budget ~/ 2) ~/ align * align;
      // 100 ms frames: short enough to land between words.
      final frame = max(align, format.byteRate ~/ 10 ~/ align * align);

      final pieces = <File>[];
      var start = 0;
      while (start < format.dataBytes) {
        var end = format.dataBytes;
        if (end - start > budget) {
          final searchFrom = start + budget - window;
          await raf.setPosition(format.dataOffset + searchFrom);
          end = searchFrom + _quietestOffset(await raf.read(window), frame);
        }
        final piece = File('${into.path}/${wav.uri.pathSegments.last}.part${pieces.length}.wav');
        await _writePiece(raf, format, start, end, piece);
        pieces.add(piece);
        start = end;
      }
      return pieces;
    } finally {
      await raf.close();
    }
  }

  /// Start of the 100 ms frame with the least energy, as a byte offset into [pcm].
  static int _quietestOffset(Uint8List pcm, int frame) {
    final samples = pcm.buffer.asByteData(pcm.offsetInBytes, pcm.lengthInBytes);
    var best = 0;
    var bestEnergy = double.infinity;
    for (var offset = 0; offset + frame <= pcm.length; offset += frame) {
      var energy = 0.0;
      for (var i = offset; i < offset + frame; i += 2) {
        final s = samples.getInt16(i, Endian.little);
        energy += s * s;
      }
      if (energy < bestEnergy) {
        bestEnergy = energy;
        best = offset;
      }
    }
    return best;
  }

  static Future<void> _writePiece(RandomAccessFile source, _WavFormat format, int start, int end, File piece) async {
    final out = await piece.open(mode: FileMode.write);
    try {
      await out.writeFrom(format.header(end - start));
      await source.setPosition(format.dataOffset + start);
      for (var at = start; at < end;) {
        final bytes = await source.read(min(1 << 20, end - at));
        if (bytes.isEmpty) break;
        await out.writeFrom(bytes);
        at += bytes.length;
      }
    } finally {
      await out.close();
    }
  }
}

class _WavFormat {
  _WavFormat({
    required this.channels,
    required this.sampleRate,
    required this.blockAlign,
    required this.dataOffset,
    required this.dataBytes,
  });

  static const headerBytes = 44;

  final int channels;
  final int sampleRate;
  final int blockAlign;
  final int dataOffset;
  final int dataBytes;

  int get byteRate => sampleRate * blockAlign;

  /// Walks the RIFF chunks; macOS writes a padding chunk before the audio data, so the data isn't always at byte 44.
  static Future<_WavFormat?> read(RandomAccessFile raf) async {
    final length = await raf.length();
    await raf.setPosition(0);
    final riff = await raf.read(12);
    if (riff.length < 12 || String.fromCharCodes(riff, 0, 4) != 'RIFF' || String.fromCharCodes(riff, 8, 12) != 'WAVE') {
      return null;
    }
    int? channels;
    int? sampleRate;
    int? blockAlign;
    var position = 12;
    while (position + 8 <= length) {
      await raf.setPosition(position);
      final head = await raf.read(8);
      final id = String.fromCharCodes(head, 0, 4);
      final size = ByteData.sublistView(head).getUint32(4, Endian.little);
      final body = position + 8;
      if (id == 'fmt ') {
        final fmt = ByteData.sublistView(await raf.read(16));
        if (fmt.lengthInBytes < 16) return null;
        final tag = fmt.getUint16(0, Endian.little);
        // 1 is plain PCM, 0xFFFE the extensible header some recorders use for it.
        if ((tag != 1 && tag != 0xFFFE) || fmt.getUint16(14, Endian.little) != 16) return null;
        channels = fmt.getUint16(2, Endian.little);
        sampleRate = fmt.getUint32(4, Endian.little);
        blockAlign = fmt.getUint16(12, Endian.little);
      } else if (id == 'data') {
        if (channels == null || sampleRate == null || blockAlign == null || blockAlign == 0) return null;
        // The header's size is 0 or stale when the recorder never finalized it, so trust the file length instead.
        final available = length - body;
        final dataBytes = size == 0 || size > available ? available : size;
        return _WavFormat(
          channels: channels,
          sampleRate: sampleRate,
          blockAlign: blockAlign,
          dataOffset: body,
          dataBytes: dataBytes ~/ blockAlign * blockAlign,
        );
      }
      position = body + size + size % 2;
    }
    return null;
  }

  Uint8List header(int dataBytes) {
    final header = ByteData(headerBytes)
      ..setUint32(4, dataBytes + 36, Endian.little)
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, channels, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, byteRate, Endian.little)
      ..setUint16(32, blockAlign, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(40, dataBytes, Endian.little);
    final bytes = header.buffer.asUint8List();
    bytes
      ..setAll(0, 'RIFF'.codeUnits)
      ..setAll(8, 'WAVE'.codeUnits)
      ..setAll(12, 'fmt '.codeUnits)
      ..setAll(36, 'data'.codeUnits);
    return bytes;
  }
}
