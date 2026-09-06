namespace :content do
  desc "Validate authored metadata, dates, publication flags, IDs, assets and Markdown"
  task validate: :environment do
    result = ContentValidator.new.call
    result.warnings.each { |warning| warn "WARNING: #{warning}" }
    abort result.errors.join("\n") unless result.valid?

    puts "Content valid: #{result.documents} Markdown documents and #{ContentJsonSchemas.registered_paths.length} JSON catalogs."
  end
end
