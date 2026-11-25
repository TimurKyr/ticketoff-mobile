import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:ticketoff_mobile/core/l10n/app_text.dart';

/// Reserves enough space for every translation at the current width and scale.
class StableLocalizedText extends StatelessWidget {
  const StableLocalizedText(
    this.textForLanguage, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final String Function(AppLanguage) textForLanguage;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final language = context.language;
    final defaults = DefaultTextStyle.of(context);
    final textStyle = (style?.inherit ?? true)
        ? defaults.style.merge(style)
        : style!;
    final scaledStyle = MediaQuery.boldTextOf(context)
        ? textStyle.merge(const TextStyle(fontWeight: FontWeight.bold))
        : textStyle;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          textAlign: textAlign,
          textWidthBasis: defaults.textWidthBasis,
          textHeightBehavior:
              defaults.textHeightBehavior ??
              DefaultTextHeightBehavior.maybeOf(context),
        );
        double width = 0;
        double height = 0;
        for (final option in AppLanguage.values) {
          painter
            ..locale = option.locale
            ..text = TextSpan(text: textForLanguage(option), style: scaledStyle)
            ..layout(maxWidth: constraints.maxWidth);
          width = math.max(width, painter.width);
          height = math.max(height, painter.height);
        }
        painter.dispose();

        return SizedBox(
          width: width.ceilToDouble(),
          height: height,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                textForLanguage(language),
                locale: language.locale,
                style: style,
                textAlign: textAlign,
              ),
            ),
          ),
        );
      },
    );
  }
}
