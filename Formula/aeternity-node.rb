class AeternityNode < Formula
  desc "Aeternity blockchain reference implementation in Erlang"
  homepage "https://aeternity.com"
  url "https://github.com/aeternity/aeternity/releases/download/v5.11.0/aeternity-5.11.0-macos-x86_64.tar.gz"
  version "5.11.0"
  sha256 "970bd7f6562ac0f76539e1ffbde264774120de5b09d0dc24bf2e6b53e704aa07"
  license "ISC"
  head "https://github.com/aeternity/aeternity.git"

  bottle :unneeded

  depends_on "gmp"
  depends_on "libsodium"
  depends_on "openssl"

  uses_from_macos "curl"

  def install
    prefix.install Dir["*"]

    (var/"aeternity/log").mkpath
    (var/"aeternity/data/mnesia").mkpath

    prefix.install_symlink var/"aeternity/log"
    (prefix/"data").install_symlink var/"aeternity/data/mnesia"

    inreplace bin/"aeternity" do |s|
      s.gsub! 'SCRIPT_DIR="$(cd "$(dirname "$SCRIPT")" && pwd -P)"', "SCRIPT_DIR=#{bin}"
      s.gsub! "set -e", "set -e\nulimit -n 24576"
    end
  end

  def caveats
    return unless latest_version_installed?

    <<~EOS
      NOTE The aeternity node is not started by default, run:
        '#{bin}/aeternity daemon' to start the node in background mode or
        '#{bin}/aeternity console' to start it in foreground/console mode.

      You may want to add #{bin} to your PATH to use `aeternity` command without full path.
    EOS
  end

  test do
    system "false"
    # ENV["AE__CHAIN_PERSIST"] = 0 ?
    # system bin/"aeternity", "daemon"
    # system "curl -s -f -S -o /dev/null --retry 6 http://localhost:3013/v2/status"
    # system bin/"aeternity", "stop"
  end
end
