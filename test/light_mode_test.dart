import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomu/core/yomu_colors.dart';
import 'package:yomu/models/reader_settings_model.dart';

/// WCAG relative luminance.
double luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('palettes', () {
    for (final colors in [YomuColors.dark, YomuColors.light]) {
      final name = colors.isDark ? 'dark' : 'light';
      test('$name text reads on its backgrounds (WCAG AA)', () {
        for (final bg in [colors.background, colors.surface, colors.surfaceRaised]) {
          expect(contrast(colors.textPrimary, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(colors.textSecondary, bg), greaterThanOrEqualTo(4.5));
        }
      });

      test('$name accent stands out as an icon or progress (3:1)', () {
        expect(contrast(colors.accent, colors.surface), greaterThanOrEqualTo(3));
        expect(
          contrast(colors.accent, colors.background),
          greaterThanOrEqualTo(3),
        );
      });

      test('$name text on a green button reads', () {
        expect(contrast(colors.onAccent, colors.accent), greaterThanOrEqualTo(4.5));
      });

      test('$name tint follows the text colour', () {
        expect(colors.tint(0.1), colors.textPrimary.withValues(alpha: 0.1));
      });
    }

    test('dark is the original Yomu palette', () {
      expect(YomuColors.dark.background, const Color(0xFF0A0B0E));
      expect(YomuColors.dark.surface, const Color(0xFF16171D));
      expect(YomuColors.dark.textPrimary, const Color(0xFFFFFFFF));
      expect(YomuColors.dark.textSecondary, const Color(0xFF94A3B8));
      expect(YomuColors.dark.accent, const Color(0xFF2ECC71));
      expect(YomuColors.dark.hairline, const Color(0x0FFFFFFF));
    });
  });

  group('reader settings', () {
    test('settings saved before this update keep their page and scroll', () {
      final old = ReaderSettings.fromMap({
        'theme': ReaderTheme.white.index,
        'epubTheme': ReaderTheme.cream.index,
        'typeface': 'Lexend',
        'textSize': 20.0,
        'lineHeight': 1.8,
        'alignment': 0,
        'usePublisherDefaults': false,
        'autoScrollSpeed': 3.0,
        'lockState': 0,
      });
      expect(old.lightPageTheme, ReaderTheme.cream);
      expect(old.darkPageTheme, ReaderTheme.cream);
      expect(old.epubPageTurn, PageTurn.scroll);
      expect(old.pdfPageTurn, PageTurn.scroll);
      expect(old.typeface, 'Lexend');
    });

    test('without a chosen EPUB theme, light is white and dark is black', () {
      // `theme` alone was set to white by opening a PDF; it is no choice.
      final old = ReaderSettings.fromMap({'theme': ReaderTheme.white.index});
      expect(old.lightPageTheme, ReaderTheme.white);
      expect(old.darkPageTheme, ReaderTheme.black);
      expect(old.autoScrollSpeed, 2.0);
    });

    test('new choices survive a save and load', () {
      const settings = ReaderSettings(
        epubPageTurn: PageTurn.slide,
        pdfPageTurn: PageTurn.slide,
        lightPageTheme: ReaderTheme.cream,
        darkPageTheme: ReaderTheme.darkBlue,
      );
      final loaded = ReaderSettings.fromMap(settings.toMap());
      expect(loaded.epubPageTurn, PageTurn.slide);
      expect(loaded.pdfPageTurn, PageTurn.slide);
      expect(loaded.lightPageTheme, ReaderTheme.cream);
      expect(loaded.darkPageTheme, ReaderTheme.darkBlue);
      expect(loaded.pageThemeFor(Brightness.light), ReaderTheme.cream);
      expect(loaded.pageThemeFor(Brightness.dark), ReaderTheme.darkBlue);
      expect(loaded.pageTurnFor(isPdf: true), PageTurn.slide);
    });

    test('unknown values fall back instead of failing', () {
      final loaded = ReaderSettings.fromMap({
        'epubPageTurn': 'curl',
        'lightPageTheme': 42,
      });
      expect(loaded.epubPageTurn, PageTurn.scroll);
      expect(loaded.lightPageTheme, ReaderTheme.white);
    });
  });
}
