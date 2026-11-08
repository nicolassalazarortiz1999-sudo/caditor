import 'dart:math' as math;

enum ClipType { video, image, text }

enum TrackKind { video, text }

double clampD(double v, double lo, double hi) => math.max(lo, math.min(hi, v));

double _d(Object? v, double def) => v is num ? v.toDouble() : def;
int _i(Object? v, int def) => v is num ? v.toInt() : def;

String fmtTime(int ms) {
  final s = ms / 1000;
  final m = s ~/ 60;
  final sec = s - m * 60;
  return '$m:${sec.toStringAsFixed(1).padLeft(4, '0')}';
}

/// Un elemento de la línea de tiempo (video, imagen o texto).
class MediaClip {
  String id;
  ClipType type;
  String? sourcePath;
  String name;
  int sourceDurationMs; // solo videos; 0 = sin límite
  int startMs; // posición en la línea de tiempo
  int inMs; // inicio dentro del archivo original
  int outMs; // fin dentro del archivo original
  double speed;
  double volume;
  double opacity;
  String filterId;
  double brightness;
  double contrast;
  double saturation;
  double scale;
  double rotation;
  double posX;
  double posY;
  bool flipH;
  bool flipV;
  int fadeInMs;
  int fadeOutMs;
  String text;
  double fontSize;
  int textColor;
  int bgColor;
  bool bold;
  bool italic;

  MediaClip({
    required this.id,
    required this.type,
    this.sourcePath,
    this.name = '',
    this.sourceDurationMs = 0,
    this.startMs = 0,
    this.inMs = 0,
    required this.outMs,
    this.speed = 1,
    this.volume = 1,
    this.opacity = 1,
    this.filterId = 'none',
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.scale = 1,
    this.rotation = 0,
    this.posX = 0,
    this.posY = 0,
    this.flipH = false,
    this.flipV = false,
    this.fadeInMs = 0,
    this.fadeOutMs = 0,
    this.text = '',
    this.fontSize = 32,
    this.textColor = 0xFFFFFFFF,
    this.bgColor = 0,
    this.bold = true,
    this.italic = false,
  });

  int get durationMs => math.max(1, ((outMs - inMs) / speed).round());
  int get endMs => startMs + durationMs;

  /// Factor 0..1 de los fundidos de entrada/salida.
  double fadeFactorAt(int localMs) {
    var f = 1.0;
    if (fadeInMs > 0 && localMs < fadeInMs) {
      f = math.min(f, localMs / fadeInMs);
    }
    final rem = durationMs - localMs;
    if (fadeOutMs > 0 && rem < fadeOutMs) {
      f = math.min(f, rem / fadeOutMs);
    }
    return clampD(f, 0.0, 1.0);
  }

  MediaClip copy() => MediaClip.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'sourcePath': sourcePath,
        'name': name,
        'sourceDurationMs': sourceDurationMs,
        'startMs': startMs,
        'inMs': inMs,
        'outMs': outMs,
        'speed': speed,
        'volume': volume,
        'opacity': opacity,
        'filterId': filterId,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'scale': scale,
        'rotation': rotation,
        'posX': posX,
        'posY': posY,
        'flipH': flipH,
        'flipV': flipV,
        'fadeInMs': fadeInMs,
        'fadeOutMs': fadeOutMs,
        'text': text,
        'fontSize': fontSize,
        'textColor': textColor,
        'bgColor': bgColor,
        'bold': bold,
        'italic': italic,
      };

  factory MediaClip.fromJson(Map<String, dynamic> j) => MediaClip(
        id: j['id'] as String,
        type: ClipType.values.byName(j['type'] as String),
        sourcePath: j['sourcePath'] as String?,
        name: (j['name'] as String?) ?? '',
        sourceDurationMs: _i(j['sourceDurationMs'], 0),
        startMs: _i(j['startMs'], 0),
        inMs: _i(j['inMs'], 0),
        outMs: _i(j['outMs'], 1000),
        speed: _d(j['speed'], 1),
        volume: _d(j['volume'], 1),
        opacity: _d(j['opacity'], 1),
        filterId: (j['filterId'] as String?) ?? 'none',
        brightness: _d(j['brightness'], 0),
        contrast: _d(j['contrast'], 1),
        saturation: _d(j['saturation'], 1),
        scale: _d(j['scale'], 1),
        rotation: _d(j['rotation'], 0),
        posX: _d(j['posX'], 0),
        posY: _d(j['posY'], 0),
        flipH: (j['flipH'] as bool?) ?? false,
        flipV: (j['flipV'] as bool?) ?? false,
        fadeInMs: _i(j['fadeInMs'], 0),
        fadeOutMs: _i(j['fadeOutMs'], 0),
        text: (j['text'] as String?) ?? '',
        fontSize: _d(j['fontSize'], 32),
        textColor: _i(j['textColor'], 0xFFFFFFFF),
        bgColor: _i(j['bgColor'], 0),
        bold: (j['bold'] as bool?) ?? true,
        italic: (j['italic'] as bool?) ?? false,
      );
}

class Track {
  String id;
  String name;
  TrackKind kind;
  bool hidden;
  bool muted;
  List<MediaClip> clips;

  Track({
    required this.id,
    required this.name,
    required this.kind,
    this.hidden = false,
    this.muted = false,
    List<MediaClip>? clips,
  }) : clips = clips ?? [];

  int get endMs {
    var e = 0;
    for (final c in clips) {
      if (c.endMs > e) e = c.endMs;
    }
    return e;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'hidden': hidden,
        'muted': muted,
        'clips': clips.map((c) => c.toJson()).toList(),
      };

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'Pista',
        kind: TrackKind.values.byName(j['kind'] as String),
        hidden: (j['hidden'] as bool?) ?? false,
        muted: (j['muted'] as bool?) ?? false,
        clips: ((j['clips'] as List?) ?? [])
            .map((e) => MediaClip.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Project {
  String name;
  int aspectW;
  int aspectH;
  List<Track> tracks;

  Project({
    required this.name,
    required this.aspectW,
    required this.aspectH,
    required this.tracks,
  });

  factory Project.empty() => Project(
        name: 'Mi proyecto',
        aspectW: 9,
        aspectH: 16,
        tracks: [
          Track(id: 't_main', name: 'Principal', kind: TrackKind.video),
          Track(id: 't_over', name: 'Superposición', kind: TrackKind.video),
          Track(id: 't_text', name: 'Texto', kind: TrackKind.text),
        ],
      );

  double get aspect => aspectW / aspectH;

  int get durationMs {
    var e = 0;
    for (final t in tracks) {
      if (t.endMs > e) e = t.endMs;
    }
    return e;
  }

  bool get isEmpty => tracks.every((t) => t.clips.isEmpty);

  MediaClip? findClip(String id) {
    for (final t in tracks) {
      for (final c in t.clips) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  Track? trackOf(String clipId) {
    for (final t in tracks) {
      for (final c in t.clips) {
        if (c.id == clipId) return t;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'name': name,
        'aspectW': aspectW,
        'aspectH': aspectH,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        name: (j['name'] as String?) ?? 'Mi proyecto',
        aspectW: _i(j['aspectW'], 9),
        aspectH: _i(j['aspectH'], 16),
        tracks: ((j['tracks'] as List?) ?? [])
            .map((e) => Track.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
