import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';

class TrackArtwork extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  final double borderRadius;
  final IconData placeholderIcon;
  final BoxFit fit;

  TrackArtwork({
    super.key,
    required this.url,
    double? width,
    double? height,
    double? size,
    this.borderRadius = 10,
    this.placeholderIcon = Icons.music_note_rounded,
    this.fit = BoxFit.cover,
  })  : width = size ?? width ?? 48,
        height = size ?? height ?? 48;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.trim().isEmpty) {
      return _buildPlaceholder();
    }

    final trimmed = url!.trim();

    Widget img;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      img = CachedNetworkImage(
        imageUrl: trimmed,
        width: width,
        height: height,
        fit: fit,
        placeholder: (ctx, u) => _buildPlaceholder(),
        errorWidget: (ctx, u, e) => _buildPlaceholder(),
      );
    } else {
      final cleanPath = trimmed.replaceFirst('file://', '');
      final file = File(cleanPath);
      if (file.existsSync()) {
        img = Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (ctx, e, s) => _buildPlaceholder(),
        );
      } else {
        img = _buildPlaceholder();
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: img,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
      child: Center(
        child: Icon(
          placeholderIcon,
          color: Colors.white,
          size: width * 0.42,
        ),
      ),
    );
  }
}
