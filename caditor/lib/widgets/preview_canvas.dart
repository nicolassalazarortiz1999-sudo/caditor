import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/filters.dart';
import '../models/project.dart';
import '../state/playback_engine.dart';
import '../state/providers.dart';
import '../theme.dart';

class PreviewCanvas extends ConsumerWidget {
  const PreviewCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ed = ref.watch(editorProvider);
    final engine = ref.watch(playbackProvider);
    final project = ed.project;

    return Center(
      child: AspectRatio(
        aspectRatio: project.aspect,
        child: ClipRect(
          child: Container(
            color: Colors.black,
            child: LayoutBuilder(builder: (context, box) {
              final size = Size(box.maxWidth, box.maxHeight);
              final t = engine.playheadMs;
              final layers = <Widget>[];
              for (final track in project.tracks) {
                if (track.hidden) continue;
                for (final c in track.clips) {
                  if (t >= c.startMs && t < c.endMs) {
                    final w = _layer(c, size, t, engine);
                    if (w != null) layers.add(w);
                  }
                }
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  ...layers,
                  if (project.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Toca "Media" para agregar\ntus videos y fotos',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: kMuted, height: 1.4),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget? _layer(MediaClip c, Size size, int t, PlaybackEngine engine) {
    Widget content;
    switch (c.type) {
      case ClipType.video:
        final ctrl = engine.readyPlayer(c.id);
        if (ctrl == null || ctrl.value.size.isEmpty) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: kPink),
            ),
          );
        }
        content = SizedBox(
          width: size.width,
          height: size.height,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: ctrl.value.size.width,
              height: ctrl.value.size.height,
              child: VideoPlayer(ctrl),
            ),
          ),
        );
        break;
      case ClipType.image:
        content = SizedBox(
          width: size.width,
          height: size.height,
          child: Image.file(
            File(c.sourcePath ?? ''),
            fit: BoxFit.contain,
            cacheWidth: 1280,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        );
        break;
      case ClipType.text:
        content = SizedBox(
          width: size.width,
          height: size.height,
          child: Center(child: _textBox(c, size)),
        );
        break;
    }

    final matrix = clipColorMatrix(c);
    if (matrix != null && c.type != ClipType.text) {
      content = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: content,
      );
    }

    content = Transform.translate(
      offset: Offset(c.posX * size.width / 2, c.posY * size.height / 2),
      child: Transform.rotate(
        angle: c.rotation * math.pi / 180,
        child: Transform.scale(
          scale: c.scale,
          child: Transform.flip(
            flipX: c.flipH,
            flipY: c.flipV,
            child: content,
          ),
        ),
      ),
    );

    final alpha = clampD(c.opacity * c.fadeFactorAt(t - c.startMs), 0.0, 1.0);
    if (alpha < 1) {
      content = Opacity(opacity: alpha, child: content);
    }
    return Positioned.fill(child: content);
  }

  Widget _textBox(MediaClip c, Size size) {
    final fs = c.fontSize * size.width / 360;
    final style = TextStyle(
      color: Color(c.textColor),
      fontSize: fs,
      fontWeight: c.bold ? FontWeight.w800 : FontWeight.w400,
      fontStyle: c.italic ? FontStyle.italic : FontStyle.normal,
      height: 1.15,
      shadows: c.bgColor == 0
          ? const [Shadow(blurRadius: 6, color: Colors.black54)]
          : null,
    );
    final text = Text(c.text, textAlign: TextAlign.center, style: style);
    if (c.bgColor == 0) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.06),
        child: text,
      );
    }
    return Container(
      margin: EdgeInsets.symmetric(horizontal: size.width * 0.06),
      padding: EdgeInsets.symmetric(horizontal: fs * 0.5, vertical: fs * 0.25),
      decoration: BoxDecoration(
        color: Color(c.bgColor),
        borderRadius: BorderRadius.circular(fs * 0.3),
      ),
      child: text,
    );
  }
}
