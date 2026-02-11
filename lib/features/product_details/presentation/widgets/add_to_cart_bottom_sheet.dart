import 'package:flutter/material.dart';
import '../../../../core/theme/app_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../../../core/constants/responsive_constants.dart';
import '../../../../core/services/haptic_service.dart';

import '../../domain/entities/product_details.dart';
import '../bloc/product_details_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../cart/presentation/pages/cart_page.dart';
import '../../../cart/presentation/bloc/cart_bloc.dart';
import '../../../../core/navigation/navigation_service.dart';

class AddToCartBottomSheet extends StatelessWidget {
  final ProductDetails productDetails;
  final ProductDetailsBloc bloc;

  const AddToCartBottomSheet({
    super.key,
    required this.productDetails,
    required this.bloc,
  });

  static Future<void> show(
    BuildContext context,
    ProductDetails productDetails,
    ProductDetailsBloc bloc,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: false,
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.8, // Responsive max height
      ),
      builder: (context) => BlocProvider.value(
        value: bloc,
        child: AddToCartBottomSheet(productDetails: productDetails, bloc: bloc),
      ),
    ).then((_) {
      // Reset the isAdding state when the bottom sheet is closed
      bloc.add(ResetAddingStateEvent());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(
              ResponsiveConstants.lgPadding,
              ResponsiveConstants.mdSpacing,
              ResponsiveConstants.lgPadding,
              ResponsiveConstants.lgPadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () async {
                    await HapticService.buttonClick();
                    Navigator.of(context).pop();
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Product Info Card
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: ResponsiveConstants.lgPadding,
            ),
            padding: EdgeInsets.all(ResponsiveConstants.mdSpacing),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(ResponsiveConstants.mdRadius),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    ResponsiveConstants.smRadius,
                  ),
                  child: CachedNetworkImage(
                    imageUrl: productDetails.images.first,
                    width: ResponsiveConstants.xlDimension,
                    height: ResponsiveConstants.xlDimension,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Container(
                      width: ResponsiveConstants.xlDimension,
                      height: ResponsiveConstants.xlDimension,
                      color: Theme.of(context).colorScheme.surface,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: ResponsiveConstants.xlDimension,
                      height: ResponsiveConstants.xlDimension,
                      color: Theme.of(context).colorScheme.surface,
                      child: Icon(
                        Icons.error,
                        color: Theme.of(context).colorScheme.error,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveConstants.mdSpacing),

                // Product Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productDetails.brand,
                        style: AppFonts.getTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      BlocBuilder<ProductDetailsBloc, ProductDetailsState>(
                        builder: (context, state) {
                          final pd = state is ProductDetailsLoaded
                              ? state.productDetails
                              : productDetails;
                          // Compose selected attributes summary
                          final List<String> parts = [];
                          if (pd.variantAttributeOptions.isNotEmpty) {
                            for (final opt in pd.variantAttributeOptions) {
                              if (opt.selectedValue.isNotEmpty) {
                                parts.add(
                                  '${opt.attributeName}: ${opt.selectedValue}',
                                );
                              }
                            }
                          }
                          // Fallback include primary selected size if not covered
                          if (parts.isEmpty && pd.selectedSize.isNotEmpty) {
                            parts.add(
                              '${pd.primaryVariantLabel}: ${pd.selectedSize}',
                            );
                          }
                          final String subtitle = parts.isNotEmpty
                              ? ' (${parts.join(', ')})'
                              : '';
                          return Text(
                            pd.name + subtitle,
                            style: AppFonts.getTextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Consumer<CurrencyProvider>(
                            builder: (context, currencyProvider, child) {
                              return Text(
                                currencyProvider.formatPrice(
                                  productDetails.price,
                                  locale: Localizations.localeOf(context),
                                ),
                                style: AppFonts.getTextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              );
                            },
                          ),
                          if (productDetails.originalPrice != null &&
                              productDetails.originalPrice! >
                                  productDetails.price) ...[
                            const SizedBox(width: 8),
                            Consumer<CurrencyProvider>(
                              builder: (context, currencyProvider, child) {
                                return Text(
                                  currencyProvider.formatPrice(
                                    productDetails.originalPrice!,
                                    locale: Localizations.localeOf(context),
                                  ),
                                  style: AppFonts.getTextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: ResponsiveConstants.lgPadding),

          // Selected Options (dynamic attribute header)
          ...(() {
            final hasRealColors = productDetails.colorOptions
                .where((c) => c.name.toLowerCase() != 'default')
                .isNotEmpty;
            final hasSizes = productDetails.sizeOptions.isNotEmpty;
            final showSelected =
                (hasRealColors && productDetails.selectedColor.isNotEmpty) ||
                (hasSizes && productDetails.selectedSize.isNotEmpty);
            if (!showSelected) return <Widget>[];

            return [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveConstants.lgPadding,
                ),
                child: Row(
                  children: [
                    Text(
                      '${AppLocalizations.of(context)!.selected}: ',
                      style: AppFonts.getTextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                    if (hasRealColors &&
                        productDetails.selectedColor.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${AppLocalizations.of(context)!.color}: ${productDetails.selectedColor}',
                          style: AppFonts.getTextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                    if (hasSizes &&
                        productDetails.selectedSize.isNotEmpty &&
                        productDetails.primaryVariantLabel.isNotEmpty) ...[
                      if (hasRealColors &&
                          productDetails.selectedColor.isNotEmpty)
                        const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${productDetails.primaryVariantLabel}: ${productDetails.selectedSize}',
                          style: AppFonts.getTextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: ResponsiveConstants.lgPadding),
            ];
          })(),

          // Quantity Selector
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveConstants.lgPadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.quantity,
                  style: AppFonts.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(
                      ResponsiveConstants.smRadius,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05,
                        ),
                        blurRadius: ResponsiveConstants.smElevation,
                        offset: Offset(0, ResponsiveConstants.xsSpacing),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildQuantityButton(
                        context,
                        icon: Icons.remove,
                        onPressed: () {
                          context.read<ProductDetailsBloc>().add(
                            DecrementQuantityEvent(),
                          );
                        },
                      ),
                      Container(
                        width: ResponsiveConstants.xlDimension,
                        height: ResponsiveConstants.xlDimension,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.background,
                          border: Border.symmetric(
                            horizontal: BorderSide(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        child:
                            BlocBuilder<
                              ProductDetailsBloc,
                              ProductDetailsState
                            >(
                              builder: (context, state) {
                                if (state is! ProductDetailsLoaded) {
                                  return Text(
                                    '1',
                                    style: AppFonts.getTextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  );
                                }

                                final pd = state.productDetails;
                                int displayedQty = state.quantity;

                                // Clamp quantity to the selected variant's available
                                // stock for display, using the same loop-based logic
                                // as attributes/badge.
                                try {
                                  final cartState =
                                      context.read<CartBloc>().state;
                                  final available = _getAvailableQuantityForSelection(
                                    pd,
                                    cartState,
                                  );
                                  if (available != null) {
                                    int maxAvailable = available;

                                    if (maxAvailable > 0) {
                                      if (displayedQty > maxAvailable) {
                                        displayedQty = maxAvailable;
                                      }
                                    } else {
                                      displayedQty = 1;
                                    }
                                  }
                                } catch (e) {
                                  developer.log(
                                      '⚠️ Error clamping quantity: $e');
                                }

                                return Text(
                                  '$displayedQty',
                                  style: AppFonts.getTextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                );
                              },
                            ),
                      ),
                      BlocBuilder<ProductDetailsBloc, ProductDetailsState>(
                        buildWhen: (previous, current) {
                          return current is ProductDetailsLoaded;
                        },
                        builder: (context, state) {
                          return BlocBuilder<CartBloc, CartState>(
                            buildWhen: (previous, current) {
                              return true; // Rebuild when cart changes
                            },
                            builder: (context, cartState) {
                              if (state is! ProductDetailsLoaded) {
                                return _buildQuantityButton(
                                  context,
                                  icon: Icons.add,
                                  onPressed: () {
                                    context.read<ProductDetailsBloc>().add(
                                      IncrementQuantityEvent(),
                                    );
                                  },
                                );
                              }
                              
                              final pd = state.productDetails;
                              final currentQty = state.quantity;
                              
                              // Find available quantity using the same loop-based
                              // logic as attributes/badge and remaining stock label.
                              int maxAvailable = 999; // Fallback high value
                              try {
                                final available = _getAvailableQuantityForSelection(
                                  pd,
                                  cartState,
                                );
                                if (available != null) {
                                  maxAvailable = available;
                                }
                              } catch (e) {
                                developer.log(
                                    '⚠️ Error calculating max available: $e');
                              }

                              // Always limit increment to available stock
                              final isAtMax = currentQty >= maxAvailable;
                              
                              return _buildQuantityButton(
                                context,
                                icon: Icons.add,
                                onPressed: isAtMax ? null : () {
                                  context.read<ProductDetailsBloc>().add(
                                    IncrementQuantityEvent(),
                                  );
                                },
                                enabled: !isAtMax,
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Show remaining quantity - listen to both ProductDetailsBloc and CartBloc
          BlocBuilder<ProductDetailsBloc, ProductDetailsState>(
            buildWhen: (previous, current) {
              // Rebuild when product details change (variant selection, stock update)
              return current is ProductDetailsLoaded;
            },
            builder: (context, state) {
              return BlocBuilder<CartBloc, CartState>(
                buildWhen: (previous, current) {
                  // Rebuild when cart changes (items added/removed)
                  return true;
                },
                builder: (context, cartState) {
                  if (state is! ProductDetailsLoaded) {
                    return const SizedBox.shrink();
                  }
                  
                  final pd = state.productDetails;
                  int remainingQty = 999; // Default
                  bool hasStockInfo = false;

                  try {
                    final available =
                        _getAvailableQuantityForSelection(pd, cartState);
                    if (available != null) {
                      remainingQty = available;
                      hasStockInfo = true;
                    }
                  } catch (e) {
                    developer.log(
                        '⚠️ Error calculating remaining quantity: $e');
                  }

                  // Always show available count when we have stock info
                  if (!hasStockInfo) {
                    return const SizedBox.shrink();
                  }
                  
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveConstants.lgPadding,
                      vertical: ResponsiveConstants.smSpacing,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: remainingQty > 0 
                              ? Colors.orange.shade600
                              : Colors.red.shade600,
                        ),
                        SizedBox(width: ResponsiveConstants.xsSpacing),
                        Text(
                          remainingQty > 0
                              ? AppLocalizations.of(context)!.availableCount(remainingQty)
                              : AppLocalizations.of(context)!.outOfStock,
                          style: AppFonts.getTextStyle(
                            fontSize: ResponsiveConstants.smFontSize,
                            color: remainingQty > 0
                                ? Colors.orange.shade600
                                : Colors.red.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          SizedBox(height: ResponsiveConstants.lgSpacing),

          // Total Price
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveConstants.lgPadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppLocalizations.of(context)!.total}:',
                  style: AppFonts.getTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                BlocBuilder<ProductDetailsBloc, ProductDetailsState>(
                  builder: (context, state) {
                    final quantity = state is ProductDetailsLoaded
                        ? state.quantity
                        : 1;
                    final currentPd = state is ProductDetailsLoaded
                        ? state.productDetails
                        : productDetails;
                    final totalPrice = currentPd.price * quantity;
                    return Consumer<CurrencyProvider>(
                      builder: (context, currencyProvider, child) {
                        return Text(
                          currencyProvider.formatPrice(
                            totalPrice,
                            locale: Localizations.localeOf(context),
                          ),
                          style: AppFonts.getTextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: ResponsiveConstants.lgSpacing),

          // Add to Cart Button
          Padding(
            padding: EdgeInsets.fromLTRB(
              ResponsiveConstants.lgPadding,
              0,
              ResponsiveConstants.lgPadding,
              ResponsiveConstants.lgPadding,
            ),
            child: SizedBox(
              width: double.infinity,
              height: ResponsiveConstants.lgButtonHeight,
              child: BlocBuilder<ProductDetailsBloc, ProductDetailsState>(
                buildWhen: (previous, current) => current is ProductDetailsLoaded,
                builder: (context, state) {
                  return BlocBuilder<CartBloc, CartState>(
                    builder: (context, cartState) {
                      final isAdding =
                          state is ProductDetailsLoaded && state.isAdding;
                      final currentPd = state is ProductDetailsLoaded
                          ? state.productDetails
                          : productDetails;

                      String _normalize(String s) => s
                          .toLowerCase()
                          .trim()
                          .replaceAll(RegExp(r"[^\p{L}\p{N}]", unicode: true), '')
                          .replaceAll(RegExp(r"\s+"), '');
                      bool normalizeEqual(String a, String b) => _normalize(a) == _normalize(b);
                      final bool hasColorRequirement = currentPd.colorOptions
                          .where((c) => c.name.toLowerCase() != 'default')
                          .isNotEmpty;
                      final bool colorSelected =
                          !hasColorRequirement ||
                          (currentPd.selectedColor.isNotEmpty &&
                              currentPd.selectedColor.toLowerCase() != 'default');

                      // Primary attribute (dynamic) selection check
                      final primaryOpt = currentPd.variantAttributeOptions
                          .firstWhere(
                            (o) =>
                                o.attributeName.toLowerCase() ==
                                    currentPd.primaryVariantLabel.toLowerCase() ||
                                o.attributeName.toLowerCase() == 'size',
                            orElse: () => const VariantAttributeOption(
                              attributeName: '',
                              values: [],
                              selectedValue: '',
                            ),
                          );
                      final bool hasPrimaryRequirement =
                          primaryOpt.attributeName.isNotEmpty;
                      final bool primarySelected =
                          !hasPrimaryRequirement ||
                          (primaryOpt.selectedValue.isNotEmpty || currentPd.selectedSize.isNotEmpty);

                      bool variantCombinationSelected = true;
                      if ((hasColorRequirement || hasPrimaryRequirement) &&
                          colorSelected &&
                          primarySelected &&
                          currentPd.variantCombinations.isNotEmpty) {
                        final String selColor = currentPd.selectedColor;
                        final String selPrimary =
                            primaryOpt.selectedValue.isNotEmpty
                            ? primaryOpt.selectedValue
                            : currentPd.selectedSize;
                        variantCombinationSelected = currentPd.variantCombinations
                            .any((v) {
                              String? _getAttr(List<String> keys) {
                                for (final k in keys) {
                                  final val = v.getAttributeValue(k);
                                  if (val != null && val.isNotEmpty) return val;
                                }
                                return null;
                              }

                              // Try common color keys in both EN/AR with case variants
                              final colorVal = _getAttr([
                                'color', 'Color', 'colour', 'Colour', 'COLOR', 'COLOR NAME', 'اللون', 'لون', 'لون المنتج'
                              ]);
                              final bool colorMatch = !hasColorRequirement || (
                                colorVal != null && (
                                  normalizeEqual(colorVal, selColor) ||
                                  _normalize(colorVal).contains(_normalize(selColor)) ||
                                  _normalize(selColor).contains(_normalize(colorVal))
                                )
                              );
                              final bool primaryMatch = !hasPrimaryRequirement || (
                                (
                                  v.getAttributeValue(currentPd.primaryVariantLabel) != null &&
                                  normalizeEqual(
                                    v.getAttributeValue(currentPd.primaryVariantLabel)!,
                                    selPrimary,
                                  )
                                ) || (
                                  v.getAttributeValue('size') != null &&
                                  normalizeEqual(
                                    v.getAttributeValue('size')!,
                                    selPrimary,
                                  )
                                ) || (
                                  v.getAttributeValue('SIZE') != null &&
                                  normalizeEqual(
                                    v.getAttributeValue('SIZE')!,
                                    selPrimary,
                                  )
                                ) || (
                                  v.getAttributeValue('المقاس') != null &&
                                  normalizeEqual(
                                    v.getAttributeValue('المقاس')!,
                                    selPrimary,
                                  )
                                )
                              );
                              return colorMatch && primaryMatch;
                            });
                      }

                      // Use the same quantity we show in the UI (from _getAvailableQuantityForSelection)
                      // as the source of truth for the Add to Cart button. This keeps button and "(X available)"
                      // in sync.
                      final int? availableQty =
                          _getAvailableQuantityForSelection(currentPd, cartState);
                      final bool variantInStock =
                          availableQty != null && availableQty > 0;
                      final bool isOutOfStock = !variantInStock;
                      final bool canAdd = variantInStock && !isAdding;

                      developer.log(
                        '🔘 Button stock check -> availableQty=$availableQty, '
                        'variantInStock=$variantInStock, isOutOfStock=$isOutOfStock, canAdd=$canAdd',
                      );
                      developer.log('🧩 Selection check -> hasColorReq=$hasColorRequirement, colorSelected=$colorSelected, hasPrimaryReq=$hasPrimaryRequirement, primarySelected=$primarySelected, variantOk=$variantCombinationSelected');
                      return ElevatedButton(
                    onPressed: canAdd && !isOutOfStock
                        ? () async {
                            await HapticService.heavyImpact();
                            developer.log('🔘 Add to Cart button pressed!');
                            final latest =
                                context.read<ProductDetailsBloc>().state
                                    is ProductDetailsLoaded
                                ? (context.read<ProductDetailsBloc>().state
                                          as ProductDetailsLoaded)
                                      .productDetails
                                : productDetails;
                            developer.log('📱 Product ID Label: ${latest.id}');
                            developer.log(
                              '🎨 Selected Color: ${latest.selectedColor}',
                            );
                            // Prefer primary attribute selection from variantAttributeOptions
                            final latestPrimary = latest.variantAttributeOptions
                                .firstWhere(
                                  (o) =>
                                      o.attributeName.toLowerCase() ==
                                          latest.primaryVariantLabel
                                              .toLowerCase() ||
                                      o.attributeName.toLowerCase() == 'size',
                                  orElse: () => const VariantAttributeOption(
                                    attributeName: '',
                                    values: [],
                                    selectedValue: '',
                                  ),
                                );
                            final String latestPrimaryValue =
                                latestPrimary.selectedValue.isNotEmpty
                                ? latestPrimary.selectedValue
                                : latest.selectedSize;
                            developer.log(
                              '📏 Selected ${latest.primaryVariantLabel}: $latestPrimaryValue',
                            );

                            final currentState = context
                                .read<ProductDetailsBloc>()
                                .state;
                            developer.log(
                              '📱 Current bloc state: ${currentState.runtimeType}',
                            );

                            if (currentState is ProductDetailsLoaded) {
                              developer.log(
                                '✅ State is ProductDetailsLoaded, quantity: ${currentState.quantity}',
                              );
                              developer.log('🚀 Dispatching AddToCartEvent...');

                              // Resolve selected option IDs from the latest bloc state (avoid stale snapshot)
                              final blocState =
                                  context.read<ProductDetailsBloc>().state
                                      as ProductDetailsLoaded;
                              final latestPd = blocState.productDetails;

                              String selectedColorId = '';
                              String selectedSizeId = '';
                              // Map selected color to its id if applicable
                              if (latestPd.colorOptions.isNotEmpty) {
                                final selectedColor = latestPd.colorOptions
                                    .firstWhere(
                                      (c) => c.isSelected,
                                      orElse: () => latestPd.colorOptions.first,
                                    );
                                selectedColorId =
                                    selectedColor.name.toLowerCase() ==
                                        'default'
                                    ? ''
                                    : selectedColor.id;
                              }

                              // Map selected size to its id if applicable
                              if (latestPd.sizeOptions.isNotEmpty) {
                                final selectedSize = latestPd.sizeOptions.firstWhere(
                                  (s) => s.isSelected,
                                  orElse: () => latestPd.sizeOptions.first,
                                );
                                selectedSizeId = selectedSize.id;
                              }

                              context.read<ProductDetailsBloc>().add(
                                AddToCartEvent(
                                  productId: latestPd.id,
                                  colorId: selectedColorId,
                                  sizeId: selectedSizeId,
                                  quantity: currentState.quantity,
                                ),
                              );

                              developer.log(
                                '📤 AddToCartEvent dispatched successfully',
                              );

                              // Show success message and close bottom sheet
                              await HapticService.success();
                              AppSnackBar.success(
                                context,
                                AppLocalizations.of(context)!.itemAddedToCart,
                                actionLabel: AppLocalizations.of(context)!.cart,
                                onAction: () async {
                                  await HapticService.buttonClick();
                                  final rootNav = NavigationService.currentState;
                                  // Use root navigator only; avoid relying on local Navigator.of(context)
                                  if (rootNav != null) {
                                    // Optionally pop current route stack until first
                                    rootNav.popUntil((route) => route.isFirst);
                                    rootNav.push(
                                      MaterialPageRoute(
                                        builder: (_) => const CartPage(),
                                      ),
                                    );
                                  }
                                },
                              );

                              // Close the bottom sheet after a short delay
                              Future.delayed(
                                const Duration(milliseconds: 500),
                                () {
                                  if (context.mounted &&
                                      Navigator.of(context).canPop()) {
                                    Navigator.of(context).pop();
                                  }
                                },
                              );
                            } else {
                              developer.log(
                                '⚠️ State is not ProductDetailsLoaded: ${currentState.runtimeType}',
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOutOfStock
                          ? Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.5)
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: isOutOfStock
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6)
                          : Theme.of(context).colorScheme.onPrimary,
                      disabledBackgroundColor: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.5),
                      disabledForegroundColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveConstants.mdRadius,
                        ),
                      ),
                      elevation: isOutOfStock ? 0 : 0,
                      shadowColor: isOutOfStock
                          ? Colors.transparent
                          : Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.2),
                    ),
                        child: isAdding
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isOutOfStock
                                        ? Icons.block
                                        : Icons.shopping_cart_outlined,
                                    size: 20,
                                    color: isOutOfStock
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isOutOfStock
                                        ? AppLocalizations.of(context)!.outOfStock
                                        : (canAdd
                                            ? AppLocalizations.of(context)!.addToCart
                                            : AppLocalizations.of(context)!
                                                .selectOptions),
                                    style: AppFonts.getTextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isOutOfStock
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6)
                                          : Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                    ),
                                  ),
                                ],
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildQuantityButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onPressed,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: enabled && onPressed != null ? () async {
        await HapticService.selectionClick();
        onPressed();
      } : null,
      child: Container(
        width: ResponsiveConstants.xlDimension,
        height: ResponsiveConstants.xlDimension,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: enabled 
              ? colorScheme.onSurface.withValues(alpha: 0.7)
              : colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  /// Helper method to find the currently selected variant.
  /// Uses value_name matching (color, size, material, height) so inStock and quantity_available
  /// match the stock badge and BLoC state.
  VariantCombination? _findSelectedVariant(ProductDetails pd) {
    try {
      developer.log('🔍 Finding selected variant for:');
      developer.log('  - selectedSize: ${pd.selectedSize}');
      developer.log('  - selectedColor: ${pd.selectedColor}');
      developer.log('  - primaryVariantLabel: ${pd.primaryVariantLabel}');

      // 1) Match by value_name (same as BLoC): all 4 attributes -> one variant -> inStock & quantity_available
      final byValueName = pd.findVariantMatchingSelectionByValueName();
      if (byValueName != null) {
        developer.log('🔍 Found variant by value_name: variantId=${byValueName.variantId}, quantityAvailable=${byValueName.quantityAvailable}');
        return byValueName;
      }

      // 2) Fallback: build selected pairs using attribute names (try multiple variations)
      final Map<String, String> selectedByAttribute = {};
      
      // Add selected size/primary variant
      if (pd.selectedSize.isNotEmpty) {
        selectedByAttribute[pd.primaryVariantLabel] = pd.selectedSize;
        selectedByAttribute['size'] = pd.selectedSize;
        selectedByAttribute['SIZE'] = pd.selectedSize;
        selectedByAttribute['المقاس'] = pd.selectedSize;
      }
      
      // Add selected color (try all possible attribute name variations)
      if (pd.selectedColor.isNotEmpty) {
        selectedByAttribute['color'] = pd.selectedColor;
        selectedByAttribute['Color'] = pd.selectedColor;
        selectedByAttribute['COLOR'] = pd.selectedColor;
        selectedByAttribute['colour'] = pd.selectedColor;
        selectedByAttribute['Colour'] = pd.selectedColor;
        selectedByAttribute['COLOUR'] = pd.selectedColor;
        selectedByAttribute['اللون'] = pd.selectedColor;
        selectedByAttribute['color name'] = pd.selectedColor;
        selectedByAttribute['Color Name'] = pd.selectedColor;
        selectedByAttribute['COLOR NAME'] = pd.selectedColor;
      }
      
      // Add selected material if available
      if (pd.selectedMaterial != null && pd.selectedMaterial!.isNotEmpty) {
        selectedByAttribute['MATERIAL NAME'] = pd.selectedMaterial!;
        selectedByAttribute['material name'] = pd.selectedMaterial!;
        selectedByAttribute['Material Name'] = pd.selectedMaterial!;
      }
      
      // Add selected heel height if available
      if (pd.selectedHeelHeightCm != null) {
        final heightStr = pd.selectedHeelHeightCm!.toStringAsFixed(1);
        selectedByAttribute['HEIGHT'] = heightStr;
        selectedByAttribute['height'] = heightStr;
        selectedByAttribute['Height'] = heightStr;
      }
      
      // Add other selected attributes from variantAttributeOptions
      for (final opt in pd.variantAttributeOptions) {
        if (opt.selectedValue.isNotEmpty) {
          selectedByAttribute[opt.attributeName] = opt.selectedValue;
          // Also add uppercase version
          selectedByAttribute[opt.attributeName.toUpperCase()] = opt.selectedValue;
        }
      }
      
      developer.log('🔍 Searching with attributes: ${selectedByAttribute.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
      
      // Find matching variant - prioritize size and color, other attributes are optional
      final matching = pd.variantCombinations.where((combo) {
        // Must match size if provided
        if (pd.selectedSize.isNotEmpty) {
          bool sizeMatch = false;
          final sizeValue = combo.getAttributeValue('SIZE') ?? 
                           combo.getAttributeValue('size') ?? 
                           combo.getAttributeValue(pd.primaryVariantLabel);
          if (sizeValue != null && sizeValue.toLowerCase().trim() == pd.selectedSize.toLowerCase().trim()) {
            sizeMatch = true;
          }
          if (!sizeMatch) return false;
        }
        
        // Must match color if provided
        if (pd.selectedColor.isNotEmpty) {
          bool colorMatch = false;
          final colorValue = combo.getAttributeValue('COLOR NAME') ?? 
                            combo.getAttributeValue('color name') ?? 
                            combo.getAttributeValue('color') ?? 
                            combo.getAttributeValue('colour') ?? 
                            combo.getAttributeValue('اللون');
          if (colorValue != null && colorValue.toLowerCase().trim() == pd.selectedColor.toLowerCase().trim()) {
            colorMatch = true;
          }
          if (!colorMatch) return false;
        }
        
        // Try to match other attributes if they exist in the variant (optional)
        for (final entry in selectedByAttribute.entries) {
          // Skip size and color as we already checked them
          final keyLower = entry.key.toLowerCase();
          if (keyLower == 'size' || 
              keyLower == 'color' ||
              keyLower == 'colour' ||
              keyLower == 'color name' ||
              keyLower == 'اللون' ||
              entry.key == pd.primaryVariantLabel ||
              entry.key == 'SIZE' ||
              entry.key == 'COLOR NAME') {
            continue;
          }
          
          // For other attributes, check if they match (if present in variant)
          final v = combo.getAttributeValue(entry.key);
          if (v != null && v.toLowerCase().trim() != entry.value.toLowerCase().trim()) {
            return false;
          }
        }
        
        return true;
      }).toList();
      
      developer.log('🔍 Found ${matching.length} matching variant(s)');
      if (matching.isNotEmpty) {
        developer.log('🔍 First match: variantId=${matching.first.variantId}, quantityAvailable=${matching.first.quantityAvailable}');
        for (final attr in matching.first.attributes) {
          developer.log('  - ${attr.attributeName}: ${attr.valueName}');
        }
      }
      
      if (matching.length == 1) {
        return matching.first;
      }
      
      if (matching.length > 1) {
        developer.log('⚠️ Multiple variants matched (${matching.length}), using first one with highest stock');
        // If multiple matches, prefer the one with highest available stock
        matching.sort((a, b) {
          final qtyA = a.quantityAvailable ?? 0;
          final qtyB = b.quantityAvailable ?? 0;
          return qtyB.compareTo(qtyA); // Sort descending
        });
        developer.log('🔍 Selected variant: variantId=${matching.first.variantId}, quantityAvailable=${matching.first.quantityAvailable}');
        return matching.first;
      }
      
      // If no exact match, log for debugging
      developer.log('⚠️ No exact match found. Available variants:');
      for (final v in pd.variantCombinations.take(3)) {
        developer.log('  - variantId=${v.variantId}:');
        for (final attr in v.attributes) {
          developer.log('    ${attr.attributeName}: ${attr.valueName}');
        }
      }
      
      return null;
    } catch (e) {
      developer.log('⚠️ Error finding selected variant: $e');
      return null;
    }
  }

  /// Helper to compute the available quantity for the *current selection*.
  ///
  /// Primary source when `attribute_value_combinations` is present:
  /// - `ProductDetails.selectedVariantQuantityAvailable` (already cart-adjusted
  ///   by the BLoC on every attribute change).
  ///
  /// Fallback when normalized attribute data is missing:
  /// - Resolve the exact variant from `variantCombinations` and subtract the
  ///   current cart quantity.
  int? _getAvailableQuantityForSelection(
    ProductDetails pd,
    CartState cartState,
  ) {
    try {
      // 1) attribute_value_combinations: trust BLoC-computed quantity
      if (pd.attributeVariantCombinations.isNotEmpty ||
          pd.attributeValueCombinationsByKey.isNotEmpty) {
        final q = pd.selectedVariantQuantityAvailable;
        if (q != null) return q;
      }

      // 2) Fallback: variant_combinations, match full selection
      VariantCombination? selectedVariant = _findSelectedVariant(pd);
      selectedVariant ??= (pd.selectedColor.isNotEmpty &&
              pd.variantCombinations.isNotEmpty)
          ? pd.getFirstInStockVariantForColor(pd.selectedColor)
          : null;

      if (selectedVariant != null && selectedVariant.quantityAvailable != null) {
        int available = selectedVariant.quantityAvailable!.round();
        if (cartState is CartLoaded) {
          try {
            final existingItem = cartState.cartItems.firstWhere(
              (item) =>
                  item.product.id.toString() ==
                  selectedVariant!.variantId.toString(),
            );
            available = available - existingItem.quantity;
          } catch (_) {}
        }
        if (available >= 0) return available;
      }

      // 3) No stock info available
      return null;
    } catch (e) {
      developer.log('⚠️ Error in _getAvailableQuantityForSelection: $e');
      return null;
    }
  }
}

