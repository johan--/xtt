class UserContext < ActiveRecord::Base
  set_table_name "contexts"
  has_many :memberships
  has_many :projects, :through => :memberships
  belongs_to :user

  has_permalink :name

  validates_uniqueness_of :name, :scope => :user_id

  attr_accessible :name, :permalink

  def users
    @users ||= User.for_projects(projects.map(&:id))
  end

  def to_param
    permalink
  end
  
  def hours(filter, date)
    hours = 0
    projects.each_with_index do |project, index|
      hours += project.statuses.filtered_hours(nil, filter, :context => self, :date => date).total
    end
    hours
  end

end