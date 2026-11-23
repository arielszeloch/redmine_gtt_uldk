# frozen_string_literal: true

module RedmineGttUldk
  # Background geocoding, so saving an issue never waits for ULDK.
  class GeocodeJob < ActiveJob::Base
    queue_as :default

    def perform(issue_id)
      issue = Issue.find_by(id: issue_id)
      return unless issue

      result = Geocoder.call(issue)
      Rails.logger.info("[ULDK] issue ##{issue_id}: #{result.status} #{result.message}")
    rescue StandardError => e
      Rails.logger.warn("[ULDK] issue ##{issue_id}: error #{e.class}: #{e.message}")
    end
  end
end
