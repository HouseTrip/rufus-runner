Dir.glob('spec/support/**/*.rb').each do |file|
  require "./#{file}"
end

