% dj.key_hash - key hashing function for populate jobs, etc

function s = key_hash(key)
  s = dj.internal.hash(key);
  s = s(1:32);
end

