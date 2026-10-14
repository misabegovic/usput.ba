# frozen_string_literal: true

require "test_helper"

class ReviewModerationTest < ActiveSupport::TestCase
  ENFORCE = { mode: "enforce", approve_below: 0.35, reject_above: 0.85, model: "jev-latest" }.freeze
  OBSERVE = ENFORCE.merge(mode: "observe").freeze

  setup do
    @place = Location.create!(name: "Kozija ćuprija", city: "Sarajevo", lat: 43.8569, lng: 18.4510)
    @author = User.create!(username: "jev_author", email: "jev_author@example.com", password: "password123")
  end

  def review(comment: "Lijepo mjesto, mirno i čisto.", status: :pending)
    @place.reviews.create!(rating: 4, comment: comment, user: @author, moderation_status: status)
  end

  def judgment(abusive:, spam:, model: "jev-1.13.0")
    answers = { "abusive" => RubyLLM::Probability.new(probability: abusive),
                "spam" => RubyLLM::Probability.new(probability: spam) }
    RubyLLM::Judgment.new(answers: answers, model: model)
  end

  def with_jev(answer, config: ENFORCE, &block)
    sent = []
    judge = ->(state, **options) { sent << [ state, options ]; answer.is_a?(Exception) ? raise(answer) : answer }
    RubyLLM.config.stub(:typesafe_api_key, "test-key") do
      ReviewModeration.stub(:config, config) do
        RubyLLM.stub(:judge, judge, &block)
      end
    end
    sent
  end

  # === The bands ===

  test "a review Jev reads as clearly fine is approved" do
    result = nil
    with_jev(judgment(abusive: 0.02, spam: 0.05)) { result = ReviewModeration.screen(review) }

    assert_equal :approved, result.band
    assert_equal "jev-1.13.0", result.model
  end

  test "a review Jev reads as clearly abusive or spam is rejected" do
    result = nil
    with_jev(judgment(abusive: 0.1, spam: 0.97)) { result = ReviewModeration.screen(review) }

    assert_equal :rejected, result.band
  end

  test "a review Jev is unsure about waits for a curator" do
    result = nil
    with_jev(judgment(abusive: 0.5, spam: 0.1)) { result = ReviewModeration.screen(review) }

    assert_equal :held, result.band
  end

  test "Jev is asked only about abuse and spam, never whether the review is negative" do
    sent = with_jev(judgment(abusive: 0.0, spam: 0.0)) { ReviewModeration.screen(review(comment: "Grozno, nikad više.")) }

    state, options = sent.sole
    assert_equal %i[abusive spam], options[:questions].keys
    assert_equal "jev-latest", options[:model]
    assert_equal({ review: "Grozno, nikad više.", rating: 4 }, state, "only the text and the rating leave usput")
  end

  # === Skips, which never raise ===

  test "a review without a comment is approved without asking" do
    asked = with_jev(judgment(abusive: 1.0, spam: 1.0)) { @result = ReviewModeration.screen(review(comment: "")) }

    assert_empty asked
    assert_equal :approved, @result.band
    assert_equal "no_comment", @result.skip
  end

  test "with no TypeSafe key the review is held and nothing is sent" do
    RubyLLM.config.stub(:typesafe_api_key, nil) do
      RubyLLM.stub(:judge, ->(*) { flunk "Jev must not be asked without a key" }) do
        result = ReviewModeration.screen(review)

        assert_equal :held, result.band
        assert_equal "no_key", result.skip
      end
    end
  end

  test "an error from Jev is a named skip that holds the review" do
    result = nil
    with_jev(RubyLLM::RateLimitError.new("slow down")) { result = ReviewModeration.screen(review) }

    assert_equal :held, result.band
    assert_equal "error: RubyLLM::RateLimitError", result.skip
  end

  # === Applying a reading ===

  test "in enforce mode Jev's band decides a waiting review and both steps are recorded" do
    waiting = review
    ReviewModeration.stub(:config, ENFORCE) do
      ReviewModeration.apply(waiting, ReviewModeration::Result.new(band: :rejected, answers: { "abusive" => 0.9 },
                                                                    model: "jev-1.13.0", skip: nil))
    end

    assert waiting.reload.rejected?
    assert_equal "rejected", waiting.jev_band
    assert_equal [ ReviewJudged, ReviewRejected ], DecisionLog.history(waiting).map(&:class)
    assert_equal "jev", DecisionLog.history(waiting).last.data[:decided_by]
  end

  test "in observe mode the review stays as it is and only the reading is recorded" do
    live = review(status: :approved)
    ReviewModeration.stub(:config, OBSERVE) do
      ReviewModeration.apply(live, ReviewModeration::Result.new(band: :rejected, answers: { "spam" => 0.95 },
                                                                 model: "jev-1.13.0", skip: nil))
    end

    assert live.reload.approved?
    assert_equal "rejected", live.jev_band, "what Jev would have decided, for measuring"
    assert_equal [ ReviewJudged ], DecisionLog.history(live).map(&:class)
  end

  test "a curator's earlier decision is not undone by a late answer" do
    decided = review(status: :approved)
    ReviewModeration.stub(:config, ENFORCE) do
      ReviewModeration.apply(decided, ReviewModeration::Result.new(band: :rejected, answers: {}, model: "jev-1.13.0", skip: nil))
    end

    assert decided.reload.approved?
  end
end
