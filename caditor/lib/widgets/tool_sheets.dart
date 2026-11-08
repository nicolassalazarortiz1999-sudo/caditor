import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/filters.dart';
import '../models/project.dart';
import '../state/providers.dart';
import '../theme.dart';

Future<void> _openSheet(BuildContext context, WidgetRef ref, Widget sheet) {
  return showModalBottomSheet<void>(
    context: context,
    barrierColor: Colors.transparent,
    backgroundColor: kCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => sheet,
  ).whenComplete(() => ref.read(editorProvider).endEdit());
}

void showSpeedSheet(BuildContext c, WidgetRef r) => _openSheet(c, r, const _SpeedSheet());
void showVolumeSheet(BuildContext c, WidgetRef r) => _openSheet(c, r, const _VolumeSheet());
void showOpacitySheet(BuildContext c, WidgetRef r) => _openSheet(c, r, const _OpacitySheet());
void showFilterSheet(BuildContext c, WidgetRef r) => _openSheet(c, r, const _FilterSheet());
void showAdjustSheet(BuildContext c, WidgetRef r) => _openSheet(c, r, const _AdjustSheet());
void showTransformSheet(BuildContext c, WidgetRef r) => _openSheet(c, r, const _TransformSheet());
void showFadeSheet(BuildContext c, WidgetRef r) => _openSheet(c, r, const _FadeSheet());
void showTextSheet(BuildContext c, WidgetRef r) => _openSheet(c, r, const _TextSheet());
void showAspectSheet(BuildContext c, WidgetRef r) => _openSheet(c, r, const _AspectSheet());
void showTrackSheet(BuildContext c, WidgetRef r) => _openSheet(c, r, const _TrackSheet());

// ───────────── piezas comunes ─────────────

class _SheetFrame extends StatelessWidget {
  final String title;
  final Widget child;
  const _SheetFrame({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _Sl extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double) fmt;
  final VoidCallback onStart;
  final ValueChanged<double> onChanged;
  final VoidCallback onEnd;

  const _Sl({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.fmt,
    required this.onStart,
    required this.onChanged,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: kMuted)),
            Text(fmt(value), style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        Slider(
          value: clampD(value, min, max),
          min: min,
          max: max,
          onChangeStart: (_) => onStart(),
          onChanged: onChanged,
          onChangeEnd: (_) => onEnd(),
        ),
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  final List<int> colors;
  final int selected;
  final ValueChanged<int> onPick;
  const _ColorRow({required this.colors, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final col in colors)
          GestureDetector(
            onTap: () => onPick(col),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: col == 0 ? Colors.transparent : Color(col),
                shape: BoxShape.circle,
                border: Border.all(
                  color: col == selected ? kPink : Colors.white24,
                  width: col == selected ? 3 : 1.5,
                ),
              ),
              child: col == 0
                  ? const Icon(Icons.block_rounded, size: 18, color: kMuted)
                  : null,
            ),
          ),
      ],
    );
  }
}

String _pct(double v) => '${(v * 100).round()}%';

// ───────────── hojas de herramientas ─────────────

