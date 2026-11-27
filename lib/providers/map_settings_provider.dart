import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

const String defaultTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

class MapSettings {
  /// Whether map tiles are downloaded at all. When false the map shows only
  /// the bundled station markers and makes no network requests.
  final bool tilesEnabled;

  /// Tile URL template, e.g. https://tile.openstreetmap.org/{z}/{x}/{y}.png
  final String tileUrl;

  /// False until the saved settings have been read from disk, so the map
  /// never contacts the default server before a user's choice is known.
  final bool loaded;

  const MapSettings({
    this.tilesEnabled = true,
    this.tileUrl = defaultTileUrl,
    this.loaded = true,
  });

  bool get isDefaultServer => tileUrl == defaultTileUrl;

  /// Host name of the tile server, for attribution.
  String get tileHost => Uri.tryParse(_fillPlaceholders(tileUrl))?.host ?? '';

  static String _fillPlaceholders(String url) =>
      url.replaceAll(RegExp(r'\{[a-z]+\}'), '0');

  MapSettings copyWith({bool? tilesEnabled, String? tileUrl}) => MapSettings(
    tilesEnabled: tilesEnabled ?? this.tilesEnabled,
    tileUrl: tileUrl ?? this.tileUrl,
  );

  Map<String, dynamic> toJson() => {
    'tilesEnabled': tilesEnabled,
    'tileUrl': tileUrl,
  };

  factory MapSettings.fromJson(Map<String, dynamic> json) => MapSettings(
    tilesEnabled: json['tilesEnabled'] as bool? ?? true,
    tileUrl: json['tileUrl'] as String? ?? defaultTileUrl,
  );

  /// Returns true when [url] looks like a usable tile URL template.
  static bool isValidTileUrl(String url) {
    final uri = Uri.tryParse(_fillPlaceholders(url.trim()));
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        url.contains('{z}') &&
        url.contains('{x}') &&
        url.contains('{y}');
  }
}

class MapSettingsNotifier extends StateNotifier<MapSettings> {
  MapSettingsNotifier() : super(const MapSettings(loaded: false)) {
    _load();
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/map_settings.json');
  }

  Future<void> _load() async {
    var settings = const MapSettings();
    try {
      final file = await _file();
      if (await file.exists()) {
        settings = MapSettings.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Corrupt or unreadable settings: keep defaults.
    }
    if (mounted) {
      state = settings;
    }
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(state.toJson()));
    } catch (_) {}
  }

  Future<void> update(MapSettings settings) async {
    state = settings;
    await _save();
  }

  Future<void> reset() => update(const MapSettings());
}

final mapSettingsProvider =
    StateNotifierProvider<MapSettingsNotifier, MapSettings>(
      (ref) => MapSettingsNotifier(),
    );
