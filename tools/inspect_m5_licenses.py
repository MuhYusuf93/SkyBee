"""Read pinned local dependency license metadata, without changing caches."""
from pathlib import Path
import zipfile
import re

base=Path(r'C:\Users\ACER\.gradle\caches\modules-2\files-2.1')
for group,artifact,version in [('net.zetetic','sqlcipher-android','4.19.1'),('com.google.crypto.tink','tink-android','1.23.0')]:
 for path in (base/group/artifact/version).glob('*/*'):
  if path.suffix=='.pom':
   text=path.read_text(encoding='utf-8')
   start=text.find('<licenses>');end=text.find('</licenses>')
   print(artifact,version,text[start:end+11])
  if path.suffix in ('.aar','.jar'):
   with zipfile.ZipFile(path) as archive:
    names=[name for name in archive.namelist() if any(word in name.upper() for word in ('LICENSE','NOTICE','COPYING'))]
    print(artifact,path.name,names)
    if path.suffix=='.aar':
     for name in archive.namelist():
      if name.endswith('/libsqlcipher.so'):
       print(name,[m.decode('ascii') for m in re.findall(rb'OpenSSL [0-9][ -~]{1,65}',archive.read(name))][:3])
    for name in names:
     if not name.endswith('/') and archive.getinfo(name).file_size<200000:
      data=archive.read(name).decode('utf-8',errors='replace')
      print(name,data[:1800])
