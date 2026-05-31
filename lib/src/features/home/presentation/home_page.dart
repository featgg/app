import 'package:featgg/src/core/core.dart'; // AppSpacing
import 'package:flutter/material.dart';

/// Root screen of the app, reached through the central router at '/'.
///
/// Static identity surface for the M1 vertical slice: it renders the app
/// wordmark from the active theme and carries no controller or business logic.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Feat.gg',
            style: textTheme.displayLarge?.copyWith(color: colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
