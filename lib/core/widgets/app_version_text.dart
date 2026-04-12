import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionText extends StatelessWidget {
  final TextStyle? style;

  const AppVersionText({
    super.key,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final version = snapshot.data!.version;
          return Text(
            "Version $version",
            style: style ?? const TextStyle(color: Colors.grey, fontSize: 12),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
