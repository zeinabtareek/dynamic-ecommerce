import 'package:flutter/material.dart';
import '../../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/image_cache_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../l10n/app_localizations.dart';

import '../../domain/entities/product_details.dart';

class ProductImageGallery extends StatefulWidget {
  final ProductDetails productDetails;
  final Function(int) onImageChanged;
  final int currentImageIndex;
  final Function(String)? onColorSelected;

  const ProductImageGallery({
    super.key,
    required this.productDetails,
    required this.onImageChanged,
    required this.currentImageIndex,
    this.onColorSelected,
  });

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  late PageController _pageController;
  late List<String> _currentImages;

  @override
  void initState() {
    super.initState();
    _currentImages = _getCurrentColorImages();
    _pageController = PageController(initialPage: widget.currentImageIndex);
  }

  @override
  void didUpdateWidget(ProductImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productDetails.selectedColor != widget.productDetails.selectedColor) {
      _currentImages = _getCurrentColorImages();
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Resolve selected ColorOption by matching [productDetails.selectedColor] to
  /// name or displayName (works for both English and Arabic; selectedColor may be either).
  ColorOption _findSelectedColorOption() {
    if (widget.productDetails.colorOptions.isEmpty) {
      return widget.productDetails.colorOptions.first;
    }
    final pd = widget.productDetails;
    if (pd.selectedColor.isEmpty) {
      return pd.colorOptions.first;
    }
    final sel = pd.selectedColor.toLowerCase().trim();
    for (final c in pd.colorOptions) {
      final candidateNames = <String>[
        c.name.toLowerCase().trim(),
        (c.displayName ?? c.name).toLowerCase().trim(),
      ];
      if (candidateNames.any((n) =>
          n == sel || (n.isNotEmpty && (n.contains(sel) || sel.contains(n))))) {
        return c;
      }
    }
    return pd.colorOptions.first;
  }

  List<String> _getCurrentColorImages() {
    if (widget.productDetails.colorOptions.isEmpty) {
      return _dedupeImages(widget.productDetails.images);
    }
    final selectedColorOption = _findSelectedColorOption();
    return _dedupeImages(selectedColorOption.images);
  }

  List<String> _dedupeImages(List<String> images) {
    final Set<String> seen = {};
    return images.where((url) {
      if (url.isEmpty) return false;
      final isNew = !seen.contains(url);
      if (isNew) seen.add(url);
      return isNew;
    }).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main Image Area with PageView
        Container(
          height: 400,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                widget.onImageChanged(index);
              },
              itemCount: _currentImages.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () async {
          await HapticService.buttonClick();
          _showFullScreenImage(index);
        },
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: ImageCacheUtils.getAuthenticatedImageData(_currentImages[index]),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final data = snapshot.data!;
                      final finalUrl = data['url'] as String;
                      // Use normalized original URL as cache key for consistent caching
                      // This ensures old cached images with bad URLs are not reused
                      final originalImageUrl = _currentImages[index];
                      final cacheKey = ImageCacheUtils.normalizeImageUrl(originalImageUrl);
                      return CachedNetworkImage(
                        imageUrl: finalUrl,
                        cacheKey: cacheKey,
                        fit: BoxFit.cover,
                        httpHeaders: data['headers'] as Map<String, String>,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.error,
                            color: Colors.red,
                            size: 50,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Image Indicators
        if (_currentImages.length > 1) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _currentImages.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.currentImageIndex == index
                      ? Colors.black
                      : Colors.grey[400],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Image Counter
        if (_currentImages.length > 1)
          Text(
            '${widget.currentImageIndex + 1} of ${_currentImages.length}',
            style: AppFonts.getTextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        
        const SizedBox(height: 20),
        
        // Color Swatches with Images
        _buildColorSwatches(),
      ],
    );
  }

  Widget _buildColorSwatches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${AppLocalizations.of(context)!.color}: ${_getSelectedColorName(context)}',
          style: AppFonts.getTextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.productDetails.colorOptions.length,
            itemBuilder: (context, index) {
              final color = widget.productDetails.colorOptions[index];
              final selectedOption = _findSelectedColorOption();
              final isSelected = color.id == selectedOption.id;
              
              return GestureDetector(
                onTap: () async {
          await HapticService.buttonClick();
          _onColorSelected(color.id);
        },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      // Color swatch with image
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: ImageCacheUtils.normalizeImageUrl(color.images.first),
                            cacheKey: ImageCacheUtils.normalizeImageUrl(color.images.first),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Color name
                      Text(
                        color.displayNameOrName,
                        style: AppFonts.getTextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? Colors.black : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getSelectedColorName(BuildContext context) {
    if (widget.productDetails.colorOptions.isEmpty) {
      return AppLocalizations.of(context)!.color;
    }
    return _findSelectedColorOption().displayNameOrName;
  }

  void _onColorSelected(String colorId) {
    if (widget.onColorSelected != null) {
      widget.onColorSelected!(colorId);
    }
  }

  void _showFullScreenImage(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageView(
          images: _currentImages,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class FullScreenImageView extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenImageView({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageView> createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () async {
          await HapticService.buttonClick();
          Navigator.of(context).pop();
        },
        ),
        title: Text(
          '${_currentIndex + 1} of ${widget.images.length}',
          style: AppFonts.getTextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Image PageView
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.images[index],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.black,
                      child: const Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Navigation arrows
          if (widget.images.length > 1) ...[
            // Previous button
            if (_currentIndex > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: () async {
          await HapticService.buttonClick();
          _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
        },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            
            // Next button
            if (_currentIndex < widget.images.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: () async {
          await HapticService.buttonClick();
          _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
        },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
