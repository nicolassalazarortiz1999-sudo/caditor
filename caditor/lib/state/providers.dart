import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_controller.dart';
import 'playback_engine.dart';

final editorProvider =
    ChangeNotifierProvider<EditorController>((ref) => EditorController());

final playbackProvider = ChangeNotifierProvider<PlaybackEngine>(
    (ref) => PlaybackEngine(ref.read(editorProvider)));

/// Píxeles por milisegundo de la línea de tiempo (zoom).
final timelineZoomProvider = StateProvider<double>((ref) => 0.08);
