class Status
  can_search do
    scoped_by :user
    scoped_by :project
    scoped_by :created, :scope => :date_range
  end

  class << self
    attr_accessor :filter_types
  end
  
  self.filter_types = Set.new CanSearch::DateRangeScope.periods.keys
  
  # user_id can be an integer or nil
  def self.filter(user_id, filter, options = {})
    scope_by_context(options.delete(:context), user_id || options[:current_user]) do
      range   = filter ? date_range_for(filter, options[:date]) : nil
      records = search :created => range, :user =>  user_id, 
        :order => 'statuses.created_at desc', :page => options[:page], :per_page => options[:per_page]
      [records, range]
    end
  end

  # user_id can be an integer or nil
  def self.filter_all_users(user_id, f, options = {})
    filter(user_id, f, options)
  end
  
  def self.hours(user_id, filter, options = {})
    scope_by_context(options.delete(:context), user_id || options[:current_user]) do
      search_for(:user => user_id, :created => {:period => filter, :start => options[:date]}).sum :hours, :conditions => 'statuses.project_id is not null'
    end
  end
  
  def self.filtered_hours(user_id, filter, options = {})
    scope_by_context(options.delete(:context), user_id || options[:current_user]) do
      hours = search_for(:user => user_id, :created => {:period => filter, :start => options[:date]}).sum(:hours,
        :group => "CONCAT(statuses.user_id, '::', DATE(CONVERT_TZ(statuses.created_at, '+00:00', '#{Time.zone.utc_offset_string}')))", 
        :conditions => 'statuses.project_id is not null').to_a
      hours.extend(FilteredHourMethods)
    end
  end

protected
  def self.scope_by_context(value, user_id=nil)
    if value
      if value.class.name =~ /GlobalContext/
        with_scope :find => {:conditions => {'memberships.user_id' => user_id}, :select => "DISTINCT statuses.*",
            :joins => "INNER JOIN memberships on statuses.project_id = memberships.project_id"} do
          yield
        end
      else
        value = value.id if value.is_a?(UserContext)
        with_scope :find => {:conditions => {'memberships.user_context_id' => value}, :select => "DISTINCT statuses.*",
            :joins => "INNER JOIN memberships on statuses.project_id = memberships.project_id"} do
          yield
        end
      end
    else
      yield
    end
  end
end