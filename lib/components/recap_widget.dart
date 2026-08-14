import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:music_wave_player/components/recap_card_header.dart';
import 'package:music_wave_player/components/recap_controls.dart';
import 'package:music_wave_player/components/recap_list_tile.dart';
import 'package:music_wave_player/services/recap_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class RecapWidget extends StatefulWidget {
  final RecapResult result;

  const RecapWidget._({required this.result});

  static Future<void> show(BuildContext context, RecapResult result) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecapWidget._(result: result),
    );
  }

  @override
  State<RecapWidget> createState() => _RecapWidgetState();
}

class _RecapWidgetState extends State<RecapWidget> {
  final GlobalKey _shareKey = GlobalKey();
  bool _sharing = false;
  int _currentPage = 0;

  RecapResult get result => widget.result;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _shareKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/recap_${result.period.label}.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Meu recap ${result.period.label} no LocalPlay 🎵',
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    if (m < 60) return '${m}min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem > 0 ? '${h}h ${rem}min' : '${h}h';
  }

  String get _periodIcon => switch (result.period.type) {
    RecapType.month => '📅',
    RecapType.quarter => '📊',
    RecapType.semester => '🎯',
    RecapType.year => '🏆',
  };

  List<Widget> get _pages => [_buildTracksPage(), _buildArtistsPage()];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: RepaintBoundary(key: _shareKey, child: _buildCard()),
          ),
          RecapControls(
            isSharing: _sharing,
            onClose: () => Navigator.pop(context),
            onShare: _share,
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B2A), Color(0xFF1D3557), Color(0xFF457B9D)],
        ),
      ),
      child: Column(
        children: [
          RecapCardHeader(
            periodIcon: _periodIcon,
            periodLabel: result.period.label,
            currentPage: _currentPage,
            pageCount: _pages.length,
          ),
          Expanded(
            child: PageView(
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: _pages,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.headphones, color: Colors.white38, size: 14),
                const SizedBox(width: 6),
                Text(
                  'LocalPlay',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTracksPage() {
    final tracks = result.tracks;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP MÚSICAS',
            style: TextStyle(
              color: Color(0xFFA8DADC),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tracks.length,
              itemBuilder: (context, i) {
                final item = tracks[i];
                return RecapListTile(
                  position: i + 1,
                  title: item.track.title,
                  subtitle: item.track.artist.split(';').first.trim(),
                  time: _formatSeconds(item.seconds),
                  isTop3: i < 3,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistsPage() {
    final artists = result.artists;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP ARTISTAS',
            style: TextStyle(
              color: Color(0xFFA8DADC),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: artists.length,
              itemBuilder: (context, i) {
                final item = artists[i];
                return RecapListTile(
                  position: i + 1,
                  title: item.artist,
                  time: _formatSeconds(item.seconds),
                  isTop3: i < 3,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
