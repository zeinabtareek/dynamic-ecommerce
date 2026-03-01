import 'dart:developer' as developer;
import 'package:flutter/cupertino.dart';
import 'package:zalando_clone_app/core/network/api_client.dart';
import '../../../../core/constants/endpoints.dart';

abstract class ProductDetailsRemoteDataSource {
  /// Fetch product details from `/ecom/get/product`.
  ///
  /// Two-phase flow used by product details page:
  /// 1. First API: [apiLoad] = `'lite'` — called on initial load. Show UI as soon as
  ///    this returns; response is parsed in a background isolate so the main thread
  ///    can paint the product page quickly.
  /// 2. Second API: [apiLoad] = `'normal'` — triggered in background after the
  ///    first frame with lite data is painted. Heavy response is parsed in a
  ///    background isolate; when done, full variant/attribute data is merged in.
  ///
  /// [apiLoad] controls how much data the backend returns:
  /// - `'lite'`   → initial single‑variant payload for fast first paint
  /// - `'normal'` → full variant/combination payload for attribute selection
  ///
  /// Default is `'normal'` to preserve existing behaviour for callers that
  /// don't explicitly opt into the lite/normal dual‑phase flow.
  Future<Map<String, dynamic>> getProductDetails(
    String productId, {
    String productType = 'variant',
    String apiLoad = 'normal',
  });

  /// Fallback: fetch variant data by selected attribute value IDs when normal API
  /// has not returned variant_combinations (loading, empty, or failed).
  /// Uses `/ecom/get/variant/lite` with [productId] and [attributeValueIds].
  Future<Map<String, dynamic>> getVariantLite(
    String productId,
    List<int> attributeValueIds,
  );
}

class ProductDetailsRemoteDataSourceImpl implements ProductDetailsRemoteDataSource {
  final ApiClient apiClient;

  ProductDetailsRemoteDataSourceImpl(this.apiClient);
  
  @override
  Future<Map<String, dynamic>> getProductDetails(
    String productId, {
    String productType = 'variant',
    String apiLoad = 'normal',
  }) async {
    debugPrint(
      '🌐 ProductDetailsRemoteDataSource: REQUEST /ecom/get/product '
      '(id=$productId, type=$productType, api_load=$apiLoad)',
    );
    
    try {
      final networkStopwatch = Stopwatch()..start();
      // API expects a unified payload: { id: <int>, type: '<template|variant>' }
      final params = <String, dynamic>{
        'id': int.parse(productId),
        'type': productType,
        // New backend contract: api_load controls payload shape.
        // - 'lite'   → initial single‑variant payload
        // - 'normal' → full variant combinations / attribute data
        'api_load': apiLoad,
      };

      debugPrint(
        '📤 ProductDetailsRemoteDataSource: Request payload for /ecom/get/product '
        '(api_load=$apiLoad): $params',
      );

      final response = await apiClient.requestRpc(
        Endpoints.getProduct,
        method: 'POST',
        params: params,
      );
      networkStopwatch.stop();

      debugPrint(
        '⏱ ProductDetailsRemoteDataSource: /ecom/get/product '
        '(api_load=$apiLoad) network time = ${networkStopwatch.elapsedMilliseconds} ms',
      );

      debugPrint(
        '📥 ProductDetailsRemoteDataSource: Response from /ecom/get/product '
        '(api_load=$apiLoad) → status=${response.statusCode}',
      );
      debugPrint('📥 ProductDetailsRemoteDataSource: Raw body: ${response.data}');

      final body = response.data;
      if (body is Map && body['result'] is Map) {
        final result = body['result'] as Map;
        final status = (result['status'] ?? '').toString().toLowerCase();
        
        if (status == 'error') {
          developer.log('❌ API returned error: ${result['message']}');
          throw Exception((result['message'] ?? 'Failed to get product').toString());
        }

        if (result['data'] is Map) {
          final productData = result['data'] as Map<String, dynamic>;
          developer.log('🌐 Extracted product data: $productData');
          // Step 1: Debug selected_variant from API response (for initial attribute selection)
          final selectedVariant = productData['selected_variant'];
          debugPrint(
            '📥 [Step 1 - API] selected_variant from response (api_load=$apiLoad): $selectedVariant',
          );
          if (selectedVariant is Map) {
            final attrs = selectedVariant['attributes'] as List<dynamic>? ?? const [];
            for (final a in attrs) {
              if (a is Map) {
                debugPrint(
                  '   → attr: ${a['attribute_name']} value_id=${a['value_id']} value_name="${a['value_name']}"',
                );
              }
            }
          }
          // Debug: variant_combinations from API (critical for normal API – used for attribute matching)
          final rawVc = productData['variant_combinations'];
          if (apiLoad == 'normal') {
            debugPrint(
              '📥 [Normal API] variant_combinations in response: '
              'present=${rawVc != null}, type=${rawVc?.runtimeType}',
            );
            if (rawVc == null) {
              debugPrint('   ⚠️ [Normal API] variant_combinations is NULL in normal API response');
            } else if (rawVc is List) {
              debugPrint('   [Normal API] variant_combinations.length = ${rawVc.length}');
              if (rawVc.isNotEmpty && rawVc.first is Map) {
                final first = rawVc.first as Map;
                debugPrint('   [Normal API] first variant keys: ${first.keys.toList()}');
              }
            } else if (rawVc is Map) {
              debugPrint('   [Normal API] variant_combinations is Map, keys.length = ${rawVc.length}');
            } else {
              debugPrint('   ⚠️ [Normal API] variant_combinations unexpected type: ${rawVc.runtimeType}');
            }
          } else {
            debugPrint(
              '📥 [Lite API] variant_combinations in response: present=${rawVc != null}, '
              '${rawVc is List ? "length=${rawVc.length}" : rawVc is Map ? "mapKeys=${rawVc.length}" : "type=${rawVc?.runtimeType}"}',
            );
          }
          return productData;
        }
      }

      developer.log('❌ Invalid API response structure');
      throw Exception('Invalid API response structure');
    } catch (e) {
      developer.log('❌ Error fetching product details: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getVariantLite(
    String productId,
    List<int> attributeValueIds,
  ) async {
    debugPrint(
      '🌐 ProductDetailsRemoteDataSource: REQUEST /ecom/get/variant/lite '
      '(id=$productId, attribute_value_ids=$attributeValueIds)',
    );
    try {
      final params = <String, dynamic>{
        'id': int.parse(productId),
        'attribute_value_ids': attributeValueIds,
      };
      final response = await apiClient.requestRpc(
        Endpoints.productLite,
        method: 'POST',
        params: params,
      );
      final body = response.data;
      if (body is Map && body['result'] is Map) {
        final result = body['result'] as Map;
        final status = (result['status'] ?? '').toString().toLowerCase();
        if (status == 'error') {
          throw Exception((result['message'] ?? 'Variant lite failed').toString());
        }
        if (result['data'] is Map) {
          final data = result['data'] as Map<String, dynamic>;
          debugPrint(
            '📥 ProductDetailsRemoteDataSource: variant/lite response keys: ${data.keys.toList()}',
          );
          return data;
        }
      }
      throw Exception('Invalid variant lite response structure');
    } catch (e) {
      developer.log('❌ Error fetching variant lite: $e');
      rethrow;
    }
  }
}

