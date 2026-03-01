import 'package:flutter/foundation.dart';

import '../../product_details/domain/entities/product_details.dart';
import 'models/product_details_model.dart';

/// Runs the full ProductDetails parsing (including variant/attribute building)
/// on a background isolate so it does not block the main thread.
///
/// Used only for the **normal** (heavy) API response. The lite response is
/// parsed on the main thread (small payload, no isolate overhead = faster first paint).
///
/// This offloads:
/// - variant_combinations normalization
/// - variant_attributes → variantAttributeOptions
/// - attribute_value_combinations parsing
/// - initial attribute selection / availability flags
///
/// The repository can await this and keep its external API unchanged.
Future<ProductDetails> parseProductDetailsInBackground(
  Map<String, dynamic> apiJson,
) {
  return compute<Map<String, dynamic>, ProductDetails>(
    _parseProductDetails,
    apiJson,
  );
}

/// Top‑level function used by [compute]. It must be a static or top‑level
/// function so that it can be invoked inside the spawned isolate.
ProductDetails _parseProductDetails(Map<String, dynamic> json) {
  return ProductDetailsModel.fromApiJson(json);
}

