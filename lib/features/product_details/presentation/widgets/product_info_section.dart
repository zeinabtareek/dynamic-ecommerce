import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/responsive_constants.dart';
import '../../domain/entities/product_details.dart';
import '../bloc/product_details_bloc.dart';
import 'about_product_section.dart';
import 'package:zalando_clone_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:zalando_clone_app/features/home/presentation/widgets/common/product_card.dart';
import 'package:zalando_clone_app/features/home/domain/entities/product.dart'
    as HomeProduct;
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../l10n/app_localizations.dart';
import 'color_selection_section.dart';

class ProductInfoSection extends StatelessWidget {
  final ProductDetails productDetails;

  const ProductInfoSection({super.key, required this.productDetails});

  @override
  Widget build(BuildContext context) {
    final currencyProvider = context.watch<CurrencyProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primary = colorScheme.primary;

    // Read latest ProductDetails from BLoC so UI always reflects the most
    // recent attribute/stock state (not only the initial props).
    // Also read lightweight loading flag so we can show a loader while
    // variant/attribute combinations are being recomputed.
    final pdState = context.watch<ProductDetailsBloc>().state;
    final bool isVariantFilterLoading =
        pdState is ProductDetailsLoaded ? pdState.isVariantFilterLoading : false;
    final ProductDetails currentProductDetails =
        pdState is ProductDetailsLoaded ? pdState.productDetails : productDetails;

    return SliverToBoxAdapter(
      child: Container(
        // Follow page background in dark mode, subtle surface tint in light mode.
        color: isDark ? colorScheme.background : colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top spacing
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
                  // Brand and Name
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentProductDetails.brand,
                              style: AppFonts.getTextStyle(
                                fontSize: ResponsiveConstants.mdFontSize,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            SizedBox(height: ResponsiveConstants.xsSpacing),
                            Text(
                              currentProductDetails.name,
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
                      // Stock badge - always from bloc so it updates on attribute change
                      BlocBuilder<ProductDetailsBloc, ProductDetailsState>(
                        buildWhen: (prev, curr) =>
                            curr is ProductDetailsLoaded &&
                            (prev is! ProductDetailsLoaded ||
                                prev.productDetails.inStock != curr.productDetails.inStock ||
                                prev.productDetails.selectedVariantQuantityAvailable !=
                                    curr.productDetails.selectedVariantQuantityAvailable),
                        builder: (context, state) {
                          if (state is ProductDetailsLoaded) {
                            return _StockBadge(productDetails: state.productDetails);
                          }
                          return _StockBadge(productDetails: productDetails);
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: ResponsiveConstants.mdSpacing),

                  // Price Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          currencyProvider.formatPrice(
                            currentProductDetails.price,
                            locale: Localizations.localeOf(context),
                          ),
                          style: AppFonts.getTextStyle(
                            fontSize: ResponsiveConstants.xlFontSize,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                      ),
                      if (currentProductDetails.originalPrice != null) ...[
                        SizedBox(width: ResponsiveConstants.smSpacing),
                        Flexible(
                          child: Text(
                              currencyProvider.formatPrice(
                                currentProductDetails.originalPrice!,
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
                      if (currentProductDetails.originalPrice != null &&
                          currentProductDetails.originalPrice! >
                              currentProductDetails.price &&
                          (currentProductDetails.discountPercentage ?? 0) > 0) ...[
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
                            '-${currentProductDetails.discountPercentage}%',
                            style: AppFonts.getTextStyle(
                              fontSize: ResponsiveConstants.smFontSize,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  if (currentProductDetails.originalPrice != null) ...[
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

            // Variant Attributes Card (Size, Material, Height, Width, etc.) - All Dynamic
            // Attributes are dynamically loaded from variant_attributes API response.
            // When a user selects an attribute value, it's stored in variantAttributeOptions.selectedValue
            // and used to filter variants via filterVariantsBySelectedAttributes() function.
            // Example: Selecting SIZE=36, COLOR=BLACK, MATERIALS=Synthetic Leather will filter
            // variant_combinations to find matching variants.
            if (currentProductDetails.variantAttributeOptions.where((attrOption) {
              final name = attrOption.attributeName.toLowerCase();
              return name != 'color' && name != 'colour' && name != 'اللون';
            }).isNotEmpty)
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
                child: isVariantFilterLoading
                    ? Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveConstants.lgSpacing,
                        ),
                        child: Center(
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                primary,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: currentProductDetails.variantAttributeOptions
                            .where((attrOption) {
                              final name =
                                  attrOption.attributeName.toLowerCase();
                              return name != 'color' &&
                                  name != 'colour' &&
                                  name != 'اللون' &&
                                  name != 'color name';
                            })
                            .map((attrOption) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: attrOption ==
                                          currentProductDetails
                                              .variantAttributeOptions
                                              .where((a) {
                                                final n = a.attributeName
                                                    .toLowerCase();
                                                return n != 'color' &&
                                                    n != 'colour' &&
                                                    n != 'اللون' &&
                                                    n != 'color name';
                                              })
                                              .last
                                      ? 0
                                      : ResponsiveConstants.mdSpacing,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      attrOption.attributeName,
                                      style: AppFonts.getTextStyle(
                                        fontSize:
                                            ResponsiveConstants.mdFontSize,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    SizedBox(
                                        height:
                                            ResponsiveConstants.smSpacing),
                                    _buildFullWidthAttributeButtons(
                                      context: context,
                                      values: attrOption.values,
                                      primary: primary,
                                      productDetails: currentProductDetails,
                                      attributeName: attrOption.attributeName,
                                    ),
                                  ],
                                ),
                              );
                            })
                            .toList(),
                      ),
              ),

            if (currentProductDetails.variantAttributeOptions.where((attrOption) {
              final name = attrOption.attributeName.toLowerCase();
              return name != 'color' &&
                  name != 'colour' &&
                  name != 'اللون' &&
                  name != 'color name';
            }).isNotEmpty)
              SizedBox(height: ResponsiveConstants.mdSpacing),

            // Color Selection Card (visual swatches)
            if (currentProductDetails.colorOptions.isNotEmpty) ...[
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
                child:
                    ColorSelectionSection(productDetails: currentProductDetails),
              ),
              SizedBox(height: ResponsiveConstants.mdSpacing),
            ],

            // About Product Card
            if (currentProductDetails.description.isNotEmpty) ...[
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
                  description: currentProductDetails.description,
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

            // Bottom spacing before recommendations
            SizedBox(height: ResponsiveConstants.mdSpacing),

            // Recommended Items (render only when available)
            BlocBuilder<HomeBloc, HomeState>(
              builder: (context, state) {
                if (state is HomeLoaded) {
                  final products = state.featuredProducts;
                  debugPrint('recommended products in product details page ${products.length}');
                  if (products.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final cardWidth = ResponsiveConstants.productDetailsCardWidth;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveConstants.smPadding,
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.recommendedForYou,
                          style: AppFonts.getTextStyle(
                            fontSize: ResponsiveConstants.mdFontSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      SizedBox(height: ResponsiveConstants.mdSpacing),
                      SizedBox(
                        height:
                            ResponsiveConstants.productDetailsCompactListHeight,
                        child: ListView.separated(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveConstants.smPadding,
                          ),
                          scrollDirection: Axis.horizontal,
                          itemCount: products.length,
                          separatorBuilder: (_, __) => SizedBox(
                            width:
                                ResponsiveConstants.productDetailsGridSpacing,
                          ),
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return SizedBox(
                              width: cardWidth,
                              child: ProductCard(
                                product: product,
                                isCompact: true,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }

                if (state is HomeInitial || state is HomeLoading) {
                  return const SizedBox.shrink();
                }

                if (state is HomeError) {
                  return const SizedBox.shrink();
                }

                return const SizedBox.shrink();
              },
            ),

            // Optional products (horizontal list)
            if (currentProductDetails.optionalProducts.isNotEmpty) ...[
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
                  itemCount: currentProductDetails.optionalProducts.length,
                  separatorBuilder: (_, __) => SizedBox(
                    width: ResponsiveConstants.productDetailsGridSpacing,
                  ),
                  itemBuilder: (context, index) {
                    final rp = currentProductDetails.optionalProducts[index];
                    final mapped = _mapRelatedToHomeProduct(
                      RelatedProduct(
                        id: rp.id,
                        name: rp.name,
                        price: rp.price,
                        imageUrl: rp.imageUrl,
                        type: 'template',
                      ),
                    );
                    final cardWidth =
                        ResponsiveConstants.productDetailsCardWidth;
                    return SizedBox(
                      width: cardWidth,
                      child: ProductCard(
                        product: mapped,
                        productType: rp.type,
                        isCompact: true,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: ResponsiveConstants.mdSpacing),
            ],

            // Accessories (horizontal list)
            if (currentProductDetails.accessoryProducts.isNotEmpty) ...[
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
                  itemCount: currentProductDetails.accessoryProducts.length,
                  separatorBuilder: (_, __) => SizedBox(
                    width: ResponsiveConstants.productDetailsGridSpacing,
                  ),
                  itemBuilder: (context, index) {
                    final rp = currentProductDetails.accessoryProducts[index];
                    final mapped = _mapRelatedToHomeProduct(
                      RelatedProduct(
                        id: rp.id,
                        name: rp.name,
                        price: rp.price,
                        imageUrl: rp.imageUrl,
                        type: 'variant',
                      ),
                    );
                    final cardWidth =
                        ResponsiveConstants.productDetailsCardWidth;
                    return SizedBox(
                      width: cardWidth,
                      child: ProductCard(
                        product: mapped,
                        productType: rp.type,
                        isCompact: true,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: ResponsiveConstants.mdSpacing),
            ],

            // Alternatives (horizontal list)
            if (currentProductDetails.alternativeProducts.isNotEmpty) ...[
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
                  itemCount: currentProductDetails.alternativeProducts.length,
                  separatorBuilder: (_, __) => SizedBox(
                    width: ResponsiveConstants.productDetailsGridSpacing,
                  ),
                  itemBuilder: (context, index) {
                    final rp = currentProductDetails.alternativeProducts[index];
                    final mapped = _mapRelatedToHomeProduct(
                      RelatedProduct(
                        id: rp.id,
                        name: rp.name,
                        price: rp.price,
                        imageUrl: rp.imageUrl,
                        type: 'template',
                      ),
                    );
                    final cardWidth =
                        ResponsiveConstants.productDetailsCardWidth;
                    return SizedBox(
                      width: cardWidth,
                      child: ProductCard(
                        product: mapped,
                        productType: rp.type,
                        isCompact: true,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: ResponsiveConstants.mdSpacing),
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

  // Enabled values for this attribute now come directly from the backend‑
  // provided availability on each value, instead of recomputing via a
  // color‑based loop. We simply respect `isAvailable` on each value.
  Set<String> enabledValuesForThisAttribute = {};
  String norm(String s) => s.toLowerCase().trim();
  enabledValuesForThisAttribute = values
      .where((v) => (v as VariantAttributeValue).isAvailable)
      .map((v) => norm((v as VariantAttributeValue).name))
      .toSet();

  // Auto-select first enabled value if no value is currently selected
  // This happens when color changes and we need to select from available options.
  // NOTE: This is used only to drive the canonical selectedValue in the BLoC,
  // not to allow multiple selections in the UI; the UI selection is taken from
  // a single source of truth (currentSelectedForAttr).
  String? valueToAutoSelect;
  final normalizedAttrName = norm(attributeName);
  if (enabledValuesForThisAttribute.isNotEmpty) {
    // Check if current selection is still enabled
    String? currentSelectedValue;
    for (final opt in productDetails.variantAttributeOptions) {
      if (norm(opt.attributeName) == normalizedAttrName && opt.selectedValue.isNotEmpty) {
        currentSelectedValue = opt.selectedValue;
        break;
      }
    }
    
    // If current selection is enabled, keep it; otherwise select first enabled value
    if (currentSelectedValue != null && 
        enabledValuesForThisAttribute.contains(norm(currentSelectedValue))) {
      valueToAutoSelect = currentSelectedValue;
    } else {
      // Find first value from the values list that is enabled
      for (final val in values) {
        final valObj = val as VariantAttributeValue;
        if (enabledValuesForThisAttribute.contains(norm(valObj.name))) {
          valueToAutoSelect = valObj.name;
          debugPrint(
            '🔴 [ProductInfoSection] valueToAutoSelect CHANGED: attr="$attributeName" '
            'currentSelectedValue="$currentSelectedValue" NOT in enabled → valueToAutoSelect="$valueToAutoSelect" '
            '(current selection became unavailable, UI will show different button as selected)',
          );
          break;
        }
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

        // Use the same logic as color: BLoC drives availability (selected = fill, available = outline).
        // Respect isAvailable from BLoC so that after any attribute click we show correct enabled/disabled.
        final bool effectiveIsAvailable = val.isAvailable;

        // Single source of truth: use option's selectedValue for ALL attributes (including size)
        // so chips always match the bottom sheet summary (which also uses opt.selectedValue).
        String? currentSelectedForAttr;
        for (final opt in productDetails.variantAttributeOptions) {
          if (norm(opt.attributeName) != normalizedAttrName) continue;
          currentSelectedForAttr = opt.selectedValue.isNotEmpty
              ? opt.selectedValue
              : (isSizeAttribute && productDetails.selectedSize.isNotEmpty
                  ? productDetails.selectedSize
                  : null);
          break;
        }
        bool isSelected;
        String selectionSource;
        if (currentSelectedForAttr != null &&
            (norm(val.name) == norm(currentSelectedForAttr) ||
                (val.displayName != null &&
                    val.displayName!.isNotEmpty &&
                    norm(val.displayName!) == norm(currentSelectedForAttr)))) {
          // The value that matches the BLoC's selectedValue (by name or displayName for Arabic).
          isSelected = true;
          selectionSource = 'BLoC_selectedValue';
        } else if (currentSelectedForAttr == null &&
            valueToAutoSelect != null &&
            norm(val.name) == norm(valueToAutoSelect) &&
            enabledValuesForThisAttribute.contains(norm(valueToAutoSelect))) {
          // No selection recorded yet for this attribute – use first enabled
          // as a temporary visual selection.
          isSelected = true;
          selectionSource = 'valueToAutoSelect_FALLBACK';
        } else if (shouldForceSelectedForSingleOption) {
          // Single-option attributes (non-color) look selected but are not
          // treated as "multi-select".
          isSelected = true;
          selectionSource = 'shouldForceSelectedForSingleOption';
        } else {
          // Ignore val.isSelected and any stale flags; UI follows only one
          // canonical selection per attribute.
          isSelected = false;
          selectionSource = 'none';
        }
        if (isSelected) {
          debugPrint(
            '🔴 [ProductInfoSection] Button SHOWING SELECTED: attr="$attributeName" value="${val.name}" (id=${val.id}) '
            'source=$selectionSource currentSelectedForAttr="$currentSelectedForAttr" valueToAutoSelect="$valueToAutoSelect"',
          );
        }

        final bool isTapEnabled = !isSelected && effectiveIsAvailable;

        // Same as color: selected = fill, available = outline; never grey out the selected value.
        final bool showDisabledVisual = !effectiveIsAvailable && !isSelected;
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
                      debugPrint('🎯 Attribute button tapped: $attributeName id=${val.id}');
                      context.read<ProductDetailsBloc>().add(
                        FilterVariantsByAttributeEvent(
                          productId: productDetails.id,
                          attributeValueId: val.id,
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
                val.displayNameOrName,
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
    // Use BLoC-computed values only (single source of truth).
    bool inStock = productDetails.inStock;
    final int? q = productDetails.selectedVariantQuantityAvailable;
    if (q != null && q <= 0) inStock = false;

    final bool low = q != null && q > 0 && q <= 5;

    final Color bg = inStock
        ? (low ? Colors.orange.shade600 : Colors.green.shade600)
        : Colors.red.shade600;
    final String label = inStock
        ? (low
              ? AppLocalizations.of(context)!.lowStock
              : AppLocalizations.of(context)!.inStock)
        : AppLocalizations.of(context)!.outOfStock;
    // No product count display; only show stock status label

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
  }
}

HomeProduct.Product _mapRelatedToHomeProduct(RelatedProduct rp) {
  return HomeProduct.Product(
    id: rp.id,
    name: rp.name,
    description: '',
    price: rp.price,
    originalPrice: null,
    images: rp.imageUrl.isNotEmpty ? [rp.imageUrl] : [],
    category: 'Recommended',
    brand: '',
    // Regardless of related type, ensure we open the variant API for better detail resolution
    type: 'variant',
    rating: 0,
    reviewCount: 0,
    isAvailable: true,
    sizes: const [],
    colors: const [],
    createdAt: DateTime.now(),
  );
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
