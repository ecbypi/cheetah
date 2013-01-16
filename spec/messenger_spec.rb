require 'spec_helper'

describe Cheetah::Messenger do
  def generate_messenger(options = {})
    options = {
      :host             => "foo.com",
      :username         => "foo_user",
      :password         => "foo",
      :aid              => "123"
    }.merge(options)

    Cheetah::Messenger.new(options)
  end

  context 'logging in' do
    it 'sets the session cookie' do
      messenger = generate_messenger

      stub_login
      stub_request(:post, 'https://foo.com/').to_return(status: 200, body: 'OK\r\n')

      messenger.send_message('/', {})

      messenger.cookie.should_not be_nil
    end

    it 'raises error in the event of an authentication failure' do
      messenger = generate_messenger

      stub_request(:post, 'https://foo.com/api/login1').with(body: { name: 'foo_user', cleartext: 'foo' }).to_return(body: "err:authentication error\r\n", status: 200)

      lambda { messenger.send_message('/', {}) }.should raise_error(CheetahPermanentException)
    end
  end

  it 'sends cookie on subsequent requests and merges in default params (aid)' do
    messenger = generate_messenger

    stub_login
    messenger.send(:login)

    # Webmock will raise an error if we attempt to make a request that isn't
    # stubbed. The test will only pass if we stub the request that will be
    # made.
    stub_request(:post, 'https://foo.com/').with(body: 'aid=123', headers: { 'Cookie' => 'token' })

    messenger.send_message('/', {})
  end

  describe "#send_message" do
    before do
      stub_login
    end

    it "should raise CheetahPermanentException when there's a permanent error on Cheetah's end" do
      stub_request(:post, 'https://foo.com/').to_return(status: 400)

      lambda { generate_messenger.send_message('/', {}) }.should raise_error(CheetahPermanentException)
    end

    it "should raise CheetahTemporaryException when there's a temporary (server) error on Cheetah's end" do
      stub_request(:post, 'https://foo.com/').to_return(status: 500)

      lambda { generate_messenger.send_message('/', {}) }.should raise_error(CheetahTemporaryException)
    end

    it "should raise CheetahTemporaryException when there's a temporary error on Cheetah's end" do
      stub_request(:post, 'https://foo.com/').to_return(status: 200, body: 'err:internal error')

      lambda { generate_messenger.send_message('/', {}) }.should raise_error(CheetahTemporaryException)
    end
  end

  context 'with :disable_tracking set to true' do
    it 'sets "test" param' do
      messenger = generate_messenger(disable_tracking: true)

      stub_login
      stub_request(:post, 'https://foo.com/').with(body: 'aid=123&test=1').to_return(status: 200, body: "OK\r\n")

      messenger.send_message('/', {})
    end
  end
end
