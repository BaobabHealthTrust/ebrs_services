class SyncCheck
  include SuckerPunch::Job
  workers 1

  def perform()
    begin
      puts "Syncing ... "
      load "#{Rails.root}/bin/sync.rb"
      SyncCheck.perform_in(5*60)
    rescue
      SyncCheck.perform_in(5*60)
    end
  end
end

