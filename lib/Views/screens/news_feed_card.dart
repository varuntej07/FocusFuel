import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

class NewsFeedCard extends StatefulWidget {
  final List<Map<String, dynamic>> articles;

  const NewsFeedCard({
    super.key,
    required this.articles,
  });

  @override
  State<NewsFeedCard> createState() => _NewsFeedCardState();
}

class _NewsFeedCardState extends State<NewsFeedCard> {
  final CardSwiperController controller = CardSwiperController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.articles.isEmpty) {
      return const Center(
        child: Text(
          'No articles available',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return Expanded(
      child: CardSwiper(
        controller: controller,
        cardsCount: widget.articles.length,
        onSwipe: _onSwipe,
        numberOfCardsDisplayed: 2,
        padding: const EdgeInsets.all(16.0),
        allowedSwipeDirection: const AllowedSwipeDirection.only(
          up: true,
          down: true,
        ),
        cardBuilder: (
            context, index,
            horizontalThresholdPercentage,
            verticalThresholdPercentage,
            ) =>
            NewsCard(article: widget.articles[index]),
      ),
    );
  }

  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    return true;
  }
}

class NewsCard extends StatelessWidget {
  final Map<String, dynamic> article;

  const NewsCard({
    super.key,
    required this.article,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9, // Almost full screen
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder
              Container(
                width: double.infinity,
                height: 150,
                decoration: const BoxDecoration(color: Colors.white),
                child: const Icon(Icons.image_outlined, size: 80),
              ),

              // Content section
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        article['title'] ?? 'No Title Available',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 12),

                      // Description - takes remaining space
                      Expanded(
                        child: Text(
                          article['description'] ?? 'No description available...',
                          style: const TextStyle(fontSize: 15, height: 1.4),
                          maxLines: 10,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Bottom section with source and actions - positioned at bottom
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Source info - bottom left
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFF007AFF),
                                  child: Text(
                                    (article['source'] ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  article['source'] ?? 'Unknown Source',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Action buttons - bottom right
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    // Handle bookmark
                                  },
                                  icon: const Icon(
                                    Icons.bookmark_border_rounded,
                                    size: 22,
                                    color: Color(0xFF666666),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                                IconButton(
                                  onPressed: () {
                                    // Handle audio/listen
                                  },
                                  icon: const Icon(
                                    Icons.headphones_rounded,
                                    size: 22,
                                    color: Color(0xFF666666),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}