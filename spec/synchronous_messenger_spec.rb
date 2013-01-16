require 'spec_helper'

# through this class I'm also testing the base messenger class
describe Cheetah::SynchronousMessenger do
  before do
    @options = {
      :host             => "foo.com",
      :username         => "foo_user",
      :password         => "foo",
      :aid              => "123",
      :enable_tracking  => false,
    }
    @messenger = Cheetah::SynchronousMessenger.new(@options)
  end

  context 'logging in' do
    it 'sets the session cookie' do
      messenger = Cheetah::SynchronousMessenger.new(@options)
      message = Message.new('/', {})

      stub_login
      stub_request(:post, 'https://foo.com/').to_return(status: 200, body: 'OK\r\n')

      messenger.do_send(message)

      messenger.instance_variable_get(:@cookie).should_not be_nil
    end

    it 'raises error in the event of an authentication failure' do
      messenger = Cheetah::SynchronousMessenger.new(@options)
      message = Message.new('/', {})

      stub_request(:post, 'https://foo.com/api/login1').with(body: { name: 'foo_user', cleartext: 'foo' }).to_return(body: "err:authentication error\r\n", status: 200)

      lambda { messenger.do_send(message) }.should raise_error(CheetahPermanentException)
    end
  end

  context "#do_send" do
    before do
      @message   = Message.new("/",{})

      stub_login
    end

    it "should raise CheetahPermanentException when there's a permanent error on Cheetah's end" do
      stub_request(:post, 'https://foo.com/').to_return(status: 400)

      lambda { @messenger.do_send(@message) }.should raise_error(CheetahPermanentException)
    end

    it "should raise CheetahTemporaryException when there's a temporary (server) error on Cheetah's end" do
      stub_request(:post, 'https://foo.com/').to_return(status: 500)

      lambda { @messenger.do_send(@message) }.should raise_error(CheetahTemporaryException)
    end

    it "should raise CheetahTemporaryException when there's a temporary error on Cheetah's end" do
      stub_request(:post, 'https://foo.com/').to_return(status: 200, body: 'err:internal error')

      lambda { @messenger.do_send(@message) }.should raise_error(CheetahTemporaryException)
    end
  end

  describe '#send_message' do
    before do
      @params = {'email' => 'foo@test.com'}
      @message = Message.new('/', @params)

      stub_login
      stub_request(:post, 'https://foo.com/').with(body: 'email=foo%40test.com').to_return(status: 200, body: "OK\r\n")
    end

    it 'should send' do
      @messenger.should_receive(:do_send).with(@message)
      @messenger.send_message(@message)
    end

    context 'with a whitelist filter' do
      before do
        @options[:whitelist_filter] = /@test\.com$/
        @messenger = Cheetah::SynchronousMessenger.new(@options)
        @message   = Message.new('/', @params)
      end

      context 'and an email that does not match the whitelist filter' do
        before do
          @email = 'foo@bar.com'
        end

        it "should suppress the email" do
          @message.params['email'] = @email
          @messenger.should_not_receive(:do_send)
          @messenger.send_message(@message)
        end
      end

      context 'with an email that matches the whitelist filter' do
        before do
          @email = 'foo@test.com'
        end

        it 'should send' do
          @messenger.should_receive(:do_send).with(@message)
          @messenger.send_message(@message)
        end

        context "with :enable_tracking set to true" do
          before do
            @options[:enable_tracking] = true
            @messenger = Cheetah::SynchronousMessenger.new(@options)
          end

          it 'should not set the test parameter' do
            @message.params.should_not_receive(:[]=).with('test', '1')
            @messenger.send_message(@message)
          end
        end

        context "with :enable_tracking set to false" do
          before do
            @options[:enable_tracking] = false
            @messenger = Cheetah::SynchronousMessenger.new(@options)
          end

          it 'should set the test parameter' do
            @message.params.stub(:[]=)
            @message.params.should_receive(:[]=).with('test', '1')
            @messenger.send_message(@message)
          end
        end
      end
    end
  end
end
