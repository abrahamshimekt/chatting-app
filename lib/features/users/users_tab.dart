import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// Assuming these are defined elsewhere
import '../users/users_repo.dart';
import '../chats/chat_repo.dart';

class PeopleTab extends StatefulWidget {
  const PeopleTab({super.key});

  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _subcityCtrl = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _countryCtrl.dispose();
    _regionCtrl.dispose();
    _cityCtrl.dispose();
    _subcityCtrl.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool _matchContains(String? value, String input) {
    if (input.isEmpty) return true;
    final v = (value ?? '').toLowerCase().trim();
    return v.contains(input.toLowerCase().trim());
  }

  List<Person> _applyFilters(List<Person> people) {
    final q = _searchCtrl.text.trim();
    final fc = _countryCtrl.text.trim();
    final fr = _regionCtrl.text.trim();
    final fci = _cityCtrl.text.trim();
    final fs = _subcityCtrl.text.trim();

    return people.where((p) {
      final nameOk = _matchContains(p.displayName, q);
      final countryOk = _matchContains(p.country, fc);
      final regionOk = _matchContains(p.region, fr);
      final cityOk = _matchContains(p.city, fci);
      final subcityOk = _matchContains(p.subcity, fs);
      return nameOk && countryOk && regionOk && cityOk && subcityOk;
    }).toList();
  }

