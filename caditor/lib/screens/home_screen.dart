import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/project_storage.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/gradient_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasSaved = false;

  @override
  void initState() {
    super.initState();
    _refreshSaved();
  }

  void _refreshSaved() {
    ProjectStorage.exists().then((v) {
      if (mounted) setState(() => _hasSaved = v);
    });
  }

  Future<void> _open({required bool fresh}) async {
    final ed = ref.read(editorProvider);
    final engine = ref.read(playbackProvider);

    if (fresh && _hasSaved) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kCard,
          title: const Text('¿Empezar un proyecto nuevo?'),
          content: const Text(
            'Tu proyecto guardado se reemplazará por uno vacío.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Empezar nuevo'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    if (fresh) {
      ed.newProject();
    } else {
      final loaded = await ed.loadSaved();
      if (!loaded) ed.newProject();
    }
    engine.seek(0);

    if (!mounted) return;
    await Navigator.of(context).pushNamed('/editor');
    _refreshSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1033), kBg],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      gradient: kBrandGradient,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: kPurple.withAlpha(130),
                          blurRadius: 44,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.movie_creation_rounded,
                      size: 58,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                Center(
                  child: ShaderMask(
                    shaderCallback: (rect) => kBrandGradient.createShader(rect),
                    child: const Text(
                      'Caditor',
                      style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'El editor de video en español.\nCorta, mezcla y crea sin límites.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMuted, fontSize: 16, height: 1.4),
                ),
                const Spacer(),
                GradientButton(
                  label: 'Nuevo proyecto',
                  icon: Icons.add_rounded,
                  onPressed: () => _open(fresh: true),
                ),
                if (_hasSaved) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _open(fresh: false),
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Continuar proyecto'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
