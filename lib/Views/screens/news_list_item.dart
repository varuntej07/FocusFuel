import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NewsListItem extends StatelessWidget {
  final Map<String, dynamic> article;
  final VoidCallback? onTap;
  final VoidCallback? onBookmark;
  final VoidCallback? onListen;
  final bool isBookmarked;

  const NewsListItem({
    super.key,
    required this.article,
    this.onTap,
    this.onBookmark,
    this.onListen,
    this.isBookmarked = false,
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
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(2, 4),
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
            height: 1.3,
          ),
          maxLines: 4,
        ),

        const SizedBox(height: 8),

        Text(
          article['description'] ?? 'No description available...',
          style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color),
          maxLines: 5,
        ),

        const SizedBox(height: 12),

        // Footer: Source and actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: _buildSourceInfo(context)),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                    icon: ColorFiltered(
                        colorFilter: ColorFilter.mode(Theme.of(context).iconTheme.color!, BlendMode.srcIn),
                        child: Image.asset(isBookmarked ? 'lib/Assets/icons/saved.png' : 'lib/Assets/icons/save.png', width: 20, height: 18)
                    ),
                    onPressed: onBookmark,
                ),
                _buildActionButton(
                    icon: ColorFiltered(
                        colorFilter: ColorFilter.mode(Theme.of(context).iconTheme.color!, BlendMode.srcIn),
                        child: Image.asset('lib/Assets/icons/dark_headphone.png', width: 20, height: 18)
                    ),
                    onPressed: onListen
                )
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceInfo(context) {
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
            style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.w600),
          ),
        ),

        const SizedBox(width: 4),

        Text(
          source,
          style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodyMedium?.color, fontWeight: FontWeight.w500),
        ),

        const SizedBox(width: 6),

        Text(publishedDate, style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodyMedium?.color))
      ],
    );
  }

  // custom icon button widget that is responsible for displaying icons in the news card
  Widget _buildActionButton({required icon, VoidCallback? onPressed}) {
    return IconButton(
      padding: const EdgeInsets.all(8),
      onPressed: onPressed,
      icon: icon,
    );
  }
}

String formatPublishedDateWithIntl(String publishedDateString) {
  // Handle empty or null strings
  if (publishedDateString.isEmpty || publishedDateString.toLowerCase() == 'unknown') {
    return 'Today';
  }

  try {
    DateTime? dateTime;

    // Try parsing with multiple strategies
    try {
      // Try direct DateTime.parse (handles ISO 8601 like your data)
      dateTime = DateTime.parse(publishedDateString);
    } catch (e1) {
      try {
        // Handle RFC 2822 format
        final rfc2822Format = DateFormat('EEE, dd MMM yyyy HH:mm:ss \'GMT\'', 'en_US');
        dateTime = rfc2822Format.parseUtc(publishedDateString);
      } catch (e2) {
        try {
          // Handle other common formats
          final commonFormats = [
            DateFormat('yyyy-MM-dd HH:mm:ss'),
            DateFormat('yyyy-MM-ddTHH:mm:ss'),
            DateFormat('dd/MM/yyyy HH:mm:ss'),
            DateFormat('MMM dd, yyyy HH:mm:ss'),
            DateFormat('yyyy-MM-dd'),
          ];

          for (final format in commonFormats) {
            try {
              dateTime = format.parse(publishedDateString);
              break;
            } catch (_) {
              continue;
            }
          }
        } catch (e3) {
          // All parsing failed, use current time
          dateTime = DateTime.now();
        }
      }
    }

    // Ensure we have a valid dateTime
    dateTime ??= DateTime.now();

    // Smart formatting based on time difference
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    // Handle future dates (sometimes happens with timezone issues)
    if (diff.isNegative) {
      return 'Just now';
    }

    // Format based on recency
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else if (diff.inDays < 30) {
      return DateFormat('d MMM').format(dateTime);
    } else {
      return DateFormat('d MMM yyyy').format(dateTime);
    }

  } catch (error, stackTrace) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace, information: ['Error while formatting published date of a news article in news_list_item.dart']);
    return 'Recent';
  }
}