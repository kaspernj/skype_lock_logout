require "dbus"

#A class that connects to the Gnome-Screensaver and listens for locks. When locking the app will log out of Skype. When unlocking the app will lock back into Skype.
class Skype_lock_logout
  #Spawns the object, starts to listen and blocks the thread.
  def self.start
    loop do
      begin
        Skype_lock_logout.new.listen
      rescue => e
        puts e.inspect
        puts e.backtrace
      end
      
      sleep 1
    end
  end
  
  def initialize
    #Spawn the session-DBus.
    @bus = DBus::SessionBus.instance
    
    #Spawn Skype-DBus objects.
    @skype_service = @bus.service("com.Skype.API")
    @skype_obj = @skype_service.object("/com/Skype")
    @skype_obj.introspect
    @skype_obj.default_iface = "com.Skype.API"
    
    #Register the application with Skype.
    res = @skype_obj.Invoke("NAME SkypeLockLogout").first
    raise "The application wasnt allowed use Skype: '#{res}'." if res != "OK"
    
    #Set the protocol to 8 - could only find documentation on this protocol.
    res = @skype_obj.Invoke("PROTOCOL 8").first
    raise "Couldnt set the protocol for Skype: '#{res}'." if res != "PROTOCOL 8"
    
    #Listen for lock-events on the screensaver.
    mr = DBus::MatchRule.new.from_s("interface='org.gnome.ScreenSaver',member='ActiveChanged'")
    @bus.add_match(mr, &self.method(:gnome_screensaver_status))
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