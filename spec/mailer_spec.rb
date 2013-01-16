require 'spec_helper'

describe Cheetah::Mailer do
  def generate_mailer(options = {})
    options = {
      :host             => "foo.com",
      :username         => "foo_user",
      :password         => "foo",
      :aid              => "123",
    }.merge(options)

    Cheetah::Mailer.new(options)
  end

  before do
    stub_login
  end

  describe '#send_email' do
    it 'should send a message to the ebmtrigger api' do
      mailer = generate_mailer

      stub_request(:post, 'https://foo.com/ebm/ebmtrigger1').with(body: 'eid=foo&email=foo%40bar.baz&aid=123', headers: { 'Cookie' => 'token' })

      mailer.send_email(:foo, 'foo@bar.baz')
    end
  end

  describe '#mailing_list_update' do
    it "should should send a message to the setuser api" do
      mailer = generate_mailer

      stub_request(:post, 'https://foo.com/api/setuser1').with(body: 'sub=123&email=foo%40bar.baz&aid=123')

      mailer.mailing_list_update('foo@bar.baz', sub: '123')
    end
  end

  describe '#mailing_list_email_change' do
    it "should should send a message to the setuser api with the old and new emails" do
      mailer = generate_mailer

      stub_request(:post, 'https://foo.com/api/setuser1').with(body: 'email=foo%40bar.baz&newemail=foo2%40bar.baz&aid=123')

      mailer.mailing_list_email_change('foo@bar.baz', 'foo2@bar.baz')
    end
  end
end

