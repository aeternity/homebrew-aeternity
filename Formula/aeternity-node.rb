class AeternityNode < Formula
  AETERNITY_VERSION = "6.7.0"
  desc "Aeternity blockchain reference implementation in Erlang"
  homepage "https://aeternity.com"
  version AETERNITY_VERSION
  license "ISC"

  livecheck do
    url "https://github.com/aeternity/aeternity/releases/latest"
    regex(%r{href=.*?/tag/v?(\d+(?:\.\d+)+)["' >]}i)
  end

  on_macos do
    if Hardware::CPU.intel? && Hardware::CPU.is_64_bit?
      url "https://github.com/aeternity/aeternity/releases/download/v#{AETERNITY_VERSION}/aeternity-v#{AETERNITY_VERSION}-macos-x86_64.tar.gz"
      sha256 "f26a5cde98edc1acc4af4d0abd8875ec95e5b14ca7f40d75ea92413afae7f4ef"
    end
  end

  head do
    url "https://github.com/aeternity/aeternity.git"

    depends_on "cmake" => :build
    depends_on "autoconf" => :build
    depends_on "erlang@22" => :build
  end

  depends_on "gmp"
  depends_on "libsodium"
  depends_on "openssl@1.1"
  depends_on "rocksdb" => :recommended

  uses_from_macos "curl"

  # HAED are installed from source while :stable we use prebuild packages
  # while it's not quite standart formula setup, it does the job until more common bottles are supported
  def install
    if build.head?
      if build.with? "rocksdb"
        ohai "Building with shared rocksdb library"
        ENV["ERLANG_ROCKSDB_OPTS"] = "-DWITH_SYSTEM_ROCKSDB=ON -DWITH_LZ4=ON -DWITH_SNAPPY=ON -DWITH_BZ2=ON -DWITH_ZSTD=ON"
      else
        opoo "Building without shared rocksdb library, compiling from source"
      end

      system "make", "prod-build"

      prefix.install Dir["_build/prod/rel/aeternity/*"]
    end

    if build.stable?
      prefix.install Dir["*"]

      inreplace bin/"aeternity" do |s|
        s.gsub! 'SCRIPT_DIR="$(cd "$(dirname "$SCRIPT")" && pwd -P)"', "SCRIPT_DIR=#{bin}"
        s.gsub! "set -e", "set -e\nulimit -n 24576"
      end
    end

    (var/"aeternity/log").mkpath
    (var/"aeternity/data/mnesia").mkpath

    prefix.install_symlink var/"aeternity/log"
    (prefix/"data").install_symlink var/"aeternity/data/mnesia"
  end

  def caveats
    return unless latest_version_installed?

    <<~EOS
      To start the node run:
        brew services start aeternity-node
    EOS
  end

  plist_options manual: "aeternity-node"
  service do
    run [bin/"aeternity", "foreground"]
    run_type :immediate
    keep_alive true
    error_log_path var/"log/aeternity_service.log"
    log_path var/"log/aeternity_service.log"
    working_dir var
  end

  test do
    begin
      port = free_port

      pid = fork do
        ENV["AE__CHAIN__PERSIST"] = "false"
        ENV["AE__CHAIN__DB_PATH"] = testpath/"data"
        ENV["AE__KEYS__DIR"] = testpath/"keys"
        ENV["AE__LOGGING__LEVEL"] = "none"
        ENV["AE__HTTP__EXTERNAL__PORT"] = port.to_s
        exec bin/"aeternity", "foreground"
      end
      sleep 3

      expected_output = /\"node_version\":\"#{AETERNITY_VERSION}\"/
      assert_match expected_output, shell_output("curl -s 127.0.0.1:#{port}/v2/status")
    ensure
      if pid
        Process.kill("TERM", pid)
        Process.wait(pid)
      end
    end
  end
end
