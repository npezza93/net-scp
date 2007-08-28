$LOAD_PATH.unshift File.dirname(__FILE__)
require 'common'

class TestDownload < Net::SCP::TestCase
  def test_download_file_should_transfer_file
    file = prepare_file("/path/to/local.txt", "a" * 1234)

    expect_scp_session "-f /path/to/remote.txt" do |channel|
      simple_download(channel)
    end

    assert_scripted { scp.download!("/path/to/remote.txt", "/path/to/local.txt") }
    assert_equal "a" * 1234, file.io.string
  end

  def test_download_with_preserve_should_send_times
    file = prepare_file("/path/to/local.txt", "a" * 1234, 0644, Time.at(1234567890, 123456), Time.at(12121212, 232323))

    expect_scp_session "-f -p /path/to/remote.txt" do |channel|
      channel.sends_ok
      channel.gets_data "T1234567890 123456 12121212 232323\n"
      simple_download(channel, 0644)
    end

    File.expects(:utime).with(Time.at(12121212, 232323), Time.at(1234567890, 123456), "/path/to/local.txt")
    assert_scripted { scp.download!("/path/to/remote.txt", "/path/to/local.txt", :preserve => true) }
    assert_equal "a" * 1234, file.io.string
  end

  def test_download_with_progress_callback_should_invoke_callback
    prepare_file("/path/to/local.txt", "a" * 3000 + "b" * 3000 + "c" * 3000 + "d" * 3000)

    expect_scp_session "-f /path/to/remote.txt" do |channel|
      channel.sends_ok
      channel.gets_data "C0666 12000 remote.txt\n"
      channel.sends_ok
      channel.gets_data "a" * 3000
      channel.gets_data "b" * 3000
      channel.gets_data "c" * 3000
      channel.gets_data "d" * 3000
      channel.gets_ok
      channel.sends_ok
    end

    calls = []
    progress = Proc.new { |*args| calls << args }

    assert_scripted do
      scp.download!("/path/to/remote.txt", "/path/to/local.txt", &progress)
    end

    assert_equal ["/path/to/local.txt",     0, 12000], calls.shift
    assert_equal ["/path/to/local.txt",  3000, 12000], calls.shift
    assert_equal ["/path/to/local.txt",  6000, 12000], calls.shift
    assert_equal ["/path/to/local.txt",  9000, 12000], calls.shift
    assert_equal ["/path/to/local.txt", 12000, 12000], calls.shift
    assert calls.empty?
  end

  def test_download_io_with_recursive_should_raise_error
    expect_scp_session "-f -r /path/to/remote.txt"
    assert_raises(Net::SCP::Error) { scp.download!("/path/to/remote.txt", StringIO.new, :recursive => true) }
  end

  def test_download_io_with_preserve_should_ignore_preserve
    expect_scp_session "-f -p /path/to/remote.txt" do |channel|
      simple_download(channel)
    end

    io = StringIO.new
    assert_scripted { scp.download!("/path/to/remote.txt", io, :preserve  => true) }
    assert_equal "a" * 1234, io.string
  end

  def test_download_io_should_transfer_data
    expect_scp_session "-f /path/to/remote.txt" do |channel|
      simple_download(channel)
    end

    io = StringIO.new
    assert_scripted { scp.download!("/path/to/remote.txt", io) }
    assert_equal "a" * 1234, io.string
  end

  def test_download_bang_without_target_should_return_string
    expect_scp_session "-f /path/to/remote.txt" do |channel|
      simple_download(channel)
    end

    assert_scripted do
      assert_equal "a" * 1234, scp.download!("/path/to/remote.txt")
    end
  end

  private

    def simple_download(channel, mode=0666)
      channel.sends_ok
      channel.gets_data "C%04o 1234 remote.txt\n" % mode
      channel.sends_ok
      channel.gets_data "a" * 1234
      channel.gets_ok
      channel.sends_ok
    end
end