import os

path = r'e:\wiejski\wiejski\wiejski-kaskader-simulator'
replacements = {
    '\u00c4\u0099': '\u0119',  # ę
    '\u00c4\u0085': '\u0105',  # ą
    '\u00c4\u0087': '\u0107',  # ć
    '\u00c5\u0082': '\u0142',  # ł
    '\u00c5\u0084': '\u0144',  # ń
    '\u00c5\u009b': '\u015b',  # ś
    '\u00c5\u00ba': '\u017a',  # ź
    '\u00c5\u00bc': '\u017c',  # ż
    '\u00c3\u00b3': '\u00f3',  # ó
    '\u00c4\u0098': '\u0118',  # Ę
    '\u00c4\u0084': '\u0104',  # Ą
    '\u00c4\u0086': '\u0106',  # Ć
    '\u00c5\u0081': '\u0141',  # Ł
    '\u00c5\u0083': '\u0143',  # Ń
    '\u00c5\u009a': '\u015a',  # Ś
    '\u00c5\u00b9': '\u0179',  # Ź
    '\u00c5\u00bb': '\u017b',  # Ż
    '\u00c3\u0093': '\u00d3',  # Ó
}

files_fixed = []
for root, dirs, files in os.walk(path):
    dirs[:] = [d for d in dirs if d not in ['.godot', '.git', '__pycache__']]
    for f in files:
        if f.endswith('.gd'):
            fp = os.path.join(root, f)
            try:
                with open(fp, 'r', encoding='utf-8') as fh:
                    content = fh.read()
                original = content
                for bad, good in replacements.items():
                    content = content.replace(bad, good)
                if content != original:
                    with open(fp, 'w', encoding='utf-8', newline='\n') as fh:
                        fh.write(content)
                    files_fixed.append(f)
            except Exception as e:
                print(f"Error in {f}: {e}")
print('Fixed files:', files_fixed)