class _SpeedSheet extends ConsumerWidget {
  const _SpeedSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ed = ref.watch(editorProvider);
    final c = ed.selectedClip;
    if (c == null) return const SizedBox(height: 80);
    return _SheetFrame(
      title: 'Velocidad',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Sl(
            label: 'Velocidad',
            value: c.speed,
            min: 0.25,
            max: 4,
            fmt: (v) => '${v.toStringAsFixed(2)}x',
            onStart: ed.beginEdit,
            onChanged: (v) => ed.setSpeed(c.id, v),
            onEnd: ed.endEdit,
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final s in [0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0])
                ChoiceChip(
                  label: Text('${s}x'),
                  selected: (c.speed - s).abs() < 0.01,
                  onSelected: (_) => ed.edit(() => ed.setSpeed(c.id, s)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VolumeSheet extends ConsumerWidget {
  const _VolumeSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ed = ref.watch(editorProvider);
    final c = ed.selectedClip;
    if (c == null) return const SizedBox(height: 80);
    return _SheetFrame(
      title: 'Volumen',
      child: _Sl(
        label: 'Volumen del clip',
        value: c.volume,
        min: 0,
        max: 2,
        fmt: _pct,
        onStart: ed.beginEdit,
        onChanged: (v) => ed.updateClip(c.id, (x) => x.volume = v),
        onEnd: ed.endEdit,
      ),
    );
  }
}

class _OpacitySheet extends ConsumerWidget {
  const _OpacitySheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ed = ref.watch(editorProvider);
    final c = ed.selectedClip;
    if (c == null) return const SizedBox(height: 80);
    return _SheetFrame(
      title: 'Opacidad',
      child: _Sl(
        label: 'Opacidad',
        value: c.opacity,
        min: 0,
        max: 1,
        fmt: _pct,
        onStart: ed.beginEdit,
        onChanged: (v) => ed.updateClip(c.id, (x) => x.opacity = v),
        onEnd: ed.endEdit,
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ed = ref.watch(editorProvider);
    final c = ed.selectedClip;
    if (c == null) return const SizedBox(height: 80);
    return _SheetFrame(
      title: 'Filtros',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in kFilters)
            ChoiceChip(
              label: Text(f.name),
              selected: c.filterId == f.id,
              onSelected: (_) =>
                  ed.edit(() => ed.updateClip(c.id, (x) => x.filterId = f.id)),
            ),
        ],
      ),
    );
  }
}

class _AdjustSheet extends ConsumerWidget {
  const _AdjustSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ed = ref.watch(editorProvider);
    final c = ed.selectedClip;
    if (c == null) return const SizedBox(height: 80);
    return _SheetFrame(
      title: 'Ajustes de color',
      child: Column(
        children: [
          _Sl(
            label: 'Brillo',
            value: c.brightness,
            min: -0.5,
            max: 0.5,
            fmt: (v) => v.toStringAsFixed(2),
            onStart: ed.beginEdit,
            onChanged: (v) => ed.updateClip(c.id, (x) => x.brightness = v),
            onEnd: ed.endEdit,
          ),
          _Sl(
            label: 'Contraste',
            value: c.contrast,
            min: 0.3,
            max: 2,
            fmt: (v) => v.toStringAsFixed(2),
            onStart: ed.beginEdit,
            onChanged: (v) => ed.updateClip(c.id, (x) => x.contrast = v),
            onEnd: ed.endEdit,
          ),
          _Sl(
            label: 'Saturación',
            value: c.saturation,
            min: 0,
            max: 2,
            fmt: (v) => v.toStringAsFixed(2),
            onStart: ed.beginEdit,
            onChanged: (v) => ed.updateClip(c.id, (x) => x.saturation = v),
            onEnd: ed.endEdit,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => ed.edit(() => ed.updateClip(c.id, (x) {
                    x.brightness = 0;
                    x.contrast = 1;
                    x.saturation = 1;
                  })),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Restablecer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransformSheet extends ConsumerWidget {
  const _TransformSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ed = ref.watch(editorProvider);
    final c = ed.selectedClip;
    if (c == null) return const SizedBox(height: 80);
    return _SheetFrame(
      title: 'Transformar',
      child: Column(
        children: [
          _Sl(
            label: 'Tamaño',
            value: c.scale,
            min: 0.1,
            max: 4,
            fmt: _pct,
            onStart: ed.beginEdit,
            onChanged: (v) => ed.updateClip(c.id, (x) => x.scale = v),
            onEnd: ed.endEdit,
          ),
          _Sl(
            label: 'Rotación',
            value: c.rotation,
            min: -180,
            max: 180,
            fmt: (v) => '${v.round()}°',
            onStart: ed.beginEdit,
            onChanged: (v) => ed.updateClip(c.id, (x) => x.rotation = v),
            onEnd: ed.endEdit,
          ),
          _Sl(
            label: 'Posición horizontal',
            value: c.posX,
            min: -1,
            max: 1,
            fmt: (v) => v.toStringAsFixed(2),
            onStart: ed.beginEdit,
            onChanged: (v) => ed.updateClip(c.id, (x) => x.posX = v),
            onEnd: ed.endEdit,
          ),
          _Sl(
            label: 'Posición vertical',
            value: c.posY,
            min: -1,
            max: 1,
            fmt: (v) => v.toStringAsFixed(2),
            onStart: ed.beginEdit,
            onChanged: (v) => ed.updateClip(c.id, (x) => x.posY = v),
            onEnd: ed.endEdit,
          ),
          Row(
            children: [
              FilterChip(
                label: const Text('Voltear ↔'),
                selected: c.flipH,
                onSelected: (_) =>
                    ed.edit(() => ed.updateClip(c.id, (x) => x.flipH = !x.flipH)),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Voltear ↕'),
                selected: c.flipV,
                onSelected: (_) =>
                    ed.edit(() => ed.updateClip(c.id, (x) => x.flipV = !x.flipV)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => ed.edit(() => ed.updateClip(c.id, (x) {
                      x.scale = 1;
                      x.rotation = 0;
                      x.posX = 0;
                      x.posY = 0;
                      x.flipH = false;
                      x.flipV = false;
                    })),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Restablecer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FadeSheet extends ConsumerWidget {
  const _FadeSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ed = ref.watch(editorProvider);
    final c = ed.selectedClip;
    if (c == null) return const SizedBox(height: 80);
    final maxFade = (c.durationMs / 2).clamp(300, 3000).toDouble();
    String s(double v) => '${(v / 1000).toStringAsFixed(1)} s';
    return _SheetFrame(
      title: 'Fundidos',
      child: Column(
        children: [
          _Sl(
            label: 'Aparecer (entrada)',
            value: c.fadeInMs.toDouble(),
            min: 0,
            max: maxFade,
            fmt: s,
            onStart: ed.beginEdit,
            onChanged: (v) => ed.updateClip(c.id, (x) => x.fadeInMs = v.round()),
            onEnd: ed.endEdit,
          ),
          _Sl(
            label: 'Desaparecer (salida)',
            value: c.fadeOutMs.toDouble(),
            min: 0,
            max: maxFade,
            fmt: s,
            onStart: ed.beginEdit,
            onChanged: (v) => ed.updateClip(c.id, (x) => x.fadeOutMs = v.round()),
            onEnd: ed.endEdit,
          ),
        ],
      ),
    );
  }
}

const List<int> kTextColors = [
  0xFFFFFFFF, 0xFF000000, 0xFFEF4444, 0xFFF59E0B, 0xFFFDE047,
  0xFF22C55E, 0xFF06B6D4, 0xFF3B82F6, 0xFF8B5CF6, 0xFFEC4899,
];
const List<int> kBgColors = [
  0, 0xFF000000, 0xB3000000, 0xFFFFFFFF, 0xFFEC4899, 0xFF8B5CF6, 0xFF3B82F6,
];

class _TextSheet extends ConsumerStatefulWidget {
  const _TextSheet();
  @override
  ConsumerState<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends ConsumerState<_TextSheet> {
  late final TextEditingController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TextEditingController(
      text: ref.read(editorProvider).selectedClip?.text ?? '',
    );
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ed = ref.watch(editorProvider);
    final c = ed.selectedClip;
    if (c == null || c.type != ClipType.text) return const SizedBox(height: 80);
    return _SheetFrame(
      title: 'Texto',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _tc,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Escribe tu texto',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              ed.beginEdit();
              ed.updateClip(c.id, (x) => x.text = v);
            },
            onSubmitted: (_) => ed.endEdit(),
          ),
          const SizedBox(height: 8),
          _Sl(
            label: 'Tamaño de letra',
            value: c.fontSize,
            min: 10,
            max: 120,
            fmt: (v) => v.round().toString(),
            onStart: ed.beginEdit,
            onChanged: (v) => ed.updateClip(c.id, (x) => x.fontSize = v),
            onEnd: ed.endEdit,
          ),
          Row(
            children: [
              FilterChip(
                label: const Text('Negrita'),
                selected: c.bold,
                onSelected: (_) =>
                    ed.edit(() => ed.updateClip(c.id, (x) => x.bold = !x.bold)),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Cursiva'),
                selected: c.italic,
                onSelected: (_) =>
                    ed.edit(() => ed.updateClip(c.id, (x) => x.italic = !x.italic)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Color del texto', style: TextStyle(color: kMuted)),
          const SizedBox(height: 8),
          _ColorRow(
            colors: kTextColors,
            selected: c.textColor,
            onPick: (col) =>
                ed.edit(() => ed.updateClip(c.id, (x) => x.textColor = col)),
          ),
          const SizedBox(height: 14),
          const Text('Fondo del texto', style: TextStyle(color: kMuted)),
          const SizedBox(height: 8),
          _ColorRow(
            colors: kBgColors,
            selected: c.bgColor,
            onPick: (col) =>
                ed.edit(() => ed.updateClip(c.id, (x) => x.bgColor = col)),
          ),
        ],
      ),
    );
  }
}

class _AspectSheet extends ConsumerWidget {
  const _AspectSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ed = ref.watch(editorProvider);
    final p = ed.project;
    const options = [
      (9, 16, '9:16  TikTok / Reels / Shorts'),
      (16, 9, '16:9  YouTube / horizontal'),
      (1, 1, '1:1  Cuadrado'),
      (4, 5, '4:5  Instagram'),
      (3, 4, '3:4  Vertical clásico'),
    ];
    return _SheetFrame(
      title: 'Proporción del video',
      child: Column(
        children: [
          for (final o in options)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(o.$3),
              trailing: (p.aspectW == o.$1 && p.aspectH == o.$2)
                  ? const Icon(Icons.check_circle_rounded, color: kPink)
                  : null,
              onTap: () {
                ed.setAspect(o.$1, o.$2);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}

class _TrackSheet extends ConsumerWidget {
  const _TrackSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ed = ref.read(editorProvider);
    return _SheetFrame(
      title: 'Agregar pista',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.videocam_rounded, color: kPink),
            title: const Text('Pista de video / fotos'),
            subtitle: const Text('Para superponer clips encima del principal'),
            onTap: () {
              ed.addTrack(TrackKind.video);
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.title_rounded, color: kPink),
            title: const Text('Pista de texto'),
            subtitle: const Text('Para varios textos al mismo tiempo'),
            onTap: () {
              ed.addTrack(TrackKind.text);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 4),
          const Text(
            'Tip: mantén presionado el icono de una pista para eliminarla.',
            style: TextStyle(color: kMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
