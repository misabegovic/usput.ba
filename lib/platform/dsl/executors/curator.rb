# frozen_string_literal: true

module Platform
  module DSL
    module Executors
      # Curator executor - handles curator management
      #
      # Query types:
      # - curators_query: list/show curators
      # - curator_management: block/unblock curators
      #
      module Curator
        class << self
          # Execute curators query
          def execute_curators_query(ast)
            filters = ast[:filters] || {}
            operation = ast[:operations]&.first

            case operation&.dig(:name)
            when :list, nil
              list_curators(filters)
            when :show
              show_curator(filters)
            when :activity
              show_curator_activity(filters)
            when :check_spam
              check_spam(filters)
            when :count
              count_curators(filters)
            when :stats
              curator_stats
            else
              list_curators(filters)
            end
          end

          # Execute curator management
          def execute_curator_management(ast)
            action = ast[:action]
            filters = ast[:filters]

            case action
            when :block
              block_curator(filters, ast[:reason])
            when :unblock
              unblock_curator(filters)
            else
              raise ExecutionError, "Nepoznata curator management akcija: #{action}"
            end
          end

          private

          def platform_admin_user
            User.find_by(user_type: :admin) || User.find_by(username: "platform_system") || create_platform_user
          end

          def create_platform_user
            admin = User.admin.first
            return admin if admin

            # A system account nobody signs in to: an address that can never
            # receive mail, confirmed so that no confirmation is ever sent.
            User.create!(
              username: "platform_system",
              email: "platform_system@usput.invalid",
              user_type: :admin,
              password: SecureRandom.hex(32)
            ) { |user| user.skip_confirmation! }
          rescue => e
            Rails.logger.error "Failed to create platform user: #{e.message}"
            raise ExecutionError, "Nije moguće pronaći admin korisnika za odobravanje"
          end

          # ===================
          # Curators query methods
          # ===================

          def list_curators(filters)
            scope = User.curator

            if filters[:status] == "blocked"
              scope = scope.where("spam_blocked_until > ?", Time.current)
            elsif filters[:status] == "active"
              scope = scope.where(spam_blocked_until: nil)
            end

            if filters[:high_activity]
              scope = scope.where("activity_count_today > ?", (User::MAX_ACTIVITIES_PER_DAY * 0.5).to_i)
            end

            curators = scope.order(created_at: :desc).limit(50)

            {
              action: :list_curators,
              count: curators.size,
              total_curators: User.curator.count,
              total_blocked: User.curator.where("spam_blocked_until > ?", Time.current).count,
              curators: curators.map { |c| format_curator(c) }
            }
          end

          def show_curator(filters)
            curator = find_curator(filters)

            {
              action: :show_curator,
              id: curator.id,
              username: curator.username,
              user_type: curator.user_type,
              created_at: curator.created_at.iso8601,
              spam_blocked: curator.spam_blocked?,
              spam_block_reason: curator.spam_block_reason,
              spam_blocked_until: curator.spam_blocked_until&.iso8601,
              activity_count_today: curator.activity_count_today,
              total_activities: curator.curator_activities.count
            }
          end

          def show_curator_activity(filters)
            curator = find_curator(filters)
            limit = filters[:limit] || 20

            activities = curator.curator_activities.recent.limit(limit)

            {
              action: :curator_activity,
              curator_id: curator.id,
              username: curator.username,
              activity_count_today: curator.activity_count_today,
              activities: activities.map do |a|
                {
                  action: a.action,
                  description: a.description,
                  recordable_type: a.recordable_type,
                  recordable_id: a.recordable_id,
                  created_at: a.created_at.iso8601
                }
              end,
              summary: {
                by_action: curator.curator_activities.today.group(:action).count,
                total_today: curator.curator_activities.today.count,
                total_this_hour: curator.curator_activities.this_hour.count
              }
            }
          end

          def check_spam(filters)
            if filters[:id]
              curator = find_curator(filters)
              result = Services::SpamDetector.check_curator(curator, auto_block: false)

              {
                action: :check_spam,
                curator_id: curator.id,
                username: curator.username,
                result: result
              }
            else
              result = Services::SpamDetector.check_all

              {
                action: :check_spam_all,
                result: result,
                statistics: Services::SpamDetector.statistics
              }
            end
          end

          def count_curators(filters)
            {
              total: User.curator.count,
              active: User.curator.where(spam_blocked_until: nil).count,
              blocked: User.curator.where("spam_blocked_until > ?", Time.current).count,
              high_activity: User.curator.where("activity_count_today > ?", (User::MAX_ACTIVITIES_PER_DAY * 0.5).to_i).count
            }
          end

          def curator_stats
            Services::SpamDetector.statistics
          end

          def find_curator(filters)
            raise ExecutionError, "Potreban filter: id ili username" unless filters[:id] || filters[:username]

            curator = if filters[:id]
                        User.find_by(id: filters[:id])
            else
                        User.find_by(username: filters[:username])
            end

            raise ExecutionError, "Kurator nije pronađen" unless curator
            raise ExecutionError, "Korisnik nije kurator" unless curator.curator? || curator.admin?

            curator
          end

          def format_curator(curator)
            {
              id: curator.id,
              username: curator.username,
              spam_blocked: curator.spam_blocked?,
              activity_count_today: curator.activity_count_today,
              created_at: curator.created_at.iso8601
            }
          end

          # ===================
          # Curator management methods
          # ===================

          def block_curator(filters, reason)
            curator = find_curator(filters)

            if curator.spam_blocked?
              raise ExecutionError, "Kurator je već blokiran (do #{curator.spam_blocked_until})"
            end

            raise ExecutionError, "Potreban razlog za blokiranje" if reason.blank?

            curator.block_for_spam!(reason)

            {
              success: true,
              action: :block_curator,
              curator_id: curator.id,
              username: curator.username,
              reason: reason,
              blocked_until: curator.spam_blocked_until.iso8601,
              message: "Kurator je blokiran do #{curator.spam_blocked_until}"
            }
          end

          def unblock_curator(filters)
            curator = find_curator(filters)

            unless curator.spam_blocked?
              raise ExecutionError, "Kurator nije blokiran"
            end

            old_reason = curator.spam_block_reason
            curator.admin_unblock!

            {
              success: true,
              action: :unblock_curator,
              curator_id: curator.id,
              username: curator.username,
              message: "Kurator je odblokiran"
            }
          end
        end
      end
    end
  end
end
