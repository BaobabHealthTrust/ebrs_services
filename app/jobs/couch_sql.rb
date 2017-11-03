class CouchSQL
  include SuckerPunch::Job
  workers 1

  def perform()
    begin
      load "#{Rails.root}/bin/couch-mysql.rb"
			CouchSQL.perform_in(3)
    rescue => e
      SuckerPunch.logger.info "Error: #{e.to_s}"
      CouchSQL.perform_in(3)
    end
  end
end

