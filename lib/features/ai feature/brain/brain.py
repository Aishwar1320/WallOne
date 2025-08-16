import json
import math
import random
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum
import statistics

class AdviceType(Enum):
    BUDGET = "budget"
    SAVING = "saving"
    INVESTMENT = "investment"
    SPENDING = "spending"
    WARNING = "warning"
    PREDICTION = "prediction"
    OPTIMIZATION = "optimization"
    BEHAVIORAL = "behavioral"

class AdvicePriority(Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

@dataclass
class AIInsight:
    id: str
    title: str
    description: str
    type: AdviceType
    priority: AdvicePriority
    confidence: float
    icon: str
    actionable: bool = False
    metadata: Optional[Dict] = None
    action_hint: Optional[str] = None

class SmartFinancialAdvisor:
    def __init__(self):
        self.config = {
            'emergency_fund_months': 6,
            'savings_rate_target': 0.20,
            'investment_ratio_target': 0.15,
            'debt_to_income_max': 0.40,
            'high_spending_threshold': 0.80,
            'volatility_threshold': 0.30
        }
        
        # Machine Learning-like patterns (stored knowledge)
        self.spending_patterns = self._load_spending_patterns()
        self.investment_strategies = self._load_investment_strategies()
        self.behavioral_insights = self._load_behavioral_patterns()
    
    def _load_spending_patterns(self):
        """Simulated ML model for spending pattern recognition"""
        return {
            'seasonal_multipliers': {
                'january': 0.8,  # post-holiday low
                'february': 0.85,
                'march': 0.95,
                'april': 1.0,
                'may': 1.05,
                'june': 1.1,   # vacation season
                'july': 1.15,
                'august': 1.1,
                'september': 0.95,
                'october': 1.0,
                'november': 1.2,  # pre-holiday
                'december': 1.3   # holiday season
            },
            'category_correlations': {
                'food': {'entertainment': 0.7, 'transport': 0.5},
                'entertainment': {'food': 0.7, 'shopping': 0.6},
                'transport': {'food': 0.5, 'work': 0.8},
                'shopping': {'entertainment': 0.6, 'lifestyle': 0.9}
            }
        }
    
    def _load_investment_strategies(self):
        """Investment recommendation engine based on risk profiles"""
        return {
            'conservative': {
                'equity_ratio': 0.30,
                'debt_ratio': 0.60,
                'liquid_ratio': 0.10,
                'expected_return': 0.08
            },
            'moderate': {
                'equity_ratio': 0.50,
                'debt_ratio': 0.40,
                'liquid_ratio': 0.10,
                'expected_return': 0.12
            },
            'aggressive': {
                'equity_ratio': 0.70,
                'debt_ratio': 0.25,
                'liquid_ratio': 0.05,
                'expected_return': 0.15
            }
        }
    
    def _load_behavioral_patterns(self):
        """Behavioral finance insights"""
        return {
            'spending_triggers': [
                {'pattern': 'weekend_spike', 'description': 'Weekend spending 40% higher than weekdays'},
                {'pattern': 'salary_day_effect', 'description': 'First week spending 60% of monthly budget'},
                {'pattern': 'emotional_spending', 'description': 'Stress-related purchases in entertainment/shopping'}
            ],
            'saving_psychology': [
                {'rule': '50_30_20', 'description': '50% needs, 30% wants, 20% savings'},
                {'rule': 'pay_yourself_first', 'description': 'Automate savings before expenses'},
                {'rule': 'round_up_savings', 'description': 'Round up purchases and save difference'}
            ]
        }

    def analyze_financial_health(self, balance: float, budgets: Dict, investments: Dict) -> Dict:
        """Comprehensive financial health analysis"""
        
        # Calculate key metrics
        monthly_income = sum(budget.get('allocated', 0) for budget in budgets.values())
        monthly_expenses = sum(budget.get('spent', 0) for budget in budgets.values())
        total_investments = sum(inv.get('current_value', 0) for inv in investments.values())
        
        # Emergency fund analysis
        monthly_essential_expenses = self._calculate_essential_expenses(budgets)
        emergency_fund_months = balance / max(monthly_essential_expenses, 1)
        
        # Savings rate
        savings_rate = max(0, (monthly_income - monthly_expenses) / max(monthly_income, 1))
        
        # Investment ratio
        total_wealth = balance + total_investments
        investment_ratio = total_investments / max(total_wealth, 1)
        
        # Budget utilization by category
        budget_utilization = {}
        for category, budget in budgets.items():
            allocated = budget.get('allocated', 0)
            spent = budget.get('spent', 0)
            budget_utilization[category] = spent / max(allocated, 1)
        
        return {
            'emergency_fund_months': emergency_fund_months,
            'savings_rate': savings_rate,
            'investment_ratio': investment_ratio,
            'budget_utilization': budget_utilization,
            'monthly_income': monthly_income,
            'monthly_expenses': monthly_expenses,
            'total_wealth': total_wealth,
            'financial_score': self._calculate_financial_score(
                emergency_fund_months, savings_rate, investment_ratio
            )
        }

    def _calculate_essential_expenses(self, budgets: Dict) -> float:
        """Calculate essential monthly expenses"""
        essential_categories = ['food', 'housing', 'utilities', 'transport', 'insurance', 'minimum_payments']
        essential_expenses = 0
        
        for category, budget in budgets.items():
            if any(essential in category.lower() for essential in essential_categories):
                essential_expenses += budget.get('spent', 0)
        
        return essential_expenses

    def _calculate_financial_score(self, emergency_months: float, savings_rate: float, investment_ratio: float) -> float:
        """Calculate overall financial health score (0-100)"""
        
        # Emergency fund score (0-30 points)
        emergency_score = min(30, (emergency_months / self.config['emergency_fund_months']) * 30)
        
        # Savings rate score (0-35 points)
        savings_score = min(35, (savings_rate / self.config['savings_rate_target']) * 35)
        
        # Investment score (0-25 points)
        investment_score = min(25, (investment_ratio / self.config['investment_ratio_target']) * 25)
        
        # Bonus points for balance (0-10 points)
        balance_bonus = min(10, max(0, 10 * (emergency_months - 3) / 3))
        
        return min(100, emergency_score + savings_score + investment_score + balance_bonus)

    def generate_smart_insights(self, balance: float, budgets: Dict, investments: Dict) -> List[AIInsight]:
        """Generate intelligent financial insights using ML-like analysis"""
        
        health_metrics = self.analyze_financial_health(balance, budgets, investments)
        insights = []
        
        # Emergency Fund Insights
        insights.extend(self._analyze_emergency_fund(balance, health_metrics))
        
        # Budget Optimization Insights
        insights.extend(self._analyze_budget_patterns(budgets, health_metrics))
        
        # Investment Strategy Insights
        insights.extend(self._analyze_investment_opportunities(investments, health_metrics))
        
        # Spending Behavior Insights
        insights.extend(self._analyze_spending_behavior(budgets, health_metrics))
        
        # Predictive Insights
        insights.extend(self._generate_predictions(health_metrics))
        
        # Behavioral Finance Insights
        insights.extend(self._generate_behavioral_insights(health_metrics))
        
        # Sort by priority and confidence
        insights.sort(key=lambda x: (x.priority.value, -x.confidence), reverse=True)
        
        return insights[:6]  # Return top 6 insights

    def _analyze_emergency_fund(self, balance: float, metrics: Dict) -> List[AIInsight]:
        """Emergency fund analysis with smart recommendations"""
        insights = []
        emergency_months = metrics['emergency_fund_months']
        
        if emergency_months < 3:
            insights.append(AIInsight(
                id=f"emergency_{int(datetime.now().timestamp())}",
                title="🚨 Critical: Build Emergency Fund",
                description=f"You have only {emergency_months:.1f} months of emergency funds. Experts recommend 6 months. Start with ₹{int(balance * 0.3):,} immediately.",
                type=AdviceType.SAVING,
                priority=AdvicePriority.CRITICAL,
                confidence=0.95,
                icon="🚨",
                actionable=True,
                metadata={
                    "current_months": emergency_months,
                    "target_months": 6,
                    "recommended_amount": balance * 0.3,
                    "monthly_increase": metrics['monthly_income'] * 0.1
                },
                action_hint="Set up automatic transfer to emergency fund"
            ))
        elif emergency_months < 6:
            insights.append(AIInsight(
                id=f"emergency_boost_{int(datetime.now().timestamp())}",
                title="📈 Boost Emergency Fund",
                description=f"Great progress! You're at {emergency_months:.1f} months. Add ₹{int(metrics['monthly_income'] * 0.15):,}/month to reach 6-month target.",
                type=AdviceType.SAVING,
                priority=AdvicePriority.HIGH,
                confidence=0.88,
                icon="📈",
                actionable=True,
                metadata={
                    "current_months": emergency_months,
                    "monthly_addition_needed": metrics['monthly_income'] * 0.15
                }
            ))
        
        return insights

    def _analyze_budget_patterns(self, budgets: Dict, metrics: Dict) -> List[AIInsight]:
        """Smart budget analysis with pattern recognition"""
        insights = []
        utilization = metrics['budget_utilization']
        
        # Find overspending categories
        overspent_categories = [(cat, util) for cat, util in utilization.items() if util > 0.9]
        if overspent_categories:
            worst_category, worst_util = max(overspent_categories, key=lambda x: x[1])
            
            insights.append(AIInsight(
                id=f"overspend_{worst_category}_{int(datetime.now().timestamp())}",
                title=f"⚠️ Overspending Alert: {worst_category.title()}",
                description=f"You've used {worst_util*100:.0f}% of your {worst_category} budget. Consider reducing by ₹{int(budgets[worst_category].get('spent', 0) * 0.15):,}/month.",
                type=AdviceType.BUDGET,
                priority=AdvicePriority.HIGH,
                confidence=0.92,
                icon="⚠️",
                actionable=True,
                metadata={
                    "category": worst_category,
                    "utilization": worst_util,
                    "reduction_amount": budgets[worst_category].get('spent', 0) * 0.15,
                    "alternatives": self._suggest_alternatives(worst_category)
                }
            ))
        
        # Identify optimization opportunities
        underutilized = [(cat, util) for cat, util in utilization.items() if util < 0.5 and util > 0]
        if underutilized and len(overspent_categories) == 0:
            insights.append(AIInsight(
                id=f"budget_realloc_{int(datetime.now().timestamp())}",
                title="🔄 Smart Budget Reallocation",
                description=f"You're under-utilizing some budgets. Consider reallocating ₹{int(sum(budgets[cat].get('allocated', 0) - budgets[cat].get('spent', 0) for cat, _ in underutilized) * 0.7):,} to investments or savings.",
                type=AdviceType.OPTIMIZATION,
                priority=AdvicePriority.MEDIUM,
                confidence=0.78,
                icon="🔄",
                actionable=True,
                metadata={
                    "underutilized_categories": underutilized,
                    "potential_savings": sum(budgets[cat].get('allocated', 0) - budgets[cat].get('spent', 0) for cat, _ in underutilized) * 0.7
                }
            ))
        
        return insights

    def _analyze_investment_opportunities(self, investments: Dict, metrics: Dict) -> List[AIInsight]:
        """Investment strategy recommendations using ML-like analysis"""
        insights = []
        investment_ratio = metrics['investment_ratio']
        total_wealth = metrics['total_wealth']
        
        # Determine risk profile based on age/wealth (simulated)
        risk_profile = self._determine_risk_profile(total_wealth, metrics['emergency_fund_months'])
        strategy = self.investment_strategies[risk_profile]
        
        if investment_ratio < 0.1:
            insights.append(AIInsight(
                id=f"invest_start_{int(datetime.now().timestamp())}",
                title="🚀 Start Your Investment Journey",
                description=f"With {metrics['emergency_fund_months']:.1f} months emergency fund, start investing ₹{int(metrics['monthly_income'] * 0.15):,}/month. {risk_profile.title()} portfolio recommended.",
                type=AdviceType.INVESTMENT,
                priority=AdvicePriority.HIGH if metrics['emergency_fund_months'] >= 3 else AdvicePriority.MEDIUM,
                confidence=0.87,
                icon="🚀",
                actionable=True,
                metadata={
                    "risk_profile": risk_profile,
                    "recommended_monthly_sip": metrics['monthly_income'] * 0.15,
                    "portfolio_allocation": strategy,
                    "expected_return": strategy['expected_return']
                }
            ))
        elif investment_ratio < strategy['equity_ratio'] + strategy['debt_ratio']:
            insights.append(AIInsight(
                id=f"invest_optimize_{int(datetime.now().timestamp())}",
                title="📊 Optimize Investment Portfolio",
                description=f"Your current {investment_ratio*100:.1f}% investment ratio is good, but could reach {(strategy['equity_ratio'] + strategy['debt_ratio'])*100:.0f}% for better returns.",
                type=AdviceType.INVESTMENT,
                priority=AdvicePriority.MEDIUM,
                confidence=0.82,
                icon="📊",
                actionable=True,
                metadata={
                    "current_ratio": investment_ratio,
                    "target_ratio": strategy['equity_ratio'] + strategy['debt_ratio'],
                    "additional_investment_needed": total_wealth * (strategy['equity_ratio'] + strategy['debt_ratio'] - investment_ratio)
                }
            ))
        
        return insights

    def _analyze_spending_behavior(self, budgets: Dict, metrics: Dict) -> List[AIInsight]:
        """Behavioral spending analysis"""
        insights = []
        
        # Simulate spending pattern analysis
        current_month = datetime.now().strftime('%B').lower()
        seasonal_factor = self.spending_patterns['seasonal_multipliers'].get(current_month, 1.0)
        
        if seasonal_factor > 1.1:
            insights.append(AIInsight(
                id=f"seasonal_{current_month}_{int(datetime.now().timestamp())}",
                title=f"🎯 {current_month.title()} Spending Alert",
                description=f"Historically, spending increases {(seasonal_factor-1)*100:.0f}% in {current_month.title()}. Budget an extra ₹{int(metrics['monthly_expenses'] * (seasonal_factor - 1)):,} or reduce discretionary spending.",
                type=AdviceType.BEHAVIORAL,
                priority=AdvicePriority.MEDIUM,
                confidence=0.75,
                icon="🎯",
                actionable=True,
                metadata={
                    "seasonal_factor": seasonal_factor,
                    "month": current_month,
                    "extra_budget_needed": metrics['monthly_expenses'] * (seasonal_factor - 1)
                }
            ))
        
        # Identify potential lifestyle inflation
        if metrics['savings_rate'] < 0.1 and metrics['monthly_income'] > 50000:
            insights.append(AIInsight(
                id=f"lifestyle_inflation_{int(datetime.now().timestamp())}",
                title="📉 Lifestyle Inflation Warning",
                description=f"With good income but low {metrics['savings_rate']*100:.1f}% savings rate, you might be experiencing lifestyle inflation. Apply the 50-30-20 rule.",
                type=AdviceType.BEHAVIORAL,
                priority=AdvicePriority.HIGH,
                confidence=0.83,
                icon="📉",
                actionable=True,
                metadata={
                    "current_savings_rate": metrics['savings_rate'],
                    "recommended_savings": metrics['monthly_income'] * 0.2,
                    "needs_budget": metrics['monthly_income'] * 0.5,
                    "wants_budget": metrics['monthly_income'] * 0.3
                }
            ))
        
        return insights

    def _generate_predictions(self, metrics: Dict) -> List[AIInsight]:
        """Predictive financial insights"""
        insights = []
        
        # Predict future wealth based on current savings rate
        years_ahead = 5
        future_wealth = metrics['total_wealth'] * ((1 + metrics['savings_rate'] * 1.2) ** years_ahead)
        
        if future_wealth > metrics['total_wealth'] * 2:
            insights.append(AIInsight(
                id=f"prediction_wealth_{int(datetime.now().timestamp())}",
                title="🔮 Future Wealth Projection",
                description=f"At current savings rate, your wealth could grow to ₹{int(future_wealth):,} in {years_ahead} years. That's {future_wealth/metrics['total_wealth']:.1f}x growth!",
                type=AdviceType.PREDICTION,
                priority=AdvicePriority.LOW,
                confidence=0.70,
                icon="🔮",
                actionable=False,
                metadata={
                    "current_wealth": metrics['total_wealth'],
                    "projected_wealth": future_wealth,
                    "growth_factor": future_wealth/metrics['total_wealth'],
                    "years": years_ahead
                }
            ))
        
        return insights

    def _generate_behavioral_insights(self, metrics: Dict) -> List[AIInsight]:
        """Generate insights based on behavioral finance"""
        insights = []
        
        # Suggest automation based on behavioral patterns
        if metrics['savings_rate'] < 0.15:
            insights.append(AIInsight(
                id=f"automate_savings_{int(datetime.now().timestamp())}",
                title="🤖 Automate Your Success",
                description=f"Behavioral studies show people save 3x more with automation. Set up automatic transfer of ₹{int(metrics['monthly_income'] * 0.15):,} on salary day.",
                type=AdviceType.BEHAVIORAL,
                priority=AdvicePriority.MEDIUM,
                confidence=0.85,
                icon="🤖",
                actionable=True,
                metadata={
                    "recommended_automation": metrics['monthly_income'] * 0.15,
                    "behavioral_benefit": "3x more savings with automation",
                    "optimal_timing": "Within 2 days of salary credit"
                }
            ))
        
        return insights

    def _determine_risk_profile(self, wealth: float, emergency_months: float) -> str:
        """Determine investment risk profile based on financial stability"""
        if wealth < 500000 or emergency_months < 3:
            return 'conservative'
        elif wealth < 2000000 or emergency_months < 6:
            return 'moderate'
        else:
            return 'aggressive'

    def _suggest_alternatives(self, category: str) -> List[str]:
        """Suggest alternatives for high-spending categories"""
        alternatives = {
            'food': ['Cook more meals at home', 'Buy groceries in bulk', 'Use meal planning apps'],
            'entertainment': ['Free community events', 'Home streaming instead of cinema', 'Potluck parties'],
            'transport': ['Public transport', 'Carpooling', 'Walking/cycling for short distances'],
            'shopping': ['30-day rule before buying', 'Compare prices online', 'Buy during sales']
        }
        return alternatives.get(category.lower(), ['Track expenses daily', 'Set weekly spending limits'])


# FastAPI Integration (keeping your original structure)
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="Smart Financial AI Advisor", version="2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class UserData(BaseModel):
    balance: float
    budgets: dict
    investments: dict

# Initialize the smart advisor
advisor = SmartFinancialAdvisor()

@app.post("/generate_insights")
def generate_insights(data: UserData):
    """Generate intelligent financial insights"""
    try:
        insights = advisor.generate_smart_insights(
            balance=data.balance,
            budgets=data.budgets,
            investments=data.investments
        )
        
        # Convert to dict format for JSON response
        insights_dict = []
        for insight in insights:
            insights_dict.append({
                "id": insight.id,
                "title": insight.title,
                "description": insight.description,
                "type": insight.type.value,
                "priority": insight.priority.value,
                "confidence": insight.confidence,
                "icon": insight.icon,
                "actionable": insight.actionable,
                "metadata": insight.metadata,
                "actionHint": insight.action_hint
            })
        
        return {"insights": insights_dict}
    
    except Exception as e:
        return {"insights": [], "error": str(e)}

@app.get("/health")
def health_check():
    return {"status": "healthy", "message": "Smart Financial AI is running"}

# Optional: Add endpoint for financial health score
@app.post("/financial_health")
def get_financial_health(data: UserData):
    """Get detailed financial health analysis"""
    try:
        health_metrics = advisor.analyze_financial_health(
            balance=data.balance,
            budgets=data.budgets,
            investments=data.investments
        )
        return health_metrics
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)