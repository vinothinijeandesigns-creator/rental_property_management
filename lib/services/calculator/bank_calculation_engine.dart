import 'dart:math';

class CalculationResult {
  final double maturityAmount;
  final double totalInterest;
  final bool isEstimated;

  CalculationResult({
    required this.maturityAmount,
    required this.totalInterest,
    this.isEstimated = false,
  });
}

abstract class BankCalculationEngine {
  /// Calculates the maturity amount and total interest for a Fixed Deposit.
  CalculationResult calculateFDMaturity({
    required double principal,
    required double rate,
    required int tenureMonths,
    required String interestMode, // 'Cumulative' or 'Non-Cumulative'
    required String payoutFrequency, // 'Monthly', 'Quarterly', 'Half-Yearly', 'Yearly', 'Maturity'
    required DateTime startDate,
    required DateTime endDate,
  });


  /// Calculates the overall maturity for a Recurring Deposit.
  CalculationResult calculateRDMaturity({
    required double monthlyInstallment,
    required double rate,
    required int tenureMonths,
    required DateTime startDate,
    required int paymentDay,
  }) {
    double totalPrincipal = monthlyInstallment * tenureMonths;
    double totalAmount = 0;
    double r = rate / 100.0;

    for (int i = 1; i <= tenureMonths; i++) {
        // Standard Indian Bank RD formula:
        // Interest is compounded quarterly.
        // Months left for this installment to mature = i
        // Convert months to quarters = i / 3.0
        double quarters = i / 3.0;
        double amount = monthlyInstallment * pow(1 + (r / 4), quarters);
        totalAmount += amount;
    }

    double totalInterest = totalAmount - totalPrincipal;

    return CalculationResult(
      maturityAmount: totalAmount,
      totalInterest: totalInterest,
      isEstimated: isEstimatedCalculation(),
    );
  }

  bool isEstimatedCalculation() {
    return false; // Subclasses can override
  }
}
