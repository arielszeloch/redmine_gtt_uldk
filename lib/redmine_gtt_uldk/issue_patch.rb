# frozen_string_literal: true

module RedmineGttUldk
  # Queues geocoding after an issue is committed when its parcel fields
  # changed (or it has no geometry yet) and the user did not draw a geometry
  # in the same edit. Never raises into the issue save.
  module IssuePatch
    def self.apply
      return if Issue < InstanceMethods

      Issue.include InstanceMethods
      Issue.class_eval do
        before_save :gtt_uldk_remember_need
        after_commit :gtt_uldk_enqueue, on: %i[create update]
      end
    end

    module InstanceMethods
      private

      def gtt_uldk_remember_need
        @gtt_uldk_needed =
          if !respond_to?(:geom) || !Settings.auto_geocode?
            false
          elsif geom_changed? && geom.present?
            false # the user drew/changed the geometry explicitly
          else
            gtt_uldk_fields_changed? || geom.blank?
          end
        true
      rescue StandardError => e
        Rails.logger.warn("[ULDK] issue ##{id}: #{e.class}: #{e.message}")
        @gtt_uldk_needed = false
        true
      end

      def gtt_uldk_fields_changed?
        ids = Settings.field_ids
        return false if ids.empty?

        custom_field_values.any? do |v|
          ids.include?(v.custom_field.id) && v.value_was.to_s != v.value.to_s
        end
      end

      def gtt_uldk_enqueue
        return unless @gtt_uldk_needed

        @gtt_uldk_needed = false
        return unless project&.module_enabled?(:gtt)
        return unless Settings.field(:parcel) && custom_field_value(Settings.field(:parcel)).present?

        GeocodeJob.perform_later(id)
      rescue StandardError => e
        Rails.logger.warn("[ULDK] issue ##{id}: enqueue failed #{e.class}: #{e.message}")
      end
    end
  end
end
