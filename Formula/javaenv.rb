class Javaenv < Formula
  desc "Java environment manager - install and switch between JDK versions"
  homepage "https://github.com/latte-java/javaenv"
  url "https://github.com/latte-java/javaenv/archive/refs/heads/main.tar.gz"
  version "0.1.0"
  license "MIT"

  def install
    bin.install "javaenv"
  end

  def post_install
    (var/"lib/javaenv/java").mkpath
  end

  def caveats
    <<~EOS
      To use javaenv, create a .javaversion file in your project directory
      or ~/.javaversion with the JDK version you want (e.g., 17.0.18+8).

      Then install that version:
        javaenv install 17.0.18+8

      And generate the shims:
        javaenv reshim

      Ensure #{HOMEBREW_PREFIX}/bin is in your PATH (it usually is with Homebrew).
    EOS
  end

  test do
    assert_match "Usage: javaenv", shell_output("#{bin}/javaenv help")
  end
end
