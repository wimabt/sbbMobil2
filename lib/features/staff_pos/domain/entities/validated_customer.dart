class ValidatedCustomer {
  const ValidatedCustomer({
    required this.maskedName,
    required this.hasSufficientBalance,
    required this.tokenHash,
    required this.tokenOrCode,
  });

  final String maskedName;
  final bool? hasSufficientBalance;
  final String tokenHash;
  final String tokenOrCode;

  factory ValidatedCustomer.fromJson(
    Map<String, dynamic> json, {
    required String tokenOrCode,
  }) {
    return ValidatedCustomer(
      maskedName: json['masked_name']?.toString() ?? '',
      hasSufficientBalance: json['has_sufficient_balance'] as bool?,
      tokenHash: json['token_hash']?.toString() ?? '',
      tokenOrCode: tokenOrCode,
    );
  }
}

