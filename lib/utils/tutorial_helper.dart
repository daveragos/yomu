import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TutorialHelper {
  /// Shows a TutorialCoachMark with standard styling.
  static void showTutorial({
    required BuildContext context,
    required List<TargetFocus> targets,
    required VoidCallback onFinish,
    required bool Function() onSkip,
    Color colorShadow = Colors.black87,
    FutureOr<void> Function(TargetFocus)? onClickTarget,
  }) {
    TutorialCoachMark(
      targets: targets,
      colorShadow: colorShadow,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onClickTarget: onClickTarget,
      onFinish: onFinish,
      onSkip: onSkip,
    ).show(context: context);
  }

  /// Creates a standard TargetFocus with a title and description.
  static TargetFocus createTarget({
    required String identify,
    required GlobalKey keyTarget,
    required String title,
    required String description,
    AlignmentGeometry alignSkip = Alignment.topRight,
    ContentAlign contentAlign = ContentAlign.bottom,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
    TextAlign textAlign = TextAlign.left,
  }) {
    return TargetFocus(
      identify: identify,
      keyTarget: keyTarget,
      alignSkip: alignSkip,
      contents: [
        TargetContent(
          align: contentAlign,
          builder: (context, controller) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: crossAxisAlignment,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 24,
                  ),
                  textAlign: textAlign,
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: textAlign,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
