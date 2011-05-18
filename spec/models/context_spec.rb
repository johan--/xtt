require File.dirname(__FILE__) + '/../spec_helper'

describe User, "sorting membership contexts" do
  define_models :contexts

  before do
    @user     = users(:default)
    @context  = user_contexts(:default)
    @contexts = @user.memberships.contexts
  end

  it "has key for contexts" do
    @contexts[@context].should == [memberships(:another), memberships(:context)]
  end

  it "has key for project without context" do
    @contexts[nil].should == [memberships(:default)]
  end

  it "leaves nil context for last" do
    @contexts.to_a.last.should == [nil, [memberships(:default)]]
  end
end
