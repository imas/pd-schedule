require 'mechanize'
require 'icalendar'

def parse_timetext(year, month, day, time_text)
  range = time_text.scan(/[0-9]+:[0-9]+/)

  case range.count
  when 1
    start_time = get_datetime(year, month, day, range.first)
    end_time = start_time + Rational('1/24')
    start_time..end_time
  when 2
    start_time = get_datetime(year, month, day, range.first)
    end_time = get_datetime(year, month, day, range.last)
    start_time..end_time
  else
    theday = Date.new(year, month, day)
    nextday = theday + 1
    return theday..nextday
  end
end

def get_datetime(year, month, day, text)
  hour = text.split(':').first.to_i
  min = text.split(':').last.to_i
  begin
    time = DateTime.new(year, month, day, hour, min)
  rescue ArgumentError
    time = DateTime.new(year, month, day)
    time += Rational(hour, 24)
    time += Rational(min, 24 * 60)
  end
  time
end

specify_ym = '201407'
page_uri = 'http://idolmaster.jp/schedule/index.php'

specify_datetime = Date.strptime(specify_ym, '%Y%m') unless specify_ym.nil?
page_uri = "http://idolmaster.jp/schedule/#{specify_datetime.year}#{specify_datetime.strftime('%B').downcase}.php"

agent = Mechanize.new
agent.get(page_uri)
raw_page = agent.page

year = raw_page.search('#wrapperschedule .inner').first.attributes['id'].value.match(/(\d+)/)[1].to_i
month = raw_page.search('#wrapperschedule .tit img')[1].attributes['alt'].value.match(/(\d+)/)[1].to_i
raw_page.save(File.expand_path('html/%04d%02d.html'%[year, month], File.dirname(__FILE__)))

cal = Icalendar::Calendar.new
cal.timezone.tzid = "Asia/Tokyo"
day = 1
table = raw_page.search('table.List')
table.search('tr').each do |row|
  last_column = row.search('td').last
  next if last_column.children.first.name != 'a'
  if row.search('td').first.attributes['class'].value == 'day2'
    day = row.search('td').first.search('img').first.attributes['alt'].value.to_i
  end
  event_range = parse_timetext(year, month, day, row.search('.time2').first.text)
  dtstart = event_range.begin
  dtend = event_range.end
  if dtend - dtstart == 1
    dtstart = Icalendar::Values::Date.new dtstart
    dtend = Icalendar::Values::Date.new dtend
  end
  summary = "#{last_column.children.text} (#{last_column.children.first.attributes['href']})"

  cal.event do |evt|
    evt.dtstart = dtstart
    evt.dtend = dtend
    evt.summary = summary
  end
end

open(File.expand_path('ics/%04d%02d.ics'%[year, month], File.dirname(__FILE__)), 'w') do |file|
  file.puts cal.to_ical
end
