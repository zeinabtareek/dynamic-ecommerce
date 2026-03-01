import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/responsive_constants.dart';
import '../../domain/entities/product_details.dart';
import '../../domain/entities/product_details_card_preview.dart';
import '../bloc/product_details_bloc.dart';
import '../controllers/dynamic_variant_controller.dart' show DynamicVariantController, ValueState;
import '../widgets/dynamic_variant_selector.dart';
import 'about_product_section.dart';
import 'package:zalando_clone_app/features/home/presentation/widgets/common/product_card.dart';
import 'package:zalando_clone_app/features/home/domain/entities/product.dart'
    as HomeProduct;
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../utils/attribute_label_helper.dart';
import 'color_selection_section.dart';

class ProductInfoSection extends StatelessWidget {
  /// When null, [cardPreview] must be provided (loading state with preview data).
  final ProductDetails? productDetails;
  final ScrollController? scrollController;
  /// When product details are loading, pass card preview to show image/brand/title/price;
  /// sections without data show skeleton loaders until API responds.
  final ProductDetailsCardPreview? cardPreview;
  /// Called after user selects an attribute (e.g. to trigger variant lite fallback when normal API has no variant_combinations).
  final VoidCallback? onAfterAttributeSelected;

  const ProductInfoSection({
    super.key,
    this.productDetails,
    this.scrollController,
    this.cardPreview,
    this.onAfterAttributeSelected,
  }) : assert(productDetails != null || cardPreview != null,
            'Either productDetails or cardPreview must be provided');

  bool get _isPreviewMode => productDetails == null && cardPreview != null;

  @override
  Widget build(BuildContext context) {
    if (_isPreviewMode) {
      return _buildPreviewWithSkeletons(context);
    }
    return _buildFullContent(context, productDetails!);
  }

  SliverToBoxAdapter _buildPreviewWithSkeletons(BuildContext context) {
    final preview = cardPreview!;
    final currencyProvider = context.watch<CurrencyProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primary = colorScheme.primary;
    final formattedPrice = currencyProvider.formatPrice(preview.price);

    return SliverToBoxAdapter(
      child: Container(
        color: isDark ? colorScheme.background : colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: ResponsiveConstants.mdSpacing),
            // Header card with preview data; stock = skeleton
            Container(
              margin: EdgeInsets.symmetric(horizontal: ResponsiveConstants.smPadding),
              padding: EdgeInsets.all(ResponsiveConstants.mdPadding),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(ResponsiveConstants.mdRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preview.brand,
                              style: AppFonts.getTextStyle(
                                fontSize: ResponsiveConstants.mdFontSize,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            SizedBox(height: ResponsiveConstants.xsSpacing),
                            Text(
                              preview.productTitle,
                              style: AppFonts.getTextStyle(
                                fontSize: ResponsiveConstants.lgFontSize,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: ResponsiveConstants.smSpacing),
                      _shimmerLine(context, height: 24, width: 72, radius: 12),
                    ],
                  ),
                  SizedBox(height: ResponsiveConstants.mdSpacing),
                  Text(
                    formattedPrice,
                    style: AppFonts.getTextStyle(
                      fontSize: ResponsiveConstants.xlFontSize,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ResponsiveConstants.mdSpacing),
            _shimmerVariantAttributesCard(context),
            SizedBox(height: ResponsiveConstants.mdSpacing),
            _shimmerColorSelectionCard(context),
            SizedBox(height: ResponsiveConstants.mdSpacing),
            _shimmerAboutCard(context),
            SizedBox(height: ResponsiveConstants.lgSpacing),
          ],
        ),
      ),
    );
  }

