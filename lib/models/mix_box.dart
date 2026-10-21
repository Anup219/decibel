import 'package:flutter/material.dart';
import 'track.dart';

class DecibelMixBox {
  final String id;
  final String title;
  final String subtitle;
  final String cadenceBadge;
  final List<Color> gradientColors;
  final List<Track> tracks;

  const DecibelMixBox({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.cadenceBadge,
    required this.gradientColors,
    required this.tracks,
  });
}

class UserPlaylist {
  final String id;
  final String name;
  final String imageUrl;
  final int trackCount;
  final List<Track> tracks;

  const UserPlaylist({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.trackCount,
    required this.tracks,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'trackCount': trackCount,
    'tracks': tracks.map((t) => t.toJson()).toList(),
  };

  factory UserPlaylist.fromJson(Map<String, dynamic> json) => UserPlaylist(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Untitled Playlist',
    imageUrl: json['imageUrl'] as String? ?? '',
    trackCount: (json['trackCount'] as num?)?.toInt() ?? 0,
    tracks: (json['tracks'] as List<dynamic>?)
            ?.map((e) => Track.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}
