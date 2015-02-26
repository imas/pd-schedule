require 'icalendar'

calendar = Icalendar::Calendar.new
Dir.glob('ics/[0-9]*.ics').sort.each do |icsname|
  open(icsname, 'r:utf-8') do |file|
    Icalendar.parse(file, true).events.each do |evt|
      calendar.add_event(evt)
    end
  end
end

open('ics/pd-schedule.ics', 'w') do |out|
  out.puts calendar.to_ical
end
