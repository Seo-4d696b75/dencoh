require "json"

def parse_words_special(table)
  list = []
  group = nil
  table.each do |e|
    tag = e[0]
    value = e[1]
    if tag == "th"
      group = {}
      group["title"] = value
      group["list"] = []
      list << group
    else
      if value == "変化なし" || value == "&nbsp;" || value == "なし" then next end
      group["list"] << value
    end
  end
  list
end

def parse_words(no, name, title, table, base, film)
  table = table.scan(/<(td|th).*?>(.+?)<\/(td|th)>/)
  if title == "ログイン時/通常時"
    title = "default"
  elsif title == "期間限定"
    base["special_words"] = parse_words_special(table)
    return
  elsif m = title.match(/(.+)(フィルム|ラッピング)?装着時/)
    title = m[1]
  else
    puts "unknown words title:#{title} at #{name}"
    return
  end
  type = ""
  words = {}
  group = {
    "numbering" => no,
    "name" => name,
    "series" => title,
    "words" => words,
  }
  special = nil
  table.each do |e|
    tag, value = e
    if tag == "th"
      if m = value.match(/^(.+?)限定$/)
        type = m[1]
        special = {}
        special["list"] = []
        special["title"] = type
        if !words.key?("special") then words["special"] = [] end
        words["special"] << special
      elsif value.include?("ログイン時")
        type = "ログイン時"
      elsif value.include?("車両基地")
        type = "車両基地"
      elsif value.include?("タイムライン")
        type = "タイムライン"
      else
        puts "unknown film title:#{value} at #{name} file:#{src}"
        exit(1)
      end
    else
      if value == "変化なし" || value == "なし" then next end
      if value == "&nbsp;" then value = "unknown" end
      if type == "ログイン時"
        if !base.key?("login_words") then base["login_words"] = [] end
        base["login_words"] << value
      elsif type == "車両基地"
        words["base"] = value
      elsif type == "タイムライン"
        if !words.key?("timeline") then words["timeline"] = [] end
        words["timeline"] << value
      else
        special["list"] << value
      end
    end
  end
  film << group
end

def parse_profile(no, str)
  dst = { "numbering" => no }
  m = str.match(/<h2.+?>プロフィール<\/h2>\s*<div><span.*?><span.*?>.*?No.(?<no>[0-9]+)[\s　]+(?<full_name>\S+)\s*<\/span><\/span><\/div>\s*<div>\s*<table.*?>(?<table>.+?)<\/table>\s*<\/div>/m)
  raise RuntimeError.new("no mismatched #{no}") if !no.include?(m[:no].to_i.to_s)
  full_name = m[:full_name]
  table = m[:table].scan(/<tr>(.+?)<\/tr>/m)
  raise RuntimeError.new("profile table cnt != 5 #{no}") if table.length != 5
  m = table[0][0].match(/<img.*?alt="(.+?)"/)
  name = m[1].downcase
  dst["name"] = name
  dst["full_name"] = full_name
  m = table[1][0].match(/<td>タイプ<\/td>\s*<td>(?<type>.+?)<\/td>/)
  case m[:type]
  when "アタッカー"
    dst["type"] = "attacker"
  when "ディフェンダー"
    dst["type"] = "defender"
  when "サポーター"
    dst["type"] = "supporter"
  when "トリックスター"
    dst["type"] = "trickster"
  else
    raise RuntimeError.new("fail parse denco type #{m[:type]} at #{no}")
  end
  m = table[2][0].match(/<td>属性<\/td>\s*<td>(<span.*?>)?(?<attr>.+?)(<\/span>)?<\/td>/m)
  attribute = m[:attr]
  raise RuntimeError.new("fail parse denco attr #{attribute} at #{no}") if !["eco", "heat", "cool", "flat"].include?(attribute)
  dst["attr"] = attribute
  m = table[3][0].match(/<td>でんこカラー<\/td>\s*<td>(<span.*?>)?(?<color>.+?)(<\/span>)?<\/td>/m)
  case m[:color]
  when "赤"
    dst["color"] = "red"
  when "黄"
    dst["color"] = "yellow"
  when "桃"
    dst["color"] = "pink"
  when "青"
    dst["color"] = "blue"
  when "緑"
    dst["color"] = "green"
  when "橙"
    dst["color"] = "orange"
  when "紫"
    dst["color"] = "purple"
  else
    raise RuntimeError.new("fail to parse color #{m[:color]} at #{no}")
  end
  dst
