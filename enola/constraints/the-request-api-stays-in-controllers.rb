Enola.architecture "app" do
  rails

  law "the request api stays in controllers" do
    models.must_not_call "params", receiver: :none
    why "params without a receiver is the controller's; a model reading it only works inside a request"
    mode :ratchet
  end
end