  void _showFilterPopup(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter by Location',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        fontSize: screenWidth * 0.05,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: screenWidth * 0.04),
                _buildFilterTextField(theme, _countryCtrl, 'Country', screenWidth),
                SizedBox(height: screenWidth * 0.03),
                _buildFilterTextField(theme, _regionCtrl, 'Region', screenWidth),
                SizedBox(height: screenWidth * 0.03),
                _buildFilterTextField(theme, _cityCtrl, 'City', screenWidth),
                SizedBox(height: screenWidth * 0.03),
                _buildFilterTextField(theme, _subcityCtrl, 'Subcity', screenWidth),
                SizedBox(height: screenWidth * 0.04),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        _countryCtrl.clear();
                        _regionCtrl.clear();
                        _cityCtrl.clear();
                        _subcityCtrl.clear();
                        setState(() {});
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Clear Filters',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: screenWidth * 0.04,
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.04,
                          vertical: screenWidth * 0.03,
                        ),
                      ),
                      child: Text(
                        'Apply',
                        style: TextStyle(fontSize: screenWidth * 0.04),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getGenderIcon(String? gender) {
    switch (gender?.toLowerCase().trim()) {
      case 'male':
        return Icons.male;
      case 'female':
        return Icons.female;
      default:
        return Icons.person;
    }
  }

  String _getGenderLabel(String? gender) {
    switch (gender?.toLowerCase().trim()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = PeopleRepo();
    final chatRepo = ChatRepo();
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 3,
        shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.filter_list, color: theme.colorScheme.onSurface),
                if (_countryCtrl.text.isNotEmpty ||
                    _regionCtrl.text.isNotEmpty ||
                    _cityCtrl.text.isNotEmpty ||
                    _subcityCtrl.text.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: screenWidth * 0.02,
                      height: screenWidth * 0.02,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Filter by Location',
            onPressed: () {
              HapticFeedback.lightImpact();
              _showFilterPopup(context);
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final avatarHeight = constraints.maxHeight * 0.6;
          final padding = screenWidth * 0.04;
          final isLargeScreen = screenWidth > 600;

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(padding, padding, padding, padding / 2),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurface),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: theme.colorScheme.onSurface),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    labelText: 'Search by name',
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: screenWidth * 0.04,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface.withOpacity(0.05),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: padding,
                      vertical: padding * 0.5,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
              Expanded(
                child: StreamBuilder<List<Person>>(
                  stream: repo.oppositeGenderPeople(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Error loading people. Please try again.',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: screenWidth * 0.045,
                          ),
                        ),
                      );
                    }
                    final all = snap.data ?? const <Person>[];
                    final people = _applyFilters(all);

                    if (people.isEmpty) {
                      return Center(
                        child: Text(
                          'No people to show with current filters.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontSize: screenWidth * 0.045,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.all(padding),
                      itemCount: people.length,
                      separatorBuilder: (_, __) => SizedBox(height: padding),
                      itemBuilder: (context, i) {
                        final p = people[i];

                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: Semantics(
                            label: 'Profile for ${p.displayName}',
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                context.pushNamed(
                                  'profileView',
                                  pathParameters: {'userId': p.userId},
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Card(
                                elevation: 6,
                                shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  children: [
                                    // Full-width avatar
                                    (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                                        ? CachedNetworkImage(
                                            imageUrl: p.avatarUrl!,
                                            width: double.infinity,
                                            height: avatarHeight,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              width: double.infinity,
                                              height: avatarHeight,
                                              color: theme.colorScheme.surface,
                                              child: const Center(
                                                child: CircularProgressIndicator(),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              width: double.infinity,
                                              height: avatarHeight,
                                              color: theme.colorScheme.surface,
                                              child: Icon(
                                                Icons.error,
                                                color: theme.colorScheme.error,
                                                size: screenWidth * 0.08,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: double.infinity,
                                            height: avatarHeight,
                                            color: theme.colorScheme.primary,
                                            child: Center(
                                              child: Text(
                                                p.displayName.isNotEmpty
                                                    ? p.displayName[0].toUpperCase()
                                                    : 'U',
                                                style: theme.textTheme.titleLarge?.copyWith(
                                                  color: theme.colorScheme.onPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: screenWidth * 0.08,
                                                ),
                                              ),
                                            ),
                                          ),
                                    // Overlay with text and buttons
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: EdgeInsets.all(padding),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              theme.brightness == Brightness.dark
                                                  ? Colors.black.withOpacity(0.1)
                                                  : Colors.white.withOpacity(0.1),
                                              theme.brightness == Brightness.dark
                                                  ? Colors.black.withOpacity(0.8)
                                                  : Colors.white.withOpacity(0.8),
                                            ],
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Gender icon and name row
                                            Row(
                                              children: [
                                                Semantics(
                                                  label: _getGenderLabel(p.gender),
                                                  child: Icon(
                                                    _getGenderIcon(p.gender),
                                                    size: isLargeScreen ? 22 : 18,
                                                    color: theme.brightness == Brightness.dark
                                                        ? Colors.white.withOpacity(0.9)
                                                        : Colors.black.withOpacity(0.9),
                                                  ),
                                                ),
                                                SizedBox(width: padding * 0.5),
                                                Expanded(
                                                  child: Text(
                                                    p.displayName,
                                                    style: (isLargeScreen
                                                            ? theme.textTheme.titleLarge
                                                            : theme.textTheme.titleMedium)
                                                        ?.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                      color: theme.brightness == Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black,
                                                      fontSize: screenWidth * 0.05,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: padding * 0.5),
                                            // Location row with icon
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on,
                                                  size: isLargeScreen ? 18 : 16,
                                                  color: theme.brightness == Brightness.dark
                                                      ? Colors.white.withOpacity(0.9)
                                                      : Colors.black.withOpacity(0.9),
                                                ),
                                                SizedBox(width: padding * 0.5),
                                                Expanded(
                                                  child: Text(
                                                    [
                                                      if ([
                                                        p.subcity,
                                                        p.city,
                                                        p.region,
                                                        p.country,
                                                      ].where((e) => (e ?? '').trim().isNotEmpty).isNotEmpty)
                                                        [p.subcity, p.city, p.region, p.country]
                                                            .where((e) => (e ?? '').trim().isNotEmpty)
                                                            .join(', '),
                                                    ].join(''),
                                                    style: (isLargeScreen
                                                            ? theme.textTheme.bodyMedium
                                                            : theme.textTheme.bodySmall)
                                                        ?.copyWith(
                                                      color: theme.brightness == Brightness.dark
                                                          ? Colors.white.withOpacity(0.9)
                                                          : Colors.black.withOpacity(0.9),
                                                      fontSize: screenWidth * 0.035,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: padding * 0.75),
                                            // Buttons row
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                _buildAnimatedButton(
                                                  icon: Icons.chat_bubble_outline,
                                                  tooltip: 'Chat',
                                                  onPressed: () async {
                                                    HapticFeedback.lightImpact();
                                                    final convId = await chatRepo.upsertDirectConversation(p.userId);
                                                    if (context.mounted) {
                                                      context.push('/chat/$convId');
                                                    }
                                                  },
                                                  theme: theme,
                                                  size: isLargeScreen ? 50.0 : 42.0,
                                                  screenWidth: screenWidth,
                                                ),
                                                SizedBox(width: padding * 0.5),
                                                _buildAnimatedButton(
                                                  icon: Icons.videocam_outlined,
                                                  tooltip: 'Video Call',
                                                  onPressed: () {
                                                    HapticFeedback.lightImpact();
                                                    context.push('/call/${p.userId}');
                                                  },
                                                  theme: theme,
                                                  size: isLargeScreen ? 50.0 : 42.0,
                                                  screenWidth: screenWidth,
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
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterTextField(
    ThemeData theme,
    TextEditingController controller,
    String label,
    double screenWidth,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
          fontSize: screenWidth * 0.04,
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: theme.colorScheme.onSurface),
                onPressed: () {
                  controller.clear();
                  setState(() {});
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface.withOpacity(0.05),
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenWidth * 0.03,
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildAnimatedButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required ThemeData theme,
    required double size,
    required double screenWidth,
  }) {
    return GestureDetector(
      onTapDown: (_) {
        _animationController.reset();
        _animationController.forward();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: theme.colorScheme.primary,
              size: size * 0.5,
            ),
            tooltip: tooltip,
            onPressed: onPressed,
            constraints: BoxConstraints.tight(Size(size, size)),
            padding: EdgeInsets.all(size * 0.2),
          ),
        ),
      ),
    );
  }
}