end

def parse(no, path, bases, skills, films)
  str = File.open(path, "r:utf-8").read
  base = parse_profile(no, str)
  name = base["name"]
  bases << base
  m = str.match(/セリフ<\/h2>(.+?)<h(2|3).+?>/m)
  m[1].scan(/<div.*?><p.*?><span.*?>(.+?)<\/span><\/p>.+?<table.*?>(.+?)<\/table>/m).each do |e|
    title, table = e
    parse_words(no, name, title, table, base, films)
  end
  if !base.key?("login_words")
    raise RuntimeError.new("no putsin in words at #{base["name"]} file:#{path}")
  end
  m = str.match(/ステータス詳細<\/h2>(.+?)(マイレージ最終値|h2|h3)/m)
  has_unknown = false
  list = m[1].scan(/<tr>(.+?)<\/tr>/m).map.with_index do |e, i|
    th = e[0].scan(/<td.*?>([0-9]+?|&nbsp;)<\/td>/m)
    if th.length != 4 then next nil end
    next th.map do |e|
           if e[0] == "&nbsp;"
             has_unknown = true
             next 0
           else
             next e[0].to_i
           end
         end
  end.compact
  puts "unknown status(#{name})" if has_unknown
  if list.length != 80
    puts "status size not 80 size:#{list.length} at #{name} file:#{path}"
  end
  exp = []
  ap = []
  hp = []
  list.each do |e|
    exp << e[1]
    ap << e[2]
    hp << e[3]
  end
  base["EXP"] = exp
  base["AP"] = ap
  base["HP"] = hp

  skill = {}
  skill["numbering"] = no
  class_name = no
  if class_name.match(/[0-9]+/)
    class_name = "D%02d" % no.to_i
  end
  skill["class"] = "#{class_name}_#{name[0].upcase}#{name[1..-1]}"
  skill["list"] = []
  m = str.match(/スキル<\/h2>(.+?)<h2.*?>/m)
  skill_name = m[1].match(/^\s*<h3.*?>(.+?)<\/h3>/m)[1]
  table = m[1]
  if m = m[1].match(/<td.*?>スキル名\s*『(.*?)』<\/td>/)
    skill_name2 = m[1]
    m = table.match(/<table.*?<tr>.*?スキルLv.*?<\/tr>(.+?)<\/table>/m)
    m[1].scan(/Lv.([0-9]+)<br\s*\/>\s*\(でんこLv.\s*([0-9]+)\)/).each do |e|
      skill_level, denco_level = e.map(&:to_i)
      skill["list"] << {
        "skill_level" => skill_level,
        "denco_level" => denco_level,
        "name" => denco_level == 80 ? skill_name2 : "#{skill_name} Lv.#{skill_level}",
      }
    end
  else
    skill["list"] << { "level" => 1, "name" => skill_name }
  end
  skills << skill
end

def format_list_json(list)
  str = "[\n  "
  str << list.map { |e| JSON.dump(e) }.join(",\n  ")
  str << "\n]"
  str
end

base = []
skill = []
film = []
File.open("src/url.csv", "r:utf-8") do |f|
  f.each_line do |line|
    no = line.chomp.split(",")[0]
    path = "src/html/#{no}.html"
    parse(no, path, base, skill, film)
    puts "no:#{no} file:#{path}"
  end
end

File.open("dst/base.json", "w:utf-8") { |f| f.write(format_list_json(base)) }
File.open("dst/skill.json", "w:utf-8") { |f| f.write(format_list_json(skill)) }
File.open("dst/film.json", "w:utf-8") { |f| f.write(format_list_json(film)) }
