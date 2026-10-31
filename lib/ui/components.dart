import 'package:flutter/material.dart';

class FantaNavigation extends StatelessWidget {
  const FantaNavigation({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.available,
  });
  final int selected;
  final Set<String> available;
  final ValueChanged<int> onSelected;
  static const keys = ['dashboard', 'rose', 'calendario', 'classifica', 'menu'];
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selected,
    onDestinationSelected: onSelected,
    destinations: [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home_rounded),
        label: 'Dashboard',
        enabled: available.contains('dashboard'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.shield_outlined),
        selectedIcon: const Icon(Icons.shield_rounded),
        label: 'Rose',
        enabled: available.contains('rose'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.calendar_month_outlined),
        selectedIcon: const Icon(Icons.calendar_month_rounded),
        label: 'Calendario',
        enabled: available.contains('calendario'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.emoji_events_outlined),
        selectedIcon: const Icon(Icons.emoji_events_rounded),
        label: 'Classifica',
        enabled: available.contains('classifica'),
      ),
      const NavigationDestination(
        icon: Icon(Icons.menu_rounded),
        label: 'Menu',
      ),
    ],
  );
}

class LoadFailurePanel extends StatelessWidget {
  const LoadFailurePanel({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onHome,
    this.onAccess,
    this.title = 'Riprendiamo da qui',
  });
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onHome;
  final VoidCallback? onAccess;
  final String title;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 54,
              color: Color(0xff285bd7),
            ),
            const SizedBox(height: 20),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Riprova'),
            ),
            if (onAccess != null)
              TextButton(
                onPressed: onAccess,
                child: const Text('Accesso dalla home ufficiale'),
              ),
            TextButton(
              onPressed: onHome,
              child: const Text('Vai alla pagina iniziale'),
            ),
          ],
        ),
      ),
    ),
  );
}
