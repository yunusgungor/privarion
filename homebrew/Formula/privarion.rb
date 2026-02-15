class Privarion < Formula
  desc "macOS Privacy Protection System"
  homepage "https://privarion.dev"
  url "https://github.com/privarion/privarion.git"
  version "1.0.0"
  license "MIT"
  
  sha256 "REPLACE_WITH_ACTUAL_SHA256"
  
  depends_on "swift" => :build
  depends_on :macos
  
  def install
    system "swift", "build", "-c", "release"
    
    bin.install ".build/release/privacyctl"
    app.install ".build/release/PrivarionGUI.app"
  end
  
  test do
    system "privarion", "--version"
  end
end
