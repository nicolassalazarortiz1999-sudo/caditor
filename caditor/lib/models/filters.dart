import 'project.dart';

class FilterPreset {
  final String id;
  final String name;
  final List<double>? matrix;
  FilterPreset(this.id, this.name, this.matrix);
}

const List<double> _identity = [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

/// Resultado de aplicar [a] y después [b].
List<double> _mul(List<double> b, List<double> a) {
  final r = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 5; col++) {
      var v = 0.0;
      for (var k = 0; k < 4; k++) {
        v += b[row * 5 + k] * a[k * 5 + col];
      }
      if (col == 4) v += b[row * 5 + 4];
      r[row * 5 + col] = v;
    }
  }
  return r;
}

List<double> _sat(double s) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  return [
    lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0, 0, //
    lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0, 0,
    lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

List<double> _contrast(double c) {
  final t = 128 * (1 - c);
  return [
    c, 0, 0, 0, t, //
    0, c, 0, 0, t,
    0, 0, c, 0, t,
    0, 0, 0, 1, 0,
  ];
}

List<double> _brightness(double b) {
  final o = b * 255;
  return [
    1, 0, 0, 0, o, //
    0, 1, 0, 0, o,
    0, 0, 1, 0, o,
    0, 0, 0, 1, 0,
  ];
}

final List<double> _sepia = [
  0.393, 0.769, 0.189, 0, 0, //
  0.349, 0.686, 0.168, 0, 0,
  0.272, 0.534, 0.131, 0, 0,
  0, 0, 0, 1, 0,
];

final List<FilterPreset> kFilters = [
  FilterPreset('none', 'Original', null),
  FilterPreset('bw', 'B/N', _sat(0)),
  FilterPreset('noir', 'Noir', _mul(_contrast(1.4), _sat(0))),
  FilterPreset('sepia', 'Sepia', _sepia),
  FilterPreset('vivid', 'Vívido', _mul(_contrast(1.1), _sat(1.5))),
  FilterPreset('cold', 'Frío', [
    0.9, 0, 0, 0, 0, //
    0, 1, 0, 0, 0,
    0, 0, 1.15, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  FilterPreset('warm', 'Cálido', [
    1.12, 0, 0, 0, 0, //
    0, 1, 0, 0, 0,
    0, 0, 0.88, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  FilterPreset('vintage', 'Vintage',
      _mul(_contrast(0.9), _mul(_sat(0.75), _sepia))),
  FilterPreset('cine', 'Cine', _mul(_contrast(1.15), [
    0.95, 0, 0, 0, 0, //
    0, 1, 0, 0, 0,
    0, 0, 1.08, 0, 0,
    0, 0, 0, 1, 0,
  ])),
  FilterPreset(
      'fade', 'Desvanecido', _mul(_brightness(0.06), _mul(_contrast(0.8), _sat(0.8)))),
];

/// Matriz de color final del clip (filtro + ajustes) o null si no hay cambios.
List<double>? clipColorMatrix(MediaClip c) {
  final preset =
      kFilters.firstWhere((f) => f.id == c.filterId, orElse: () => kFilters.first);
  List<double>? m = preset.matrix;
  if (c.saturation != 1) m = _mul(_sat(c.saturation), m ?? _identity);
  if (c.contrast != 1) m = _mul(_contrast(c.contrast), m ?? _identity);
  if (c.brightness != 0) m = _mul(_brightness(c.brightness), m ?? _identity);
  return m;
}
