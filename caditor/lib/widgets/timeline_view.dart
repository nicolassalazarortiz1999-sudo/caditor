import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project.dart';
import '../state/editor_controller.dart';
import '../state/playback_engine.dart';
import '../state/providers.dart';
import '../theme.dart';

/// Línea de tiempo estilo CapCut: la línea blanca queda fija al centro y
/// las pistas se desplazan debajo. Toca un clip para seleccionarlo, arrastra
/// sus bordes para recortar y mantenlo presionado para moverlo.
class TimelineView extends ConsumerStatefulWidget {
  const TimelineView({super.key});

  @override
  ConsumerState<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<TimelineView> {
  static const double headerW = 56;
  static const double rowH = 54;
  static const double rulerH = 26;

  final ScrollController _hc = ScrollController();
  late final PlaybackEngine _engine;
  late final EditorController _ed;
  bool _programmatic = false;
  double _px = 0.08;
  int _dragStartMs = 0;
  double _dragDy = 0;
  double _trimRem = 0;

  @override
  void initState() {
    super.initState();
    _engine = ref.read(playbackProvider);
    _ed = ref.read(editorProvider);
    _engine.addListener(_onEngine);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToPlayhead());
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngine);
    _hc.dispose();
    super.dispose();
  }

  void _jumpToPlayhead({double threshold = 0}) {
    if (!_hc.hasClients || !_hc.position.hasContentDimensions) return;
    final max = _hc.position.maxScrollExtent;
    final target = math.max(0.0, math.min(max, _engine.playheadMs * _px));
    if ((target - _hc.offset).abs() > threshold) {
      _programmatic = true;
      _hc.jumpTo(target);
      _programmatic = false;
    }
  }

  void _onEngine() => _jumpToPlayhead(threshold: 0.75);

  @override
  Widget build(BuildContext context) {
    final ed = ref.watch(editorProvider);
    final zoom = ref.watch(timelineZoomProvider);
    if (zoom != _px) {
      _px = zoom;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToPlayhead());
    }
    final project = ed.project;

    return LayoutBuilder(builder: (context, box) {
      final viewportW = math.max(100.0, box.maxWidth - headerW);
      final pad = viewportW / 2;
      final durationMs = project.durationMs;
      final contentW = pad * 2 + math.max(durationMs, 1000) * _px;

      return Container(
        color: const Color(0xFF0F0F1A),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: headerW,
                    child: Column(
                      children: [
                        const SizedBox(height: rulerH),
                        for (var i = 0; i < project.tracks.length; i++)
                          _header(project.tracks[i], i),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: viewportW,
                    child: NotificationListener<ScrollUpdateNotification>(
                      onNotification: (n) {
                        if (_programmatic) return false;
                        if (n.metrics.axis != Axis.horizontal) return false;
                        _engine.seek((n.metrics.pixels / _px).round());
                        return false;
                      },
                      child: SingleChildScrollView(
                        controller: _hc,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: contentW,
                          child: Column(
                            children: [
                              _ruler(contentW, pad, durationMs),
                              for (var i = 0; i < project.tracks.length; i++)
                                _trackRow(project.tracks[i], i, contentW, pad),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: headerW + pad - 1,
              top: 0,
              bottom: 0,
              width: 2,
              child: const IgnorePointer(
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ───────────── encabezados de pista ─────────────

  Widget _mini(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: 16, color: kMuted),
      ),
    );
  }

  Widget _header(Track t, int i) {
    return SizedBox(
      height: rowH,
      child: GestureDetector(
        onLongPress: i == 0 ? null : () => _confirmRemove(t, i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _mini(
                  t.hidden
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  () => _ed.toggleHidden(i),
                ),
                if (t.kind == TrackKind.video)
                  _mini(
                    t.muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    () => _ed.toggleMuted(i),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(Icons.title_rounded, size: 16, color: kMuted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(Track t, int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('Eliminar pista'),
        content: Text(
          t.clips.isEmpty
              ? '¿Eliminar la pista "${t.name}"?'
              : '¿Eliminar la pista "${t.name}" y sus ${t.clips.length} clips?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) _ed.removeTrack(i);
  }

  // ───────────── regla de tiempo ─────────────

  Widget _ruler(double contentW, double pad, int durationMs) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) =>
          _engine.seek(((d.localPosition.dx - pad) / _px).round()),
      child: SizedBox(
        height: rulerH,
        width: contentW,
        child: CustomPaint(painter: _RulerPainter(_px, durationMs, pad)),
      ),
    );
  }

  // ───────────── pistas y clips ─────────────

  Widget _trackRow(Track track, int index, double contentW, double pad) {
    final selectedId = _ed.selectedId;
    return Opacity(
      opacity: track.hidden ? 0.4 : 1,
      child: SizedBox(
        height: rowH,
        width: contentW,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _ed.select(null),
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white10)),
                  ),
                ),
              ),
            ),
            for (final c in track.clips)
              _clipTile(c, index, pad, c.id == selectedId),
          ],
        ),
      ),
    );
  }

  Color _clipColor(ClipType t) {
    switch (t) {
      case ClipType.video:
        return const Color(0xFF6D28D9);
      case ClipType.image:
        return const Color(0xFF0E7490);
      case ClipType.text:
        return const Color(0xFFB45309);
    }
  }

  IconData _clipIcon(ClipType t) {
    switch (t) {
      case ClipType.video:
        return Icons.videocam_rounded;
      case ClipType.image:
        return Icons.image_rounded;
      case ClipType.text:
        return Icons.title_rounded;
    }
  }

  Widget _clipTile(MediaClip c, int trackIndex, double pad, bool selected) {
    final left = pad + c.startMs * _px;
    final width = math.max(12.0, c.durationMs * _px);
    final label = c.type == ClipType.text ? c.text : c.name;

    return Positioned(
      key: ValueKey(c.id),
      left: left,
      top: 3,
      width: width,
      height: rowH - 6,
      child: GestureDetector(
        onTap: () => _ed.select(c.id),
        onLongPressStart: (_) {
          _dragStartMs = c.startMs;
          _dragDy = 0;
          _ed.beginEdit();
          _ed.select(c.id);
        },
        onLongPressMoveUpdate: (d) {
          _dragDy = d.offsetFromOrigin.dy;
          _ed.moveClip(
            c.id,
            _dragStartMs + (d.offsetFromOrigin.dx / _px).round(),
          );
        },
        onLongPressEnd: (_) {
          final dRow = (_dragDy / rowH).round();
          if (dRow != 0) _ed.moveClipToTrack(c.id, trackIndex + dRow);
          _ed.endEdit();
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _clipColor(c.type),
                  borderRadius: BorderRadius.circular(8),
                  image: (c.type == ClipType.image && c.sourcePath != null)
                      ? DecorationImage(
                          image: ResizeImage(
                            FileImage(File(c.sourcePath!)),
                            width: 160,
                          ),
                          fit: BoxFit.cover,
                          colorFilter: const ColorFilter.mode(
                            Colors.black38,
                            BlendMode.darken,
                          ),
                        )
                      : null,
                ),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white24,
                    width: selected ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: width > 60
                    ? Row(
                        children: [
                          Icon(_clipIcon(c.type), size: 14, color: Colors.white70),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.clip,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          if ((c.speed - 1).abs() > 0.01)
                            Text(
                              '${c.speed.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            if (selected) _handle(c, true),
            if (selected) _handle(c, false),
          ],
        ),
      ),
    );
  }

  Widget _handle(MediaClip c, bool left) {
    return Positioned(
      left: left ? 0 : null,
      right: left ? null : 0,
      top: 0,
      bottom: 0,
      width: 18,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          _trimRem = 0;
          _ed.beginEdit();
        },
        onHorizontalDragUpdate: (d) {
          _trimRem += d.delta.dx / _px;
          final step = _trimRem.truncate();
          if (step != 0) {
            _trimRem -= step;
            if (left) {
              _ed.trimStartBy(c.id, step);
            } else {
              _ed.trimEndBy(c.id, step);
            }
          }
        },
        onHorizontalDragEnd: (_) => _ed.endEdit(),
        onHorizontalDragCancel: () => _ed.endEdit(),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: left
                ? const BorderRadius.horizontal(left: Radius.circular(8))
                : const BorderRadius.horizontal(right: Radius.circular(8)),
          ),
          child: Center(
            child: Container(width: 2, height: 16, color: Colors.black45),
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double px;
  final int durationMs;
  final double pad;

  _RulerPainter(this.px, this.durationMs, this.pad);

  String _label(int ms) {
    if (ms % 1000 == 0) {
      final s = ms ~/ 1000;
      return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    }
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }

  @override
  void paint(Canvas canvas, Size size) {
    const steps = [100, 200, 500, 1000, 2000, 5000, 10000, 30000, 60000, 120000, 300000];
    var step = steps.last;
    for (final s in steps) {
      if (s * px >= 70) {
        step = s;
        break;
      }
    }
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    for (var t = 0; t <= durationMs + step; t += step) {
      final x = pad + t * px;
      canvas.drawLine(Offset(x, size.height - 8), Offset(x, size.height), paint);
      final tp = TextPainter(
        text: TextSpan(
          text: _label(t),
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 3, 4));
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) =>
      old.px != px || old.durationMs != durationMs || old.pad != pad;
}
