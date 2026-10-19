# frozen_string_literal: true

require 'rspec'
require 'tmpdir'
require 'fileutils'

# Unit test for the SSL-backend detection used by packages/haproxy/packaging.
#
# The monolithic (single-variant) packaging script decides FIPS vs non-FIPS
# AWS-LC vs system OpenSSL purely from which blobs are present. That decision is
# extracted into src/detect-ssl-backend.sh so it lives in one place and can be
# pinned here. The order is load-bearing: a FIPS build ships BOTH the aws-lc-v*
# source and the golang-* toolchain, so golang-* must be detected first or a
# FIPS build would be silently misdetected as plain AWS-LC.
describe 'detect_ssl_backend (packages/haproxy build-time SSL backend selection)' do
  helper = File.expand_path('../../src/detect-ssl-backend.sh', __dir__)

  # Create a throwaway compile root with haproxy/<blob> files touched, run the
  # real helper against it, and return the detected backend string.
  def detect(helper, *blobs)
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, 'haproxy'))
      blobs.each { |b| FileUtils.touch(File.join(root, 'haproxy', b)) }
      `bash -c 'source "#{helper}"; detect_ssl_backend "#{root}"'`.strip
    end
  end

  it 'selects system OpenSSL when no crypto blobs are present' do
    expect(detect(helper)).to eq('openssl')
  end

  it 'selects non-FIPS AWS-LC when only the aws-lc source blob is present' do
    expect(detect(helper, 'aws-lc-v4.0.0.tar.gz')).to eq('awslc')
  end

  it 'selects FIPS when the golang toolchain blob is present alongside the source' do
    expect(detect(helper, 'aws-lc-v4.0.0.tar.gz', 'golang-1.27.1.tar.gz')).to eq('awslc-fips')
  end

  # The crux: FIPS always ships both blobs, so golang must win regardless of the
  # order the files happen to be listed/created. Guards against a future reorder
  # of the branches in detect-ssl-backend.sh.
  it 'prefers FIPS over non-FIPS when both aws-lc and golang blobs are present' do
    expect(detect(helper, 'golang-1.27.1.tar.gz', 'aws-lc-v4.0.0.tar.gz')).to eq('awslc-fips')
  end

  it 'does not treat an unrelated openssl-named tarball as AWS-LC' do
    expect(detect(helper, 'openssl-3.0.0.tar.gz')).to eq('openssl')
  end
end
