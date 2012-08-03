require "dbus"

#A class that connects to the Gnome-Screensaver and listens for locks. When locking the app will log out of Skype. When unlocking the app will lock back into Skype.
class Skype_lock_logout
  #Spawns the object, starts to listen and blocks the thread.
  def self.start
    loop do
      print "Starting Skype-lock-logout.\n"
      
      begin
        Skype_lock_logout.new.listen
      rescue => e
        if e.is_a?(DBus::Error) and e.message == "The name com.Skype.API was not provided by any .service files"
          puts "Skype isnt running - trying again in 10 secs."
        elsif e.is_a?(RuntimeError) and e.message == "Skype has stopped running."
          puts "Skype stopped running - trying to reconnect in 10 secs."
        else
          puts e.inspect
          puts e.backtrace
        end
      end
      
      sleep 10
    end
  end
  
  def initialize
    #Spawn the session-DBus.
    @bus = DBus::SessionBus.instance
    
    #Spawn Skype-DBus objects.
    skype_service = @bus.service("com.Skype.API")
    @skype_obj = skype_service.object("/com/Skype")
    @skype_obj.introspect
    @skype_obj.default_iface = "com.Skype.API"
    
    #Register the application with Skype.
    res = @skype_obj.Invoke("NAME SkypeLockLogout").first
    raise "The application wasnt allowed use Skype: '#{res}'." if res != "OK"
    
    #Set the protocol to 8 - could only find documentation on this protocol. Are there any better ones???
    res = @skype_obj.Invoke("PROTOCOL 8").first
    raise "Couldnt set the protocol for Skype: '#{res}'." if res != "PROTOCOL 8"
    
    #Listen for lock-events on the screensaver.
    mr = DBus::MatchRule.new.from_s("interface='org.gnome.ScreenSaver',member='ActiveChanged'")
    @bus.add_match(mr, &self.method(:gnome_screensaver_status))
    
    #Listen for when Skype stops running to quit listening.
    mr = DBus::MatchRule.new.from_s("path='/org/freedesktop/DBus',interface='org.freedesktop.DBus',member='NameOwnerChanged'")
    @bus.add_match(mr, &self.method(:name_owner_changed))
  end
  
  #This method is being called on 'NameOwnerChanged', which helps us stop the app when Skype stops (a reconnect is needed after Skype restarts).
  def name_owner_changed(msg)
    raise "Skype has stopped running." if msg.params.first == "com.Skype.API" and msg.params[1].to_s.match(/^:\d\.\d+$/)
  end
  
  #This method is called, when the Gnome-Screensaver locks or unlocks.
  def gnome_screensaver_status(msg)
    val = msg.params.first
    
    if val == true
      puts "Detected screenlock by Gnome Screensaver - logging out of Skype."
      self.skype_status_offline
    else
      puts "Detected screenlock unlock by Gnome Screensaver - going online on Skype."
      self.skype_status_online
    end
  end
  
  #This listens for the connected events and blocks the thread calling it.
  def listen
    main = DBus::Main.new
    main << @bus
    main.run
    
    nil
  end
  
  #Tells Skype to go offline.
  def skype_status_offline
    ret = @skype_obj.Invoke("SET USERSTATUS OFFLINE").first
    raise "Couldnt go offline: '#{ret}'." if ret != "USERSTATUS OFFLINE"
    nil
  end
  
  #Tells skype to go online.
  def skype_status_online
    ret = @skype_obj.Invoke("SET USERSTATUS ONLINE").first
    raise "Couldnt go online: '#{ret}'." if ret != "USERSTATUS ONLINE"
    nil
  end
end