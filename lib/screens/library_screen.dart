import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/app_menu_sheet.dart';
import 'package:music_wave_player/components/library_bottom_nav.dart';
import 'package:music_wave_player/components/library_top_bar.dart';
import 'package:music_wave_player/components/mini_player_component.dart';
import 'package:music_wave_player/components/recap_widget.dart';
import 'package:music_wave_player/components/tabs_component.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/screens/recently_played_screen.dart';
import 'package:music_wave_player/screens/search_screen.dart';
import 'package:music_wave_player/services/recap_service.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRecap());
  }

  Future<void> _checkRecap() async {
    final indexingState = await ref.read(indexingNotifierProvider.future);
    if (indexingState.indexedTracks.isEmpty) return;

    final recap = await RecapService.checkPendingRecap(
      indexingState.indexedTracks,
    );
    if (recap != null && mounted) {
      await RecapWidget.show(context, recap);
    }
  }

  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const AppMenuSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                LibraryTopBar(
                  onHistoryTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecentlyPlayedScreen(),
                    ),
                  ),
                  onSearchTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                  onMenuTap: () => _openMenu(context),
                ),
                Expanded(child: TabsComponent(activeIndex: _activeIndex)),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiniPlayerComponent(),
                  LibraryBottomNav(
                    activeIndex: _activeIndex,
                    onTap: (index) {
                      if (index == _activeIndex) return;
                      setState(() => _activeIndex = index);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
