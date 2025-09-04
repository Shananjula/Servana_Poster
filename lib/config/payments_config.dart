
class PaymentsConfig {
  static const int minCoinsToPost = 500;
  static const int minDepositCoins = 100;
  static const double depositPercentOfBudget = 0.05;
  static const Map<String, int> baseIntroFeeByCategory = {
    'Plumbing': 300, 'Electrical': 300, 'Cleaning': 200, 'Tutoring': 200,
    'Design': 250, 'Repairs': 250, 'Other': 200,
  };
  static const Map<String, double> helperTierMultiplier = {
    'Bronze': 1.0, 'Silver': 1.25, 'Gold': 1.5, 'TopRated': 1.6,
  };
  static const int introCreditWindowDays = 7;
  static const int monthlyIntroCapPerCategory = 3;
}
