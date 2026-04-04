import 'package:flutter/material.dart';
import '../../../models/book_model.dart';
import '../../../models/reader_settings_model.dart';

class ReadingFooter extends StatelessWidget {
  final Book book;
  final ReaderSettings settings;
  final String currentTime;
  final String currentChapter;
  final int batteryLevel;
  final ValueNotifier<double> scrollProgressNotifier;
  final int totalChapters;
  final int currentChapterIndex;
  final List<int>? chapterLengths;

  const ReadingFooter({
    super.key,
    required this.book,
    required this.settings,
    required this.currentTime,
    required this.currentChapter,
    required this.batteryLevel,
    required this.scrollProgressNotifier,
    required this.totalChapters,
    required this.currentChapterIndex,
    this.chapterLengths,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: settings.backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Row(
              children: [
                Icon(
                  batteryLevel > 80
                      ? Icons.battery_full_rounded
                      : batteryLevel > 50
                          ? Icons.battery_5_bar_rounded
                          : batteryLevel > 20
                              ? Icons.battery_3_bar_rounded
                              : Icons.battery_alert_rounded,
                  size: 14,
                  color: settings.secondaryTextColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '$batteryLevel%',
                  style: TextStyle(
                    color: settings.secondaryTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
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
                  double overallProgress;
                  
                  if (chapterLengths != null && 
                      chapterLengths!.isNotEmpty && 
                      chapterLengths!.length == totalChapters) {
                    // Weighted progress calculation
                    double totalLength = chapterLengths!.fold(0, (sum, len) => sum + len);
                    if (totalLength > 0) {
                      double accumulatedLength = 0;
                      for (int i = 0; i < currentChapterIndex; i++) {
                        accumulatedLength += chapterLengths![i];
                      }
                      double currentChapterProgress = 
                          chapterLengths![currentChapterIndex] * scrollProgress;
                      overallProgress = (accumulatedLength + currentChapterProgress) / totalLength * 100;
                    } else {
                      overallProgress = (currentChapterIndex + scrollProgress) / totalChapters * 100;
                    }
                  } else {
                    // Fallback to equal chapters
                    overallProgress =
                        ((currentChapterIndex + scrollProgress) /
                        totalChapters *
                        100);
                  }

                  if ((currentChapterIndex == totalChapters - 1 &&
                          scrollProgress > 0.99)) {
                    overallProgress = 100.0;
                  }
                  return Text(
                    '${overallProgress.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: settings.secondaryTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                } else if (book.filePath.toLowerCase().endsWith('.pdf')) {
                  return Text(
                    '${(scrollProgress * 100).toStringAsFixed(1)}%',
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
