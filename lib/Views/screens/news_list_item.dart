import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NewsListItem extends StatelessWidget {
  final Map<String, dynamic> article;
  final VoidCallback? onTap;
  final VoidCallback? onBookmark;
  final VoidCallback? onListen;

  const NewsListItem({
    super.key,
    required this.article,
    this.onTap,
    this.onBookmark,
    this.onListen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Image
                _buildImageSection(),

                const SizedBox(width: 12),

                // Right: Content
                Flexible(child: _buildContentSection(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final imageUrl = article['image_url'] as String?;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 100,
        height: 100,
        child: imageUrl != null && imageUrl.isNotEmpty ?
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildImagePlaceholder();
          },
          errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
        )
            : _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Icon(Icons.image_outlined, size: 32, color: Colors.grey[400]);
  }

  Widget _buildContentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          article['title'] ?? 'No Title Available',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            height: 1.3,
          ),
          maxLines: 4,
        ),

        const SizedBox(height: 8),

        Text(
          article['description'] ?? 'No description available...',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          maxLines: 5,
        ),

        const SizedBox(height: 12),

        // Footer: Source and actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: _buildSourceInfo()),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(icon: Image.asset('lib/Assets/icons/save.png', width: 20, height: 18), onPressed: onBookmark),
                _buildActionButton(icon: Image.asset('lib/Assets/icons/dark_headphone.png', width: 20, height: 18), onPressed: onListen)
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceInfo() {
    final source = article['source_id'] ?? article['source'] ?? 'Unknown';
    final time = article['pubDate'] ?? 'Unknown';
    final publishedDate = formatPublishedDateWithIntl(time);

    return Row(
      children: [
        // Source avatar
        CircleAvatar(
          radius: 8,
          backgroundColor: Colors.deepOrangeAccent,
          child: Text(
            source[0].toUpperCase(),
            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),

        const SizedBox(width: 4),

        Text(
          source,
          style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w500),
        ),

        const SizedBox(width: 6),

        Text(publishedDate, style: TextStyle(fontSize: 10, color: Colors.grey[600]))
      ],
    );
  }

  Widget _buildActionButton({required icon, VoidCallback? onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: icon,
      ),
    );
  }
}

String formatPublishedDateWithIntl(String publishedDateString) {
  try {
    // intl's DateFormat can parse it directly if you specify the locale
    // that understands English month/day names, or be very explicit.
    // We can manually parse or use a known pattern.

    DateTime dateTime;
    try {
      dateTime = DateTime.parse(publishedDateString);
    } catch (e) {
      // Fallback to more explicit parsing if DateTime.parse fails for this specific GMT format.
      final inputFormat = DateFormat('EEE, dd MMM yyyy HH:mm:ss \'GMT\'', 'en_US');
      // We add 'GMT' as a literal string to match if it's always there.
      dateTime = inputFormat.parseUtc(publishedDateString); // Parse as UTC
    }


    final outputFormat = DateFormat('d MMM', 'en_US'); // 'en_US' for English month names
    return outputFormat.format(dateTime);
  } catch (e) {
    print('Error formatting date with intl: $e');
    return 'Invalid Date';
  }
}