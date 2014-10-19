require 'mechanize'
require 'icalendar'

def parse_timerange(year, month, day, time_text)
  start_time = DateTime.new(year, month, day, 0, 0, 0)
  end_time = DateTime.new(year, month, day, 23, 59, 59)
  puts time_text
  start_time..end_time
end

agent = Mechanize.new
agent.get('http://idolmaster.jp/schedule/index.php')
raw_page = agent.page
raw_page.save('cal.html')

cal = Icalendar::Calendar.new
table = raw_page.search('table.List')
day = 1
table.search('tr').each do |row|
  last_column = row.search('td').last
  next if last_column.children.first.name != 'a'
  if row.search('td').first.attributes['class'].value == 'day2'
    day = row.search('td').first.search('img').first.attributes['alt'].value.to_i
  end
  event_range = parse_timerange(2014, 10, day, row.search('.time2').first.text)
  puts row.search('.performance2 img').first.attributes['alt']
  summary = "#{last_column.children.text} (#{last_column.children.first.attributes['href']})"

  cal.event do |evt|
    evt.dtstart = event_range.begin
    evt.dtend = event_range.end
    evt.summary = summary
  end
end

puts cal.to_ical
