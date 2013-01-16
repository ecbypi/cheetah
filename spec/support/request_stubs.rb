module RequestStubs

  def stub_login
    stub_request(:post, 'https://foo.com/api/login1').
      with(body: { name: 'foo_user', cleartext: 'foo' }).
      to_return(body: "OK\r\n", headers: { 'set-cookie' => 'token' })
  end
end
