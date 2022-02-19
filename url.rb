require "net/http"

File.open("list.csv", "r") do |file|
  file.each_line do |line|
    no, _, path = line.chomp.split(",")
    url = "https://ek1mem0.wiki.fc2.com#{path}"
    if r = Net::HTTP.get(URI.parse(url))
      File.open("raw/html/#{no}.html", "w") { |f| f.write(r) }
    else
      raise RuntimeError.new("fail to get #{url}")
    end
    puts url
  end
end
