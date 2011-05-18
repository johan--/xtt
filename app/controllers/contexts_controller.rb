class ContextsController < ApplicationController
  before_filter :login_required, :except => :index
  before_filter :find_context,   :except => :index

  def index
    redirect_to root_path
  end

  def show
    params[:per] = 9999 if request.format == 'csv'
    # We pass in "current_user" so that for the "all" context, the project list is scoped.
    @statuses, @date_range = Status.filter(user_status_for(params[:user_id]), params[:filter] ||= :weekly, :context => @context, :date => params[:date], :page => params[:page], :per_page => params[:per]||20, :current_user => current_user.id)
    @daily_hours = Status.filtered_hours(user_status_for(params[:user_id]), :daily, :context => @context, :date => params[:date], :current_user => current_user.id)
    @hours       = Status.filtered_hours(user_status_for(params[:user_id]), params[:filter], :context => @context, :date => params[:date], :current_user => current_user.id)

    all_statuses = Status.filter_all_users(user_status_for(params[:user_id]), params[:filter] ||= :weekly, :context => @context, :date => params[:date])
    # hmm, the [0] is necessary b/c this is actually a WillPaginateCollection
    user_ids = all_statuses[0].map {|s| s.user.permalink }.uniq
    @user_hours = []
    user_ids.each do |user|
      hours = Status.filtered_hours(user_status_for(user), params[:filter], :date => params[:date], :context => @context)
      @user_hours << hours unless hours.empty?
    end
    # reset @user var. hack. omg.
    user_status_for(params[:user_id])

    @context ||= UserContext.new :name => "etc"
    respond_to do |format|
      format.html # show.html.erb
      format.iphone
      format.xml  { render :xml  => @context }
      format.csv  # show.csv.erb
    end
  end

  def update
    @context.update_attributes params[:context]
    redirect_to context_path(@context)
  end


  class GlobalContext
    attr_accessor :name
    
    def projects=(val)
      @projects = val.map(&:id)
    end

    def projects
      @projects.map { |p| Project.find(p) }
    end
    
    def users
      @users ||= User.for_projects(projects)
    end
    
    def hours(filter, date)
      hours = 0
      projects.each_with_index do |project, index|
        hours += project.statuses.filtered_hours(nil, filter, :context => self, :date => date).total
      end
      hours
    end
  end

protected
  def find_context
    return if params[:id].blank?
    if params[:id] == "all"
      @context = GlobalContext.new
      @context.name = "all"
      @context.projects = current_user.projects
    else
      @context = current_user.contexts.find_by_permalink(params[:id])
    end
  end

  def user_status_for(status)
    @user = status == 'me' ? current_user : User.find_by_permalink(status)
    @user ? @user.id : nil
  end
end