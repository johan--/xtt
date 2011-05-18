require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StatusTest < ActiveSupport::TestCase
  user_time = Time.now.utc # Time.utc 2007, 1, 1
  fixtures do
    cleanup User, Project, Status
    @user = User.make
    @project = Project.make :user => @user, :code => "abc", :name => "default"
    @another = Project.make :user => @user, :code => "def", :name => "another"
    @in_project = Status.make :user => @user, :message => "@abc in-project", :created_at => user_time - 47.hours, :project => @project
    @status     = Status.make :user => @user, :message => '@abc pending',    :created_at => user_time - 15.hours, :project => @project, :aasm_state => 'pending', :hours => 0
  end
  
  describe "Status, being created" do
    before do
      @new = @status.user.statuses.build(:message => 'howdy')
      @creating_status = lambda { @new.save! }
    end
    
    it "starts in :pending state" do
      @new.save!
      @new.pending?.should == true
    end

    it "increments user statuses count" do
      assert_difference "@status.user.reload.statuses.size", 1 do
        @new.save!
      end
    end
  
    it "is related properly to the previous status" do
      @new.save!
      @new.previous.should    == @status
      @status.followup.should == @new
    end
  
    it "processes previous status when creating" do
      assert @status.pending?
      assert @status.valid?
      @new.save!
      @status.user.should == @new.user
      assert_nil @status.finished_at
      assert @status.reload.processed?
      assert_equal 15.0, @status.hours.to_f, "Sometimes this fails to 15.25 if it takes too long to process (#{@status.finished_at - @status.created_at})"
    end
  
    it "caches User#last_status_id" do
      @new.save!
      @status.user.reload.last_status.should == @new
    end
  
    it "caches User#last_status_message" do
      @new.save!
      @status.user.reload.last_status_message.should == @new.message
    end
  
    it "caches User#last_status_project_id" do
      @new.project = @project
      @new.save!
      @status.user.reload.last_status_project.should == @new.project
    end
  
    it "caches User#last_status_at" do
      @new.save!
      (@new.created_at - @status.user.reload.last_status_at).should be_close(0, 1)
    end
  
    it "sets the time in the past" do
      @new.message = "Howdy [-30]"
      @new.save!
      (@new.created_at - Time.now.utc).should be_close(-30.minutes, 1)
      @new.message.should == "Howdy"
    end
  
    it "sets the time in the past as hours" do
      @new.message = "Wassup? [-2h]"
      @new.save!
      (@new.created_at - Time.now.utc).should be_close(-2.hours, 1)
      @new.message.should == "Wassup?"
    end
  
    it "sets the time in the past as decimal hours" do
      @new.message = "Hmmm. [-2.5h]"
      @new.save!
      (@new.created_at - Time.now).should be_close(-2.5.hours, 1)
    end
  
    it "sets the time in the past as hh:mm" do
      @new.message = "FFfffuuuu [-2:30h]"
      @new.save!
      (@new.created_at - Time.now).should be_close(-2.5.hours, 1)
      @new.message.should == "FFfffuuuu"
    end
  
    it "sets the start time manually" do
      @new.message = "Howdy [2:30pm]"
      @new.save!
      (@new.created_at - Time.parse("14:30")).should be_close(0, 1)
      @new.message.should == "Howdy"
    end    
  end

  describe "Status" do
    it "#user retrieves associated User" do
      @status.user.should == @user
    end

    it "#next retrieves followup status" do
      @in_project.followup.should == @status
    end

    it "does not allow time travel backwards" do
      pending "PDI"
      @in_project.previous.should == @status
      lambda {
        @in_project.set_created_at = @status.created_at.utc - 10.minutes
        assert_nil @in_project.errors.on(:created_at)
      }.should_not change { @in_project.created_at }

      #}.should change { @in_project.valid? }.to(false)
      #@in_project.should_not be_valid
    end

    it "#next retrieves previous status" do
      @status.previous.should == @in_project
    end

    describe "#extract_code_and_message" do
      #before do
      #  @status = Status.new
      #end

      ['', ' '].each do |code|
        it "extracts nil code from #{code.inspect}" do
          @status.send(:extract_code_and_message, code + 'foo').should == [nil, "foo"]
        end
      end

      it "extracts nil code from '@'" do
        @status.send(:extract_code_and_message, ' @ foo').should == ['', "foo"]
      end

      it "strips whitespace from message" do
        @status.send(:extract_code_and_message, " foo ").should == [nil, "foo"]
      end

      ["@foo ", " @foo "].each do |code|
        it "extracts 'foo' code from #{code.inspect}" do
          @status.send(:extract_code_and_message, code + " bar ").should == %w(foo bar)
        end
      end
    end
  end
  
  describe "Status, being updated" do
    it "allows changed project" do
      assert @status.update_attributes!(:code_and_message => "@def booya")
      @status.message.should == 'booya'
      @status.project.code.should == 'def'
    end

    it "allows changing to OUT" do
      assert ! @status.out?
      assert @status.update_attributes(:code_and_message => "booya")
      @status.message.should == 'booya'
      assert @status.project.nil?
      assert @status.out?
    end

    it "allows changed message" do
      assert @status.update_attributes(:code_and_message => "@abc booya")
      @status.message.should == 'booya'
      @status.user.memberships.for(@status.project).code.should == 'abc'
    end

    it "requires valid code, yet still updates message" do
      @status.update_attributes(:code_and_message => '@booya peeps').should == false
      @status.message.should == 'peeps'
    end
  end
  
  describe "Status, in pending state with followup in other project" do
    user_time = Time.now.utc # Time.utc 2007, 1, 1
    fixtures do
      cleanup Status
      @new     = Status.make :user => @user, :message => '@def new_in_other_project', :created_at => (user_time - 2.hours), :project => @another
    end
   
    before do
      @nstatus = Status.new  :user => @user, :message => '@abc pending',              :created_at => user_time - 5.hours,   :project => @project, :aasm_state => 'pending', :hours => 0
      @new.code_and_message = @new.message
    end

    it "assigns to project" do
      @new.project.should == @another
    end

    it "#next retrieves next status" do
      @nstatus.followup.should == @new
    end
    
    it "sets up this fucking test properly" do
      @nstatus.hours.to_f.should == 0
    end

    #it "skips processing if no followup is found" do
    #  @status.followup = :false
    #  @status.hours.should == 0 # be_close(0,1)
    #  @status.should be_pending
    #  @status.process!
    #  @status.should be_pending
    #end

    {0 => 0.0, 10 => 0.25, 15 => 0.25, 25 => 0.5, 30 => 0.5, 45 => 0.75}.each do |min, result|
      it "processes @status hours in quarters at #{min} minutes past the hour" do
        @new.created_at = (user_time - 2.hours) + min.minutes
        @new.save!

        assert_equal 0, @nstatus.hours
        assert @nstatus.pending?
        @nstatus.process!
        assert @nstatus.processed?
        v = (@new.created_at - @nstatus.created_at)
        assert_equal (3.to_f + result).to_s, @nstatus.hours.to_s, "Exact time was #{v} (#{v/60.0/60.0}) for #{min} minutes at #{result}. #{@new.created_at} / #{user_time} / #{user_time - 2.hours}"
        # @nstatus.destroy
      end
    end
    
  end
end