  /// Shared skeleton content used for variant attributes (e.g. Size / other attributes).
  Widget _variantAttributesSkeletonContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _shimmerLine(context, height: 18, width: 80, radius: 8),
        SizedBox(height: ResponsiveConstants.mdSpacing),
        Row(
          children: [
            for (int i = 0; i < 5; i++) ...[
              if (i > 0) SizedBox(width: ResponsiveConstants.smSpacing),
              _shimmerLine(context, height: 40, width: 64, radius: 8),
            ],
          ],
        ),
      ],
    );
  }

  /// Skeleton that matches the variant attributes card (e.g. Size / attribute chips).
  Widget _shimmerVariantAttributesCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: ResponsiveConstants.smPadding),
      padding: EdgeInsets.all(ResponsiveConstants.mdPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(ResponsiveConstants.mdRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _variantAttributesSkeletonContent(context),
    );
  }

  /// Skeleton that matches the color selection card: "Color: [skeleton]" + list of image placeholders.
  Widget _shimmerColorSelectionCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    const double colorThumbSize = 100;
    const int placeholderCount = 4;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: ResponsiveConstants.smPadding),
      padding: EdgeInsets.all(ResponsiveConstants.mdPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(ResponsiveConstants.mdRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Color: [skeleton]" - same structure as real "Color: black"
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${l10n.color}: ',
                style: AppFonts.getTextStyle(
                  fontSize: ResponsiveConstants.mdFontSize,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              _shimmerLine(context, height: 16, width: 56, radius: 6),
            ],
          ),
          SizedBox(height: ResponsiveConstants.mdSpacing),
          // Skeleton image thumbnails below - like the real color images list
          SizedBox(
            height: colorThumbSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: placeholderCount,
              separatorBuilder: (_, __) => SizedBox(width: ResponsiveConstants.mdSpacing),
              itemBuilder: (_, index) {
                return _shimmerLine(
                  context,
                  height: colorThumbSize,
                  width: colorThumbSize,
                  radius: ResponsiveConstants.smRadius,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Skeleton that matches the about product card.
  Widget _shimmerAboutCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: ResponsiveConstants.smPadding),
      padding: EdgeInsets.all(ResponsiveConstants.mdPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(ResponsiveConstants.mdRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerLine(context, height: 18, width: 160, radius: 8),
          SizedBox(height: ResponsiveConstants.mdSpacing),
          _shimmerLine(context, height: 14, width: double.infinity, radius: 6),
          SizedBox(height: ResponsiveConstants.xsSpacing),
          _shimmerLine(context, height: 14, width: double.infinity, radius: 6),
          SizedBox(height: ResponsiveConstants.xsSpacing),
          _shimmerLine(context, height: 14, width: 220, radius: 6),
        ],
      ),
    );
  }

  Widget _shimmerLine(BuildContext context,
      {required double height, required double width, required double radius}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? colorScheme.outline.withValues(alpha: 0.3)
        : Colors.grey.shade300;
    final highlightColor =
        isDark ? colorScheme.outline.withValues(alpha: 0.5) : Colors.grey.shade100;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildFullContent(BuildContext context, ProductDetails productDetails) {
    final currencyProvider = context.watch<CurrencyProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primary = colorScheme.primary;

    final pdState = context.watch<ProductDetailsBloc>().state;
    final bool isVariantFilterLoading =
        pdState is ProductDetailsLoaded ? pdState.isVariantFilterLoading : false;

    return SliverToBoxAdapter(
      child: Container(
        color: isDark ? colorScheme.background : colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: ResponsiveConstants.mdSpacing),

            // Product Header Card (Brand, Name, Price, Stock)
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: ResponsiveConstants.smPadding,
              ),
              padding: EdgeInsets.all(ResponsiveConstants.mdPadding),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(
                  ResponsiveConstants.mdRadius,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.35 : 0.06,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productDetails.brand,
                              style: AppFonts.getTextStyle(
                                fontSize: ResponsiveConstants.mdFontSize,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            SizedBox(height: ResponsiveConstants.xsSpacing),
                            Text(
                              productDetails.name,
                              style: AppFonts.getTextStyle(
                                fontSize: ResponsiveConstants.lgFontSize,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: ResponsiveConstants.smSpacing),
                      _StockBadge(productDetails: productDetails),
                    ],
                  ),

                  SizedBox(height: ResponsiveConstants.mdSpacing),

                  Consumer<DynamicVariantController>(
                    builder: (context, variantController, _) {
                      final displayPrice = variantController.currentPrice > 0 
                          ? variantController.currentPrice 
                          : productDetails.price;
                      
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              currencyProvider.formatPrice(
                                displayPrice,
                                locale: Localizations.localeOf(context),
                              ),
                              style: AppFonts.getTextStyle(
                                fontSize: ResponsiveConstants.xlFontSize,
                                fontWeight: FontWeight.w700,
                                color: primary,
                              ),
                            ),
                          ),
                          if (productDetails.originalPrice != null) ...[
                            SizedBox(width: ResponsiveConstants.smSpacing),
                            Flexible(
                              child: Text(
                                currencyProvider.formatPrice(
                                  productDetails.originalPrice!,
                                  locale: Localizations.localeOf(context),
                                ),
                                style: AppFonts.getTextStyle(
                                  fontSize: ResponsiveConstants.mdFontSize,
                                  color: Colors.grey.shade600,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          ],
                          if (productDetails.originalPrice != null &&
                              productDetails.originalPrice! >
                                  displayPrice &&
                              (productDetails.discountPercentage ?? 0) > 0) ...[
                            SizedBox(width: ResponsiveConstants.smSpacing),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveConstants.smPadding,
                                vertical: ResponsiveConstants.xsPadding,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(
                                  ResponsiveConstants.xsRadius,
                                ),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                '-${productDetails.discountPercentage}%',
                                style: AppFonts.getTextStyle(
                                  fontSize: ResponsiveConstants.smFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                  if (productDetails.originalPrice != null) ...[
                    SizedBox(height: ResponsiveConstants.xsSpacing),
                    Text(
                      AppLocalizations.of(context)!.vatIncluded,
                      style: AppFonts.getTextStyle(
                        fontSize: ResponsiveConstants.xsFontSize,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: ResponsiveConstants.mdSpacing),

            // Dynamic Variant Attributes Card - Uses DynamicVariantSelector
            // This handles ALL attributes dynamically using attribute_id and value_id
            // No hardcoded logic - works with unlimited attributes
            Consumer<DynamicVariantController>(
              builder: (context, variantController, _) {
                // Filter out color attributes (handled separately with visual swatches)
                final nonColorAttributes = productDetails.variantAttributeOptions
                    .where((attrOption) {
                      final name = attrOption.attributeName.toLowerCase();
                      return name != 'color' &&
                          name != 'colour' &&
                          name != 'اللون' &&
                          name != 'color name';
                    })
                    .toList();

                if (nonColorAttributes.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(
                    horizontal: ResponsiveConstants.smPadding,
                  ),
                  padding: EdgeInsets.all(ResponsiveConstants.mdPadding),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(
                      ResponsiveConstants.mdRadius,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.35 : 0.06,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isVariantFilterLoading
                      ? _variantAttributesSkeletonContent(context)
                      : _DynamicVariantAttributesSection(
                          productDetails: productDetails,
                          variantController: variantController,
                          onAfterAttributeSelected: onAfterAttributeSelected,
                        ),
                );
              },
            ),

            SizedBox(height: ResponsiveConstants.mdSpacing),

            // Color Selection Card (visual swatches) - always show; use skeleton when no colors
            productDetails.colorOptions.isNotEmpty
                ? Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: ResponsiveConstants.smPadding,
                    ),
                    padding: EdgeInsets.all(ResponsiveConstants.mdPadding),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(
                        ResponsiveConstants.mdRadius,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.06,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ColorSelectionSection(
                      productDetails: productDetails,
                      scrollController: scrollController,
                      onAfterAttributeSelected: onAfterAttributeSelected,
                    ),
                  )
                : _shimmerColorSelectionCard(context),
            SizedBox(height: ResponsiveConstants.mdSpacing),

            // About Product Card
            if (productDetails.description.isNotEmpty) ...[
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: ResponsiveConstants.smPadding,
                ),
                padding: EdgeInsets.all(ResponsiveConstants.mdPadding),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(
                    ResponsiveConstants.mdRadius,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.06,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AboutProductSection(
                  description: productDetails.description,
                ),
              ),
              SizedBox(height: ResponsiveConstants.mdSpacing),
            ],

            // All Expandable Sections Grouped Together - COMMENTED OUT (keeping only recommended)

            // Customer Reviews Section - COMMENTED OUT
            /*
            _ExpandableSection(
              title: AppLocalizations.of(context)!.customerReviews,
              icon: Icons.rate_review,
              iconColor: Colors.orange.shade600,
              child: Container(
                padding: EdgeInsets.all(ResponsiveConstants.mdPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.orange, size: ResponsiveConstants.mdIconSize),
                        SizedBox(width: ResponsiveConstants.xsSpacing),
                        Text(
                          '${productDetails.rating}.0',
                          style: AppFonts.getTextStyle(fontSize: ResponsiveConstants.mdFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: ResponsiveConstants.smSpacing),
                        Text(
                          '(${productDetails.reviewCount} reviews)',
                          style: AppFonts.getTextStyle(fontSize: ResponsiveConstants.smFontSize,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveConstants.mdSpacing),
                    Text(
                      'Be the first to review this product!',
                      style: AppFonts.getTextStyle(fontSize: ResponsiveConstants.smFontSize,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: ResponsiveConstants.smSpacing),
            
            // Deals and Offers Section - COMMENTED OUT
            _ExpandableSection(
              title: AppLocalizations.of(context)!.dealsAndOffers,
              icon: Icons.local_fire_department,
              iconColor: Colors.red.shade600,
              child: DealsAndOffersSection(
                hasActiveDiscount: productDetails.hasDiscount,
                discountPercentage: (productDetails.discountPercentage ?? 0).toDouble(),
                dealEndTime: productDetails.hasDiscount ? DateTime.now().add(const Duration(hours: 24)) : null,
              ),
            ),

            SizedBox(height: ResponsiveConstants.smSpacing),
            
            // Delivery Information - COMMENTED OUT
            _ExpandableSection(
              title: AppLocalizations.of(context)!.deliveryAndReturns,
              icon: Icons.local_shipping,
              iconColor: Colors.green.shade600,
              child: DeliveryInfoSection(
                isFreeDeliveryEligible: productDetails.price >= 29.90,
                estimatedDelivery: 'Tomorrow, Dec 15',
                orderTotal: productDetails.price,
              ),
            ),

            SizedBox(height: ResponsiveConstants.smSpacing),
            
            // Product Care & Materials - COMMENTED OUT
            _ExpandableSection(
              title: AppLocalizations.of(context)!.productCareAndMaterials,
              icon: Icons.info_outline,
              iconColor: Colors.blue.shade600,
              child: ProductCareSection(
                countryOfOrigin: AppLocalizations.of(context)!.turkey,
                careInstructions: [productDetails.careInstructions],
                materials: productDetails.materialsList.isNotEmpty
                    ? productDetails.materialsList
                    : [productDetails.material],
              ),
            ),

            // Heel details - COMMENTED OUT
            if (productDetails.heelHeightCm != null || productDetails.heelType != null) ...[
              SizedBox(height: ResponsiveConstants.smSpacing),
              _ExpandableSection(
                title: AppLocalizations.of(context)!.heelDetails,
                icon: Icons.stairs_outlined,
                iconColor: Colors.purple.shade600,
                child: Container(
                  padding: EdgeInsets.all(ResponsiveConstants.mdPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (productDetails.heelType != null)
                        _keyValueRow(AppLocalizations.of(context)!.heelType, productDetails.heelType!),
                      if (productDetails.heelHeightCm != null)
                        _keyValueRow(AppLocalizations.of(context)!.heelHeight, '${productDetails.heelHeightCm!.toStringAsFixed(1)} ${AppLocalizations.of(context)!.cm}'),
                    ],
                  ),
                ),
              ),
            ],
            */

            // Optional products (horizontal list)
            if (productDetails.optionalProducts.isNotEmpty) ...[
              SizedBox(height: ResponsiveConstants.mdSpacing),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveConstants.smPadding,
                ),
                child: Text(
                  AppLocalizations.of(context)!.optionalItems,
                  style: AppFonts.getTextStyle(
                    fontSize: ResponsiveConstants.lgFontSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(height: ResponsiveConstants.mdSpacing),
              SizedBox(
                height: ResponsiveConstants.productDetailsCompactListHeight,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveConstants.smPadding,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: productDetails.optionalProducts.length,
                  separatorBuilder: (_, __) => SizedBox(
                    width: ResponsiveConstants.productDetailsGridSpacing,
                  ),
                  itemBuilder: (context, index) {
                    final rp = productDetails.optionalProducts[index];
                    final mapped = _mapRelatedToHomeProduct(rp);
                    final cardWidth =
                        ResponsiveConstants.productDetailsCardWidth;
                    return SizedBox(
                      width: cardWidth,
                      height: ResponsiveConstants.productDetailsCompactListHeight,
                      child: ProductCard(
                        product: mapped,
                        productType: rp.type,
                        isCompact: true,
                      ),
                    );
                  },
                ),
              ),
            ],

            // Accessories (horizontal list)
            if (productDetails.accessoryProducts.isNotEmpty) ...[
              SizedBox(height: ResponsiveConstants.mdSpacing),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveConstants.smPadding,
                ),
                child: Text(
                  AppLocalizations.of(context)!.accessories,
                  style: AppFonts.getTextStyle(
                    fontSize: ResponsiveConstants.lgFontSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(height: ResponsiveConstants.mdSpacing),
              SizedBox(
                height: ResponsiveConstants.productDetailsCompactListHeight,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveConstants.smPadding,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: productDetails.accessoryProducts.length,
                  separatorBuilder: (_, __) => SizedBox(
                    width: ResponsiveConstants.productDetailsGridSpacing,
                  ),
                  itemBuilder: (context, index) {
                    final rp = productDetails.accessoryProducts[index];
                    final mapped = _mapRelatedToHomeProduct(rp);
                    final cardWidth =
                        ResponsiveConstants.productDetailsCardWidth;
                    return SizedBox(
                      width: cardWidth,
                      height: ResponsiveConstants.productDetailsCompactListHeight,
                      child: ProductCard(
                        product: mapped,
                        productType: rp.type,
                        isCompact: true,
                      ),
                    );
                  },
                ),
              ),
            ],

            // Alternatives (horizontal list)
            if (productDetails.alternativeProducts.isNotEmpty) ...[
              SizedBox(height: ResponsiveConstants.mdSpacing),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveConstants.smPadding,
                ),
                child: Text(
                  AppLocalizations.of(context)!.alternativeItems,
                  style: AppFonts.getTextStyle(
                    fontSize: ResponsiveConstants.lgFontSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(height: ResponsiveConstants.mdSpacing),
              SizedBox(
                height: ResponsiveConstants.productDetailsCompactListHeight,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveConstants.smPadding,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: productDetails.alternativeProducts.length,
                  separatorBuilder: (_, __) => SizedBox(
                    width: ResponsiveConstants.productDetailsGridSpacing,
                  ),
                  itemBuilder: (context, index) {
                    final rp = productDetails.alternativeProducts[index];
                    final mapped = _mapRelatedToHomeProduct(rp);
                    final cardWidth =
                        ResponsiveConstants.productDetailsCardWidth;
                    return SizedBox(
                      width: cardWidth,
                      height: ResponsiveConstants.productDetailsCompactListHeight,
                      child: ProductCard(
                        product: mapped,
                        productType: rp.type,
                        isCompact: true,
                      ),
                    );
                  },
                ),
              ),
            ],

            // Extra bottom spacing
            SizedBox(height: ResponsiveConstants.lgSpacing),
          ],
        ),
      ),
    );
  }

  // _sizeHint helper removed along with size recommendation UI
}

/// Helper function to map RelatedProduct to HomeProduct.Product for ProductCard
HomeProduct.Product _mapRelatedToHomeProduct(RelatedProduct rp) {
  return HomeProduct.Product(
    id: rp.id,
    name: rp.name,
    description: '',
    price: rp.price,
    originalPrice: null,
    images: rp.imageUrl.isNotEmpty ? [rp.imageUrl] : [],
    category: '',
    brand: rp.brand,
    type: rp.type,
    rating: 0,
    reviewCount: 0,
    isAvailable: true,
    sizes: const [],
    colors: const [],
    createdAt: DateTime.now(),
  );
}

/// Dynamic variant attributes section that uses attribute_id and value_id
/// Works with unlimited attributes - no hardcoded logic
class _DynamicVariantAttributesSection extends StatelessWidget {
  final ProductDetails productDetails;
  final DynamicVariantController variantController;
  final VoidCallback? onAfterAttributeSelected;

  const _DynamicVariantAttributesSection({
    required this.productDetails,
    required this.variantController,
    this.onAfterAttributeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;

    // Filter out color attributes (handled separately)
    final nonColorAttributes = productDetails.variantAttributeOptions
        .where((attrOption) {
          final name = attrOption.attributeName.toLowerCase();
          return name != 'color' &&
              name != 'colour' &&
              name != 'اللون' &&
              name != 'color name';
        })
        .toList();

    if (nonColorAttributes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: nonColorAttributes.map((attrOption) {
        final attributeId = int.tryParse(attrOption.attributeId ?? '');
        
        if (attributeId == null) {
          debugPrint('⚠️ _DynamicVariantAttributesSection: Skipping attribute "${attrOption.attributeName}" - no valid attribute_id');
          return const SizedBox.shrink();
        }

        // Get currently selected value for this attribute from controller
        final selectedValueId = variantController.selectedAttributes[attributeId];
        
        debugPrint('🎨 _DynamicVariantAttributesSection: Attribute "${attrOption.attributeName}" (id: $attributeId)');
        debugPrint('   Selected value_id: $selectedValueId');

        return Container(
          margin: EdgeInsets.only(
            bottom: attrOption == nonColorAttributes.last
                ? 0
                : ResponsiveConstants.mdSpacing,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizedAttributeLabel(context, attrOption.apiAttributeName?.isNotEmpty == true
                    ? attrOption.apiAttributeName!
                    : attrOption.attributeName),
                style: AppFonts.getTextStyle(
                  fontSize: ResponsiveConstants.mdFontSize,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: ResponsiveConstants.smSpacing),
              Wrap(
                spacing: ResponsiveConstants.smSpacing,
                runSpacing: ResponsiveConstants.smSpacing,
                children: attrOption.values.map((value) {
                  final valueId = int.tryParse(value.id);
                  
                  if (valueId == null) {
                    debugPrint('⚠️ _DynamicVariantAttributesSection: Skipping value "${value.name}" - no valid value_id');
                    return const SizedBox.shrink();
                  }
                  
                  // On initial load, when the controller has not yet built
                  // selectedAttributes for this attribute, fall back to the
                  // model's isSelected flag (set from `selected_variant` in
                  // the first API response).
                  final isSelected = selectedValueId != null
                      ? selectedValueId == valueId
                      : value.isSelected;
                  if (selectedValueId == null && value.isSelected) {
                    debugPrint(
                      '✅ [Step 4 - UI] Chip "${attrOption.attributeName}" = "${value.name}" '
                      'selected via model (selected_variant); controller had no selection yet',
                    );
                  }
                  
                  // Get the state of this value (three-state logic)
                  final valueState = variantController.getValueState(attributeId, valueId);
                  
                  // Determine button properties based on state
                  final isFullyAvailable = valueState == ValueState.fullyAvailable;
                  final existsButIncompatible = valueState == ValueState.existsButIncompatible;
                  final doesNotExist = valueState == ValueState.doesNotExist;
                  
                  // Button is enabled if:
                  // - Not selected AND (fully available OR exists but incompatible)
                  // - Only disabled if value does not exist at all
                  final isEnabled = !isSelected && !doesNotExist;
                  
                  // Determine colors and styles based on state
                  Color backgroundColor;
                  Color borderColor;
                  Color textColor;
                  double borderWidth;
                  double textOpacity;
                  
                  // STANDARDIZED BUTTON STATES - Only 3 clear states:
                  // 1. Selected: Orange background + White text
                  // 2. Available (Not Selected): White background + Orange border + Orange text
                  // 3. Unavailable: Light gray background + Gray text + Not clickable
                  
                  if (isSelected) {
                    // ✅ STATE 1: Selected State
                    // Orange background, white text, no ambiguity
                    backgroundColor = primary;
                    borderColor = primary;
                    textColor = colorScheme.onPrimary; // White text
                    borderWidth = 2;
                    textOpacity = 1.0;
                  } else if (doesNotExist) {
                    // ✅ STATE 3: Unavailable / Hidden State
                    // Light gray background, gray text, not clickable
                    backgroundColor = Colors.grey.shade200; // Light gray background
                    borderColor = Colors.grey.shade400; // Light gray border
                    textColor = Colors.grey.shade600; // Gray text
                    borderWidth = 1;
                    textOpacity = 1.0; // Full opacity but gray color
                  } else {
                    // ✅ STATE 2: Available (Not Selected) State
                    // Transparent background, orange border, orange text, clickable
                    // This applies to both fullyAvailable and existsButIncompatible
                    // User can click to change selection even if incompatible
                    backgroundColor = Colors.transparent; // Transparent background
                    borderColor = primary; // Orange border
                    textColor = primary; // Orange text
                    borderWidth = 1;
                    textOpacity = 1.0;
                  }
                  
                  return GestureDetector(
                    onTap: isEnabled
                        ? () {
                            debugPrint('🎯 Selecting attribute $attributeId → value $valueId (${value.name})');
                            debugPrint('   State: $valueState');
                            // Sync controller with latest product details and variant_combinations from normal API
                            // (kept separate; used for matching on attribute click)
                            final state = context.read<ProductDetailsBloc>().state;
                            if (state is ProductDetailsLoaded) {
                              variantController.updateProductDetails(state.productDetails);
                              variantController.setVariantCombinationsForMatching(state.variantCombinationsFromNormalApi);
                            }
                            variantController.selectAttributeValue(attributeId, valueId);
                            onAfterAttributeSelected?.call();
                          }
                        : null,
                    behavior: isEnabled ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
                    child: Opacity(
                      opacity: textOpacity,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveConstants.mdPadding,
                          vertical: ResponsiveConstants.smPadding,
                        ),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          border: Border.all(
                            color: borderColor,
                            width: borderWidth,
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveConstants.smRadius,
                          ),
                        ),
                        child: Text(
                          value.name,
                          style: AppFonts.getTextStyle(
                            fontSize: ResponsiveConstants.mdFontSize,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// Removed card wrapper (requested) – kept simple typography + spacing paddings above

Widget _buildFullWidthAttributeButtons({
  required BuildContext context,
  required List<dynamic> values,
  required Color primary,
  required ProductDetails productDetails,
  required String attributeName,
}) {
  if (values.isEmpty) return const SizedBox.shrink();

  final attrNameLower = attributeName.toLowerCase();
  final colorScheme = Theme.of(context).colorScheme;
  // If an attribute has ONLY one option, or only ONE available option,
  // make it unclickable (no meaningful alternative to choose).
  final bool isSingleOptionAttribute = values.length == 1;
  final int availableCount = values
      .where((v) => (v as VariantAttributeValue).isAvailable)
      .length;
  final bool onlyOneAvailableAttribute = availableCount == 1;
  // Still used to decide if there is a *meaningful* alternative to tap,
  // but we no longer use it to grey out the *selected* value visually.
  final bool shouldBeUnclickable =
      isSingleOptionAttribute || onlyOneAvailableAttribute;

  // Auto-select visual state for single-option non-color attributes
  final bool shouldForceSelectedForSingleOption =
      isSingleOptionAttribute &&
      attrNameLower != 'color' &&
      attrNameLower != 'colour' &&
      attrNameLower != 'color name' &&
      attrNameLower != 'اللون';

  // CRITICAL: Build enabled values based on the **current selection** across all
  // attributes (color, size, material, height, etc.), not only by color.
  //
  // This uses ProductDetails.getEnabledValuesForCurrentSelection(), which:
  // - Filters variant_combinations by the current selection
  // - Keeps only in‑stock variants
  // - Collects all attribute/value pairs from those variants
  //
  // This prevents us from "guessing" combinations and ensures that a button is
  // enabled if and only if there exists at least one in‑stock variant that is
  // compatible with the current selection and contains this value.
  final Map<String, Set<String>> enabledAttributesForSelection =
      productDetails.getEnabledValuesForCurrentSelection();

  // Check if we have any selections beyond just color
  bool hasNonColorSelections = productDetails.selectedSize.isNotEmpty ||
      productDetails.variantAttributeOptions.any((opt) {
        final attrLower = opt.attributeName.toLowerCase();
        final isColorAttr = attrLower.contains('color') ||
            attrLower == 'colour' ||
            attrLower == 'اللون';
        return !isColorAttr && opt.selectedValue.isNotEmpty;
      });

  // Fallback (only for truly initial state with NO selections): when nothing
  // is selected except maybe color, use color‑based logic. However, if we have
  // any non-color selections (size, material, height, etc.), we should NOT use
  // the color fallback even if enabledAttributesForSelection is empty, because
  // that means the current combination has no stock and we should rely on
  // val.isAvailable fallback instead (handled later in effectiveIsAvailable).
  final Map<String, Set<String>> enabledAttributesForColor =
      (enabledAttributesForSelection.isEmpty &&
              productDetails.variantCombinations.isNotEmpty &&
              productDetails.selectedColor.isNotEmpty &&
              !hasNonColorSelections) // Only use color fallback if NO non-color selections exist
          ? productDetails
              .getEnabledAttributeValuesForColor(productDetails.selectedColor)
          : const <String, Set<String>>{};

  // Get the enabled values for this specific attribute
  // Try multiple attribute name variations to match (case-insensitive)
  Set<String> enabledValuesForThisAttribute = {};
  String norm(String s) => s.toLowerCase().trim();
  final normalizedAttrName = norm(attributeName);

  // 1) Prefer the full‑selection map (color + size + material + height, etc.)
  for (final entry in enabledAttributesForSelection.entries) {
    final normalizedEntryName = norm(entry.key);
    if (normalizedEntryName == normalizedAttrName) {
      enabledValuesForThisAttribute =
          entry.value.map((v) => norm(v)).toSet();
      debugPrint(
          '✅ Matched attribute "${entry.key}" with UI attribute "$attributeName" from full selection → enabled values: ${enabledValuesForThisAttribute.toList()}');
      break;
    }
  }

  // 2) If nothing found yet, fall back to color‑based enabled map
  if (enabledValuesForThisAttribute.isEmpty &&
      enabledAttributesForColor.isNotEmpty) {
    for (final entry in enabledAttributesForColor.entries) {
      final normalizedEntryName = norm(entry.key);
      // Match by exact name or if attribute name contains the entry key or vice versa
      // Also handle common variations like "MATERIAL NAME" vs "MATERIALS", "MATERIAL" vs "MATERIAL NAME"
      final bool nameMatches = normalizedEntryName == normalizedAttrName ||
          normalizedEntryName.contains(normalizedAttrName) ||
          normalizedAttrName.contains(normalizedEntryName);
      
      // Special handling for material attributes
      final bool isMaterialMatch = 
          (normalizedEntryName.contains('material') && normalizedAttrName.contains('material')) ||
          (normalizedEntryName == 'materials' && normalizedAttrName == 'material name') ||
          (normalizedEntryName == 'material name' && normalizedAttrName == 'materials');
      
      if (nameMatches || isMaterialMatch) {
        // Normalize all values for comparison
        enabledValuesForThisAttribute = entry.value.map((v) => norm(v)).toSet();
        debugPrint(
            '✅ Matched attribute "${entry.key}" with UI attribute "$attributeName" from color map → enabled values: ${enabledValuesForThisAttribute.toList()}');
        break;
      }
    }
  }

  // Auto-select ONLY when there is **no prior user selection** for this attribute.
  // If the user already picked a value (e.g. SIZE=36) we always preserve it,
  // even if it becomes "not available" for the newly selected color. In that
  // case the chip will stay visually selected but disabled, and the CTA will
  // show "Out of stock" for the current combination.
  String? valueToAutoSelect;
  
  // First, check if there's a current selection in variantAttributeOptions
  String? currentSelectedValue;
  for (final opt in productDetails.variantAttributeOptions) {
    final optAttrName = opt.apiAttributeName?.isNotEmpty == true 
        ? opt.apiAttributeName! 
        : opt.attributeName;
    final optAttrNameNormalized = norm(optAttrName);
    
    // Match by exact name or if attribute name contains the entry key or vice versa
    final bool nameMatches = optAttrNameNormalized == normalizedAttrName ||
        optAttrNameNormalized.contains(normalizedAttrName) ||
        normalizedAttrName.contains(optAttrNameNormalized);
    
    // Special handling for material attributes
    final bool isMaterialMatch = 
        (optAttrNameNormalized.contains('material') && normalizedAttrName.contains('material')) ||
        (optAttrNameNormalized == 'materials' && normalizedAttrName == 'material name') ||
        (optAttrNameNormalized == 'material name' && normalizedAttrName == 'materials');
    
    if ((nameMatches || isMaterialMatch) && opt.selectedValue.isNotEmpty) {
      currentSelectedValue = opt.selectedValue;
      debugPrint('📌 Found selectedValue for "$attributeName" (matched with "$optAttrName"): "$currentSelectedValue"');
      break;
    }
  }
  
  if (currentSelectedValue != null) {
    // Always respect the user's current selection, even if it is not part of
    // enabledValuesForThisAttribute. Availability will be reflected separately
    // via `effectiveIsAvailable` (disabled style + Out of stock CTA).
    valueToAutoSelect = currentSelectedValue;
    debugPrint(
      '✅ Preserving user selection "$currentSelectedValue" for "$attributeName" '
      '(availability will be handled visually).',
    );
  } else if (enabledValuesForThisAttribute.isNotEmpty) {
    // No previous selection for this attribute: auto‑select the first enabled
    // value as a sensible default.
    for (final val in values) {
      final valObj = val as VariantAttributeValue;
      if (enabledValuesForThisAttribute.contains(norm(valObj.name))) {
        valueToAutoSelect = valObj.name;
        debugPrint(
          '✅ Auto‑selecting first enabled value "${valObj.name}" for "$attributeName" '
          '(no prior user selection).',
        );
        break;
      }
    }
  }

  // Container takes full width, buttons wrap inside
  return SizedBox(
    width: double.infinity,
    child: Wrap(
      spacing: ResponsiveConstants.smSpacing,
      runSpacing: ResponsiveConstants.smSpacing,
      children: values.map((value) {
        final val = value as VariantAttributeValue;
        // Detect if this attribute represents SIZE (primary variant)
        final bool isSizeAttribute =
            attrNameLower == 'size' ||
            attrNameLower == productDetails.primaryVariantLabel.toLowerCase() ||
            attrNameLower.contains('size');

        // UX IMPROVEMENT: Enable buttons liberally - let users interact with all options.
        // Only disable if the value doesn't exist in ANY variant. Stock validation happens at cart level.
        // This allows users to explore combinations freely, and we show "Out of Stock" CTA when needed.
        bool effectiveIsAvailable = val.isAvailable;
        
        // If value exists in any variant, always enable it (even if not compatible with current selection)
        // The "Out of Stock" CTA will handle stock validation at the cart level

        // Selection rule:
        // - NEVER override the user's explicit selection to "fix" stock.
        // - valueToAutoSelect is only used when there was **no prior selection**
        //   for this attribute (initial/default state).
        // - Availability is handled separately via `effectiveIsAvailable` and
        //   drives disabled styling / CTA state.
        bool isSelected = false;
        
        // Normalize the value name once for use in both Priority 1 and Priority 2
        final normalizedValName = norm(val.name);
        
        // Priority 1: If valueToAutoSelect is set and this value matches it, select it
        if (valueToAutoSelect != null) {
          final normalizedAutoSelect = norm(valueToAutoSelect!);
          if (normalizedValName == normalizedAutoSelect) {
            isSelected = true;
            debugPrint(
              '✅ Auto‑selecting "$normalizedValName" for attribute "$attributeName" '
              '(no prior user selection).',
            );
          }
        }
        
        // Priority 2: If not auto-selected, check current selection
        if (!isSelected) {
          if (isSizeAttribute) {
            // For SIZE: Use current selectedSize regardless of availability.
            // We want the chip to stay selected when the user picked 36 and
            // then changed color to RED, even if 36+RED is out of stock.
            if (productDetails.selectedSize.isNotEmpty &&
                norm(val.name) == norm(productDetails.selectedSize)) {
              isSelected = true;
            }
          } else {
            // For non-SIZE: Check variantAttributeOptions.selectedValue first (most reliable)
            String? currentSelectedValue;
            for (final opt in productDetails.variantAttributeOptions) {
              final optAttrName = opt.apiAttributeName?.isNotEmpty == true 
                  ? opt.apiAttributeName! 
                  : opt.attributeName;
              final optAttrNameNormalized = norm(optAttrName);
              
              // Match by exact name or if attribute name contains the entry key or vice versa
              final bool nameMatches = optAttrNameNormalized == normalizedAttrName ||
                  optAttrNameNormalized.contains(normalizedAttrName) ||
                  normalizedAttrName.contains(optAttrNameNormalized);
              
              // Special handling for material attributes
              final bool isMaterialMatch = 
                  (optAttrNameNormalized.contains('material') && normalizedAttrName.contains('material')) ||
                  (optAttrNameNormalized == 'materials' && normalizedAttrName == 'material name') ||
                  (optAttrNameNormalized == 'material name' && normalizedAttrName == 'materials');
              
              if ((nameMatches || isMaterialMatch) && opt.selectedValue.isNotEmpty) {
                currentSelectedValue = opt.selectedValue;
                break;
              }
            }
            
            // Check if this value matches the selectedValue from variantAttributeOptions
            if (currentSelectedValue != null &&
                norm(val.name) == norm(currentSelectedValue)) {
              isSelected = true;
              debugPrint(
                '✅ Marking "$normalizedValName" as selected for attribute "$attributeName" '
                '(from variantAttributeOptions.selectedValue="$currentSelectedValue")',
              );
            }
            // Fallback to BLoC's selection if still enabled
            else if (val.isSelected || shouldForceSelectedForSingleOption) {
              isSelected = true;
            }
          }
        }

        // Interaction rule:
        // - Unclickable when already selected OR not enabled for current color.
        //   We still keep the "no meaningful alternative" UX, but that no longer
        //   affects the visual state of the *enabled* selected value.
        final bool isTapEnabled = !isSelected && effectiveIsAvailable;

        // Grey disabled look purely based on effective availability.
        // If a value is not part of the enabled set for this color, it is
        // fully disabled (unclickable) even if it is currently selected –
        // this visually communicates "you chose this, but it's out of stock".
        final bool showDisabledVisual = !effectiveIsAvailable;
        final bool isEnabledChoice =
            !showDisabledVisual && effectiveIsAvailable == true;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isTapEnabled
                ? () {
                    if (isSizeAttribute) {
                      debugPrint('🎯 Size button tapped: ${val.name} (id: ${val.id})');
                      context.read<ProductDetailsBloc>().add(
                        SelectSizeEvent(
                          productId: productDetails.id,
                          sizeId: val.id,
                        ),
                      );
                    } else {
                      // Store selected attribute value and filter variants
                      // The selected value is stored in variantAttributeOptions and used to
                      // filter variant_combinations that match all selected attributes.
                      debugPrint('🎯 Attribute button tapped: $attributeName="${val.name}" (id: ${val.id})');
                      context.read<ProductDetailsBloc>().add(
                        FilterVariantsByAttributeEvent(
                          productId: productDetails.id,
                          attributeName: attributeName,
                          attributeValue: val.name,
                        ),
                      );
                    }
                  }
                : null,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveConstants.mdPadding,
                vertical: ResponsiveConstants.smPadding,
              ),
              decoration: BoxDecoration(
                // Background:
                // - disabled/unavailable: grey (like PRINTED COVER)
                // - selected: solid primary
                // - other choices: neutral surface
                color: showDisabledVisual
                    ? colorScheme.surfaceContainerHighest
                    : (isSelected
                        ? primary
                        : colorScheme.surface.withValues(alpha: 0.5)),
                // Border:
                // - disabled/unavailable: grey outline
                // - selected: primary
                // - enabled (but not selected): primary border
                border: Border.all(
                  color: showDisabledVisual
                      ? colorScheme.outline.withValues(alpha: 0.4)
                      : (isSelected
                          ? primary
                          : (isEnabledChoice
                              ? primary
                              : colorScheme.outline.withValues(alpha: 0.4))),
                  width: showDisabledVisual ? 1 : (isSelected ? 2 : 1),
                ),
                borderRadius: BorderRadius.circular(
                  ResponsiveConstants.smRadius,
                ),
              ),
              child: Text(
                val.name,
                style: AppFonts.getTextStyle(
                  fontSize: ResponsiveConstants.mdFontSize,
                  fontWeight: FontWeight.w600,
                  // Text color:
                  // - disabled: grey
                  // - selected: onPrimary
                  // - enabled (not selected): primary text
                  // - unavailable: faint grey
                  color: showDisabledVisual
                      ? colorScheme.onSurface.withValues(alpha: 0.5)
                      : (isSelected
                          ? colorScheme.onPrimary
                          : (isEnabledChoice
                              ? primary
                              : colorScheme.onSurface.withValues(alpha: 0.5))),
                ),
              ),
            ),
        );
      }).toList(),
    ),
  );
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.productDetails});
  final ProductDetails productDetails;

  @override
  Widget build(BuildContext context) {
    return Consumer<DynamicVariantController>(
      builder: (context, variantController, _) {
        // Use dynamic variant controller for stock status
        final inStock = variantController.inStock;
        final q = variantController.quantityAvailable;
        
        final bool low = q > 0 && q <= 5;

        final Color bg = inStock
            ? (low ? Colors.orange.shade600 : Colors.green.shade600)
            : Colors.red.shade600;
        
        // Build label with quantity if available
        String label;
        if (!inStock) {
          label = AppLocalizations.of(context)!.outOfStock;
        } else if (low) {
          label = '${AppLocalizations.of(context)!.lowStock} ($q)';
        } else {
          label = '${AppLocalizations.of(context)!.inStock} ($q)';
        }

        debugPrint('📊 _StockBadge: variant_id=${variantController.variantId}, inStock=$inStock, qty=$q, label="$label"');

        return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveConstants.mdPadding,
        vertical: ResponsiveConstants.xsPadding,
      ),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bg.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inStock ? Icons.check_circle : Icons.error_outline,
            color: bg,
            size: 18,
          ),
          SizedBox(width: 8),
          Text(
            label,
            style: AppFonts.getTextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: ResponsiveConstants.smPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveConstants.mdRadius),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with expand/collapse button
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(ResponsiveConstants.mdRadius),
            ),
            child: Padding(
              padding: EdgeInsets.all(ResponsiveConstants.mdPadding),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(ResponsiveConstants.xsPadding),
                    decoration: BoxDecoration(
                      color: widget.iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        ResponsiveConstants.smRadius,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: ResponsiveConstants.mdIconSize,
                    ),
                  ),
                  SizedBox(width: ResponsiveConstants.smSpacing),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppFonts.getTextStyle(
                        fontSize: ResponsiveConstants.mdFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey.shade600,
                      size: ResponsiveConstants.mdIconSize,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content with smooth animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _isExpanded ? null : 0,
            child: _isExpanded
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(ResponsiveConstants.mdRadius),
                      ),
                    ),
                    child: widget.child,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
