class Stormchecker < Formula
  desc "Modern probabilistic model checker"
  homepage "https://www.stormchecker.org"
  url "https://github.com/stormchecker/storm/archive/refs/tags/2.0.0.tar.gz"
  sha256 "60f0df72032331bd5284038b7a30ee3c003cbff672eda74cf302a0ee28164f00"
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
    url "https://github.com/stormchecker/carl-storm/archive/refs/tags/14.37.tar.gz"
    sha256 "a5127b61f7296aec567a6aca331eae51bc5b41a69d1eaf8cc991ce8aaa322a11"
  end

  resource "l3pp" do
    url "https://github.com/hbruintjes/l3pp/archive/513c7589232396e4b8975113b7709a8f39b46c85.tar.gz"
    sha256 "02cc7550717eb2c061cfaa07ff020daad2fd3f152cd9407d7cbad91cf059b443"
  end

  resource "StormEigen" do
    url "https://github.com/eigen-mirror/eigen/archive/bc3b39870ecb690a623a3f49149a358b95c5781d.tar.gz"
    sha256 "5f6557d1aca6e959a4b955c55f2935261fd30de59c0c79e35bc6d5cbe1de22d1"
  end

  resource "gmm" do
    url "https://download-mirror.savannah.gnu.org/releases/getfem/stable/gmm-5.5.tar.gz"
    sha256 "c7603f9007fe8e0be5beb68709d655bdef13c327f50391b69243fbc42dfefac6"
  end

  def install
    # Stage resources
    (buildpath/"fetched_deps").mkpath
    resources.each do |r|
      r.stage buildpath/"fetched_deps"/r.name
    end

    # Apply patches that usually Storm would have applied
    cd "fetched_deps/StormEigen" do
      system "git", "apply", buildpath/"resources/3rdparty/patches/eigen501.patch"
    end
    cd "fetched_deps/gmm" do
      system "patch", "-N", "-p1", "-s", "-i", buildpath/"resources/3rdparty/patches/gmm55.patch"
    end

    # Set CMake flags
    args = %w[
      -DCMAKE_BUILD_TYPE=RELEASE
      -DSTORM_COMPILE_WITH_CCACHE=OFF
      -DSTORM_BUILD_TESTS=OFF
      -DFETCHCONTENT_SOURCE_DIR_CARL=fetched_deps/carl-storm
      -DFETCHCONTENT_SOURCE_DIR_SYLVANFETCH=resources/3rdparty/sylvan
      -DFETCHCONTENT_SOURCE_DIR_L3PP=fetched_deps/l3pp
      -DFETCHCONTENT_SOURCE_DIR_EIGEN=fetched_deps/StormEigen
      -DFETCHCONTENT_SOURCE_DIR_GMM=fetched_deps/gmm
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
