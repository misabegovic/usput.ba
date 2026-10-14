Enola.architecture "app" do
  rails

  law "background jobs never invoke controller code" do
    jobs.must_not_call controllers
    why "rendering from a job goes through ApplicationController.renderer"
    mode :ratchet
  end
end
