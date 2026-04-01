class PaymentMethodsConfig {
  final Map<String, bool> purchase;
  final Map<String, bool> withdrawal;

  const PaymentMethodsConfig({
    required this.purchase,
    required this.withdrawal,
  });

  static const List<String> defaultPurchaseMethods = [
    'stripe',
  ];

  static const List<String> defaultWithdrawalMethods = [
    'stripe',
  ];

  factory PaymentMethodsConfig.fallbackAllDisabled() {
    return PaymentMethodsConfig(
      purchase: {
        for (final id in defaultPurchaseMethods) id: false,
      },
      withdrawal: {
        for (final id in defaultWithdrawalMethods) id: false,
      },
    );
  }

  factory PaymentMethodsConfig.fromJson(dynamic json) {
    if (json is! Map) {
      return PaymentMethodsConfig.fallbackAllDisabled();
    }

    final purchaseMap = _readBoolMap(json['purchase']);
    final withdrawalMap = _readBoolMap(json['withdrawal']);

    return PaymentMethodsConfig(
      purchase: _withDefaults(purchaseMap, defaultPurchaseMethods),
      withdrawal: _withDefaults(withdrawalMap, defaultWithdrawalMethods),
    );
  }

  Map<String, dynamic> toJson() => {
        'purchase': purchase,
        'withdrawal': withdrawal,
      };

  bool isEnabled({required String flow, required String methodId}) {
    final map = flow == 'withdrawal' ? withdrawal : purchase;
    return map[methodId] ?? false;
  }

  PaymentMethodsConfig copyWith({
    Map<String, bool>? purchase,
    Map<String, bool>? withdrawal,
  }) {
    return PaymentMethodsConfig(
      purchase: purchase ?? this.purchase,
      withdrawal: withdrawal ?? this.withdrawal,
    );
  }

  static Map<String, bool> _readBoolMap(dynamic value) {
    if (value is! Map) return {};
    return value.map((key, val) {
      if (key == null) return const MapEntry('', false);
      final boolValue = val is bool
          ? val
          : (val is String ? val.toLowerCase() == 'true' : false);
      return MapEntry(key.toString(), boolValue);
    })
      ..removeWhere((key, _) => key.isEmpty);
  }

  static Map<String, bool> _withDefaults(
    Map<String, bool> map,
    List<String> defaults,
  ) {
    return {
      for (final id in defaults) id: map[id] ?? false,
      for (final entry in map.entries) entry.key: entry.value,
    };
  }
}

class PaymentMethodUiSpec {
  final String id;
  final String label;
  final String description;

  const PaymentMethodUiSpec({
    required this.id,
    required this.label,
    required this.description,
  });
}

class PaymentMethodsCatalog {
  static const List<PaymentMethodUiSpec> purchase = [
    PaymentMethodUiSpec(
      id: 'stripe',
      label: 'Tarjeta de Credito / Debito',
      description: 'Visa, Mastercard, Amex — pago en USD',
    ),
  ];

  static const List<PaymentMethodUiSpec> withdrawal = [
    PaymentMethodUiSpec(
      id: 'stripe',
      label: 'Stripe',
      description: 'Transferencia internacional',
    ),
  ];
}
