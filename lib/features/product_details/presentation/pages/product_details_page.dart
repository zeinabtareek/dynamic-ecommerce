import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/responsive_constants.dart';
import '../bloc/product_details_bloc.dart';
import '../../domain/entities/product_details.dart';
import '../widgets/collapsible_image_section_widget.dart';
import '../widgets/product_info_section.dart';
import '../widgets/product_details_shimmer.dart';
import '../widgets/add_to_cart_bottom_sheet.dart';
import '../../domain/entities/product_details_card_preview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/dynamic_variant_controller.dart';
import 'package:share_plus/share_plus.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/navigation/navigation_service.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../cart/presentation/pages/cart_page.dart';
import '../../../cart/presentation/widgets/cart_button_with_badge.dart';
import '../../../cart/presentation/bloc/cart_bloc.dart';
import '../../../../core/services/app_localization_service.dart';
import '../../../../core/services/language_service.dart';
import '../widgets/color_selection_widget.dart' show ColorSelectionSkeleton;

class ProductDetailsPage extends StatefulWidget {
  final String productId;
  final String productType;
  final bool openAddToCart;
  /// Preview data from the product card (image, brand, title, price)
  /// to show immediately while full details are loading.
  final ProductDetailsCardPreview? cardPreview;

  const ProductDetailsPage({
    super.key,
    required this.productId,
    this.productType = 'variant', // Default to variant for backward compatibility
    this.openAddToCart = false,
    this.cardPreview,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage>
    with AutomaticKeepAliveClientMixin<ProductDetailsPage> {
  late PageController _pageController;
  late ScrollController _scrollController;
  late DynamicVariantController _variantController;
  late final AppLocalizationService _localizationService;
  String? _lastLanguageCode;
  bool _isControllerInitialized = false;
  bool _hasOpenedAddToCartFromRoute = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _localizationService = AppLocalizationService();
    _pageController = PageController();
    _scrollController = ScrollController();
    _variantController = DynamicVariantController();
    
    _lastLanguageCode = _localizationService.currentLocale.languageCode;
    
    debugPrint('📱 ProductDetailsPage: Initializing');
    debugPrint('  - Product ID: ${widget.productId}');
    debugPrint('  - Product Type: ${widget.productType}');
    debugPrint('  - Product ID Type: ${widget.productId.runtimeType}');
    debugPrint('  - Product Type Type: ${widget.productType.runtimeType}');
    debugPrint('  - Current Language: $_lastLanguageCode');
    
    // Listen to language changes
    _localizationService.addListener(_onLanguageChanged);
    print('product id from the catalog list selected ${widget.productId}');
    // Ensure API language is synced with current app language before loading product
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final currentLanguage = _localizationService.currentLocale.languageCode;
      // Fire-and-forget language sync so that product loading can start immediately.
      // This avoids blocking the initial load on any async I/O inside LanguageService.
      unawaited(
        LanguageService()
            .setFromAppLanguageCode(currentLanguage)
            .then((_) => debugPrint(
                  '🌐 ProductDetailsPage: Synced API language to: $currentLanguage',
                )),
      );

      // Load product details with current language without waiting for the sync call
      context.read<ProductDetailsBloc>().add(LoadProductDetails(
            widget.productId,
            productType: widget.productType,
            cardPreview: widget.cardPreview,
          ));

      final cartState = context.read<CartBloc>().state;
      if (cartState is! CartLoaded && cartState is! CartUpdating) {
        context.read<CartBloc>().add(const LoadCart());
      }
    });
  }

  /// When user selects an attribute and normal API has not provided variant_combinations
  /// (loading, empty, or failed), trigger variant lite fallback API.
  void _onAfterAttributeSelected() {
    final blocState = context.read<ProductDetailsBloc>().state;
    if (blocState is! ProductDetailsLoaded) return;
    if (blocState.variantCombinationsFromNormalApi != null &&
        blocState.variantCombinationsFromNormalApi!.isNotEmpty) {
      return; // Already have variant data, no fallback needed
    }
    final productId = blocState.productDetails.id;
    final valueIds = _variantController.selectedAttributes.values.toList();
    if (valueIds.isEmpty) return;
    context.read<ProductDetailsBloc>().add(
          FetchVariantLiteFallbackEvent(
            productId: productId,
            attributeValueIds: valueIds,
          ),
        );
  }

