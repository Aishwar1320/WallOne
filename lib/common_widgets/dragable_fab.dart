import 'package:flutter/material.dart';

class DraggableFAB extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? text;
  final IconData? icon;
  final double? elevation;
  final bool enableHapticFeedback;
  final Duration animationDuration;
  final EdgeInsets margin;

  const DraggableFAB({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.text,
    this.icon,
    this.elevation,
    this.enableHapticFeedback = true,
    this.animationDuration = const Duration(milliseconds: 300),
    this.margin = const EdgeInsets.all(20),
  });

  @override
  State<DraggableFAB> createState() => _DraggableFABState();
}

class _DraggableFABState extends State<DraggableFAB>
    with SingleTickerProviderStateMixin {
  late Offset position;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool minimized = false;
  bool isDragging = false;
  late Size _screenSize;

  // Constants for better maintainability
  static const double _expandedWidth = 180;
  static const double _minimizedWidth = 60;
  static const double _fabHeight = 60;
  static const double _velocityThreshold = 800;
  static const double _tapScale = 0.95;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: _tapScale,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  bool _positionInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.of(context).size;

    if (!_positionInitialized) {
      _setInitialPosition();
      _positionInitialized = true;
    }
  }

  void _setInitialPosition() {
    position = Offset(
      _screenSize.width - _expandedWidth - widget.margin.right,
      _screenSize.height -
          _fabHeight -
          widget.margin.bottom -
          MediaQuery.of(context).padding.bottom,
    );
  }

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      isDragging = true;
    });

    if (widget.enableHapticFeedback) {
      // Add haptic feedback (requires services import)
      // HapticFeedback.lightImpact();
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!isDragging) return;

    final double fabWidth = minimized ? _minimizedWidth : _expandedWidth;

    setState(() {
      position = Offset(
        (position.dx + details.delta.dx).clamp(
          0.0,
          _screenSize.width - fabWidth,
        ),
        (position.dy + details.delta.dy).clamp(
          MediaQuery.of(context).padding.top,
          _screenSize.height -
              _fabHeight -
              MediaQuery.of(context).padding.bottom,
        ),
      );
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!isDragging) return;

    setState(() {
      isDragging = false;
    });

    final velocity = details.velocity.pixelsPerSecond;
    final horizontalVelocity = velocity.dx;
    final verticalVelocity = velocity.dy.abs();

    // Enhanced logic for minimizing/expanding
    final bool shouldMinimize =
        _shouldMinimize(horizontalVelocity, verticalVelocity);
    final Offset targetPosition = _calculateTargetPosition(shouldMinimize);

    setState(() {
      minimized = shouldMinimize;
      position = targetPosition;
    });

    if (widget.enableHapticFeedback && minimized != shouldMinimize) {
      // HapticFeedback.mediumImpact();
    }
  }

  bool _shouldMinimize(double horizontalVelocity, double verticalVelocity) {
    // More sophisticated logic for when to minimize
    if (horizontalVelocity > _velocityThreshold) {
      return true; // Swipe right to minimize
    }
    if (horizontalVelocity < -_velocityThreshold && minimized) {
      return false; // Swipe left to expand when minimized
    }

    // Check if FAB is near the edge
    final isNearRightEdge = position.dx > _screenSize.width * 0.7;
    final isNearLeftEdge = position.dx < _screenSize.width * 0.3;

    if (isNearRightEdge && !minimized) {
      return true; // Auto-minimize when near right edge
    }
    if (isNearLeftEdge && minimized) {
      return false; // Auto-expand when near left edge
    }

    return minimized; // Keep current state
  }

  Offset _calculateTargetPosition(bool shouldMinimize) {
    final double targetWidth =
        shouldMinimize ? _minimizedWidth : _expandedWidth;

    if (shouldMinimize) {
      // Stick to the nearest vertical edge
      final double targetX = position.dx > _screenSize.width / 2
          ? _screenSize.width - targetWidth
          : 0;

      return Offset(
        targetX,
        position.dy.clamp(
          MediaQuery.of(context).padding.top,
          _screenSize.height -
              _fabHeight -
              MediaQuery.of(context).padding.bottom,
        ),
      );
    } else {
      // Return to a more central position when expanding
      return Offset(
        (_screenSize.width - targetWidth - widget.margin.right).clamp(
          widget.margin.left,
          _screenSize.width - targetWidth,
        ),
        position.dy.clamp(
          MediaQuery.of(context).padding.top + widget.margin.top,
          _screenSize.height -
              _fabHeight -
              widget.margin.bottom -
              MediaQuery.of(context).padding.bottom,
        ),
      );
    }
  }

  void _handleTap() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Add small delay for visual feedback
    Future.delayed(const Duration(milliseconds: 100), () {
      widget.onPressed();
    });

    if (widget.enableHapticFeedback) {
      // HapticFeedback.selectionClick();
    }
  }

  void _handleLongPress() {
    // Toggle minimized state on long press
    setState(() {
      minimized = !minimized;
      position = _calculateTargetPosition(minimized);
    });

    if (widget.enableHapticFeedback) {
      // HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double fabWidth = minimized ? _minimizedWidth : _expandedWidth;

    final Color backgroundColor = widget.backgroundColor ?? theme.primaryColor;
    final Color foregroundColor = widget.foregroundColor ?? Colors.white;

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onTap: _handleTap,
        onLongPress: _handleLongPress,
        onPanStart: _handleDragStart,
        onPanUpdate: _handleDragUpdate,
        onPanEnd: _handleDragEnd,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: widget.animationDuration,
                curve: Curves.easeInOutCubic,
                width: fabWidth,
                height: _fabHeight,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: _getBorderRadius(),
                  boxShadow: _getBoxShadow(backgroundColor),
                ),
                child: _buildFABContent(foregroundColor),
              ),
            );
          },
        ),
      ),
    );
  }

  BorderRadius _getBorderRadius() {
    if (minimized) {
      // Dynamic border radius based on position
      final isOnLeftEdge = position.dx <= 0;
      final isOnRightEdge = position.dx >= _screenSize.width - _minimizedWidth;

      if (isOnLeftEdge) {
        return const BorderRadius.horizontal(right: Radius.circular(30));
      } else if (isOnRightEdge) {
        return const BorderRadius.horizontal(left: Radius.circular(30));
      }
    }
    return BorderRadius.circular(30);
  }

  List<BoxShadow> _getBoxShadow(Color backgroundColor) {
    final double elevation = widget.elevation ?? (isDragging ? 8.0 : 4.0);

    return [
      BoxShadow(
        color: backgroundColor.withOpacity(0.3),
        blurRadius: elevation,
        offset: Offset(0, elevation / 2),
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: elevation * 2,
        offset: Offset(0, elevation),
        spreadRadius: 0,
      ),
    ];
  }

  Widget _buildFABContent(Color foregroundColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: _getBorderRadius(),
        onTap: _handleTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment:
                minimized ? MainAxisAlignment.center : MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon ?? Icons.auto_awesome,
                color: foregroundColor,
                size: 24,
              ),
              if (!minimized) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.text ?? 'Smart Analysis',
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
