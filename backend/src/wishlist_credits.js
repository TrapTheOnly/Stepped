import { readNonEmptyString, startOfNextMonthUtc } from './planner_utils.js';

export function buildWishlistCreditsPayload(planHeader) {
  const plan = readNonEmptyString(planHeader) === 'plus' ? 'plus' : 'free';
  const monthlyCredits = plan === 'plus' ? 150 : 10;
  const dailyBurstLimit = plan === 'plus' ? 25 : 2;
  const rewardedMonthlyCap = 20;
  return {
    plan,
    generation_cost_credits: 1,
    monthly_limit: monthlyCredits,
    remaining_credits: monthlyCredits,
    daily_burst_limit: dailyBurstLimit,
    rewarded_ad_monthly_limit: rewardedMonthlyCap,
    rewarded_ad_remaining: rewardedMonthlyCap,
    next_reset_at: startOfNextMonthUtc(),
  };
}
