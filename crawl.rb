require 'mechanize'

agent = Mechanize.new
agent.get('http://idolmaster.jp/schedule/index.php')
raw_page = agent.page
raw_page.save('cal.html')

table = raw_page.search('table.List')
table.search('tr').each do |row|
  last_column = row.search('td').last
  next if last_column.children.first.name != 'a'
  puts '--'
  puts row.search('td').first.search('img').first.attributes['alt'].value if row.search('td').first.attributes['class'].value == 'day2'
  puts row.search('.time2').first.text
  puts row.search('.performance2 img').first.attributes['alt']
  puts "#{last_column.children.text} (#{last_column.children.first.attributes['href']})"
end
