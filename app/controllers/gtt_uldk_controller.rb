# frozen_string_literal: true

# Manual "fetch parcel geometry from ULDK" action on an issue.
class GttUldkController < ApplicationController
  before_action :find_issue, :authorize_edit

  def geocode
    report(RedmineGttUldk::Geocoder.call(@issue))
  rescue RedmineGttUldk::Client::Error => e
    flash[:error] = l(:error_gtt_uldk_service, message: e.message)
  ensure
    redirect_to issue_path(@issue) unless performed?
  end

  private

  def report(result)
    case result.status
    when :ok
      flash[:notice] = l(:notice_gtt_uldk_ok, parcels: result.parcels.map(&:id).join(', '))
    when :partial
      flash[:warning] = l(:notice_gtt_uldk_partial, parcels: result.parcels.map(&:id).join(', '),
                                                    missing: result.missing.join(', '))
    when :not_found
      flash[:error] = l(:error_gtt_uldk_not_found, missing: result.missing.join(', '))
    else
      flash[:error] = l(:error_gtt_uldk_missing_fields)
    end
  end

  def find_issue
    @issue = Issue.find(params[:id])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def authorize_edit
    deny_access unless @issue.visible? && @issue.editable? && @project.module_enabled?(:gtt)
  end
end
