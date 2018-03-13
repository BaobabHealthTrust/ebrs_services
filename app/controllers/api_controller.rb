class ApiController < ActionController::Base

  def home
    @current_count = PersonBirthDetail.select(" COUNT(national_serial_number) AS c ").where(" national_serial_number IS NOT NULL")[0]['c'].to_i rescue 0
  end

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
