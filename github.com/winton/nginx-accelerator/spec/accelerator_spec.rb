require 'spec_helper'

describe Accelerator do

  before(:all) do
    @accelerator = Accelerator.new
    @accelerator.delete("/test") rescue nil
  end

  it "should create cache on first request" do
    time = Time.new.to_i
    request.should == time
    body, options = @accelerator.get("/test")
    response_tests(time)
  end

  it "should return same cache on next request" do
    $expires_at = Time.now.to_f.ceil
    request.should == $last_time
    body, options = @accelerator.get("/test")
    response_tests($last_time)
  end

  it "should not expire naturally before 1 second" do
    if Time.now.to_f < $expires_at
      expires_in = $expires_at - Time.now.to_f
      request(0.5 * expires_in).should == $last_time
    end
  end

  it "should expire naturally after 1 second" do
    if Time.now.to_f < $expires_at
      expires_in = $expires_at - Time.now.to_f
      request(expires_in).should == $last_time
    end
    response_tests(Time.new.to_i)
  end

  it "should set cache body from the client" do
    @accelerator.set("/test", "123")
    $expires_at = Time.now.to_f.ceil
    request.should == 123
  end

  it "should not expire naturally before 1 second" do
    if Time.now.to_f < $expires_at
      expires_in = $expires_at - Time.now.to_f
      request(0.5 * expires_in).should == 123
    end
  end

  it "should expire naturally after 1 second" do
    if Time.now.to_f < $expires_at
      expires_in = $expires_at - Time.now.to_f
      request(expires_in).should == 123
    end
    response_tests(Time.new.to_i)
  end

  it "should obey client expiration" do
    @accelerator.set("/test", "123")
    @accelerator.expire("/test")
    request.should == 123
    response_tests(Time.new.to_i)
  end
end