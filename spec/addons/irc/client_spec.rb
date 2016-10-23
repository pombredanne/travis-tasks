require 'spec_helper'

describe Travis::Addons::Irc::Client do
  let(:subject)  { Travis::Addons::Irc::Client }
  let(:socket)   { stub(puts: true, get: true, eof?: true) }
  let(:server)   { 'irc.freenode.net' }
  let(:nick)     { 'travis_bot' }
  let(:channel)  { 'travis' }
  let(:password) { 'secret' }
  let(:ping)     { 'testping' }

  before do
    subject.stubs(:wait_for_numeric).returns(nil)
  end

  describe 'on initialization' do
    describe 'with no port specified' do
      it 'should open a socket on the server for port 6667' do
        TCPSocket.expects(:open).with(server, 6667).returns socket
        subject.new(server, nick)
      end
    end

    describe 'with port specified' do
      it 'should open a socket on the server for the given port' do
        TCPSocket.expects(:open).with(server, 1234).returns socket
        subject.new(server, nick, port: 1234)
      end
    end

    describe 'should connect to the server' do
      before do
        @socket = mock
        TCPSocket.stubs(:open).returns @socket
      end

      def expect_standard_sequence
        @socket.expects(:puts).with("NICK #{nick}\r")
        @socket.expects(:puts).with("USER #{nick} #{nick} #{nick} :#{nick}\r")
      end

      describe 'without a password' do
        it 'by sending NICK then USER' do
          expect_standard_sequence
          subject.new(server, nick)
        end
      end

      describe 'with a password' do
        it 'by sending PASS then NICK then USER' do
          @socket.expects(:puts).with("PASS #{password}\r")
          expect_standard_sequence
          subject.new(server, nick, password: password)
        end
      end

      describe "with a nickserv password" do
        it "should identify with nickserv" do
          @socket.expects(:puts).with("PRIVMSG NickServ :IDENTIFY pass\r")
          expect_standard_sequence
          subject.new(server, nick, nickserv_password: 'pass')
        end
      end

      describe "without a nickserv password" do
        it "should not identify with nickserv" do
          expect_standard_sequence
          subject.new(server, nick)
        end

      end
    end

    describe 'should connect to a server which requires ping/pong' do
      before do
        @socket = mock
        TCPSocket.stubs(:open).returns @socket
        @socket.stubs(:gets).returns("PING #{ping}").then.returns ""
      end

      def expect_standard_sequence
        @socket.expects(:puts).with("NICK #{nick}\r")
        @socket.expects(:puts).with("USER #{nick} #{nick} #{nick} :#{nick}\r")
        @socket.expects(:puts).with("PONG #{ping}\r")
      end

      describe "without a password" do
        it 'by sending NICK then USER' do
          expect_standard_sequence
          subject.new(server, nick)
          # this sleep is here so that the ping thread has a chance to run
          sleep 0.5
        end
      end

    end

    describe 'should define @numeric_received' do
      before do
        @socket = mock
        TCPSocket.stubs(:open).returns(@socket)
      end

      def expect_standard_sequence
        @socket.expects(:puts).with("NICK #{nick}\r")
        @socket.expects(:puts).with("USER #{nick} #{nick} #{nick} :#{nick}\r")
      end

      def expect_numeric_sequence
        expect_standard_sequence
        @socket.stubs(:gets).returns(":fake-server 001 fake-nick :fake-message").then.returns("")
      end

      describe 'to a non-true value' do
        it 'before receiving a numeric' do
          expect_standard_sequence
          client = subject.new(server, nick)
          client.numeric_received.should_not be_true
        end
      end

      describe 'to true' do
        it 'after receiving a numeric' do
          expect_numeric_sequence
          client = subject.new(server, nick)
          sleep 0.5
          client.numeric_received.should be_true
        end
      end
    end
  end

  describe 'with connection established' do
    let(:socket) { stub(puts: true) }
    let(:channel_key) { 'mykey' }

    before(:each) do
      TCPSocket.stubs(:open).returns socket
      @client = subject.new(server, nick)
    end

    it 'can message a channel before joining' do
      socket.expects(:puts).with("PRIVMSG #travis :hello\r")
      @client.say 'hello', 'travis'
    end

    it 'can notice a channel before joining' do
      socket.expects(:puts).with("NOTICE #travis :hello\r")
      @client.say 'hello', 'travis', true
    end

    it 'can join a channel' do
      socket.expects(:puts).with("JOIN ##{channel}\r")
      @client.join(channel)
    end

    it 'can join a channel with a key' do
      socket.expects(:puts).with("JOIN ##{channel} mykey\r")
      @client.join(channel, 'mykey')
    end

    describe 'and channel joined' do
      before(:each) do
        @client.join(channel)
      end
      it 'can leave the channel' do
        socket.expects(:puts).with("PART ##{channel}\r")
        @client.leave(channel)
      end
      it 'can message the channel' do
        socket.expects(:puts).with("PRIVMSG ##{channel} :hello\r")
        @client.say 'hello', channel
      end
      it 'can notice the channel' do
        socket.expects(:puts).with("NOTICE ##{channel} :hello\r")
        @client.say 'hello', channel, true
      end
    end

    it 'can run a series of commands' do
      socket.expects(:puts).with("JOIN #travis\r")
      socket.expects(:puts).with("PRIVMSG #travis :hello\r")
      socket.expects(:puts).with("NOTICE #travis :hi\r")
      socket.expects(:puts).with("PRIVMSG #travis :goodbye\r")
      socket.expects(:puts).with("PART #travis\r")

      @client.run do |client|
        client.join 'travis'
        client.say 'hello', 'travis'
        client.say 'hi', 'travis', true
        client.say 'goodbye', 'travis'
        client.leave 'travis'
      end
    end

    it 'can abandon the connection' do
      socket.expects(:puts).with("QUIT\r")
      socket.expects(:eof?).returns(true)
      socket.expects(:close)
      @client.quit
    end
  end
end
