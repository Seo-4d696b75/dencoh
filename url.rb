
def parse_url_item(cell)
  no = cell[0]
  img_path = cell[1].match(/<img.*?src="(?<src>.+?)"/)[:src]
  m = cell[2].match(/<a.*?href="(?<href>.+?)">(?<name>.+?)<\/a>/)
  wiki_path = m[:href]
  name = m[:name]
  type = cell[3]
  attr = cell[4].match(/<img.*?alt="(?<attr>.+?)"/)[:attr]
  color = cell[5]
  skill_name = cell[6]
  desc = cell[7]
  [no, img_path, wiki_path, name, type, attr, color, skill_name, desc]
end

def parse_url_list(str)
  m = str.match(/<table.*?>(?<body>.+?)<\/table>/m)
  body = m[:body]
  rows = body.scan(/<tr>.+?<\/tr>/m)
  rows.map do |row|
    row.scan(/<td.*?>(.+?)<\/td>/m).map{|e| e[0]}
  end.select do |e|
    e.length > 0
  end.map do |e|
    parse_url_item(e).join(",")
  end
end

result = Dir.glob("src/*.html").map do |path|
  File.open(path).read
end.map do |str|
  parse_url_list(str)
end.flatten.join("\n")

File.open("src/url.csv", "w:utf-8").write(result)