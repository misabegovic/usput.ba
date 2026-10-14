Enola.architecture "app" do
  rails

  law "models do not reach controllers" do
    models.must_not_call controllers
    why "a model that knows the request cannot be used off the request"
    mode :ratchet
  end
end
