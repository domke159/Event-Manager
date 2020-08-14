require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_number(phone_number)
  phone_number = phone_number.tr('^0-9', '')
  if phone_number.length < 10 || (phone_number == 11 && phone_number[0] != '1') || phone_number.length > 11
    "Wrong number"
  elsif phone_number.length == 10
    phone_number
  elsif phone_number.length == 11 && phone_number[0] == '1'
    phone_number = phone_number[1..-1]
    phone_number
  end
end

def convert_to_date(registration_date)
  format = "%m/%d/%Y %H:%M"
  date = DateTime.strptime(registration_date, format)
end

def peak_hour(hours)
  freq = hours.inject(Hash.new(0)) { |h,v| h[v] += 1; h }
  hours.max_by { |v| freq[v] }
end

def peak_week(weeks)
  freq = weeks.inject(Hash.new(0)) { |h,v| h[v] += 1; h }
  weeks.max_by { |v| freq[v] }
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir("output") unless Dir.exists?("output")

  filename = "output/thanks_#{id}.html"

  File.open(filename,'w') do |file|
    file.puts form_letter
  end
end

puts "EventManager initialized."

contents = CSV.open 'event_attendees.csv', headers: true, header_converters: :symbol

template_letter = File.read "form_letter.erb"
erb_template = ERB.new template_letter

hours = []
weeks = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = clean_number(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  hours << convert_to_date(row[:regdate]).strftime("%H")
  weeks << convert_to_date(row[:regdate]).wday
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id,form_letter)
end

puts("Peak registration hour: #{peak_hour(hours)}:00")
puts("Peak registration week: #{peak_week(weeks)}")