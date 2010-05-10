require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "RackRescue" do
  class RRUnknownException < RuntimeError; end

  def safe_endpoint(msg = "OK")
    lambda{|e| Rack::Response.new(msg)}
  end

  def raise_endpoint(exception, msg)
    lambda{|e| raise exception, msg }
  end

  def build_stack(endpoint = safe_endpoint)
    Rack::Builder.new do
      use Rack::Rescue
      run endpoint
    end
  end

  before do
    @env = Rack::MockRequest.env_for("/")
  end

  it "should do nothing if there is no downstream exception" do
    result = build_stack.call(@env)
    result.body.map.join.should == "OK"
  end

  it "should render the error with the defautl text error handler if it's an unkonwn exception" do
    @env['HTTP_ACCEPT'] =  "text/plain"
    bad_app = raise_endpoint(RRUnknownException, "Unknown Brew")
    stack = build_stack(bad_app)
    r = stack.call(@env)
    r[0].should == 500
    body = r[2].body.map.join
    body.should include("Error")
    body.should include("Unknown Brew")
  end

  describe "A known exception" do
    it "should render the template for the error" do
      bad_app = raise_endpoint(Pancake::Errors::NotFound, "Action Not Found")
      stack = build_stack(bad_app)
      @env['HTTP_ACCEPT'] = 'text/plain'
      r = stack.call(@env)

      body = r[2].body.map.join
      body.should include("Pancake::Errors::NotFound")
    end

    it "should set the correct status code" do
      bad_app = raise_endpoint(Pancake::Errors::NotFound, "Action Not Found")
      stack = build_stack(bad_app)
      @env['HTTP_ACCEPT'] = "text/plain"
      r = stack.call(@env)

      status = r[0]
      status.should == 404
      body = r[2].body.map.join
      body.should include("Action Not Found")
    end
  end

  it "should provide a list of default formats" do
    Rack::Rescue.default_formats.should == Pancake::MimeTypes.groups.keys.map(&:to_sym)
    rr = Rack::Rescue.new SUCCESS_APP
    rr.formats.should == Pancake::MimeTypes.groups.keys.map(&:to_sym)
  end

  it "should let me overwrite the formats avaiable" do
    rr = Rack::Rescue.new(SUCCESS_APP, :formats => [:text, :html])
    rr.formats.should == [:text, :html]
  end

  it "should inspect the rack env and negotiate the content" do
    env = Rack::MockRequest.env_for("/")
    env['HTTP_ACCEPT'] = "text/xml"

    rr = Rack::Rescue.new(raise_endpoint(RuntimeError, "Boo"))
    result = rr.call(env)
    result[0].should == 500
    result[2].body.to_s.should include("XML Error Template")
  end


  it "should inspect the extension of the " do
    env = Rack::MockRequest.env_for("/")
    env['HTTP_ACCEPT'] = "text/xml"

    rr = Rack::Rescue.new(raise_endpoint(RuntimeError, "Boo"))
    result = rr.call(env)
    result[0].should == 500
    result[2].body.to_s.should include("XML Error Template")
  end

end
