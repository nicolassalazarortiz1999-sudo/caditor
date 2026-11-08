import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../models/project.dart';
import 'editor_controller.dart';

/// Motor de reproducción: mueve la línea blanca (playhead) y mantiene
/// sincronizados los reproductores de video con la línea de tiempo.
class PlaybackEngine extends ChangeNotifier {
  PlaybackEngine(this.editor) {
    editor.addListener(_onEditorChanged);
  }

  final EditorController editor;

  int playheadMs = 0;
  bool isPlaying = false;

  final Map<String, VideoPlayerController> _players = {};
  final Set<String> _loading = {};
  final Map<String, double> _lastSpeed = {};
  final Map<String, double> _lastVolume = {};

  Timer? _timer;
  final Stopwatch _sw = Stopwatch();
  int _baseMs = 0;
  bool _syncing = false;
  bool _syncAgain = false;
  bool _disposed = false;

  VideoPlayerController? readyPlayer(String clipId) => _players[clipId];

  // ───────────── control ─────────────

  void play() {
    if (isPlaying) return;
    final end = editor.project.durationMs;
    if (end <= 0) return;
    if (playheadMs >= end - 50) playheadMs = 0;
    isPlaying = true;
    _baseMs = playheadMs;
    _sw
      ..reset()
      ..start();
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
    notifyListeners();
    _sync(force: true);
  }

  void pause() {
    if (!isPlaying) return;
    isPlaying = false;
    _timer?.cancel();
    _timer = null;
    _sw.stop();
    notifyListeners();
    _sync();
  }

  void toggle() => isPlaying ? pause() : play();

  void seek(int ms) {
    final end = editor.project.durationMs;
    playheadMs = math.max(0, math.min(end, ms));
    if (isPlaying) {
      _baseMs = playheadMs;
      _sw
        ..reset()
        ..start();
    }
    notifyListeners();
    _sync(force: isPlaying);
  }

  void _tick() {
    final end = editor.project.durationMs;
    final t = _baseMs + _sw.elapsedMilliseconds;
    if (t >= end) {
      playheadMs = end;
      isPlaying = false;
      _timer?.cancel();
      _timer = null;
      _sw.stop();
      notifyListeners();
      _sync();
      return;
    }
    playheadMs = t;
    notifyListeners();
    _sync();
  }

  void _onEditorChanged() {
    final end = editor.project.durationMs;
    if (playheadMs > end) playheadMs = end;
    notifyListeners();
    _sync();
  }

  // ───────────── reproductores ─────────────

  void _ensurePlayer(MediaClip c) {
    if (c.type != ClipType.video || c.sourcePath == null) return;
    if (_players.containsKey(c.id) || _loading.contains(c.id)) return;
    _loading.add(c.id);
    final ctrl = VideoPlayerController.file(
      File(c.sourcePath!),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    ctrl.initialize().then((_) async {
      _loading.remove(c.id);
      if (_disposed || editor.project.findClip(c.id) == null) {
        await ctrl.dispose();
        return;
      }
      await ctrl.setLooping(false);
      _players[c.id] = ctrl;
      notifyListeners();
      _sync(force: true);
    }).catchError((Object _) {
      _loading.remove(c.id);
      ctrl.dispose();
    });
  }

  void _disposeLater(VideoPlayerController ctrl) {
    Future.delayed(const Duration(milliseconds: 150), () {
      ctrl.dispose();
    });
  }

  Future<void> _sync({bool force = false}) async {
    if (_disposed) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      var f = force;
      do {
        _syncAgain = false;
        await _syncOnce(f);
        f = false;
      } while (_syncAgain && !_disposed);
    } catch (_) {
      // Un fallo puntual de un reproductor no debe detener el editor.
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncOnce(bool force) async {
    final t = playheadMs;
    final project = editor.project;

    // 1. Precargar los videos cercanos al playhead.
    for (final track in project.tracks) {
      if (track.hidden) continue;
      for (final c in track.clips) {
        if (c.type != ClipType.video) continue;
        if (c.endMs > t - 2500 && c.startMs < t + 2000) _ensurePlayer(c);
      }
    }

    // 2. Liberar los que quedaron lejos o ya no existen.
    var removed = false;
    for (final id in _players.keys.toList()) {
      final c = project.findClip(id);
      final far = c == null || c.endMs < t - 4000 || c.startMs > t + 4000;
      if (far) {
        final p = _players.remove(id);
        _lastSpeed.remove(id);
        _lastVolume.remove(id);
        if (p != null) _disposeLater(p);
        removed = true;
      }
    }
    if (removed) notifyListeners();

    // 3. Sincronizar posición, velocidad y volumen.
    for (final entry in _players.entries.toList()) {
      final c = project.findClip(entry.key);
      final track = c == null ? null : project.trackOf(c.id);
      if (c == null || track == null) continue;
      final ctrl = entry.value;
      final active = !track.hidden && t >= c.startMs && t < c.endMs;

      if (!active) {
        if (ctrl.value.isPlaying) await ctrl.pause();
        continue;
      }

      final target = c.inMs + ((t - c.startMs) * c.speed).round();
      final pos = ctrl.value.position.inMilliseconds;
      final rawVol =
          track.muted ? 0.0 : c.volume * c.fadeFactorAt(t - c.startMs);
      final vol = (clampD(rawVol, 0.0, 1.0) * 100).round() / 100;

      if (_lastVolume[c.id] != vol) {
        _lastVolume[c.id] = vol;
        await ctrl.setVolume(vol);
      }

      if (isPlaying) {
        if (_lastSpeed[c.id] != c.speed) {
          _lastSpeed[c.id] = c.speed;
          await ctrl.setPlaybackSpeed(c.speed);
        }
        if (force || (pos - target).abs() > 400) {
          await ctrl.seekTo(Duration(milliseconds: target));
        }
        if (!ctrl.value.isPlaying) await ctrl.play();
      } else {
        if (ctrl.value.isPlaying) await ctrl.pause();
        if ((pos - target).abs() > 30) {
          await ctrl.seekTo(Duration(milliseconds: target));
        }
      }
    }
  }

  /// Pausa y libera todos los reproductores (al salir del editor).
  void releasePlayers() {
    isPlaying = false;
    _timer?.cancel();
    _timer = null;
    _sw.stop();
    for (final p in _players.values) {
      p.dispose();
    }
    _players.clear();
    _lastSpeed.clear();
    _lastVolume.clear();
    _loading.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    editor.removeListener(_onEditorChanged);
    releasePlayers();
    super.dispose();
  }
}
