# frozen_string_literal: true

module Platform
  module Services
    # SpamDetector - Detects spam patterns in curator activities
    #
    # Analyzes curator behavior to identify potential spam:
    # - High activity rates (unusual number of actions)
    # - Repetitive content (duplicate submissions)
    # - Suspicious patterns (bulk actions in short time)
    #
    # @example Check all curators for spam
    #   SpamDetector.check_all
    #
    # @example Check specific curator
    #   SpamDetector.check_curator(user)
    #
    class SpamDetector
      # Thresholds for spam detection
      HOURLY_THRESHOLD = 30        # Actions per hour considered suspicious
      DAILY_THRESHOLD = 150        # Actions per day considered suspicious
      BURST_THRESHOLD = 10         # Actions in 5 minutes considered suspicious
      DUPLICATE_THRESHOLD = 5      # Same action type in a row
      BLOCK_DURATION = 24.hours

      class << self
        # Check all curators for spam patterns
        #
        # @return [Hash] Summary of spam check results
        def check_all
          curators = User.curator.where(spam_blocked_until: nil)

          results = {
            checked: 0,
            blocked: 0,
            warnings: [],
            blocked_users: []
          }

          curators.find_each do |curator|
            result = check_curator(curator)
            results[:checked] += 1

            if result[:blocked]
              results[:blocked] += 1
              results[:blocked_users] << {
                id: curator.id,
                username: curator.username,
                reason: result[:reason]
              }
            elsif result[:warning]
              results[:warnings] << {
                id: curator.id,
                username: curator.username,
                warning: result[:warning]
              }
            end
          end

          results
        end

        # Check a specific curator for spam patterns
        #
        # @param curator [User] The curator to check
        # @param auto_block [Boolean] Whether to automatically block if spam detected
        # @return [Hash] Check result with status and details
        def check_curator(curator, auto_block: true)
          return { error: "Not a curator" } unless curator.curator?
          return { already_blocked: true } if curator.spam_blocked?

          analysis = analyze_activity(curator)

          if analysis[:is_spam]
            if auto_block
              curator.block_for_spam!(analysis[:reason])
            end
            { blocked: true, reason: analysis[:reason], details: analysis }
          elsif analysis[:suspicious]
            { warning: true, message: analysis[:warning], details: analysis }
          else
            { ok: true, details: analysis }
          end
        end

        # Analyze a curator's activity patterns
        #
        # @param curator [User] The curator to analyze
        # @return [Hash] Analysis results
        def analyze_activity(curator)
          activities = curator.curator_activities

          hourly_count = activities.this_hour.count
          daily_count = activities.today.count
          burst_count = activities.where("created_at >= ?", 5.minutes.ago).count

          # Check for duplicate content submissions
          recent_actions = activities.recent.limit(20).pluck(:action, :recordable_type, :recordable_id)
          duplicate_score = calculate_duplicate_score(recent_actions)

          # Check for suspicious patterns
          patterns = detect_patterns(activities)

          result = {
            curator_id: curator.id,
            username: curator.username,
            hourly_count: hourly_count,
            daily_count: daily_count,
            burst_count: burst_count,
            duplicate_score: duplicate_score,
            patterns: patterns,
            is_spam: false,
            suspicious: false,
            reason: nil,
            warning: nil
          }

          # Evaluate thresholds
          if hourly_count >= HOURLY_THRESHOLD
            result[:is_spam] = true
            result[:reason] = "Exceeded #{HOURLY_THRESHOLD} actions per hour (#{hourly_count})"
          elsif daily_count >= DAILY_THRESHOLD
            result[:is_spam] = true
            result[:reason] = "Exceeded #{DAILY_THRESHOLD} actions per day (#{daily_count})"
          elsif burst_count >= BURST_THRESHOLD
            result[:is_spam] = true
            result[:reason] = "Burst activity: #{burst_count} actions in 5 minutes"
          elsif duplicate_score >= DUPLICATE_THRESHOLD
            result[:is_spam] = true
            result[:reason] = "Repetitive actions detected (score: #{duplicate_score})"
          elsif patterns[:suspicious_ip_changes]
            result[:suspicious] = true
            result[:warning] = "Multiple IP address changes detected"
          elsif hourly_count >= HOURLY_THRESHOLD * 0.7
            result[:suspicious] = true
            result[:warning] = "Approaching hourly limit (#{hourly_count}/#{HOURLY_THRESHOLD})"
          end

          result
        end

        # Get spam statistics for reporting
        #
        # @return [Hash] Spam statistics
        def statistics
          {
            total_curators: User.curator.count,
            currently_blocked: User.curator.where("spam_blocked_until > ?", Time.current).count,
            blocked_today: User.curator.where("spam_blocked_at >= ?", Time.current.beginning_of_day).count,
            high_activity_curators: high_activity_curators.map do |c|
              {
                id: c.id,
                username: c.username,
                activity_today: c.activity_count_today
              }
            end
          }
        end

        private

        def calculate_duplicate_score(actions)
          return 0 if actions.size < 2

          # Count consecutive same actions
          max_consecutive = 1
          current_consecutive = 1

          actions.each_cons(2) do |prev, curr|
            if prev[0] == curr[0] && prev[1] == curr[1]
              current_consecutive += 1
              max_consecutive = [ max_consecutive, current_consecutive ].max
            else
              current_consecutive = 1
            end
          end

          max_consecutive
        end

        def detect_patterns(activities)
          patterns = {
            suspicious_ip_changes: false,
            after_hours_activity: false,
            bulk_deletions: false
          }

          recent = activities.recent.limit(50)

          # Check for IP changes
          ips = recent.pluck(:ip_address).compact.uniq
          patterns[:suspicious_ip_changes] = ips.size > 5

          # Check for after-hours activity (2am-5am local time)
          after_hours = recent.where("EXTRACT(HOUR FROM created_at) BETWEEN 2 AND 5").count
          patterns[:after_hours_activity] = after_hours > 10

          # Check for bulk deletions
          deletions = recent.where(action: "proposal_deleted").count
          patterns[:bulk_deletions] = deletions > 5

          patterns
        end

        def high_activity_curators
          User.curator
              .where("activity_count_today > ?", (User::MAX_ACTIVITIES_PER_DAY * 0.5).to_i)
              .order(activity_count_today: :desc)
              .limit(10)
        end
      end
    end
  end
end
