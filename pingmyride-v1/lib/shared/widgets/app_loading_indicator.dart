import 'package:flutter/material.dart';

class AppLoadingIndicator extends StatelessWidget {
  final String? message;
  final double spacing;

  const AppLoadingIndicator({
    super.key,
    this.message,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null && message!.trim().isNotEmpty) ...[
              SizedBox(height: spacing),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
