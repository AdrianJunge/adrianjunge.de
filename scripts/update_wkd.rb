#!/usr/bin/env ruby
require "digest"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"
require_relative "../app/models/site_profile"

# Authoring tool only: deployed Rails serves the committed export without GPG.
class WkdPublisher
  class Failure < StandardError; end
  ZBASE32 = "ybndrfg8ejkmcpqxot1uwisza345h769".freeze

  def initialize(root:, email: SiteProfile.email)
    @root = Pathname(root)
    @email = email
    @directory = @root.join("public/.well-known/openpgpkey")
  end

  def hash
    # SHA-1 is WKD's specified filename mapping, not a cryptographic signature.
    mailbox = @email.split("@", 2).first.tr("A-Z", "a-z")
    bits = Digest::SHA1.digest(mailbox).unpack1("B*")
    bits.scan(/.{5}/).map { |group| ZBASE32[group.to_i(2)] }.join
  end

  def run(check: false)
    binary, fingerprint = export
    key_path = @directory.join("hu", hash)
    policy_path = @directory.join("policy")
    if check
      unless key_path.file? && key_path.binread == binary && policy_path.file? && policy_path.size.zero?
        raise Failure, "WKD files are missing or stale. Run: ruby scripts/update_wkd.rb"
      end
      unless @directory.children.map(&:basename).map(&:to_s).sort == %w[hu policy] &&
             key_path.dirname.children.map(&:basename).map(&:to_s) == [ hash ]
        raise Failure, "Unexpected files in the public WKD directory"
      end
    else
      FileUtils.mkdir_p(key_path.dirname)
      key_path.binwrite(binary)
      policy_path.binwrite("")
    end
    { email: @email, fingerprint: fingerprint, hash: hash, bytes: binary.bytesize }
  end

  private

  def export
    source = @root.join("public", SiteProfile.pgp_path.delete_prefix("/")).binread
    unless source.start_with?("-----BEGIN PGP PUBLIC KEY BLOCK-----") && !source.include?("PRIVATE KEY BLOCK")
      raise Failure, "The source must be an armored public key export"
    end

    Dir.mktmpdir("adrian-wkd-") do |home|
      # Never consult the owner's GPG configuration, trust database, or keys.
      command = [ "gpg", "--no-options", "--homedir", home, "--batch", "--no-tty", "--no-autostart" ]
      gpg(command, "--import-options", "import-minimal", "--import", input: source)
      source_records = records(gpg(command, "--with-colons", "--list-keys"))
      unless source_records.count { |record| record[0] == "pub" } == 1
        raise Failure, "The source must contain exactly one public certificate"
      end
      unless source_records.any? { |record| record[0] == "uid" && (record[9][/<([^<>]+)>/, 1] || record[9]) == @email }
        raise Failure, "The public certificate needs a signed #{@email} identity"
      end
      fingerprint = source_records.find { |record| record[0] == "fpr" }.fetch(9)
      binary = gpg(command, "--export-options", "export-minimal",
        "--export-filter", "keep-uid=mbox = #{@email}", "--export", fingerprint)
      exported = records(gpg(command, "--with-colons", "--show-keys", input: binary))
      identities = exported.select { |record| record[0] == "uid" }.map { |record| record[9] }
      unless identities.one? && (identities.first[/<([^<>]+)>/, 1] || identities.first) == @email
        raise Failure, "The public certificate needs a signed #{@email} identity"
      end
      unless exported.any? { |record| %w[pub sub].include?(record[0]) && record[11].to_s.include?("e") }
        raise Failure, "The WKD export is missing an encryption key"
      end
      [ binary, fingerprint ]
    end
  end

  def gpg(command, *arguments, input: "")
    output, error, status = Open3.capture3(*command, *arguments, stdin_data: input, binmode: true)
    raise Failure, "GnuPG rejected the public certificate: #{error.strip}" unless status.success?

    output
  rescue Errno::ENOENT
    raise Failure, "Install GnuPG 2.2 or later to generate or check WKD exports"
  end

  def records(output)
    output.lines.map { |line| line.strip.split(":", -1) }
  end
end

if $PROGRAM_NAME == __FILE__
  abort "Usage: ruby scripts/update_wkd.rb [--check]" unless ARGV.empty? || ARGV == [ "--check" ]
  begin
    result = WkdPublisher.new(root: File.expand_path("..", __dir__)).run(check: ARGV == [ "--check" ])
    puts "WKD #{ARGV.empty? ? 'generated' : 'verified'}: #{result[:email]}, #{result[:fingerprint]}, #{result[:bytes]} bytes"
  rescue WkdPublisher::Failure, SystemCallError => error
    warn error.message
    exit 1
  end
end
