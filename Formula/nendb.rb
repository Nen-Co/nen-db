class Nendb < Formula
  desc "AI-Native Graph Database built with Data-Oriented Design (DOD) for AI workloads"
  homepage "https://github.com/Nen-Co/nen-db"
  url "https://github.com/Nen-Co/nen-db/archive/v0.2.1-beta.tar.gz"
  sha256 "bcc5e864b05003fc14dba7e9150b4d17ea47c5e1a81ae38b91d9daef15286ba9"
  license "Apache-2.0"
  head "https://github.com/Nen-Co/nen-db.git", branch: "main"

  depends_on "zig" => :build

  def install
    # Build the project
    system "zig", "build", "-Doptimize=ReleaseFast"
    
    # Install the binary
    bin.install "zig-out/bin/nendb"
    
    # Create a symlink for the server command
    bin.install_symlink "nendb" => "nendb-server"
  end

  test do
    # Test that the binary works
    assert_match "NenDB", shell_output("#{bin}/nendb --version", 1)
    
    # Test help command
    assert_match "Usage:", shell_output("#{bin}/nendb help", 1)
  end
end
