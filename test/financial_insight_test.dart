import 'package:flutter_test/flutter_test.dart';
import 'package:wallone/utils/services/gemini_service.dart';

void main() {
  group('FinancialInsight.fromJson', () {
    test('parses recommendedAmount from number', () {
      final json = {
        'id': '1',
        'title': 'Save for emergency',
        'description': 'Set aside some funds',
        'category': 'savings',
        'type': 'savings',
        'priority': 'high',
        'actionData': {},
        'recommendedAmount': 150.5,
        'isActionable': true,
        'isExecuted': false,
        'createdAt': '2025-10-19T12:34:56Z'
      };

      final insight = FinancialInsight.fromJson(json);

      expect(insight.id, '1');
      expect(insight.recommendedAmount, 150.5);
      expect(insight.isActionable, isTrue);
      expect(insight.isExecuted, isFalse);
      expect(insight.createdAt.toUtc().year, 2025);
    });

    test('parses recommendedAmount from string and boolean-like fields', () {
      final json = {
        'id': '2',
        'title': 'Budget new category',
        'description': 'Create a budget',
        'category': 'food',
        'type': 'budget',
        'priority': 'medium',
        'actionData': {},
        'recommendedAmount': '200.00',
        'isActionable': 'true',
        'isExecuted': '1',
      };

      final insight = FinancialInsight.fromJson(json);

      expect(insight.id, '2');
      expect(insight.recommendedAmount, 200.0);
      expect(insight.isActionable, isTrue);
      expect(insight.isExecuted, isTrue);
    });

    test('toJson produces matching fields', () {
      final json = {
        'id': '3',
        'title': 'Invest small',
        'description': 'Try micro-investing',
        'category': 'investment',
        'type': 'investment',
        'priority': 'low',
        'actionData': {'action': 'add_investment'},
        'recommendedAmount': 50,
      };

      final insight = FinancialInsight.fromJson(json);
      final out = insight.toJson();

      expect(out['id'], '3');
      expect(out['title'], 'Invest small');
      expect(out['recommendedAmount'], 50);
      expect(out['actionData'], isA<Map>());
    });
  });
}
