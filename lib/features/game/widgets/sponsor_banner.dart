import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../admin/models/sponsor.dart';

class SponsorBanner extends StatefulWidget {
  final Sponsor? sponsor;
  final bool isCompact;
  final VoidCallback? onImpression;
  final VoidCallback? onTap;

  const SponsorBanner({
    super.key,
    required this.sponsor,
    this.isCompact = false,
    this.onImpression,
    this.onTap,
  });

  @override
  State<SponsorBanner> createState() => _SponsorBannerState();
}

class _SponsorBannerState extends State<SponsorBanner> {
  bool _impressionTracked = false;

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (_impressionTracked) return;
    // Track impression only when at least 50% of the banner is visible
    if (info.visibleFraction >= 0.5) {
      _impressionTracked = true;
      widget.onImpression?.call();
    }
  }

  Future<void> _handleTap() async {
    widget.onTap?.call();

    final url = widget.sponsor?.targetUrl;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (sponsor == null || !sponsor!.hasSponsoredByBanner) {
      return const SizedBox.shrink();
    }

    final String? imageUrl = sponsor!.bannerUrl ?? sponsor!.logoUrl;

    if (imageUrl == null) {
      return const SizedBox.shrink();
    }

    return VisibilityDetector(
      key: Key('sponsor_banner_${sponsor!.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.6),
                    const Color(0xFF1A1A1A),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Brand Info
                    Container(
                      width: 120,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        border: Border(
                          right: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "PATROCINADO POR",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sponsor!.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              fontFamily: 'Orbitron',
                              letterSpacing: 0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Right Image Area (Full width)
                    Expanded(
                      child: Stack(
                        children: [
                          Image.network(
                            imageUrl,
                            height: 70,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) {
                              return const SizedBox.shrink();
                            },
                          ),
                          // Subtle gradient overlay for the image
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withOpacity(0.4),
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.2),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Sponsor? get sponsor => widget.sponsor;
}
