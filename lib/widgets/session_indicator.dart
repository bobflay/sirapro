import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sirapro/services/visit_service.dart';
import 'package:sirapro/utils/app_colors.dart';

/// A global session indicator that shows when there's an active visit session.
/// Displays at the top of the screen with client name and elapsed time.
class SessionIndicator extends StatefulWidget {
  final Widget child;

  const SessionIndicator({
    super.key,
    required this.child,
  });

  @override
  State<SessionIndicator> createState() => _SessionIndicatorState();
}

class _SessionIndicatorState extends State<SessionIndicator> {
  final VisitService _visitService = VisitService();
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _hasActiveSession = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
    // Check session status periodically
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateElapsed();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _checkSession() {
    final hasActive = _visitService.hasActiveVisit;
    if (hasActive != _hasActiveSession) {
      setState(() {
        _hasActiveSession = hasActive;
      });
    }
    if (hasActive) {
      _updateElapsed();
    }
  }

  void _updateElapsed() {
    final hasActive = _visitService.hasActiveVisit;

    if (hasActive != _hasActiveSession) {
      setState(() {
        _hasActiveSession = hasActive;
      });
    }

    if (hasActive && _visitService.activeVisitStartTime != null) {
      final newElapsed = DateTime.now().difference(_visitService.activeVisitStartTime!);
      if (newElapsed.inSeconds != _elapsed.inSeconds) {
        setState(() {
          _elapsed = newElapsed;
        });
      }
    } else if (!hasActive && _elapsed != Duration.zero) {
      setState(() {
        _elapsed = Duration.zero;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Session indicator banner
        if (_hasActiveSession) _buildSessionBanner(context),
        // Main content
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _buildSessionBanner(BuildContext context) {
    final clientName = _visitService.activeClientName ?? 'Client';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.success,
              AppColors.success.withValues(alpha: 0.85),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Pulsing indicator dot
                _buildPulsingDot(),
                const SizedBox(width: 12),
                // Session info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Visite en cours',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        clientName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Timer display
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDuration(_elapsed),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          letterSpacing: 1,
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
    );
  }

  Widget _buildPulsingDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: value * 0.6),
                blurRadius: 6 * value,
                spreadRadius: 2 * value,
              ),
            ],
          ),
        );
      },
      onEnd: () {
        // This creates a continuous pulsing effect by rebuilding
        if (mounted) {
          setState(() {});
        }
      },
    );
  }
}
