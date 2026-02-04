import 'package:flutter/material.dart';
import '../../../models/book_model.dart';
import '../../../models/reader_settings_model.dart';

class ReadingFooter extends StatelessWidget {
  final Book book;
  final ReaderSettings settings;
  final String currentTime;
  final String currentChapter;
  final ValueNotifier<double> scrollProgressNotifier;
  final int totalChapters;
  final int currentChapterIndex;

  const ReadingFooter({
    super.key,
    required this.book,
    required this.settings,
    required this.currentTime,
    required this.currentChapter,
    required this.scrollProgressNotifier,
    required this.totalChapters,
    required this.currentChapterIndex,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Row(
              children: [
                Icon(
                  Icons.battery_6_bar_rounded,
                  size: 14,
                  color: settings.secondaryTextColor,
                ),
                const SizedBox(width: 4),
                Text(
                  currentTime,
                  style: TextStyle(
                    color: settings.secondaryTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Expanded(
              flex: 4,
              child: Text(
                currentChapter,
                style: TextStyle(
                  color: settings.secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            ValueListenableBuilder<double>(
              valueListenable: scrollProgressNotifier,
              builder: (context, scrollProgress, _) {
                if (book.filePath.toLowerCase().endsWith('.epub') &&
                    totalChapters > 0) {
                  final overallProgress =
                      ((currentChapterIndex + scrollProgress) /
                      totalChapters *
                      100);
                  return Text(
                    '${overallProgress.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: settings.secondaryTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }
                return Text(
                  '${(book.progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: settings.secondaryTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
