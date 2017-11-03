class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  #protect_from_forgery with: :exception
  protect_from_forgery	#with: :null_session

  before_filter :check_if_logged_in, :except => ['login']

  def start_sync
    SyncCheck.perform_in(1)
    render :text => 'ok'
  end

  def start_data_loading
    CouchSQL.perform_in(1)
    render :text => 'ok'
  end

  def start_ping
    Ping.perform_in(1)
    render :text => 'ok'
  end
end