  void _onLanguageChanged() {
    final currentLanguage = _localizationService.currentLocale.languageCode;
    
    // If language changed, reload product details with new language

    if (_lastLanguageCode != currentLanguage) {
      debugPrint('🌐 ProductDetailsPage: Language changed from $_lastLanguageCode to $currentLanguage, reloading product...');
      _lastLanguageCode = currentLanguage;
      
      // Sync API language and reload product

      LanguageService().setFromAppLanguageCode(currentLanguage).then((_) {
        if (mounted) {
          context.read<ProductDetailsBloc>().add(LoadProductDetails(
                widget.productId,
                productType: widget.productType,
                cardPreview: widget.cardPreview,
              ));
        }
      });
    }
  }


  @override
  void dispose() {
    _localizationService.removeListener(_onLanguageChanged);
    _pageController.dispose();
    _scrollController.dispose();
    _variantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final colorScheme = theme.colorScheme;
    
    return ChangeNotifierProvider<DynamicVariantController>.value(
      value: _variantController,
      child: Scaffold(
        backgroundColor: colorScheme.background,
        body: BlocConsumer<ProductDetailsBloc, ProductDetailsState>(
        listener: (context, state) {
          // Initialize dynamic variant controller ONLY on first load
          // Don't re-initialize on every state change (like color selection) to avoid resetting selection
          if (state is ProductDetailsLoaded && !_isControllerInitialized) {
            debugPrint('🔄 ProductDetailsPage: Initializing variant controller with product details (first load)');
            _variantController.initialize(state.productDetails);
            _variantController.setVariantCombinationsForMatching(state.variantCombinationsFromNormalApi);
            _isControllerInitialized = true;
            debugPrint('✅ ProductDetailsPage: Variant controller initialized');
            debugPrint('   Selected attributes: ${_variantController.selectedAttributes}');
            debugPrint('   Variant ID: ${_variantController.variantId}');
            debugPrint('   In Stock: ${_variantController.inStock}');
            debugPrint('   Quantity: ${_variantController.quantityAvailable}');
          } else if (state is ProductDetailsLoaded && _isControllerInitialized) {
            // On subsequent state changes (e.g. normal API merged), sync controller
            debugPrint('🔄 ProductDetailsPage: Product details updated, syncing controller (preserving selection)');
            _variantController.updateProductDetails(state.productDetails);
            _variantController.setVariantCombinationsForMatching(state.variantCombinationsFromNormalApi);
          }
          
          if (state is ProductDetailsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${AppLocalizations.of(context)!.error}: ${state.message}'),
                backgroundColor: colorScheme.error,
              ),
            );
          } else if (state is ProductDetailsAddedToCart) {
            AppSnackBar.success(
              context,
              AppLocalizations.of(context)!.addedToCartSuccessfully,
              actionLabel: AppLocalizations.of(context)!.cart,
              onAction: () async {
                await HapticService.buttonClick();
                final rootNav = NavigationService.currentState;
                // Close any dialogs/sheets if possible
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                // Navigate to cart using root navigator to avoid disposed context
                rootNav?.push(
                  MaterialPageRoute(
                    builder: (_) => const CartPage(),
                  ),
                );
              },
            );
          }
        },
        builder: (context, state) {
          if (state is ProductDetailsError) {
            return _buildErrorState(state.message);
          }

          if (state is ProductDetailsLoading) {
            if (state.cardPreview != null) {
              return _buildProductDetailsBody(cardPreview: state.cardPreview);
            }
            return const ProductDetailsShimmer();
          }

          if (state is ProductDetailsLoaded) {
            if (widget.openAddToCart && !_hasOpenedAddToCartFromRoute) {
              _hasOpenedAddToCartFromRoute = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final variantController = context.read<DynamicVariantController>();
                AddToCartBottomSheet.show(
                  context,
                  context.read<ProductDetailsBloc>(),
                  variantController,
                );
              });
            }
            return _buildProductDetailsBody(productDetails: state.productDetails);
          }

          return const ProductDetailsShimmer();
        },
      ),
      bottomNavigationBar: Consumer<DynamicVariantController>(
        builder: (context, variantController, _) {
          return BlocBuilder<ProductDetailsBloc, ProductDetailsState>(
            builder: (context, state) {
              final isLoaded = state is ProductDetailsLoaded;
              final isLoading = state is ProductDetailsLoading;
              if (isLoaded || isLoading) {
                final bool isOutOfStock =
                    isLoaded ? !variantController.inStock : true;

                return Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveConstants.smPadding,
                vertical: ResponsiveConstants.mdPadding,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.4 : 0.1,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    // Disable until loaded; then use stock rule (out of stock = disabled).
                    onPressed: (!isLoaded || isOutOfStock)
                        ? null
                        : () async {
                            await HapticService.buttonClick();
                            AddToCartBottomSheet.show(
                              context,
                              context.read<ProductDetailsBloc>(),
                              variantController,
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isOutOfStock ? colorScheme.surface : primary,
                      foregroundColor: isOutOfStock
                          ? colorScheme.onSurface.withValues(alpha: 0.6)
                          : colorScheme.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ResponsiveConstants.mdRadius),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isLoaded && !isOutOfStock) ...[
                          Icon(
                            Icons.shopping_cart,
                            size: ResponsiveConstants.mdIconSize,
                          ),
                          SizedBox(width: ResponsiveConstants.smSpacing),
                        ],
                        SizedBox(width: ResponsiveConstants.smSpacing),
                        Text(
                          !isLoaded
                              ? AppLocalizations.of(context)!.loading
                              : isOutOfStock
                                  ? AppLocalizations.of(context)!.outOfStock
                                  : AppLocalizations.of(context)!.addToCart,
                          style: AppFonts.getTextStyle(
                            fontSize: ResponsiveConstants.mdFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return AppErrorView(
      message: message,
      onRetry: () async {
        await HapticService.buttonClick();
        context.read<ProductDetailsBloc>().add(
              LoadProductDetails(
                widget.productId,
                productType: widget.productType,
                cardPreview: widget.cardPreview,
              ),
            );
      },
    );
  }

  /// Builds the same product details UI. Pass [productDetails] when loaded,
  /// or [cardPreview] when still loading so passed values show and rest are skeletons.
  Widget _buildProductDetailsBody({
    ProductDetails? productDetails,
    ProductDetailsCardPreview? cardPreview,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoaded = productDetails != null;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          // Show a smaller hero image in preview so more skeleton content is visible,
          // and full height once real product details are loaded.
          expandedHeight: isLoaded
              ? ResponsiveConstants.productDetailsAppBarHeight
              : ResponsiveConstants.productDetailsAppBarHeight * 0.7,
          floating: false,
          pinned: true,
          elevation: 0,
          backgroundColor: colorScheme.background,
          leading: Padding(
            padding: EdgeInsets.only(left: ResponsiveConstants.mdPadding),
            child: _buildBackButton(),
          ),
          title: isLoaded
              ? _buildAppBarTitle(productDetails!)
              : _buildAppBarTitleFromPreview(cardPreview!),
          iconTheme: IconThemeData(color: colorScheme.onBackground),
          actions: [
            _buildShareButton(productDetails: productDetails, cardPreview: cardPreview),
            const CartButtonWithBadge(),
            Padding(
              padding: EdgeInsetsDirectional.only(end: ResponsiveConstants.mdPadding),
              child: isLoaded
                  ? Consumer<DynamicVariantController>(
                      builder: (context, variantController, _) {
                        final String favProductId =
                            variantController.variantId.isNotEmpty
                                ? variantController.variantId
                                : productDetails!.id;
                        return FavoriteButton(
                          productId: favProductId,
                          productName: productDetails!.name,
                          brand: productDetails!.brand,
                          price: productDetails!.price,
                          imageUrl: productDetails!.images.isNotEmpty
                              ? productDetails!.images.first
                              : null,
                          category: null,
                          isFavorite: productDetails!.isFavorite,
                          size: ResponsiveConstants.mdIconSize,
                          isCompact: true,
                        );
                      },
                    )
                  : FavoriteButton(
                      productId: widget.productId,
                      productName: cardPreview!.productTitle,
                      brand: cardPreview!.brand,
                      price: cardPreview!.price,
                      imageUrl: cardPreview!.imageUrl,
                      category: null,
                      isFavorite: false,
                      size: ResponsiveConstants.mdIconSize,
                      isCompact: true,
                    ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: isLoaded
                ? Consumer<DynamicVariantController>(
                    builder: (context, variantController, _) {
                      return CollapsibleImageSectionWidget(
                        productDetails: productDetails!,
                        pageController: _pageController,
                        variantImageUrls: variantController.currentImages,
                        onAfterAttributeSelected: _onAfterAttributeSelected,
                      );
                    },
                  )
                : _buildPreviewImage(cardPreview!),
          ),
        ),
        ProductInfoSection(
          productDetails: productDetails,
          cardPreview: cardPreview,
          scrollController: _scrollController,
          onAfterAttributeSelected: _onAfterAttributeSelected,
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: ResponsiveConstants.lgSpacing),
        ),
      ],
    );
  }

  Widget _buildAppBarTitleFromPreview(ProductDetailsCardPreview preview) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          preview.brand,
          style: AppFonts.getTextStyle(
            fontSize: ResponsiveConstants.smFontSize,
            fontWeight: FontWeight.w600,
            color: colorScheme.onBackground,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          preview.productTitle,
          style: AppFonts.getTextStyle(
            fontSize: ResponsiveConstants.mdFontSize,
            fontWeight: FontWeight.w600,
            color: colorScheme.onBackground,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPreviewImage(ProductDetailsCardPreview preview) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.background,
      child: preview.imageUrl != null && preview.imageUrl!.isNotEmpty
          ? Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: CachedNetworkImage(
                    imageUrl: preview.imageUrl!,
                    fit: BoxFit.contain,
                    placeholder: (_, __) =>
                        Container(color: colorScheme.background),
                    errorWidget: (_, __, ___) =>
                        Container(color: colorScheme.background),
                  ),
                ),
                Positioned(
                  left: ResponsiveConstants.mdPadding,
                  right: ResponsiveConstants.mdPadding,
                  bottom: ResponsiveConstants.mdPadding,
                  child: ColorSelectionSkeleton(colorScheme: colorScheme),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildBackButton() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return IconButton(
      icon: Icon(
        Icons.arrow_back_ios,
        color: colorScheme.onBackground,
        size: ResponsiveConstants.mdIconSize,
      ),
      onPressed: () async {
        await HapticService.buttonClick();
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildAppBarTitle(ProductDetails productDetails) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          productDetails.brand,
          style: AppFonts.getTextStyle(
            fontSize: ResponsiveConstants.smFontSize,
            fontWeight: FontWeight.w600,
            color: colorScheme.onBackground,
          ),
        ),
        Text(
          productDetails.name,
          style: AppFonts.getTextStyle(
            fontSize: ResponsiveConstants.mdFontSize,
            fontWeight: FontWeight.w600,
            color: colorScheme.onBackground,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }



  Widget _buildShareButton({
    ProductDetails? productDetails,
    ProductDetailsCardPreview? cardPreview,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(
        Icons.share,
        color: colorScheme.onBackground,
        size: ResponsiveConstants.mdIconSize,
      ),
      onPressed: () async {
        await HapticService.buttonClick();
        if (productDetails != null) {
          final p = productDetails;
          final image = p.images.isNotEmpty ? p.images.first : '';
          String? fullUrl;
          try {
            final String? websitePath = p.websiteUrl;
            if (websitePath != null && websitePath.isNotEmpty) {
              final base = AppConstants.baseUrl;
              fullUrl = websitePath.startsWith('http')
                  ? websitePath
                  : (base.endsWith('/')
                      ? base.substring(0, base.length - 1)
                      : base) +
                      websitePath;
            }
          } catch (_) {}
          final List<String> lines = [];
          try {
            final localized = AppLocalizations.of(context);
            if (localized == null) {
              lines.add('Check out this product:');
            } else {
              final dynamic dyn = localized;
              final prefix = (() {
                try {
                  return dyn.checkOutThisProduct as String;
                } catch (_) {
                  return 'Check out this product:';
                }
              })();
              lines.add(prefix);
            }
          } catch (_) {
            lines.add('Check out this product:');
          }
          lines.add('${p.brand} — ${p.name}');
          lines.add('');
          lines.add('Price: ${p.price.toStringAsFixed(2)}');
          if (fullUrl != null) {
            lines.add('');
            lines.add(fullUrl);
          }
          if (image.isNotEmpty) {
            lines.add('');
            lines.add('Image: $image');
          }
          Share.share(lines.join('\n'), subject: p.name);
        } else if (cardPreview != null) {
          final lines = [
            '${cardPreview.brand} — ${cardPreview.productTitle}',
            '',
            'Price: ${cardPreview.price}',
            if (cardPreview.imageUrl != null && cardPreview.imageUrl!.isNotEmpty)
              '\nImage: ${cardPreview.imageUrl}',
          ];
          Share.share(lines.join('\n'), subject: cardPreview.productTitle);
        }
      },
    );
  }
}
