#!/usr/bin/env ruby
require "fileutils"
require "json"
require "open3"
require "optparse"
require "time"

module ReleaseManifest
  DIGEST = /\Asha256:[a-f0-9]{64}\z/
  COMMIT = /\A[a-f0-9]{40}\z/

  def self.build(image:, commit:, run_url:, inspection:, now: Time.now.utc)
    raise ArgumentError, "Expected a full source commit" unless COMMIT.match?(commit.to_s)
    match = /\A(ghcr\.io\/[a-z0-9_.-]+\/[a-z0-9_.\/-]+):sha-([a-f0-9]{40})-([0-9]+)-([0-9]+)\z/.match(image.to_s)
    raise ArgumentError, "Expected a unique GHCR sha/commit/run/attempt tag" unless match && match[2] == commit
    repository = match[1]
    source = "https://github.com/#{repository.delete_prefix('ghcr.io/')}"
    expected_run = "#{source}/actions/runs/#{match[3]}/attempts/#{match[4]}"
    raise ArgumentError, "Workflow identity does not match the image tag" unless run_url == expected_run
    raise ArgumentError, "Expected exactly one inspected image" unless inspection.is_a?(Array) && inspection.length == 1

    metadata = inspection.first
    labels = metadata.fetch("Config").fetch("Labels")
    raise ArgumentError, "Image source commit label does not match" unless labels["org.opencontainers.image.revision"] == commit
    raise ArgumentError, "Image repository label does not match" unless labels["org.opencontainers.image.source"].to_s.downcase == source
    raise ArgumentError, "Image ID is missing or invalid" unless DIGEST.match?(metadata["Id"].to_s)

    digests = Array(metadata["RepoDigests"]).select do |reference|
      name, digest = reference.split("@", 2)
      name == repository && DIGEST.match?(digest.to_s)
    end.uniq
    raise ArgumentError, "Expected one pushed digest for #{repository}" unless digests.length == 1

    {
      schema_version: 1, image_tag: image, image_digest: digests.first,
      image_id: metadata.fetch("Id"), source_commit: commit, source_url: source,
      workflow_run: run_url, created_at: now.iso8601
    }
  end
end

if $PROGRAM_NAME == __FILE__
  options = {}
  parser = OptionParser.new do |cli|
    cli.banner = "Usage: ruby scripts/release_manifest.rb --image IMAGE --commit SHA --run-url URL --output FILE"
    %w[image commit run-url output].each { |name| cli.on("--#{name} VALUE") { |value| options[name.tr('-', '_').to_sym] = value } }
  end
  begin
    parser.parse!
    raise ArgumentError, parser.banner unless options.length == 4 && ARGV.empty?

    # Array arguments keep image references out of shell parsing.
    output, error, status = Open3.capture3("docker", "image", "inspect", options.fetch(:image))
    raise ArgumentError, "Cannot inspect published image: #{error.strip}" unless status.success?

    manifest = ReleaseManifest.build(**options.except(:output), inspection: JSON.parse(output))
    FileUtils.mkdir_p(File.dirname(options.fetch(:output)))
    File.write(options.fetch(:output), JSON.pretty_generate(manifest) + "\n")
    puts manifest.fetch(:image_digest)
  rescue ArgumentError, KeyError, JSON::ParserError, OptionParser::ParseError => error
    warn error.message
    exit 1
  end
end
