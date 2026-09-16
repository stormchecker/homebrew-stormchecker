class Stormchecker < Formula
  desc "Modern probabilistic model checker"
  homepage "https://www.stormchecker.org"
  url "https://github.com/stormchecker/storm/archive/refs/tags/1.14.0.tar.gz"
  sha256 "ab5d7df2049ab683c3062f58d4201f960f8295bb9c702a2352305b7c7c597010"
  license "GPL-3.0-only"
  head "https://github.com/stormchecker/storm.git", using: :git, branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/stormchecker/homebrew-stormchecker/releases/download/stormchecker-1.14.0"
    sha256 cellar: :any, arm64_tahoe:   "b494ce4e4f2d5bb74b7a9459318777d26be17c7f207d364f94eeb3ce190a437a"
    sha256 cellar: :any, arm64_sequoia: "6f60bfde155499e0d4e7b438b58588e79c9424ea8a5d5125c31c36c2ce970466"
    sha256 cellar: :any, arm64_sonoma:  "5b5c9401a7305b301a94fdf79bd76a67c0bd98e9160d3bf51a40e4b4a9380fd5"
    sha256 cellar: :any, arm64_linux:   "83d9509a73e7f19576e21be3d7255156147f792dfeb8b30efa8956383d0df2ed"
    sha256 cellar: :any, x86_64_linux:  "887824f0844d9e141bb5a1e6dd9c52905ea2df358edb1c4bc03a80f175dc5df0"
  end

  depends_on "automake" => :build
  depends_on "cmake" => :build
  depends_on "boost"
  depends_on "cln"
  depends_on "ginac"
  depends_on "glpk"
  depends_on "gmp"
  depends_on "hwloc"
  depends_on "libarchive"
  depends_on "spot"
  depends_on "xerces-c"
  depends_on "z3"

  # Additional dependencies (usually obtained via FetchContent)
  resource "carl-storm" do
    url "https://github.com/stormchecker/carl-storm/archive/refs/tags/14.36.tar.gz"
    sha256 "bdb4339903544d03c8b63e348a1559b19cc420469116afa1e0cd6716cba63cfe"
  end

  def install
    # Stage resources
    (buildpath/"fetched_deps").mkpath
    resources.each do |r|
      r.stage buildpath/"fetched_deps"/r.name
    end

    # Set CMake flags
    args = %w[
      -DCMAKE_BUILD_TYPE=RELEASE
      -DSTORM_COMPILE_WITH_CCACHE=OFF
      -DSTORM_BUILD_TESTS=OFF
      -DFETCHCONTENT_SOURCE_DIR_CARL=fetched_deps/carl-storm
      -DFETCHCONTENT_SOURCE_DIR_SYLVANFETCH=resources/3rdparty/sylvan
    ]

    # Build and install
    system "cmake", "-S", ".", "-B", "build", *(std_cmake_args + args)
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    # Write small MDP file
    (testpath/"walk.nm").write <<~EOS
      mdp
      const int N;
      const double p = 0.5;
      module main
              x : [0..N] init N/2;
              [right] x<N -> p : (x'=x+1) + (1-p) : (x'=x);
              [left] x>0 -> p : (x'=x-1) + (1-p) : (x'=x);
      endmodule
    EOS
    # Run Storm and check output
    output = shell_output("#{bin}/storm --prism #{testpath}/walk.nm -prop 'Pmax=? [F<=10 x=0]' -const 'N=10' --exact")
    assert_match "Result (for initial states): 319/512", output
  end
end
