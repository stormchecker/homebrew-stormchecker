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
    root_url "https://github.com/stormchecker/homebrew-stormchecker/releases/download/stormchecker-2.0.0"
    sha256 cellar: :any, arm64_golden_gate: "bb503c01ffa459eb01e3bfd83d969801b1408a724481d30e996b6f70b7fee748"
    sha256 cellar: :any, arm64_tahoe:       "591784746260527ecae7cc5bffc3f81ff0a1a2f45da5a690be8be554690351b8"
    sha256 cellar: :any, arm64_sequoia:     "0d68612e0c608688ad26d862d45aa61e0fad056e3e5fb58e8ba691646e7b8322"
    sha256 cellar: :any, arm64_linux:       "d30b7258a3359b2e6f31b42306c5e2438bad8a644b18e9a8ce08d3087c4dda4a"
    sha256 cellar: :any, x86_64_linux:      "7b5909babb4380db7ca12940be5c2be739d0876990e802ce95eb40229f2c11ce"
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
