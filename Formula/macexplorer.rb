cask "macexplorer" do
  version "1.0.0"
  sha256 "" # Will be filled after first release

  url "https://github.com/ronhash10/MacExplorer/releases/download/v#{version}/MacExplorer-#{version}.dmg"
  name "MacExplorer"
  desc "Windows-style file explorer for macOS"
  homepage "https://github.com/ronhash10/MacExplorer"

  app "MacExplorer.app"

  zap trash: [
    "~/Library/Preferences/com.macexplorer.app.plist",
    "~/Library/Caches/com.macexplorer.app",
  ]
end
