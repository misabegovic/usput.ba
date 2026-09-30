# `rate_limit` keeps the store it is given when the controller class loads.
# Handing it this module instead makes every count go to whatever Rails.cache
# is at request time, the shared Solid Cache in production.
module RateLimitStore
  def self.increment(name, amount = 1, **options)
    Rails.cache.increment(name, amount, **options)
  end
end
