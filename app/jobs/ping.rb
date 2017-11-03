class Ping
  include SuckerPunch::Job
  workers 1

  def perform()
    begin
      puts "Pinging Sites ... "
      load "#{Rails.root}/bin/jobs.rb"
      Ping.perform_in(60)
    rescue
      Ping.perform_in(60)
    end
  end
end

