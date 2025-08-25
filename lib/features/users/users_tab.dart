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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFilterTextField(theme, _countryCtrl, 'Country'),
                const SizedBox(height: 12),
                _buildFilterTextField(theme, _regionCtrl, 'Region'),
                const SizedBox(height: 12),
                _buildFilterTextField(theme, _cityCtrl, 'City'),
                const SizedBox(height: 12),
                _buildFilterTextField(theme, _subcityCtrl, 'Subcity'),
                const SizedBox(height: 16),
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
                      child: const Text('Clear Filters'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Apply'),
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

  @override
  Widget build(BuildContext context) {
    final repo = PeopleRepo();
    final chatRepo = ChatRepo();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_countryCtrl.text.isNotEmpty ||
                    _regionCtrl.text.isNotEmpty ||
                    _cityCtrl.text.isNotEmpty ||
                    _subcityCtrl.text.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                labelText: 'Search by name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface.withOpacity(0.1),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const Divider(height: 0, thickness: 1),
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
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.error,
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
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: people.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final p = people[i];

                    final avatar =
                        (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                        ? CircleAvatar(
                            radius: 26,
                            backgroundImage: CachedNetworkImageProvider(
                              p.avatarUrl!,
                            ),
                            backgroundColor: theme.colorScheme.surface,
                            onBackgroundImageError: (_, __) =>
                                const Icon(Icons.error),
                          )
                        : CircleAvatar(
                            radius: 26,
                            backgroundColor: theme.colorScheme.primary,
                            child: Text(
                              p.displayName.isNotEmpty
                                  ? p.displayName[0].toUpperCase()
                                  : 'U',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          );

                    final locParts = [p.subcity, p.city, p.region, p.country]
                        .where((e) => (e ?? '').trim().isNotEmpty)
                        .cast<String>()
                        .toList();
                    final subtitle = [
                      p.gender.toUpperCase(),
                      if (locParts.isNotEmpty) ' • ${locParts.join(', ')}',
                    ].join('');

                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: avatar,
                          title: Text(
                            p.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
                          ),
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              IconButton(
                                tooltip: 'Chat',
                                icon: Icon(
                                  Icons.chat_bubble_outline,
                                  color: theme.colorScheme.primary,
                                ),
                                onPressed: () async {
                                  HapticFeedback.lightImpact();
                                  final convId = await chatRepo
                                      .upsertDirectConversation(p.userId);
                                  if (context.mounted) {
                                    // GoRouter path: /chat/:convId
                                    context.push(
                                      '/chat/$convId',
                                    ); // ⬅️ use GoRouter
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: 'Video Call',
                                icon: Icon(
                                  Icons.videocam_outlined,
                                  color: theme.colorScheme.primary,
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  // GoRouter path: /call/:peer
                                  context.push(
                                    '/call/${p.userId}',
                                  ); // ⬅️ use GoRouter
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.pushNamed(
                              'profileView',
                              pathParameters: {'userId': p.userId},
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTextField(
    ThemeData theme,
    TextEditingController controller,
    String label,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  setState(() {});
                },
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: theme.colorScheme.surface.withOpacity(0.1),
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}
