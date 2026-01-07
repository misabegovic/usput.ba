# frozen_string_literal: true

namespace :cities do
  desc "Download and import cities from GeoNames database"
  task import: :environment do
    require "open-uri"
    require "zip"
    require "csv"

    # GeoNames cities database (gradovi sa populacijom > 1000)
    # Alternativa: cities15000.zip za gradove > 15000 stanovnika
    cities_url = "https://download.geonames.org/export/dump/cities1000.zip"
    country_info_url = "https://download.geonames.org/export/dump/countryInfo.txt"

    tmp_dir = Rails.root.join("tmp", "geonames")
    FileUtils.mkdir_p(tmp_dir)

    puts "Downloading cities database..."

    # Preuzmi country info za mapiranje country_code -> country_name
    country_names = {}
    begin
      URI.open(country_info_url) do |file|
        file.each_line do |line|
          next if line.start_with?("#")
          parts = line.split("\t")
          next if parts.length < 5
          country_code = parts[0]
          country_name = parts[4]
          country_names[country_code] = country_name
        end
      end
      puts "Loaded #{country_names.size} countries"
    rescue => e
      puts "Warning: Could not download country info: #{e.message}"
    end

    # Preuzmi cities zip file
    cities_zip_path = tmp_dir.join("cities1000.zip")
    cities_txt_path = tmp_dir.join("cities1000.txt")

    begin
      URI.open(cities_url) do |remote_file|
        File.open(cities_zip_path, "wb") do |local_file|
          local_file.write(remote_file.read)
        end
      end
      puts "Downloaded cities database"
    rescue => e
      puts "Error downloading cities: #{e.message}"
      exit 1
    end

    # Ekstrahiraj zip
    puts "Extracting..."
    Zip::File.open(cities_zip_path) do |zip_file|
      zip_file.each do |entry|
        if entry.name == "cities1000.txt"
          entry.extract(cities_txt_path) { true }
        end
      end
    end

    # Parsiraj i importiraj gradove
    puts "Importing cities..."
    count = 0
    batch_size = 1000
    cities_batch = []

    # GeoNames format:
    # 0: geonameid
    # 1: name
    # 2: asciiname
    # 3: alternatenames
    # 4: latitude
    # 5: longitude
    # 6: feature class
    # 7: feature code
    # 8: country code
    # 9: cc2
    # 10: admin1 code
    # 11: admin2 code
    # 12: admin3 code
    # 13: admin4 code
    # 14: population
    # 15: elevation
    # 16: dem
    # 17: timezone
    # 18: modification date

    File.foreach(cities_txt_path, encoding: "UTF-8") do |line|
      parts = line.chomp.split("\t")
      next if parts.length < 19

      name = parts[1]
      lat = parts[4].to_f
      lng = parts[5].to_f
      country_code = parts[8]
      region = parts[10]
      population = parts[14].to_i
      timezone = parts[17]

      cities_batch << {
        name: name,
        lat: lat,
        lng: lng,
        country_code: country_code,
        country_name: country_names[country_code],
        region: region,
        population: population,
        timezone: timezone,
        created_at: Time.current,
        updated_at: Time.current
      }

      if cities_batch.size >= batch_size
        City.insert_all(cities_batch)
        count += cities_batch.size
        print "\rImported #{count} cities..."
        cities_batch = []
      end
    end

    # Importiraj preostale
    if cities_batch.any?
      City.insert_all(cities_batch)
      count += cities_batch.size
    end

    puts "\nImported #{count} cities total"

    # Cleanup
    FileUtils.rm_rf(tmp_dir)
    puts "Done!"
  end

  desc "Import cities for specific countries only (faster)"
  task :import_countries, [ :codes ] => :environment do |_t, args|
    require "open-uri"
    require "zip"

    codes = args[:codes]&.split(",")&.map(&:strip)&.map(&:upcase) || []

    if codes.empty?
      puts "Usage: rake cities:import_countries[BA,HR,RS,ME,SI]"
      puts "This will import cities only for specified country codes"
      exit 1
    end

    puts "Importing cities for countries: #{codes.join(', ')}"

    cities_url = "https://download.geonames.org/export/dump/cities1000.zip"
    country_info_url = "https://download.geonames.org/export/dump/countryInfo.txt"

    tmp_dir = Rails.root.join("tmp", "geonames")
    FileUtils.mkdir_p(tmp_dir)

    # Preuzmi country info
    country_names = {}
    begin
      URI.open(country_info_url) do |file|
        file.each_line do |line|
          next if line.start_with?("#")
          parts = line.split("\t")
          next if parts.length < 5
          country_code = parts[0]
          country_name = parts[4]
          country_names[country_code] = country_name
        end
      end
    rescue => e
      puts "Warning: Could not download country info: #{e.message}"
    end

    # Preuzmi cities
    cities_zip_path = tmp_dir.join("cities1000.zip")
    cities_txt_path = tmp_dir.join("cities1000.txt")

    puts "Downloading cities database..."
    begin
      URI.open(cities_url) do |remote_file|
        File.open(cities_zip_path, "wb") do |local_file|
          local_file.write(remote_file.read)
        end
      end
    rescue => e
      puts "Error downloading cities: #{e.message}"
      exit 1
    end

    puts "Extracting..."
    Zip::File.open(cities_zip_path) do |zip_file|
      zip_file.each do |entry|
        if entry.name == "cities1000.txt"
          entry.extract(cities_txt_path) { true }
        end
      end
    end

    puts "Importing cities for selected countries..."
    count = 0
    batch_size = 500
    cities_batch = []

    File.foreach(cities_txt_path, encoding: "UTF-8") do |line|
      parts = line.chomp.split("\t")
      next if parts.length < 19

      country_code = parts[8]
      next unless codes.include?(country_code)

      name = parts[1]
      lat = parts[4].to_f
      lng = parts[5].to_f
      region = parts[10]
      population = parts[14].to_i
      timezone = parts[17]

      cities_batch << {
        name: name,
        lat: lat,
        lng: lng,
        country_code: country_code,
        country_name: country_names[country_code],
        region: region,
        population: population,
        timezone: timezone,
        created_at: Time.current,
        updated_at: Time.current
      }

      if cities_batch.size >= batch_size
        City.insert_all(cities_batch)
        count += cities_batch.size
        print "\rImported #{count} cities..."
        cities_batch = []
      end
    end

    if cities_batch.any?
      City.insert_all(cities_batch)
      count += cities_batch.size
    end

    puts "\nImported #{count} cities for #{codes.join(', ')}"

    FileUtils.rm_rf(tmp_dir)
    puts "Done!"
  end

  desc "Clear all cities from database"
  task clear: :environment do
    count = City.count
    City.delete_all
    puts "Deleted #{count} cities"
  end

  desc "Show cities statistics"
  task stats: :environment do
    puts "Cities Statistics"
    puts "-" * 40
    puts "Total cities: #{City.count}"
    puts ""
    puts "Top 10 countries by city count:"
    City.group(:country_code, :country_name)
        .count
        .sort_by { |_, v| -v }
        .first(10)
        .each do |country, count|
          code, name = country
          puts "  #{code} (#{name || 'N/A'}): #{count}"
        end
    puts ""
    puts "Top 10 cities by population:"
    City.order(population: :desc).limit(10).each do |city|
      puts "  #{city.name}, #{city.country_name}: #{city.population.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    end
  end
end
