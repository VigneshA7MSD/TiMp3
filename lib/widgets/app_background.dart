import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../models/settings.dart';
import '../services/database_service.dart';

class AppBackground extends StatelessWidget {
  final Widget content;

  const AppBackground({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final databaseService = context.read<DatabaseService>();

    return ValueListenableBuilder<Box<AppSettings>>(
      valueListenable: databaseService.getSettingsListenable(),
      child: content,
      builder: (context, _, builderChild) {
        final settings = databaseService.getSettings();
        final colorScheme = Theme.of(context).colorScheme;
        final imagePath = settings.backgroundImagePath;
        final imageOpacity = settings.backgroundImageOpacity.clamp(0.0, 1.0);
        final hasImage =
            !kIsWeb &&
            imagePath != null &&
            imagePath.isNotEmpty &&
            File(imagePath).existsSync();

        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface,
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
            if (hasImage)
              Opacity(
                opacity: imageOpacity,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface.withValues(
                      alpha: hasImage ? (0.80 - (imageOpacity * 0.30)) : 1.0,
                    ),
                    colorScheme.surfaceContainerHighest.withValues(
                      alpha: hasImage ? (0.56 - (imageOpacity * 0.22)) : 0.3,
                    ),
                  ],
                ),
              ),
            ),
            builderChild ?? content,
          ],
        );
      },
    );
  }
}
