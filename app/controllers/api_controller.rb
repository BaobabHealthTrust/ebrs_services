class ApiController < ActionController::Base
  
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
