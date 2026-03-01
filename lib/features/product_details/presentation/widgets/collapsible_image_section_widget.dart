import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/product_details.dart';
import '../bloc/product_details_bloc.dart';
import 'product_image_section_widget.dart';
import 'color_selection_widget.dart';
import 'page_indicator_widget.dart';

class CollapsibleImageSectionWidget extends StatelessWidget {
  final ProductDetails productDetails;
  final PageController pageController;
  final List<String>? variantImageUrls;
  final VoidCallback? onAfterAttributeSelected;

  const CollapsibleImageSectionWidget({
    super.key,
    required this.productDetails,
    required this.pageController,
    this.variantImageUrls,
    this.onAfterAttributeSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Use BlocBuilder to get latest product details, but widget rebuilds when variantImageUrls prop changes
    // (which happens when controller updates via Consumer in parent)
    return BlocBuilder<ProductDetailsBloc, ProductDetailsState>(
      buildWhen: (previous, current) {
        // Always rebuild to get latest product details
        // The actual image updates come from variantImageUrls prop (from controller)
        return true;
      },
      builder: (context, state) {
        // Always use the latest product details from the bloc when available
        final currentProduct =
            state is ProductDetailsLoaded ? state.productDetails : productDetails;
        return Stack(
          children: [
            // Main Product Image (reacts to color/variant changes)
            // Use variant images from controller if available, otherwise use BLoC images
            ProductImageSectionWidget(
              key: ValueKey('img_${variantImageUrls?.length ?? currentProduct.images.length}_${(variantImageUrls != null && variantImageUrls!.isNotEmpty) ? variantImageUrls!.first : (currentProduct.images.isNotEmpty ? currentProduct.images.first : "")}'),
              productDetails: currentProduct,
              pageController: pageController,
              overrideImages: variantImageUrls, // Use controller's variant images
            ),

            // Color Selection - Top left (kept in sync with controller)
            ColorSelectionWidget(
              productDetails: currentProduct,
              onAfterAttributeSelected: onAfterAttributeSelected,
            ),

            // Page Indicator - Above images, centered
            PageIndicatorWidget(
              productDetails: currentProduct,
              pageController: pageController,
              overrideImages: variantImageUrls, // Use controller's variant images for indicator too
            ),
          ],
        );
      },
    );
  }
}
