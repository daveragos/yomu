import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// A bottom sheet that shows themed quote card styles for sharing selected text.
class ShareQuoteSheet extends StatefulWidget {
  final String text;
  final String? bookTitle;
  final String? bookAuthor;

  const ShareQuoteSheet({
    super.key,
    required this.text,
    this.bookTitle,
    this.bookAuthor,
  });

  static Future<void> show(
    BuildContext context, {
    required String text,
    String? bookTitle,
    String? bookAuthor,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareQuoteSheet(
        text: text,
        bookTitle: bookTitle,
        bookAuthor: bookAuthor,
      ),
    );
  }

  @override
  State<ShareQuoteSheet> createState() => _ShareQuoteSheetState();
}

class _ShareQuoteSheetState extends State<ShareQuoteSheet> {
  int _selectedStyle = 0;
  int _selectedLayout = 0; // 0 = classic, 1 = bold
  bool _isSharing = false;

  final List<_QuoteStyle> _styles = const [
    _QuoteStyle(
      name: 'Dark',
      background: Color(0xFF0A0B0E),
      textColor: Color(0xFFFFFFFF),
      accentColor: Color(0xFF2ECC71),
      metaColor: Color(0xFF94A3B8),
    ),
    _QuoteStyle(
      name: 'Emerald',
      background: Color(0xFF064E3B),
      textColor: Color(0xFFECFDF5),
      accentColor: Color(0xFF6EE7B7),
      metaColor: Color(0xFFA7F3D0),
    ),
    _QuoteStyle(
      name: 'Warm',
      background: Color(0xFF1C1917),
      textColor: Color(0xFFFAF5F0),
      accentColor: Color(0xFFF59E0B),
      metaColor: Color(0xFFA8A29E),
    ),
    _QuoteStyle(
      name: 'Ocean',
      background: Color(0xFF0C1929),
      textColor: Color(0xFFE2E8F0),
      accentColor: Color(0xFF38BDF8),
      metaColor: Color(0xFF7DD3FC),
    ),
    _QuoteStyle(
      name: 'Light',
      background: Color(0xFFF8FAFC),
      textColor: Color(0xFF0F172A),
      accentColor: Color(0xFF2ECC71),
      metaColor: Color(0xFF64748B),
    ),
  ];

  final List<GlobalKey> _cardKeys = [];

  @override
  void initState() {
    super.initState();
    _cardKeys.addAll(List.generate(_styles.length, (_) => GlobalKey()));
  }

  Future<void> _shareCard() async {
    setState(() => _isSharing = true);
    try {
      final boundary =
          _cardKeys[_selectedStyle].currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/yomu_quote.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final meta = [
        if (widget.bookTitle != null) widget.bookTitle!,
        if (widget.bookAuthor != null) widget.bookAuthor!,
      ].join(' · ');
      final shareText = meta.isNotEmpty
          ? '"${widget.text}"\n\n— $meta'
          : '"${widget.text}"';

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: shareText,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF16171D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.format_quote, color: Color(0xFF2ECC71), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Share Quote',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Card preview (selected style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _selectedLayout == 0
                  ? _buildQuoteCard(
                      _styles[_selectedStyle],
                      _cardKeys[_selectedStyle],
                    )
                  : _buildBoldQuoteCard(
                      _styles[_selectedStyle],
                      _cardKeys[_selectedStyle],
                    ),
            ),
            const SizedBox(height: 16),

            // Layout toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildLayoutOption(0, Icons.format_quote_rounded, 'Classic'),
                  const SizedBox(width: 10),
                  _buildLayoutOption(1, Icons.format_bold_rounded, 'Bold'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Style selector
            SizedBox(
              height: 72,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _styles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final style = _styles[index];
                  final isSelected = index == _selectedStyle;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStyle = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72,
                      decoration: BoxDecoration(
                        color: style.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? style.accentColor
                              : Colors.white10,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.format_quote,
                            color: style.accentColor,
                            size: 18,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            style.name,
                            style: TextStyle(
                              color: style.textColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Share button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSharing ? null : _shareCard,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.share, size: 20),
                  label: Text(_isSharing ? 'Preparing...' : 'Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteCard(_QuoteStyle style, GlobalKey key) {
    final hasMeta = widget.bookTitle != null || widget.bookAuthor != null;
    final metaParts = [
      if (widget.bookTitle != null) widget.bookTitle!,
      if (widget.bookAuthor != null) widget.bookAuthor!,
    ];

    return RepaintBoundary(
      key: key,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: style.background),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              // Opening quote mark
              Icon(Icons.format_quote, color: style.accentColor, size: 32),
              const SizedBox(height: 16),

              // Quote text
              Flexible(
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: _maxLines,
                  style: TextStyle(
                    color: style.textColor,
                    fontSize: _quoteFontSize,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Book name · Author (above the line)
              if (hasMeta) ...[
                Text(
                  metaParts.join(' · '),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: style.metaColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
              ],

              // Divider line
              Container(
                width: 90,
                height: 1,
                decoration: BoxDecoration(
                  color: style.metaColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 16),

              // App branding (below the line)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: Image.asset(
                        'assets/app_icon.png',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Yomu',
                    style: TextStyle(
                      color: style.metaColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoldQuoteCard(_QuoteStyle style, GlobalKey key) {
    final hasMeta = widget.bookTitle != null || widget.bookAuthor != null;
    final metaParts = [
      if (widget.bookTitle != null) widget.bookTitle!,
      if (widget.bookAuthor != null) widget.bookAuthor!,
    ];

    return RepaintBoundary(
      key: key,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: style.background),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              // Opening quote + line above
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '\u201C',
                    style: TextStyle(
                      color: style.accentColor,
                      fontSize: 80,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -14),
                      child: Container(
                        height: 5,
                        color: style.accentColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Quote text — bold, uppercase
              Flexible(
                child: Text(
                  widget.text.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: _maxLines,
                  style: TextStyle(
                    color: style.textColor,
                    fontSize: _quoteFontSize - 2,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Line below + closing quote
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -14),
                      child: Container(
                        height: 5,
                        color: style.accentColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '\u201D',
                    style: TextStyle(
                      color: style.accentColor,
                      fontSize: 80,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bottom row: book info + branding
              Row(
                children: [
                  if (hasMeta)
                    Expanded(
                      child: Text(
                        metaParts.join(' \u00b7 '),
                        style: TextStyle(
                          color: style.metaColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (!hasMeta) const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: Image.asset(
                        'assets/app_icon.png',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Yomu',
                    style: TextStyle(
                      color: style.metaColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutOption(int index, IconData icon, String label) {
    final isSelected = _selectedLayout == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedLayout = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2ECC71).withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF2ECC71) : Colors.white10,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? const Color(0xFF2ECC71)
                    : const Color(0xFF94A3B8),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF2ECC71)
                      : const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _quoteFontSize {
    final len = widget.text.length;
    if (len < 80) return 20;
    if (len < 200) return 17;
    if (len < 400) return 15;
    if (len < 600) return 13;
    return 11;
  }

  int get _maxLines {
    final len = widget.text.length;
    if (len < 80) return 6;
    if (len < 200) return 8;
    if (len < 400) return 10;
    return 14;
  }
}

class _QuoteStyle {
  final String name;
  final Color background;
  final Color textColor;
  final Color accentColor;
  final Color metaColor;

  const _QuoteStyle({
    required this.name,
    required this.background,
    required this.textColor,
    required this.accentColor,
    required this.metaColor,
  });
}
