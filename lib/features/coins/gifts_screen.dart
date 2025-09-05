import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'gifts_repo.dart';

class GiftsScreen extends StatefulWidget {
  const GiftsScreen({super.key});
  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> with SingleTickerProviderStateMixin {
  final repo = GiftsRepo();
  late Future<List<Map<String, dynamic>>> _future;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedReceiverId;
  String? _selectedReceiverName;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _future = repo.catalog();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onSearchChanged() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final results = await repo.searchUsers(query);
      if (mounted) {
        setState(() => _searchResults = results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  void _selectUser(String userId, String displayName) {
    setState(() {
      _selectedReceiverId = userId;
      _selectedReceiverName = displayName;
      _searchController.clear();
      _searchResults = [];
    });
  }

  IconData _getGiftIcon(String? giftName) {
    switch (giftName?.toLowerCase().trim()) {
      case 'rose':
        return Icons.local_florist;
      case 'heart':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'diamond':
        return Icons.diamond;
      case 'cake':
        return Icons.cake;
      case 'gift':
        return Icons.card_giftcard;
      case 'crown':
        return Icons.emoji_events; // Fallback for crown
      case 'rocket':
        return Icons.rocket_launch;
      case 'unicorn':
        return Icons.pets;
      case 'castle':
        return Icons.castle;
      case 'balloon':
        return Icons.air;
      case 'fireworks':
        return Icons.celebration;
      case 'teddy_bear':
        return Icons.toys;
      case 'rainbow':
        return Icons.wb_iridescent;
      case 'champagne':
        return Icons.wine_bar;
      case 'car':
        return Icons.directions_car;
      case 'boat':
        return Icons.directions_boat;
      case 'gem':
        return Icons.diamond;
      case 'sunflower':
        return Icons.local_florist;
      case 'treasure_chest':
        return Icons.lock; // Fallback for treasure chest
      default:
        return Icons.card_giftcard;
    }
  }

  Color _getGiftColor(String? giftName) {
    switch (giftName?.toLowerCase().trim()) {
      case 'rose':
        return Colors.redAccent;
      case 'heart':
        return Colors.pink;
      case 'star':
        return Colors.yellow;
      case 'diamond':
        return Colors.lightBlueAccent;
      case 'cake':
        return Colors.purpleAccent;
      case 'gift':
        return Colors.orange;
      case 'crown':
        return Colors.amber; // Gold-like for crown
      case 'rocket':
        return Colors.blueGrey;
      case 'unicorn':
        return Colors.pinkAccent;
      case 'castle':
        return Colors.grey;
      case 'balloon':
        return Colors.red;
      case 'fireworks':
        return Colors.orangeAccent;
      case 'teddy_bear':
        return Colors.brown;
      case 'rainbow':
        return Colors.blue; // Blue as a base for rainbow
      case 'champagne':
        return Colors.deepOrangeAccent;
      case 'car':
        return Colors.red;
      case 'boat':
        return Colors.blue;
      case 'gem':
        return Colors.teal;
      case 'sunflower':
        return Colors.yellowAccent;
      case 'treasure_chest':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    final padding = screenWidth * 0.04;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 3,
        shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search user by name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: theme.colorScheme.surface.withOpacity(0.1),
            prefixIcon: Icon(Icons.search, size: screenWidth * 0.05),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: screenWidth * 0.05),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchResults = []);
                    },
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(vertical: padding * 0.5),
          ),
          style: TextStyle(fontSize: screenWidth * 0.04),
        ),
        actions: [
          FutureBuilder<Map<String, dynamic>>(
            future: repo.getUserBalance(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const SizedBox.shrink();
              }
              final balance = snap.data!['balance'] as int;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: Row(
                  children: [
                    Icon(Icons.currency_exchange, size: screenWidth * 0.05, color: theme.colorScheme.primary),
                    SizedBox(width: padding * 0.5),
                    Text(
                      '$balance Coins',
                      style: TextStyle(fontSize: screenWidth * 0.04, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_selectedReceiverName != null)
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: Row(
                    children: [
                      Text(
                        'Sending to: $_selectedReceiverName',
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      SizedBox(width: padding),
                      IconButton(
                        icon: Icon(Icons.clear, size: screenWidth * 0.05),
                        onPressed: () => setState(() {
                          _selectedReceiverId = null;
                          _selectedReceiverName = null;
                        }),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snap.data!;
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          'No gifts available',
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      );
                    }
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: isLargeScreen
                          ? GridView.builder(
                              padding: EdgeInsets.all(padding),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: padding,
                                mainAxisSpacing: padding,
                                childAspectRatio: 2.5,
                              ),
                              itemCount: items.length,
                              itemBuilder: (context, i) {
                                return _buildGiftCard(context, items[i], screenWidth, theme, padding);
                              },
                            )
                          : ListView.separated(
                              padding: EdgeInsets.all(0.2),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => SizedBox(height: padding),
                              itemBuilder: (context, i) {
                                return _buildGiftCard(context, items[i], screenWidth, theme, padding);
                              },
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (_searchResults.isNotEmpty)
            Positioned(
              top: 0,
              left: padding,
              right: padding,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: BoxConstraints(maxHeight: screenWidth * 0.8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, i) {
                      final user = _searchResults[i];
                      final userId = user['user_id'] as String;
                      final displayName = user['display_name'] as String;
                      final avatarUrl = user['avatar_url'] as String?;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: screenWidth * 0.05,
                          backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                          child: avatarUrl == null
                              ? Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                  style: TextStyle(fontSize: screenWidth * 0.04),
                                )
                              : null,
                        ),
                        title: Text(
                          displayName,
                          style: TextStyle(fontSize: screenWidth * 0.04),
                        ),
                        onTap: () => _selectUser(userId, displayName),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGiftCard(
    BuildContext context,
    Map<String, dynamic> gift,
    double screenWidth,
    ThemeData theme,
    double padding,
  ) {
    final giftId = gift['id'] as String;
    final giftName = gift['name'] as String;
    final price = gift['price_coins'] as int;
    final iconName = gift['icon'] as String? ?? giftName;
    final avatarSize = screenWidth * 0.1;

    return Card(
      elevation: 4,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (_selectedReceiverId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select a recipient first')),
            );
            return;
          }
          try {
            await repo.sendGift(receiver: _selectedReceiverId!, giftId: giftId,giftPrice:price);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$giftName sent to $_selectedReceiverName!')),
              );
              Navigator.pop(context);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to send gift: $e')),
              );
            }
          }
        },
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
            children: [
              CircleAvatar(
                radius: avatarSize / 2,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                foregroundColor: _getGiftColor(iconName),
                child: Icon(
                  _getGiftIcon(iconName),
                  size: avatarSize * 0.5,
                ),
              ),
              SizedBox(width: padding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      giftName,
                      style: TextStyle(
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: padding * 0.5),
                    Text(
                      '$price coins',
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: padding),
              _AnimatedButton(
                onPressed: () async {
                  if (_selectedReceiverId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a recipient first')),
                    );
                    return;
                  }
                  try {
                    print(giftId);
                    await repo.sendGift(receiver: _selectedReceiverId!, giftId: giftId,giftPrice: price);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$giftName sent to $_selectedReceiverName!')),
                      );
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to send gift: $e')),
                      );
                    }
                  }
                },
                label: 'Send',
                isFilled: true,
                theme: theme,
                screenWidth: screenWidth,
                animationController: _animationController,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedButton extends StatelessWidget {
  const _AnimatedButton({
    required this.onPressed,
    required this.label,
    required this.isFilled,
    required this.theme,
    required this.screenWidth,
    required this.animationController,
  });

  final VoidCallback onPressed;
  final String label;
  final bool isFilled;
  final ThemeData theme;
  final double screenWidth;
  final AnimationController animationController;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        animationController.reset();
        animationController.forward();
      },
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.92).animate(
          CurvedAnimation(parent: animationController, curve: Curves.easeInOut),
        ),
        child: isFilled
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.04,
                      vertical: screenWidth * 0.025,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            : OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.04,
                    vertical: screenWidth * 0.025,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }
}