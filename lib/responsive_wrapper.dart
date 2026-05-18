import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  
  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 600,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth > maxWidth) {
      final horizontalPadding = (screenWidth - maxWidth) / 2;
      return Container(
        color: Colors.grey[100],
        child: Center(
          child: Container(
            width: maxWidth,
            color: Colors.white,
            child: child,
          ),
        ),
      );
    }
    
    return child;
  }
}