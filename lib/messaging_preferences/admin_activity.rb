# frozen_string_literal: true

module ::MessagingPreferences
  class AdminActivity
    PERIODS = {
      "7" => 7,
      "30" => 30,
      "90" => 90,
      "all" => nil,
    }.freeze
    EVENT_FILTERS = {
      "all" => ::MessagingPreferences::Event::EVENT_TYPES,
      "preference_changes" => ::MessagingPreferences::Event::PREFERENCE_EVENT_TYPES,
      "acknowledgements" => [::MessagingPreferences::Event::ACKNOWLEDGEMENT_EVENT_TYPE],
    }.freeze
    DEFAULT_PERIOD = "30"
    DEFAULT_EVENT_FILTER = "all"
    EVENTS_PER_PAGE = 25
    RELATIONSHIP_LIMIT = 100

    class << self
      def payload(
        user_id: nil,
        period: DEFAULT_PERIOD,
        event_filter: DEFAULT_EVENT_FILTER,
        page: 1,
        user_page: 1
      )
        period = normalize_period(period)
        event_filter = normalize_event_filter(event_filter)
        page = normalize_page(page)
        user_page = normalize_page(user_page)
        states = preference_states
        acknowledgements = acknowledgement_rows
        filtered_scope = filtered_event_scope(period: period, event_filter: event_filter)
        selected_user =
          if user_id.present?
            user_payload(
              user_id,
              states,
              filtered_scope: filtered_scope,
              page: user_page,
            )
          end

        {
          generated_at: Time.zone.now.iso8601(6),
          filters: filter_payload(period: period, event_filter: event_filter),
          summary: summary(states, acknowledgements),
          trend: trend_payload(period),
          recent_events: paginated_events(filtered_scope, page),
          selected_user: selected_user,
          maintenance: ::MessagingPreferences::DataMaintenance.status(user_id: user_id),
        }
      end

      private

      def normalize_period(value)
        value = value.to_s
        PERIODS.key?(value) ? value : DEFAULT_PERIOD
      end

      def normalize_event_filter(value)
        value = value.to_s
        EVENT_FILTERS.key?(value) ? value : DEFAULT_EVENT_FILTER
      end

      def normalize_page(value)
        [value.to_i, 1].max
      end

      def filter_payload(period:, event_filter:)
        start_at = period_start(period)

        {
          period: period,
          event_filter: event_filter,
          starts_at: start_at&.iso8601(6),
          ends_at: Time.zone.now.iso8601(6),
        }
      end

      def active_user_scope
        ::User.where(active: true, staged: false)
      end

      def preference_states(user_ids = nil)
        scope =
          ::UserCustomField.where(
            name: ::MessagingPreferences::FIELD_NAMES,
            user_id: active_user_scope.select(:id),
          )
        scope = scope.where(user_id: user_ids) if user_ids.present?

        states = Hash.new do |hash, user_id|
          hash[user_id] = {
            works_well: "",
            please_avoid: "",
            updated_at: nil,
          }
        end

        scope
          .order(:id)
          .pluck(:user_id, :name, :value, :updated_at)
          .each do |user_id, name, value, updated_at|
            state = states[user_id]
            normalized = ::MessagingPreferences.normalize_text(value)

            if name == ::MessagingPreferences::WORKS_WELL_FIELD
              state[:works_well] = normalized
            elsif name == ::MessagingPreferences::PLEASE_AVOID_FIELD
              state[:please_avoid] = normalized
            end

            state[:updated_at] = [state[:updated_at], updated_at].compact.max
          end

        states.each_value do |state|
          state[:digest] =
            ::MessagingPreferences::PreferenceSnapshot.digest_for(
              works_well: state[:works_well],
              please_avoid: state[:please_avoid],
            )
          state[:has_preferences] = state[:digest].present?
          state[:works_well_set] = state[:works_well].present?
          state[:please_avoid_set] = state[:please_avoid].present?
        end

        states.select { |_user_id, state| state[:has_preferences] }
      end

      def acknowledgement_rows
        return [] if !::MessagingPreferences::Acknowledgement.table_ready?

        ::MessagingPreferences::Acknowledgement.pluck(
          :viewer_user_id,
          :target_user_id,
          :preferences_digest,
          :acknowledged_at,
        )
      end

      def summary(states, acknowledgements)
        current_acknowledgements =
          acknowledgements.count do |_viewer_id, target_id, digest, _acknowledged_at|
            states.dig(target_id, :digest) == digest
          end

        event_counts = event_counts_by_type
        recent_cutoff = 30.days.ago

        {
          members_with_preferences: states.length,
          members_with_both_fields:
            states.count do |_id, state|
              state[:works_well_set] && state[:please_avoid_set]
            end,
          members_with_works_well_only:
            states.count { |_id, state| state[:works_well_set] && !state[:please_avoid_set] },
          members_with_please_avoid_only:
            states.count { |_id, state| !state[:works_well_set] && state[:please_avoid_set] },
          members_updated_last_30_days:
            states.count do |_id, state|
              state[:updated_at].present? && state[:updated_at] >= recent_cutoff
            end,
          acknowledgement_records: acknowledgements.length,
          current_acknowledgements: current_acknowledgements,
          outdated_acknowledgements: acknowledgements.length - current_acknowledgements,
          distinct_acknowledging_members: acknowledgements.map(&:first).uniq.length,
          distinct_preference_owners_acknowledged:
            acknowledgements.map { |row| row[1] }.uniq.length,
          tracked_preference_changes:
            ::MessagingPreferences::Event::PREFERENCE_EVENT_TYPES.sum do |type|
              event_counts[type].to_i
            end,
          tracked_acknowledgements:
            event_counts[::MessagingPreferences::Event::ACKNOWLEDGEMENT_EVENT_TYPE].to_i,
        }
      end

      def event_counts_by_type
        return {} if !::MessagingPreferences::Event.table_ready?

        ::MessagingPreferences::Event.group(:event_type).count
      end

      def base_event_scope
        return ::MessagingPreferences::Event.none if !::MessagingPreferences::Event.table_ready?

        ::MessagingPreferences::Event.all
      end

      def period_start(period)
        days = PERIODS.fetch(period)
        days.present? ? days.days.ago : nil
      end

      def filtered_event_scope(period:, event_filter:)
        scope = base_event_scope.where(event_type: EVENT_FILTERS.fetch(event_filter))
        start_at = period_start(period)
        start_at.present? ? scope.where("occurred_at >= ?", start_at) : scope
      end

      def trend_payload(period)
        current_scope = base_event_scope
        days = PERIODS.fetch(period)
        start_at = period_start(period)
        previous = nil
        previous_start = nil
        previous_end = nil
        current_scope = current_scope.where("occurred_at >= ?", start_at) if start_at.present?
        current = trend_counts(current_scope)

        if days.present?
          previous_end = start_at
          previous_start = previous_end - days.days
          previous_scope =
            base_event_scope.where(
              "occurred_at >= ? AND occurred_at < ?",
              previous_start,
              previous_end,
            )
          previous = trend_counts(previous_scope)
        end

        {
          period: period,
          comparison_available: previous.present?,
          starts_at: start_at&.iso8601(6),
          ends_at: Time.zone.now.iso8601(6),
          previous_starts_at: previous_start&.iso8601(6),
          previous_ends_at: previous_end&.iso8601(6),
          metrics: {
            preference_changes:
              trend_metric(current[:preference_changes], previous&.dig(:preference_changes)),
            acknowledgements:
              trend_metric(current[:acknowledgements], previous&.dig(:acknowledgements)),
            active_members:
              trend_metric(current[:active_members], previous&.dig(:active_members)),
            total_events: trend_metric(current[:total_events], previous&.dig(:total_events)),
          },
        }
      end

      def trend_counts(scope)
        event_counts = scope.group(:event_type).count

        {
          preference_changes:
            ::MessagingPreferences::Event::PREFERENCE_EVENT_TYPES.sum do |type|
              event_counts[type].to_i
            end,
          acknowledgements:
            event_counts[::MessagingPreferences::Event::ACKNOWLEDGEMENT_EVENT_TYPE].to_i,
          active_members: scope.distinct.count(:actor_user_id),
          total_events: event_counts.values.sum,
        }
      end

      def trend_metric(current, previous)
        current = current.to_i
        return { current: current, previous: nil, change_percent: nil, direction: "none" } if previous.nil?

        previous = previous.to_i
        direction =
          if current > previous
            "up"
          elsif current < previous
            "down"
          else
            "flat"
          end

        change_percent =
          if previous.zero?
            current.zero? ? 0 : nil
          else
            (((current - previous).to_f / previous) * 100).round
          end

        {
          current: current,
          previous: previous,
          change_percent: change_percent,
          direction: direction,
        }
      end

      def paginated_events(scope, requested_page)
        total = scope.count
        total_pages = [(total.to_f / EVENTS_PER_PAGE).ceil, 1].max
        page = [[requested_page, 1].max, total_pages].min
        records =
          scope
            .order(occurred_at: :desc, id: :desc)
            .offset((page - 1) * EVENTS_PER_PAGE)
            .limit(EVENTS_PER_PAGE)

        {
          items: serialize_events(records),
          pagination: {
            page: page,
            per_page: EVENTS_PER_PAGE,
            total: total,
            total_pages: total_pages,
            has_previous: page > 1,
            has_next: page < total_pages,
          },
        }
      end

      def user_payload(user_id, states, filtered_scope:, page:)
        user = active_user_scope.find_by(id: user_id.to_i)
        return if user.blank?

        state = states[user.id] || empty_state
        received = received_acknowledgements(user, states)
        made = made_acknowledgements(user, states)
        events =
          paginated_events(
            filtered_scope.where(
              "actor_user_id = :id OR target_user_id = :id",
              id: user.id,
            ),
            page,
          )

        event_counts = user_event_counts(user)
        relationship_counts = current_relationship_counts(user, states)

        {
          user: serialize_user(user),
          current_preferences: {
            has_preferences: state[:has_preferences] == true,
            works_well_set: state[:works_well_set] == true,
            please_avoid_set: state[:please_avoid_set] == true,
            updated_at: state[:updated_at]&.iso8601(6),
          },
          counts: event_counts.merge(relationship_counts),
          acknowledgements_received: received,
          acknowledgements_made: made,
          events: events,
        }
      end

      def empty_state
        {
          has_preferences: false,
          works_well_set: false,
          please_avoid_set: false,
          updated_at: nil,
          digest: nil,
        }
      end

      def received_acknowledgements(user, states)
        return [] if !::MessagingPreferences::Acknowledgement.table_ready?

        rows =
          ::MessagingPreferences::Acknowledgement
            .where(target_user_id: user.id)
            .order(acknowledged_at: :desc)
            .limit(RELATIONSHIP_LIMIT)
            .pluck(:viewer_user_id, :preferences_digest, :acknowledged_at)

        users = users_by_id(rows.map(&:first))
        current_digest = states.dig(user.id, :digest)

        rows.filter_map do |viewer_id, digest, acknowledged_at|
          viewer = users[viewer_id]
          next if viewer.blank?

          {
            user: serialize_user(viewer),
            acknowledged_at: acknowledged_at&.iso8601(6),
            current: current_digest.present? && current_digest == digest,
          }
        end
      end

      def made_acknowledgements(user, states)
        return [] if !::MessagingPreferences::Acknowledgement.table_ready?

        rows =
          ::MessagingPreferences::Acknowledgement
            .where(viewer_user_id: user.id)
            .order(acknowledged_at: :desc)
            .limit(RELATIONSHIP_LIMIT)
            .pluck(:target_user_id, :preferences_digest, :acknowledged_at)

        users = users_by_id(rows.map(&:first))

        rows.filter_map do |target_id, digest, acknowledged_at|
          target = users[target_id]
          next if target.blank?

          {
            user: serialize_user(target),
            acknowledged_at: acknowledged_at&.iso8601(6),
            current:
              states.dig(target_id, :digest).present? &&
                states.dig(target_id, :digest) == digest,
          }
        end
      end

      def current_relationship_counts(user, states)
        return {
          current_acknowledgements_received: 0,
          current_acknowledgements_made: 0,
        } if !::MessagingPreferences::Acknowledgement.table_ready?

        current_digest = states.dig(user.id, :digest)
        received =
          if current_digest.present?
            ::MessagingPreferences::Acknowledgement.where(
              target_user_id: user.id,
              preferences_digest: current_digest,
            ).count
          else
            0
          end

        made =
          ::MessagingPreferences::Acknowledgement
            .where(viewer_user_id: user.id)
            .pluck(:target_user_id, :preferences_digest)
            .count do |target_id, digest|
              states.dig(target_id, :digest).present? &&
                states.dig(target_id, :digest) == digest
            end

        {
          current_acknowledgements_received: received,
          current_acknowledgements_made: made,
        }
      end

      def user_event_counts(user)
        return {
          tracked_preference_changes: 0,
          tracked_acknowledgements_received: 0,
          tracked_acknowledgements_made: 0,
        } if !::MessagingPreferences::Event.table_ready?

        {
          tracked_preference_changes:
            ::MessagingPreferences::Event.where(
              target_user_id: user.id,
              event_type: ::MessagingPreferences::Event::PREFERENCE_EVENT_TYPES,
            ).count,
          tracked_acknowledgements_received:
            ::MessagingPreferences::Event.where(
              target_user_id: user.id,
              event_type: ::MessagingPreferences::Event::ACKNOWLEDGEMENT_EVENT_TYPE,
            ).count,
          tracked_acknowledgements_made:
            ::MessagingPreferences::Event.where(
              actor_user_id: user.id,
              event_type: ::MessagingPreferences::Event::ACKNOWLEDGEMENT_EVENT_TYPE,
            ).count,
        }
      end

      def serialize_events(scope)
        records = scope.to_a
        users =
          users_by_id(
            records.flat_map { |event| [event.actor_user_id, event.target_user_id] },
          )

        records.map do |event|
          {
            id: event.id,
            event_type: event.event_type,
            actor_user_id: event.actor_user_id,
            target_user_id: event.target_user_id,
            actor: serialize_user(users[event.actor_user_id]),
            target: serialize_user(users[event.target_user_id]),
            occurred_at: event.occurred_at&.iso8601(6),
          }
        end
      end

      def users_by_id(ids)
        ids = ids.compact.uniq
        return {} if ids.empty?

        ::User.where(id: ids).index_by(&:id)
      end

      def serialize_user(user)
        return if user.blank?

        {
          id: user.id,
          username: user.username,
          name: user.name,
          avatar_template: user.avatar_template,
        }
      end
    end
  end
end
