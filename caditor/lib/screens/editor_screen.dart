import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../models/project.dart';
import '../services/project_storage.dart';
import '../state/playback_engine.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/preview_canvas.dart';
import '../widgets/timeline_view.dart';
import '../widgets/tool_sheets.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _ToolDef {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _ToolDef(this.icon, this.label, this.onTap, {this.danger = false});
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late final PlaybackEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = ref.read(playbackProvider);
  }

  @override
  void dispose() {
    _engine.releasePlayers();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ───────────── acciones ─────────────

  Future<void> _importMedia() async {
    _engine.pause();
    List<XFile> files;
    try {
      files = await ImagePicker().pickMultipleMedia();
    } catch (e) {
      _snack('No se pudo abrir la galería: $e');
      return;
    }
    if (files.isEmpty || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: kPink)),
    );

    final clips = <MediaClip>[];
    final ed = ref.read(editorProvider);
    try {
      for (final f in files) {
        final path = await ProjectStorage.importMedia(f.path);
        final name = path.split('/').last.replaceFirst(RegExp(r'^\d+_'), '');
        if (isVideoPath(path)) {
          final vc = VideoPlayerController.file(File(path));
          await vc.initialize();
          final dur = vc.value.duration.inMilliseconds;
          await vc.dispose();
          clips.add(MediaClip(
            id: ed.newId(),
            type: ClipType.video,
            sourcePath: path,
            name: name,
            sourceDurationMs: dur,
            outMs: dur,
          ));
        } else {
          clips.add(MediaClip(
            id: ed.newId(),
            type: ClipType.image,
            sourcePath: path,
            name: name,
            outMs: 5000,
          ));
        }
      }
    } catch (e) {
      if (mounted) _snack('No se pudo importar un archivo: $e');
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    if (clips.isNotEmpty) ed.addMediaClips(clips, _engine.playheadMs);
  }

  void _addText() {
    _engine.pause();
    ref.read(editorProvider).addText(_engine.playheadMs);
    showTextSheet(context, ref);
  }

  void _split() {
    final ok = ref.read(editorProvider).splitAtPlayhead(_engine.playheadMs);
    if (!ok) {
      _snack('Mueve la línea blanca sobre el clip seleccionado para dividirlo.');
    }
  }

  void _zoom(double factor) {
    final n = ref.read(timelineZoomProvider.notifier);
    n.state = clampD(n.state * factor, 0.01, 0.6);
  }

  // ───────────── interfaz ─────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            const Expanded(flex: 11, child: PreviewCanvas()),
            _playerBar(),
            const Expanded(flex: 9, child: TimelineView()),
            _toolbar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    final p = ref.watch(editorProvider).project;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 12, 2),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () {
              _engine.pause();
              Navigator.of(context).pop();
            },
          ),
          ShaderMask(
            shaderCallback: (r) => kBrandGradient.createShader(r),
            child: const Text(
              'Caditor',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          ActionChip(
            avatar: const Icon(Icons.aspect_ratio_rounded, size: 18),
            label: Text('${p.aspectW}:${p.aspectH}'),
            onPressed: () => showAspectSheet(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _playerBar() {
    final ed = ref.watch(editorProvider);
    final engine = ref.watch(playbackProvider);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${fmtTime(engine.playheadMs)} / ${fmtTime(ed.project.durationMs)}',
              style: const TextStyle(fontSize: 12, color: kMuted),
            ),
          ),
          IconButton(
            tooltip: 'Deshacer',
            icon: const Icon(Icons.undo_rounded),
            onPressed: ed.canUndo ? ed.undo : null,
          ),
          IconButton(
            iconSize: 34,
            tooltip: engine.isPlaying ? 'Pausar' : 'Reproducir',
            icon: Icon(
              engine.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: Colors.white,
            ),
            onPressed: engine.toggle,
          ),
          IconButton(
            tooltip: 'Rehacer',
            icon: const Icon(Icons.redo_rounded),
            onPressed: ed.canRedo ? ed.redo : null,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Alejar',
                  icon: const Icon(Icons.zoom_out_rounded),
                  onPressed: () => _zoom(1 / 1.35),
                ),
                IconButton(
                  tooltip: 'Acercar',
                  icon: const Icon(Icons.zoom_in_rounded),
                  onPressed: () => _zoom(1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    final ed = ref.watch(editorProvider);
    final clip = ed.selectedClip;

    final tools = <_ToolDef>[
      _ToolDef(Icons.add_photo_alternate_rounded, 'Media', _importMedia),
      _ToolDef(Icons.title_rounded, 'Texto', _addText),
      if (clip != null) ...[
        _ToolDef(Icons.content_cut_rounded, 'Dividir', _split),
        if (clip.type == ClipType.text)
          _ToolDef(Icons.edit_rounded, 'Editar', () => showTextSheet(context, ref)),
        if (clip.type == ClipType.video)
          _ToolDef(Icons.speed_rounded, 'Velocidad', () => showSpeedSheet(context, ref)),
        if (clip.type == ClipType.video)
          _ToolDef(Icons.volume_up_rounded, 'Volumen', () => showVolumeSheet(context, ref)),
        if (clip.type != ClipType.text)
          _ToolDef(Icons.auto_awesome_rounded, 'Filtros', () => showFilterSheet(context, ref)),
        if (clip.type != ClipType.text)
          _ToolDef(Icons.tune_rounded, 'Ajustes', () => showAdjustSheet(context, ref)),
        _ToolDef(Icons.opacity_rounded, 'Opacidad', () => showOpacitySheet(context, ref)),
        _ToolDef(Icons.open_with_rounded, 'Transformar', () => showTransformSheet(context, ref)),
        _ToolDef(Icons.gradient_rounded, 'Fundidos', () => showFadeSheet(context, ref)),
        _ToolDef(Icons.copy_rounded, 'Duplicar', ed.duplicateSelected),
        _ToolDef(Icons.delete_rounded, 'Eliminar', ed.deleteSelected, danger: true),
      ],
      _ToolDef(Icons.layers_rounded, 'Pista', () => showTrackSheet(context, ref)),
      _ToolDef(Icons.aspect_ratio_rounded, 'Proporción', () => showAspectSheet(context, ref)),
    ];

    return Container(
      height: 66,
      decoration: const BoxDecoration(
        color: kCard,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        children: [
          for (final t in tools)
            InkWell(
              onTap: t.onTap,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 74,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t.icon, color: t.danger ? kPink : Colors.white, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: t.danger ? kPink : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
