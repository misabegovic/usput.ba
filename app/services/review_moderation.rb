# frozen_string_literal: true

# The one place that asks Jev, TypeSafe's decision model, about a review, and
# the one place that turns its answer into a band
# (wiki/decisions/jev-decides-reviews.md):
#
#   approved  both answers below approve_below: public at once
#   rejected  either answer above reject_above: hidden; its author still sees it
#   held      anything between, or no answer at all: a curator decides
#
# Jev is asked whether the review is abusive and whether it is spam, never
# whether it is negative: an honest bad review is approved. Only the comment
# and the rating leave usput; no name, account, place or address. Asking never
# raises: a missing key, a timeout or an error is a named skip, and a skipped
# review is held for a curator rather than published or lost.
module ReviewModeration
  extend PromptHelper

  QUESTIONS = { abusive: "review_judge/abusive.md", spam: "review_judge/spam.md" }.freeze
  BAND_EVENTS = { approved: ReviewApproved, held: ReviewHeld, rejected: ReviewRejected }.freeze

  Result = Data.define(:band, :answers, :model, :skip)

  class << self
    def config
      Rails.application.config_for(:review_moderation)
    end

    def enforcing?
      config[:mode].to_s == "enforce"
    end

    # The state a review enters when a traveller submits it.
    def initial_status
      enforcing? ? :pending : :approved
    end

    def screen(review)
      return Result.new(band: :approved, answers: {}, model: nil, skip: "no_comment") if review.comment.blank?
      return skipped("no_key") if RubyLLM.config.typesafe_api_key.blank?

      judgment = RubyLLM.judge({ review: review.comment, rating: review.rating },
                               questions: questions, model: config[:model])
      answers = QUESTIONS.keys.to_h { |name| [ name.to_s, judgment[name].probability.to_f ] }
      Result.new(band: band_for(answers.values.max), answers: answers, model: judgment.model, skip: nil)
    rescue StandardError => e
      skipped("error: #{e.class}")
    end

    # Records Jev's reading on the review and in its stream; in enforce mode
    # also decides a review still waiting. A curator's later decision wins.
    def apply(review, result)
      ActiveRecord::Base.transaction do
        review.update!(jev_answers: result.answers, jev_model: result.model, jev_band: result.band.to_s,
                       jev_skip: result.skip, judged_at: Time.current)
        DecisionLog.publish(ReviewJudged, review, by: nil, answers: result.answers, band: result.band.to_s,
                            model: result.model, skip: result.skip, mode: config[:mode].to_s)
        next unless enforcing? && review.pending?

        review.update!(moderation_status: result.band)
        DecisionLog.publish(BAND_EVENTS.fetch(result.band), review, by: nil, decided_by: "jev")
      end
    end

    def band_for(probability)
      return :approved if probability < config[:approve_below]
      return :rejected if probability > config[:reject_above]

      :held
    end

    private

    def questions
      QUESTIONS.transform_values { |path| { type: :probability, instructions: load_prompt(path) } }
    end

    def skipped(reason)
      Result.new(band: :held, answers: {}, model: nil, skip: reason)
    end
  end
end
