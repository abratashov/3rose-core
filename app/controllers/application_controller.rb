class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :authority

  private

  def authority
    unless params[:auth_token] == APP_CORE_TOKEN
      render :status => 400, :success => false, :msg => 'Authorization error' and return
    end
  end
end
