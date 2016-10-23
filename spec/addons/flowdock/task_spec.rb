require 'spec_helper'

describe Travis::Addons::Flowdock::Task do
  include Travis::Testing::Stubs

  let(:subject) { Travis::Addons::Flowdock::Task }
  let(:http)    { Faraday::Adapter::Test::Stubs.new }
  let(:client)  { Faraday.new { |f| f.request :url_encoded; f.adapter :test, http } }
  let(:payload) { Marshal.load(Marshal.dump(TASK_PAYLOAD)) }

  before do
    subject.any_instance.stubs(:http).returns(client)
  end

  def run(targets)
    subject.new(payload, targets: targets).run
  end

  it "sends flowdock notifications to the Team Inbox with the given tokens" do
    targets = ['12345', '23456']
    message = <<-msg.gsub(/^\s*/m, '')
      <ul>
      <li><code><a href="https://github.com/svenfuchs/minimal">svenfuchs/minimal</a></code> build #2 has passed!</li>
      <li>Branch: <code>master</code></li>
      <li>Latest commit: <code><a href="https://github.com/svenfuchs/minimal/commit/62aae5f70ceee39123ef">62aae5f</a></code> by <a href="mailto:svenfuchs@artweb-design.de">Sven Fuchs</a></li>
      <li>Change view: https://github.com/svenfuchs/minimal/compare/master...develop</li>
      <li>Build details: https://travis-ci.org/svenfuchs/minimal/builds/#{build.id}</li>
      </ul>
    msg
    payload = {
      source:       'Travis',
      from_address: 'build+ok@flowdock.com',
      subject:      'svenfuchs/minimal build #2 has passed!',
      content:      message,
      from_name:    'CI',
      project:      'Build Status',
      format:       'html',
      tags:         ['ci', 'ok'],
      link:         "https://travis-ci.org/svenfuchs/minimal/builds/#{build.id}"
    }

    expect_flowdock('12345', payload)
    expect_flowdock('23456', payload)

    run(targets)
    http.verify_stubbed_calls
  end

  describe "handling errors" do
    it "doesn't raise on an invalid URI" do
      expect {
        subject.new(payload, targets: ["https://api.flowdock.com/v1/messages/team_inbox/pfd/oCT/ra Qgk/Q9/ttf/ sRFQ="]).run
      }.to_not raise_error
    end
  end

  def expect_flowdock(token, payload)
    http.post("v1/messages/team_inbox/#{token}") do |env|
      env[:url].host.should == 'api.flowdock.com'
      env[:body].should == MultiJson.encode(payload)
    end
  end
end

