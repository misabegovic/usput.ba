# usput's own laws, beside the four Rails ones enola:install wrote. Each
# carries its reason; the decisions they keep are in wiki/decisions/ and
# wiki/initiatives/. Ratchet (the default) fails a new breach and leaves the
# ones the baseline already carries quiet; strict fails any breach at all.
Enola.architecture "usput" do
  rails

  part :app_code,   files: "app/**"
  part :platform,   files: "lib/platform/**"
  part :ai_seam,    files: "app/services/ai/openai_queue.rb"
  part :ai,         files: "app/services/ai/**"
  part :services,   files: "app/services/**"
  part :avo_controllers, files: "app/controllers/avo/**", kind: :symbol,
                         where: { symbol_kind: "class" }
  part :policy_gate, files: "app/controllers/concerns/admin_resource.rb"
  part :job_classes,    files: "app/jobs/**", kind: :symbol, where: { symbol_kind: "class" }
  part :policy_classes, files: "app/policies/**", kind: :symbol, where: { symbol_kind: "class" }

  # One door to a language model (wiki/initiatives/rubyllm-2-upgrade.md).
  law "only Ai::OpenaiQueue opens a chat with a model" do
    app_code.must_not_call "RubyLLM.chat"
    why "one seam keeps retries, error mapping, cost and Langfuse tracing in one place; a second door has none of them"
    exempt "Ai::OpenaiQueue#initialize -> RubyLLM.chat via calls",
           because: "this is the seam", owner: "usput", since: "2026-10-14"
    exempt "prism-call: Ai::OpenaiQueue#initialize -> RubyLLM.chat -> RubyLLM.chat via calls",
           because: "this is the seam, as the Prism extractor records the same call", owner: "usput", since: "2026-10-14"
  end

  law "the Platform DSL reaches models through the seam too" do
    platform.must_not_call "RubyLLM.chat"
    why "LLMHelper#generate_with_llm still opens its own chat; the rubyllm-2 initiative moves it behind Ai::OpenaiQueue, and nothing new may join it"
  end

  # The app never leans on the agents' tooling (wiki/architecture/overview.md).
  law "the app never depends on the Platform DSL" do
    app_code.must_not_call platform
    why "lib/platform is the agents' command line over the same models; the app must run, and deploy, without it"
    mode :strict
  end

  # A request never waits on a model (rubyllm-2 initiative, Jev review flagging).
  law "controllers never wait on a language model" do
    controllers.must_not_call ai
    why "a model call takes seconds and fails in ways a page cannot recover from; generation runs in a job"
  end

  # Avo Community authorizes nothing by itself (wiki/initiatives/avo-admin-and-roles.md).
  law "every Avo resource controller passes the policy gate" do
    avo_controllers.must_reach policy_gate, via: :implements, direction: :outbound
    why "Avo's authorization service is a null object in Community; a controller without AdminResource opens its records to every curator"
    mode :strict
    exempt "Avo::ToolsController has no outbound calls edge into policy-gate",
           because: "the tools controller renders only the welcome page, which holds no records; it sits behind the curator gate in the route and in Avo",
           owner: "usput", since: "2026-10-14"
  end

  law "services never read the request's params" do
    services.must_not_call "params", receiver: :none
    why "a service that reads params only works inside a request and cannot be called from a job, the DSL or a test"
    exempt "prism-call: GuestPayloadStash#store -> params -> params via calls",
           because: "it reads request.params from the Rack request OmniAuth hands it before leaving for Google; the extractor drops the receiver",
           owner: "usput", since: "2026-10-14"
  end

  law "jobs are named for what runs them" do
    job_classes.names_must_match "*Job"
    why "Solid Queue and the job tests find jobs by the suffix"
  end

  law "policies are named for what they authorize" do
    policy_classes.names_must_match "*Policy"
    why "AdminPolicy.for resolves a model's policy from its class name"
  end
end
