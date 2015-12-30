require 'mechanize'
require 'icalendar'
require 'optparse'

def ics_path(year, month)
  File.expand_path('ics/%04d%02d.ics'%[year, month], File.dirname(__FILE__))
end
def html_path(year, month)
  File.expand_path('html/%04d%02d.html'%[year, month], File.dirname(__FILE__))
end

class ProducerCalendar
  class << self
    def crawl(datetime)
      agent = Mechanize.new
      agent.tap do |mec|
        mec.follow_meta_refresh = true
        page_uri = if datetime
                     "http://idolmaster.jp/schedule/#{datetime.year}#{datetime.strftime('%B').downcase}.php"
                   else
                     'http://idolmaster.jp/schedule/index.php'
                   end
        mec.get(page_uri)
      end
      agent.page
    end

    def cache(datetime)
      src_path = if datetime
                   html_path(datetime.year, datetime.month)
                 else
                   Dir.glob('html/[0-9]*.html').sort{|a, b| b <=> a}.first
                 end
      Nokogiri.HTML(open(src_path))
    end
  end
end

class ProducerCalendarParser
  attr_accessor :existing_cal
  attr_reader :year, :month, :calendar

  def initialize(raw_page)
    @raw_page = raw_page
    @year = @raw_page.search('#wrapperschedule #tabs img').select{|img| img.attributes['src'].value.include? 'down'}.first.attributes['src'].value.match(/(\d+)/)[1].to_i
    month_word = @raw_page.search('#wrapperschedule .tit img')[1].attributes['src'].value.match(/_(\w+)\.jpg/)[1]
    @month = Time.parse(month_word).month

    @calendar = Icalendar::Calendar.new.tap { |cal| cal.timezone.tzid = "Asia/Tokyo" }

    yield self if block_given?
  end

  def analyze!
    day = 1
    table = @raw_page.search('table.List')
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

      genre = row.search('.genre2').text

      categories_img = row.search('.performance2 img').first
      if categories_img.respond_to? :attributes
        categories = categories_img.attributes['alt'].value.split(/、|,/)
      end

      categories ||= []
      category_text = ''
      categories.each do |cat|
        category_text += "【#{cat}】"
      end

      summary = "#{category_text}#{last_column.children.text}(#{genre})"
      description = "#{last_column.children.first.attributes['href']}"

      event = Icalendar::Event.new
      event.dtstart = dtstart
      event.dtend = dtend
      event.summary = summary
      event.description = description

      @existing_cal.first.events.each do |evt|
        next if evt.summary != summary
        next if evt.dtstart != event_range.begin
        next if evt.dtend != event_range.end
        event.uid = evt.uid
        event.dtstamp = evt.dtstamp
        break
      end if @existing_cal

      @calendar.add_event event
    end

    yield @calendar if block_given?

    @calendar
  end

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
      theday..nextday
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
end

params = ARGV.getopts('d:c')
use_cache = params['c']
specify_ym = params['d']

specify_datetime = Date.strptime(specify_ym, '%Y%m') unless specify_ym.nil?
ProducerCalendar.send((use_cache ? :cache : :crawl), specify_datetime).tap do |raw_page|
  ProducerCalendarParser.new(raw_page) do |parser|
    year, month = [parser.year, parser.month]
    raw_page.save(html_path(year, month)) unless use_cache
    if File.exist? ics_path(year, month)
      parser.existing_cal = open(ics_path(year, month), 'r:utf-8') { |f| Icalendar.parse(f) }
    end

    parser.analyze! do |cal|
      open(ics_path(year, month), 'w') { |f| f.puts cal.to_ical }
    end
  end
end
