
def usage
  puts <<EOF

ruby tools/stat.rb pathdef < log/stat.log


pathdef should be like

/user/*
/
/users
/post/*/detail

then outputs like

METHOD	PATH	TIME	REQ	TIME/REQ
GET	/user/*	4825	321	15.031152647975079
GET	/	3021	893	3.382978723404255
GET	/users	10893	543	20.060773480662984
GET	/post/*/detail	6023	657	9.167427701674278

EOF
end

get = {  }
post = {  }
nget = {  }
npost = {  }
paths = []
unless ARGV[0]
  usage
  exit 1
end
open(ARGV[0]) do |f|
  f.each_line do |l|
    l.chomp!
    paths << l
    get[l] = 0
    post[l] = 0
    nget[l] = 0
    npost[l] = 0
  end
end
ARGV.shift

ARGF.each_line do |l|
  method, path, time = l.chomp.split("\t")
  paths.each do |k|
    if File.fnmatch(k, path, File::FNM_PATHNAME) && method == "GET"
      get[k] += time.to_i
      nget[k] += 1
    end
    if File.fnmatch(k, path, File::FNM_PATHNAME) && method == "POST"
      post[k] += time.to_i
      npost[k] += 1
    end
  end
end

puts "METHOD	PATH	TIME	REQ"
paths.each do |k|
  puts "GET\t#{k}\t#{get[k]}\t#{nget[k]}\t#{get[k].to_f / nget[k].to_f}"
  puts "POST\t#{k}\t#{post[k]}\t#{npost[k]}\t#{post[k].to_f / npost[k].to_f}"
end
