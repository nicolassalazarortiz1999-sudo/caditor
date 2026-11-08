import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/project.dart';
import '../services/project_storage.dart';

/// Cerebro del editor: guarda el proyecto y todas las operaciones de edición.
/// Cada operación cambia el proyecto (una lista de instrucciones), nunca el
/// video original; por eso todo se puede deshacer, rehacer y volver a editar.
class EditorController extends ChangeNotifier {
  static const int minClipMs = 200;

  Project project = Project.empty();
  String? selectedId;

  final List<String> _undo = [];
  final List<String> _redo = [];
  String? _pending;
  Timer? _saveTimer;
  final math.Random _rand = math.Random();

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  MediaClip? get selectedClip =>
      selectedId == null ? null : project.findClip(selectedId!);

  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_rand.nextInt(99999)}';

  String _snap() => jsonEncode(project.toJson());

  // ───────────── historial ─────────────

  void beginEdit() {
    _pending ??= _snap();
  }

  void endEdit() {
    final p = _pending;
    if (p == null) return;
    _pending = null;
    if (p != _snap()) {
      _undo.add(p);
      if (_undo.length > 100) _undo.removeAt(0);
      _redo.clear();
      _scheduleSave();
    }
    notifyListeners();
  }

  void edit(void Function() fn) {
    beginEdit();
    fn();
    endEdit();
  }

  void undo() {
    endEdit();
    if (_undo.isEmpty) return;
    _redo.add(_snap());
    project =
        Project.fromJson(jsonDecode(_undo.removeLast()) as Map<String, dynamic>);
    _validateSelection();
    _scheduleSave();
    notifyListeners();
  }

  void redo() {
    endEdit();
    if (_redo.isEmpty) return;
    _undo.add(_snap());
    project =
        Project.fromJson(jsonDecode(_redo.removeLast()) as Map<String, dynamic>);
    _validateSelection();
    _scheduleSave();
    notifyListeners();
  }

  void _validateSelection() {
    if (selectedId != null && project.findClip(selectedId!) == null) {
      selectedId = null;
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () async {
      try {
        await ProjectStorage.save(project);
      } catch (_) {}
    });
  }

  // ───────────── proyecto ─────────────

  void newProject() {
    project = Project.empty();
    selectedId = null;
    _undo.clear();
    _redo.clear();
    _pending = null;
    _scheduleSave();
    notifyListeners();
  }

  Future<bool> loadSaved() async {
    final p = await ProjectStorage.load();
    if (p == null) return false;
    project = p;
    selectedId = null;
    _undo.clear();
    _redo.clear();
    _pending = null;
    notifyListeners();
    return true;
  }

  void setAspect(int w, int h) {
    edit(() {
      project.aspectW = w;
      project.aspectH = h;
    });
  }

  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  // ───────────── pistas ─────────────

  void addTrack(TrackKind kind) {
    edit(() {
      final n = project.tracks.where((t) => t.kind == kind).length + 1;
      project.tracks.add(Track(
        id: newId(),
        name: kind == TrackKind.video ? 'Video $n' : 'Texto $n',
        kind: kind,
      ));
    });
  }

  void removeTrack(int index) {
    if (index <= 0 || index >= project.tracks.length) return;
    edit(() {
      project.tracks.removeAt(index);
      _validateSelection();
    });
  }

  void toggleHidden(int index) {
    edit(() => project.tracks[index].hidden = !project.tracks[index].hidden);
  }

  void toggleMuted(int index) {
    edit(() => project.tracks[index].muted = !project.tracks[index].muted);
  }

  // ───────────── ayudas internas ─────────────

  bool _isMain(Track t) => identical(t, project.tracks.first);

  void _normalize(Track track) {
    track.clips.sort((a, b) => a.startMs.compareTo(b.startMs));
    final main = _isMain(track);
    var cursor = 0;
    for (final c in track.clips) {
      if (main) {
        c.startMs = cursor;
      } else {
        c.startMs = math.max(c.startMs, cursor);
      }
      cursor = c.endMs;
    }
  }

  int _prevEnd(Track t, MediaClip c) {
    var r = 0;
    for (final o in t.clips) {
      if (o.id != c.id && o.endMs <= c.startMs && o.endMs > r) r = o.endMs;
    }
    return r;
  }

  int _nextStart(Track t, MediaClip c) {
    var r = 1 << 30;
    for (final o in t.clips) {
      if (o.id != c.id && o.startMs >= c.endMs && o.startMs < r) r = o.startMs;
    }
    return r;
  }

  int _freeStart(Track t, int dur, int desired, {String? ignoreId}) {
    desired = math.max(0, desired);
    bool ok(int s) {
      for (final o in t.clips) {
        if (o.id == ignoreId) continue;
        if (s < o.endMs && s + dur > o.startMs) return false;
      }
      return true;
    }

    if (ok(desired)) return desired;
    final candidates = <int>[0];
    for (final o in t.clips) {
      if (o.id == ignoreId) continue;
      candidates.add(o.endMs);
      candidates.add(o.startMs - dur);
    }
    int? best;
    for (final c in candidates) {
      if (c < 0 || !ok(c)) continue;
      if (best == null || (c - desired).abs() < (best - desired).abs()) best = c;
    }
    return best ?? t.endMs;
  }

  // ───────────── agregar ─────────────

  void addMediaClips(List<MediaClip> clips, int playheadMs) {
    if (clips.isEmpty) return;
    edit(() {
      var ti = 0;
      final sel = selectedClip;
      if (sel != null) {
        final st = project.trackOf(sel.id);
        if (st != null && st.kind == TrackKind.video) {
          ti = project.tracks.indexOf(st);
        }
      }
      final track = project.tracks[ti];
      var cursor = playheadMs;
      for (final c in clips) {
        if (ti == 0) {
          c.startMs = track.endMs;
        } else {
          c.startMs = _freeStart(track, c.durationMs, cursor);
          cursor = c.startMs + c.durationMs;
        }
        track.clips.add(c);
      }
      _normalize(track);
      selectedId = clips.last.id;
    });
  }

  void addText(int playheadMs) {
    edit(() {
      var ti = project.tracks.indexWhere((t) => t.kind == TrackKind.text);
      if (ti == -1) {
        project.tracks
            .add(Track(id: newId(), name: 'Texto', kind: TrackKind.text));
        ti = project.tracks.length - 1;
      }
      final track = project.tracks[ti];
      final c = MediaClip(
        id: newId(),
        type: ClipType.text,
        name: 'Texto',
        text: 'Toca para editar',
        outMs: 3000,
      );
      c.startMs = _freeStart(track, c.durationMs, playheadMs);
      track.clips.add(c);
      _normalize(track);
      selectedId = c.id;
    });
  }

  // ───────────── edición del clip ─────────────

  /// Cambio "en vivo" (sliders). Úsalo entre beginEdit() y endEdit().
  void updateClip(String id, void Function(MediaClip c) fn) {
    final c = project.findClip(id);
    if (c == null) return;
    fn(c);
    notifyListeners();
  }

  void setSpeed(String id, double s) {
    final c = project.findClip(id);
    final t = project.trackOf(id);
    if (c == null || t == null) return;
    c.speed = clampD(s, 0.1, 8.0);
    _normalize(t);
    notifyListeners();
  }

  void moveClip(String id, int newStart) {
    final c = project.findClip(id);
    final t = project.trackOf(id);
    if (c == null || t == null) return;
    if (_isMain(t)) {
      c.startMs = math.max(0, newStart);
      _normalize(t);
    } else {
      c.startMs = _freeStart(t, c.durationMs, newStart, ignoreId: id);
    }
    notifyListeners();
  }

  void moveClipToTrack(String id, int targetIndex) {
    final c = project.findClip(id);
    final from = project.trackOf(id);
    if (c == null || from == null) return;
    if (targetIndex < 0 || targetIndex >= project.tracks.length) return;
    final to = project.tracks[targetIndex];
    if (identical(from, to)) return;
    final needed = c.type == ClipType.text ? TrackKind.text : TrackKind.video;
    if (to.kind != needed) return;
    from.clips.remove(c);
    if (_isMain(to)) {
      to.clips.add(c);
    } else {
      c.startMs = _freeStart(to, c.durationMs, c.startMs);
      to.clips.add(c);
    }
    _normalize(from);
    _normalize(to);
    notifyListeners();
  }

  void trimStartBy(String id, int delta) {
    final c = project.findClip(id);
    final t = project.trackOf(id);
    if (c == null || t == null || delta == 0) return;
    var d = delta;
    d = math.min(d, math.max(0, c.durationMs - minClipMs));
    d = math.max(d, (-c.inMs / c.speed).ceil());
    if (!_isMain(t)) {
      d = math.max(d, _prevEnd(t, c) - c.startMs);
    }
    if (d == 0) return;
    c.inMs += (d * c.speed).round();
    c.startMs += d;
    _normalize(t);
    notifyListeners();
  }

  void trimEndBy(String id, int delta) {
    final c = project.findClip(id);
    final t = project.trackOf(id);
    if (c == null || t == null || delta == 0) return;
    var newDur = math.max(minClipMs, c.durationMs + delta);
    if (!_isMain(t)) {
      newDur = math.min(newDur, _nextStart(t, c) - c.startMs);
    }
    var newOut = c.inMs + (newDur * c.speed).round();
    final maxOut = c.type == ClipType.video ? c.sourceDurationMs : (1 << 30);
    newOut = math.min(newOut, maxOut);
    newOut = math.max(newOut, c.inMs + 1);
    c.outMs = newOut;
    _normalize(t);
    notifyListeners();
  }

  /// Divide el clip seleccionado en la posición de la línea blanca.
  bool splitAtPlayhead(int p) {
    final c = selectedClip;
    final t = c == null ? null : project.trackOf(c.id);
    if (c == null || t == null) return false;
    if (p <= c.startMs + 100 || p >= c.endMs - 100) return false;
    edit(() {
      final offset = ((p - c.startMs) * c.speed).round();
      final right = c.copy()
        ..id = newId()
        ..inMs = c.inMs + offset
        ..startMs = p
        ..fadeInMs = 0;
      c.outMs = c.inMs + offset;
      c.fadeOutMs = 0;
      t.clips.add(right);
      _normalize(t);
      selectedId = right.id;
    });
    return true;
  }

  void duplicateSelected() {
    final c = selectedClip;
    final t = c == null ? null : project.trackOf(c.id);
    if (c == null || t == null) return;
    edit(() {
      final copy = c.copy()..id = newId();
      if (_isMain(t)) {
        copy.startMs = c.endMs - 1;
      } else {
        copy.startMs = _freeStart(t, copy.durationMs, c.endMs);
      }
      t.clips.add(copy);
      _normalize(t);
      selectedId = copy.id;
    });
  }

  void deleteSelected() {
    final c = selectedClip;
    final t = c == null ? null : project.trackOf(c.id);
    if (c == null || t == null) return;
    edit(() {
      t.clips.remove(c);
      _normalize(t);
      selectedId = null;
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
