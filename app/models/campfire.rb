class Campfire < ActiveRecord::Base
  has_many :tendrils, :as => :notifies
  has_many :projects, :through => :tendrils
  belongs_to :user # creator

  def send_message(message)
    Job::NotifyCampfire.create self, message
  end
  
  def tinder_room
    @tinder_room ||= self.room ? tinder.find_room_by_name(room) : tinder.rooms[0]
  end

private

  def tinder
    return @tinder if @tinder
    @tinder = Tinder::Campfire.new domain, :token => key, :ssl => true
    @tinder
  end

end
