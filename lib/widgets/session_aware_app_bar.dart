import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sirapro/services/visit_service.dart';
import 'package:sirapro/services/client_service.dart';
import 'package:sirapro/screens/client_detail_page.dart';
import 'package:sirapro/utils/app_colors.dart';

/// A unified app bar that adapts when there's an active visit session.
/// When no visit is active: Shows standard red SIRA PRO app bar
/// When visit is active: Shows green app bar with session info and timer
class SessionAwareAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;

  const SessionAwareAppBar({
    super.key,
    this.title = 'SIRA PRO',
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
  });

  @override
  State<SessionAwareAppBar> createState() => _SessionAwareAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );
}

class _SessionAwareAppBarState extends State<SessionAwareAppBar> {
  final VisitService _visitService = VisitService();
  final ClientService _clientService = ClientService();
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _hasActiveSession = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateState();
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

  void _updateState() {
    final hasActive = _visitService.hasActiveVisit;

    if (hasActive != _hasActiveSession) {
      setState(() {
        _hasActiveSession = hasActive;
      });
    }

    if (hasActive) {
      _updateElapsed();
    } else if (_elapsed != Duration.zero) {
      setState(() {
        _elapsed = Duration.zero;
      });
    }
  }

  void _updateElapsed() {
    if (_visitService.activeVisitStartTime != null) {
      final newElapsed =
          DateTime.now().difference(_visitService.activeVisitStartTime!);
      if (newElapsed.inSeconds != _elapsed.inSeconds) {
        setState(() {
          _elapsed = newElapsed;
        });
      }
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

  Future<void> _navigateToActiveClient() async {
    final clientId = _visitService.activeClientId;
    if (clientId == null) return;

    try {
      final client = await _clientService.getClient(clientId);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClientDetailPage(client: client),
          ),
        );
      }
    } catch (e) {
      // Silently fail if client cannot be loaded
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasActiveSession) {
      return _buildActiveSessionAppBar(context);
    }
    return _buildNormalAppBar(context);
  }

  Widget _buildNormalAppBar(BuildContext context) {
    return AppBar(
      title: Text(widget.title),
      leading: widget.leading,
      automaticallyImplyLeading: widget.automaticallyImplyLeading,
      actions: widget.actions,
      bottom: widget.bottom,
    );
  }

  Widget _buildActiveSessionAppBar(BuildContext context) {
    final clientName = _visitService.activeClientName ?? 'Client';

    return AppBar(
      backgroundColor: AppColors.success,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: widget.leading,
      automaticallyImplyLeading: widget.automaticallyImplyLeading,
      title: GestureDetector(
        onTap: _navigateToActiveClient,
        child: Row(
          children: [
            // Pulsing dot
            _buildPulsingDot(),
            const SizedBox(width: 10),
            // Session info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                        child: const Text(
                          'EN VISITE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          clientName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Timer display
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
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
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDuration(_elapsed),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        // Include original actions
        if (widget.actions != null) ...widget.actions!,
      ],
      bottom: widget.bottom,
    );
  }

  Widget _buildPulsingDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: value * 0.6),
                blurRadius: 4 * value,
                spreadRadius: 1.5 * value,
              ),
            ],
          ),
        );
      },
      onEnd: () {
        if (mounted && _hasActiveSession) {
          setState(() {});
        }
      },
    );
  }
}
