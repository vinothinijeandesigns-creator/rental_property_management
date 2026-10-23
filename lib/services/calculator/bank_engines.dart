import 'dart:math';
import 'bank_calculation_engine.dart';

bool _isLeapYear(int year) {
  return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
}

// ---------------------------------------------------------
// Generic Fallback Engine
// ---------------------------------------------------------
class GenericEngine extends BankCalculationEngine {
  @override
  bool isEstimatedCalculation() => true;

  @override
  CalculationResult calculateFDMaturity({
    required double principal,
    required double rate,
    required int tenureMonths,
    required String interestMode,
    required String payoutFrequency,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    double r = rate / 100;
    int totalDays = endDate.difference(startDate).inDays;
    double t = totalDays / 365.25;
    double maturityAmount = principal;
    double totalInterest = 0;

    if (interestMode == 'Cumulative') {
      maturityAmount = principal * pow((1 + r / 4), 4 * t);
      totalInterest = maturityAmount - principal;
    } else {
      if (payoutFrequency == 'Monthly') {
         double monthlyDiscountedRate = (pow(1 + r/4, 1/3) - 1);
         totalInterest = principal * monthlyDiscountedRate * tenureMonths;
      } else {
         totalInterest = principal * r * t;
      }
    }
    return CalculationResult(maturityAmount: maturityAmount, totalInterest: totalInterest, isEstimated: true);
  }

}

// ---------------------------------------------------------
// HDFC Engine
// ---------------------------------------------------------
class HdfcEngine extends BankCalculationEngine {
  @override
  CalculationResult calculateFDMaturity({
    required double principal,
    required double rate,
    required int tenureMonths,
    required String interestMode,
    required String payoutFrequency,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    double r = rate / 100;
    
    if (interestMode == 'Cumulative') {
      int totalDays = endDate.difference(startDate).inDays;
      if (totalDays <= 181) {
        // HDFC FD <= 6 months uses Simple Interest
        double daysInYear = _isLeapYear(startDate.year) ? 366.0 : 365.0;
        double interest = principal * r * (totalDays / daysInYear);
        return CalculationResult(maturityAmount: principal + interest, totalInterest: interest);
      } else {
        int quarters = 0;
        DateTime currentDate = startDate;
        
        while (true) {
          DateTime nextQuarter = DateTime(currentDate.year, currentDate.month + 3, currentDate.day);
          if (nextQuarter.isAfter(endDate)) break;
          quarters++;
          currentDate = nextQuarter;
        }
        
        double amount = principal * pow((1 + r / 4), quarters);
        
        int remainingDays = endDate.difference(currentDate).inDays;
        if (remainingDays > 0) {
          double daysInYear = _isLeapYear(currentDate.year) ? 366.0 : 365.0;
          amount += amount * r * (remainingDays / daysInYear);
        }
        
        return CalculationResult(maturityAmount: amount, totalInterest: amount - principal);
      }
    } else {
      double totalInterest = 0;
      if (payoutFrequency == 'Monthly') {
         double monthlyDiscountedRate = (pow(1 + r/4, 1/3) - 1);
         totalInterest = principal * monthlyDiscountedRate * tenureMonths;
      } else {
         double t = endDate.difference(startDate).inDays / 365.0;
         totalInterest = principal * r * t;
      }
      return CalculationResult(maturityAmount: principal, totalInterest: totalInterest);
    }
  }

}

// ---------------------------------------------------------
// SBI Engine (STDR/TDR)
// ---------------------------------------------------------
class SbiEngine extends BankCalculationEngine {
  @override
  CalculationResult calculateFDMaturity({
    required double principal,
    required double rate,
    required int tenureMonths,
    required String interestMode,
    required String payoutFrequency,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    double r = rate / 100;
    if (interestMode == 'Cumulative') {
       int quarters = 0;
       DateTime currentDate = startDate;
       
       while (true) {
         DateTime nextQuarter = DateTime(currentDate.year, currentDate.month + 3, currentDate.day);
         if (nextQuarter.isAfter(endDate)) break;
         quarters++;
         currentDate = nextQuarter;
       }
       
       double amount = principal * pow((1 + r / 4), quarters);
       
       int remainingDays = endDate.difference(currentDate).inDays;
       if (remainingDays > 0) {
         // SBI strictly uses 365 for broken days
         amount += amount * r * (remainingDays / 365.0);
       }
       
       return CalculationResult(maturityAmount: amount, totalInterest: amount - principal);
    } else {
       double totalInterest = 0;
       if (payoutFrequency == 'Monthly') {
           double monthlyDiscountedRate = (pow(1 + r/4, 1/3) - 1);
           totalInterest = principal * monthlyDiscountedRate * tenureMonths;
       } else {
           double t = endDate.difference(startDate).inDays / 365.0;
           totalInterest = principal * r * t;
       }
       return CalculationResult(maturityAmount: principal, totalInterest: totalInterest);
    }
  }

}

// ---------------------------------------------------------
// Axis Engine
// ---------------------------------------------------------
class AxisEngine extends HdfcEngine {
  @override
  CalculationResult calculateFDMaturity({
    required double principal,
    required double rate,
    required int tenureMonths,
    required String interestMode,
    required String payoutFrequency,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    double r = rate / 100;
    if (interestMode == 'Cumulative') {
        int quarters = 0;
        DateTime currentDate = startDate;
        
        while (true) {
          DateTime nextQuarter = DateTime(currentDate.year, currentDate.month + 3, currentDate.day);
          if (nextQuarter.isAfter(endDate)) break;
          quarters++;
          currentDate = nextQuarter;
        }
        
        double amount = principal * pow((1 + r / 4), quarters);
        
        int remainingDays = endDate.difference(currentDate).inDays;
        if (remainingDays > 0) {
          // Axis strictly uses 365 days
          amount += amount * r * (remainingDays / 365.0);
        }
        return CalculationResult(maturityAmount: amount, totalInterest: amount - principal);
    }
    return super.calculateFDMaturity(
       principal: principal, rate: rate, tenureMonths: tenureMonths, 
       interestMode: interestMode, payoutFrequency: payoutFrequency, startDate: startDate, endDate: endDate
    );
  }
}

// ---------------------------------------------------------
// Other Banks (Mapped separately)
// ---------------------------------------------------------
class IobEngine extends HdfcEngine {}
class CubEngine extends HdfcEngine {}
class UcoEngine extends HdfcEngine {}
class CanaraEngine extends HdfcEngine {}
class IciciEngine extends HdfcEngine {}
