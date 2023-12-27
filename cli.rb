# cli.rb

require 'csv'
require 'geocoder'

class CsvParser
  def initialize(input_file, output_file=false)
    @input_file = input_file
    @output_file = output_file
  end

  def parse
    validate_and_update_csv
  end

  private
  
  def validate_and_update_csv
    validate_csv
  end

  def validate_csv
    CSV.foreach(@input_file, headers: true, header_converters: :symbol) do |row|
      next unless valid_row?(row)
      enhanced_row = enhance_row(row)
      next unless enhanced_row
      if @output_file
        CSV.open(@output_file, 'a', write_headers: true, headers: enhanced_row.headers) do |csv|
          csv << enhanced_row.fields
        end
      else
        puts enhanced_row
      end
    end
  end

  def valid_row?(row)
    email_regex = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
    !row[:first_name]&.empty? &&
    !row[:last_name]&.empty?
    !row[:email]&.empty? && 
    row[:email]&.match?(email_regex) &&
    !resedential_address_empty?(row) &&
    !postal_address_empty?(row)
  end

  def resedential_address_empty?(row)
    row[:residential_address_street]&.empty? |
    row[:residential_address_locality]&.empty? |
    row[:residential_address_state]&.empty? |
    row[:residential_address_postcode]&.empty?
  end

  def postal_address_empty?(row)
    row[:postal_address_street]&.empty? |
    row[:postal_address_locality]&.empty? |
    row[:postal_address_state]&.empty? |
    row[:postal_address_postcode]&.empty?
  end

  def resedential_address(row)
    "#{row[:residential_address_street]}, #{row[:residential_address_locality]}, #{row[:residential_address_state]}, #{row[:residential_address_postcode]}"
  end

  def postal_address(row)
    "#{row[:postal_address_street]}, #{row[:postal_address_locality]}, #{row[:postal_address_state]}, #{row[:postal_address_postcode]}"
  end

  def enhance_row(row)
    coordinates = fetch_coordinates(row)
    return false unless coordinates
    row['Resedential Latitude'] = coordinates[0][0]
    row['Resedential Longitude'] = coordinates[0][1]
    row['Postal Latitude'] = coordinates[1][0]
    row['Postal Longitude'] = coordinates[1][1]
  end

  def fetch_coordinates(row)
    resedential_location = resedential_address(row)
    postal_location = postal_address(row)
    resedential_coordinates = Geocoder.search(resedential_location).first&.coordinates
    postal_coordinates = Geocoder.search(postal_location).first&.coordinates

    if resedential_coordinates && postal_coordinates
      [resedential_coordinates, postal_coordinates]
    else
      false
    end
  end
end

# Main CLI logic
if ARGV.include?('--help')
  puts 'Usage:'
  puts './cli input.csv # parses input.csv and prints output to STDOUT'
  puts './cli input.csv output.csv # parses input.csv and produces output.csv'
  exit
end

input_file = ARGV[0]
output_file = ARGV[1]
unless input_file
  puts 'Please provide the input CSV file.'
  exit
end

CsvParser.new(input_file, output_file).parse
