import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/constants.dart';

class GoogleImageSearchScreen extends StatefulWidget {
  final String query;

  const GoogleImageSearchScreen({super.key, required this.query});

  @override
  State<GoogleImageSearchScreen> createState() =>
      _GoogleImageSearchScreenState();
}

class _GoogleImageSearchScreenState extends State<GoogleImageSearchScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    final String searchUrl =
        'https://www.google.com/search?tbm=isch&q=${Uri.encodeComponent("${widget.query} book cover")}';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (progress == 100) {
              _injectSelectionScript();
            }
          },
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _injectSelectionScript();
            // Inject again after a short delay to handle potential hydration/SPA updates
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _injectSelectionScript();
            });
          },
          onUrlChange: (UrlChange change) {
            _injectSelectionScript();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'ImageSelectionChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final String imageUrl = message.message;
          if (imageUrl.isNotEmpty) {
            _showConfirmationDialog(imageUrl);
          }
        },
      )
      ..loadRequest(Uri.parse(searchUrl));
  }

  void _injectSelectionScript() {
    // This script uses a capture-phase listener on the document level.
    // It traverses up from the click target to find an <img> element.
    // This handles cases where clicks target overlaying divs or detail panels.
    const String script = """
      (function() {
        if (window.yomuInjected) return;
        window.yomuInjected = true;

        document.addEventListener('click', function(e) {
          var target = e.target;

          // Traverse up to find an IMG tag if we didn't click it directly
          while (target && target.tagName !== 'IMG' && target !== document.body) {
            target = target.parentElement;
          }

          if (target && target.tagName === 'IMG') {
            var src = target.src;
            // On Google Images, sometimes the src is a data URI or a low-res thumb.
            // We prioritze the 'src' but we can also check properties like 'data-src'.
            if (src && src.startsWith('http')) {
               ImageSelectionChannel.postMessage(src);
               e.preventDefault();
               e.stopPropagation();
            }
          }
        }, true);
      })();
    """;
    _controller.runJavaScript(script);
  }

  void _showConfirmationDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use this image?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, size: 50),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Would you like to use this as the book cover?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, url); // Return URL to previous screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: YomuConstants.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Web Search: ${widget.query}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
