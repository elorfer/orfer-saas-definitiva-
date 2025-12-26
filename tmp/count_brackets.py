from pathlib import Path
p=Path(r"c:/app definitiva/apps/frontend/lib/features/home/screens/home_screen.dart")
s=p.read_text(encoding='utf-8')
counts={c:s.count(c) for c in '(){}[]'}
print(counts)
# print first 200 chars around likely area
idx=s.find('return RepaintBoundary')
print('index',idx)
print(s[idx:idx+400])
