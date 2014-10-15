require 'mechanize'

agent = Mechanize.new
agent.get('http://idolmaster.jp/schedule/index.php')

raw_page = agent.page
raw_page.save('cal.html')

table = raw_page.search('table.List')
table.search('tr').each do |row|
  last_column = row.search('td').last
  first_column = row.search('td').first
  next if last_column.children.first.name != 'a'
  puts first_column.children.first.attributes['alt'].value if first_column.attributes['class'].value == 'day2'
  puts last_column.children.text
end
