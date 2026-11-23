# frozen_string_literal: true

module RedmineGttUldk
  # "Fetch parcel geometry from ULDK" link on the issue page.
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_issues_show_details_bottom, partial: 'redmine_gtt_uldk/issue_button'
  end
end
