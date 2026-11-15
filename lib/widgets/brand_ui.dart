import 'package:flutter/material.dart';

import '../brand/brand.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// The shared green hero band used at the top of every working screen.
///
/// It keeps the brand rule consistent across the app: a rich green top third,
/// cream content below, and gold accents. Screens never hard-code colours.
class AppHeroHeader extends StatelessWidget {
  const AppHeroHeader({
    required this.title,
    this.subtitle,
    this.kicker,
    this.trailing,
    this.heightFactor = 0.55,
    this.minHeight = 340,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? kicker;
  final Widget? trailing;
  final double heightFactor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final height = (MediaQuery.sizeOf(context).height * heightFactor).clamp(
      minHeight,
      620.0,
    );
    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              BrandColors.deepGreen,
              BrandColors.forestGreen,
              BrandColors.leafGreen,
            ],
            stops: [0, 0.58, 1],
          ),
          border: Border(bottom: BorderSide(color: BrandColors.gold, width: 3)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -42,
              top: -52,
              child: Icon(
                Icons.bakery_dining,
                size: 240,
                color: BrandColors.ivory.withValues(alpha: 0.055),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Image.asset(Brand.logoAsset, width: 42, height: 42),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                kicker ?? AppLocalizations.of(context).appTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: BrandColors.lightGold,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: BrandColors.ivory,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle ?? Brand.slogan,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: BrandColors.cream.withValues(alpha: 0.9),
                              ),
                        ),
                        const Spacer(),
                        Container(
                          height: 3,
                          width: 54,
                          decoration: const BoxDecoration(
                            color: BrandColors.gold,
                            borderRadius: BorderRadius.all(Radius.circular(99)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          strings.pressBackToReturn,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: BrandColors.cream.withValues(
                                  alpha: 0.78,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A green summary card with cream text, used for KPI and quick facts.
class KpiCard extends StatelessWidget {
  const KpiCard({
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: BrandColors.deepGreen,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: BrandColors.gold, width: 1),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: BrandColors.lightGold, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: BrandColors.cream,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: BrandColors.ivory,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// An ivory content card with a thin gold/green border.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    super.key,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) => Card(
    margin: margin,
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Container(
            color: BrandColors.forestGreen,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: BrandColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: BrandColors.ivory,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        Padding(padding: padding, child: child),
      ],
    ),
  );
}

/// A compact green section title bar for long cream lists.
class SectionBar extends StatelessWidget {
  const SectionBar({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 18, 16, 6),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: const BoxDecoration(
      color: BrandColors.forestGreen,
      borderRadius: BorderRadius.all(Radius.circular(12)),
      border: Border.fromBorderSide(
        BorderSide(color: BrandColors.gold, width: 1),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: BrandColors.ivory,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BrandColors.cream.withValues(alpha: 0.85),
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}
