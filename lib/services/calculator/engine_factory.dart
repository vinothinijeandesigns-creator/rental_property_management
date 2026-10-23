import 'bank_calculation_engine.dart';
import 'bank_engines.dart';

class EngineFactory {
  static BankCalculationEngine getEngine(String bankName) {
    switch (bankName.toUpperCase()) {
      case 'HDFC':
        return HdfcEngine();
      case 'SBI':
        return SbiEngine();
      case 'AXIS':
        return AxisEngine();
      case 'CUB':
      case 'CITY UNION BANK':
        return CubEngine();
      case 'IOB':
      case 'INDIAN OVERSEAS BANK':
        return IobEngine();
      case 'UCO':
        return UcoEngine();
      case 'CANARA':
        return CanaraEngine();
      case 'ICICI':
        return IciciEngine();
      default:
        return GenericEngine();
    }
  }
}
