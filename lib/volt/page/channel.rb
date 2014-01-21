# The channel is the connection between the front end and the backend.

require 'volt/reactive/events'
require 'json'

class Channel
  include ReactiveTags
  
  attr_reader :state, :error, :reconnect_interval
  
  def initialize
    @socket = nil
    @state = :opening
    @error = nil
    @queue = []
    
    connect!
  end
  
  def connect!
    %x{
      this.socket = new SockJS('http://localhost:3000/channel');

      this.socket.onopen = function() {
        self.$opened();
      };

      this.socket.onmessage = function(message) {
        self['$message_received'](message.data);
      };
      
      this.socket.onclose = function(error) {
        self.$closed(error);
      };
    }
  end
  
  def opened
    puts "OPEN"
    @state = :open
    @reconnect_interval = nil
    @queue.each do |message|
      send(message)
    end
    
    trigger!('open')
    trigger!('changed')
  end

  def closed(error)
    puts "CLOSED"
    @state = :closed
    @error = `error.reason`
    
    trigger!('closed')
    trigger!('changed')
    
    reconnect!
  end
  
  def reconnect!
    @reconnect_interval ||= 0
    @reconnect_interval += (2000 + rand(5000))
    
    # Trigger changed for reconnect interval
    trigger!('changed')
    
    interval = @reconnect_interval
    
    %x{
      setTimeout(function() {
        self['$connect!']();
      }, interval);
    }
  end
  
  def message_received(message)
    message = JSON.parse(message)
    # puts "GOT: #{message.inspect}"
    trigger!('message', nil, *message)
  end
  
  def send(message)
    if @state != :open
      @queue << message
    else
      # TODO: Temp: wrap message in an array, so we're sure its valid JSON
      message = JSON.dump([message])
      %x{
        this.socket.send(message);
      }
    end
  end
  
  def close
    @state = :closed
    %x{
      this.socket.close();
    }
  end
end