import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoadingWrapper<T extends ChangeNotifier> extends StatelessWidget {
  final Widget child;
  final bool Function(T provider) isLoading;

  const LoadingWrapper({
    Key? key,
    required this.child,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Consumer<T>(
      builder: (context, provider, _) {
        return Stack(
          children: [
            // The main screen
            Opacity(
              opacity: isLoading(provider) ? 0 : 1,
              child: child,
            ),
            // Loading spinner
            if (isLoading(provider))
              const Center(
                child:
                    CircularProgressIndicator(), // color pulled from theme automatically
              ),
          ],
        );
      },
    );
  }
}
