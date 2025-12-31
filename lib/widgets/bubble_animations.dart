import 'package:flutter/material.dart';
import 'dart:math' as math;

class BubbleAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? bubbleColor;
  final int bubbleCount;
  final double minBubbleSize;
  final double maxBubbleSize;

  const BubbleAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 3),
    this.bubbleColor,
    this.bubbleCount = 15,
    this.minBubbleSize = 10.0,
    this.maxBubbleSize = 30.0,
  });

  @override
  State<BubbleAnimation> createState() => _BubbleAnimationState();
}

class _BubbleAnimationState extends State<BubbleAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<BubbleData> _bubbles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 12), // Slower animation
      vsync: this,
    );
    
    _initializeBubbles();
    _controller.repeat();
  }

  void _initializeBubbles() {
    _bubbles.clear();
    for (int i = 0; i < widget.bubbleCount; i++) {
      _bubbles.add(BubbleData(
        x: (i * 137.5) % 360.0, // Golden angle for better distribution
        y: 100.0 + (i * 50.0) % 200.0, // More spread out
        size: widget.minBubbleSize + 
               (i * 7.3) % (widget.maxBubbleSize - widget.minBubbleSize),
        speed: 0.2 + (i * 0.08) % 0.4, // Slower speeds
        opacity: 0.05 + (i * 0.03) % 0.15, // More subtle opacity
        delay: (i * 0.3), // Staggered animation start
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated bubbles
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: BubblePainter(
                bubbles: _bubbles,
                progress: _controller.value,
                bubbleColor: widget.bubbleColor ?? 
                           Theme.of(context).primaryColor.withValues(alpha: 0.1),
              ),
            );
          },
        ),
        // Content
        widget.child,
      ],
    );
  }
}

class BubbleData {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final double delay;

  BubbleData({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.delay,
  });
}

class BubblePainter extends CustomPainter {
  final List<BubbleData> bubbles;
  final double progress;
  final Color bubbleColor;

  BubblePainter({
    required this.bubbles,
    required this.progress,
    required this.bubbleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final bubble in bubbles) {
      // Apply delay to create staggered animation
      final adjustedProgress = (progress + bubble.delay) % 1.0;
      
      // Only animate bubble when its delay has passed
      if (adjustedProgress > 0) {
        final adjustedY = bubble.y - (adjustedProgress * size.height * 2.0);
        final wrappedY = adjustedY % (size.height + bubble.size * 2);
        
        if (wrappedY > -bubble.size && wrappedY < size.height + bubble.size) {
          // Fade in and out effect
          final fadeProgress = adjustedProgress < 0.1 
              ? adjustedProgress * 10 
              : (adjustedProgress > 0.9 ? (1.0 - adjustedProgress) * 10 : 1.0);
          
          final paint = Paint()
            ..color = bubbleColor.withValues(alpha: bubble.opacity * fadeProgress)
            ..style = PaintingStyle.fill;
          
          final center = Offset(
            (bubble.x / 360.0) * size.width,
            wrappedY,
          );
          
          // Add subtle wobble effect
          final wobble = math.sin(adjustedProgress * math.pi * 2) * 5;
          final wobbleCenter = Offset(center.dx + wobble, center.dy);
          
          canvas.drawCircle(wobbleCenter, bubble.size, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant BubblePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class FloatingBubble extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? size;
  final bool isAnimating;

  const FloatingBubble({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.size,
    this.isAnimating = true,
  });

  @override
  State<FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<FloatingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4), // Slower animation
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05, // More subtle scaling
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _floatAnimation = Tween<double>(
      begin: 0,
      end: 6, // Less floating distance
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubbleSize = widget.size ?? 60.0;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_floatAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: bubbleSize,
                height: bubbleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.backgroundColor ?? 
                         Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(child: widget.child),
              ),
            ),
          ),
        );
      },
    );
  }
}

class BubbleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final bool isLoading;

  const BubbleButton({
    super.key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.width,
    this.height,
    this.isLoading = false,
  });

  @override
  State<BubbleButton> createState() => _BubbleButtonState();
}

class _BubbleButtonState extends State<BubbleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;


  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500), // Slower animation
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03, // More subtle scaling
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));



    if (!widget.isLoading) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isLoading ? 1.0 : _scaleAnimation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                  colors: [
                    widget.backgroundColor ?? Theme.of(context).primaryColor,
                    (widget.backgroundColor ?? Theme.of(context).primaryColor).withValues(alpha: 0.8),
                  ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.backgroundColor ?? Theme.of(context).primaryColor)
                      .withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isLoading ? null : widget.onPressed,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: widget.padding ?? 
                         const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: widget.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.foregroundColor ?? Colors.white,
                            ),
                          ),
                        )
                      : DefaultTextStyle(
                          style: TextStyle(
                            color: widget.foregroundColor ?? Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          child: widget.child,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class BubbleCard extends StatefulWidget {
  final Widget child;
  final Color? backgroundColor;
  final double? elevation;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool isAnimating;

  const BubbleCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.elevation,
    this.margin,
    this.padding,
    this.borderRadius,
    this.onTap,
    this.isAnimating = true,
  });

  @override
  State<BubbleCard> createState() => _BubbleCardState();
}

class _BubbleCardState extends State<BubbleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5), // Slower animation
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.01, // More subtle scaling
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _elevationAnimation = Tween<double>(
      begin: widget.elevation ?? 4.0,
      end: (widget.elevation ?? 4.0) + 1.0, // Less elevation change
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Card(
            margin: widget.margin,
            elevation: _elevationAnimation.value,
            shape: RoundedRectangleBorder(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
            ),
            color: widget.backgroundColor,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
              child: Container(
                padding: widget.padding ?? const EdgeInsets.all(16),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class BubbleBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final Duration? duration;

  const BubbleBackground({
    super.key,
    required this.child,
    this.colors,
    this.duration,
  });

  @override
  State<BubbleBackground> createState() => _BubbleBackgroundState();
}

class _BubbleBackgroundState extends State<BubbleBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<Color?>> _colorAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? const Duration(seconds: 10),
      vsync: this,
    );

    final colors = widget.colors ?? [
      Theme.of(context).primaryColor.withValues(alpha: 0.1),
      Theme.of(context).primaryColor.withValues(alpha: 0.05),
      Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
    ];

    _colorAnimations = colors.map((colorEntry) {
      final nonNullableColor = colorEntry;
      return ColorTween(
        begin: nonNullableColor.withValues(alpha: 0.05),
        end: nonNullableColor.withValues(alpha: 0.15),
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ));
    }).toList();

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _colorAnimations.map((anim) => anim.value ?? Colors.transparent).toList(),
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}
