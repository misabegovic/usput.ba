# frozen_string_literal: true

module Platform
  module DSL
    module Executors
      # Curator executor - handles proposals, applications, approval, and curator management
      #
      # Query types:
      # - proposals_query: list/show content change proposals
      # - applications_query: list/show curator applications
      # - approval: approve/reject proposals and applications
      # - curators_query: list/show curators
      # - curator_management: block/unblock curators
      #
      module Curator
        class << self
          # Execute proposals query
          def execute_proposals_query(ast)
            filters = ast[:filters] || {}
            operation = ast[:operations]&.first

            case operation&.dig(:name)
            when :list, nil
              list_proposals(filters)
            when :show
              show_proposal(filters)
            when :count
              count_proposals(filters)
            else
              list_proposals(filters)
            end
          end

          # Execute applications query
          def execute_applications_query(ast)
            filters = ast[:filters] || {}
            operation = ast[:operations]&.first

            case operation&.dig(:name)
            when :list, nil
              list_applications(filters)
            when :show
              show_application(filters)
            when :count
              count_applications(filters)
            else
              list_applications(filters)
            end
          end

          # Execute approval action
          def execute_approval(ast)
            action = ast[:action]
            type = ast[:approval_type]
            filters = ast[:filters]

            case action
            when :approve
              if type == :proposal
                approve_proposal(filters, ast[:notes])
              else
                approve_application(filters, ast[:notes])
              end
            when :reject
              if type == :proposal
                reject_proposal(filters, ast[:reason])
              else
                reject_application(filters, ast[:reason])
              end
            else
              raise ExecutionError, "Nepoznata approval akcija: #{action}"
            end
          end

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

          # ===================
          # Proposals methods
          # ===================

          def list_proposals(filters)
            scope = ContentChange.all

            if filters[:status]
              status = filters[:status].to_s
              scope = scope.where(status: status) if ContentChange.statuses.key?(status)
            else
              scope = scope.pending
            end

            if filters[:change_type] || filters[:type]
              change_type = (filters[:change_type] || filters[:type]).to_s
              scope = scope.where(change_type: change_type) if ContentChange.change_types.key?(change_type)
            end

            if filters[:content_type]
              scope = scope.where(changeable_type: filters[:content_type].to_s.classify)
            end

            proposals = scope.order(created_at: :desc).limit(50)

            {
              action: :list_proposals,
              count: proposals.size,
              total_pending: ContentChange.pending.count,
              proposals: proposals.map { |p| format_proposal(p) }
            }
          end

          def show_proposal(filters)
            proposal = find_proposal(filters)

            {
              action: :show_proposal,
              id: proposal.id,
              status: proposal.status,
              change_type: proposal.change_type,
              changeable_type: proposal.changeable_type || proposal.changeable_class,
              changeable_id: proposal.changeable_id,
              description: proposal.description,
              proposed_data: proposal.proposed_data,
              original_data: proposal.original_data,
              changes_diff: proposal.changes_diff,
              proposer: {
                id: proposal.user_id,
                username: proposal.user.username
              },
              contributors: proposal.all_contributors.map { |u| { id: u.id, username: u.username } },
              reviews: proposal.curator_reviews.map do |r|
                {
                  user: r.user.username,
                  recommendation: r.recommendation,
                  comment: r.comment.truncate(100)
                }
              end,
              recommendation_summary: proposal.recommendation_summary,
              created_at: proposal.created_at.iso8601,
              reviewed_at: proposal.reviewed_at&.iso8601,
              reviewed_by: proposal.reviewed_by&.username
            }
          end

          def count_proposals(filters)
            {
              pending: ContentChange.pending.count,
              approved: ContentChange.approved.count,
              rejected: ContentChange.rejected.count,
              total: ContentChange.count,
              by_type: ContentChange.group(:change_type).count,
              by_content_type: ContentChange.group(:changeable_type).count
            }
          end

          def find_proposal(filters)
            raise ExecutionError, "Potreban filter: id" unless filters[:id]

            proposal = ContentChange.find_by(id: filters[:id])
            raise ExecutionError, "Proposal sa id=#{filters[:id]} nije pronađen" unless proposal

            proposal
          end

          def format_proposal(proposal)
            {
              id: proposal.id,
              status: proposal.status,
              change_type: proposal.change_type,
              description: proposal.description,
              content_type: proposal.changeable_type || proposal.changeable_class,
              proposer: proposal.user.username,
              contributors_count: proposal.all_contributors.size,
              reviews_count: proposal.curator_reviews.count,
              recommendation_summary: proposal.recommendation_summary,
              created_at: proposal.created_at.iso8601
            }
          end

          # ===================
          # Applications methods
          # ===================

          def list_applications(filters)
            scope = CuratorApplication.all

            if filters[:status]
              status = filters[:status].to_s
              scope = scope.where(status: status) if CuratorApplication.statuses.key?(status)
            else
              scope = scope.pending
            end

            applications = scope.recent.limit(50)

            {
              action: :list_applications,
              count: applications.size,
              total_pending: CuratorApplication.pending.count,
              applications: applications.map { |a| format_application(a) }
            }
          end

          def show_application(filters)
            application = find_application(filters)

            {
              action: :show_application,
              id: application.id,
              status: application.status,
              user: {
                id: application.user_id,
                username: application.user.username
              },
              motivation: application.motivation,
              experience: application.experience,
              created_at: application.created_at.iso8601,
              reviewed_at: application.reviewed_at&.iso8601,
              reviewed_by: application.reviewed_by&.username,
              admin_notes: application.admin_notes
            }
          end

          def count_applications(filters)
            {
              pending: CuratorApplication.pending.count,
              approved: CuratorApplication.approved.count,
              rejected: CuratorApplication.rejected.count,
              total: CuratorApplication.count
            }
          end

          def find_application(filters)
            raise ExecutionError, "Potreban filter: id" unless filters[:id]

            application = CuratorApplication.find_by(id: filters[:id])
            raise ExecutionError, "Application sa id=#{filters[:id]} nije pronađena" unless application

            application
          end

          def format_application(application)
            {
              id: application.id,
              status: application.status,
              user: {
                id: application.user_id,
                username: application.user.username
              },
              motivation_preview: application.motivation.truncate(100),
              created_at: application.created_at.iso8601
            }
          end

          # ===================
          # Approval methods
          # ===================

          def approve_proposal(filters, notes)
            proposal = find_proposal(filters)

            unless proposal.pending?
              raise ExecutionError, "Proposal nije u pending statusu (trenutni status: #{proposal.status})"
            end

            admin = platform_admin_user
            success = proposal.approve!(admin, notes: notes)

            unless success
              raise ExecutionError, "Odobravanje prijedloga nije uspjelo"
            end

            {
              success: true,
              action: :approve_proposal,
              proposal_id: proposal.id,
              change_type: proposal.change_type,
              content_type: proposal.changeable_type || proposal.changeable_class,
              notes: notes,
              message: "Prijedlog je odobren i promjene su primijenjene"
            }
          end

          def reject_proposal(filters, reason)
            proposal = find_proposal(filters)

            unless proposal.pending?
              raise ExecutionError, "Proposal nije u pending statusu (trenutni status: #{proposal.status})"
            end

            raise ExecutionError, "Potreban razlog za odbijanje" if reason.blank?

            admin = platform_admin_user
            proposal.reject!(admin, notes: reason)

            {
              success: true,
              action: :reject_proposal,
              proposal_id: proposal.id,
              reason: reason,
              message: "Prijedlog je odbijen"
            }
          end

          def approve_application(filters, notes)
            application = find_application(filters)

            unless application.pending?
              raise ExecutionError, "Application nije u pending statusu (trenutni status: #{application.status})"
            end

            admin = platform_admin_user
            application.approve!(admin)

            {
              success: true,
              action: :approve_application,
              application_id: application.id,
              user: {
                id: application.user_id,
                username: application.user.username
              },
              message: "Prijava za kuratora je odobrena. Korisnik je sada kurator."
            }
          end

          def reject_application(filters, reason)
            application = find_application(filters)

            unless application.pending?
              raise ExecutionError, "Application nije u pending statusu (trenutni status: #{application.status})"
            end

            raise ExecutionError, "Potreban razlog za odbijanje" if reason.blank?

            admin = platform_admin_user
            application.reject!(admin, reason)

            {
              success: true,
              action: :reject_application,
              application_id: application.id,
              reason: reason,
              message: "Prijava za kuratora je odbijena"
            }
          end

          def platform_admin_user
            User.find_by(user_type: :admin) || User.find_by(username: "platform_system") || create_platform_user
          end

          def create_platform_user
            admin = User.admin.first
            return admin if admin

            User.create!(
              username: "platform_system",
              user_type: :admin,
              password: SecureRandom.hex(32)
            )
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
              total_activities: curator.curator_activities.count,
              proposals_count: curator.content_changes.count,
              reviews_count: curator.curator_reviews.count
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
