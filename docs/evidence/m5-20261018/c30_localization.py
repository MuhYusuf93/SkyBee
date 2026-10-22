import json
from pathlib import Path
root=Path(__file__).resolve().parents[3]
translations={
 'm5DriveArchiveList':('Arsip Drive akun tujuan','Destination account Drive archives'),
 'm5DriveArchiveEmpty':('Tidak ada arsip Drive pada halaman ini.','No Drive archives on this page.'),
 'm5RunHistoryTitle':('Riwayat backup di perangkat ini','Backup history on this device'),
 'm5RunHistoryHelp':('Catatan pengiriman ke Drive untuk semua akun di perangkat ini. Arsip lama dapat terhapus oleh retensi; riwayat tetap disimpan.','Drive upload records for all accounts on this device. Retention may remove older archives; history is retained.'),
 'm5RunCurrentAccount':('Akun tujuan saat ini','Current destination account'),
 'm5RunOtherAccount':('Akun tujuan lain atau sebelumnya','Another or previous destination account'),
 'm5RunUnknownAccount':('Akun tujuan tidak tercatat','Destination account not recorded'),
}
for index,language in enumerate(['id','en']):
 path=root/f'lib/l10n/app_{language}.arb';data=json.loads(path.read_text(encoding='utf-8-sig'))
 for key,values in translations.items():
  assert key not in data
  data[key]=values[index];data['@'+key]={'description':'Backup destination archive listing or device-local cross-account upload history: '+key+'.'}
 path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('7 new keys, Indonesian and English; no credentials')
