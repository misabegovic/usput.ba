Enola.architecture "app" do
  rails

  law "policies only answer" do
    policies.must_not_call jobs
    why "authorization is asked many times per request and sometimes speculatively"
    mode :ratchet
  end
end
