import 'package:flutter/material.dart';
import 'package:ticketoff_mobile/core/l10n/app_text.dart';
import 'package:ticketoff_mobile/core/theme/app_theme.dart';

class LanguageSettings extends InheritedWidget {
  const LanguageSettings({
    super.key,
    required this.onChanged,
    required super.child,
  });

  final ValueChanged<AppLanguage> onChanged;

  @override
  bool updateShouldNotify(LanguageSettings oldWidget) =>
      onChanged != oldWidget.onChanged;
}

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context
        .dependOnInheritedWidgetOfExactType<LanguageSettings>();
    if (settings == null) return const SizedBox.shrink();
    final language = context.language;
    return Semantics(
      key: const Key('language-selector'),
      label: context.t(AppText.language),
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: Center(
                child: SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: AppTheme.background,
                      shape: StadiumBorder(),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in AppLanguage.values)
                  _LanguageSegment(
                    language: option,
                    selected: option == language,
                    onPressed: () {
                      if (option != language) settings.onChanged(option);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSegment extends StatelessWidget {
  const _LanguageSegment({
    required this.language,
    required this.selected,
    required this.onPressed,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: language.label,
      child: Semantics(
        selected: selected,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: selected ? AppTheme.navy : AppTheme.muted,
            backgroundColor: selected ? Colors.white : Colors.transparent,
            shape: StadiumBorder(
              side: selected
                  ? const BorderSide(color: AppTheme.line)
                  : BorderSide.none,
            ),
            minimumSize: const Size(46, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          child: Text(language.shortLabel),
        ),
      ),
    );
  }
}
